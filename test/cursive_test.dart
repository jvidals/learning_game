import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/cursive.dart';
import 'package:rainbow_garden/handwriting.dart';

void main() {
  test('families cover each lowercase letter exactly once', () {
    final letters = cursiveFamilies.expand((family) => family.letters).toList();
    expect(letters, hasLength(26));
    expect(letters.toSet(), 'abcdefghijklmnopqrstuvwxyz'.split('').toSet());
    expect(cursiveFamilies.map((family) => family.name), [
      'Magic c',
      'Loops',
      'Tall and short',
      'Humps',
    ]);
  });

  for (final character in ['a', 'd', 'g', 'q', 'p']) {
    test('$character bowl encloses a clear open interior', () {
      final letter = cursiveLetters[character]!;
      final center = InkPoint(character == 'p' ? .59 : .50, .75);
      const minimumOpening = .5 * .35; // 35% of the .5-unit x-height.
      const strokeWidth = .055; // The model's largest relative stroke width.
      final points = letter.strokes.single;
      final horizontal = <double>[], vertical = <double>[];
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1], b = points[i];
        if ((a.y <= center.y && b.y > center.y) ||
            (b.y <= center.y && a.y > center.y)) {
          horizontal.add(a.x + (center.y - a.y) / (b.y - a.y) * (b.x - a.x));
        }
        if ((a.x <= center.x && b.x > center.x) ||
            (b.x <= center.x && a.x > center.x)) {
          vertical.add(a.y + (center.x - a.x) / (b.x - a.x) * (b.y - a.y));
        }
      }
      final left = horizontal.where((x) => x < center.x).reduce(math.max);
      final right = horizontal.where((x) => x > center.x).reduce(math.min);
      final top = vertical.where((y) => y < center.y).reduce(math.max);
      final bottom = vertical.where((y) => y > center.y).reduce(math.min);
      expect(right - left - strokeWidth, greaterThanOrEqualTo(minimumOpening));
      expect(bottom - top - strokeWidth, greaterThanOrEqualTo(minimumOpening));
      // A big outline alone is insufficient: no entry, stem or retrace may
      // cross the open center and fill it when painted with rounded strokes.
      expect(
        letter.points.map((point) => point.distance(center)).reduce(math.min),
        greaterThan((minimumOpening + strokeWidth) / 2),
      );
    });
  }

  for (final character in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
    test(
      '$character has bounded directed paths and the expected pen lifts',
      () {
        final letter = cursiveLetters[character]!;
        expect(letter.strokes, hasLength('ijtx'.contains(character) ? 2 : 1));
        expect(letter.strokes.first.first.x, closeTo(.12, .0001));
        expect(letter.strokes.first.first.y, closeTo(1, .0001));
        for (final point in letter.strokes.expand((stroke) => stroke)) {
          expect(point.x, inInclusiveRange(0, 1.25));
          expect(point.y, inInclusiveRange(0, 1.35));
        }
        final top = letter.points.map((p) => p.y).reduce(math.min);
        final bottom = letter.points.map((p) => p.y).reduce(math.max);
        if ('bdfhklt'.contains(character)) {
          expect(top, lessThanOrEqualTo(.2), reason: 'ascender band');
        } else {
          expect(top, greaterThanOrEqualTo(.27), reason: 'below ascender band');
        }
        if ('fgjpqyz'.contains(character)) {
          expect(bottom, greaterThanOrEqualTo(1.26), reason: 'descender band');
        } else {
          expect(bottom, lessThanOrEqualTo(1.001));
        }
        expect(letter.strokes.first.last.y, closeTo(.76, .001));
        expect(letter.watchPoint(0).distance(letter.strokes.first.first), 0);
        expect(
          letter.watchPoint(1).distance(letter.strokes.last.last),
          closeTo(0, 1e-10),
        );
      },
    );

    test('$character accepts its own path without checking stroke order', () {
      final letter = cursiveLetters[character]!;
      expect(cursiveCoverage(letter, letter.strokes), greaterThan(.99));
      expect(
        cursiveCoverage(
          letter,
          letter.strokes.reversed.map((s) => s.reversed.toList()).toList(),
        ),
        greaterThan(.99),
      );
      expect(
        cursiveCoverage(letter, const [
          [InkPoint(0, 0), InkPoint(.05, .04), InkPoint(.02, .08)],
        ]),
        lessThan(.15),
      );
      expect(cursiveCoverage(letter, const []), 0);
    });
  }
}
