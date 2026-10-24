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

const activity4NewSpellings = {
  'tuz',
  'rup',
  'hos',
  'fec',
  'gob',
  'sis',
  'bap',
  'yek',
  'fon',
  'nop',
  'hap',
  'bef',
  'din',
  'lod',
  'tep',
  'paz',
  'gik',
  'pev',
  'fab',
  'neb',
  'lim',
  'yik',
  'min',
  'pag',
  'yun',
  'sid',
  'tix',
  'piz',
  'dax',
  'roz',
  'yon',
  'kim',
  'tiv',
  'fez',
  'ris',
  'dap',
  'dod',
};

const activity4Spellings = {
  'tuz',
  'rup',
  'vab',
  'hos',
  'bem',
  'fec',
  'gob',
  'sis',
  'bap',
  'yek',
  'fon',
  'nop',
  'hap',
  'bef',
  'din',
  'lod',
  'tep',
  'paz',
  'gik',
  'pok',
  'pev',
  'fab',
  'neb',
  'lim',
  'yik',
  'min',
  'pag',
  'yun',
  'lix',
  'nuv',
  'sid',
  'tix',
  'piz',
  'dax',
  'tik',
  'roz',
  'yon',
  'kim',
  'tiv',
  'sut',
  'fez',
  'ris',
  'hif',
  'dap',
  'dod',
};

const sprintOnlySpellings = {...activity2Spellings, ...activity4NewSpellings};

void main() {
  test('runs contain 48 words', () {
    expect(wordSprintSessionLength, 48);
  });

  test('Activity 2 and 4 words need only existing letter-sound recordings', () {
    final manifest =
        jsonDecode(File('assets/audio_manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      sprintOnlyPretendWords.map((w) => w.spelling).toSet(),
      sprintOnlySpellings,
    );
    expect(sprintOnlyPretendWords, hasLength(59));
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

  test('worksheet words extend only the Word Sprint pretend pool', () {
    final targets = makeBelieveItems.map((item) => item.target).toSet();
    final pretendPool = {
      ...targets,
      ...sprintOnlyPretendWords.map((word) => word.spelling),
    };
    expect(activity4NewSpellings, hasLength(37));
    expect(activity4Spellings, hasLength(45));
    expect(pretendPool, hasLength(83));
    expect(pretendPool, containsAll(activity4Spellings));
    expect(targets, hasLength(24));
    expect(targets.intersection(sprintOnlySpellings), isEmpty);
    expect(
      realWords
          .map((word) => word.spelling)
          .toSet()
          .intersection(sprintOnlySpellings),
      isEmpty,
    );
    expect(const DecodableWord('fec').letterSounds, [
      ['sound_f'],
      ['sound_e'],
      ['sound_k'],
    ]);
    expect(const DecodableWord('tix').letterSounds, [
      ['sound_t'],
      ['sound_i'],
      ['sound_k', 'sound_s'],
    ]);
  });

  for (final mode in WordSprintMode.values) {
    test('${mode.name} cycles its shuffled pool without adjacent repeats', () {
      final pool = switch (mode) {
        WordSprintMode.realWords => realWords.map((w) => w.spelling).toSet(),
        WordSprintMode.makeBelieve => {
          ...makeBelieveItems.map((w) => w.target),
          ...sprintOnlySpellings,
        },
        WordSprintMode.mix => {
          ...realWords.map((w) => w.spelling),
          ...makeBelieveItems.map((w) => w.target),
          ...sprintOnlySpellings,
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
            session.words.any((w) => sprintOnlySpellings.contains(w.spelling)),
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
