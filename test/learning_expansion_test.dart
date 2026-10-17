import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/counting.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/letter_sounds.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'widget_test.dart' show MemoryDevice;

void main() {
  test(
    'sound selection validates distinct sounds and malformed saved data',
    () {
      expect(() => SoundSelection(['c', 'k', 'a']), throwsArgumentError);
      expect(() => SoundSelection(['q', 's', 't']), throwsArgumentError);
      expect(SoundSelection(['c', 'k', 'a', 'm']).letters, [
        'a',
        'c',
        'k',
        'm',
      ]);
      for (final value in [
        null,
        [],
        ['m'],
        ['m', 's', 2],
        ['m', 's', 'x'],
      ]) {
        expect(() => SoundSelection.fromValue(value), throwsFormatException);
      }
    },
  );

  test(
    'all supported letters have exactly one valid answer even with c/k enabled',
    () {
      final selection = SoundSelection(['a', 'c', 'k', 'm']);
      final seen = <String>{};
      for (var seed = 0; seed < 500; seed++) {
        final round = GameRound(
          Activity.letterSounds,
          sounds: selection,
          random: Random(seed),
        );
        for (final q in round.questions) {
          seen.add(q.answer);
          expect(q.choices, everyElement(isIn(selection.letters)));
          expect(
            q.choices.where(
              (c) => soundFor(c).phoneme == soundFor(q.answer).phoneme,
            ),
            [q.answer],
          );
          expect(q.audio, soundFor(q.answer).audio);
          expect(q.choices.toSet().length, 3);
          expect(q.choices.map((c) => soundFor(c).phoneme).toSet().length, 3);
        }
      }
      expect(seen, selection.enabled);
    },
  );

  for (final maximum in [5, 10, 20]) {
    for (final activity in [Activity.howMany, Activity.makeGroup]) {
      test(
        '${activity.name} covers zero through $maximum independently of numeral range',
        () {
          final seen = <int>{};
          for (var seed = 0; seed < 100; seed++) {
            final round = GameRound(
              activity,
              countingMax: maximum,
              numberRange: NumberRange(90, 100),
              random: Random(seed),
            );
            expect(round.questions.map((q) => q.answer).toSet().length, 5);
            for (final q in round.questions) {
              seen.add(int.parse(q.answer));
              expect(q.audio, isEmpty);
              expect(q.counting!.quantity, int.parse(q.answer));
              expect(
                q.choices.map(int.parse),
                everyElement(inInclusiveRange(0, maximum)),
              );
              if (q.counting!.quantity > 10) {
                expect(q.counting!.arrangement, CountingArrangement.frame);
              }
            }
          }
          expect(seen, Set.of(List.generate(maximum + 1, (i) => i)));
        },
      );
    }
  }

  test(
    'marking is reversible and collection adds/removals cannot exceed capacity',
    () {
      final work = CountingWork(5);
      work.toggleMark(2);
      work.toggleMark(3);
      work.toggleMark(2);
      expect(work.marked, {3});
      for (var i = 0; i < 5; i++) {
        expect(work.add(), isTrue);
      }
      expect(work.add(), isFalse);
      final removed = work.items[2];
      expect(work.remove(removed), isTrue);
      expect(work.remove(removed), isFalse);
      expect(work.add(), isTrue);
      expect(work.items.toSet().length, 5);
      expect(work.items, isNot(contains(removed)));
    },
  );

  test(
    'Make a group accepts any checked quantity and rewards the exact target once',
    () {
      final round = GameRound(Activity.makeGroup, random: Random(4));
      expect(round.choose('-1'), AnswerResult.ignored);
      expect(round.choose('abc'), AnswerResult.ignored);
      final target = int.parse(round.question.answer);
      expect(round.choose('${(target + 1) % 11}'), AnswerResult.retry);
      expect(round.completed, 0);
      expect(round.choose('$target'), AnswerResult.correct);
      expect(round.choose('$target'), AnswerResult.ignored);
    },
  );

  test(
    'settings round-trip, legacy defaults, and helpers preserve both new settings',
    () {
      final settings = AppSettings(
        enabledLetterSounds: SoundSelection(['m', 's', 't']),
        numberGameRanges: NumberGameRanges.fromLegacy(NumberRange.defaults, 20),
      );
      final decoded = AppSettings.fromMap(
        settings.toMap(),
      ).withSound(false).withOrderingCase(true);
      expect(decoded.enabledLetterSounds.enabled, {'m', 's', 't'});
      expect(decoded.numberGameRanges.howMany.max, 20);
      expect(AppSettings.fromMap({}).numberGameRanges.howMany.max, 10);
      expect(AppSettings.fromMap({}).enabledLetterSounds.letters.length, 24);
      for (final value in [null, 0, 7, 100, '10']) {
        expect(
          () => AppSettings.fromMap({'countingMax': value}),
          throwsFormatException,
        );
      }
      expect(
        () => AppSettings.fromMap({'enabledLetterSounds': null}),
        throwsFormatException,
      );
    },
  );

  test(
    'failed settings retain player, retry and reset preserve selected content',
    () async {
      final device = MemoryDevice();
      final controller = ProgressController(device);
      await controller.load();
      final original = controller.activeProfile!.id;
      final settings = AppSettings(
        numberGameRanges: NumberGameRanges.fromLegacy(NumberRange.defaults, 20),
        enabledLetterSounds: SoundSelection(['m', 's', 't']),
      );
      device.failSave = true;
      await expectLater(controller.saveSettings(settings), throwsStateError);
      expect(controller.blocked.value, isTrue);
      expect(controller.settings.numberGameRanges.howMany.max, 10);
      await expectLater(controller.addProfile('Other'), throwsStateError);
      device.failSave = false;
      await controller.retry();
      await controller.setSound(false);
      await controller.reset();
      expect(controller.settings.numberGameRanges.howMany.max, 20);
      expect(controller.settings.enabledLetterSounds.enabled, {'m', 's', 't'});
      await controller.addProfile('Other');
      expect(controller.settings.numberGameRanges.howMany.max, 10);
      expect(controller.settings.enabledLetterSounds.letters.length, 24);
      await controller.selectProfile(original);
      expect(controller.settings.numberGameRanges.howMany.max, 20);
      controller.dispose();
      final reopened = ProgressController(device);
      await reopened.load();
      expect(reopened.settings.enabledLetterSounds.enabled, {'m', 's', 't'});
      reopened.dispose();
    },
  );
}
