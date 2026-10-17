"""Read-only sample audit of a completed reward export; never regenerates art."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets', type=Path, required=True)
    parser.add_argument('--frames', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((args.assets/'manifest.json').read_text())
    size = manifest['size']
    planes = ('color', 'mask', 'hooves', 'headwear', 'wings')
    report = {'outfits': {}, 'samples': 0, 'maxMaskBeyondColorAlpha': 0}
    for outfit, clips in manifest['outfits'].items():
        totals = [0]*4
        for clip, metadata in clips.items():
            count = metadata['frameCount']
            for sample in sorted({0, count//5, count*2//5, count*3//5, count*4//5, count-1}):
                segment = metadata['segments'][sample//manifest['segmentFrames']]
                decoded = segment['sampleFrames'][sample-segment['firstFrame']]
                with Image.open(args.assets/segment['asset']) as packed:
                    packed.seek(decoded)
                    alpha = packed.convert('RGBA').getchannel('A')
                folder = args.frames/outfit/clip
                original_alpha = None
                try:
                    for plane, name in enumerate(planes):
                        with Image.open(folder/f'{name}-{sample:04d}.png') as original:
                            expected = original.getchannel('A') if plane == 0 else original.convert('L')
                        actual = alpha.crop((0, plane*size, size, (plane+1)*size))
                        try:
                            difference = ImageChops.difference(actual, expected)
                            try:
                                if difference.getbbox():
                                    raise ValueError(f'Lossless alpha mismatch: {outfit}/{clip}/{sample}/{name}')
                            finally:
                                difference.close()
                            if plane == 0:
                                original_alpha = expected.copy()
                                bounds = expected.getbbox()
                                if not bounds or min(bounds) < 2 or bounds[2] > size-2 or bounds[3] > size-2:
                                    raise ValueError(f'Clipped or empty pose: {outfit}/{clip}/{sample}')
                            else:
                                totals[plane-1] += sum(expected.histogram()[1:])
                                excess = ImageChops.subtract(expected, original_alpha)
                                report['maxMaskBeyondColorAlpha'] = max(report['maxMaskBeyondColorAlpha'], excess.getextrema()[1])
                                excess.close()
                        finally:
                            actual.close()
                            expected.close()
                finally:
                    alpha.close()
                    if original_alpha is not None:
                        original_alpha.close()
                report['samples'] += 1
        if min(totals[:2]) <= 0:
            raise ValueError('Missing hair or hoof coverage: '+outfit)
        head, wing = outfit.split('-')
        if (head in ('flower','bow')) != (totals[2] > 0):
            raise ValueError('Incorrect headwear recolor coverage: '+outfit)
        if (wing in ('feather','butterfly')) != (totals[3] > 0):
            raise ValueError('Incorrect wing recolor coverage: '+outfit)
        report['outfits'][outfit] = dict(zip(planes[1:], totals))
        print('Verified sampled alpha, masks and bounds:', outfit, flush=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'samples': report['samples'], 'outfits': len(report['outfits']), 'maxEdgeExcess': report['maxMaskBeyondColorAlpha']}))

if __name__ == '__main__':
    main()
