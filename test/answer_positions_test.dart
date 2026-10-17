import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/number_range.dart';

void main() {
  for (final activity in ActivityContent.recognition) {
    final ranges = activity == Activity.numbers
        ? [
            NumberRange.defaults,
            NumberRange(0, 100),
            NumberRange(20, 30),
            NumberRange(98, 100),
          ]
        : [NumberRange.defaults];
    for (final range in ranges) {
      test(
        '${activity.name} ${range.label}: each round balances slots without a fixed sequence',
        () {
          final sequences = <String>{};
          final singletons = <int>{};
          final firstPositions = <int>{};
          for (var seed = 0; seed < 1000; seed++) {
            final round = GameRound(
              activity,
              random: Random(seed),
              numberRange: range,
            );
            final slots = round.questions
                .map((q) => q.choices.indexOf(q.answer))
                .toList();
            final counts = List.generate(
              3,
              (slot) => slots.where((value) => value == slot).length,
            );
            singletons.add(counts.indexOf(1));
            firstPositions.add(slots.first);
            expect([...counts]..sort(), [1, 2, 2]);
            sequences.add(slots.join());
            for (final question in round.questions) {
              expect(question.choices.toSet().length, 3);
              expect(
                question.choices
                    .where((value) => value == question.answer)
                    .length,
                1,
              );
            }
          }
          expect(singletons, {0, 1, 2});
          expect(firstPositions, {0, 1, 2});
          expect(sequences.length, greaterThan(30));
        },
      );
    }
  }
}
