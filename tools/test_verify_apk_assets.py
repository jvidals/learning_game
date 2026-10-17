"""Packaging regression fixtures; no production APK or artwork is changed."""
from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import tempfile
from unittest.mock import patch
import verify_apk_assets
import unittest
import warnings
from zipfile import ZipFile

from verify_apk_assets import PREFIX, verify_companion_inventory


class CompanionApkInventoryTests(unittest.TestCase):
    def archive(self, extras=(), omitted=()):
        data = io.BytesIO()
        prefix = PREFIX + 'assets/companion/foal_3d/'
        names = [prefix + name for name in ('manifest.json', 'items.png')
                 if name not in omitted]
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            with ZipFile(data, 'w') as archive:
                for name in names + list(extras):
                    archive.writestr(name, b'fixture')
        return ZipFile(data)

    def test_only_current_manifest_and_referenced_assets_are_allowed(self):
        with self.archive() as archive:
            verify_companion_inventory(archive, {'items.png'})

    def test_stale_files_old_libraries_and_missing_assets_fail(self):
        for extra in ('assets/companion/foal_3d/old.webp',
                      'assets/companion/foal_3d/notes.json',
                      'assets/companion/gentle_foal/old.png',
                      'assets/companion/foal_3d/old/'):
            with self.subTest(extra=extra), self.archive([PREFIX+extra]) as archive:
                with self.assertRaises(AssertionError):
                    verify_companion_inventory(archive, {'items.png'})
        with self.archive(omitted={'items.png'}) as archive:
            with self.assertRaises(AssertionError):
                verify_companion_inventory(archive, {'items.png'})

    def test_unrelated_old_art_cannot_hide_outside_companion_directory(self):
        with tempfile.TemporaryDirectory(prefix='apk-content-') as temp:
            root=Path(temp);foal=root/'assets/companion/foal_3d'
            foal.mkdir(parents=True)
            (root/'assets/audio_manifest.json').write_text('{}')
            (root/'assets/phonics').mkdir()
            (root/'assets/phonics/manifest.json').write_text('{"checksums": {}}')
            names=('items.png','none-none-poster.webp','none-none-happy-000.webp')
            manifest={'outfits':{'none-none':{'happy':{'segments':[{'asset':names[2]}]}}},
                      'checksums':{name:hashlib.sha256(b'fixture').hexdigest() for name in names}}
            raw=json.dumps(manifest).encode();(foal/'manifest.json').write_bytes(raw)
            for extra in (False,True):
                apk=root/'fixture.apk'
                with ZipFile(apk,'w') as archive:
                    prefix=PREFIX+'assets/companion/foal_3d/'
                    archive.writestr(prefix+'manifest.json',raw)
                    archive.writestr(PREFIX+'assets/phonics/manifest.json',b'{"checksums": {}}')
                    for name in names:archive.writestr(prefix+name,b'fixture')
                    archive.writestr(PREFIX+'shaders/companion_hair.frag',b'shader')
                    if extra:archive.writestr(PREFIX+'assets/old-unicorn/preview.png',b'old')
                with patch.object(verify_apk_assets,'ROOT',root),redirect_stdout(io.StringIO()):
                    if extra:
                        with self.assertRaisesRegex(AssertionError,'bundled content'):
                            verify_apk_assets.verify(apk)
                    else:verify_apk_assets.verify(apk)

    def test_profiling_entrypoint_requires_explicit_candidate_mode(self):
        with tempfile.TemporaryDirectory(prefix='apk-profile-') as temp:
            root=Path(temp);foal=root/'assets/companion/foal_3d'
            foal.mkdir(parents=True)
            (root/'assets/audio_manifest.json').write_text('{}')
            (root/'assets/phonics').mkdir()
            (root/'assets/phonics/manifest.json').write_text('{"checksums": {}}')
            names=('items.png','none-none-poster.webp')
            manifest={'outfits':{'none-none':{}},'checksums':{name:hashlib.sha256(b'fixture').hexdigest() for name in names}}
            raw=json.dumps(manifest).encode();(foal/'manifest.json').write_bytes(raw)
            for instrumented in (False,True):
                apk=root/'fixture.apk'
                with ZipFile(apk,'w') as archive:
                    prefix=PREFIX+'assets/companion/foal_3d/'
                    archive.writestr(prefix+'manifest.json',raw)
                    archive.writestr(PREFIX+'assets/phonics/manifest.json',b'{"checksums": {}}')
                    for name in names:archive.writestr(prefix+name,b'fixture')
                    archive.writestr(PREFIX+'shaders/companion_hair.frag',b'shader')
                    archive.writestr('lib/arm64-v8a/libapp.so',b'FOAL_TIMING' if instrumented else b'normal')
                with patch.object(verify_apk_assets,'ROOT',root),redirect_stdout(io.StringIO()):
                    verify_apk_assets.verify(apk,allow_profiling=instrumented)
                    with self.assertRaisesRegex(AssertionError,'profiling entrypoint'):
                        verify_apk_assets.verify(apk,allow_profiling=not instrumented)

    def test_duplicate_entries_and_authoring_material_fail(self):
        for extra in (PREFIX+'assets/companion/foal_3d/items.png',
                      PREFIX+'art/unicorn.blend',
                      PREFIX+'art/unicorn.blend1',
                      PREFIX+'art/build.py',
                      PREFIX+'model-review/preview.png',
                      PREFIX+'frames/color-0000.png'):
            with self.subTest(extra=extra), self.archive([extra]) as archive:
                with self.assertRaises(AssertionError):
                    verify_companion_inventory(archive, {'items.png'})


if __name__ == '__main__':
    unittest.main()
