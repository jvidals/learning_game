import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:rainbow_garden/handwriting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/cursive.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/cursive_page.dart';
import 'package:rainbow_garden/widgets/cursive_pad.dart';
import 'package:rainbow_garden/widgets/writing_pad.dart';

import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

Future<void> drawLetter(
  WidgetTester tester,
  String character, {
  String padKey = 'cursive-pad',
}) async {
  final finder = find.byKey(ValueKey(padKey));
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

final tracePad = find.byKey(const ValueKey('cursive-trace-pad'));
final writePad = find.byKey(const ValueKey('cursive-pad'));
CursivePad trace(WidgetTester tester) => tester.widget<CursivePad>(tracePad);
CursivePad write(WidgetTester tester) => tester.widget<CursivePad>(writePad);

Future<void> pick(WidgetTester tester, String key) async {
  await tapVisible(tester, find.byKey(const ValueKey('cursive-picker')));
  await tapVisible(tester, find.byKey(ValueKey(key)));
}

void main() {
  setUpAll(() async {
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
    'Writing opens a–z cursive; Watch, trace, check, next and skip stay silent and unsaved',
    (tester) async {
      final device = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await tapVisible(tester, find.text('Writing'));
      await tester.ensureVisible(find.text('Cursive play').first);
      await settle(tester);
      await tester.tap(find.text('Cursive play').first);
      await tester.pump();
      final writes = device.writes, settingsWrites = device.settingsWrites;
      final document = device.profileDocument;
      await tester.pump(const Duration(milliseconds: 400));
      expect(write(tester).letter.character, 'a');
      expect(find.text('Practice only · no XP · a–z'), findsOneWidget);
      final first = trace(tester).watchProgress!;
      await tester.pump(const Duration(milliseconds: 600));
      expect(trace(tester).watchProgress, greaterThan(first));
      await drawLetter(tester, 'a', padKey: 'cursive-trace-pad');
      expect(trace(tester).watchProgress, isNull);
      expect(trace(tester).ink.isEmpty, isFalse);
      await tapVisible(tester, find.byKey(const ValueKey('cursive-watch')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(trace(tester).watchProgress, inExclusiveRange(0, 1));
      expect(write(tester).watchProgress, isNull);
      await drawLetter(tester, 'a');
      await tapVisible(tester, find.byKey(const ValueKey('cursive-check')));
      expect(find.text('Nice curves!'), findsOneWidget);
      expect(find.byKey(const ValueKey('cursive-next')), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('cursive-next')));
      expect(write(tester).letter.character, 'b');
      expect(write(tester).ink.isEmpty, isTrue);
      expect(trace(tester).ink.isEmpty, isTrue);
      expect(trace(tester).watchProgress, isNotNull);
      await tapVisible(tester, find.text('Skip letter'));
      expect(write(tester).letter.character, 'c');
      expect(find.byKey(const ValueKey('cursive-next')), findsNothing);
      await pick(tester, 'pick-letter-z');
      await tapVisible(tester, find.text('Skip letter'));
      expect(write(tester).letter.character, 'a');
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

  testWidgets(
    'picker selects lowercase letters or ordered groups and exposes selected semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = ProgressController(MemoryDevice());
      addTearDown(controller.dispose);
      await openPage(tester, controller, reducedMotion: true);
      await pick(tester, 'pick-letter-q');
      expect(write(tester).letter.character, 'q');
      await tapVisible(tester, find.byKey(const ValueKey('cursive-picker')));
      await tester.ensureVisible(find.byKey(const ValueKey('pick-letter-q')));
      await tester.pump();
      final selected = find.bySemanticsLabel('Practise cursive q');
      expect(
        tester.getSemantics(selected),
        matchesSemantics(
          label: 'Practise cursive q',
          isSelected: true,
          hasSelectedState: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tapVisible(tester, find.byKey(const ValueKey('pick-group-1')));
      expect(write(tester).letter.character, 'e');
      expect(find.text('Practice only · no XP · Loops'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('cursive-picker')));
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('pick-group-1')))
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      await tapVisible(tester, find.byTooltip('Close letter picker'));
      for (final character in [...cursiveFamilies[1].letters.skip(1), 'e']) {
        await drawLetter(tester, write(tester).letter.character);
        await tapVisible(tester, find.byKey(const ValueKey('cursive-check')));
        await tapVisible(tester, find.byKey(const ValueKey('cursive-next')));
        expect(write(tester).letter.character, character);
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'Check rejects empty ink, pad-wide scribble and a different letter; ignores live strokes',
    (tester) async {
      final controller = ProgressController(MemoryDevice());
      addTearDown(controller.dispose);
      await openPage(tester, controller, reducedMotion: true);
      await tapVisible(tester, find.byKey(const ValueKey('cursive-check')));
      expect(find.text('Try tracing first'), findsOneWidget);
      await tapVisible(tester, find.text('Clear'));
      final ink = write(tester).ink;
      // A dense zigzag covers the model, but most of its length is elsewhere.
      ink.begin(const InkPoint(-.3, -.1));
      for (var i = 0; i <= 30; i++) {
        ink.add(InkPoint(i.isEven ? 1.4 : -.3, -.1 + i * .05));
      }
      ink.end();
      expect(
        cursiveCoverage(write(tester).letter, ink.strokes),
        greaterThanOrEqualTo(.60),
      );
      await tapVisible(tester, find.byKey(const ValueKey('cursive-check')));
      expect(find.text('Try tracing first'), findsOneWidget);
      await tapVisible(tester, find.text('Clear'));
      await pick(tester, 'pick-letter-q');
      await drawLetter(tester, 'i');
      await tapVisible(tester, find.byKey(const ValueKey('cursive-check')));
      expect(find.text('Try tracing first'), findsOneWidget);
      await tapVisible(tester, find.text('Clear'));
      await tester.ensureVisible(writePad);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(writePad));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cursive-check')));
      await tester.pump();
      expect(find.text('Try tracing first'), findsNothing);
      await gesture.up();
    },
  );

  testWidgets(
    'faint toggle preserves both inks, pass and message, with toggled semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = ProgressController(MemoryDevice());
      addTearDown(controller.dispose);
      await openPage(tester, controller, reducedMotion: true);
      expect(write(tester).faint, isTrue);
      expect(write(tester).showModel, isTrue);
      expect(trace(tester).guidance, isTrue);
      await drawLetter(tester, 'a', padKey: 'cursive-trace-pad');
      await drawLetter(tester, 'a');
      await tapVisible(tester, find.byKey(const ValueKey('cursive-check')));
      final before = write(tester).ink.strokes;
      final toggle = find.byKey(const ValueKey('cursive-faint-toggle'));
      expect(
        tester.getSemantics(toggle).flagsCollection.isToggled,
        ui.Tristate.isTrue,
      );
      expect(find.byTooltip('Hide faint letter'), findsOneWidget);
      await tapVisible(tester, toggle);
      expect(write(tester).showModel, isFalse);
      expect(trace(tester).showModel, isTrue);
      expect(trace(tester).ink.isEmpty, isFalse);
      expect(write(tester).ink.strokes, before);
      expect(find.text('Nice curves!'), findsOneWidget);
      expect(find.byKey(const ValueKey('cursive-next')), findsOneWidget);
      expect(find.byTooltip('Show faint letter'), findsOneWidget);
      expect(
        tester.getSemantics(toggle).flagsCollection.isToggled,
        ui.Tristate.isFalse,
      );
      await tapVisible(tester, find.text('Clear'));
      expect(write(tester).ink.isEmpty, isTrue);
      expect(trace(tester).ink.isEmpty, isTrue);
      expect(find.text('Nice curves!'), findsNothing);
      expect(find.byKey(const ValueKey('cursive-check')), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'pause cancels strokes and Watch; no auto-resume or callbacks after disposal',
    (tester) async {
      final controller = ProgressController(MemoryDevice());
      addTearDown(controller.dispose);
      await openPage(tester, controller);
      await tester.pump(const Duration(milliseconds: 400));
      expect(trace(tester).watchProgress, isNotNull);
      await tester.ensureVisible(writePad);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(writePad));
      expect(write(tester).ink.drawing, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(trace(tester).watchProgress, isNull);
      expect(write(tester).ink.isEmpty, isTrue);
      expect(write(tester).enabled, isFalse);
      await gesture.moveBy(const Offset(20, 10));
      await gesture.up();
      expect(write(tester).ink.isEmpty, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      expect(trace(tester).watchProgress, isNull);
      await tapVisible(tester, find.byKey(const ValueKey('cursive-watch')));
      await tester.pump(const Duration(seconds: 6));
      expect(trace(tester).watchProgress, isNull);
      await tapVisible(tester, find.byKey(const ValueKey('cursive-watch')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'resize cancels unfinished strokes while retaining finished ink',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ProgressController(MemoryDevice());
      addTearDown(controller.dispose);
      await openPage(tester, controller, reducedMotion: true);
      await drawLetter(tester, 'a');
      final completed = write(tester).ink.strokes;
      final gesture = await tester.startGesture(tester.getCenter(writePad));
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pump();
      await tester.pump();
      expect(write(tester).ink.drawing, isFalse);
      await gesture.up();
      expect(write(tester).ink.strokes, completed);
    },
  );

  testWidgets(
    '393x852 keeps both pads, Watch and fixed actions visible with system insets',
    (tester) async {
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
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(top: 24, bottom: 24)),
            child: child!,
          ),
          home: CursivePage(controller: controller),
        ),
      );
      await tester.pump();
      final t = tester.getRect(tracePad), w = tester.getRect(writePad);
      final watch = tester.getRect(find.byKey(const ValueKey('cursive-watch')));
      final check = tester.getRect(find.byKey(const ValueKey('cursive-check')));
      // Printed positions are part of the review evidence.
      debugPrint('PHONE trace=$t write=$w watch=$watch check=$check');
      expect(t.height, 200);
      expect(w.height, 200);
      expect(t.top, greaterThanOrEqualTo(80));
      expect(w.top, greaterThan(t.bottom));
      expect(w.bottom, lessThan(check.top));
      expect(watch.top, greaterThanOrEqualTo(80));
      expect(check.bottom, lessThanOrEqualTo(828));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('800x1280 puts pads side by side near the fixed bottom actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ProgressController(MemoryDevice());
    addTearDown(controller.dispose);
    await openPage(tester, controller, reducedMotion: true);
    await tester.pump();
    final t = tester.getRect(tracePad), w = tester.getRect(writePad);
    expect(t.height, 240);
    expect(w.height, 240);
    expect(t.top, w.top);
    expect(t.right, lessThan(w.left));
    expect(w.bottom, greaterThan(1100));
    expect(tester.getRect(find.text('Skip letter')).bottom, lessThan(t.top));
  });

  for (final dark in [false, true]) {
    testWidgets(
      '360x640 2x ${dark ? 'dark' : 'light'} has reduced motion and reachable controls and picker',
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
          reducedMotion: true,
          dark: dark,
          scale: 2,
        );
        await tester.pumpAndSettle();
        expect(trace(tester).watchProgress, isNull);
        expect(trace(tester).guidance, isTrue);
        await tapVisible(tester, find.byKey(const ValueKey('cursive-watch')));
        expect(trace(tester).watchProgress, isNull);
        await tester.ensureVisible(writePad);
        await tester.pump();
        for (final label in ['Clear', 'Check']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(640));
        }
        final semantics = tester.ensureSemantics();
        expect(
          find.bySemanticsLabel('Watch how to write cursive a'),
          findsOneWidget,
        );
        semantics.dispose();
        await pick(tester, 'pick-letter-w');
        expect(write(tester).letter.character, 'w');
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
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
