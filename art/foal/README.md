# Playful Spark: editable 3D source

The approved revision-five character remains the production source in
`gentle_foal.blend`. Reward expansion adds a heart tiara and fairy wings;
the body, rig, facial parts and eight actions remain intact. Rebuild with
`build_model.py`, which imports `rig_source.py` and `rewards.py`.
Preserve manual scene edits before rebuilding. Historical scripts and required references remain outside bundled assets.
The 2026-10-03 cleanup removed raw frames, old model/APK copies and intermediate
exports. See the [retained artwork index](archive/README.md) and
[cleanup record](../../artifacts/workspace-cleanup-20261003/README.md).

## Rewards and coordinates

Forward is −X, left is −Y, and up is +Z. Headwear attaches to the head bone.
Wings attach at the shoulders and flow toward +X. Blender handles their
occlusion during every pose and turn. Flutter recolors rendered coverage;
it never positions separate crowns, wings or hooves.

`reward_palette.json` is the canonical seven-color palette: pink, blue,
mint, gold, lavender, coral and teal. Mane and nail polish use the same colors
but have independent ownership and equipment. The default pink mane retains its
original source shading; selectable mane tints and polish read palette metadata.
No polish restores the original
lavender hooves. All four hooves share a polish color.

The five headwear geometries and five wing geometries produce 25 rendered
outfits. Lavender flower petals, the coral bow, mint feather surfaces and
lavender butterfly membranes reuse geometry with material-specific masks.
Contrasting leaves, gold details, rims and pearls retain their source colors.
The heart tiara and fairy wings have their own geometry.

## Animation safeguards

`animation_spec.json` defines 60 Hz samples at 1024×1024 color resolution:
idle 8 s, happy 550 ms, simple/hop 1.4 s,
bow/twirl 2 s. Authoring includes loop endpoints; exports exclude the duplicate.

Idle retains the small lateral weight shift, head tilt, separate ear flicks,
tail swish and irregular blinks. All four hoof controls remain fixed. The
happy smile is reserved for triggered feedback. Forelegs use shoulder →
carpus → hoof chains. Bowing folds the left foreleg and plants the other
three hooves; preserve the IK rest-chain plane.

The saved-scene validator checks accepted body proportions, skin weights,
facial parts, bone attachments, grounded idle samples, IK and framing.
Inspect decoded art as well as geometric results: a passing rig does not
establish material appearance, mobile frame pacing or touch comfort.

## Memory-conscious authoring

This computer uses apt Blender 4.0.2 / EEVEE. The installed NVIDIA
580.178.04 user libraries and kernel now match, so `/usr/bin/blender`
works directly. The historical 0.12.0 wrapper pins older 580.173.02 libraries
and must not be reused on this host. No system driver was changed.
Pillow and libwebp are authoring dependencies only.

Rebuild and validate explicitly:

```bash
blender --background --factory-startup --threads 2 --python-exit-code 1 \
  --python art/foal/build_model.py
blender --background art/foal/gentle_foal.blend --threads 2 \
  --python-exit-code 1 --python art/foal/validate_model.py
```

Render into staging, with one Blender process, two render threads and one
packing worker. The exporter checks Linux MemAvailable before work and every
five seconds during Blender; below 8 GiB it stops its own render. Completed
clips remain resumable. A packing worker holds at most fifteen packed frames,
roughly 300 MiB before encoder overhead. Avoid overlapping APK builds,
emulators or capture suites with a full render.

```bash
python3 tools/export_foal_library.py \
  --dest artifacts/foal-authoring/staged-assets \
  --frames-root artifacts/foal-authoring/frames \
  --log-root artifacts/foal-authoring/logs \
  --blender /usr/bin/blender --workers 1 --blender-threads 2 \
  --pack-workers 1 --min-available-gib 8 \
  --webp-method 6 --minimize-size --allow-mixed
python3 tools/export_foal.py --verify \
  --dest artifacts/foal-authoring/staged-assets
```

The staging paths above are fresh output locations, not retained caches.
Run a normal render/export before attempting `--pack-only`, `--index-only`,
`--items-only` or a compression experiment. Ordinary APK builds still need no
rendering; they verify and reuse the complete bundled library.

Raw PNGs and source stamps never ship. Resume accepts complete clips only
when the scene and geometry source hashes match. `--pack-only` uses complete
raw renders; `--index-only` reconstructs the final manifest without rendering
or recompressing. Indexing rejects stale sources and packed files, decodes
every packed frame, checks timing and refreshes the static item atlas.
A partial outfit export cannot publish a complete manifest.

## Compression experiments and production recipe

The compression-only recipe is WebP **quality 90, method 6, minimize-size on,
allow-mixed on**, with unchanged 1024-pixel planes, 60 Hz authored samples and
15-sample segment boundaries. Pass `--webp-method 6 --minimize-size --allow-mixed`
to either export command when intentionally authoring new clips. Legacy method-1
CLI defaults remain available for reproducible baseline comparisons. Routine APK
builds still only verify the already-bundled library.

The 0.18.2 full-library pass reduced the 1,575 animated files by **43.29%**,
with all 23,025 authored samples passing exact transparency/material-coverage
checks. Static posters and the item atlas are unchanged. See the
[compression report](../../artifacts/companion-compression/README.md) for measured
quality, decoder timings, Android validation and reproducible commands.

