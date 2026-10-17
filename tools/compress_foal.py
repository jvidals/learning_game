"""Offline, resumable compression experiment using original foal renders.

Keeps resolution, sampling, quality 90 and lossless coverage. State and logs
live outside the exact bundled inventory. Never publishes production assets.
"""
import argparse
import copy
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import resource
import shutil
import signal
import tarfile
import time
from concurrent.futures import ProcessPoolExecutor, wait, FIRST_COMPLETED

from PIL import Image, ImageChops, features
import numpy as np
import export_foal as foal

PROFILES = {'baseline': dict(lossless=False, quality=90, method=1,
                             minimize_size=False, allow_mixed=False)}
for method in (4, 6):
    for small in (False, True):
        for mixed in (False, True):
            name = f'm{method}' + ('-small' if small else '') + ('-mixed' if mixed else '')
            PROFILES[name] = dict(lossless=False, quality=90, method=method,
                                  minimize_size=small, allow_mixed=mixed)


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix('.json.partial')
    temp.write_text(json.dumps(value, indent=2)+'\n')
    temp.replace(path)


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def source_provenance(baseline, frames, prior_path=None, archive_path=None):
    manifest = json.loads((baseline/'manifest.json').read_text())
    foal.validate_manifest(manifest)
    foal.validate_inventory(baseline, foal.required_assets(manifest))
    if manifest['sourceHash'] != foal.source_hash():
        raise ValueError('Current source no longer matches baseline')
    for name, digest in manifest['checksums'].items():
        if foal.sha(baseline/name) != digest:
            raise ValueError('Baseline checksum mismatch: '+name)
    raw_hash = manifest['sourceHash']
    if prior_path:
        prior = json.loads(prior_path.read_text())
        # An explicitly supplied historical manifest may describe a superset
        # pruned from production. Every retained clip and asset must match.
        for key in ('fps', 'size', 'segmentFrames', 'packedPlanes', 'framing', 'headwear', 'wings'):
            if manifest[key] != prior[key]:
                raise ValueError('Historical render contract differs: '+key)
        for clip, definition in manifest['clips'].items():
            if definition != prior['clips'].get(clip):
                raise ValueError('Retained animation changed: '+clip)
        for outfit, clips in manifest['outfits'].items():
            for clip, metadata in clips.items():
                if metadata != prior['outfits'][outfit][clip]:
                    raise ValueError('Historical clip differs: '+outfit+'-'+clip)
        for name, digest in manifest['checksums'].items():
            if prior['checksums'].get(name) != digest:
                raise ValueError('Historical retained asset differs: '+name)
        if not archive_path:
            raise ValueError('Historical provenance requires the source archive')
        with tarfile.open(archive_path) as archive:
            names = set(archive.getnames())
            h = hashlib.sha256()
            for name in ('animation_spec.json', 'build_model.py', 'rig_source.py',
                         'gentle_foal.blend', 'render_frames.py', 'rewards.py'):
                key = 'art/foal/'+name
                data = archive.extractfile(key).read() if key in names else (foal.SOURCE/name).read_bytes()
                h.update(name.encode())
                h.update(hashlib.sha256(data).digest())
        raw_hash = prior['sourceHash']
        if h.hexdigest() != raw_hash:
            raise ValueError('Cannot reconstruct historical source fingerprint')
    for outfit, clips in manifest['outfits'].items():
        for clip, info in clips.items():
            folder = frames/outfit/clip
            if (folder/'source.sha256').read_text().strip() != raw_hash:
                raise ValueError('Stale raw renders: '+str(folder))
            for i in range(info['frameCount']):
                for plane in foal.RAW_PLANES:
                    if not (folder/f'{plane}-{i:04d}.png').is_file():
                        raise ValueError('Missing source render')
    return manifest, raw_hash


def input_fingerprint(folder, first, count, profile, raw_hash, baseline_digest):
    h = hashlib.sha256()
    for i in range(first, first+count):
        for plane in foal.RAW_PLANES:
            path = folder/f'{plane}-{i:04d}.png'
            h.update(path.name.encode())
            h.update(bytes.fromhex(foal.sha(path)))
    return fingerprint(dict(raw_hash=raw_hash, renders=h.hexdigest(),
                            source=foal.source_hash(), options=PROFILES[profile],
                            pillow=Image.__version__, webp=features.version('webp'),
                            exporter=foal.sha(Path(foal.__file__)),
                            runner=foal.sha(Path(__file__)), baseline=baseline_digest))


def resume_record(state, destination, identity):
    if not state.is_file() or not destination.is_file():
        return None
    try:
        record = json.loads(state.read_text())
        if record['identity'] == identity and record['sha256'] == foal.sha(destination):
            return record
    except (ValueError, KeyError, OSError):
        pass
    return None


