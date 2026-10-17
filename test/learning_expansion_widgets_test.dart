import 'package:rainbow_garden/number_range.dart';
import 'widget_test.dart' show nextLearningRound;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/letter_sounds.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/widgets/counting_board.dart';
import 'package:rainbow_garden/widgets/voice_button.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;
import 'settings_test.dart' show unlock;
import 'interface_refresh_test.dart' show target, answer;
import 'interface_layout_test.dart' show capture, loadCaptureFonts;

Future<ProgressController> open(
  WidgetTester tester,
  MemoryDevice device,
  Activity activity, {
  GameRound? round,
  ThemeMode theme = ThemeMode.light,
  GlobalKey? boundary,
  bool reduced = false,
}) async {
  final controller = ProgressController(device);
  await controller.load();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        theme: GardenTheme.light,
        darkTheme: GardenTheme.dark,
        themeMode: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: GamePage(
          services: device,
          activity: activity,
          sound: device.soundOn,
          controller: controller,
          countingMax: device.countingMax,
          sounds: device.sounds,
          round:
              round ??
              GameRound(
                activity,
                countingMax: device.countingMax,
                sounds: device.sounds,
                random: Random(7),
              ),
          onCompleteRound: controller.completeRound,
        ),
      ),
    ),
  );
  await settle(tester);
  return controller;
}

Future<void> buildGroup(WidgetTester tester, int quantity) async {
  final board = tester.widget<CountingBoard>(find.byType(CountingBoard));
  while (board.work.items.length > quantity) {
    await tapVisible(tester, find.byKey(const ValueKey('count-object-0')));
  }
  while (board.work.items.length < quantity) {
    await tapVisible(tester, find.byKey(const ValueKey('add-count-object')));
  }
}

