"""Compression behavior on tiny original renders, never production assets."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
import compress_foal as compression
import export_foal as foal


class CompressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.frames = self.root/'frames'
        self.frames.mkdir()
        self.spec = copy.deepcopy(foal.SPEC)
        self.spec['size'] = 32
        self.patcher = patch.object(foal, 'SPEC', self.spec)
        self.patcher.start(); self.addCleanup(self.patcher.stop)
        for index in range(18):
            # A held first segment and a moving final partial segment.
            color = Image.new('RGBA', (32, 32), (100 + max(0,index-14)*10, 140, 210, 255))
            color.putpixel((0, 0), (0, 0, 0, 0))
            if index < 15: color.putpixel((1, 0), (50, 60, 80, 127))
            color.save(self.frames/f'color-{index:04d}.png'); color.close()
            for plane in foal.RAW_PLANES[1:]:
                mask = Image.new('L', (32, 32), 0)
                for x in range(32): mask.putpixel((x,16),x*8)
                mask.save(self.frames/f'{plane}-{index:04d}.png'); mask.close()

    def test_all_profiles_preserve_held_and_partial_timing_and_every_coverage_plane(self):
        for first,last in ((0,15),(15,18)):
            baseline=self.root/f'baseline-{first}.webp'
            old=foal.encode_segment(self.frames,first,last,baseline,compression.PROFILES['baseline'])
            for profile,options in compression.PROFILES.items():
                with self.subTest(first=first,profile=profile):
                    candidate=self.root/(profile+'.webp')
                    metadata=foal.encode_segment(self.frames,first,last,candidate,options)
                    audit=compression.audit_segment(self.frames,candidate,baseline,metadata,old)
                    self.assertTrue(audit['coverage_exact'])
                    self.assertEqual(audit['samples'],last-first)
                    self.assertEqual(len(metadata['sampleFrames']),last-first)
                    if first==0:self.assertEqual(metadata['decodedFrameCount'],1)

    def test_translucent_blending_regressions_cannot_receive_a_valid_checkpoint(self):
        # libwebp 1.3.2 may accumulate a static translucent pixel when lossy
        # delta frames blend over it. The audit must catch this codec edge case.
        for index in range(15,18):
            path=self.frames/f'color-{index:04d}.png'
            with Image.open(path) as im: changed=im.copy()
            changed.putpixel((1,0),(50,60,80,127));changed.save(path);changed.close()
        baseline=self.root/'baseline.webp'
        old=foal.encode_segment(self.frames,15,18,baseline,compression.PROFILES['baseline'])
        with Image.open(baseline) as decoded:
            decoded.seek(1);decoded.load()
            affected=decoded.getpixel((1,0))[3]!=127
        if affected:
            with self.assertRaisesRegex(ValueError,'Coverage changed'):
                compression.audit_segment(self.frames,baseline,baseline,old,old)
        else:
            # Newer codec versions may fix the defect.
            self.assertTrue(compression.audit_segment(self.frames,baseline,baseline,old,old)['coverage_exact'])

    def test_failed_validation_preserves_previous_file_and_removes_partial_output(self):
        destination=self.root/'segment.webp';destination.write_bytes(b'previous')
        with patch.object(foal,'segment_metadata',side_effect=ValueError('bad duration')):
            with self.assertRaisesRegex(ValueError,'bad duration'):
                foal.encode_segment(self.frames,15,18,destination)
        self.assertEqual(destination.read_bytes(),b'previous')
        self.assertFalse(destination.with_name('segment.webp.partial').exists())

    def test_resume_requires_matching_inputs_options_and_uncorrupted_output(self):
        with patch.object(foal,'source_hash',return_value='source'):
            initial=compression.input_fingerprint(self.frames,15,3,'m4','raw','baseline')
            changed_options=compression.input_fingerprint(self.frames,15,3,'m6','raw','baseline')
            path=self.frames/'color-0015.png'
            with Image.open(path) as im:
                updated=im.copy()
            updated.putpixel((5,5),(255,0,0,255));updated.save(path);updated.close()
            changed_source=compression.input_fingerprint(self.frames,15,3,'m4','raw','baseline')
        self.assertNotEqual(initial,changed_options)
        self.assertNotEqual(initial,changed_source)
        destination=self.root/'output.webp';destination.write_bytes(b'verified')
        state=self.root/'state.json'
        record=dict(identity=initial,sha256=foal.sha(destination))
        compression.atomic_json(state,record)
        self.assertEqual(compression.resume_record(state,destination,initial),record)
        self.assertIsNone(compression.resume_record(state,destination,changed_options))
        destination.write_bytes(b'corrupted')
        self.assertIsNone(compression.resume_record(state,destination,initial))
        state.write_text('{interrupted')
        self.assertIsNone(compression.resume_record(state,destination,initial))

    def test_audit_rejects_changed_material_coverage(self):
        baseline=self.root/'baseline.webp'
        old=foal.encode_segment(self.frames,15,18,baseline)
        with Image.open(self.frames/'hooves-0015.png') as im:
            changed=im.copy()
        changed.putpixel((2,2),255);changed.save(self.frames/'hooves-0015.png');changed.close()
        with self.assertRaisesRegex(ValueError,'Coverage changed'):
            compression.audit_segment(self.frames,baseline,baseline,old,old)


if __name__=='__main__':
    unittest.main()
