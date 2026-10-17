# Companion artwork

## Current artwork and retained studies

The game uses the approved revision-five **Playful Spark** Blender model, with
later reward additions and the compressed 0.18.2 animation library. The editable
master, required references and current bundled assets are unchanged.
[Production authoring guide](../art/foal/README.md) ·
[Retained brainstorming and review images](../art/foal/archive/README.md).

The **2026-10-03 cleanup** removed all raw renders, superseded exports/models,
old APKs, rejected 2D iterations and project build caches. Exact prompts, source
history, compact reports and documentation screenshots remain. Future artwork
exports need a fresh render; normal builds use the existing bundled assets.
[Cleanup inventory and validation](../artifacts/workspace-cleanup-20261003/README.md).

Adventure scenery was retired in 0.17.0. Its original image files and backup
copies have now been removed; the exact prompts below and historical screenshots
remain. Tap Challenge uses native Flutter drawings with swappable companion skins.

## Historical rigged Gentle foal (0.9.0)

The 0.9.0 companion came from an editable Blender scene, with softly shaded
3D forms based on the Gentle foal reference. Shoulder-rooted wings sweep
rearwards, headwear follows the head bone, and the bow uses a backward-folding
foreleg with grounded support. A complete turn renders the same geometry and
attachments at every angle; there are no separately positioned turn cutouts.

[Source, authoring commands and bundled format](../art/foal/README.md) describe
the rig, action durations, transparent color/hair-mask frames and bounded
Flutter playback. The current `.blend` and scripts remain on the development computer; raw
renders were removed. Only offline WebP clips, posters, item art and the shader ship.
Normal tests/builds verify the existing export rather than regenerating it.

## Historical Gentle foal 2D art (0.8.0)

The selected **B — Gentle foal** replaced the original vector companion in 0.8.0.
Its [master, equipment, prompts and rig metadata](../output/imagegen/gentle-foal-production/README.md)
and [screen gallery](screenshots/080/README.md) remain as historical references.
Other 2D assets and demo exports have been removed. This renderer was later
superseded by rigged 3D art; future companion selection remains separate work.

## Historical Adventure scenery prompts

Generated on 2026-09-14 with the built-in image-generation tool, one call per environment. The original PNGs were formerly bundled under `assets/scenery/`; those files have been retired and removed. These are full-bleed 1024×1536 paintings. Flutter draws the paths, markers, labels, controls, glints and companion separately. Decode widths are bounded for phone/tablet memory use.

All four prompts begin with:

> Use case: illustration-story. Asset type: portrait background for Rainbow Garden, an offline kindergarten unicorn adventure board. Soft coordinated storybook gouache, clean rounded shapes, pastel mint, peach, lilac and gold, warm gentle light, polished children's book illustration. Composition: 1024x1536 portrait, full bleed scenery, spacious low-detail center for overlay path and two destinations. No characters, no unicorn, no text, no UI, no markers, no borders, no watermark.

The following environment sentence completes each prompt:

| Final asset | Environment sentence |
| --- | --- |
| `assets/scenery/meadow.png` | Environment: sunlit meadow with softly rolling green hills, small wildflowers clustered at edges, fluffy clouds and distant rainbow. |
| `assets/scenery/stream.png` | Environment: a gentle turquoise stream curving through grassy banks, tiny bubbles over water, smooth stones, a distant small rainbow over the water, flowers at edges. |
| `assets/scenery/woodland.png` | Environment: welcoming twilight woodland clearing, rounded lilac and sage trees framing edges, small golden fireflies, soft crescent moon, open pale lavender grass center. Gentle and magical, never dark or frightening. |
| `assets/scenery/castle.png` | Environment: floating cloud harbor and a small friendly fairytale star castle in the upper distance, peach and lilac cloud islands, soft blue sky, tiny golden stars. Spacious creamy clouds in center foreground. |

The four generated paintings were visually inspected: coordinated palette, no embedded labels or controls, clean full-bleed edges, and sufficient space for the board overlay. Screen-level inspection is recorded in `docs/testing.md`.

Before 0.8.0, `lib/companion.dart` implemented reusable vector layers for body, tail/mane, wings, head, expression and accessories. Later renderers preserved the familiar static rainbow during learning rounds. The starting mane is pink; collected colors, headwear and wings use the existing pastel palette. That earlier vector character is now superseded by the Gentle foal raster artwork above.

## Companion concept studies

The user selected **shaded cartoon** from the [three initial style sheets](../output/imagegen/unicorn-style-study/README.md). Four [shaded-cartoon character candidates](../output/imagegen/unicorn-shaded-variants/README.md) now compare a rounded pony, a gentle foal, a flowing mane and simpler shapes. Each includes a default body, a dressed version, a portrait and a first-step pose. Their prompts, comparison notes and checksums are saved alongside the PNGs.

The user initially selected B — Gentle foal, then later approved Playful Spark. These earlier studies remain comparison references; they are not the current production model. The future dinosaur will be a separate companion using the same visual language with its own anatomy.