void main() {
  setUpAll(loadCaptureFonts);
  for (final activity in [Activity.howMany, Activity.makeGroup]) {
    for (final manual in [true, false]) {
      testWidgets(
        '${activity.name}: silent full rounds, retry correction, reward and replay ($manual)',
        (tester) async {
          final device = MemoryDevice()..tapNext = manual;
          await open(tester, device, activity);
          expect(find.byType(VoiceButton), findsNothing);
          expect(find.text('Listen again'), findsNothing);
          for (var replay = 0; replay < 2; replay++) {
            for (var q = 0; q < 5; q++) {
              final number = int.parse(target(tester));
              if (activity == Activity.makeGroup) {
                await buildGroup(tester, (number + 1) % 11);
                await tapVisible(tester, find.text('Check'));
                expect(find.text('Try again'), findsOneWidget);
                await buildGroup(tester, number);
                await tapVisible(tester, find.text('Check'));
              } else {
                if (number > 0) {
                  final mark = find.byKey(const ValueKey('count-object-0'));
                  await tapVisible(tester, mark);
                  expect(
                    tester
                        .widget<CountingBoard>(find.byType(CountingBoard))
                        .work
                        .marked,
                    {0},
                  );
                  await tapVisible(tester, mark);
                  expect(
                    tester
                        .widget<CountingBoard>(find.byType(CountingBoard))
                        .work
                        .marked,
                    isEmpty,
                  );
                }
                await tapVisible(tester, answer('$number'));
              }
              if (q == 4) {
                expect(device.xp, (replay + 1) * 50);
                await tapVisible(tester, find.text('Rewards'));
              } else if (manual) {
                await tapVisible(tester, find.text('Next'));
              } else {
                await tester.pump(const Duration(milliseconds: 800));
                await tester.pump();
              }
            }
            expect(device.writes, replay + 1);
            expect(device.clips, isEmpty);
            if (replay == 0) await nextLearningRound(tester);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'sound-only targets replay; mute and audio failures never expose the picture without a hint',
    (tester) async {
      final device = MemoryDevice()
        ..sounds = SoundSelection(['m', 's', 't'])
        ..failAudio = true;
      final round = GameRound(
        Activity.letterSounds,
        sounds: device.sounds,
        random: Random(5),
      );
      await open(tester, device, Activity.letterSounds, round: round);
      expect(device.clips, isEmpty);
      expect(find.byType(Image), findsNothing);
      expect(
        find.text('Sound could not play. You can use the hint.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Show a hint'));
      expect(
        find.text(
          '${round.question.answer} — ${soundFor(round.question.answer).word}',
        ),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
      device.failAudio = false;
      await tapVisible(tester, find.text('Listen again'));
      expect(device.clips, [round.question.audio]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'counting Check stays available for zero and a failed fifth save retries once',
    (tester) async {
      final device = MemoryDevice();
      final controller = await open(tester, device, Activity.makeGroup);
      for (var i = 0; i < 5; i++) {
        final quantity = int.parse(target(tester));
        await buildGroup(tester, quantity);
        if (i == 4) device.failSave = true;
        await tapVisible(tester, find.text('Check'));
        if (i < 4) await tapVisible(tester, find.text('Next'));
      }
      expect(controller.blocked.value, isTrue);
      expect(device.xp, 0);
      final rewardButton = find.ancestor(
        of: find.text('Next round'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(tester.widget<FilledButton>(rewardButton).onPressed, isNull);
      device.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(device.xp, 50);
      expect(device.writes, 1);
      await tapVisible(tester, find.text('Rewards'));
      expect(device.writes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'sound edits autosave, prevent invalid removal, and survive Back',
    (tester) async {
      final device = MemoryDevice()
        ..sounds = SoundSelection(['c', 'k', 'a', 'm']);
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await unlock(tester);
      await tapVisible(tester, find.text('Letter Sounds'));
      expect(find.text('Clear letters'), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('sound-letter-a')));
      expect(device.sounds.enabled, {'c', 'k', 'a', 'm'});
      expect(
        find.text('Keep at least three different sounds.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const ValueKey('sound-letter-s')));
      await tapVisible(tester, find.byKey(const ValueKey('sound-letter-a')));
      expect(device.sounds.enabled, {'c', 'k', 'm', 's'});
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(device.sounds.enabled, {'c', 'k', 'm', 's'});
      expect(device.ranges.howMany, NumberRange.defaults);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final (name, size) in [
    ('small', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('new activities fit $name at $scale, dark=$dark', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          for (final activity in [
            Activity.letterSounds,
            Activity.howMany,
            Activity.makeGroup,
          ]) {
            final device = MemoryDevice()..countingMax = 20;
            final boundary = GlobalKey();
            GameRound? round;
            if (activity.isCounting) {
              for (var seed = 0; ; seed++) {
                final candidate = GameRound(
                  activity,
                  countingMax: 20,
                  random: Random(seed),
                );
                if (candidate.question.answer == '20') {
                  round = candidate;
                  break;
                }
              }
            }
            await open(
              tester,
              device,
              activity,
              round: round,
              boundary: boundary,
              theme: dark ? ThemeMode.dark : ThemeMode.light,
              reduced: scale == 2,
            );
            if (activity == Activity.makeGroup) await buildGroup(tester, 20);
            if (activity == Activity.letterSounds)
              await tapVisible(tester, find.text('Show a hint'));
            if (activity.isCounting) {
              await tester.ensureVisible(
                find.byKey(const ValueKey('counting-collection')),
              );
              await settle(tester);
              expect(
                tester
                    .getSize(find.byKey(const ValueKey('count-object-0')))
                    .width,
                greaterThanOrEqualTo(56),
              );
            }
            if (activity == Activity.makeGroup) {
              expect(find.text('Check').hitTestable(), findsOneWidget);
              expect(
                tester
                    .getRect(find.byKey(const ValueKey('check-counting')))
                    .bottom,
                lessThanOrEqualTo(size.height),
              );
            }
            expect(tester.takeException(), isNull);
            await capture(
              tester,
              boundary,
              '$name-${scale}x-${dark ? 'dark' : 'light'}-${activity.name}',
              directory: const String.fromEnvironment(
                'LEARNING_CAPTURE_DIR',
                defaultValue: '0180',
              ),
            );
            await tester.pumpWidget(const SizedBox());
          }
        });
      }
    }
  }
}
