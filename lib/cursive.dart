import 'handwriting.dart';

class CursiveFamily {
  const CursiveFamily(this.name, this.letters);
  final String name;
  final List<String> letters;
}

const cursiveFamilies = [
  CursiveFamily('Magic c', ['c', 'a', 'd', 'g', 'o', 'q']),
  CursiveFamily('Loops', ['e', 'l', 'h', 'k', 'b', 'f']),
  CursiveFamily('Tall and short', ['i', 't', 'u', 'w', 'j', 'p']),
  CursiveFamily('Humps', ['n', 'm', 'v', 'x', 'y', 'z', 'r', 's']),
];

/// Original, hand-authored centerline paths, drawn for Learning Corner; these
/// are not outlines or tracings of any font, worksheet, or commercial alphabet.
/// Mostly upright modern US lowercase, with small functional loops only.
/// Units match the print pads: ascender 0–.2, midline .5, baseline 1,
/// descender 1.35. Every main stroke enters at (.12, 1) and exits at y=.76.
/// Ordered strokes give Watch its direction; only i/j/t/x require a pen lift.
class CursiveLetter {
  CursiveLetter(this.character, List<InkStroke> strokes)
    : strokes = List.unmodifiable(strokes.map(List<InkPoint>.unmodifiable));

  final String character;
  final List<InkStroke> strokes;
  late final List<InkStroke> samples = List.unmodifiable(
    strokes.map((s) => List<InkPoint>.unmodifiable(sampleStroke(s))),
  );
  late final List<InkPoint> points = List.unmodifiable(
    samples.expand((s) => s),
  );
  late final List<double> _lengths = strokes
      .map((s) => inkLength([s]))
      .toList();

  /// Constant-distance travel within a stroke. Pen lifts jump to the next start
  /// instead of drawing an imaginary joining line. Dots receive a short dwell.
  InkPoint watchPoint(double progress) =>
      watchPointAlong(strokes, progress, lengths: _lengths);
}

/// Gentle spatial coverage only: no timing, direction, or stroke-order grade.
/// Resampling makes finger speed irrelevant; a generous .14-unit tolerance
/// allows wobbly curves. The page uses .60 coverage for friendly encouragement.
/// This is practice feedback, never an assessment or a reward requirement.
double cursiveCoverage(CursiveLetter letter, List<InkStroke> ink) {
  final drawn = ink
      .where((s) => s.isNotEmpty)
      .map(sampleStroke)
      .expand((s) => s)
      .toList();
  if (drawn.isEmpty) return 0;
  var covered = 0;
  for (final point in letter.points) {
    if (drawn.any((other) => point.distance(other) <= .14)) covered++;
  }
  return covered / letter.points.length;
}

/// Fraction of resampled ink near the model. Complements coverage so broad
/// scribbling cannot pass merely by crossing every part of the letter.
/// Like coverage, this ignores speed, direction and stroke order.
double cursivePrecision(CursiveLetter letter, List<InkStroke> ink) {
  final drawn = ink
      .where((stroke) => stroke.isNotEmpty)
      .map(sampleStroke)
      .expand((stroke) => stroke)
      .toList();
  if (drawn.isEmpty) return 0;
  final near = drawn
      .where(
        (point) => letter.points.any((model) => point.distance(model) <= .14),
      )
      .length;
  return near / drawn.length;
}

// Absolute M/L/C commands; each list entry is one pen-down stroke. Curves are
// flattened once for the same geometry in painting, animation and coverage.
InkStroke _path(String source) {
  final tokens = RegExp(
    r'[MLC]|-?\d*\.?\d+',
  ).allMatches(source).map((m) => m[0]!).toList();
  final points = <InkPoint>[];
  var index = 0;
  InkPoint read() =>
      InkPoint(double.parse(tokens[index++]), double.parse(tokens[index++]));
  while (index < tokens.length) {
    final command = tokens[index++];
    if (command == 'M' || command == 'L') {
      points.add(read());
    } else if (command == 'C') {
      final start = points.last, a = read(), b = read(), end = read();
      for (var step = 1; step <= 28; step++) {
        final t = step / 28, u = 1 - t;
        points.add(
          InkPoint(
            u * u * u * start.x +
                3 * u * u * t * a.x +
                3 * u * t * t * b.x +
                t * t * t * end.x,
            u * u * u * start.y +
                3 * u * u * t * a.y +
                3 * u * t * t * b.y +
                t * t * t * end.y,
          ),
        );
      }
    } else {
      throw FormatException('Invalid cursive command: $command');
    }
  }
  return points;
}

