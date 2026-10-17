import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/game.dart';

void main() {
  test('range validation and legacy/corrupt settings default safely', () {
    expect(NumberRange.fromMap(null), NumberRange.defaults);
    for (final map in [
      <String, dynamic>{},
      {'min': '0', 'max': 10},
      {'min': 10, 'max': 2},
      {'min': -1, 'max': 10},
      {'min': 0, 'max': 101},
    ]) {
      expect(NumberRange.fromMap(map), NumberRange.defaults);
    }
    for (final ends in [
      [-1, 10],
      [0, 101],
      [4, 5],
      [5, 4],
    ]) {
      expect(() => NumberRange(ends[0], ends[1]), throwsArgumentError);
    }
    final range = NumberRange(20, 30);
    expect(NumberRange.fromMap(range.toMap()), range);
  });
  for (final range in [
    NumberRange.defaults,
    NumberRange(20, 30),
    NumberRange(0, 100),
    NumberRange(98, 100),
    NumberRange(20, 23),
  ]) {
    test(
      '${range.label}: exhaust pool before repeats and always offer three valid choices',
      () {
        final coverage = <String>{};
        for (var seed = 0; seed < 200; seed++) {
          final round = GameRound(
            Activity.numbers,
            numberRange: range,
            random: Random(seed),
          );
          final targets = round.questions.map((q) => q.answer).toList();
          expect(targets.length, 5);
          expect(
            targets.take(min(5, range.count)).toSet().length,
            min(5, range.count),
          );
          for (var i = 1; i < targets.length; i++) {
            expect(targets[i], isNot(targets[i - 1]));
          }
          for (final question in round.questions) {
            coverage.add(question.answer);
            expect(question.choices.toSet().length, 3);
            expect(question.choices, contains(question.answer));
            expect(
              question.choices.map(int.parse),
              everyElement(inInclusiveRange(range.min, range.max)),
            );
            expect(question.audio, 'number_${question.answer}');
          }
        }
        expect(coverage.length, range.count);
      },
    );
  }
}
