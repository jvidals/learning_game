import 'dart:math' as math;

/// Coordinates are in cap-height units: top 0, middle .5, baseline 1.
/// Descenders reach 1.35. Raw line alignment is checked before shape fitting.
class InkPoint {
  const InkPoint(this.x, this.y);
  final double x, y;
  double distance(InkPoint other) =>
      math.sqrt((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y));
  InkPoint lerp(InkPoint other, double t) =>
      InkPoint(x + (other.x - x) * t, y + (other.y - y) * t);
}

typedef InkStroke = List<InkPoint>;

/// Constant-distance travel within a stroke. Pen lifts jump to the next start
/// instead of drawing an imaginary joining line. Dots receive a short dwell.
/// Immutable letter templates supply cached [lengths] for animation frames.
InkPoint watchPointAlong(
  List<InkStroke> strokes,
  double progress, {
  List<double>? lengths,
}) {
  final strokeLengths = lengths ?? strokes.map((s) => inkLength([s])).toList();
  final durations = strokeLengths
      .map((length) => math.max(.12, length))
      .toList();
  var remaining = progress.clamp(0, 1) * durations.reduce((a, b) => a + b);
  for (var i = 0; i < strokes.length; i++) {
    if (remaining <= durations[i] || i == strokes.length - 1) {
      final stroke = strokes[i];
      var distance = remaining / durations[i] * strokeLengths[i];
      for (var j = 1; j < stroke.length; j++) {
        final length = stroke[j - 1].distance(stroke[j]);
        if (distance <= length && length > 0) {
          return stroke[j - 1].lerp(stroke[j], distance / length);
        }
        distance -= length;
      }
      return stroke.last;
    }
    remaining -= durations[i];
  }
  return strokes.last.last;
}

class LetterTemplate {
  LetterTemplate(this.character, List<InkStroke> strokes)
    : strokes = List.unmodifiable(
        strokes.map((s) => List<InkPoint>.unmodifiable(s)),
      );
  final String character;
  final List<InkStroke> strokes;
  late final List<InkStroke> samples = strokes.map(sampleStroke).toList();
  late final List<InkPoint> points = samples.expand((s) => s).toList();
  late final double length = inkLength(strokes);
  late final List<double> _lengths = strokes
      .map((s) => inkLength([s]))
      .toList();

  InkPoint watchPoint(double progress) =>
      watchPointAlong(strokes, progress, lengths: _lengths);
}

