import 'dart:io';
import 'package:rainbow_garden/sight_words.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/game.dart';

void main() {
  for (final activity in ActivityContent.recognition) {
    test(
      '${activity.name}: five unique targets, three valid choices, bundled audio',
      () {
        final coverage = <String>{};
        final positions = <int>{};
        for (var seed = 0; seed < 100; seed++) {
          final round = GameRound(activity, random: Random(seed));
          expect(round.questions.length, 5);
          expect(
            round.questions.map((q) => q.answer.toUpperCase()).toSet().length,
            5,
          );
          for (final q in round.questions) {
            expect(q.choices.toSet().length, 3);
            expect(q.choices.where((c) => c == q.answer).length, 1);
            if (activity.hasSpokenTarget) {
              expect(File('assets/audio/${q.audio}.wav').existsSync(), isTrue);
            } else {
              expect(q.audio, isEmpty);
            }
            coverage.add(q.answer.toUpperCase());
            positions.add(q.choices.indexOf(q.answer));
            if ((activity == Activity.numbers || activity.isCounting)) {
              expect(
                q.choices.map(int.parse),
                everyElement(inInclusiveRange(0, 10)),
              );
            } else if (activity == Activity.sightWords) {
              expect(
                q.choices,
                everyElement(isIn(SightWordPacks.defaults.words)),
              );
            } else {
              expect(q.choices, everyElement(matches(RegExp(r'^[A-Za-z]$'))));
            }
            if (activity == Activity.uppercase)
              expect(q.answer, q.answer.toUpperCase());
            if (activity == Activity.lowercase)
              expect(q.answer, q.answer.toLowerCase());
            if (activity == Activity.matching) {
              expect(q.partner!.toLowerCase(), q.answer.toLowerCase());
              expect(q.partner, isNot(q.answer));
            }
          }
        }
        expect(
          coverage.length,
          (activity == Activity.numbers || activity.isCounting)
              ? 11
              : activity == Activity.letterSounds
              ? 24
              : activity == Activity.sightWords
              ? 8
              : 26,
        );
        expect(positions, {0, 1, 2});
      },
    );
  }

  test('matching includes both directions in each round', () {
    final round = GameRound(Activity.matching, random: Random(4));
    expect(
      round.questions.any((q) => q.answer == q.answer.toLowerCase()),
      isTrue,
    );
    expect(
      round.questions.any((q) => q.answer == q.answer.toUpperCase()),
      isTrue,
    );
  });

  test(
    'retries preserve progress, double taps cannot score, five finds finish',
    () {
      final round = GameRound(Activity.uppercase, random: Random(1));
      expect(round.next(), isFalse);
      expect(round.choose('?'), AnswerResult.ignored);
      for (var i = 0; i < 5; i++) {
        final q = round.question;
        expect(
          round.choose(q.choices.firstWhere((c) => c != q.answer)),
          AnswerResult.retry,
        );
        expect(round.completed, i);
        expect(round.question, same(q));
        expect(round.choose(q.answer), AnswerResult.correct);
        expect(round.choose(q.answer), AnswerResult.ignored);
        expect(round.completed, i + 1);
        expect(round.finished, i == 4);
        expect(round.next(), i != 4);
      }
      expect(round.completed, 5);
    },
  );

  test(
    'bundled audio files contain PCM samples and no prompts are missing',
    () {
      final files = Directory(
        'assets/audio',
      ).listSync().whereType<File>().toList();
      final phrases =
          jsonDecode(File('assets/audio_phrases.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(phrases.length, 221);
      expect(
        files.map((file) => file.uri.pathSegments.last).toSet(),
        phrases.keys.map((key) => '$key.wav').toSet(),
      );
      for (final file in files) {
        final bytes = file.readAsBytesSync();
        expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
        expect(bytes.length, greaterThan(1000));
      }
    },
  );
}
