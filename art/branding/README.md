# Learning Corner launcher icon

The parent selected **Letters and Numbers** on 2026-10-20:
an open cream book with **A** and **3**, a teal cover, golden page edges
and a star, on a rich blue background. The accompanying
[concept sheet](letters-and-numbers-concept.png) is the approved visual reference.
It was created with the built-in image-generation tool during design exploration.
The production mark is a clean vector recreation, not a crop of that sheet.

Editable production sources live in Android's `res/drawable/`:
`ic_launcher_foreground.xml`, `ic_launcher_monochrome.xml` and the legacy
`ic_garden.xml`. The existing `drawable-anydpi-v26/ic_garden.xml` assembles
the adaptive layers. Keep the resource names for compatibility.

- Flat fills: blue `#074BB3`, teal `#0BB5B8`, cream `#FFF9E6`,
  gold `#FFC32C`.
- A and 3 are outlined Roboto Bold glyphs, with a small optical weight adjustment
  for launcher readability. They were derived from the installed Android Studio
  layoutlib font; no font file or new runtime dependency is bundled.
- Adaptive layers use a 108 dp viewport. The mark's 0.62 scale and 23 dp
  translation keep its outline inside the central radius-33 dp safe region
  (measured maximum radius: 32.807 dp).
- The monochrome layer uses actual transparent cutouts for the fold, page detail
  and glyphs. Android supplies both themed colors.
- The older-Android fallback uses the same artwork on a full blue square,
  scaled to 0.86; Android 8+ supplies its own adaptive mask.
- The main icon has a separate background resource. Sketch Pad and 2048
  shortcuts retain their existing backgrounds and illustrations.

Companions and the in-app Light/Midnight Rainbow palettes are independent of
this launcher branding. Alternate companion icons remain future work.
