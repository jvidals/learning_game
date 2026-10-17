# Appearance design reference: AMOLED Midnight Rainbow

Accepted September 18, 2026 for Learning Garden 0.15.0. This is the design
reference for future agents adding or changing UI. The implementation source of
truth is [app_theme.dart](../lib/app_theme.dart); the
[review gallery](screenshots/0150/README.md) shows the actual Flutter screens.

Learning Corner is the current app name. This reference describes the approved current appearance; it does not require all future companion themes to use unicorns and rainbows. See [the identity decision](design.md#learning-corner-identity-0191). The 0.19.1 rename preserves all palette and artwork choices below.

## Intent and approved choices

The user chose **Midnight Rainbow**, then specifically requested true black for
AMOLED battery saving. Main backgrounds are **#000000**, not charcoal, plum or
navy. Slightly lighter surfaces separate cards and dialogs. Bright rainbow
accents retain the current unicorn-and-rainbow companion theme without filling large areas
with white or bright color. Keep the clean Home layout and existing large
controls.

Adventure scenery and its overlay were removed in 0.17.0. Tap Challenge uses dark game surfaces and outlined star/rainbow/bomb drawings. Unicorn/equipment colors retain their original meaning in both modes.

AMOLED power reduction is a design objective. Battery savings have not been
measured; do not turn this rationale into a percentage or runtime claim.
Keep existing lifecycle pauses and reduced-motion support; do not add ambient
glows, continuously animated backgrounds, polling or another rendering layer.

## Palette and component rules

| Role | Dark value | Usage |
| --- | --- | --- |
| Background | `#000000` | Scaffold, app bar, unoccupied page area |
| Surface | `#111115` | Drawing pads, empty board slots, card interiors |
| Raised panel | `#1C1B23` | Dialogs, sheets, customization stage |
| Primary text | `#F3EEF8` | Titles, body, learning targets, tile numbers |
| Secondary text | `#C6BDCF` | Supporting labels |
| Outline | `#8B8295` | Meaningful boundaries and handwriting rules |
| Primary | `#C3A1FF` | Actions, selected outlines |
| On primary | `#21152E` | Text on filled lavender actions |
| Selected surface | `#332344` | Selected case and equipment |
| Success surface / ink | `#143327` / `#75DCAD` | Correct answers, locks, checks |
| Muted answer surface | `#26212E` | Other answers after success |
| Retry surface / ink | `#3D2025` / `#FFA49B` | Brief × feedback and errors |
| Portrait backing | `#241C30` | Cached static player portrait |
| Writing guide | `#7955A3` | Traceable letter shape |
| Writing direction | `#F3EEF8` | Direction arrows and numbered start badges |
| Writing ink | `#75DCAD` | Child's temporary drawing |

Rainbow accents, in existing red-to-violet order: pink **#FF82AC**, orange
**#FFB26B**, gold **#F6D66D**, mint **#75DCAD**, blue **#75CFFF**, lavender
**#C3A1FF**. Keep category hue assignments. Dark category/answer card fills mix
18% of their accent into #111115, with a visible accent border. Bright filled
buttons are for actions; rainbow arches and short success sparkles use the
accent palette. Do not derive these colors from the phone's wallpaper.

**2048:** keep all 14 values from 2–16384 distinct. The `darkTiles` table contains
individually chosen jewel tones; stationary, sliding and merging tiles use the
same `tile(value)` function. Numbers remain light, 2048 has its gold border, and
values above 16384 reuse the last tile color. Light tiles keep the previously
approved palette exactly.

**Writing:** both trace and freehand pads are dark. Rules remain solid at top and
baseline and dashed at the middle. The trace guide, direction arrows and child's
ink must be distinguishable from one another. Visual review prompted a darker
guide and light arrows: the original lavender-on-lavender combination was too
similar. Do not restore white paper panels in dark mode.

Readable text must meet **4.5:1** contrast; meaningful control boundaries and
graphics must meet **3:1**. Evaluate actual foreground/background pairs, including
selected, success and error states. The dark Writing arrows and ink each exceed
3:1 against the guide as well as against the pad. Decoration and disabled
controls are not the same as enabled content. Retain text, checks, × marks,
selection borders and semantics so information never depends on hue alone.

## Settings, persistence and Android behavior

- **Appearance** sits near the top of parent-gated Settings with vertically
  stacked **System**, **Light**, **Dark** radio choices. These remain comfortable
  at 200% text. Changes apply immediately and autosave; Back keeps accepted changes.
- Each stable player ID owns its preference. The last selected player resumes
  with their setting. New players and old saves without this setting use System.
  Reset preserves it, as do sound and alphabet-case changes.
- `AppAppearance` is a plain Dart enum. `AppSettings.toMap()` stores
  `appearance: "system" | "light" | "dark"`. The additive field does not change
  the profile envelope schema. Absence means System; invalid present values
  trigger existing settings recovery, retaining the malformed document until
  explicit parent-gated recovery.
- Use the existing controller and full-profile save operation. Do not write
  directly through Android or create another settings store. Pending/failed
  saves retain their originating player and exact intended document. The latest accepted appearance remains visible during pending/failed saves;
  committed settings remain separately available until persistence/retry succeeds.
- The app root owns, loads and disposes the shared `ProgressController`; Home
  receives it. Root updates observe effective appearance changes. Never key/recreate
  the Navigator, controller or active route on brightness changes.
- Flutter's System mode reacts to Android brightness changes and app resume.
  Explicit Light/Dark overrides remain fixed. System brightness changes do not
  write settings or change game state. Theme changes are immediate, without an
  added animation. A purely visual rebuild must not restart automatic pacing.
- Native launch/window resources follow Android before local profiles load;
  the saved player override then controls Flutter content. System bar icon
  brightness follows the resolved app theme, including Home and app-bar routes.
  Keep Android edge-to-edge behavior and existing safe areas.

## Extending the design

1. Use `Theme.of(context).colorScheme` for Material components and
   `GardenColors.of(context)` for game-specific roles. Add paired values centrally
   when an existing role cannot express the behavior. Do not scatter new hex
   values, fixed white backgrounds or the legacy dark-purple `ink` UI text.
2. Artwork palettes are independent. `garden_art.dart` retains legacy constants
   for asset fallback colors and compatibility; they are not general UI tokens.
   Do not invert the unicorn, recolor equipment or regenerate assets for a theme.
3. Supply resolved colors to custom painters and compare the palette in
   `shouldRepaint`. A theme switch must repaint even when the drawing itself did
   not change. Retain temporary ink, ongoing gestures and animation positions.
4. Test both palettes, selected/disabled/error/success states, profiles and
   autosave/Back/retry and rapid successive edits. Test live System changes on a nested route and during play.
5. Review real rendered captures on small/normal phones, landscape and tablets,
   with normal/200% text and reduced motion. Update this reference and its gallery
   when intentionally changing approved palette roles or component behavior.

No packages, network permissions, downloads, analytics or cloud services are
needed for themes. See [testing notes](testing.md) for actual validation and
remaining physical-device checks.
