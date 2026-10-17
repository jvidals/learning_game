"""Static reward pictures and their source geometry/tint, in atlas order."""
import json
from pathlib import Path

PALETTE = json.loads((Path(__file__).resolve().parents[1] / 'art/foal/reward_palette.json').read_text())
ITEMS = [
    ('flower', 'flower', None, None), ('bow', 'bow', None, None),
    ('star', 'star', None, None), ('heart', 'heart', None, None),
    ('flower_lavender', 'flower', 'headwear', 'lavender'),
    ('bow_coral', 'bow', 'headwear', 'coral'),
    ('feather', 'feather', None, None), ('butterfly', 'butterfly', None, None),
    ('rainbow', 'rainbow', None, None), ('fairy', 'fairy', None, None),
    ('feather_mint', 'feather', 'wings', 'mint'),
    ('butterfly_lavender', 'butterfly', 'wings', 'lavender'),
    ('simple', None, None, None), ('hop', None, None, None),
    ('bowing', None, None, None), ('twirl', None, None, None),
    ('polish_none', 'hoof', None, None),
    *[('polish_' + color, 'hoof', 'hooves', color) for color in PALETTE],
]

def tint_icon(image, mask, color):
    """Match the runtime apparel shader; alpha and contrasting details survive."""
    tint = [int(PALETTE[color][i:i+2], 16)/255 for i in (0,2,4)]
    pixels = image.load()
    masks = mask.load()
    for y in range(image.height):
        for x in range(image.width):
            r,g,b,a = pixels[x,y]
            if not a or not masks[x,y]:
                continue
            weight = min(1, masks[x,y]/a)
            rgb = [r/255,g/255,b/255]
            luma = sum(v*w for v,w in zip(rgb,(.2126,.7152,.0722)))
            highlight = max(0,min(1,(luma-.88)/.12))
            highlight = highlight*highlight*(3-2*highlight)*.25
            shaded = [min(1,v*(.45+.65*luma))*(1-highlight)+highlight for v in tint]
            pixels[x,y] = (*[round(255*(v*(1-weight)+s*weight)) for v,s in zip(rgb,shaded)],a)
