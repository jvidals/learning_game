#!/usr/bin/env python3
"""Render the checked-in offline hint pictures from the local Noto emoji font.

Authoring only: normal builds reuse and verify the PNGs. Pillow is not an app
dependency. Keep the accompanying source copyright/license with the pictures.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, default=Path('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'))
    parser.add_argument('--license', type=Path, default=Path('/usr/share/doc/fonts-noto-color-emoji/copyright'))
    args = parser.parse_args()
    font = ImageFont.truetype(str(args.font), 109)
    out = ROOT / 'assets/phonics'
    out.mkdir(exist_ok=True)
    records = re.findall(r"LetterSound\('([^']+)', '([^']+)', '([^']+)', '([^']+)'\)",
                         (ROOT / 'lib/letter_sounds.dart').read_text())
    if len(records) != 24:
        raise ValueError('Expected the 24 supported basic letters')
    checksums = {}
    for letter, _, word, picture in records:
        canvas = Image.new('RGBA', (180, 180))
        ImageDraw.Draw(canvas).text((20, 0), picture, font=font, embedded_color=True)
        box = canvas.getbbox()
        if not box:
            raise ValueError('Missing picture: ' + word)
        glyph = canvas.crop(box)
        glyph.thumbnail((112, 112))
        result = Image.new('RGBA', (128, 128))
        result.alpha_composite(glyph, ((128 - glyph.width) // 2, (128 - glyph.height) // 2))
        path = out / (letter + '.png')
        result.save(path, optimize=True)
        checksums[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    shutil.copy2(args.license, out / 'LICENSE.txt')
    checksums['LICENSE.txt'] = hashlib.sha256((out / 'LICENSE.txt').read_bytes()).hexdigest()
    (out / 'manifest.json').write_text(json.dumps({
        'source': 'Noto Color Emoji, Google / Arjen Nienhuis; rendered with installed font at 109 px, padded to 128 px',
        'checksums': checksums,
    }, indent=2) + '\n')
    print(f'Rendered {len(records)} bundled hint pictures')


if __name__ == '__main__':
    main()
