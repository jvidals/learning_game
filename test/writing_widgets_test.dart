import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/handwriting.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/widgets/writing_pad.dart';
import 'package:rainbow_garden/writing.dart';
import 'progress_test.dart' show SlowDevice;
import 'fixtures/handwriting_samples.dart';
import 'interface_layout_test.dart' show capture, captureApp, loadCaptureFonts;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

MemoryDevice seeded({int index = 0, int forms = 0}) =>
    MemoryDevice()
      ..document = PlayerProgress(
        writing: WritingProgress(
          id: 'test-alphabet',
          order: List.generate(26, (i) => i),
          index: index,
          forms: List.generate(26, (i) => i == index ? forms : 0),
        ),
      ).encode();

Future<void> openWriting(
  WidgetTester tester,
  MemoryDevice device, {
  GlobalKey? boundary,
}) async {
  await tester.pumpWidget(
    boundary == null
        ? RainbowGardenApp(services: device)
        : RepaintBoundary(key: boundary, child: captureApp(device)),
  );
  await settle(tester);
  await tapVisible(tester, find.text('Writing'));
  await tapVisible(tester, find.text('Handwriting'));
}

Future<void> drawSample(
  WidgetTester tester,
  String character, {
  bool trace = false,
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final finder = find.byKey(ValueKey(trace ? 'trace-pad' : 'freehand-pad'));
  await tester.ensureVisible(finder);
  await tester.pump();
  final topLeft = tester.getTopLeft(finder);
  final geometry = WritingPadGeometry(tester.getSize(finder));
  for (final stroke in writingSamples[character]!) {
    final gesture = await tester.startGesture(
      topLeft + geometry.position(stroke.first),
      kind: kind,
    );
    for (final point in stroke.skip(1)) {
      await gesture.moveTo(topLeft + geometry.position(point));
    }
    await gesture.up();
  }
  await tester.pump();
}

void main() {
  setUpAll(loadCaptureFonts);
  WritingPad tracePad(WidgetTester tester) =>
      tester.widget<WritingPad>(find.byKey(const ValueKey('trace-pad')));

  testWidgets(
    'Watch auto-plays, stops for tracing, and replays without saving',
    (tester) async {
      final device = seeded();
      await openWriting(tester, device);
      final watch = find.byKey(const ValueKey('writing-watch'));
      expect(watch, findsOneWidget);
      expect(find.text('Watch'), findsOneWidget);
      expect(find.bySemanticsLabel('Watch how to write A'), findsOneWidget);
      // The default 800×600 tablet keeps Watch beside Skip to preserve pad fit.
      final skip = tester.getRect(find.text('Skip letter'));
      expect(tester.getRect(watch).center.dy, closeTo(skip.center.dy, 1));
      expect(
        tester.getRect(watch).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('trace-pad'))).top,
        ),
      );
      final document = device.profileDocument;
      final writes = device.writes;
      final first = tracePad(tester).watchProgress!;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tracePad(tester).watchProgress, greaterThan(first));
      expect(
        tester
            .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
            .watchProgress,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('trace-pad')));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('trace-pad'))),
      );
      await tester.pump();
      expect(tracePad(tester).watchProgress, isNull);
      await gesture.up();
      final completedInk = tracePad(tester).ink.strokes;
      final unfinished = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('trace-pad'))),
      );
      await tapVisible(tester, watch);
      await unfinished.up();
      expect(tracePad(tester).watchProgress, isNotNull);
      expect(tracePad(tester).ink.drawing, isFalse);
      expect(tracePad(tester).ink.strokes, completedInk);
      await tester.pump(const Duration(seconds: 5));
      expect(tracePad(tester).watchProgress, isNull);
      await tapVisible(tester, watch);
      expect(tracePad(tester).watchProgress, inExclusiveRange(0, 1));
      expect(device.profileDocument, document);
      expect(device.writes, writes);
      expect(device.xp, 0);
      expect(device.clips, isEmpty);
      expect(device.feedbacks, isEmpty);
    },
  );

  testWidgets('Watch auto-plays after creating the first saved alphabet', (
    tester,
  ) async {
    await openWriting(tester, MemoryDevice());
    expect(tracePad(tester).watchProgress, isNotNull);
    expect(tracePad(tester).enabled, isTrue);
  });

  testWidgets('Watch replays on Skip, case changes, picker and shuffle', (
    tester,
  ) async {
    await openWriting(tester, seeded());
    await tester.pump(const Duration(seconds: 5));
    await tapVisible(tester, find.text('Skip letter'));
    expect(tracePad(tester).template.character, 'B');
    expect(tracePad(tester).watchProgress, isNotNull);
    await tester.pump(const Duration(seconds: 5));
    await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
    expect(tracePad(tester).template.character, 'b');
    expect(tracePad(tester).watchProgress, isNotNull);
    await tester.pump(const Duration(seconds: 5));
    await tapVisible(tester, find.byTooltip('Choose a letter'));
    await tapVisible(tester, find.byKey(const ValueKey('pick-letter-C')));
    expect(tracePad(tester).template.character, 'C');
    expect(tracePad(tester).watchProgress, isNotNull);
    await tester.pump(const Duration(seconds: 5));
    await tapVisible(tester, find.byTooltip('Choose a letter'));
    await tapVisible(tester, find.text('Shuffled alphabet'));
    expect(tracePad(tester).template.character, 'b');
    expect(tracePad(tester).watchProgress, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Watch stops for backgrounding and stays stopped on resume', (
    tester,
  ) async {
    await openWriting(tester, seeded());
    expect(tracePad(tester).watchProgress, isNotNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tracePad(tester).watchProgress, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tracePad(tester).watchProgress, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('writing-watch')));
    expect(tracePad(tester).watchProgress, isNotNull);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(tracePad(tester).watchProgress, isNull);
  });

  testWidgets('Watch respects reduced motion on entry and after replay', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openWriting(tester, seeded());
    expect(tracePad(tester).watchProgress, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('writing-watch')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tracePad(tester).watchProgress, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
    expect(tracePad(tester).watchProgress, isNull);
  });

  testWidgets('phone Watch sits beside the trace label', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openWriting(tester, seeded());
    final header = tester.getRect(find.text('Trace the example'));
    final watch = tester.getRect(find.byKey(const ValueKey('writing-watch')));
    final button = find.byKey(const ValueKey('writing-watch'));
    final outline = tester.getSize(
      find.descendant(of: button, matching: find.byType(Material)),
    );
    expect(outline.height, lessThanOrEqualTo(40));
    expect(watch.width, greaterThanOrEqualTo(48));
    expect(watch.height, greaterThanOrEqualTo(48));
    debugPrint('WRITING Watch outline=$outline touch=${watch.size}');
    expect(watch.center.dy, closeTo(header.center.dy, 1));
    expect(watch.left, greaterThanOrEqualTo(header.right));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'Watch header stacks at large text and Check stays fixed $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await openWriting(tester, seeded());
        final header = tester.getRect(find.text('Trace the example'));
        final watch = tester.getRect(
          find.byKey(const ValueKey('writing-watch')),
        );
        expect(watch.top, greaterThanOrEqualTo(header.bottom));
        expect(watch.right, closeTo(304, 1));
        final check = find.byKey(const ValueKey('writing-check'));
        final before = tester.getRect(check);
        await tester.ensureVisible(find.byKey(const ValueKey('freehand-pad')));
        await tester.pump();
        expect(tester.getRect(check), before);
        expect(before.bottom, lessThanOrEqualTo(640));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tablet keeps Skip above pads and Check outside scrolling $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1100);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await openWriting(tester, seeded());
        final trace = tester.getRect(find.byKey(const ValueKey('trace-pad')));
        final freehand = tester.getRect(
          find.byKey(const ValueKey('freehand-pad')),
        );
        expect(
          tester.getRect(find.text('Skip letter')).bottom,
          lessThan(trace.top),
        );
        expect(trace.height, 240);
        expect(freehand.height, 240);
        expect(trace.top, freehand.top);
        final check = find.byKey(const ValueKey('writing-check'));
        expect(
          find.ancestor(
            of: check,
            matching: find.byType(SingleChildScrollView),
          ),
          findsNothing,
        );
        expect(tester.getRect(check).top, greaterThan(freehand.bottom));
        expect(check.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'case tabs preserve both drawings, Clear is local, and lowercase may finish first',
    (tester) async {
      final device = seeded();
      await openWriting(tester, device);
      await drawSample(tester, 'A', trace: true);
      await drawSample(tester, 'A');
      final upper = tester
          .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
          .ink;
      final savedUpper = upper.strokes;
      final active = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('freehand-pad'))),
      );
      await active.moveBy(const Offset(10, 10));
      await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
      await active.up();
      expect(upper.strokes, savedUpper);
      expect(
        tester
            .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
            .ink
            .isEmpty,
        isTrue,
      );
      await drawSample(tester, 'a');
      final lower = tester
          .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
          .ink;
      final savedLower = lower.strokes;
      await tapVisible(tester, find.byKey(const ValueKey('case-upper')));
      expect(upper.strokes, savedUpper);
      expect(
        tester
            .widget<WritingPad>(find.byKey(const ValueKey('trace-pad')))
            .ink
            .isEmpty,
        isFalse,
      );
      await tapVisible(tester, find.text('Clear'));
      expect(upper.isEmpty, isTrue);
      expect(lower.strokes, savedLower);
      await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
      await tapVisible(tester, find.text('Check'));
      expect(device.xp, 0);
      expect(PlayerProgress.decode(device.document).writing!.currentForms, 2);
      expect(find.text('Next: uppercase'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Back to writing'));
      await tapVisible(tester, find.text('Handwriting'));
      expect(
        tester
            .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
            .template
            .character,
        'A',
      );
      await drawSample(tester, 'A');
      await tapVisible(tester, find.text('Check'));
      expect(device.xp, 10);
      expect(find.text('Both letters complete! 10 XP earned!'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
      expect(find.text('Next letter'), findsOneWidget);
      await drawSample(tester, 'a');
      await tapVisible(tester, find.text('Check'));
      expect(device.xp, 10);
    },
  );

  testWidgets('manual practice preserves the paused shuffled ink and case', (
    tester,
  ) async {
    final device = seeded();
    await openWriting(tester, device);
    await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
    await drawSample(tester, 'a');
    final ink = tester
        .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
        .ink;
    final before = ink.strokes;
    final document = device.document;
    await tapVisible(tester, find.byTooltip('Choose a letter'));
    await tapVisible(tester, find.byKey(const ValueKey('pick-letter-B')));
    await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
    await drawSample(tester, 'b');
    await tapVisible(tester, find.text('Check'));
    expect(find.text('Next: uppercase'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Choose a letter'));
    await tapVisible(tester, find.text('Shuffled alphabet'));
    expect(
      tester.widget<WritingPad>(find.byKey(const ValueKey('freehand-pad'))).ink,
      same(ink),
    );
    expect(ink.strokes, before);
    expect(device.document, document);
  });

  testWidgets('both forms required; tracing and Clear repeats cannot earn XP', (
    tester,
  ) async {
    final device = seeded();
    await openWriting(tester, device);
    await drawSample(tester, 'A', trace: true);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('writing-check')))
          .onPressed,
      isNull,
    );
    expect(device.xp, 0);
    await drawSample(tester, 'A');
    await tapVisible(tester, find.text('Check'));
    expect(device.xp, 0);
    expect(PlayerProgress.decode(device.document).writing!.currentForms, 1);
    await tapVisible(tester, find.text('Clear'));
    await drawSample(tester, 'A');
    await tapVisible(tester, find.text('Check'));
    expect(device.xp, 0);
    await tapVisible(tester, find.text('Next: lowercase'));
    expect(tracePad(tester).watchProgress, isNotNull);
    await drawSample(tester, 'a', kind: PointerDeviceKind.stylus);
    await tapVisible(tester, find.text('Check'));
    expect(device.xp, 10);
    expect(find.text('Both letters complete! 10 XP earned!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
          .template
          .character,
      'a',
    );
    await tapVisible(tester, find.text('Clear'));
    await drawSample(tester, 'a');
    await tapVisible(tester, find.text('Check'));
    expect(device.xp, 10);
    await tapVisible(tester, find.text('Next letter'));
    expect(tracePad(tester).watchProgress, isNotNull);
    expect(
      tester
          .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
          .template
          .character,
      'B',
    );
    expect(device.clips, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker is practice only and resumes the shuffled pair', (
    tester,
  ) async {
    final device = seeded(forms: 1);
    await openWriting(tester, device);
    expect(
      tester
          .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
          .template
          .character,
      'a',
    );
    final original = device.document;
    await tapVisible(tester, find.byTooltip('Choose a letter'));
    await tapVisible(tester, find.byKey(const ValueKey('pick-letter-B')));
    expect(find.text('Practice only · no XP'), findsOneWidget);
    await drawSample(tester, 'B');
    await tapVisible(tester, find.text('Check'));
    await tapVisible(tester, find.text('Next: lowercase'));
    await drawSample(tester, 'b');
    await tapVisible(tester, find.text('Check'));
    expect(device.document, original);
    await tapVisible(tester, find.text('Practice this letter again'));
    expect(
      tester
          .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
          .template
          .character,
      'B',
    );
    await tapVisible(tester, find.byTooltip('Choose a letter'));
    await tapVisible(tester, find.text('Shuffled alphabet'));
    expect(
      tester
          .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
          .template
          .character,
      'a',
    );
    expect(device.document, original);
  });

  testWidgets(
    'partial completion resumes after Back; skipped pairs earn nothing',
    (tester) async {
      final device = seeded();
      await openWriting(tester, device);
      await drawSample(tester, 'A');
      await tapVisible(tester, find.text('Check'));
      await tapVisible(tester, find.byTooltip('Back to writing'));
      await tapVisible(tester, find.text('Handwriting'));
      expect(
        tester
            .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
            .template
            .character,
        'a',
      );
      await tapVisible(tester, find.text('Skip letter'));
      expect(device.xp, 0);
      expect(
        tester
            .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
            .template
            .character,
        'B',
      );
    },
  );

  testWidgets(
    'saving waits without timeout; retry after route exit awards once',
    (tester) async {
      final device = SlowDevice()..document = seeded(forms: 1).document;
      await openWriting(tester, device);
      await drawSample(tester, 'a');
      device.pending = Completer<void>();
      await tapVisible(tester, find.text('Check'));
      expect(tracePad(tester).watchProgress, isNull);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('writing-watch')))
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(device.xp, 0);
      expect(find.text('Both letters complete! 10 XP earned!'), findsNothing);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('writing-picker')))
            .onPressed,
        isNull,
      );
      device.commitThenFail = true;
      device.pending!.complete();
      await settle(tester);
      expect(find.text('Try saving again'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Back to writing'));
      await tapVisible(tester, find.byTooltip('Back to home'));
      device.pending = null;
      device.commitThenFail = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(device.xp, 10);
      await tapVisible(tester, find.text('Writing'));
      await tapVisible(tester, find.text('Handwriting'));
      expect(find.text('10 XP already saved for this letter.'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
      await drawSample(tester, 'a');
      await tapVisible(tester, find.text('Check'));
      expect(device.xp, 10);
    },
  );

  testWidgets(
    'cancel and background discard only active stroke; drawing never scrolls',
    (tester) async {
      await openWriting(tester, seeded());
      final finder = find.byKey(const ValueKey('freehand-pad'));
      await tester.ensureVisible(finder);
      await tester.pump();
      final pad = tester.widget<WritingPad>(finder);
      final start = tester.getCenter(finder);
      final before = tester.getTopLeft(finder);
      final gesture = await tester.startGesture(start - const Offset(0, 70));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      expect(tester.getTopLeft(finder), before);
      await gesture.cancel();
      expect(pad.ink.isEmpty, isTrue);
      await drawSample(tester, 'A');
      final count = pad.ink.strokes.length;
      final partial = await tester.startGesture(start);
      await partial.moveBy(const Offset(20, 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(pad.ink.strokes.length, count);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await partial.up();
      expect(pad.ink.strokes.length, count);
    },
  );

  testWidgets(
    'extra pointers do not join ink and malformed input cannot grow forever',
    (tester) async {
      await openWriting(tester, seeded());
      final finder = find.byKey(const ValueKey('freehand-pad'));
      await tester.ensureVisible(finder);
      final pad = tester.widget<WritingPad>(finder),
          start = tester.getCenter(finder);
      final first = await tester.startGesture(start, pointer: 1);
      final second = await tester.startGesture(
        start + const Offset(40, 40),
        pointer: 2,
      );
      await second.moveBy(const Offset(10, 10));
      await second.up();
      await first.moveBy(const Offset(0, 40));
      await first.up();
      expect(pad.ink.strokes.length, 1);
      expect(pad.ink.strokes.single.length, 2);
      pad.ink.clear();
      for (var i = 0; i < 65; i++) {
        pad.ink.begin(const InkPoint(.5, .5));
        pad.ink.end();
      }
      expect(pad.ink.overflow, isTrue);
      expect(pad.ink.strokes.length, 64);
    },
  );

  testWidgets(
    'last turn summary and replay have no bonus; Back to home reaches root',
    (tester) async {
      final device = seeded(index: 25);
      await openWriting(tester, device);
      await drawSample(tester, 'Z');
      await tapVisible(tester, find.text('Check'));
      await tapVisible(tester, find.text('Next: lowercase'));
      await drawSample(tester, 'z');
      await tapVisible(tester, find.text('Check'));
      await tapVisible(tester, find.text('See alphabet reward'));
      expect(find.text('1 pair complete · 10 XP earned'), findsOneWidget);
      expect(device.xp, 10);
      await tapVisible(tester, find.text('New shuffled alphabet'));
      expect(PlayerProgress.decode(device.document).writing!.index, 0);
      expect(PlayerProgress.decode(device.document).writing!.letter, isNot(25));
      expect(device.xp, 10);
      await tapVisible(tester, find.byTooltip('Back to writing'));
      await tapVisible(tester, find.byTooltip('Back to home'));
      expect(find.text('Hi, Player 1!'), findsOneWidget);
    },
  );

  for (final (name, size) in [
    ('small', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Writing, picker and summary fit $name text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final key = GlobalKey();
        await openWriting(tester, seeded(), boundary: key);
        void padsVisible() {
          if (scale != 1.0 || (name != 'phone' && name != 'tablet')) return;
          final freehand = find.byKey(const ValueKey('freehand-pad'));
          final viewport = tester.getRect(
            find
                .ancestor(
                  of: freehand,
                  matching: find.byType(SingleChildScrollView),
                )
                .first,
          );
          for (final keyName in ['trace-pad', 'freehand-pad']) {
            final rectangle = tester.getRect(find.byKey(ValueKey(keyName)));
            expect(rectangle.top, greaterThanOrEqualTo(viewport.top));
            expect(rectangle.bottom, lessThanOrEqualTo(viewport.bottom));
          }
        }

        padsVisible();
        await capture(
          tester,
          key,
          '$name-$scale-upper',
          directory: 'writing-refresh',
        );
        await tester.ensureVisible(find.byKey(const ValueKey('freehand-pad')));
        await tester.pump();
        await capture(
          tester,
          key,
          '$name-$scale-freehand',
          directory: 'writing-refresh',
        );
        expect(tester.takeException(), isNull);
        void visibleAction(String keyName) {
          final finder = find.byKey(ValueKey(keyName));
          final rectangle = tester.getRect(finder);
          expect(rectangle.top, greaterThanOrEqualTo(0));
          expect(rectangle.bottom, lessThanOrEqualTo(size.height));
          expect(finder.hitTestable(), findsOneWidget);
        }

        visibleAction('writing-check');
        final pad = tester.widget<WritingPad>(
          find.byKey(const ValueKey('freehand-pad')),
        );
        for (final stroke in writingSamples['A']!) {
          pad.ink.begin(stroke.first);
          for (final point in stroke.skip(1)) {
            pad.ink.add(point);
          }
          pad.ink.end();
        }
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('writing-check')));
        await settle(tester);
        visibleAction('writing-continue');
        padsVisible();
        await capture(
          tester,
          key,
          '$name-$scale-success',
          directory: 'writing-refresh',
        );
        // Revisit an already completed form: both rechecking and advancing stay visible.
        await tester.tap(find.text('Clear'));
        await tester.pump();
        for (final stroke in writingSamples['A']!) {
          pad.ink.begin(stroke.first);
          for (final point in stroke.skip(1)) {
            pad.ink.add(point);
          }
          pad.ink.end();
        }
        await tester.pump();
        visibleAction('writing-check');
        visibleAction('writing-continue');
        // The extra repeat-check action shrinks the viewport. Watch adds a
        // header control, so use the existing scroll area to reveal the pad.
        await tester.ensureVisible(find.byKey(const ValueKey('freehand-pad')));
        await tester.pump();
        padsVisible();
        await capture(
          tester,
          key,
          '$name-$scale-repeat',
          directory: 'writing-refresh',
        );
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.byTooltip('Choose a letter'));
        await capture(
          tester,
          key,
          '$name-$scale-picker',
          directory: 'writing-refresh',
        );
        final picker = find.byKey(const ValueKey('pick-letter-Z'));
        await tester.scrollUntilVisible(
          picker,
          150,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('letter-picker-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tapVisible(tester, picker);
        await settle(tester);
        expect(
          tester
              .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
              .template
              .character,
          'Z',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await openWriting(tester, seeded(index: 9, forms: 1), boundary: key);
        await capture(
          tester,
          key,
          '$name-$scale-lower',
          directory: 'writing-refresh',
        );
        expect(
          tester
              .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
              .template
              .character,
          'j',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        final summary = MemoryDevice()
          ..document = PlayerProgress(
            xp: 90,
            lastRewardedRound: 'fixture',
            writing: WritingProgress(
              id: 'summary',
              order: List.generate(26, (i) => i),
              index: 26,
              forms: List.generate(26, (i) => i < 9 ? 3 : 0),
            ),
          ).encode();
        await openWriting(tester, summary, boundary: key);
        await capture(
          tester,
          key,
          '$name-$scale-summary',
          directory: 'writing-refresh',
        );
        await tapVisible(tester, find.text('Back to home'));
        expect(find.text('Hi, Player 1!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('reduced motion and muted haptics keep manual form advancement', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          accessibleNavigation: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final device = seeded()
      ..haptics = false
      ..tapNext = false;
    await openWriting(tester, device);
    await drawSample(tester, 'A');
    await tester.ensureVisible(find.text('Check'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('success-sparkles')), findsNothing);
    expect(device.feedbacks, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<WritingPad>(find.byKey(const ValueKey('freehand-pad')))
          .template
          .character,
      'A',
    );
    expect(find.text('Next: lowercase'), findsOneWidget);
    expect(device.xp, 0);
  });

  testWidgets(
    'resize across portrait and landscape keeps finished strokes and cancels the active one',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openWriting(tester, seeded());
      await drawSample(tester, 'A');
      final finder = find.byKey(const ValueKey('freehand-pad'));
      final ink = tester.widget<WritingPad>(finder).ink;
      final saved = ink.strokes;
      final gesture = await tester.startGesture(tester.getCenter(finder));
      await gesture.moveBy(const Offset(10, 20));
      tester.view.physicalSize = const Size(740, 360);
      await tester.pump();
      await tester.pump();
      await gesture.up();
      expect(ink.strokes, saved);
      expect(ink.drawing, isFalse);
      await tapVisible(tester, find.text('Check'));
      expect(find.text('Next: lowercase'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all 52 letter guides gallery', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final inks = <WritingInk>[];
    Widget guide(String letter) {
      final ink = WritingInk();
      inks.add(ink);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(letter, style: const TextStyle(fontSize: 26)),
              Expanded(
                child: WritingPad(
                  ink: ink,
                  template: letterTemplates[letter]!,
                  trace: true,
                  enabled: false,
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (var start = 0; start < 26; start += 5) {
      final letters = List.generate(
        (26 - start).clamp(0, 5),
        (i) => String.fromCharCode(65 + start + i),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Column(
                children: [
                  for (final upper in letters)
                    Expanded(
                      child: Row(
                        children: [guide(upper), guide(upper.toLowerCase())],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await capture(
        tester,
        key,
        'guides-${start + 1}',
        directory: 'writing-refresh',
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    for (final ink in inks) {
      ink.dispose();
    }
  });
}
