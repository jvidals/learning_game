import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/decoding.dart';
import 'package:rainbow_garden/word_bank.dart';

int shared(String a, String b) =>
    List.generate(3, (i) => a[i] == b[i] ? 1 : 0).reduce((a, b) => a + b);

void main() {
  const slots = [2, 0, 1, 2, 0];
  test(
    'read targets are distinct and foils require reading beyond one letter',
    () {
      final positions = <int>{};
      for (var seed = 0; seed < 300; seed++) {
        final questions = buildReadAndFindQuestions(Random(seed), slots);
        expect(questions, hasLength(5));
        expect(questions.map((q) => q.answer).toSet(), hasLength(5));
        for (var i = 0; i < questions.length; i++) {
          final q = questions[i];
          expect(q.instruction, 'Read the word. Find its picture.');
          expect(q.choices.toSet(), hasLength(3));
          expect(q.choices[slots[i]], q.answer);
          expect(
            q.choices.map((c) => realWord(c).picture).toSet(),
            hasLength(3),
          );
          expect((q.visual as ReadAndFindVisual).word.spelling, q.answer);
          if (i > 0) {
            expect(
              realWord(q.answer).vowel,
              isNot(realWord(questions[i - 1].answer).vowel),
            );
          }
          final available = realWords.where(
            (w) => w.spelling != q.answer && shared(w.spelling, q.answer) > 0,
          );
          if (available.length >= 2) {
            for (final foil in q.choices.where((c) => c != q.answer)) {
              expect(shared(foil, q.answer), greaterThanOrEqualTo(1));
              for (var p = 0; p < 3; p++) {
                if (foil[p] == q.answer[p]) positions.add(p);
              }
            }
          }
        }
      }
      expect(positions, {0, 1, 2});
    },
  );

  test('pretend rounds retain exact foils and hide spellings in labels', () {
    for (var seed = 0; seed < 300; seed++) {
      final questions = buildMakeBelieveQuestions(Random(seed), slots);
      expect(questions, hasLength(5));
      expect(questions.map((q) => q.answer).toSet(), hasLength(5));
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final item = makeBelieveItems.firstWhere((w) => w.target == q.answer);
        expect(q.choices.toSet(), {item.target, ...item.foils});
        expect(q.choices[slots[i]], item.target);
        expect(q.instruction, 'Read the pretend word. Which sound matches?');
        expect(q.visual!.fullWidthChoices, isTrue);
        expect(q.visual!.selectThenCheck, isTrue);
        for (var j = 0; j < 3; j++) {
          expect(q.visual!.choiceLabel(q.choices[j]), 'Sound ${j + 1}');
          expect(
            q.visual!.choiceClip(q.choices[j]),
            makeBelieveWord(q.choices[j]).clip,
          );
          for (final spelling in q.choices) {
            expect(
              q.visual!.choiceLabel(q.choices[j]),
              isNot(contains(spelling)),
            );
          }
        }
      }
    }
  });
}
