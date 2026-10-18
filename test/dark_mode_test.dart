import 'package:rainbow_garden/game.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/game_2048.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/profiles.dart';
import 'package:rainbow_garden/screens/home_page.dart';
import 'package:rainbow_garden/widgets/board_2048.dart';
import 'package:rainbow_garden/widgets/writing_pad.dart';
import 'profiles_test.dart' show ProfileDevice;
import 'settings_test.dart' show unlock;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;
import 'writing_widgets_test.dart' show seeded, drawSample;

Brightness brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).last)).brightness;

Future<void> systemAppearance(WidgetTester tester, Brightness value) async {
  tester.platformDispatcher.platformBrightnessTestValue = value;
  await tester.pump();
  await tester.pump();
}

double contrast(Color a, Color b) =>
    (max(a.computeLuminance(), b.computeLuminance()) + .05) /
    (min(a.computeLuminance(), b.computeLuminance()) + .05);

void main() {
  test(
    'appearance round trips, defaults only when absent, and rejects damage',
    () {
      final legacy = const AppSettings().toMap()..remove('appearance');
      expect(AppSettings.fromMap(legacy).appearance, AppAppearance.system);
      expect(AppSettings.fromMap(null).appearance, AppAppearance.system);
      for (final value in AppAppearance.values) {
        final settings = AppSettings(appearance: value);
        expect(AppSettings.fromMap(settings.toMap()).appearance, value);
        expect(settings.withSound(false).appearance, value);
        expect(settings.withOrderingCase(true).appearance, value);
      }
      for (final invalid in [null, false, 1, 'unknown', 'Dark']) {
        expect(
          () => AppSettings.fromMap({...legacy, 'appearance': invalid}),
          throwsFormatException,
        );
        final store =
            jsonDecode(ProfileStore.initial().encode()) as Map<String, dynamic>;
        store['players'][0]['settings']['appearance'] = invalid;
        final damaged = ProfileStore.decode(jsonEncode(store));
        expect(damaged.active.hasValidSettings, isFalse);
        expect(
          jsonDecode(damaged.encode())['players'][0]['settings']['appearance'],
          invalid,
        );
      }
    },
  );

  test('both palettes meet reading and game contrast targets', () {
    for (final palette in [GardenColors.light, GardenColors.dark]) {
      for (final background in [
        palette.background,
        palette.surface,
        palette.panel,
        palette.selectedSurface,
        palette.successSurface,
        palette.mutedSurface,
      ]) {
        expect(
          contrast(palette.foreground, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      for (final accent in GardenColors.lightRainbow) {
        expect(
          contrast(palette.foreground, palette.card(accent)),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(palette.secondary, palette.card(accent)),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(palette.retryInk, palette.retrySurface),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrast(palette.writingInk, palette.surface),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrast(palette.writingRule, palette.surface),
        greaterThanOrEqualTo(3),
      );
      final tiles = [for (var i = 1; i <= 14; i++) palette.tile(1 << i)];
      expect(tiles.toSet(), hasLength(14));
      for (final tile in tiles) {
        expect(contrast(palette.foreground, tile), greaterThanOrEqualTo(4.5));
      }
      expect(palette.tile(32768), palette.tile(16384));
    }
    final dark = GardenColors.dark;
    expect(dark.background, Colors.black);
    for (final surface in [dark.surface, dark.panel, dark.selectedSurface]) {
      expect(contrast(dark.outline, surface), greaterThanOrEqualTo(3));
    }
    expect(contrast(dark.writingGuide, dark.surface), greaterThanOrEqualTo(3));
    expect(
      contrast(dark.writingDirection, dark.writingGuide),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(dark.writingInk, dark.writingGuide),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(dark.onDirection, dark.writingDirection),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(GardenTheme.dark.colorScheme.onPrimary, dark.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  for (final system in Brightness.values) {
    for (final appearance in AppAppearance.values) {
      testWidgets(
        '$appearance overrides or follows $system and survives restart',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = system;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final device = MemoryDevice()..appearance = appearance;
          await tester.pumpWidget(RainbowGardenApp(services: device));
          await settle(tester);
          final expected = switch (appearance) {
            AppAppearance.system => system,
            AppAppearance.light => Brightness.light,
            AppAppearance.dark => Brightness.dark,
          };
          expect(brightness(tester), expected);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(RainbowGardenApp(services: device));
          await settle(tester);
          expect(brightness(tester), expected);
          expect(device.settingsWrites, 0);
        },
      );
    }
  }

  testWidgets(
    'settings apply immediately, Back keeps them, and System stays live',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await systemAppearance(tester, Brightness.light);
      final device = MemoryDevice()..xp = 150;
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await unlock(tester);
      await tapVisible(tester, find.byKey(const ValueKey('appearance-dark')));
      expect(brightness(tester), Brightness.dark);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(device.appearance, AppAppearance.dark);
      await unlock(tester);
      await tapVisible(tester, find.byKey(const ValueKey('appearance-dark')));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(brightness(tester), Brightness.dark);
      expect(device.appearance, AppAppearance.dark);
      await tapVisible(tester, find.byTooltip('Turn sound off'));
      expect(device.appearance, AppAppearance.dark);
      await unlock(tester);
      await tapVisible(tester, find.text('Reset progress'));
      await tapVisible(tester, find.text('Reset progress').last);
      expect(device.xp, 0);
      expect(device.appearance, AppAppearance.dark);
      await tapVisible(tester, find.byKey(const ValueKey('appearance-system')));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(brightness(tester), Brightness.light);
      await systemAppearance(tester, Brightness.dark);
      expect(brightness(tester), Brightness.dark);
      expect(device.appearance, AppAppearance.system);
    },
  );

  testWidgets(
    'delayed failed appearance save stays visible through exact retry and Back',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await systemAppearance(tester, Brightness.light);
      final device = ProfileDevice();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await unlock(tester);
      device.gate = Completer<void>();
      await tapVisible(tester, find.byKey(const ValueKey('appearance-dark')));
      await tester.pump(const Duration(seconds: 30));
      expect(brightness(tester), Brightness.dark);
      device.failSave = true;
      device.gate!.complete();
      await settle(tester);
      expect(brightness(tester), Brightness.dark);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('profile-picker')))
            .onPressed,
        isNull,
      );
      device.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(brightness(tester), Brightness.dark);
      expect(device.appearance, AppAppearance.dark);
      expect(device.attempts, hasLength(2));
      expect(device.attempts[0], device.attempts[1]);
    },
  );

  testWidgets(
    'players keep separate appearances and new players follow the system',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await systemAppearance(tester, Brightness.light);
      final device = MemoryDevice()..appearance = AppAppearance.dark;
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      final controller = tester
          .widget<HomePage>(find.byType(HomePage))
          .controller;
      final first = controller.activeProfile!.id;
      await controller.addProfile('Sam');
      await settle(tester);
      expect(brightness(tester), Brightness.light);
      expect(controller.settings.appearance, AppAppearance.system);
      await controller.selectProfile(first);
      await settle(tester);
      expect(brightness(tester), Brightness.dark);
      await controller.saveSettings(controller.settings.withOrderingCase(true));
      await settle(tester);
      expect(controller.settings.appearance, AppAppearance.dark);
      await controller.reset();
      await settle(tester);
      expect(controller.settings.appearance, AppAppearance.dark);
    },
  );

  testWidgets(
    'live system change keeps question and the existing automatic deadline',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await systemAppearance(tester, Brightness.light);
      final device = MemoryDevice()..tapNext = false;
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await tapVisible(tester, find.text('Numbers'));
      await tapVisible(tester, find.text(Activity.numbers.title));
      final clip = device.clips.last;
      final choice = find.byKey(ValueKey('choice-${clip.substring(7)}'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await systemAppearance(tester, Brightness.dark);
      expect(find.text('You found it! ✨'), findsOneWidget);
      expect(device.clips.last, clip);
      await tester.pump(const Duration(milliseconds: 399));
      expect(device.clips.last, clip);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();
      expect(device.clips.length, 2);
      expect(device.clips.last, isNot(clip));
      expect(device.xp, 0);
    },
  );

  testWidgets(
    'system switch repaints both writing pads without losing ink or an active stroke',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await systemAppearance(tester, Brightness.light);
      final device = seeded();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await tapVisible(tester, find.text('Writing'));
      await tapVisible(tester, find.text('Handwriting'));
      await drawSample(tester, 'A');
      final finder = find.byKey(const ValueKey('freehand-pad'));
      final ink = tester.widget<WritingPad>(finder).ink;
      final complete = ink.strokes;
      final gesture = await tester.startGesture(tester.getCenter(finder));
      await gesture.moveBy(const Offset(0, 15));
      final inProgress = ink.strokes;
      await systemAppearance(tester, Brightness.dark);
      expect(tester.widget<WritingPad>(finder).ink, same(ink));
      expect(ink.strokes, inProgress);
      expect(ink.drawing, isTrue);
      await gesture.cancel();
      expect(ink.strokes, complete);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final checkLabel = find.text('Check');
      final labelColor = DefaultTextStyle.of(
        tester.element(checkLabel),
      ).style.color!;
      final buttonMaterial = tester.widget<Material>(
        find.ancestor(of: checkLabel, matching: find.byType(Material)).first,
      );
      expect(
        contrast(labelColor, buttonMaterial.color!),
        greaterThanOrEqualTo(4.5),
      );
      await tapVisible(tester, find.text('Check'));
      expect(find.text('Next: lowercase'), findsOneWidget);
      expect(device.xp, 0);
    },
  );

  testWidgets('AMOLED page renders true black pixels', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: RainbowGardenApp(
          services: MemoryDevice()..appearance = AppAppearance.dark,
        ),
      ),
    );
    await settle(tester);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(data!.buffer.asUint8List().sublist(0, 4), [0, 0, 0, 255]);
      image.dispose();
    });
  });

  testWidgets('2048 stationary and sliding tiles use the same dark colors', (
    tester,
  ) async {
    final before = Game2048State(
      id: 'theme-board',
      board: [0, 2, 2, 0, ...List.filled(12, 0)],
    );
    final move = before.move(Move2048Direction.left, Random(1))!;
    final animation = ValueNotifier<double>(0);
    addTearDown(animation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Board2048(
              session: move.after,
              animation: AlwaysStoppedAnimation(animation.value),
              move: move,
            ),
          ),
        ),
      ),
    );
    Container tile(String label) => tester.widget<Container>(
      find
          .ancestor(
            of: find.text(label).first,
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (tile('2').decoration! as BoxDecoration).color,
      GardenColors.dark.tile(2),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Board2048(
              session: move.after,
              animation: const AlwaysStoppedAnimation(1),
              move: move,
            ),
          ),
        ),
      ),
    );
    expect(
      (tile('4').decoration! as BoxDecoration).color,
      GardenColors.dark.tile(4),
    );
    expect(tester.takeException(), isNull);
  });
}
