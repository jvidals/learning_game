import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/word_bank.dart';
import 'package:rainbow_garden/word_sprint.dart';

void main() {
  for (final mode in WordSprintMode.values) {
    test('${mode.name} cycles its shuffled pool without adjacent repeats', () {
      final pool = switch (mode) {
        WordSprintMode.realWords => realWords.map((w) => w.spelling).toSet(),
        WordSprintMode.makeBelieve =>
          makeBelieveItems.map((w) => w.target).toSet(),
        WordSprintMode.mix => {
          ...realWords.map((w) => w.spelling),
          ...makeBelieveItems.map((w) => w.target),
        },
      };
      for (var seed = 0; seed < 30; seed++) {
        final session = WordSprintSession(mode: mode, random: Random(seed));
        expect(session.words, hasLength(60));
        expect(session.words.every((w) => pool.contains(w.spelling)), isTrue);
        expect(
          session.words.take(pool.length).map((w) => w.spelling).toSet(),
          pool,
        );
        for (var i = 1; i < session.words.length; i++) {
          expect(
            session.words[i].spelling,
            isNot(session.words[i - 1].spelling),
          );
        }
      }
    });
  }

  test('Mix is default and an injected random gives repeatable sessions', () {
    final a = WordSprintSession(random: Random(7));
    final b = WordSprintSession(random: Random(7));
    expect(a.mode, WordSprintMode.mix);
    expect(a.words.map((w) => w.spelling), b.words.map((w) => w.spelling));
    expect(a.words.any((w) => w.real), isTrue);
    expect(a.words.any((w) => !w.real), isTrue);
  });

  test('mark toggles each position independently and finish freezes marks', () {
    final session = WordSprintSession(random: Random(2));
    expect(session.count, 0);
    session.mark(0);
    session.mark(1);
    expect(session.count, 2);
    expect(session.isMarked(0), isTrue);
    session.mark(0);
    expect(session.count, 1);
    expect(session.isMarked(0), isFalse);
    session.finish();
    session.mark(0);
    session.mark(1);
    expect(session.finished, isTrue);
    expect(session.count, 1);
    expect(session.isMarked(1), isTrue);
  });
}