def audit_segment(folder, candidate, baseline, metadata, old_metadata):
    """All authored samples: exact alpha/masks and source-relative RGB error."""
    side = foal.SPEC['size']
    error = old_error = pixels = 0.0
    worst = dict(delta=-float('inf'), frame=None)
    start = time.monotonic()
    with Image.open(candidate) as new, Image.open(baseline) as old:
        for sample in range(metadata['frameCount']):
            index = metadata['firstFrame']+sample
            new.seek(metadata['sampleFrames'][sample]); new.load()
            old.seek(old_metadata['sampleFrames'][sample]); old.load()
            expected = foal.packed(folder, index)
            try:
                alpha = new.getchannel('A')
                source_alpha = expected.getchannel('A')
                difference = ImageChops.difference(alpha, source_alpha)
                if difference.getbbox() is not None:
                    raise ValueError(f'Coverage changed: {candidate.name} sample {index}')
                alpha.close(); source_alpha.close(); difference.close()
                rect = (0, 0, side, side)
                images = [im.crop(rect) for im in (expected, new, old)]
                arrays = [np.asarray(im, dtype=np.float32) for im in images]
                weight = arrays[0][:, :, 3:4]/255.0
                n = float(np.sum(np.square((arrays[1][:, :, :3]-arrays[0][:, :, :3])*weight), dtype=np.float64))
                b = float(np.sum(np.square((arrays[2][:, :, :3]-arrays[0][:, :, :3])*weight), dtype=np.float64))
                px = max(1, int(np.count_nonzero(weight))*3)
                error += n; old_error += b; pixels += px
                delta = math.sqrt(n/px)-math.sqrt(b/px)
                if delta > worst['delta']:
                    worst = dict(delta=delta, frame=index,
                                 rms=math.sqrt(n/px), baseline_rms=math.sqrt(b/px))
                for im in images: im.close()
            finally:
                expected.close()
    return dict(samples=metadata['frameCount'], coverage_exact=True,
                squared_error=error, baseline_squared_error=old_error,
                visible_channels=pixels, worst=worst,
                audit_seconds=time.monotonic()-start)


