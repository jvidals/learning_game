import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/sight_words.dart';

void main() {
  test('catalog preserves all 43 words, case, pack membership and audio IDs', () {
    final expected = [
      'the a see I to by my go',
      'is no you has he she put me with good his very her',
      'here of are was be do look want for they too have some we more or where come from as that our',
    ];
    final phrases =
        jsonDecode(File('assets/audio_phrases.json').readAsStringSync()) as Map;
    for (final pack in SightWordPack.values) {
      expect(pack.words, expected[pack.index].split(' '));
      for (final word in pack.words) {
        expect(phrases['word_${word.toLowerCase()}'], 'Find the word, $word.');
        expect(
          File('assets/audio/word_${word.toLowerCase()}.wav').existsSync(),
          isTrue,
        );
      }
    }
    final all = SightWordPacks(SightWordPack.values).words;
    expect(all.length, 43);
    expect(all.toSet().length, 43);
    expect(GameCategory.words.activities, [Activity.sightWords]);
    expect(Activity.sightWords.isRecognition, isTrue);
  });

  for (var mask = 1; mask < 8; mask++) {
    test(
      'pack combination $mask keeps every question in its pool with balanced positions',
      () {
        final packs = SightWordPacks([
          for (final pack in SightWordPack.values)
            if (mask & (1 << pack.index) != 0) pack,
        ]);
        final coverage = <String>{};
        final singletons = <int>{};
        final sequences = <String>{};
        for (var seed = 0; seed < 1000; seed++) {
          final round = GameRound(
            Activity.sightWords,
            random: Random(seed),
            wordPacks: packs,
          );
          expect(round.questions.map((q) => q.answer).toSet().length, 5);
          final slots = <int>[];
          for (final question in round.questions) {
            expect(question.choices.toSet().length, 3);
            expect(question.choices, everyElement(isIn(packs.words)));
            expect(question.audio, 'word_${question.answer.toLowerCase()}');
            expect(question.partner, isNull);
            slots.add(question.choices.indexOf(question.answer));
            coverage.add(question.answer);
          }
          final counts = List.generate(
            3,
            (i) => slots.where((s) => s == i).length,
          );
          expect([...counts]..sort(), [1, 2, 2]);
          singletons.add(counts.indexOf(1));
          sequences.add(slots.join());
        }
        expect(coverage, packs.words.toSet());
        expect(singletons, {0, 1, 2});
        expect(sequences.length, greaterThan(30));
      },
    );
  }

  test('settings default only when absent and round-trip stable pack IDs', () {
    expect(AppSettings.fromMap({}).enabledSightWordPacks.enabled, {
      SightWordPack.pack1,
    });
    final selected = SightWordPacks([SightWordPack.pack2, SightWordPack.pack3]);
    final settings = AppSettings(enabledSightWordPacks: selected);
    expect(settings.toMap()['enabledSightWordPacks'], ['pack2', 'pack3']);
    expect(
      AppSettings.fromMap(settings.toMap()).enabledSightWordPacks.enabled,
      selected.enabled,
    );
    expect(
      settings.withSound(false).enabledSightWordPacks.enabled,
      selected.enabled,
    );
    expect(
      settings.withOrderingCase(true).enabledSightWordPacks.enabled,
      selected.enabled,
    );
    expect(() => selected.enabled.clear(), throwsUnsupportedError);
    expect(() => selected.words.clear(), throwsUnsupportedError);
    expect(() => SightWordPacks([]), throwsArgumentError);
    for (final invalid in [
      [],
      ['pack4'],
      ['pack1', 3],
      'pack1',
    ]) {
      expect(() => SightWordPacks.fromValue(invalid), throwsFormatException);
    }
  });
}
