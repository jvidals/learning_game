import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/word_bank.dart';
import 'package:rainbow_garden/word_sprint.dart';

const activity2Spellings = {
  'fod',
  'hif',
  'wum',
  'lif',
  'nen',
  'pem',
  'vab',
  'nuv',
  'yez',
  'pob',
  'bem',
  'yuc',
  'sut',
  'tef',
  'jub',
  'rez',
  'juf',
  'bik',
  'nem',
  'lix',
  'wob',
  'vup',
};

void main() {
  test('runs contain 48 words', () {
    expect(wordSprintSessionLength, 48);
  });

  test('Activity 2 words need only existing letter-sound recordings', () {
    final manifest =
        jsonDecode(File('assets/audio_manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      sprintOnlyPretendWords.map((w) => w.spelling).toSet(),
      activity2Spellings,
    );
    expect(sprintOnlyPretendWords, hasLength(22));
    for (final word in sprintOnlyPretendWords) {
      expect(word.real, isFalse);
      expect(word.picture, isNull);
      expect(word.spelling, matches(RegExp(r'^[a-z][aeiou][a-z]$')));
      expect(word.spelling, isNot(contains('q')));
      expect(word.letterSounds, hasLength(3));
      for (final sounds in word.letterSounds) {
        expect(sounds, isNotEmpty);
        for (final clip in sounds) {
          expect(clip, startsWith('sound_'));
          expect(manifest, contains(clip));
        }
      }
    }
  });

  for (final mode in WordSprintMode.values) {
    test('${mode.name} cycles its shuffled pool without adjacent repeats', () {
      final pool = switch (mode) {
        WordSprintMode.realWords => realWords.map((w) => w.spelling).toSet(),
        WordSprintMode.makeBelieve => {
          ...makeBelieveItems.map((w) => w.target),
          ...activity2Spellings,
        },
        WordSprintMode.mix => {
          ...realWords.map((w) => w.spelling),
          ...makeBelieveItems.map((w) => w.target),
          ...activity2Spellings,
        },
      };
      final seen = <String>{};
      for (var seed = 0; seed < 100; seed++) {
        final session = WordSprintSession(mode: mode, random: Random(seed));
        expect(session.words, hasLength(wordSprintSessionLength));
        expect(session.words.every((w) => pool.contains(w.spelling)), isTrue);
        seen.addAll(session.words.map((w) => w.spelling));
        final cycleLength = min(pool.length, wordSprintSessionLength);
        expect(
          session.words.take(cycleLength).map((w) => w.spelling).toSet(),
          hasLength(cycleLength),
        );
        expect(
          session.words.every(
            (w) =>
                w.real == realWords.any((real) => real.spelling == w.spelling),
          ),
          isTrue,
        );
        if (mode == WordSprintMode.realWords) {
          expect(
            session.words.any((w) => activity2Spellings.contains(w.spelling)),
            isFalse,
          );
        }
        for (var i = 1; i < session.words.length; i++) {
          expect(
            session.words[i].spelling,
            isNot(session.words[i - 1].spelling),
          );
        }
      }
      expect(seen, pool);
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
