import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/category_page.dart';
import 'package:rainbow_garden/screens/game_2048_page.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/screens/home_page.dart';
import 'package:rainbow_garden/screens/sketch_page.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
}

Future<void> expectStack(WidgetTester tester, GameCategory category) async {
  await back(tester);
  expect(
    tester.widget<CategoryPage>(find.byType(CategoryPage)).category,
    category,
  );
  await back(tester);
  expect(find.byType(HomePage), findsOneWidget);
  expect(find.byType(CategoryPage), findsNothing);
  expect(find.text('Hi, Player 1!'), findsOneWidget);
}

void main() {
  for (final (id, page, category) in [
    ('sketchPad', SketchPage, GameCategory.artHub),
    ('game2048', Game2048Page, GameCategory.numbers),
  ]) {
    testWidgets('cold $id waits for loading and builds the normal stack', (
      tester,
    ) async {
      final load = Completer<void>();
      final device = MemoryDevice()
        ..pendingShortcut = id
        ..loadProfilesHold = load;
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      expect(find.byType(page), findsNothing);
      load.complete();
      await settle(tester);
      expect(find.byType(page), findsOneWidget);
      await expectStack(tester, category);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('warm shortcut closes another game and its rewards sheet', (
    tester,
  ) async {
    final device = MemoryDevice();
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    await tapVisible(tester, find.text('Letters'));
    await tapVisible(tester, find.text(Activity.uppercase.title));
    expect(find.byType(GamePage), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Rewards'));
    expect(find.byTooltip('Close rewards'), findsOneWidget);
    device.requestShortcut('sketchPad');
    await settle(tester);
    await settle(tester);
    expect(find.byType(SketchPage), findsOneWidget);
    expect(find.byType(GamePage), findsNothing);
    expect(find.byTooltip('Close rewards'), findsNothing);
    await expectStack(tester, GameCategory.artHub);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shortcut waits for a save and the newest request wins', (
    tester,
  ) async {
    final device = MemoryDevice();
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    device.saveProfilesHold = Completer<void>();
    await tester.tap(find.byTooltip('Turn sound off'));
    await settle(tester);
    expect(find.text('Saving settings…'), findsOneWidget);
    device.requestShortcut('game2048');
    await settle(tester);
    expect(find.byType(Game2048Page), findsNothing);
    device.requestShortcut('sketchPad');
    await settle(tester);
    expect(find.byType(SketchPage), findsNothing);
    device.saveProfilesHold!.complete();
    await settle(tester);
    expect(find.byType(SketchPage), findsOneWidget);
    await expectStack(tester, GameCategory.artHub);
    expect(device.soundOn, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final failDuringWait in [false, true]) {
    testWidgets('failed save drops shortcut (during wait: $failDuringWait)', (
      tester,
    ) async {
      final device = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      device.failSave = true;
      if (failDuringWait) device.saveProfilesHold = Completer<void>();
      await tester.tap(find.byTooltip('Turn sound off'));
      await settle(tester);
      device.requestShortcut('sketchPad');
      await settle(tester);
      device.saveProfilesHold?.complete();
      await settle(tester);
      expect(find.byType(SketchPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Try saving again'), findsOneWidget);
      device.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(find.byType(SketchPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('load failure drops shortcut even after retry', (tester) async {
    final device = MemoryDevice()
      ..pendingShortcut = 'sketchPad'
      ..failLoad = true;
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    expect(find.byType(SketchPage), findsNothing);
    device.failLoad = false;
    await tapVisible(tester, find.text('Try again'));
    expect(find.byType(SketchPage), findsNothing);
    expect(find.text('Hi, Player 1!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('invalid shortcut leaves Home unchanged', (tester) async {
    final device = MemoryDevice()..pendingShortcut = 'settings';
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    device.requestShortcut('settings');
    await settle(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(CategoryPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'same top activity does not add a route in dark at text scale 2',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final device = MemoryDevice()
        ..appearance = AppAppearance.dark
        ..pendingShortcut = 'sketchPad';
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      final original = tester.state(find.byType(SketchPage));
      expect(
        Theme.of(tester.element(find.byType(SketchPage))).brightness,
        Brightness.dark,
      );
      device.requestShortcut('sketchPad');
      await settle(tester);
      expect(tester.state(find.byType(SketchPage)), same(original));
      await expectStack(tester, GameCategory.artHub);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'same activity under a sheet keeps its page and closes the sheet',
    (tester) async {
      final device = MemoryDevice()..pendingShortcut = 'sketchPad';
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      final original = tester.state(find.byType(SketchPage));
      await tester.tap(find.byTooltip('Choose a tool'));
      await settle(tester);
      expect(find.byKey(const ValueKey('sketch-popover')), findsOneWidget);
      device.requestShortcut('sketchPad');
      await settle(tester);
      await settle(tester);
      expect(find.byKey(const ValueKey('sketch-popover')), findsNothing);
      expect(tester.state(find.byType(SketchPage)), same(original));
      await expectStack(tester, GameCategory.artHub);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('shortcut from Sketch to 2048 restores the Sketch window', (
    tester,
  ) async {
    final device = MemoryDevice()..pendingShortcut = 'sketchPad';
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    expect(device.sketchWindowCalls.last, isTrue);
    device.requestShortcut('game2048');
    await settle(tester);
    expect(find.byType(SketchPage), findsNothing);
    expect(find.byType(Game2048Page), findsOneWidget);
    expect(device.sketchWindowCalls.last, isFalse);
    await expectStack(tester, GameCategory.numbers);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