`tools/compress_foal.py` benchmarks or repacks existing renders into a separate
staging directory. It never renders Blender scenes or replaces production assets.
It requires the existing authoring Pillow/libwebp tools plus NumPy for numerical
comparisons; none are runtime dependencies. The current host uses Pillow 10.2.0,
libwebp 1.3.2 and NumPy 2.2.6.

A run takes `--phase benchmark|pack`, `--baseline`, `--frames-root`, `--run-root`,
`--profiles`, `--workers` and an available-memory reserve of at least 8 GiB.
Benchmark defaults cover all 25 outfits and every active action. Full packing
requires one selected profile, for example `--profiles m6-small-mixed`.

Completed segments resume automatically only when original-render hashes,
source identity, encoding settings, tool/encoder versions and the output checksum
match. Each segment is encoded from original PNGs, decoded completely, and audited
at every authored sample against the original alpha and four material masks before
its checkpoint is committed. Color-error diagnostics compare both the candidate
and previous release against those same original renders. A job lock prevents
duplicate work in one run directory. Temporary outputs and checkpoint metadata
stay outside the exact bundled inventory. Low-memory failure stops only this
job's workers; rerun the same command, with fewer workers if necessary, to resume.

The historical 0.17.0 action pruning changed the source fingerprint without
rerendering the six retained actions. The old raw cache and baseline library
were removed in the 2026-10-03 cleanup, so the old compression comparison cannot
be rerun from this workspace alone. Reports and source provenance remain.
For new experiments, first render a fresh cache from the current production
source and select an available matching baseline. Never rewrite source stamps
to make an old or mismatched cache pass verification.

Real Flutter comparisons use `tools/compression_review_test.dart`, with
`COMPRESSION_REVIEW_ROOT` pointing to a benchmark run and `COMPRESSION_PROFILES`
selecting its profiles. Output contains repeated decoder timings and paired
shader-rendered views in original/tinted colors on light/dark backgrounds.
The production manifest schema remains unchanged; encoding may change codec frame
counts, so always regenerate `sampleFrames` from actual decoded durations.
Detailed run commands, measurements and release evidence are under
`artifacts/companion-compression/`.

## Bundled contract and playback

Only one complete library ships in `assets/companion/foal_3d/`.
Schema 2 packs each image vertically into 1024×5120: color, then hair,
hooves, headwear and wings masks. Every mask uses the alpha channel of a
black tile at the full source resolution. WebP color quality remains 90,
with lossless alpha. Quarter-second animated segments are independently
decodable. `sampleFrames` maps authored 60 Hz samples to actual codec frames
when WebP merges identical held poses.

The shader tints visible materials independently and normalizes edge coverage
against source alpha. The same manifest supplies runtime palette values,
geometry, timings, framing, item IDs and checksums.

Players share a 64 MiB managed decoded-image budget. The tested Flutter
engine ignores targetWidth for animated WebP, so each packed frame reserves
20 MiB. Low-resolution posters remain available for all 25 outfits; an LRU
keeps up to four detailed posters and evicts them when animation needs space.
A single visible player may keep one lookahead; multiple players relinquish
lookahead and replace their own obsolete frames within the same shared cap.
Hidden/backgrounded/disposed players release their frames and codecs.
Reduced motion uses a static pose. This cap excludes Flutter-internal
codec/GPU caches and total process memory.

The 768×2048 atlas has 24 pictures in 256-pixel cells: six headwear,
six wings, four celebrations, No polish and seven polish colors.
Celebrations use their own action's midpoint. Adding colors and changing runtime tints
does not require another Blender render: palette JSON is deliberately excluded
from the geometry hash. Regenerate just atlas and palette metadata with:

```bash
python3 tools/export_foal.py --items-only \
  --frames-root artifacts/foal-authoring/frames
```

Add matching stable mane and polish IDs in `lib/progress.dart` when extending
the palette; ownership stays independent. The atlas includes a polish picture
for each palette entry, and runtime validation requires matching catalog IDs.
Existing earned-gift counters remain unchanged until a future level crossing.

This validates geometry/assets before updating the atlas checksum and manifest.
Geometry or render-source changes still require a new export.

## Review and publish

Normal builds only verify existing assets; tests never regenerate Blender art.
Explicit real-codec review writes 175 base geometry/mane looks, tinted reward
examples and action pose sheets, using small flattened thumbnails to avoid
retaining many full-resolution decoded frames:

```bash
flutter test tools/foal_review_test.dart --concurrency=1 \
  --dart-define=FOAL_REVIEW_ROOT=docs/screenshots/0140
```

Inspect every new item, attachment, hoof color and action, plus normal and
reduced-motion app captures at phone/landscape/tablet sizes and large text.
Replace the bundled directory only after the entire staged library verifies.
Never mix new partial clips with an old manifest.

Source verification rejects unreferenced files, nested directories and
symlinks. APK verification checks the same exact asset inventory, duplicate
ZIP entries and absence of authoring/review files before replacing the
distributable. Bundled audio and phonics pictures remain unchanged. Historical source and reports remain in `artifacts/rewards-0140/baseline/`;
its old binary assets, models and APK were removed during cleanup.

In 0.17.0, Adventure-only walk/travel clips were pruned from the active spec, runtime and bundled manifest. Existing retained WebPs/posters/atlas are unchanged. The source .blend remains the editable historical master; no model or retained animation was rerendered. The manifest source hash records the pruned spec/rig source.
