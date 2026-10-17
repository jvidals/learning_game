#!/usr/bin/env python3
"""Render the checked-in reading-game pictures from the local Noto emoji font.

Authoring only: normal builds reuse and verify the PNGs. Pillow is not an app
dependency. Pictures come from `realWords` in lib/word_bank.dart; keep the
accompanying source copyright/license with the pictures.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SIZE = 192


def records():
    source = (ROOT / 'lib/word_bank.dart').read_text()
    found = re.findall(r"DecodableWord\('([a-z]{3})', picture: '([^']+)', label: '[^']+'\)", source)
    if len(found) < 24 or len({word for word, _ in found}) != len(found):
        raise ValueError('Expected unique real words with pictures')
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, default=Path('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'))
    parser.add_argument('--license', type=Path, default=Path('/usr/share/doc/fonts-noto-color-emoji/copyright'))
    args = parser.parse_args()
    font = ImageFont.truetype(str(args.font), 109)
    out = ROOT / 'assets/words'
    out.mkdir(exist_ok=True)
    checksums = {}
    for word, picture in records():
        canvas = Image.new('RGBA', (180, 180))
        ImageDraw.Draw(canvas).text((20, 0), picture, font=font, embedded_color=True)
        box = canvas.getbbox()
        if not box:
            raise ValueError('Missing picture: ' + word)
        glyph = canvas.crop(box)
        # Noto's tofu box is monochrome; every real emoji glyph has colour.
        if len(glyph.convert('RGB').getcolors(maxcolors=1 << 24) or ()) < 8:
            raise ValueError('Font lacks a colour glyph for: ' + word)
        glyph = glyph.resize((round(glyph.width * 168 / max(glyph.size)),
                              round(glyph.height * 168 / max(glyph.size))), Image.LANCZOS)
        result = Image.new('RGBA', (SIZE, SIZE))
        result.alpha_composite(glyph, ((SIZE - glyph.width) // 2, (SIZE - glyph.height) // 2))
        path = out / (word + '.png')
        result.save(path, optimize=True)
        checksums[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    shutil.copy2(args.license, out / 'LICENSE.txt')
    checksums['LICENSE.txt'] = hashlib.sha256((out / 'LICENSE.txt').read_bytes()).hexdigest()
    (out / 'manifest.json').write_text(json.dumps({
        'source': f'Noto Color Emoji, Google / Arjen Nienhuis; rendered with installed font at 109 px, scaled to {SIZE} px',
        'checksums': checksums,
    }, indent=2) + '\n')
    print(f'Rendered {len(checksums) - 1} pictures to {out}')


if __name__ == '__main__':
    main()
