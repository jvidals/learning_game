"""Read-only content verification of a built APK against local manifests.

Optionally compare retained audio bytes with a preserved earlier APK.
Certificate, version and permissions are checked separately with Android tools.
"""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_STORED

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'assets/flutter_assets/'
RETIRED_CONTENT = {PREFIX + 'assets/audio/' + name + '.wav' for name in (
    'welcome', 'retry', 'reward', 'customize', 'adventure', 'sparkle_standard', 'sparkle_relaxed'
)} | {PREFIX + 'assets/scenery/' + name + '.png' for name in ('meadow', 'stream', 'woodland', 'castle')}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_companion_inventory(apk, required):
    names = apk.namelist()
    assert len(names) == len(set(names)), 'Duplicate APK entries'
    prefix = PREFIX + 'assets/companion/'
    actual = {name for name in names if name.startswith(prefix)}
    expected = {prefix + 'foal_3d/' + name for name in set(required) | {'manifest.json'}}
    assert actual == expected, 'APK companion inventory mismatch: ' + str(sorted(actual ^ expected))
    assert not any(name.endswith(('.blend', '.blend1', '.py')) or
                   any(part in name.split('/') for part in ('model-review', 'review', 'frames'))
                   for name in names), 'Authoring or review files in APK'


def verify(apk_path, baseline=None, allow_profiling=False):
    audio = json.loads((ROOT / 'assets/audio_manifest.json').read_text())
    foal_root = ROOT / 'assets/companion/foal_3d'
    manifest_bytes = (foal_root / 'manifest.json').read_bytes()
    foal = json.loads(manifest_bytes)
    required = {'items.png'}
    for name, outfit in foal['outfits'].items():
        required.add(name + '-poster.webp')
        for clip in outfit.values():
            required.update(s['asset'] for s in clip['segments'])
    assert required == set(foal['checksums']), 'Unreferenced or unverified foal asset'
    with ZipFile(apk_path) as apk:
        verify_companion_inventory(apk, required)
        files = set(apk.namelist())
        expected_content = {PREFIX+'assets/audio/'+name+'.wav' for name in audio}
        expected_content.update(PREFIX+'assets/companion/foal_3d/'+name for name in required | {'manifest.json'})
        pictures = json.loads((ROOT / 'assets/phonics/manifest.json').read_text())
        expected_content.update(PREFIX+'assets/phonics/'+name for name in set(pictures['checksums']) | {'manifest.json'})
        for name, checksum in pictures['checksums'].items():
            assert digest(apk.read(PREFIX+'assets/phonics/'+name)) == checksum, name
        actual_content = {name for name in files if name.startswith(PREFIX+'assets/')}
        assert actual_content == expected_content, 'Unexpected or missing bundled content: ' + str(sorted(actual_content ^ expected_content))
        for name, metadata in audio.items():
            path = PREFIX + 'assets/audio/' + name + '.wav'
            assert digest(apk.read(path)) == metadata['audio_sha256'], path
            assert apk.getinfo(path).compress_type == ZIP_STORED, path
        foal_prefix = PREFIX + 'assets/companion/foal_3d/'
        assert apk.read(foal_prefix + 'manifest.json') == manifest_bytes
        for name, expected in foal['checksums'].items():
            assert digest(apk.read(foal_prefix + name)) == expected, name
        assert PREFIX + 'shaders/companion_hair.frag' in files
        assert not any('assets/companion/gentle_foal/' in name for name in files)
        assert not any(name.endswith(('.blend', '.py')) for name in files)
        for name in files:
            if name.startswith('lib/') and name.endswith('/libapp.so'):
                has_profiling = b'FOAL_TIMING' in apk.read(name)
                assert has_profiling == allow_profiling, 'Unexpected profiling entrypoint: ' + name
        preserved = 0
        if baseline:
            with ZipFile(baseline) as old:
                for name in old.namelist():
                    if name.startswith((PREFIX + 'assets/audio/', PREFIX + 'assets/scenery/')) and not name.endswith('/'):
                        if name in RETIRED_CONTENT:
                            assert name not in files, 'Retired content still bundled: ' + name
                            continue
                        assert apk.read(name) == old.read(name), 'Changed previous content: ' + name
                        preserved += 1
    print(json.dumps({'apk': str(apk_path), 'bytes': apk_path.stat().st_size,
        'audio': len(audio), 'foalAssets': len(required),
        'companionInventoryExact': True,
        'profilingCandidate': allow_profiling,
        'retainedPreviousAudioUnchanged': preserved}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path, nargs='?', default=ROOT / 'artifacts/learning-corner.apk')
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--profiling-candidate', action='store_true',
        help='Allow the timing entrypoint only for the separate local performance APK')
    args = parser.parse_args()
    verify(args.apk, args.baseline, args.profiling_candidate)
