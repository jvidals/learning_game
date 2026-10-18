import 'package:rainbow_garden/game.dart';
import 'dart:async';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/profiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/number_range.dart';
import 'widget_test.dart' show MemoryDevice, tapVisible, settle;

Future<void> unlock(WidgetTester tester) async {
  await tapVisible(tester, find.byTooltip('Settings'));
  await answerGate(tester);
}

Future<void> answerGate(WidgetTester tester) async {
  final text = tester
      .widget<Text>(find.byKey(const ValueKey('parent-challenge')))
      .data!;
  final operands = RegExp(
    r'\d+',
  ).allMatches(text).map((m) => int.parse(m[0]!)).toList();
  await tester.enterText(
    find.byType(TextField),
    '${operands[0] * operands[1]}',
  );
  await tapVisible(tester, find.text('Continue'));
}

class PendingDevice extends MemoryDevice {
  final pending = Completer<void>();
  @override
  Future<void> saveProgress(String document) async {
    await pending.future;
    await super.saveProgress(document);
  }
}

void main() {
  test('Sketch photo saving defaults on and round trips off', () {
    expect(const AppSettings().sketchSaveToPhotos, isTrue);
    expect(AppSettings.fromMap(null).sketchSaveToPhotos, isTrue);
    expect(AppSettings.fromMap({}).sketchSaveToPhotos, isTrue);
    final settings = const AppSettings().withSketchSaveToPhotos(false);
    expect(settings.copyWith().sketchSaveToPhotos, isFalse);
    expect(AppSettings.fromMap(settings.toMap()).sketchSaveToPhotos, isFalse);
  });

  test('profiles reject non-boolean Sketch photo saving settings', () {
    final player = PlayerProfile.fresh('Player 1');
    for (final value in [null, 0, 'false', [], {}]) {
      final malformed = PlayerProfile.fromMap({
        ...player.toMap(),
        'settings': {...player.settings.toMap(), 'sketchSaveToPhotos': value},
      });
      expect(() => malformed.settings, throwsFormatException);
    }
  });

  testWidgets('Sketch photo saving toggle autosaves for the player', (
    tester,
  ) async {
    final device = MemoryDevice();
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    await unlock(tester);
    final toggle = find.byKey(const ValueKey('settings-sketch-save-photos'));
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tapVisible(tester, toggle);
    expect(
      ProfileStore.decode(
        device.profileDocument!,
      ).active.settings.sketchSaveToPhotos,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await settle(tester);
    await unlock(tester);
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets(
    'gate rejects wrong answer, cancels, and requires unlocking on each entry',
    (tester) async {
      await tester.pumpWidget(RainbowGardenApp(services: MemoryDevice()));
      await settle(tester);
      await tapVisible(tester, find.byTooltip('Settings'));
      await tester.enterText(find.byType(TextField), '0');
      await tapVisible(tester, find.text('Continue'));
      expect(find.text('Try again.'), findsOneWidget);
      expect(find.text('Number practice'), findsNothing);
      await tapVisible(tester, find.text('Cancel'));
      await unlock(tester);
      expect(
        find.text('Changes apply and save automatically.'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tapVisible(tester, find.byTooltip('Settings'));
      expect(find.text('Grown-ups only'), findsOneWidget);
    },
  );

  testWidgets(
    'settings apply immediately, Back keeps them and restart preserves XP',
    (tester) async {
      final device = MemoryDevice()..xp = 350;
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await unlock(tester);
      expect(find.text('Save settings'), findsNothing);
      expect(find.text('Number practice'), findsNothing);
      await tapVisible(tester, find.text('Tap Next'));
      expect(device.tapNext, isFalse);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      expect(device.tapNext, isFalse);
      expect(device.xp, 350);
    },
  );

  testWidgets(
    'failed automatic settings retry and reset preserves accepted choices',
    (tester) async {
      final device = MemoryDevice()..xp = 200;
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await unlock(tester);
      device.failSave = true;
      await tapVisible(tester, find.text('Tap Next'));
      await tapVisible(tester, find.text('Haptics'));
      expect(device.tapNext, isTrue);
      expect(
        find.text('Your changes could not be saved yet. Try saving again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Reset progress'),
            )
            .onPressed,
        isNull,
      );
      device.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(device.tapNext, isFalse);
      expect(device.haptics, isFalse);
      await tapVisible(tester, find.text('Reset progress'));
      await tapVisible(tester, find.text('Cancel'));
      expect(device.xp, 200);
      await tapVisible(tester, find.text('Reset progress'));
      await tapVisible(tester, find.text('Reset progress').last);
      expect(device.xp, 0);
      expect(device.tapNext, isFalse);
      expect(device.haptics, isFalse);
    },
  );

  testWidgets(
    'range editor exact controls enforce three numbers and 0–100 bounds',
    (tester) async {
      final device = MemoryDevice()..range = NumberRange(98, 100);
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await tapVisible(tester, find.text('Numbers'));
      await tapVisible(tester, find.byKey(const ValueKey('range-numbers')));
      await answerGate(tester);
      for (final tooltip in [
        'Increase start',
        'Decrease end',
        'Increase end',
      ]) {
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == tooltip,
                ),
              )
              .onPressed,
          isNull,
        );
      }
      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      slider.onChanged!(const RangeValues(99, 100));
      await tester.pump();
      expect(find.text('Numbers 98–100'), findsOneWidget);
      slider.onChanged!(const RangeValues(0, 2));
      await settle(tester);
      expect(find.text('Numbers 0–2'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Decrease start',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(device.ranges.numberHunt, NumberRange(0, 2));
      expect(device.ranges.numberOrder, NumberRange(98, 100));
      await tapVisible(tester, find.byTooltip('Close range settings'));
    },
  );

  testWidgets(
    'leaving fifth answer cannot reset or start another game before reward commits',
    (tester) async {
      final device = PendingDevice();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await tapVisible(tester, find.text('Numbers'));
      await tapVisible(tester, find.text(Activity.numbers.title));
      for (var i = 0; i < 5; i++) {
        final clip = device.clips.lastWhere(
          (clip) => clip.startsWith('number_'),
        );
        final choice = find.byKey(ValueKey('choice-${clip.substring(7)}'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        if (i < 4) {
          await settle(tester);
          await tapVisible(tester, find.text('Next'));
        } else {
          await tester.pump();
        }
      }
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Numbers'), findsOneWidget);
      expect(find.text('Saving your progress…'), findsOneWidget);
      await tapVisible(tester, find.text(Activity.numbers.title));
      expect(find.text('Numbers'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Settings',
              ),
            )
            .onPressed,
        isNull,
      );
      await tapVisible(tester, find.text('Numbers'));
      expect(find.text('Hi, Player 1!'), findsOneWidget);
      device.pending.complete();
      await settle(tester);
      expect(device.xp, 50);
      await unlock(tester);
      await tapVisible(tester, find.text('Reset progress'));
      await tapVisible(tester, find.text('Reset progress').last);
      expect(device.xp, 0);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(800, 1100),
    const Size(740, 360),
  ]) {
    testWidgets('settings fit $size at 200% text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(RainbowGardenApp(services: MemoryDevice()));
      await settle(tester);
      await unlock(tester);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Reset progress'));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Cancel'));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
