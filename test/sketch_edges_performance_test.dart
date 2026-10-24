import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/sketch.dart';
import 'package:rainbow_garden/sketch_ink.dart';
import 'package:rainbow_garden/widgets/sketch_canvas.dart';

Future<void> showCanvas(WidgetTester tester, SketchCanvasController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: GardenTheme.light,
      home: Center(
        child: SizedBox(
          width: 500,
          height: 500,
          child: SketchCanvas(
            controller: c,
            color: 0xFFFF0000,
            width: 24,
            tool: SketchTool.brush,
            enabled: true,
          ),
        ),
      ),
    ),
  );
}

SketchCanvasController portraitPage() {
  final c = SketchCanvasController();
  c.beginStroke(const Offset(500, 500), color: 0xFF000000, width: 24);
  c.endStroke();
  return c;
}

void main() {
  test(
    'segment crossing handles fast traversal and rejects parallel misses',
    () {
      const page = Rect.fromLTWH(10, 10, 100, 100);
      expect(
        sketchSegmentEntersPage(
          const Offset(0, 60),
          const Offset(120, 60),
          page,
        ),
        isTrue,
      );
      expect(
        sketchSegmentEntersPage(
          const Offset(60, 0),
          const Offset(60, 120),
          page,
        ),
        isTrue,
      );
      expect(
        sketchSegmentEntersPage(Offset.zero, const Offset(120, 120), page),
        isTrue,
      );
      expect(
        sketchSegmentEntersPage(Offset.zero, const Offset(120, 0), page),
        isFalse,
      );
      expect(
        sketchSegmentEntersPage(Offset.zero, const Offset(0, 120), page),
        isFalse,
      );
    },
  );

  for (final turns in [0, 1, 2, 3]) {
    testWidgets('all four margins accept strokes with rotation $turns', (
      tester,
    ) async {
      final c = SketchCanvasController();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: SketchCanvas(
                controller: c,
                color: 0xFFFF0000,
                width: 12,
                tool: SketchTool.brush,
                enabled: true,
                quarterTurns: turns,
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
              ),
            ),
          ),
        ),
      );
      final r = tester.getRect(find.byType(SketchCanvas));
      for (final start in [
        r.centerLeft + const Offset(2, 0),
        r.centerRight - const Offset(2, 0),
        r.topCenter + const Offset(0, 2),
        r.bottomCenter - const Offset(0, 2),
      ]) {
        final count = c.ops.length;
        final gesture = await tester.startGesture(start);
        await gesture.moveTo(r.center);
        await gesture.up();
        expect(c.ops.length, count + 1);
        expect(
          (c.ops.last as StrokeOp).stroke.points.length,
          greaterThanOrEqualTo(2),
        );
      }
      final before = c.ops.length;
      final cancelled = await tester.startGesture(
        r.centerLeft + const Offset(2, 0),
      );
      await cancelled.moveTo(r.center);
      await cancelled.cancel();
      expect(c.ops.length, before);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets(
    'cached ink matches exact replay after edits and ignores live ink',
    (tester) async {
      await tester.runAsync(() async {
        final c = SketchCanvasController();
        c.viewport = const Size(400, 300);
        Future<void> compare() async {
          await c.prepareDisplay();
          final recorder = ui.PictureRecorder();
          paintSketch(
            Canvas(recorder),
            size: c.pageSize,
            base: c.base,
            ops: c.ops,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(
            c.pageSize.width.toInt(),
            c.pageSize.height.toInt(),
          );
          final expected = (await image.toByteData())!.buffer.asUint8List();
          final actual = (await c.displayImage!.toByteData())!.buffer
              .asUint8List();
          expect(
            listEquals(actual, expected),
            isTrue,
            reason: 'display cache must match full-resolution replay',
          );
          image.dispose();
          picture.dispose();
        }

        for (final special in <SketchSpecial?>[null, ...SketchSpecial.values]) {
          c.beginStroke(
            const Offset(-30, 100),
            color: 0xFF204080,
            width: 24,
            special: special,
          );
          c.addPoint(const Offset(300, 100));
          c.endStroke();
          await compare();
        }
        final cached = c.displayImage;
        c.beginStroke(const Offset(50, 500), color: 0xFFFF0000, width: 60);
        c.addPoint(const Offset(400, 500));
        expect(c.displayImage, same(cached));
        await compare();
        c.cancelStroke();
        // Change history while a raster request is in flight.
        c.undo();
        final pending = c.prepareDisplay();
        c.clear();
        c.undo();
        c.redo();
        await pending;
        await compare();
        c.undo();
        await compare();
        c.releaseDisplay();
        expect(c.displayImage, isNull);
        c.dispose();
      });
    },
  );

  testWidgets(
    'simultaneous autosave and cache own independent exact snapshots',
    (tester) async {
      await tester.runAsync(() async {
        final c = portraitPage();
        final cache = c.prepareDisplay();
        final saved = c.flatten();
        final secondSaved = c.flatten();
        c.clear();
        final first = await saved;
        final second = await secondSaved;
        await cache;
        final before = (await first.toByteData())!.buffer.asUint8List();
        c.dispose();
        first.dispose();
        final after = (await second.toByteData())!.buffer.asUint8List();
        expect(listEquals(before, after), isTrue);
        expect(
          after.any((value) => value != 255),
          isTrue,
          reason:
              'the save predates Clear even when rasterization finishes later',
        );
        second.dispose();
      });
    },
  );

  testWidgets('disposal discards a pending raster safely', (tester) async {
    await tester.runAsync(() async {
      final c = portraitPage();
      final pending = c.prepareDisplay();
      c.dispose();
      await pending;
      expect(c.displayImage, isNull);
    });
  });

  test(
    'outside samples retain their direction instead of smearing on an edge',
    () {
      final stroke = StrokeBuilder(
        color: 0xFFFF0000,
        width: 24,
        page: const Size(100, 100),
      );
      stroke.add(const Offset(-20, 30));
      stroke.add(const Offset(-20, 60));
      stroke.add(const Offset(50, 60));
      expect(stroke.build().points, [
        const Offset(-20, 30),
        const Offset(-20, 60),
        const Offset(50, 60),
      ]);
    },
  );

  testWidgets(
    'a margin start enters the page and outside-only gestures do nothing',
    (tester) async {
      final c = portraitPage();
      await showCanvas(tester, c);
      final bounds = tester.getRect(find.byType(SketchCanvas));
      final gesture = await tester.startGesture(
        bounds.centerLeft + const Offset(5, 0),
      );
      await gesture.moveTo(bounds.center);
      await gesture.up();
      expect(c.ops, hasLength(2));
      final stroke = (c.ops.last as StrokeOp).stroke;
      expect(stroke.points.first.dx, lessThan(0));
      expect(stroke.points.last.dx, greaterThan(0));
      final revision = c.revision;
      final outside = await tester.startGesture(
        bounds.topLeft + const Offset(5, 20),
      );
      await outside.moveBy(const Offset(0, 100));
      await outside.up();
      expect(c.ops, hasLength(2));
      expect(c.revision, revision);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'background twinkles freeze during a stroke and resume on cancellation',
    (tester) async {
      final c = SketchCanvasController();
      c.setBase(null, twinkles: const [SketchTwinkle(960, 720, 0, 18)]);
      await showCanvas(tester, c);
      final overlay = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('sketch-twinkles')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SketchCanvas)),
      );
      await tester.pump();
      overlay.debugResetMetrics();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        overlay.debugSymmetricPaintCount + overlay.debugAsymmetricPaintCount,
        0,
      );
      expect(tester.binding.transientCallbackCount, 0);
      await gesture.cancel();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('finished ink does not repaint when a live stroke moves', (
    tester,
  ) async {
    final c = portraitPage();
    await showCanvas(tester, c);
    final page = tester.renderObject<RenderRepaintBoundary>(
      find
          .descendant(
            of: find.byType(SketchCanvas),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SketchCanvas)),
    );
    await tester.pump();
    page.debugResetMetrics();
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    expect(page.debugSymmetricPaintCount + page.debugAsymmetricPaintCount, 0);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
