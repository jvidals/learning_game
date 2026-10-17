import 'widget_test.dart' show nextLearningRound;
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/sight_words.dart';
import 'settings_test.dart' show unlock;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;
import 'interface_layout_test.dart' show capture, captureApp;
import 'interface_refresh_test.dart' show target, answer;

Finder pack(SightWordPack value) =>
    find.byKey(ValueKey('word-pack-${value.name}'));

class PendingSettingsDevice extends MemoryDevice {
  Completer<void>? pending;
  @override
  Future<void> saveSettings(AppSettings value) async {
    await pending?.future;
    await super.saveSettings(value);
  }
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_REFRESH')) {
      await FoalAssets.load();
    }
    // Real text metrics are essential for word fitting at 200% text.
    final fonts = Directory(
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
    );
    for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final weight
          in family == 'MaterialIcons'
              ? ['Regular']
              : ['Regular', 'Medium', 'Bold', 'Black']) {
        loader.addFont(
          File(
            '${fonts.path}/${family == 'MaterialIcons' ? 'MaterialIcons' : 'Roboto'}-$weight.${family == 'MaterialIcons' ? 'otf' : 'ttf'}',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });

  testWidgets(
    'last pack stays selected with an accessible explanation; Back keeps valid edits',
    (tester) async {
      final device = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await unlock(tester);
      expect(pack(SightWordPack.pack1).hitTestable(), findsNothing);
      await tapVisible(tester, find.text('Sight Word packs'));
      expect(
        tester.widget<CheckboxListTile>(pack(SightWordPack.pack1)).value,
        isTrue,
      );
      await tapVisible(tester, pack(SightWordPack.pack1));
      final error = find.text('Keep at least one pack.');
      expect(error, findsOneWidget);
      expect(
        tester.widget<Text>(error).style!.color,
        Theme.of(tester.element(error)).colorScheme.error,
      );
      expect(
        tester
            .widget<Semantics>(
              find.ancestor(of: error, matching: find.byType(Semantics)).first,
            )
            .properties
            .liveRegion,
        isTrue,
      );
      expect(
        tester.widget<CheckboxListTile>(pack(SightWordPack.pack1)).value,
        isTrue,
      );
      expect(device.settingsWrites, 0);
      expect(pack(SightWordPack.pack1), findsOneWidget);
      await tapVisible(tester, pack(SightWordPack.pack3));
      expect(error, findsNothing);
      await tapVisible(tester, pack(SightWordPack.pack1));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(device.wordPacks.enabled, {SightWordPack.pack3});
      await unlock(tester);
      await tapVisible(tester, find.text('Sight Word packs'));
      await tapVisible(tester, pack(SightWordPack.pack2));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(device.wordPacks.enabled, {
        SightWordPack.pack2,
        SightWordPack.pack3,
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await tapVisible(tester, find.text('Words'));
      await tapVisible(tester, find.text('Sight Words'));
      expect(device.clips.last, startsWith('word_'));
      expect(tester.widget<GamePage>(find.byType(GamePage)).wordPacks.enabled, {
        SightWordPack.pack2,
        SightWordPack.pack3,
      });
    },
  );

  testWidgets(
    'failed pack save retains its exact snapshot and preserves packs through other settings and reset',
    (tester) async {
      final device = PendingSettingsDevice()..xp = 350;
      final controller = ProgressController(device);
      await controller.load();
      final selected = SightWordPacks([SightWordPack.pack2]);
      device.pending = Completer<void>();
      final save = controller.saveSettings(
        AppSettings(enabledSightWordPacks: selected, soundOn: false),
      );
      final failed = expectLater(save, throwsStateError);
      expect(controller.blocked.value, isTrue);
      expect(controller.settings.enabledSightWordPacks.enabled, {
        SightWordPack.pack1,
      });
      await expectLater(controller.setSound(false), throwsStateError);
      device.failSave = true;
      device.pending!.complete();
      await failed;
      expect(controller.blocked.value, isTrue);
      device.pending = null;
      device.failSave = false;
      await controller.retry();
      await controller.setSound(true);
      await controller.saveSettings(controller.settings.withOrderingCase(true));
      await controller.reset();
      expect(device.wordPacks.enabled, {SightWordPack.pack2});
      expect(device.soundOn, isTrue);
      expect(device.orderingLowercase, isTrue);
      expect(device.xp, 0);
      controller.dispose();
    },
  );

  testWidgets(
    'failed automatic settings can be retried after leaving parent settings',
    (tester) async {
      final device = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await unlock(tester);
      await tapVisible(tester, find.text('Sight Word packs'));
      device.failSave = true;
      await tapVisible(tester, pack(SightWordPack.pack2));
      await tapVisible(tester, pack(SightWordPack.pack1));
      expect(device.wordPacks.enabled, {SightWordPack.pack1});
      expect(
        find.text('Your changes could not be saved yet. Try saving again.'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      device.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(device.wordPacks.enabled, {SightWordPack.pack2});
      await tapVisible(tester, find.text('Words'));
      await tapVisible(tester, find.text('Sight Words'));
      expect(tester.widget<GamePage>(find.byType(GamePage)).wordPacks.enabled, {
        SightWordPack.pack2,
      });
    },
  );

  testWidgets(
    'word audio failure keeps hint explicit; interrupted automatic pacing cancels and fifth answer waits',
    (tester) async {
      final device = MemoryDevice()
        ..tapNext = false
        ..failAudio = true;
      final controller = ProgressController(device);
      await controller.load();
      final packs = SightWordPacks([SightWordPack.pack3]);
      final round = GameRound(
        Activity.sightWords,
        wordPacks: packs,
        random: Random(11),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GamePage(
            activity: Activity.sightWords,
            services: device,
            sound: true,
            controller: controller,
            wordPacks: packs,
            round: round,
            onCompleteRound: controller.completeRound,
          ),
        ),
      );
      await settle(tester);
      expect(
        find.text('Sound could not play. You can use the hint.'),
        findsOneWidget,
      );
      expect(find.text('Find ${round.question.answer}'), findsNothing);
      await tapVisible(tester, find.text('Show a hint'));
      expect(find.text('Find ${round.question.answer}'), findsOneWidget);
      device.failAudio = false;
      await tapVisible(tester, find.text('Listen again'));
      expect(device.clips.last, round.question.audio);
      await tester.ensureVisible(answer(round.question.answer));
      await tester.tap(answer(round.question.answer));
      await tester.pump(const Duration(milliseconds: 400));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(round.completed, 1);
      expect(round.answered, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 799));
      expect(round.answered, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(round.answered, isFalse);
      for (var question = 1; question < 5; question++) {
        final value = round.question.answer;
        await tester.ensureVisible(answer(value));
        await tester.tap(answer(value));
        await tester.pump();
        await tester.tap(answer(value));
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
      }
      expect(device.xp, 50);
      expect(device.writes, 1);
      expect(find.text('Rewards'), findsOneWidget);
      expect(find.text('50 XP earned!'), findsOneWidget);
      await tapVisible(tester, find.text('Rewards'));
      expect(find.text('50 XP earned!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  for (final (name, size) in [
    ('small-phone', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final (packName, selectedPacks) in [
        ('pack1', SightWordPacks.defaults),
        ('all-packs', SightWordPacks(SightWordPack.values)),
      ]) {
        testWidgets(
          'Words, packs and whole-word choices stay vertical for $packName on $name at ${scale}x text',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final device = MemoryDevice()..wordPacks = selectedPacks;
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(key: key, child: captureApp(device)),
            );
            await settle(tester);
            await unlock(tester);
            await tapVisible(tester, find.text('Sight Word packs'));
            for (final p in SightWordPack.values) {
              await tester.ensureVisible(pack(p));
              await settle(tester);
              expect(tester.getSize(pack(p)).height, greaterThanOrEqualTo(48));
              expect(tester.takeException(), isNull);
            }
            await tester.ensureVisible(find.text('Sight Word packs'));
            await settle(tester);
            await tester.binding.handlePopRoute();
            await settle(tester);
            await tapVisible(tester, find.text('Words'));
            await tapVisible(tester, find.text('Sight Words'));
            // Play and replay a full round, checking every choice and pack snapshot.
            for (var replay = 0; replay < 2; replay++) {
              expect(
                tester
                    .widget<GamePage>(find.byType(GamePage))
                    .wordPacks
                    .words
                    .length,
                selectedPacks.words.length,
              );
              for (var question = 0; question < 5; question++) {
                final choices = tester
                    .widgetList<FilledButton>(find.byType(FilledButton))
                    .where(
                      (button) =>
                          button.key is ValueKey<String> &&
                          (button.key! as ValueKey<String>).value.startsWith(
                            'choice-',
                          ),
                    )
                    .toList();
                expect(choices.length, 3);
                final cardBounds = choices
                    .map((choice) => tester.getRect(find.byKey(choice.key!)))
                    .toList();
                for (var index = 0; index < cardBounds.length; index++) {
                  expect(
                    cardBounds[index].width,
                    closeTo(min(size.width - 40, 680), .01),
                  );
                  expect(
                    cardBounds[index].left,
                    closeTo(cardBounds.first.left, .01),
                  );
                  if (index > 0) {
                    expect(
                      cardBounds[index].top,
                      closeTo(cardBounds[index - 1].bottom + 12, .01),
                    );
                  }
                }
                for (final choice in choices) {
                  final finder = find.byKey(choice.key!);
                  await tester.ensureVisible(finder);
                  await settle(tester);
                  final bounds = tester.getRect(finder);
                  expect(bounds.width, greaterThanOrEqualTo(80));
                  expect(bounds.height, greaterThanOrEqualTo(100));
                  expect(bounds.left, greaterThanOrEqualTo(0));
                  expect(bounds.right, lessThanOrEqualTo(size.width));
                  final label = tester.widget<Text>(
                    find.descendant(of: finder, matching: find.byType(Text)),
                  );
                  final word = label.data!;
                  expect(label.maxLines, 1);
                  expect(label.style!.fontSize, 40);
                  expect(selectedPacks.words, contains(word));
                  expect(
                    tester
                        .getSemantics(find.bySemanticsLabel('Word $word'))
                        .label,
                    'Word $word',
                  );
                  expect(tester.takeException(), isNull);
                }
                if (replay == 0 && question == 0) {
                  await tester.ensureVisible(find.text('Listen again'));
                  await settle(tester);
                  await capture(
                    tester,
                    key,
                    '$name-$packName-${scale}x-game',
                    directory: '0101',
                  );
                }
                await tapVisible(tester, answer(target(tester)));
                await tapVisible(
                  tester,
                  find.text(question == 4 ? 'Rewards' : 'Next'),
                );
              }
              expect(device.xp, (replay + 1) * 50);
              expect(device.writes, replay + 1);
              if (replay == 0) {
                await nextLearningRound(tester);
              }
            }
            await tapVisible(tester, find.text('Back to home'));
            expect(find.text('Hi, Player 1!'), findsOneWidget);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
