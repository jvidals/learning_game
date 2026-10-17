import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/cursive.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/cursive_page.dart';
import 'package:rainbow_garden/widgets/cursive_pad.dart';
import 'package:rainbow_garden/widgets/writing_pad.dart';

import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

Future<void> drawLetter(WidgetTester tester, String character) async {
  final finder = find.byKey(const ValueKey('cursive-pad'));
  await tester.ensureVisible(finder);
  await tester.pump();
  final origin = tester.getTopLeft(finder);
  final geometry = WritingPadGeometry(tester.getSize(finder));
  for (final stroke in cursiveLetters[character]!.strokes) {
    final pointer = await tester.startGesture(
      origin + geometry.position(stroke.first),
    );
    for (final point in stroke.skip(1)) {
      await pointer.moveTo(origin + geometry.position(point));
    }
    await pointer.up();
  }
  await tester.pump();
}

Future<void> openPage(
  WidgetTester tester,
  ProgressController controller, {
  bool reducedMotion = false,
  bool dark = false,
  double scale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: dark ? GardenTheme.dark : GardenTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: CursivePage(controller: controller),
  ),
);

void main() {
  setUpAll(() async {
    // Optional host font makes contact-sheet labels readable; never an app asset.
    if (Platform.environment['CURSIVE_SHEET'] != '1') return;
    final font = File(
      Platform.environment['CURSIVE_FONT'] ??
          '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    );
    if (!await font.exists()) return;
    final bytes = ByteData.sublistView(await font.readAsBytes());
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
  });
  testWidgets(
    'Writing opens optional cursive, all practice stays silent and unsaved',
    (tester) async {
      final device = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await tapVisible(tester, find.text('Writing'));
      await tapVisible(tester, find.text('Cursive play').first);
      final writes = device.writes;
      final settingsWrites = device.settingsWrites;
      final document = device.profileDocument;
      await tapVisible(tester, find.byKey(const ValueKey('cursive-family-1')));
      await tapVisible(tester, find.byKey(const ValueKey('cursive-letter-l')));
      expect(find.text('Same letter'), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('cursive-mode-trace')),
      );
      await drawLetter(tester, 'l');
      expect(
        tester.widget<CursivePad>(find.byType(CursivePad)).ink.isEmpty,
        isFalse,
      );
      await tapVisible(tester, find.text('Clear'));
      expect(
        tester.widget<CursivePad>(find.byType(CursivePad)).ink.isEmpty,
        isTrue,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('cursive-mode-write')),
      );
      await drawLetter(tester, 'l');
      await tapVisible(tester, find.text('Check'));
      expect(find.text('Nice curves!'), findsOneWidget);
      await tapVisible(tester, find.text('Next letter'));
      expect(
        tester.widget<CursivePad>(find.byType(CursivePad)).letter.character,
        'h',
      );
      await tapVisible(tester, find.byTooltip('Back to writing'));
      expect(find.text('Handwriting'), findsOneWidget);
      expect(device.writes, writes);
      expect(device.settingsWrites, settingsWrites);
      expect(device.profileDocument, document);
      expect(device.xp, 0);
      expect(device.clips, isEmpty);
      expect(device.feedbacks, isEmpty);
    },
  );

  testWidgets('Watch travels once, cancels on backgrounding and dispose', (
    tester,
  ) async {
    final controller = ProgressController(MemoryDevice());
    addTearDown(controller.dispose);
    await openPage(tester, controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final first = tester
        .widget<CursivePad>(find.byType(CursivePad))
        .watchProgress!;
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.widget<CursivePad>(find.byType(CursivePad)).watchProgress!,
      greaterThan(first),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<CursivePad>(find.byType(CursivePad)).watchProgress,
      isNull,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tapVisible(tester, find.byKey(const ValueKey('cursive-mode-watch')));
    await tester.pump(const Duration(seconds: 10));
    expect(
      tester.widget<CursivePad>(find.byType(CursivePad)).watchProgress,
      isNull,
    );
    await tapVisible(tester, find.byKey(const ValueKey('cursive-mode-watch')));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'Write offers gentle tracing help; Next never waits for a check',
    (tester) async {
      final controller = ProgressController(MemoryDevice());
      addTearDown(controller.dispose);
      await openPage(tester, controller, reducedMotion: true);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('cursive-mode-write')),
      );
      await tapVisible(tester, find.text('Check'));
      expect(find.text('Try tracing first'), findsOneWidget);
      await tapVisible(tester, find.text('Next letter'));
      expect(
        tester.widget<CursivePad>(find.byType(CursivePad)).letter.character,
        'a',
      );
    },
  );

  testWidgets(
    'unfinished ink cancels on backgrounding and cannot keep drawing',
    (tester) async {
      final controller = ProgressController(MemoryDevice());
      addTearDown(controller.dispose);
      await openPage(tester, controller, reducedMotion: true);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('cursive-mode-trace')),
      );
      final pad = find.byType(CursivePad);
      await tester.ensureVisible(pad);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(pad));
      await gesture.moveBy(const Offset(20, 10));
      final ink = tester.widget<CursivePad>(pad).ink;
      expect(ink.drawing, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(ink.isEmpty, isTrue);
      expect(tester.widget<CursivePad>(pad).enabled, isFalse);
      await gesture.moveBy(const Offset(10, 10));
      await gesture.up();
      expect(ink.isEmpty, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await drawLetter(tester, 'c');
      expect(ink.isEmpty, isFalse);
    },
  );

  testWidgets('393x852 keeps every mode pad above the fixed actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ProgressController(MemoryDevice());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Include realistic system insets in the visibility requirement.
            padding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: child!,
        ),
        home: CursivePage(controller: controller),
      ),
    );
    await tester.pump();
    for (final mode in ['watch', 'trace', 'write']) {
      await tester.tap(find.byKey(ValueKey('cursive-mode-$mode')));
      await tester.pump();
      final pad = tester.getRect(find.byType(CursivePad));
      final actions = tester.getRect(
        find.ancestor(
          of: find.text('Next letter'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(pad.height, 210);
      expect(pad.top, greaterThanOrEqualTo(80));
      expect(pad.bottom, lessThanOrEqualTo(actions.top - 8));
      expect(actions.bottom, lessThanOrEqualTo(852 - 24));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('pickers stay in one row and Next reveals its selected letter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ProgressController(MemoryDevice());
    addTearDown(controller.dispose);
    await openPage(tester, controller, reducedMotion: true);
    await tester.pump();
    final families = find.byKey(const ValueKey('cursive-families'));
    final letters = find.byKey(const ValueKey('cursive-letters'));
    final familyTop = tester
        .getTopLeft(find.byKey(const ValueKey('cursive-family-0')))
        .dy;
    for (var i = 0; i < cursiveFamilies.length; i++) {
      final chip = find.byKey(ValueKey('cursive-family-$i'));
      expect(tester.getTopLeft(chip).dy, familyTop);
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    }
    await tester.drag(families, const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cursive-family-3')));
    await tester.pumpAndSettle();
    final letterTop = tester
        .getTopLeft(find.byKey(const ValueKey('cursive-letter-n')))
        .dy;
    for (final character in cursiveFamilies.last.letters) {
      final button = find.byKey(ValueKey('cursive-letter-$character'));
      expect(tester.getTopLeft(button).dy, letterTop);
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    // Next must reveal offscreen letters without scrolling away from the pad.
    final initialPad = tester.getRect(find.byType(CursivePad));
    for (final character in ['m', 'v', 'x', 'y', 'z', 'r', 's', 'n']) {
      await tester.tap(find.text('Next letter'));
      await tester.pumpAndSettle();
      final button = find.byKey(ValueKey('cursive-letter-$character'));
      final rect = tester.getRect(button);
      final viewport = tester.getRect(letters);
      expect(rect.left, greaterThanOrEqualTo(viewport.left));
      expect(rect.right, lessThanOrEqualTo(viewport.right));
      expect(
        tester
            .widget<OutlinedButton>(button)
            .style!
            .backgroundColor!
            .resolve({}),
        GardenColors.light.selectedSurface,
      );
      expect(tester.getRect(find.byType(CursivePad)), initialPad);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tablet keeps the practice pad fixed and bottom actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ProgressController(MemoryDevice());
      addTearDown(controller.dispose);
      await openPage(tester, controller, reducedMotion: true);
      await tester.pump();
      expect(tester.getSize(find.byType(CursivePad)), const Size(400, 240));
      expect(tester.getRect(find.byType(CursivePad)).bottom, greaterThan(1100));
      for (final label in ['Clear', 'Next letter']) {
        final button = find
            .ancestor(
              of: find.text(label),
              matching: find.bySubtype<ButtonStyleButton>(),
            )
            .first;
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      '360x640, 2x text, reduced motion, ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ProgressController(MemoryDevice());
        addTearDown(controller.dispose);
        await openPage(
          tester,
          controller,
          dark: dark,
          reducedMotion: true,
          scale: 2,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<CursivePad>(find.byType(CursivePad)).watchProgress,
          isNull,
        );
        expect(
          tester.widget<CursivePad>(find.byType(CursivePad)).guidance,
          isTrue,
        );
        expect(tester.binding.transientCallbackCount, 0);
        for (final mode in ['trace', 'write', 'watch']) {
          await tapVisible(tester, find.byKey(ValueKey('cursive-mode-$mode')));
          await tester.ensureVisible(find.byType(CursivePad));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        for (final label in ['Clear', 'Next letter']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(640));
        }
        final semantics = tester.ensureSemantics();
        expect(
          find.bySemanticsLabel('Watch how to write cursive c'),
          findsOneWidget,
        );
        semantics.dispose();
      },
    );
  }

  testWidgets('all 26 models paint; optional PNG contact sheet', (
    tester,
  ) async {
    // CURSIVE_SHEET=1 tools/sdk_direct.sh flutter test test/cursive_widgets_test.dart --no-pub
    final export = Platform.environment['CURSIVE_SHEET'] == '1';
    tester.view.physicalSize = const Size(1300, 1260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.light,
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: GardenColors.light.background,
              child: Wrap(
                children: [
                  for (final letter in cursiveLetters.values)
                    SizedBox(
                      width: 250,
                      height: 205,
                      child: Column(
                        children: [
                          Text(
                            letter.character,
                            style: const TextStyle(fontSize: 28),
                          ),
                          Expanded(
                            child: CustomPaint(
                              painter: CursivePainter(
                                letter: letter,
                                colors: GardenColors.light,
                                guidance: true,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    if (export) {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '/tmp/cursive_sheet.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
