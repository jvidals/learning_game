import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/number_sense.dart';

void checkChoices(Question question, int slot) {
  final values = question.choices.map(int.parse).toList();
  final answer = int.parse(question.answer);
  expect(values.toSet(), hasLength(3));
  expect(values.every((n) => n >= 0 && n <= 10), isTrue);
  expect(values[slot], answer);
  expect(values.every((n) => (n - answer).abs() <= 2), isTrue);
  expect(question.audio, isEmpty);
  expect(question.visual!.selectThenCheck, isFalse);
  for (final choice in question.choices) {
    expect(question.visual!.choiceClip(choice), isNull);
  }
}

void main() {
  const slots = [2, 0, 1, 2, 0];

  test(
    'same number rotates representations and keeps close distinct choices',
    () {
      final targets = <int>{};
      final shapes = <NumberShape>{};
      var zeroRounds = 0;
      for (var seed = 0; seed < 500; seed++) {
        final questions = buildSameNumberQuestions(Random(seed), slots);
        expect(questions, hasLength(5));
        final kinds = <NumberRepresentation>[];
        var zeros = 0;
        for (var i = 0; i < questions.length; i++) {
          final q = questions[i];
          final v = q.visual! as SameNumberVisual;
          checkChoices(q, slots[i]);
          expect(q.instruction, 'Find the same number.');
          expect(int.parse(q.answer), v.quantity);
          kinds.add(v.missingKind);
          shapes.add(v.shape);
          targets.add(v.quantity);
          zeros += v.quantity == 0 ? 1 : 0;
          if (v.quantity != 0) expect(q.choices, isNot(contains('0')));
        }
        expect(kinds.toSet(), NumberRepresentation.values.toSet());
        for (var i = 1; i < kinds.length; i++) {
          expect(kinds[i], isNot(kinds[i - 1]));
        }
        expect(zeros, lessThanOrEqualTo(1));
        zeroRounds += zeros;
      }
      expect(targets, List.generate(11, (n) => n).toSet());
      expect(shapes, NumberShape.values.toSet());
      expect(zeroRounds, inInclusiveRange(1, 150));
    },
  );

  test(
    'parts progresses from one small whole to larger wholes and make ten',
    () {
      final splits = <String>{};
      for (var seed = 0; seed < 500; seed++) {
        final questions = buildNumberPartsQuestions(Random(seed), slots);
        expect(questions, hasLength(5));
        final visuals = questions
            .map((q) => q.visual! as NumberPartsVisual)
            .toList();
        expect(visuals[0].total, inInclusiveRange(2, 5));
        expect(visuals[1].total, visuals[0].total);
        expect(visuals[1].part, isNot(visuals[0].part));
        expect(visuals[1].part, isNot(visuals[0].missing));
        for (final v in visuals.skip(2).take(2)) {
          expect(v.total, inInclusiveRange(6, 10));
        }
        expect(visuals[4].makeTen, isTrue);
        expect(visuals[4].total, 10);
        expect(visuals.take(4).every((v) => !v.makeTen), isTrue);
        expect(
          visuals.where((v) => v.part == 0 || v.missing == 0).length,
          lessThanOrEqualTo(1),
        );
        for (var i = 0; i < questions.length; i++) {
          final q = questions[i];
          final v = visuals[i];
          checkChoices(q, slots[i]);
          expect(v.fullWidthChoices, isFalse);
          expect(v.part, inInclusiveRange(0, v.total));
          expect(v.part + int.parse(q.answer), v.total);
          expect(v.missing, int.parse(q.answer));
          expect(q.instruction, i == 4 ? 'Make 10.' : 'Find the missing part.');
          splits.add('${v.part}+${v.missing}');
        }
      }
      expect(splits, containsAll(['0+5', '5+0', '2+3', '4+1', '1+9', '9+1']));
    },
  );

  test(
    'seeded scene data is stable and choice labels only name representations',
    () {
      final a = buildSameNumberQuestions(Random(23), slots);
      final b = buildSameNumberQuestions(Random(23), slots);
      for (var i = 0; i < a.length; i++) {
        final v = a[i].visual! as SameNumberVisual;
        final other = b[i].visual! as SameNumberVisual;
        expect(
          [v.quantity, v.missingKind, v.shape, v.seed],
          [other.quantity, other.missingKind, other.shape, other.seed],
        );
        expect(a[i].choices, b[i].choices);
        final expected = switch (v.missingKind) {
          NumberRepresentation.numeral => 'Number 7',
          NumberRepresentation.tenFrame => 'Ten frame showing 7',
          NumberRepresentation.picture => '7 ${v.shape.plural}',
        };
        expect(v.choiceLabel('7'), expected);
      }
      expect(
        const NumberPartsVisual(total: 10, part: 3).choiceLabel('7'),
        '7 circles',
      );
      expect(
        const NumberPartsVisual(total: 10, part: 3).choiceLabel('0'),
        'no dots',
      );
    },
  );
}
