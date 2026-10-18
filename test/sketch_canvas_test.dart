import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/sketch.dart';
import 'package:rainbow_garden/sketch_ink.dart';
import 'package:rainbow_garden/widgets/sketch_canvas.dart';

const red = 0xFFFF0000;
const black = 0xFF000000;
const whitePixel = [255, 255, 255, 255];
const redPixel = [255, 0, 0, 255];

void dot(SketchCanvasController controller, Offset at, [int color = red]) {
  controller.beginStroke(at, color: color, width: 40);
  controller.endStroke();
}

Future<List<int>> pixel(ui.Image image, int x, int y) async {
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final index = (y * image.width + x) * 4;
  return bytes.buffer.asUint8List(bytes.offsetInBytes + index, 4).toList();
}

Future<void> compact(SketchCanvasController controller) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (controller.pendingBaseOps.isNotEmpty &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(controller.pendingBaseOps, isEmpty);
}

Future<Uint8List> renderSpecial(
  SketchSpecial special,
  List<Offset> points, {
  int color = 0xFF204080,
}) async {
  final recorder = ui.PictureRecorder();
  paintSketch(
    Canvas(recorder),
    size: const Size(320, 128),
    ops: [
      StrokeOp(
        SketchStroke(color: color, width: 24, points: points, special: special),
      ),
    ],
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 128);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void glitterLine(SketchCanvasController controller) {
  controller.beginStroke(
    const Offset(100, 100),
    color: red,
    width: 24,
    special: SketchSpecial.glitter,
  );
  controller.addPoint(const Offset(400, 100));
  controller.endStroke();
}

void main() {
  testWidgets(
    'twinkle overlay paints stars alone and stops for motion, mode and empty ink',
    (tester) async {
      final c = SketchCanvasController();
      Future<void> show({bool reduced = false, bool mode = true}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: GardenTheme.light,
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                enabled: mode,
                child: SketchCanvas(
                  controller: c,
                  color: red,
                  width: 24,
                  tool: SketchTool.brush,
                  enabled: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show();
      expect(tester.binding.transientCallbackCount, 0);
      c.setBase(null, twinkles: const [SketchTwinkle(960, 720, 0, 18)]);
      await tester.pump();
      final overlayFinder = find.byKey(const ValueKey('sketch-twinkles'));
      final overlay = tester.renderObject<RenderRepaintBoundary>(overlayFinder);
      final pageFinder = find
          .descendant(
            of: find.byType(SketchCanvas),
            matching: find.byType(RepaintBoundary),
          )
          .first;
      final page = tester.renderObject<RenderRepaintBoundary>(pageFinder);
      final painterFinder = find.descendant(
        of: pageFinder,
        matching: find.byType(CustomPaint),
      );
      final painter = tester.widget<CustomPaint>(painterFinder).painter!;
      page.debugResetMetrics();
      overlay.debugResetMetrics();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final image = await overlay.toImage();
        final center = await pixel(image, image.width ~/ 2, image.height ~/ 2);
        expect(center[0], greaterThan(200));
        expect(
          center[3],
          greaterThan(0),
          reason: 'white star at its on-screen anchor',
        );
        expect(await pixel(image, 10, 10), [0, 0, 0, 0]);
        image.dispose();
        final photo = await c.flattenRotated(1);
        final photoBytes = (await photo.toByteData())!.buffer.asUint8List();
        expect(
          photoBytes.every((byte) => byte == 255),
          isTrue,
          reason: 'the visible star never enters a photo snapshot',
        );
        photo.dispose();
      });
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(page.debugAsymmetricPaintCount + page.debugSymmetricPaintCount, 0);
      expect(overlay.debugAsymmetricPaintCount, greaterThanOrEqualTo(5));
      expect(tester.widget<CustomPaint>(painterFinder).painter, same(painter));
      expect(painter.shouldRepaint(painter), isFalse);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      for (final reduced in [true, false]) {
        await show(reduced: reduced, mode: reduced);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.runAsync(() async {
          final image = await overlay.toImage();
          final data = (await image.toByteData())!;
          expect(data.buffer.asUint8List().every((byte) => byte == 0), isTrue);
          image.dispose();
        });
      }
      await show();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      c.clear();
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  test(
    'twinkle coverage respects strokes, undo, redo, clear and revision cache',
    () {
      final c = SketchCanvasController();
      addTearDown(c.dispose);
      glitterLine(c);
      final anchors = c.visibleTwinkles;
      expect(anchors, isNotEmpty);
      expect(identical(c.visibleTwinkles, anchors), isTrue);
      dot(c, const Offset(700, 700));
      expect(c.visibleTwinkles, anchors);
      c.beginStroke(const Offset(80, 100), color: sketchPaperColor, width: 48);
      c.addPoint(const Offset(420, 100));
      expect(
        c.visibleTwinkles,
        anchors,
        reason: 'live ink does not change anchors',
      );
      c.endStroke();
      expect(c.visibleTwinkles, isEmpty);
      c.undo();
      expect(c.visibleTwinkles, anchors);
      c.redo();
      expect(c.visibleTwinkles, isEmpty);
      c.undo();
      c.clear();
      expect(c.visibleTwinkles, isEmpty);
      c.undo();
      expect(c.visibleTwinkles, anchors);
    },
  );

  testWidgets(
    'fill removes covered baked anchors and adds glitter fill anchors',
    (tester) async {
      final c = SketchCanvasController();
      await tester.runAsync(() async {
        c.setBase(null, twinkles: const [SketchTwinkle(100, 100, 1, 10)]);
        expect(
          await c.fill(const Offset(100, 100), const SolidInk(red)),
          isTrue,
        );
        expect(c.visibleTwinkles, isEmpty);
        c.undo();
        expect(c.visibleTwinkles, hasLength(1));
        c.redo();
        expect(c.visibleTwinkles, isEmpty);
        expect(
          await c.fill(
            const Offset(100, 100),
            const SpecialInk(SketchSpecial.glitter),
          ),
          isTrue,
        );
        final fill = c.ops.last as FillOp;
        expect(fill.twinkles, isNotEmpty);
        expect(fill.twinkles.length, lessThanOrEqualTo(150));
        expect(c.visibleTwinkles, fill.twinkles);
        c.clear();
        expect(c.visibleTwinkles, isEmpty);
      });
      c.dispose();
    },
  );

  testWidgets('compaction bakes glitter anchors without changing them', (
    tester,
  ) async {
    final c = SketchCanvasController();
    await tester.runAsync(() async {
      glitterLine(c);
      final anchors = c.visibleTwinkles;
      for (var i = 0; i < 35; i++) {
        dot(c, Offset(700, 500 + i * 20.0));
      }
      await compact(c);
      expect(c.bakedTwinkles, anchors);
      expect(c.visibleTwinkles, anchors);
      for (var i = 0; i < 30; i++) {
        c.undo();
      }
      expect(c.visibleTwinkles, anchors);
    });
    c.dispose();
  });

  test('twinkles drop the oldest anchors above 600', () {
    final c = SketchCanvasController();
    addTearDown(c.dispose);
    final seed = List.generate(
      600,
      (i) => SketchTwinkle(900, i.toDouble(), i, 10),
    );
    c.setBase(null, twinkles: seed);
    glitterLine(c);
    expect(c.visibleTwinkles, hasLength(600));
    expect(c.visibleTwinkles.last.x, lessThan(500));
    expect(c.visibleTwinkles, isNot(contains(seed.first)));
  });

  testWidgets('glitter raster baseline before twinkle extraction', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await renderSpecial(SketchSpecial.glitter, const [
        Offset(20, 60),
        Offset(55, 35),
        Offset(110, 75),
        Offset(170, 45),
        Offset(290, 65),
      ]);
      var hash = 2166136261;
      for (final byte in bytes) {
        hash = ((hash ^ byte) * 16777619) & 0xFFFFFFFF;
      }
      expect(hash, 1194930207);
    });
  });

  testWidgets('neon keeps its halo on a perfectly horizontal line', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Zero-height path bounds once dropped the mask-filtered glow on device.
      final bytes = await renderSpecial(SketchSpecial.neon, const [
        Offset(60, 64),
        Offset(160, 64),
        Offset(260, 64),
      ]);
      // 24-unit width: the core ends near y=57; y=40 is only reached by the halo.
      final i = (40 * 320 + 160) * 4;
      expect(bytes[i + 1], lessThan(250), reason: 'halo tint above the line');
      expect(bytes[i + 3], 255);
    });
  });

  for (final special in [SketchSpecial.glitter, SketchSpecial.neon]) {
    testWidgets(
      '${special.name} replays deterministically and keeps the earlier stroke stable',
      (tester) async {
        await tester.runAsync(() async {
          const points = [
            Offset(40, 64),
            Offset(80, 60),
            Offset(120, 68),
            Offset(160, 64),
            Offset(200, 72),
          ];
          final first = await renderSpecial(special, points);
          expect(await renderSpecial(special, points), first);
          final extended = await renderSpecial(special, [
            ...points,
            const Offset(240, 64),
            const Offset(270, 60),
          ]);
          // Neon's translucent halo is one blurred draw, so appending may move
          // antialiasing by a few levels; sparkles and opaque ink stay exact.
          final tolerance = special == SketchSpecial.neon ? 6 : 0;
          for (var y = 0; y < 128; y++) {
            for (var i = y * 320 * 4; i < (y * 320 + 115) * 4; i++) {
              if ((extended[i] - first[i]).abs() > tolerance) {
                fail('row $y byte $i: ${extended[i]} vs ${first[i]}');
              }
            }
          }
          expect(
            await renderSpecial(special, points, color: red),
            isNot(first),
          );
          final dot = await renderSpecial(special, [const Offset(64, 64)]);
          expect(await renderSpecial(special, [const Offset(64, 64)]), dot);
          expect(dot, isNot(await renderSpecial(special, [])));
        });
      },
    );

    testWidgets(
      '${special.name} fill uses the supplied base color and remains undoable',
      (tester) async {
        final controller = SketchCanvasController();
        await tester.runAsync(() async {
          expect(
            await controller.fill(
              const Offset(100, 100),
              SpecialInk(special),
              color: 0xFF204080,
            ),
            isTrue,
          );
          final image = (controller.ops.single as FillOp).image!;
          final corner = await pixel(image, 0, 0);
          if (special == SketchSpecial.neon) {
            expect(corner, [32, 64, 128, 255]);
          } else {
            final bytes = (await image.toByteData())!.buffer.asUint8List();
            expect(bytes.sublist(0, 4000), containsAll([32, 64, 128]));
          }
          controller.undo();
          expect(controller.ops, isEmpty);
          controller.redo();
          expect(controller.ops.single, isA<FillOp>());
        });
        controller.dispose();
      },
    );
  }

  testWidgets(
    'glitter has base pixels and bright sparkles within padded stroke bounds, including dots',
    (tester) async {
      await tester.runAsync(() async {
        for (final points in [
          [const Offset(40, 64), const Offset(240, 64)],
          [const Offset(64, 64)],
        ]) {
          final bytes = await renderSpecial(SketchSpecial.glitter, points);
          var basePixels = 0;
          var sparkles = 0;
          for (var y = 0; y < 128; y++) {
            for (var x = 0; x < 320; x++) {
              final i = (y * 320 + x) * 4;
              final rgb = bytes.sublist(i, i + 3);
              final inside =
                  x >= points.first.dx - 17 &&
                  x <= points.last.dx + 17 &&
                  y >= 47 &&
                  y <= 81;
              if (!inside) {
                expect(rgb, [255, 255, 255]);
                continue;
              }
              if (rgb[0] == 32 && rgb[1] == 64 && rgb[2] == 128) basePixels++;
              // Count only the dark interior, so paper cannot count as glitter.
              final inCore =
                  x >= points.first.dx &&
                  x <= points.last.dx + 2 &&
                  (y - 64).abs() < 5;
              if (inCore &&
                  rgb[0] > 220 &&
                  rgb[1] > 185 &&
                  (rgb[2] > 220 || rgb[2] < 110)) {
                sparkles++;
              }
            }
          }
          expect(basePixels, greaterThan(0));
          expect(sparkles, greaterThan(0));
        }
      });
    },
  );

  testWidgets('neon has a tinted halo and a lighter core for paths and dots', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final points in [
        [const Offset(40, 64), const Offset(240, 64)],
        [const Offset(120, 64)],
      ]) {
        final bytes = await renderSpecial(SketchSpecial.neon, points);
        final core = bytes.sublist(
          (64 * 320 + 120) * 4,
          (64 * 320 + 120) * 4 + 3,
        );
        final halo = bytes.sublist(
          (86 * 320 + 120) * 4,
          (86 * 320 + 120) * 4 + 3,
        );
        for (var c = 0; c < 3; c++) {
          expect(core[c], greaterThan([32, 64, 128][c]));
          expect(halo[c], lessThan(255));
        }
        expect(halo[2], greaterThan(halo[0]));
      }
    });
  });

  testWidgets(
    'rainbow paths cycle colors, dots start red, solid ink stays solid',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        paintSketch(
          Canvas(recorder),
          size: const Size(500, 160),
          ops: [
            StrokeOp(
              SketchStroke(
                color: black,
                width: 12,
                special: SketchSpecial.rainbow,
                points: [const Offset(20, 40), const Offset(340, 40)],
              ),
            ),
            StrokeOp(
              SketchStroke(
                color: black,
                width: 20,
                special: SketchSpecial.rainbow,
                points: [const Offset(400, 40)],
              ),
            ),
            StrokeOp(
              SketchStroke(
                color: red,
                width: 12,
                points: [const Offset(20, 110), const Offset(340, 110)],
              ),
            ),
          ],
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(500, 160);
        final colors = <List<int>>[];
        for (var band = 0; band < 6; band++) {
          final sample = await pixel(image, 24 + band * 40, 40);
          colors.add(sample);
          final expected = sketchRainbowBands[band];
          for (var channel = 0; channel < 3; channel++) {
            expect(
              sample[channel],
              closeTo((expected >> (16 - channel * 8)) & 255, 55),
            );
          }
          expect(await pixel(image, 24 + band * 40, 110), redPixel);
        }
        expect(colors.map((color) => color.join(',')).toSet(), hasLength(6));
        expect(await pixel(image, 400, 40), [229, 57, 53, 255]);
        image.dispose();
        picture.dispose();
      });
    },
  );

  testWidgets('rainbow fill stripes a closed shape and Undo removes the fill', (
    tester,
  ) async {
    final controller = SketchCanvasController();
    for (final line in [
      [const Offset(100, 100), const Offset(500, 100)],
      [const Offset(500, 100), const Offset(500, 700)],
      [const Offset(500, 700), const Offset(100, 700)],
      [const Offset(100, 700), const Offset(100, 100)],
    ]) {
      controller.beginStroke(line.first, color: black, width: 32);
      controller.addPoint(line.last);
      controller.endStroke();
    }
    await tester.runAsync(() async {
      expect(
        await controller.fill(
          const Offset(300, 400),
          const SpecialInk(SketchSpecial.rainbow),
        ),
        isTrue,
      );
      final fill = controller.ops.last as FillOp;
      final mask = fill.image!;
      for (var band = 0; band < 6; band++) {
        final expected = sketchRainbowBands[band];
        expect(
          await pixel(
            mask,
            mask.width ~/ 2,
            ((band + .5) * mask.height / 6).floor(),
          ),
          [(expected >> 16) & 255, (expected >> 8) & 255, expected & 255, 255],
        );
      }
      final image = await controller.flatten();
      expect(await pixel(image, 300, 140), [229, 57, 53, 255]);
      expect(await pixel(image, 300, 660), [142, 54, 201, 255]);
      expect(await pixel(image, 50, 400), whitePixel);
      image.dispose();
      controller.undo();
      expect(controller.ops.whereType<FillOp>(), isEmpty);
      final undone = await controller.flatten();
      expect(await pixel(undone, 300, 400), whitePixel);
      expect(await pixel(undone, 100, 400), [0, 0, 0, 255]);
      undone.dispose();
    });
    controller.dispose();
  });

  testWidgets('brush forwards Rainbow and eraser always paints paper white', (
    tester,
  ) async {
    final controller = SketchCanvasController();
    Future<void> show(SketchTool tool) => tester.pumpWidget(
      MaterialApp(
        home: SketchCanvas(
          controller: controller,
          color: red,
          width: 80,
          special: SketchSpecial.rainbow,
          tool: tool,
          enabled: true,
        ),
      ),
    );
    await show(SketchTool.brush);
    await tester.tap(find.byType(SketchCanvas));
    expect(
      (controller.ops.single as StrokeOp).stroke.special,
      SketchSpecial.rainbow,
    );
    await show(SketchTool.eraser);
    await tester.tap(find.byType(SketchCanvas));
    final eraser = (controller.ops.last as StrokeOp).stroke;
    expect(eraser.special, isNull);
    expect(eraser.color, sketchPaperColor);
    await tester.runAsync(() async {
      final image = await controller.flatten();
      expect(
        await pixel(
          image,
          eraser.points.first.dx.floor(),
          eraser.points.first.dy.floor(),
        ),
        whitePixel,
      );
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test('fresh viewport is silent and the first mark fixes page geometry', () {
    final controller = SketchCanvasController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    expect(controller.viewport, Size.zero);
    expect(controller.viewScale, 0);
    expect(controller.isFresh, isTrue);
    expect(controller.pageSize, const Size(1080, 1920));
    controller.viewport = const Size(400, 800);
    expect(controller.pageSize, const Size(960, 1920));
    controller.viewport = const Size(800, 500);
    expect(controller.pageSize, const Size(1920, 1200));
    expect(notifications, 0);
    controller.beginStroke(const Offset(1500, 600), color: red, width: 40);
    expect(controller.isFresh, isFalse);
    controller.viewport = const Size(400, 800);
    expect(controller.pageSize, const Size(1920, 1200));
    controller.endStroke();
    controller.undo();
    expect(
      controller.isFresh,
      isFalse,
      reason: 'Redo still owns page geometry',
    );
    expect(controller.pageSize, const Size(1920, 1200));
    controller.redo();
    controller.setBase(null);
    expect(controller.isFresh, isTrue);
    expect(controller.pageSize, const Size(960, 1920));
  });

  testWidgets(
    'loaded geometry, resizing clear, undo and redo preserve pixels',
    (tester) async {
      final controller = SketchCanvasController()
        ..viewport = const Size(800, 500);
      await tester.runAsync(() async {
        dot(controller, const Offset(1500, 600));
        final loaded = await controller.flatten();
        controller.setBase(loaded);
        controller.viewport = const Size(400, 800);
        expect(controller.pageSize, const Size(1920, 1200));
        controller.clear();
        expect((controller.ops.single as ClearOp).size, const Size(960, 1920));
        final cleared = await controller.flatten();
        expect((cleared.width, cleared.height), (960, 1920));
        expect(await pixel(cleared, 500, 600), whitePixel);
        cleared.dispose();
        controller.undo();
        expect(controller.pageSize, const Size(1920, 1200));
        final undone = await controller.flatten();
        expect((undone.width, undone.height), (1920, 1200));
        expect(await pixel(undone, 1500, 600), redPixel);
        undone.dispose();
        controller.redo();
        expect(controller.pageSize, const Size(960, 1920));
        final redone = await controller.flatten();
        expect(await pixel(redone, 500, 600), whitePixel);
        redone.dispose();
      });
      controller.dispose();
    },
  );

  testWidgets('compaction crosses a resizing clear under continuing input', (
    tester,
  ) async {
    final controller = SketchCanvasController()
      ..viewport = const Size(400, 800);
    await tester.runAsync(() async {
      for (var i = 0; i < 32; i++) {
        dot(controller, const Offset(100, 100));
      }
      controller.viewport = const Size(800, 500);
      controller.clear();
      dot(controller, const Offset(1600, 700));
      // Yield while the first merge rasterizes, then evict the clear too.
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 32; i++) {
        dot(controller, const Offset(1600, 700));
      }
      expect(controller.busy, isFalse);
      await compact(controller);
      expect((controller.base!.width, controller.base!.height), (1920, 1200));
      final image = await controller.flatten();
      expect(await pixel(image, 100, 100), whitePixel);
      expect(await pixel(image, 1600, 700), redPixel);
      image.dispose();
      for (var i = 0; i < 30; i++) {
        controller.undo();
      }
      expect(controller.canUndo, isFalse);
      expect(controller.pageSize, const Size(1920, 1200));
      final base = await controller.flatten();
      expect(await pixel(base, 100, 100), whitePixel);
      expect(await pixel(base, 1600, 700), redPixel);
      base.dispose();
    });
    controller.dispose();
  });

  testWidgets(
    'landscape fill captures geometry before a later resizing clear',
    (tester) async {
      final controller = SketchCanvasController()
        ..viewport = const Size(800, 500);
      // Use a rectangle assembled from straight strokes to leave sharp corners.
      for (final line in [
        [const Offset(1200, 200), const Offset(1800, 200)],
        [const Offset(1800, 200), const Offset(1800, 1000)],
        [const Offset(1800, 1000), const Offset(1200, 1000)],
        [const Offset(1200, 1000), const Offset(1200, 200)],
      ]) {
        controller.beginStroke(line.first, color: black, width: 32);
        controller.addPoint(line.last);
        controller.endStroke();
      }
      await tester.runAsync(() async {
        final fill = controller.fill(
          const Offset(1500, 600),
          const SolidInk(red),
        );
        expect(controller.busy, isTrue);
        expect(controller.ops.last, isA<FillOp>());
        controller.viewport = const Size(400, 800);
        controller.clear();
        dot(controller, const Offset(200, 300), black);
        expect(controller.pageSize, const Size(960, 1920));
        await controller.idle;
        expect(await fill, isTrue);
        controller.undo();
        controller.undo();
        expect(controller.pageSize, const Size(1920, 1200));
        final image = await controller.flatten();
        expect((image.width, image.height), (1920, 1200));
        expect(await pixel(image, 1500, 600), redPixel);
        expect(await pixel(image, 500, 600), whitePixel);
        expect(await pixel(image, 1200, 600), [0, 0, 0, 255]);
        image.dispose();
        final count = controller.ops.length;
        expect(
          await controller.fill(const Offset(1500, 600), const SolidInk(red)),
          isFalse,
        );
        expect(controller.ops, hasLength(count));
      });
      controller.dispose();
    },
  );

  testWidgets('clockwise export rotates dimensions and pixels for all turns', (
    tester,
  ) async {
    final controller = SketchCanvasController()
      ..viewport = const Size(800, 500);
    dot(controller, const Offset(1500.5, 300.5));
    await tester.runAsync(() async {
      for (final turns in [0, 1, 2, 3]) {
        final image = await controller.flattenRotated(turns);
        expect((
          image.width,
          image.height,
        ), turns.isOdd ? (1200, 1920) : (1920, 1200));
        final (x, y) = switch (turns) {
          0 => (1500, 300),
          1 => (1199 - 300, 1500),
          2 => (1919 - 1500, 1199 - 300),
          _ => (300, 1919 - 1500),
        };
        expect(await pixel(image, x, y), redPixel, reason: 'turn $turns');
        expect(await pixel(image, 30, 30), whitePixel);
        image.dispose();
      }
      expect(controller.pageSize, const Size(1920, 1200));
      expect(controller.ops, hasLength(1));
    });
    controller.dispose();
  });

  testWidgets('pending fills retain tap order during compaction and disposal', (
    tester,
  ) async {
    final controller = SketchCanvasController()
      ..viewport = const Size(800, 500);
    await tester.runAsync(() async {
      final first = controller.fill(
        const Offset(100, 100),
        const SolidInk(red),
      );
      final second = controller.fill(
        const Offset(100, 100),
        const SolidInk(black),
      );
      dot(controller, const Offset(1500, 600));
      for (var i = 0; i < 35; i++) {
        dot(controller, const Offset(1000, 600));
      }
      await controller.idle;
      expect(await first, isTrue);
      expect(await second, isTrue);
      await compact(controller);
      final image = await controller.flatten();
      expect(await pixel(image, 100, 100), [0, 0, 0, 255]);
      expect(await pixel(image, 1500, 600), redPixel);
      image.dispose();
      final pending = controller.fill(Offset.zero, const SolidInk(red));
      controller.dispose();
      expect(await pending, isFalse);
    });
  });

  testWidgets('a first fill fixes geometry and clamps the landscape seed', (
    tester,
  ) async {
    final controller = SketchCanvasController()
      ..viewport = const Size(800, 500);
    await tester.runAsync(() async {
      final pending = controller.fill(
        const Offset(5000, -100),
        const SolidInk(red),
      );
      controller.viewport = const Size(400, 800);
      expect(controller.isFresh, isFalse);
      expect(controller.pageSize, const Size(1920, 1200));
      expect(await pending, isTrue);
      final image = await controller.flatten();
      expect((image.width, image.height), (1920, 1200));
      expect(await pixel(image, 1919, 0), redPixel);
      expect(await pixel(image, 100, 1199), redPixel);
      image.dispose();
    });
    controller.dispose();
  });

  testWidgets('rotation and resize cancel strokes without committing ink', (
    tester,
  ) async {
    final controller = SketchCanvasController();
    var turns = 0;
    var extent = const Size(500, 500);
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.dark,
        home: Center(
          child: SizedBox.fromSize(
            size: extent,
            child: SketchCanvas(
              controller: controller,
              color: red,
              width: 32,
              tool: SketchTool.brush,
              enabled: true,
              quarterTurns: turns,
            ),
          ),
        ),
      ),
    );
    await show();
    final center = tester.getCenter(find.byType(SketchCanvas));
    final rotating = await tester.startGesture(center);
    expect(controller.live, isNotNull);
    turns = 2; // Natural layout is unchanged for a half turn.
    await show();
    expect(controller.live, isNull);
    await rotating.up();
    expect(controller.ops, isEmpty);
    final resizing = await tester.startGesture(center);
    expect(controller.live, isNotNull);
    extent = const Size(400, 500);
    await show();
    expect(controller.live, isNull);
    await resizing.up();
    expect(controller.ops, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('rotated margins, second pointers, and fill slop stay ignored', (
    tester,
  ) async {
    final controller = SketchCanvasController();
    var tool = SketchTool.brush;
    final fills = <Offset>[];
    // Retain a portrait page within a square viewport to exercise margins.
    dot(controller, const Offset(500, 500));
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.light,
        home: Center(
          child: SizedBox(
            width: 500,
            height: 500,
            child: SketchCanvas(
              controller: controller,
              color: red,
              width: 32,
              tool: tool,
              enabled: true,
              quarterTurns: 3,
              onFill: fills.add,
            ),
          ),
        ),
      ),
    );
    await show();
    final bounds = tester.getRect(find.byType(SketchCanvas));
    await tester.tapAt(bounds.topLeft + const Offset(5, 5));
    expect(controller.ops, hasLength(1));
    final first = await tester.startGesture(bounds.center, pointer: 1);
    final second = await tester.startGesture(
      bounds.center + const Offset(30, 0),
      pointer: 2,
    );
    await second.moveBy(const Offset(50, 0));
    await second.up();
    expect(controller.live!.points, hasLength(1));
    await first.cancel();
    expect(controller.ops, hasLength(1));
    tool = SketchTool.fill;
    await show();
    final drag = await tester.startGesture(bounds.center);
    await drag.moveBy(const Offset(40, 0));
    await drag.moveTo(bounds.center);
    await drag.up();
    expect(fills, isEmpty);
    await tester.tapAt(bounds.center);
    expect(fills, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  for (final turns in [0, 1, 2, 3]) {
    testWidgets('turn $turns maps physical taps and drags to natural page', (
      tester,
    ) async {
      const natural = Size(393, 852);
      final surface = turns.isOdd ? const Size(852, 393) : natural;
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = SketchCanvasController();
      await tester.pumpWidget(
        MaterialApp(
          theme: GardenTheme.light,
          home: SketchCanvas(
            controller: controller,
            color: red,
            width: 32,
            tool: SketchTool.brush,
            enabled: true,
            quarterTurns: turns,
          ),
        ),
      );
      expect(controller.viewport, natural);
      final rect = SketchCanvas.pageRect(natural, controller.pageSize);
      expect(
        rect.width * rect.height / (natural.width * natural.height),
        greaterThanOrEqualTo(0.95),
      );
      expect(controller.viewScale, closeTo(rect.width / 886, 0.000001));
      Offset screen(Offset point) => switch (turns) {
        0 => point,
        1 => Offset(natural.height - point.dy, point.dx),
        2 => Offset(natural.width - point.dx, natural.height - point.dy),
        _ => Offset(point.dy, natural.width - point.dx),
      };
      const start = Offset(100, 200);
      const finish = Offset(150, 300);
      final gesture = await tester.startGesture(screen(start));
      await gesture.moveTo(screen(finish));
      await gesture.up();
      final stroke = (controller.ops.single as StrokeOp).stroke;
      final expectedStart = (start - rect.topLeft) / controller.viewScale;
      final expectedFinish = (finish - rect.topLeft) / controller.viewScale;
      expect(stroke.points.first.dx, closeTo(expectedStart.dx, 0.00001));
      expect(stroke.points.first.dy, closeTo(expectedStart.dy, 0.00001));
      expect(stroke.points.last.dx, closeTo(expectedFinish.dx, 0.00001));
      expect(stroke.points.last.dy, closeTo(expectedFinish.dy, 0.00001));
      await tester.tapAt(screen(start));
      expect(
        (controller.ops.last as StrokeOp).stroke.points.first.dx,
        closeTo(expectedStart.dx, 0.00001),
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