def process_segment(job):
    start = time.monotonic()
    folder = Path(job['frames'])/job['outfit']/job['clip']
    old = job['metadata']; name = old['asset']
    target = Path(job['root'])/job['profile']/'assets'/name
    state = Path(job['root'])/job['profile']/'state'/(name+'.json')
    target.parent.mkdir(parents=True, exist_ok=True)
    identity = input_fingerprint(folder, old['firstFrame'], old['frameCount'],
                                 job['profile'], job['raw_hash'], job['baseline_digest'])
    previous = resume_record(state, target, identity)
    if previous:
        return dict(previous, resumed=True)
    foal.require_headroom()
    encode_start = time.monotonic()
    metadata = foal.encode_segment(folder, old['firstFrame'],
                                  old['firstFrame']+old['frameCount'], target,
                                  PROFILES[job['profile']])
    encoded = time.monotonic()-encode_start
    audit = audit_segment(folder, target, Path(job['baseline'])/name, metadata, old)
    result = dict(asset=name, profile=job['profile'], identity=identity,
                  sha256=foal.sha(target), bytes=target.stat().st_size,
                  baseline_bytes=(Path(job['baseline'])/name).stat().st_size,
                  metadata=metadata, encode_seconds=encoded, audit=audit,
                  elapsed_seconds=time.monotonic()-start,
                  peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
    atomic_json(state, result)
    return result


def segments(manifest):
    return [dict(outfit=o, clip=c, metadata=s)
            for o, clips in manifest['outfits'].items()
            for c, info in clips.items() for s in info['segments']]


def sample_segments(manifest):
    result = []
    actions = list(manifest['clips'])
    for i, (outfit, clips) in enumerate(manifest['outfits'].items()):
        clip = actions[i % len(actions)]
        items = clips[clip]['segments']
        result.append(dict(outfit=outfit, clip=clip, metadata=items[len(items)//2]))
    # Held idle, a boundary and fast/decorated movement in addition to all outfits.
    for outfit, clip, index in [('none-none', 'idle', 0), ('none-none', 'happy', -1),
                                ('heart-fairy', 'twirl', 3), ('flower-feather', 'idle', 12)]:
        item = dict(outfit=outfit, clip=clip, metadata=manifest['outfits'][outfit][clip]['segments'][index])
        if item not in result: result.append(item)
    return result


def summarize(results):
    summary = {}
    for profile in sorted({r['profile'] for r in results}):
        rows = [r for r in results if r['profile']==profile]
        size = sum(r['bytes'] for r in rows); old = sum(r['baseline_bytes'] for r in rows)
        pixels = sum(r['audit']['visible_channels'] for r in rows)
        summary[profile] = dict(segments=len(rows), bytes=size, baseline_bytes=old,
            saved_percent=100*(old-size)/old,
            source_rms=math.sqrt(sum(r['audit']['squared_error'] for r in rows)/pixels),
            baseline_source_rms=math.sqrt(sum(r['audit']['baseline_squared_error'] for r in rows)/pixels),
            encode_seconds=sum(r['encode_seconds'] for r in rows),
            peak_worker_rss_kib=max(r['peak_rss_kib'] for r in rows),
            worst=max((dict(r['audit']['worst'], asset=r['asset']) for r in rows), key=lambda x:x['delta']))
    return summary


def run_jobs(jobs, workers, root, min_gib):
    results = []; start = last_log = time.monotonic()
    pending = {}; remaining = iter(jobs)
    pool = ProcessPoolExecutor(max_workers=workers)
    try:
        while True:
            if foal.available_bytes() < min_gib*1024**3:
                raise MemoryError('Paused packing: available RAM below headroom; resume verified segments')
            while len(pending) < workers:
                job = next(remaining, None)
                if job is None: break
                pending[pool.submit(process_segment, job)] = job
            if not pending: break
            done, _ = wait(pending, timeout=5, return_when=FIRST_COMPLETED)
            for future in done:
                pending.pop(future); results.append(future.result())
            now = time.monotonic()
            if now-last_log >= 30 or not pending:
                eta = (now-start)/len(results)*(len(jobs)-len(results)) if results else None
                status = dict(completed=len(results), total=len(jobs), workers=workers,
                              elapsed_seconds=now-start, eta_seconds=eta,
                              available_gib=foal.available_bytes()/1024**3)
                atomic_json(root/'progress.json', status)
                print(json.dumps(status), flush=True); last_log=now
    except BaseException:
        # Stop only our workers; never keep queued work alive after failure.
        for process in list(pool._processes.values()):
            process.terminate()
        pool.shutdown(wait=True, cancel_futures=True)
        raise
    else:
        pool.shutdown(wait=True)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=['benchmark', 'pack'], required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--frames-root', type=Path, required=True)
    parser.add_argument('--run-root', type=Path, required=True)
    parser.add_argument('--source-manifest', type=Path)
    parser.add_argument('--source-archive', type=Path)
    parser.add_argument('--profiles', default='m4,m4-mixed,m4-small,m4-small-mixed,m6,m6-mixed,m6-small,m6-small-mixed')
    parser.add_argument('--sample-limit', type=int)
    parser.add_argument('--workers', type=int, default=1)
    parser.add_argument('--min-available-gib', type=int, default=8)
    args = parser.parse_args()
    profiles = args.profiles.split(',')
    if any(p not in PROFILES for p in profiles) or (args.phase=='pack' and len(profiles)!=1):
        parser.error('Choose known profiles; full packing requires exactly one')
    if not 1 <= args.workers <= len(os.sched_getaffinity(0)) or args.min_available_gib < 8:
        parser.error('Workers must fit CPU affinity; preserve at least 8 GiB headroom')
    root = args.run_root.resolve(); baseline = args.baseline.resolve(); frames = args.frames_root.resolve()
    if root == foal.ROOT/'assets' or foal.ROOT/'assets' in root.parents or baseline == root or root in baseline.parents:
        parser.error('Run root must be separate from source and production assets')
    root.mkdir(parents=True, exist_ok=True)
    foal.MIN_AVAILABLE_GIB = args.min_available_gib
    with (root/'job.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        manifest, raw_hash = source_provenance(baseline, frames, args.source_manifest, args.source_archive)
        chosen = segments(manifest) if args.phase=='pack' else sample_segments(manifest)
        if args.sample_limit:
            if args.phase=='pack': parser.error('Cannot limit full-library packing')
            chosen = chosen[:args.sample_limit]
        jobs = [dict(s, profile=p, frames=str(frames), baseline=str(baseline), root=str(root),
                     raw_hash=raw_hash, baseline_digest=manifest['checksums'][s['metadata']['asset']])
                for s in chosen for p in profiles]
        atomic_json(root/'run.json', dict(phase=args.phase, profiles=profiles, options={p:PROFILES[p] for p in profiles},
                    source_hash=manifest['sourceHash'], raw_source_hash=raw_hash, workers=args.workers,
                    baseline_manifest_sha256=foal.sha(baseline/'manifest.json'),
                    pillow=Image.__version__, webp=features.version('webp'), jobs=len(jobs)))
        started=time.monotonic()
        results=run_jobs(jobs,args.workers,root,args.min_available_gib)
        report=dict(summary=summarize(results), elapsed_seconds=time.monotonic()-started, results=results)
        atomic_json(root/'report.json',report)
        print(json.dumps(report['summary'],indent=2),flush=True)
        if args.phase=='pack':
            profile=profiles[0]; target=root/profile/'assets'
            output=copy.deepcopy(manifest)
            metadata={r['asset']:r['metadata'] for r in results}
            for clips in output['outfits'].values():
                for clip in clips.values():
                    clip['segments']=[metadata[s['asset']] for s in clip['segments']]
            for name in manifest['checksums']:
                if name not in metadata: shutil.copy2(baseline/name,target/name)
            output['checksums']={name:foal.sha(target/name) for name in manifest['checksums']}
            foal.validate_manifest(output)
            atomic_json(target/'manifest.json',output)
            foal.validate_inventory(target,foal.required_assets(output))
            atomic_json(root/'complete.json',dict(profile=profile,assets=str(target),manifest_sha256=foal.sha(target/'manifest.json')))


if __name__=='__main__':
    main()
