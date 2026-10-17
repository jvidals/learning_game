"""Export disjoint outfits into staging, then publish one complete manifest.

Uses the existing exporter and its provenance checks; never swaps app assets.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys

import export_foal


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dest', type=Path, required=True)
    parser.add_argument('--frames-root', type=Path, required=True)
    parser.add_argument('--log-root', type=Path, required=True)
    parser.add_argument('--blender', type=Path, default=Path('/usr/bin/blender'))
    parser.add_argument('--workers', type=int, choices=range(1, 5), default=1)
    parser.add_argument('--pack-workers', type=int, choices=range(1,5), default=1)
    parser.add_argument('--webp-method', type=int, choices=range(7), default=1)
    parser.add_argument('--minimize-size', action='store_true')
    parser.add_argument('--allow-mixed', action='store_true')
    parser.add_argument('--pack-only', action='store_true')
    parser.add_argument('--blender-threads', type=int, choices=range(1,9), default=2)
    parser.add_argument('--min-available-gib', type=int, default=8)
    args = parser.parse_args()
    if args.min_available_gib < 1:
        parser.error('Keep at least one GiB of host headroom')
    export_foal.MIN_AVAILABLE_GIB = args.min_available_gib
    dest, frames, logs = (p.resolve() for p in (args.dest, args.frames_root, args.log_root))
    if dest == export_foal.DEST.resolve() or export_foal.ROOT/'assets' in dest.parents:
        parser.error('The library export requires a staging destination outside assets/')
    for folder in (dest, frames, logs):folder.mkdir(parents=True, exist_ok=True)
    blender = str(args.blender.resolve())
    stamp = frames/'icons/source.sha256'
    icons = tuple(export_foal.SPEC['headwear'][1:] + export_foal.SPEC['wings'][1:] + ['hoof'])
    if not (stamp.is_file() and stamp.read_text().strip() == export_foal.source_hash()
            and all((stamp.parent/name/'color-0000.png').is_file() for name in icons)):
        if args.pack_only:
            parser.error('Missing or stale icon renders in --pack-only mode')
        with (logs/'icons.log').open('w') as log:
            export_foal.run_blender([blender, '--background', str(export_foal.SOURCE/'gentle_foal.blend'),
                '--threads', str(args.blender_threads), '--python-exit-code', '1', '--python',
                str(export_foal.SOURCE/'render_frames.py'), '--', '--root', str(frames), '--icons'],
                log)
        stamp.write_text(export_foal.source_hash()+'\n')
    command = [sys.executable, str(export_foal.ROOT/'tools/export_foal.py'),
               '--blender', blender, '--dest', str(dest), '--frames-root', str(frames),
               '--log-root', str(logs), '--pack-workers', str(args.pack_workers),
               '--blender-threads', str(args.blender_threads), '--min-available-gib', str(args.min_available_gib)]

    command += ['--webp-method', str(args.webp_method)]
    if args.minimize_size: command.append('--minimize-size')
    if args.allow_mixed: command.append('--allow-mixed')

    def export(outfit):
        print('Started', outfit, flush=True)
        with (logs/('outfit-'+outfit+'.log')).open('w') as log:
            subprocess.run(command+(['--pack-only'] if args.pack_only else [])+['--outfit', outfit], cwd=export_foal.ROOT,
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        print('Completed', outfit, flush=True)

    outfits = [h+'-'+w for h in export_foal.SPEC['headwear'] for w in export_foal.SPEC['wings']]
    if args.workers == 1:
        # Stop immediately after a failed/low-memory job; do not leave queued
        # outfits that could start again as the failed process releases RAM.
        for outfit in outfits:
            export(outfit)
    else:
        pool = ThreadPoolExecutor(max_workers=args.workers)
        try:
            list(pool.map(export, outfits))
        finally:
            pool.shutdown(wait=True, cancel_futures=True)
    subprocess.run(command+['--index-only'], cwd=export_foal.ROOT, check=True)
    print(json.dumps({'status': 'complete', 'outfits': len(outfits), 'staging': str(dest)}), flush=True)


if __name__ == '__main__':
    main()
