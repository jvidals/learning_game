import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/number_range.dart';

// Compare every in-range value by the teaching rule, independently of how the
// game generates candidates. A smaller rank means a stronger look-alike.
int? lookalikeRank(int target, int candidate) {
  if (target == candidate) return null;
  final a = '$target';
  final b = '$candidate';
  if (a.length == 2 &&
      !a.contains('0') &&
      a[0] != a[1] &&
      b == '${a[1]}${a[0]}') {
    return 0;
  }
  if (a.length == b.length) {
    final differences = [
      for (var i = 0; i < a.length; i++)
        if (a[i] != b[i]) '${a[i]}${b[i]}',
    ];
    if (differences.length == 1 && {'69', '96'}.contains(differences.single)) {
      return 1;
    }
  }
  const teenTyPairs = [
    [13, 30],
    [14, 40],
    [15, 50],
    [16, 60],
    [17, 70],
    [18, 80],
    [19, 90],
  ];
  if (teenTyPairs.any(
    (pair) => pair.contains(target) && pair.contains(candidate),
  )) {
    return 2;
  }
  if (target % 10 == candidate % 10 && (target - candidate).abs() == 10) {
    return 3;
  }
  if ((target - candidate).abs() == 1) return 4;
  return null;
}

void main() {
  for (final bounds in [
    [0, 10],
    [0, 20],
    [10, 30],
    [0, 30],
    [0, 100],
    [0, 2],
  ]) {
    test(
      'Number hunt prefers in-range look-alikes in $bounds across seeds',
      () {
        final range = NumberRange(bounds[0], bounds[1]);
        final seenTargets = <int>{};
        final selected = <int, Set<int>>{};
        for (var seed = 0; seed < 400; seed++) {
          final round = GameRound(
            Activity.numbers,
            numberRange: range,
            random: Random(seed),
          );
          final slots = [0, 0, 0];
          final targets = round.questions.map((q) => q.answer).toList();
          expect(
            targets.take(min(range.count, GameRound.length)).toSet(),
            hasLength(min(range.count, GameRound.length)),
          );
          for (var i = 1; i < targets.length; i++) {
            expect(targets[i], isNot(targets[i - 1]));
          }
          for (final question in round.questions) {
            final target = int.parse(question.answer);
            final choices = question.choices.map(int.parse).toList();
            seenTargets.add(target);
            expect(choices, hasLength(3));
            expect(choices.toSet(), hasLength(3));
            expect(
              choices,
              everyElement(inInclusiveRange(range.min, range.max)),
            );
            expect(choices, contains(target));
            expect(question.audio, 'number_$target');
            slots[choices.indexOf(target)]++;
            final ranked = {
              for (var value = range.min; value <= range.max; value++)
                if (lookalikeRank(target, value) case final int rank)
                  value: rank,
            };
            if (ranked.isEmpty) continue;
            final bestRank = ranked.values.reduce(min);
            final preferred = ranked.entries
                .where((entry) => entry.value == bestRank)
                .map((entry) => entry.key)
                .toSet();
            final wrong = choices.where((value) => value != target).toList();
            expect(
              wrong.first,
              isIn(preferred),
              reason: 'seed $seed, target $target',
            );
            selected.putIfAbsent(target, () => {}).add(wrong.first);
          }
          expect(slots..sort(), [1, 2, 2]);
        }
        expect(
          seenTargets,
          containsAll([
            for (var value = range.min; value <= range.max; value++) value,
          ]),
        );
        if (range.min == 0 && range.max == 10) {
          expect(selected[6], {9});
          expect(selected[5], {4, 6});
        }
        if (range.min == 0 && range.max == 30) {
          expect(selected[12], {21});
          expect(selected[30], {13}); // Leading zero reversal is not allowed.
        }
        if (range.max == 100) {
          expect(selected[14], {41}); // Reversal precedes teen/ty.
          expect(selected[40], {14});
          expect(selected[16], {61});
          expect(selected[66], {69, 96});
        }
      },
    );
  }
}