/// Small, authored vector alphabet, not a system font. Each string is a taught
/// pen-down stroke; M/L/C are absolute move/line/cubic commands. Dots are M only.
/// Curves are flattened once, then shared by painting and evaluation.
InkStroke _path(String value) {
  final tokens = RegExp(
    r'[MLC]|-?\d*\.?\d+',
  ).allMatches(value).map((m) => m[0]!).toList();
  final points = <InkPoint>[];
  var i = 0;
  InkPoint point() =>
      InkPoint(double.parse(tokens[i++]), double.parse(tokens[i++]));
  while (i < tokens.length) {
    final command = tokens[i++];
    if (command == 'M' || command == 'L') {
      points.add(point());
    } else if (command == 'C') {
      final start = points.last, a = point(), b = point(), end = point();
      for (var step = 1; step <= 24; step++) {
        final t = step / 24, u = 1 - t;
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
      throw FormatException('Invalid letter path: $command');
    }
  }
  return points;
}

final Map<String, LetterTemplate> letterTemplates = Map.unmodifiable({
  for (final entry in _letterPaths.entries)
    entry.key: LetterTemplate(entry.key, _alignedPaths(entry.key, entry.value)),
});

// Match the taught writing rules exactly, including extrema of curved letters.
List<InkStroke> _alignedPaths(String letter, List<String> paths) {
  final strokes = paths.map(_path).toList();
  final bounds = _Bounds(strokes.expand((s) => s).toList());
  final uppercase = letter == letter.toUpperCase();
  final top = uppercase || 'bdfhkl'.contains(letter)
      ? 0.0
      : letter == 'i' || letter == 'j'
      ? .28
      : letter == 't'
      ? .18
      : .5;
  final bottom = 'gjpqy'.contains(letter)
      ? 1.35
      : letter == 'Q'
      ? 1.08
      : 1.0;
  return strokes
      .map(
        (stroke) => stroke
            .map(
              (p) => InkPoint(
                p.x,
                top + (p.y - bounds.top) / bounds.height * (bottom - top),
              ),
            )
            .toList(),
      )
      .toList();
}

const _letterPaths = <String, List<String>>{
  'A': ['M .5 0 L .15 1', 'M .5 0 L .85 1', 'M .29 .6 L .71 .6'],
  'B': ['M .25 0 L .25 1', 'M .25 0 C .95 0 .95 .5 .25 .5 C 1 .5 1 1 .25 1'],
  'C': ['M .82 .14 C .1 -.25 .05 1.24 .82 .86'],
  'D': ['M .25 0 L .25 1', 'M .25 0 C 1.1 0 1.1 1 .25 1'],
  'E': [
    'M .25 0 L .25 1',
    'M .25 0 L .8 0',
    'M .25 .5 L .7 .5',
    'M .25 1 L .8 1',
  ],
  'F': ['M .25 0 L .25 1', 'M .25 0 L .8 0', 'M .25 .5 L .7 .5'],
  'G': ['M .82 .14 C .1 -.25 .05 1.24 .82 .86 L .82 .55 L .54 .55'],
  'H': ['M .2 0 L .2 1', 'M .8 0 L .8 1', 'M .2 .5 L .8 .5'],
  'I': ['M .25 0 L .75 0', 'M .5 0 L .5 1', 'M .25 1 L .75 1'],
  'J': ['M .75 0 L .75 .73 C .75 1.1 .2 1.1 .2 .73', 'M .35 0 L .9 0'],
  'K': ['M .2 0 L .2 1', 'M .8 0 L .2 .55', 'M .43 .34 L .85 1'],
  'L': ['M .25 0 L .25 1 L .8 1'],
  'M': ['M .15 0 L .15 1', 'M .15 0 L .5 .6 L .85 0 L .85 1'],
  'N': ['M .2 0 L .2 1', 'M .2 0 L .8 1', 'M .8 0 L .8 1'],
  'O': ['M .5 0 C .05 0 .05 1 .5 1 C .95 1 .95 0 .5 0'],
  'P': ['M .25 0 L .25 1', 'M .25 0 C 1 0 1 .52 .25 .52'],
  'Q': ['M .5 0 C .05 0 .05 1 .5 1 C .95 1 .95 0 .5 0', 'M .58 .73 L .9 1.08'],
  'R': ['M .25 0 L .25 1', 'M .25 0 C 1 0 1 .52 .25 .52', 'M .49 .52 L .85 1'],
  'S': ['M .8 .13 C .23 -.28 .02 .38 .5 .5 C 1 .63 .77 1.3 .17 .87'],
  'T': ['M .1 0 L .9 0', 'M .5 0 L .5 1'],
  'U': ['M .2 0 L .2 .7 C .2 1.1 .8 1.1 .8 .7 L .8 0'],
  'V': ['M .15 0 L .5 1 L .85 0'],
  'W': ['M .06 0 L .28 1 L .5 .35 L .72 1 L .94 0'],
  'X': ['M .15 0 L .85 1', 'M .85 0 L .15 1'],
  'Y': ['M .15 0 L .5 .5', 'M .85 0 L .5 .5 L .5 1'],
  'Z': ['M .15 0 L .85 0 L .15 1 L .85 1'],
  'a': ['M .72 .57 C .18 .2 .13 1.25 .72 .92 L .72 .5 L .72 1'],
  'b': ['M .25 0 L .25 1', 'M .25 .59 C .95 .13 .95 1.37 .25 .92'],
  'c': ['M .73 .56 C .15 .21 .1 1.29 .73 .94'],
  'd': ['M .72 .57 C .18 .2 .13 1.25 .72 .92', 'M .72 0 L .72 1'],
  'e': [
    'M .25 .75 L .75 .75 C .75 .29 .16 .5 .25 .85 C .3 1.03 .56 1.06 .75 .94',
  ],
  'f': ['M .72 .08 C .47 -.12 .36 .06 .36 .3 L .36 1', 'M .17 .5 L .7 .5'],
  'g': [
    'M .72 .57 C .18 .2 .13 1.25 .72 .92 L .72 .5 L .72 1.12 C .72 1.4 .34 1.42 .22 1.23',
  ],
  'h': ['M .25 0 L .25 1', 'M .25 .69 C .4 .4 .75 .43 .75 .72 L .75 1'],
  'i': ['M .5 .5 L .5 1', 'M .5 .28'],
  'j': ['M .6 .5 L .6 1.13 C .6 1.39 .32 1.41 .22 1.22', 'M .6 .28'],
  'k': ['M .25 0 L .25 1', 'M .75 .5 L .25 .8', 'M .43 .69 L .78 1'],
  'l': ['M .5 0 L .5 1'],
  'm': [
    'M .12 .5 L .12 1',
    'M .12 .69 C .2 .42 .5 .42 .5 .7 L .5 1',
    'M .5 .69 C .62 .42 .88 .42 .88 .7 L .88 1',
  ],
  'n': ['M .25 .5 L .25 1', 'M .25 .69 C .4 .4 .75 .43 .75 .72 L .75 1'],
  'o': ['M .5 .5 C .14 .5 .14 1 .5 1 C .86 1 .86 .5 .5 .5'],
  'p': ['M .25 .5 L .25 1.35', 'M .25 .59 C .95 .13 .95 1.37 .25 .92'],
  'q': ['M .72 .57 C .18 .2 .13 1.25 .72 .92', 'M .72 .5 L .72 1.35'],
  'r': ['M .3 .5 L .3 1', 'M .3 .7 C .4 .49 .59 .43 .73 .55'],
  's': ['M .72 .57 C .33 .32 .12 .68 .49 .75 C .9 .84 .63 1.19 .25 .94'],
  't': ['M .43 .18 L .43 .84 C .43 1.05 .6 1.03 .73 .94', 'M .19 .5 L .74 .5'],
  'u': ['M .25 .5 L .25 .81 C .25 1.12 .64 1.05 .75 .81', 'M .75 .5 L .75 1'],
  'v': ['M .2 .5 L .5 1 L .8 .5'],
  'w': ['M .08 .5 L .28 1 L .5 .62 L .72 1 L .92 .5'],
  'x': ['M .22 .5 L .78 1', 'M .78 .5 L .22 1'],
  'y': ['M .2 .5 L .5 1', 'M .8 .5 L .31 1.35'],
  'z': ['M .23 .5 L .77 .5 L .23 1 L .77 1'],
};

double inkLength(List<InkStroke> strokes) {
  var sum = 0.0;
  for (final stroke in strokes) {
    for (var i = 1; i < stroke.length; i++) {
      sum += stroke[i - 1].distance(stroke[i]);
    }
  }
  return sum;
}

/// Equal-distance samples make input speed irrelevant; never connect pen lifts.
InkStroke sampleStroke(InkStroke stroke) {
  if (stroke.isEmpty) return [];
  final result = <InkPoint>[stroke.first];
  var remaining = .018;
  for (var i = 1; i < stroke.length; i++) {
    var start = stroke[i - 1];
    final end = stroke[i];
    var distance = start.distance(end);
    while (distance >= remaining) {
      start = start.lerp(end, remaining / distance);
      result.add(start);
      distance = start.distance(end);
      remaining = .018;
    }
    remaining -= distance;
  }
  if (result.last.distance(stroke.last) > .004) result.add(stroke.last);
  return result;
}

enum WritingRejection {
  none,
  empty,
  excessInk,
  size,
  position,
  proportions,
  shape,
  missingPart,
  differentLetter,
}

class WritingEvaluation {
  const WritingEvaluation(
    this.accepted,
    this.message, [
    this.reason = WritingRejection.none,
  ]);
  final bool accepted;
  final String message;
  final WritingRejection reason;
}

class _Bounds {
  _Bounds(List<InkPoint> points)
    : left = points.map((p) => p.x).reduce(math.min),
      right = points.map((p) => p.x).reduce(math.max),
      top = points.map((p) => p.y).reduce(math.min),
      bottom = points.map((p) => p.y).reduce(math.max);
  final double left, right, top, bottom;
  double get height => bottom - top;
  double get width => right - left;
  double get centerX => (left + right) / 2;
}

double _nearest(InkPoint p, List<InkPoint> points) {
  var nearest = double.infinity;
  for (final other in points) {
    nearest = math.min(nearest, p.distance(other));
  }
  return nearest;
}

/// Judge writing-line placement before normalizing shape. This lets a child
/// write a narrower/wider letter without accepting a tiny or misplaced one.
/// No rotation, reflection, stroke order, or stroke direction is required.
WritingEvaluation evaluateWriting(LetterTemplate target, List<InkStroke> ink) {
  const retry = WritingEvaluation(
    false,
    'Look at the example and try again.',
    WritingRejection.shape,
  );
  if (ink.isEmpty || ink.every((s) => s.isEmpty)) {
    return const WritingEvaluation(
      false,
      'Write a letter in the blank space.',
      WritingRejection.empty,
    );
  }
  if (ink.length > 64 || ink.fold(0, (n, s) => n + s.length) > 4096) {
    return const WritingEvaluation(
      false,
      'Clear the space and write one letter.',
      WritingRejection.excessInk,
    );
  }
  if (ink
      .expand((s) => s)
      .any(
        (p) =>
            !p.x.isFinite || !p.y.isFinite || p.x.abs() > 10 || p.y.abs() > 10,
      ))
    return retry;
  final length = inkLength(ink);
  if (length < target.length * .45 || length > target.length * 2.2) {
    return const WritingEvaluation(
      false,
      'Clear the space and write one letter.',
      WritingRejection.excessInk,
    );
  }
  final sampled = ink.map(sampleStroke).expand((s) => s).toList();
  if (sampled.length < 6 || sampled.length > 2000) return retry;
  final bounds = _Bounds(sampled), guide = _Bounds(target.points);
  if (bounds.height < guide.height * .70) {
    return const WritingEvaluation(
      false,
      'Try making it taller.',
      WritingRejection.size,
    );
  }
  if (bounds.height > guide.height * 1.30) {
    return const WritingEvaluation(
      false,
      'Try making it a little smaller.',
      WritingRejection.size,
    );
  }
  if ((bounds.bottom - guide.bottom).abs() > .18 ||
      (bounds.top - guide.top).abs() > .18) {
    return const WritingEvaluation(
      false,
      'Use the lines like the example.',
      WritingRejection.position,
    );
  }
  if (guide.width > .1 &&
      (bounds.width < guide.width * .5 || bounds.width > guide.width * 1.85)) {
    return const WritingEvaluation(
      false,
      'Try making the shape like the example.',
      WritingRejection.proportions,
    );
  }
  // Normalize width independently of height; keep vertical-line letters from
  // magnifying small finger wobbles into a different shape.
  List<InkPoint> aligned(LetterTemplate template) {
    final box = _Bounds(template.points);
    final sx = box.width > .1 && bounds.width > .04
        ? box.width / bounds.width
        : 1.0;
    final sy = box.height / bounds.height;
    return sampled
        .map(
          (p) => InkPoint(
            box.centerX + (p.x - bounds.centerX) * sx,
            box.top + (p.y - bounds.top) * sy,
          ),
        )
        .toList();
  }

  final points = aligned(target);
  final uppercase = target.character == target.character.toUpperCase();
  final tolerance = uppercase ? .14 : .105;
  final distances = points.map((p) => _nearest(p, target.points)).toList();
  if (distances.where((d) => d <= tolerance).length / distances.length < .82)
    return retry;
  for (final stroke in target.samples) {
    if (stroke.where((p) => _nearest(p, points) <= tolerance).length /
            stroke.length <
        .80) {
      final message = switch (target.character) {
        'i' || 'j' => 'Remember the dot and the line.',
        'A' || 't' || 'f' => 'Remember the line across.',
        'Q' || 'R' => 'Remember the tail.',
        _ => 'Finish all the parts of the letter.',
      };
      return WritingEvaluation(false, message, WritingRejection.missingPart);
    }
  }
  // A full straight right stem distinguishes a from a closed oval. Overall
  // distance alone can prefer o when a child's oval is especially round.
  if (target.character == 'o') {
    final rightSide = List.generate(
      9,
      (i) => InkPoint(guide.right, guide.top + guide.height * (.1 + i * .1)),
    );
    if (rightSide.where((p) => _nearest(p, points) < .028).length >= 8)
      return retry;
  }
  if (target.character == 'a') {
    final stem = List.generate(9, (i) => InkPoint(.72, .54 + i * .055));
    if (stem.where((p) => _nearest(p, points) <= .065).length < 7) return retry;
  }
  if (target.character == 'e' &&
      _nearest(const InkPoint(.71, .855), points) < .045)
    return retry;
  double error(LetterTemplate template, List<InkPoint> candidate) {
    final forward =
        candidate.fold(0.0, (sum, p) => sum + _nearest(p, template.points)) /
        candidate.length;
    final backward =
        template.points.fold(0.0, (sum, p) => sum + _nearest(p, candidate)) /
        template.points.length;
    return (forward + backward) / 2;
  }

  final targetError = error(target, points);
  if (targetError > (uppercase ? .085 : .065)) return retry;
  final reflected = points
      .map((p) => InkPoint(2 * guide.centerX - p.x, p.y))
      .toList();
  if (error(target, reflected) + .012 < targetError) return retry;
  for (final other in letterTemplates.values) {
    if (other == target ||
        (other.character == other.character.toUpperCase()) != uppercase)
      continue;
    final otherBox = _Bounds(other.points);
    // Compare only alternatives that also fit the actual handwriting lines.
    if ((bounds.top - otherBox.top).abs() > .18 ||
        (bounds.bottom - otherBox.bottom).abs() > .18)
      continue;
    if (error(other, aligned(other)) + .004 < targetError) {
      return const WritingEvaluation(
        false,
        'Look at the example and try again.',
        WritingRejection.differentLetter,
      );
    }
  }
  return const WritingEvaluation(true, 'Lovely writing!');
}
