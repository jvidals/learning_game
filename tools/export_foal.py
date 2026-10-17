"""Explicit, resumable authoring export. Routine builds only use --verify.

The .blend and packed clips are local build inputs; no network or paid service
is involved. Color and lossless visible-hair alpha share each WebP frame.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import signal
import time
from foal_reward_items import ITEMS, PALETTE, tint_icon
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/foal"
DEST = ROOT / "assets/companion/foal_3d"
FRAMES = ROOT / "artifacts/foal-3d/frames"
SPEC = json.loads((SOURCE / "animation_spec.json").read_text())
PACK_WORKERS = 1
BLENDER_THREADS = 2
MIN_AVAILABLE_GIB = 8
RAW_PLANES = ("color", "mask", "hooves", "headwear", "wings")
WEBP_OPTIONS = dict(lossless=False, quality=90, method=1, minimize_size=False, allow_mixed=False)


def sha(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def source_hash():
    h = hashlib.sha256()
    for name in ("animation_spec.json", "build_model.py", "rig_source.py", "gentle_foal.blend", "render_frames.py", "rewards.py"):
        h.update(name.encode())
        h.update(bytes.fromhex(sha(SOURCE / name)))
    return h.hexdigest()


def available_bytes():
    for line in Path('/proc/meminfo').read_text().splitlines():
        if line.startswith('MemAvailable:'):
            return int(line.split()[1]) * 1024
    raise RuntimeError('Cannot read available RAM')


def require_headroom():
    if available_bytes() < MIN_AVAILABLE_GIB * 1024**3:
        raise MemoryError('Export paused: less than required available RAM; completed clips remain resumable')


def run_blender(command, log):
    require_headroom()
    with subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT) as process:
        while process.poll() is None:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                if available_bytes() < MIN_AVAILABLE_GIB * 1024**3:
                    process.send_signal(signal.SIGINT)
                    try:
                        process.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    raise MemoryError('Stopped this render for low available RAM; resume completed clips later')
        if process.returncode:
            raise subprocess.CalledProcessError(process.returncode, command)


def packed(frame_dir, index):
    from PIL import Image
    size = SPEC["size"]
    output = Image.new("RGBA", (size, size * len(RAW_PLANES)))
    for plane, name in enumerate(RAW_PLANES):
        with Image.open(frame_dir / f"{name}-{index:04d}.png") as source:
            if source.size != (size, size):
                output.close()
                raise ValueError("Unexpected render size")
            if plane == 0:
                color = source.convert("RGBA")
                output.paste(color, (0,0))
                color.close()
            else:
                tile = Image.new("RGBA", (size,size), (0,0,0,0))
                alpha = source.convert("L")
                tile.putalpha(alpha)
                output.paste(tile, (0,size*plane))
                alpha.close()
                tile.close()
    return output


def segment_metadata(path, first, count):
    """Decode a segment and recover the authored-sample to codec-frame mapping."""
    from PIL import Image
    durations = [round((i+1)*1000/SPEC['fps'])-round(i*1000/SPEC['fps'])
                 for i in range(first, first+count)]
    ends, elapsed = [], 0
    with Image.open(path) as encoded:
        if encoded.size != (SPEC['size'], SPEC['size']*len(RAW_PLANES)):
            raise ValueError('Incorrect packed frame size: '+path.name)
        for index in range(encoded.n_frames):
            encoded.seek(index)
            encoded.load()
            elapsed += encoded.info.get('duration', 0)
            ends.append(elapsed)
        if encoded.n_frames == 1:
            ends = [sum(durations)]
        elif elapsed != sum(durations):
            raise ValueError('Encoded segment duration mismatch: '+path.name)
    mapping = [next(j for j, end in enumerate(ends) if sum(durations[:i]) < end)
               for i in range(count)]
    return dict(asset=path.name, firstFrame=first, frameCount=count,
                decodedFrameCount=len(ends), sampleFrames=mapping)


def encode_segment(frame_dir, first, last, destination, options=None):
    """Encode from original renders; publish only a completely decoded file."""
    options = dict(WEBP_OPTIONS if options is None else options)
    if options.get('quality') != 90 or options.get('method') not in range(7):
        raise ValueError('Companion encoding requires quality 90 and method 0–6')
    temporary = destination.with_name(destination.name+'.partial')
    frames = []
    try:
        for i in range(first, last):
            frames.append(packed(frame_dir, i))
        durations = [round((i+1)*1000/SPEC['fps'])-round(i*1000/SPEC['fps'])
                     for i in range(first, last)]
        frames[0].save(temporary, format='WEBP', save_all=True,
                       append_images=frames[1:], duration=durations, loop=0,
                       **options)
        metadata = segment_metadata(temporary, first, last-first)
        temporary.replace(destination)
        metadata['asset'] = destination.name
        return metadata
    finally:
        for frame in frames:
            frame.close()
        temporary.unlink(missing_ok=True)


def pack_clip(outfit, clip, index_only=False):
    definition = SPEC['clips'][clip]
    count = round(definition['durationMs'] * SPEC['fps'] / 1000)
    frame_dir = FRAMES / outfit / clip

    def pack_segment(first):
        last = min(count, first + SPEC['segmentFrames'])
        path = DEST / f"{outfit}-{clip}-{first // SPEC['segmentFrames']:03d}.webp"
        if index_only:
            if path.stat().st_mtime_ns < (frame_dir/'source.sha256').stat().st_mtime_ns:
                raise ValueError('Packed clip predates its source render: '+path.name)
            return segment_metadata(path, first, last-first)
        require_headroom()
        return encode_segment(frame_dir, first, last, path)

    with ThreadPoolExecutor(max_workers=PACK_WORKERS) as workers:
        outputs = list(workers.map(pack_segment, range(0, count, SPEC['segmentFrames'])))
    return {'frameCount': count, 'segments': outputs}


def required_assets(manifest):
    required = {'items.png'}
    for outfit, clips in manifest['outfits'].items():
        required.add(outfit + '-poster.webp')
        for clip in clips.values():
            required.update(segment['asset'] for segment in clip['segments'])
    return required


def validate_inventory(root, required):
    expected = set(required) | {'manifest.json'}
    actual = {p.name for p in root.iterdir()}
    if actual != expected or any(not p.is_file() or p.is_symlink() for p in root.iterdir()):
        raise ValueError('Companion inventory mismatch; extra=' + str(sorted(actual - expected)) +
                         ', missing=' + str(sorted(expected - actual)))


def validate_manifest(manifest, reward_metadata=True):
    if any(manifest.get(key) != value for key, value in SPEC.items()):
        raise ValueError('Foal manifest disagrees with the authoring contract')
    if reward_metadata and (manifest.get('palette') != PALETTE or manifest.get('itemIds') != [item[0] for item in ITEMS]):
        raise ValueError('Reward palette or atlas mismatch')
    outfits = {h+'-'+w for h in SPEC['headwear'] for w in SPEC['wings']}
    if set(manifest['outfits']) != outfits:
        raise ValueError('Incomplete foal outfits')
    required = {'items.png'}
    for outfit, clips in manifest['outfits'].items():
        required.add(outfit+'-poster.webp')
        if set(clips) != set(SPEC['clips']):
            raise ValueError('Incomplete foal actions: '+outfit)
        for clip, metadata in clips.items():
            count = round(SPEC['clips'][clip]['durationMs'] * SPEC['fps'] / 1000)
            segments = metadata['segments']
            if metadata['frameCount'] != count or len(segments) != (count+14)//15:
                raise ValueError('Incomplete foal samples: '+outfit+'-'+clip)
            for i, segment in enumerate(segments):
                length = min(15, count-i*15)
                name = f'{outfit}-{clip}-{i:03d}.webp'
                decoded = segment['decodedFrameCount']
                mapping = segment['sampleFrames']
                if (segment['asset'] != name or segment['firstFrame'] != i*15 or
                    segment['frameCount'] != length or not 1 <= decoded <= length or
                    len(mapping) != length or mapping[0] != 0 or mapping[-1] != decoded-1 or
                    any(b-a not in (0,1) for a,b in zip(mapping,mapping[1:]))):
                    raise ValueError('Invalid foal frame mapping: '+name)
                required.add(name)
    if set(manifest['checksums']) != required:
        raise ValueError('Unverified or unreferenced foal assets')


def verify(reward_metadata=True):
    manifest = json.loads((DEST / "manifest.json").read_text())
    if manifest["sourceHash"] != source_hash():
        raise ValueError("Foal source changed: run the explicit exporter")
    validate_manifest(manifest, reward_metadata=reward_metadata)
    validate_inventory(DEST, required_assets(manifest))
    for name, expected in manifest["checksums"].items():
        if sha(DEST / name) != expected:
            raise ValueError("Foal asset checksum mismatch: " + name)
    print(f"Verified {len(manifest['checksums'])} rigged foal assets")


def pack_items():
    from PIL import Image
    if (FRAMES/"icons/source.sha256").read_text().strip() != source_hash():
        raise ValueError("Stale equipment icon source")
    atlas = Image.new('RGBA', (768, ((len(ITEMS)+2)//3)*256))
    for i, (item, geometry, mask_name, tint) in enumerate(ITEMS):
        if geometry is not None:
            folder = FRAMES/'icons'/geometry
            path = folder/'color-0000.png'
        else:
            folder = FRAMES/'none-none'/item
            if (folder/'source.sha256').read_text().strip() != source_hash():
                raise ValueError('Stale behavior preview source: '+item)
            frame = round(SPEC['clips'][item]['durationMs']*60/1000)//2
            path = folder/f'color-{frame:04d}.png'
        with Image.open(path) as source:
            thumb = source.convert('RGBA')
            bounds = thumb.getbbox() if geometry is not None else (0,0,*thumb.size)
            if bounds is None:
                raise ValueError('Empty reward icon: '+item)
            cropped = thumb.crop(bounds)
            thumb.close()
            thumb = cropped
            if tint is not None:
                with Image.open(folder/(mask_name+'-0000.png')) as source_mask:
                    mask = source_mask.convert('L').crop(bounds)
                    tint_icon(thumb, mask, tint)
                    mask.close()
            thumb.thumbnail((236,236), Image.Resampling.LANCZOS)
            atlas.paste(thumb, (i%3*256+(256-thumb.width)//2,
                               i//3*256+(256-thumb.height)//2))
            thumb.close()
    atlas.save(DEST/'items.png')
    atlas.close()


def main():
    global DEST, FRAMES, PACK_WORKERS, BLENDER_THREADS, MIN_AVAILABLE_GIB, WEBP_OPTIONS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dest", type=Path, default=DEST)
    parser.add_argument("--frames-root", type=Path, default=FRAMES)
    parser.add_argument("--log-root", type=Path, default=ROOT/"artifacts/foal-3d/logs")
    parser.add_argument("--blender", default="/usr/bin/blender")
    parser.add_argument("--pack-workers", type=int, choices=range(1,5), default=1)
    parser.add_argument("--blender-threads", type=int, choices=range(1,9), default=2)
    parser.add_argument("--min-available-gib", type=int, default=8)
    parser.add_argument("--webp-method", type=int, choices=range(7), default=1)
    parser.add_argument("--minimize-size", action="store_true")
    parser.add_argument("--allow-mixed", action="store_true")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--review", action="store_true")
    parser.add_argument("--outfit")
    parser.add_argument("--clip")
    parser.add_argument("--pack-only", action="store_true")
    parser.add_argument('--items-only', action='store_true',
        help='Refresh static item/behavior pictures from completed source renders')
    parser.add_argument("--index-only", action="store_true",
        help="Recover a full manifest and static atlas without rendering or recompressing animation clips")
    args = parser.parse_args()
    DEST, FRAMES = args.dest.resolve(), args.frames_root.resolve()
    PACK_WORKERS, BLENDER_THREADS = args.pack_workers, args.blender_threads
    WEBP_OPTIONS = dict(lossless=False, quality=90, method=args.webp_method,
                        minimize_size=args.minimize_size, allow_mixed=args.allow_mixed)
    MIN_AVAILABLE_GIB = args.min_available_gib
    if MIN_AVAILABLE_GIB < 1: parser.error("Keep at least one GiB of host headroom")
    if args.verify:
        verify()
        return
    if args.items_only:
        verify(reward_metadata=False)
        pack_items()
        manifest = json.loads((DEST/'manifest.json').read_text())
        manifest['checksums']['items.png'] = sha(DEST/'items.png')
        manifest['palette'] = PALETTE
        manifest['itemIds'] = [item[0] for item in ITEMS]
        (DEST/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
        verify()
        return
    if args.index_only and (args.outfit or args.clip or args.review or args.pack_only):
        parser.error('--index-only requires the complete library and no other export mode')
    from PIL import Image
    DEST.mkdir(parents=True, exist_ok=True)
    log_dir = args.log_root.resolve()
    log_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    manifest = {**SPEC, "sourceHash": source_hash(), "blender": "4.0.2",
                "outfits": {}, "checksums": {}, "palette": PALETTE, "itemIds": [item[0] for item in ITEMS]}
    if not args.index_only and not args.outfit and not args.clip and not args.review:
        if not args.pack_only:
            command=[args.blender,'--background',str(SOURCE/'gentle_foal.blend'),
                '--threads',str(BLENDER_THREADS),'--python-exit-code','1','--python',str(SOURCE/'render_frames.py'),
                '--','--root',str(FRAMES),'--icons']
            with (log_dir/'icons.log').open('w') as log:
                run_blender(command,log)
            (FRAMES/"icons/source.sha256").write_text(manifest["sourceHash"] + "\n")
    for head in SPEC["headwear"]:
        for wing in SPEC["wings"]:
            outfit = head + "-" + wing
            if args.outfit and outfit != args.outfit:
                continue
            manifest["outfits"][outfit] = {}
            for clip in SPEC["clips"]:
                if args.clip and clip != args.clip:
                    continue
                print("Index" if args.index_only else "Export", outfit, clip, flush=True)
                frame_dir = FRAMES / outfit / clip
                count = round(SPEC["clips"][clip]["durationMs"] * 60 / 1000)
                stamp = frame_dir / "source.sha256"
                complete = stamp.is_file() and stamp.read_text().strip() == manifest["sourceHash"] and all((frame_dir / f"{kind}-{i:04d}.png").is_file()
                               for i in range(count) for kind in RAW_PLANES)
                if (args.index_only or args.pack_only) and not complete:
                    raise ValueError('Missing or stale raw source stamp: '+outfit+'-'+clip)
                if not (args.pack_only or args.index_only) and (args.review or not complete):
                    command = [args.blender, "--background", str(SOURCE / "gentle_foal.blend"),
                        "--threads", str(BLENDER_THREADS), "--python-exit-code", "1", "--python",
                        str(SOURCE / "render_frames.py"), "--", "--root", str(FRAMES),
                        "--headwear", head, "--wings", wing, "--clip", clip]
                    if args.review:
                        command.append("--review")
                    with (log_dir / f"{outfit}-{clip}.log").open("w") as log:
                        run_blender(command,log)
                    if not args.review:
                        stamp.write_text(manifest["sourceHash"] + "\n")
                if args.review:
                    continue
                require_headroom()
                manifest["outfits"][outfit][clip] = pack_clip(outfit, clip, args.index_only)
                if args.index_only and clip == 'idle':
                    if (DEST/f'{outfit}-poster.webp').stat().st_mtime_ns < stamp.stat().st_mtime_ns:
                        raise ValueError('Poster predates its source render: '+outfit)
                if clip == "idle" and not args.index_only:
                    p = packed(frame_dir, 0)
                    p.save(DEST / f"{outfit}-poster.webp", lossless=True, method=6)
                    p.close()
    if not args.review and not args.outfit and not args.clip:
        pack_items()
        for name in sorted(required_assets(manifest)):
            manifest["checksums"][name] = sha(DEST/name)
        (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        verify()


if __name__ == "__main__":
    main()