final Map<String, CursiveLetter> cursiveLetters = Map.unmodifiable({
  for (final entry in _paths.entries)
    entry.key: CursiveLetter(entry.key, entry.value.map(_path).toList()),
});

// Bowl entries follow the upper/left outline instead of cutting through its
// counter. The right-side retrace stays on the oval edge; stems extend outside.
const _paths = <String, List<String>>{
  'a': [
    'M .12 1 C .18 .83 .18 .52 .50 .5 C .57 .49 .65 .49 .72 .5 C .48 .45 .28 .52 .28 .75 C .28 1.08 .72 1.08 .72 .75 L .72 .5 L .72 .87 C .72 1.08 .86 .96 1 .76',
  ],
  'b': [
    'M .12 1 C .32 .78 .63 .24 .57 .06 C .51 -.08 .38 .06 .38 .35 L .38 .85 C .38 1.07 .76 1.06 .78 .71 C .80 .45 .58 .51 .62 .71 C .68 .86 .84 .90 .96 .76',
  ],
  'c': [
    'M .12 1 C .29 .81 .43 .47 .65 .5 C .46 .44 .30 .60 .30 .78 C .30 1.04 .66 1.07 .92 .76',
  ],
  'd': [
    'M .12 1 C .18 .83 .18 .52 .50 .5 C .57 .49 .65 .49 .72 .5 C .48 .45 .28 .52 .28 .75 C .28 1.08 .72 1.08 .72 .75 L .72 .04 L .72 .87 C .72 1.08 .86 .96 1 .76',
  ],
  'e': [
    'M .12 1 C .25 .84 .65 .69 .61 .55 C .57 .41 .30 .56 .32 .77 C .35 1.06 .65 1.06 .94 .76',
  ],
  'f': [
    'M .12 1 C .36 .73 .67 .25 .59 .06 C .52 -.08 .40 .08 .40 .35 L .40 1.20 C .40 1.45 .65 1.32 .62 1.12 C .59 .91 .40 1.01 .43 .84 C .47 .65 .73 .92 .96 .76',
  ],
  'g': [
    'M .12 1 C .18 .83 .18 .52 .50 .5 C .57 .49 .65 .49 .72 .5 C .48 .45 .28 .52 .28 .75 C .28 1.08 .72 1.08 .72 .75 L .72 .5 L .72 1.16 C .72 1.38 .38 1.38 .38 1.24 C .38 1.10 .82 .99 1 .76',
  ],
  'h': [
    'M .12 1 C .32 .78 .63 .24 .57 .06 C .51 -.08 .38 .06 .38 .35 L .38 1 C .38 .73 .47 .5 .63 .5 C .81 .5 .74 .78 .74 .89 C .74 1.04 .86 .93 .98 .76',
  ],
  'i': [
    'M .12 1 C .28 .85 .39 .65 .46 .5 L .44 .87 C .44 1.08 .65 .98 .86 .76',
    'M .46 .30',
  ],
  'j': [
    'M .12 1 C .28 .85 .45 .65 .54 .5 L .52 1.17 C .52 1.38 .25 1.38 .27 1.24 C .29 1.07 .68 .98 .94 .76',
    'M .54 .30',
  ],
  'k': [
    'M .12 1 C .32 .78 .63 .24 .57 .06 C .51 -.08 .38 .06 .38 .35 L .38 1 L .39 .77 C .47 .53 .73 .39 .74 .61 C .74 .74 .50 .78 .42 .78 C .76 .64 .63 1.05 .83 .94 L .98 .76',
  ],
  'l': [
    'M .12 1 C .32 .78 .63 .24 .57 .06 C .51 -.08 .38 .06 .38 .35 L .38 .85 C .38 1.09 .67 1.01 .89 .76',
  ],
  'm': [
    'M .12 1 C .22 .87 .27 .66 .30 .5 L .29 1 C .29 .74 .34 .50 .48 .5 C .62 .5 .57 .84 .57 1 C .57 .74 .62 .5 .76 .5 C .91 .5 .85 .79 .85 .89 C .85 1.05 1 .93 1.12 .76',
  ],
  'n': [
    'M .12 1 C .25 .85 .32 .65 .36 .5 L .35 1 C .35 .74 .42 .5 .60 .5 C .80 .5 .72 .80 .72 .89 C .72 1.05 .86 .93 .98 .76',
  ],
  'o': [
    'M .12 1 C .27 .85 .42 .52 .65 .5 C .43 .44 .30 .60 .30 .78 C .30 1.07 .72 1.07 .72 .75 C .72 .56 .64 .49 .56 .52 C .48 .55 .72 .88 .96 .76',
  ],
  'p': [
    'M .12 1 C .24 .82 .34 .64 .36 .5 L .36 1.32 L .36 .75 C .36 .42 .82 .42 .82 .75 C .82 1.08 .36 1.08 .36 .75 L .36 .88 C .36 1.08 .82 1.04 1.02 .76',
  ],
  'q': [
    'M .12 1 C .18 .83 .18 .52 .50 .5 C .57 .49 .65 .49 .72 .5 C .48 .45 .28 .52 .28 .75 C .28 1.08 .72 1.08 .72 .75 L .72 .5 L .72 1.28 C .72 1.35 .91 1.35 .91 1.25 C .91 1.13 .76 1.16 .78 1.27 C .83 1.13 .91 .90 1.05 .76',
  ],
  'r': [
    'M .12 1 C .29 .81 .45 .65 .50 .5 C .51 .59 .54 .64 .58 .60 C .64 .53 .70 .48 .76 .52 L .70 .86 C .67 1.04 .83 .96 .96 .76',
  ],
  's': [
    'M .12 1 C .28 .84 .48 .66 .60 .5 C .60 .65 .82 .78 .65 .94 C .53 1.02 .36 .98 .38 .86 C .44 1 .71 1 .96 .76',
  ],
  't': [
    'M .12 1 C .30 .80 .48 .40 .51 .16 L .48 .86 C .48 1.08 .72 .98 .92 .76',
    'M .30 .49 L .73 .49',
  ],
  'u': [
    'M .12 1 C .28 .85 .39 .65 .44 .5 L .41 .84 C .38 1.05 .70 1.05 .71 .79 L .73 .5 L .71 .87 C .71 1.06 .86 .94 .98 .76',
  ],
  'v': [
    'M .12 1 C .28 .84 .36 .50 .46 .5 C .54 .5 .46 .85 .55 .96 C .66 1.10 .80 .62 .78 .51 C .76 .65 .88 .84 1 .76',
  ],
  'w': [
    'M .12 1 C .24 .86 .31 .65 .35 .5 L .32 .84 C .29 1.05 .56 1.05 .58 .79 L .60 .5 L .58 .84 C .56 1.05 .82 1.05 .88 .76 L .91 .5 C .89 .67 1 .84 1.12 .76',
  ],
  'x': [
    'M .12 1 C .25 .86 .28 .53 .39 .5 C .53 .44 .59 .81 .72 .94 C .79 1 .87 .88 .96 .76',
    'M .80 .5 C .67 .66 .46 .86 .35 1',
  ],
  'y': [
    'M .12 1 C .28 .85 .39 .65 .44 .5 L .41 .84 C .38 1.05 .70 1.05 .71 .79 L .73 .5 L .70 1.17 C .70 1.38 .37 1.38 .38 1.24 C .39 1.07 .77 .97 .98 .76',
  ],
  'z': [
    'M .12 1 C .28 .84 .37 .50 .49 .5 C .74 .46 .74 .75 .52 .80 C .80 .69 .84 1 .65 1.18 C .45 1.39 .29 1.36 .36 1.24 C .42 1.13 .78 1 .98 .76',
  ],
};
