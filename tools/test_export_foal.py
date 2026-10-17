"""Small synthetic packing tests; never regenerates production artwork."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
import export_foal


class FoalPackingTests(unittest.TestCase):
    def test_manifest_requires_every_clip_sample_and_checksum(self):
        manifest = copy.deepcopy(export_foal.SPEC)
        manifest.update(outfits={}, checksums={'items.png': 'fixture'}, palette=export_foal.PALETTE, itemIds=[i[0] for i in export_foal.ITEMS])
        for head in manifest['headwear']:
            for wing in manifest['wings']:
                outfit = head+'-'+wing
                clips = manifest['outfits'][outfit] = {}
                manifest['checksums'][outfit+'-poster.webp'] = 'fixture'
                for clip, definition in manifest['clips'].items():
                    count = round(definition['durationMs'] * 60 / 1000)
                    segments = []
                    for first in range(0, count, 15):
                        length = min(15, count-first)
                        name = f'{outfit}-{clip}-{first//15:03d}.webp'
                        segments.append(dict(asset=name, firstFrame=first,
                            frameCount=length, decodedFrameCount=length,
                            sampleFrames=list(range(length))))
                        manifest['checksums'][name] = 'fixture'
                    clips[clip] = dict(frameCount=count, segments=segments)
        export_foal.validate_manifest(manifest)
        bad = copy.deepcopy(manifest)
        bad['outfits']['none-none']['bowing']['segments'][0]['sampleFrames'][2] = 99
        with self.assertRaises(ValueError):
            export_foal.validate_manifest(bad)
        bad = copy.deepcopy(manifest)
        del bad['checksums']['items.png']
        with self.assertRaises(ValueError):
            export_foal.validate_manifest(bad)
        bad = copy.deepcopy(manifest)
        bad['clips']['twirl']['durationMs'] = 1400
        with self.assertRaises(ValueError):
            export_foal.validate_manifest(bad)

    def test_held_poses_map_to_encoded_frames_and_masks_stay_lossless(self):
        with tempfile.TemporaryDirectory(prefix='foal-pack-test-') as temp:
            root = Path(temp)
            frames = root / 'frames' / 'none-none' / 'happy'
            frames.mkdir(parents=True)
            output = root / 'packed'
            output.mkdir()
            spec = copy.deepcopy(export_foal.SPEC)
            spec['size'] = 32
            for i in range(33):
                # A held first segment must merge to one encoded WebP frame.
                shade = 120 if i < 15 else 100 + i
                color = Image.new('RGBA', (32, 32), (shade, 140, 220, 255))
                color.putpixel((0, 0), (0, 0, 0, 0))
                color.save(frames / f'color-{i:04d}.png')
                mask = Image.new('L', (32, 32), 0)
                for x in range(32):
                    mask.putpixel((x, 16), x * 8)
                for plane in export_foal.RAW_PLANES[1:]:
                    mask.save(frames / f'{plane}-{i:04d}.png')
                color.close()
                mask.close()
            (frames / 'source.sha256').write_text('fixture\n')
            with patch.multiple(export_foal, SPEC=spec, FRAMES=root / 'frames', DEST=output):
                clip = export_foal.pack_clip('none-none', 'happy')
                before = {p.name: p.read_bytes() for p in output.iterdir()}
                self.assertEqual(export_foal.pack_clip('none-none', 'happy', index_only=True), clip)
                self.assertEqual({p.name: p.read_bytes() for p in output.iterdir()}, before)
            self.assertEqual(clip['frameCount'], 33)
            segments = clip['segments']
            self.assertEqual([s['frameCount'] for s in segments], [15, 15, 3])
            self.assertEqual(segments[0]['decodedFrameCount'], 1)
            self.assertEqual(segments[0]['sampleFrames'], [0] * 15)
            total = 0
            for segment in segments:
                self.assertEqual(len(segment['sampleFrames']), segment['frameCount'])
                with Image.open(output / segment['asset']) as image:
                    self.assertEqual(image.n_frames, segment['decodedFrameCount'])
                    if image.n_frames == 1:
                        first = segment['firstFrame']
                        last = first + segment['frameCount']
                        total += round(last * 1000 / 60) - round(first * 1000 / 60)
                    for i in range(image.n_frames):
                        image.seek(i)
                        image.load()
                        if image.n_frames > 1:
                            total += image.info['duration']
                        rgba = image.convert('RGBA')
                        self.assertEqual(rgba.getpixel((0, 0))[3], 0)
                        for plane in range(1,5):
                            self.assertEqual([rgba.getpixel((x, plane*32+16))[3] for x in range(32)], [x * 8 for x in range(32)])
                        rgba.close()
            self.assertEqual(total, 550)

    def test_inventory_rejects_stale_files_directories_and_missing_assets(self):
        with tempfile.TemporaryDirectory(prefix='foal-inventory-') as temp:
            root = Path(temp)
            for name in ('manifest.json', 'items.png'):
                (root/name).write_bytes(b'fixture')
            export_foal.validate_inventory(root, {'items.png'})
            for extra in ('old.webp', 'preview.json'):
                (root/extra).write_bytes(b'stale')
                with self.assertRaises(ValueError):
                    export_foal.validate_inventory(root, {'items.png'})
                (root/extra).unlink()
            (root/'old-revision').mkdir()
            with self.assertRaises(ValueError):
                export_foal.validate_inventory(root, {'items.png'})
            (root/'old-revision').rmdir()
            (root/'items.png').unlink()
            with self.assertRaises(ValueError):
                export_foal.validate_inventory(root, {'items.png'})

    def test_pack_only_rejects_missing_or_stale_render_provenance(self):
        with tempfile.TemporaryDirectory(prefix='foal-stale-') as temp:
            root = Path(temp)
            frames = root/'frames';output = root/'packed'
            clip = frames/'none-none'/'happy';clip.mkdir(parents=True)
            args = ['export_foal.py', '--pack-only', '--outfit', 'none-none',
                    '--clip', 'happy', '--dest', str(output),
                    '--frames-root', str(frames), '--log-root', str(root/'logs')]
            for stamp in (None, 'previous-model'):
                if stamp is not None:(clip/'source.sha256').write_text(stamp)
                with patch.multiple(export_foal, DEST=output, FRAMES=frames), \
                     patch.object(export_foal, 'source_hash', return_value='current-model'), \
                     patch('sys.argv', args):
                    with self.assertRaisesRegex(ValueError, 'Missing or stale'):
                        export_foal.main()
                self.assertFalse((output/'manifest.json').exists())

    def test_low_memory_pauses_before_starting_a_render(self):
        with patch.object(export_foal, 'available_bytes', return_value=1024**3), \
             patch.object(export_foal.subprocess, 'Popen') as launch:
            with self.assertRaisesRegex(MemoryError, 'resumable'):
                export_foal.run_blender(['blender'], None)
            launch.assert_not_called()

    def test_palette_changes_do_not_invalidate_rendered_geometry(self):
        with tempfile.TemporaryDirectory(prefix='foal-palette-test-') as temp:
            root = Path(temp)
            for name in ('animation_spec.json', 'build_model.py', 'rig_source.py',
                         'gentle_foal.blend', 'render_frames.py', 'rewards.py'):
                (root/name).write_bytes(b'geometry')
            (root/'reward_palette.json').write_text('old colors')
            with patch.object(export_foal, 'SOURCE', root):
                before = export_foal.source_hash()
                (root/'reward_palette.json').write_text('new colors')
                self.assertEqual(export_foal.source_hash(), before)

    def test_source_fingerprint_changes_with_authored_source(self):
        with tempfile.TemporaryDirectory(prefix='foal-source-test-') as temp:
            root = Path(temp)
            for name in ('animation_spec.json', 'build_model.py', 'rig_source.py', 'gentle_foal.blend', 'render_frames.py', 'rewards.py', 'reward_palette.json'):
                (root / name).write_bytes(b'fixture')
            with patch.object(export_foal, 'SOURCE', root):
                before = export_foal.source_hash()
                (root / 'gentle_foal.blend').write_bytes(b'edited fixture')
                self.assertNotEqual(export_foal.source_hash(), before)
                before = export_foal.source_hash()
                (root / 'rig_source.py').write_bytes(b'changed rig helper')
                self.assertNotEqual(export_foal.source_hash(), before)


if __name__ == '__main__':
    unittest.main()
