import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/sketch_page.dart';
import 'package:rainbow_garden/sketch.dart';
import 'package:rainbow_garden/sketch_ink.dart';
import 'package:rainbow_garden/sketch_store.dart';
import 'package:rainbow_garden/widgets/sketch_canvas.dart';
import 'package:rainbow_garden/widgets/special_swatch.dart';

import 'widget_test.dart' show MemoryDevice;

class GalleryFailureDevice extends MemoryDevice {
  @override
  Future<String> saveToGallery(
    Uint8List png,
    String displayName, {
    String? replaceUri,
  }) async {
    throw StateError('Photos unavailable');
  }
}

class GalleryCaptureDevice extends MemoryDevice {
  Uint8List? exported;
  final replaceUris = <String?>[];

  @override
  Future<String> saveToGallery(
    Uint8List png,
    String displayName, {
    String? replaceUri,
  }) async {
    exported = Uint8List.fromList(png);
    replaceUris.add(replaceUri);
    return super.saveToGallery(png, displayName, replaceUri: replaceUri);
  }
}

Finder keyed(String key) => find.byKey(ValueKey(key));

ui.DisplayFeature cutout(Rect bounds) => ui.DisplayFeature(
  bounds: bounds,
  type: ui.DisplayFeatureType.cutout,
  state: ui.DisplayFeatureState.unknown,
);

Future<void> settleImages(WidgetTester tester) async {
  await tester.pump();
  // Native PNG work needs real isolate time; don't spin a progress indicator
  // through pumpAndSettle's fake clock while its codec is still running.
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byIcon(Icons.hourglass_top_rounded).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
  // Route disposal can start its final PNG flush during the transition.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pumpAndSettle();
}

Future<void> flushStore(WidgetTester tester, SketchStore store) async {
  var done = false;
  final flushed = store.flush().whenComplete(() => done = true);
  for (var i = 0; !done && i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(done, isTrue, reason: 'Pending PNG encoding must finish');
  await flushed;
}

Future<void> waitForFills(
  WidgetTester tester,
  SketchCanvasController controller,
) async {
  for (var i = 0; controller.busy && i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(controller.busy, isFalse, reason: 'Queued fills must finish');
}

Future<({ProgressController progress, SketchStore store})> mount(
  WidgetTester tester,
  MemoryDevice device, {
  bool dark = false,
  double scale = 1,
  EdgeInsets? padding,
  bool reducedMotion = false,
  bool? saveToPhotos,
}) async {
  final progress = ProgressController(device);
  await progress.load();
  if (saveToPhotos != null) {
    await progress.updateSettings(
      (settings) => settings.withSketchSaveToPhotos(saveToPhotos),
    );
  }
  final store = SketchStore(device);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? GardenTheme.dark : GardenTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: padding,
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SketchPage(
                  controller: progress,
                  services: device,
                  store: store,
                ),
              ),
            ),
            child: const Text('Art Hub'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Art Hub'));
  await settleImages(tester);
  return (progress: progress, store: store);
}

SketchCanvas canvas(WidgetTester tester) =>
    tester.widget<SketchCanvas>(keyed('sketch-canvas'));

Future<void> draw(WidgetTester tester) async {
  final center = tester.getCenter(keyed('sketch-canvas'));
  final gesture = await tester.startGesture(center - const Offset(20, 0));
  await gesture.moveBy(const Offset(40, 0));
  await gesture.up();
  await settleImages(tester);
}

Future<List<int>> pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return data.buffer
      .asUint8List(data.offsetInBytes + (y * image.width + x) * 4, 4)
      .toList();
}

class PendingGalleryDevice extends GalleryCaptureDevice {
  final saving = Completer<void>();
  final finish = Completer<void>();

  @override
  Future<String> saveToGallery(
    Uint8List png,
    String displayName, {
    String? replaceUri,
  }) async {
    saving.complete();
    await finish.future;
    return super.saveToGallery(png, displayName, replaceUri: replaceUri);
  }
}

Rect screenPage(WidgetTester tester) {
  final drawing = canvas(tester);
  final bounds = tester.getRect(keyed('sketch-canvas'));
  final page = drawing.controller.pageSize;
  final displayed = drawing.quarterTurns.isOdd
      ? Size(page.height, page.width)
      : page;
  return SketchCanvas.pageRect(bounds.size, displayed).shift(bounds.topLeft);
}

Rect naturalRect(Rect rect, Size naturalSize, int rotation) =>
    switch (rotation) {
      1 => Rect.fromLTWH(
        naturalSize.width - rect.bottom,
        rect.left,
        rect.height,
        rect.width,
      ),
      2 => Rect.fromLTWH(
        naturalSize.width - rect.right,
        naturalSize.height - rect.bottom,
        rect.width,
        rect.height,
      ),
      3 => Rect.fromLTWH(
        rect.top,
        naturalSize.height - rect.right,
        rect.height,
        rect.width,
      ),
      _ => rect,
    };

void expectRectNear(Rect actual, Rect expected) {
  for (final pair in [
    (actual.left, expected.left),
    (actual.top, expected.top),
    (actual.right, expected.right),
    (actual.bottom, expected.bottom),
  ]) {
    expect(pair.$1, closeTo(pair.$2, 1));
  }
}

Future<void> seedLegacy(
  WidgetTester tester,
  MemoryDevice device, {
  bool white = false,
}) async {
  final progress = ProgressController(device);
  await progress.load();
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final drawing = ui.Canvas(recorder)
      ..drawPaint(ui.Paint()..color = Colors.white);
    if (!white) {
      drawing.drawRect(
        const Rect.fromLTWH(180, 180, 80, 80),
        ui.Paint()..color = Colors.black,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1080, 1920);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    device.sketches[progress.activeProfile!.id] = SketchSnapshot(
      png: Uint8List.fromList(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
    image.dispose();
    picture.dispose();
  });
  progress.dispose();
}

void main() {
  group('sketchCutoutInsets', () {
    const size = Size(400, 800);

    test('no display features need no clearance', () {
      expect(sketchCutoutInsets(size, []), EdgeInsets.zero);
    });

    for (final (bounds, expected) in [
      (const Rect.fromLTWH(180, 6, 33, 40), const EdgeInsets.only(top: 46)),
      (const Rect.fromLTWH(6, 380, 40, 33), const EdgeInsets.only(left: 46)),
      (const Rect.fromLTWH(354, 380, 40, 33), const EdgeInsets.only(right: 46)),
      (
        const Rect.fromLTWH(180, 754, 33, 40),
        const EdgeInsets.only(bottom: 46),
      ),
    ]) {
      test('inset punch hole uses its far side: $expected', () {
        expect(sketchCutoutInsets(size, [cutout(bounds)]), expected);
      });
    }

    test('uses the deepest cutout per edge and ignores other features', () {
      expect(
        sketchCutoutInsets(size, [
          cutout(const Rect.fromLTWH(180, 0, 33, 28)),
          cutout(const Rect.fromLTWH(100, 5, 33, 40)),
          cutout(const Rect.fromLTWH(0, 380, 12, 33)),
          for (final type in [
            ui.DisplayFeatureType.hinge,
            ui.DisplayFeatureType.fold,
            ui.DisplayFeatureType.unknown,
          ])
            ui.DisplayFeature(
              bounds: const Rect.fromLTWH(0, 300, 400, 20),
              type: type,
              state: ui.DisplayFeatureState.unknown,
            ),
        ]),
        const EdgeInsets.only(left: 12, top: 45),
      );
    });

    test('a corner cutout clears both touched edges', () {
      expect(
        sketchCutoutInsets(size, [cutout(const Rect.fromLTWH(0, 0, 20, 30))]),
        const EdgeInsets.only(left: 20, top: 30),
      );
    });

    test('empty and off-screen cutouts do not reserve space', () {
      expect(
        sketchCutoutInsets(size, [
          cutout(Rect.zero),
          cutout(const Rect.fromLTWH(500, 0, 20, 30)),
        ]),
        EdgeInsets.zero,
      );
    });
  });

  setUpAll(() async {
    // Match Android text metrics, as in the existing layout test suites.
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final weight
          in family == 'MaterialIcons'
              ? ['Regular']
              : ['Regular', 'Medium', 'Bold', 'Black']) {
        final name = family == 'MaterialIcons' ? family : 'Roboto';
        final extension = family == 'MaterialIcons' ? 'otf' : 'ttf';
        loader.addFont(
          File(
            '$fonts/$name-$weight.$extension',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });

  for (final size in [
    const Size(393, 852),
    const Size(1280, 800),
    const Size(320, 640),
    const Size(852, 393),
  ]) {
    testWidgets('fresh paper fills the drawable area at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, MemoryDevice());
      final portrait = size.height >= size.width;
      final expected = portrait
          ? Rect.fromLTWH(8, 80, size.width - 16, size.height - 160)
          : Rect.fromLTWH(80, 8, size.width - 160, size.height - 16);
      final page = screenPage(tester);
      expectRectNear(page, expected);
      // The specified 72px strips + gaps preclude 85% of the whole screen.
      // Require virtually all the remaining drawable area instead.
      expect(
        page.width * page.height / (expected.width * expected.height),
        greaterThan(.998),
      );
      expect(tester.getSize(keyed('sketch-save')), const Size(56, 56));
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    });
  }

  for (final naturalSize in [const Size(393, 852), const Size(1280, 800)]) {
    testWidgets('natural viewport and physical page stay fixed: $naturalSize', (
      tester,
    ) async {
      final device = MemoryDevice();
      await tester.binding.setSurfaceSize(naturalSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, device);
      final original = screenPage(tester);
      final viewport = canvas(tester).controller.viewport;
      final pageSize = canvas(tester).controller.pageSize;
      // Ink fixes the page size, exercising fitting as well as the fresh case.
      await draw(tester);
      for (final rotation in [0, 1, 2, 3]) {
        final size = rotation.isEven
            ? naturalSize
            : Size(naturalSize.height, naturalSize.width);
        device.rotate(rotation);
        await tester.binding.setSurfaceSize(size);
        await settleImages(tester);
        expect(canvas(tester).quarterTurns, (4 - rotation) % 4);
        expect(canvas(tester).controller.viewport, viewport);
        expect(canvas(tester).controller.pageSize, pageSize);
        final page = screenPage(tester);
        expectRectNear(naturalRect(page, naturalSize, rotation), original);
        final back = tester.getRect(keyed('sketch-back'));
        final undo = tester.getRect(keyed('sketch-undo'));
        if (size.height >= size.width) {
          expect(back.bottom, lessThan(page.top));
          expect(undo.top, greaterThan(page.bottom));
          expect(
            back.left,
            lessThan(tester.getRect(keyed('sketch-tool')).left),
          );
        } else {
          expect(back.right, lessThan(page.left));
          expect(undo.left, greaterThan(page.right));
          expect(back.top, lessThan(tester.getRect(keyed('sketch-tool')).top));
        }
      }
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    });
  }

  for (final tool in [SketchTool.eraser, SketchTool.fill]) {
    testWidgets('saved $tool starts on Brush, preserving ink and size', (
      tester,
    ) async {
      final device = MemoryDevice();
      final progress = ProgressController(device);
      await progress.load();
      device.sketches[progress.activeProfile!.id] = SketchSnapshot(
        settings: SketchSettings(
          tool: tool,
          color: 0xFF123456,
          size: 24,
          special: SketchSpecial.rainbow,
          recentColors: const [0xFF123456],
        ).encode(),
      );
      await mount(tester, device);
      expect(canvas(tester).tool, SketchTool.brush);
      expect(canvas(tester).special, SketchSpecial.rainbow);
      expect(canvas(tester).width, 24);
      expect(canvas(tester).color, 0xFF123456);
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    });
  }

  for (final special in [null, SketchSpecial.glitter]) {
    testWidgets('color tab is visit-local with initial special $special', (
      tester,
    ) async {
      final device = MemoryDevice();
      final seed = ProgressController(device);
      await seed.load();
      device.sketches[seed.activeProfile!.id] = SketchSnapshot(
        settings: SketchSettings(special: special).encode(),
      );
      seed.dispose();
      final fixture = await mount(tester, device);
      Future<void> open() async {
        await tester.tap(keyed('sketch-color'));
        await tester.pumpAndSettle();
      }

      void expectInitial() {
        expect(
          keyed(special == null ? 'sketch-preset-0' : 'sketch-special-glitter'),
          findsOneWidget,
        );
        expect(keyed('sketch-color-wheel'), findsNothing);
      }

      await open();
      expectInitial();
      await tester.tap(keyed('sketch-color-tab-mix'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await open();
      expect(keyed('sketch-color-wheel'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(keyed('sketch-back'));
      await settleImages(tester);
      await tester.pumpWidget(const SizedBox());
      final reopened = await mount(tester, device);
      await open();
      expectInitial();
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
      fixture.progress.dispose();
      reopened.progress.dispose();
    });
  }

  for (final special in [SketchSpecial.glitter, SketchSpecial.neon]) {
    for (final source in ['crayon', 'recent', 'mix', 'plain', 'again']) {
      testWidgets(
        '${special.name} with $source pick leaves eraser and updates ink',
        (tester) async {
          final device = MemoryDevice();
          final seed = ProgressController(device);
          await seed.load();
          device.sketches[seed.activeProfile!.id] = SketchSnapshot(
            settings: SketchSettings(
              special: special,
              color: 0xFFFF0000,
              recentColors: const [0xFF123456],
            ).encode(),
          );
          seed.dispose();
          final fixture = await mount(tester, device, reducedMotion: true);
          await tester.tap(keyed('sketch-tool'));
          await tester.pumpAndSettle();
          await tester.tap(keyed('sketch-tool-eraser'));
          await tester.pumpAndSettle();
          await tester.tap(keyed('sketch-color'));
          await tester.pumpAndSettle();
          var expectedColor = 0xFFFF0000;
          final expectedSpecial = ['plain', 'again'].contains(source)
              ? null
              : special;
          if (source == 'mix') {
            await tester.tap(keyed('sketch-color-tab-mix'));
            await tester.pumpAndSettle();
            final wheel = keyed('sketch-color-wheel');
            final rect = tester.getRect(wheel);
            final gesture = await tester.startGesture(rect.center);
            await gesture.moveTo(rect.bottomCenter - const Offset(0, 1));
            await gesture.up();
            await tester.pump();
            expectedColor = canvas(tester).color;
            expect(expectedColor, isNot(0xFFFF0000));
            expect(canvas(tester).special, special);
            final liveDot = tester.widget<SpecialSwatch>(
              find.descendant(
                of: keyed('sketch-color'),
                matching: find.byType(SpecialSwatch),
              ),
            );
            expect(liveDot.base, Color(expectedColor));
            expect(liveDot.special, special);
            await tester.binding.handlePopRoute();
          } else if (source == 'crayon') {
            await tester.tap(keyed('sketch-color-tab-crayons'));
            await tester.pumpAndSettle();
            expectedColor = sketchPresetColors[3].color;
            await tester.tap(keyed('sketch-preset-3'));
          } else if (source == 'recent') {
            expectedColor = 0xFF123456;
            await tester.tap(keyed('sketch-recent-0'));
          } else {
            await tester.tap(
              keyed(
                source == 'plain'
                    ? 'sketch-special-plain'
                    : 'sketch-special-${special.name}',
              ),
            );
          }
          await settleImages(tester);
          expect(canvas(tester).tool, SketchTool.brush);
          expect(canvas(tester).color, expectedColor);
          expect(canvas(tester).special, expectedSpecial);
          if (expectedSpecial != null) {
            final dot = tester.widget<SpecialSwatch>(
              find.descendant(
                of: keyed('sketch-color'),
                matching: find.byType(SpecialSwatch),
              ),
            );
            expect(dot.base, Color(expectedColor));
            expect(dot.special, special);
            await tester.tap(keyed('sketch-size'));
            await tester.pumpAndSettle();
            final preview = tester.widget<SpecialSwatch>(
              find.descendant(
                of: keyed('sketch-size-preview'),
                matching: find.byType(SpecialSwatch),
              ),
            );
            expect(preview.base, Color(expectedColor));
            expect(preview.special, special);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          await draw(tester);
          final stroke =
              (canvas(tester).controller.ops.last as StrokeOp).stroke;
          expect(stroke.special, expectedSpecial);
          expect(stroke.color, expectedColor);
          await flushStore(tester, fixture.store);
          final saved = SketchSettings.decode(
            device.sketches[fixture.progress.activeProfile!.id]!.settings!,
          );
          expect(saved.special, expectedSpecial);
          expect(
            saved.recentColors,
            source == 'plain' || source == 'again'
                ? [0xFF123456]
                : source == 'recent'
                ? [expectedColor]
                : [expectedColor, 0xFF123456],
          );
          await tester.pumpWidget(const SizedBox());
          await settleImages(tester);
          fixture.progress.dispose();
        },
      );
    }
  }

  for (final special in [SketchSpecial.glitter, SketchSpecial.neon]) {
    testWidgets(
      '${special.label} uses base color, preserves recents and leaves eraser',
      (tester) async {
        const base = 0xFF2040C0;
        final device = MemoryDevice();
        final seed = ProgressController(device);
        await seed.load();
        device.sketches[seed.activeProfile!.id] = SketchSnapshot(
          settings: const SketchSettings(
            color: base,
            recentColors: [0xFF123456],
          ).encode(),
        );
        seed.dispose();
        final fixture = await mount(tester, device, reducedMotion: true);
        final id = fixture.progress.activeProfile!.id;
        await tester.tap(keyed('sketch-tool'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-tool-eraser'));
        await tester.pumpAndSettle();
        expect(canvas(tester).tool, SketchTool.eraser);
        await tester.tap(keyed('sketch-color'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-color-tab-special'));
        await tester.pumpAndSettle();
        final tile = keyed('sketch-special-${special.name}');
        expect(
          tester
              .widget<SpecialSwatch>(
                find.descendant(of: tile, matching: find.byType(SpecialSwatch)),
              )
              .base,
          const Color(base),
        );
        await tester.tap(tile);
        await settleImages(tester);
        expect(canvas(tester).tool, SketchTool.brush);
        expect(canvas(tester).special, special);
        expect(canvas(tester).color, base);
        final dot = tester.widget<SpecialSwatch>(
          find.descendant(
            of: keyed('sketch-color'),
            matching: find.byType(SpecialSwatch),
          ),
        );
        expect(dot.special, special);
        expect(dot.shape, BoxShape.circle);
        expect(dot.base, const Color(base));
        await tester.tap(keyed('sketch-size'));
        await tester.pumpAndSettle();
        final preview = tester.widget<SpecialSwatch>(
          find.descendant(
            of: keyed('sketch-size-preview'),
            matching: find.byType(SpecialSwatch),
          ),
        );
        expect(preview.special, special);
        expect(preview.base, const Color(base));
        expect(preview.shape, BoxShape.circle);
        await tester.binding.handlePopRoute();
        await settleImages(tester);
        await flushStore(tester, fixture.store);
        expect(
          SketchSettings.decode(device.sketches[id]!.settings!).recentColors,
          [0xFF123456],
        );
        if (special == SketchSpecial.glitter) {
          await tester.tap(keyed('sketch-tool'));
          await tester.pumpAndSettle();
          await tester.tap(keyed('sketch-tool-fill'));
          await tester.pumpAndSettle();
          await tester.tap(keyed('sketch-canvas'));
          await waitForFills(tester, canvas(tester).controller);
          final fill = canvas(tester).controller.ops.last as FillOp;
          await tester.runAsync(() async {
            expect(await pixel(fill.image!, 10, 10), [32, 64, 192, 255]);
          });
        }
        await tester.tap(keyed('sketch-color'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-color-tab-crayons'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-preset-3'));
        await settleImages(tester);
        expect(canvas(tester).special, special);
        expect(canvas(tester).color, sketchPresetColors[3].color);
        final changedDot = tester.widget<SpecialSwatch>(
          find.descendant(
            of: keyed('sketch-color'),
            matching: find.byType(SpecialSwatch),
          ),
        );
        expect(changedDot.special, special);
        expect(changedDot.base, Color(sketchPresetColors[3].color));
        await tester.pumpWidget(const SizedBox());
        await settleImages(tester);
        fixture.progress.dispose();
      },
    );
  }

  testWidgets('mixed ink previews live and commits one recent on dismissal', (
    tester,
  ) async {
    final device = MemoryDevice();
    final fixture = await mount(tester, device);
    await tester.tap(keyed('sketch-tool'));
    await tester.pumpAndSettle();
    await tester.tap(keyed('sketch-tool-eraser'));
    await tester.pumpAndSettle();
    await tester.tap(keyed('sketch-color'));
    await tester.pumpAndSettle();
    await tester.tap(keyed('sketch-color-tab-mix'));
    await tester.pumpAndSettle();
    final wheel = keyed('sketch-color-wheel');
    await tester.ensureVisible(wheel);
    await tester.pumpAndSettle();
    final rect = tester.getRect(wheel);
    final gesture = await tester.startGesture(
      rect.centerRight - const Offset(1, 0),
    );
    await gesture.moveTo(rect.bottomCenter - const Offset(0, 1));
    await gesture.up();
    await tester.pump();
    final mixed = canvas(tester).color;
    expect(mixed, isNot(sketchDefaultColor));
    expect(canvas(tester).tool, SketchTool.brush);
    expect(canvas(tester).special, isNull);
    await flushStore(tester, fixture.store);
    expect(
      SketchSettings.decode(
        device.sketches[fixture.progress.activeProfile!.id]!.settings!,
      ).recentColors,
      isEmpty,
    );
    await tester.binding.handlePopRoute();
    await settleImages(tester);
    await flushStore(tester, fixture.store);
    expect(
      SketchSettings.decode(
        device.sketches[fixture.progress.activeProfile!.id]!.settings!,
      ).recentColors,
      [mixed],
    );
    expect(canvas(tester).color, mixed);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets('blank and exported pages clear immediately; new ink asks', (
    tester,
  ) async {
    await mount(tester, MemoryDevice());
    await tester.tap(keyed('sketch-clear'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await draw(tester);
    await tester.tap(keyed('sketch-save'));
    await settleImages(tester);
    await tester.tap(keyed('sketch-clear'));
    await settleImages(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(canvas(tester).controller.isBlank, isTrue);
    await tester.tap(keyed('sketch-undo'));
    await settleImages(tester);
    expect(canvas(tester).controller.isBlank, isFalse);
    await draw(tester);
    await tester.tap(keyed('sketch-clear'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Clear the whole page?'), findsOneWidget);
    await tester.tap(find.byTooltip('Keep drawing'));
    await tester.pumpAndSettle();
    expect(canvas(tester).controller.isBlank, isFalse);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets('caption bar cannot resize the physical page on rotation', (
    tester,
  ) async {
    const naturalSize = Size(800, 1280);
    const pixelRatio = 1.5;
    final device = MemoryDevice();
    tester.view
      ..devicePixelRatio = pixelRatio
      ..physicalSize = naturalSize * pixelRatio
      ..padding = const FakeViewPadding(top: 59)
      ..viewPadding = const FakeViewPadding(top: 59)
      ..displayFeatures = [];
    addTearDown(tester.view.reset);
    await mount(tester, device);
    final original = screenPage(tester);
    expectRectNear(original, const Rect.fromLTWH(8, 80, 784, 1120));
    final physicalOriginal = Rect.fromPoints(
      original.topLeft * pixelRatio,
      original.bottomRight * pixelRatio,
    );
    final viewport = canvas(tester).controller.viewport;
    await draw(tester);
    final pageSize = canvas(tester).controller.pageSize;

    for (final rotation in [0, 1]) {
      final size = rotation == 0
          ? naturalSize
          : Size(naturalSize.height, naturalSize.width);
      device.rotate(rotation);
      tester.view.physicalSize = size * pixelRatio;
      await settleImages(tester);
      final context = tester.element(keyed('sketch-canvas'));
      expect(MediaQuery.paddingOf(context).top, closeTo(59 / pixelRatio, .001));
      expect(
        MediaQuery.viewPaddingOf(context).top,
        closeTo(59 / pixelRatio, .001),
      );
      expect(MediaQuery.displayFeaturesOf(context), isEmpty);
      expect(canvas(tester).quarterTurns, (4 - rotation) % 4);
      expect(canvas(tester).controller.viewport, viewport);
      expect(canvas(tester).controller.pageSize, pageSize);
      final page = naturalRect(screenPage(tester), naturalSize, rotation);
      expectRectNear(
        Rect.fromPoints(
          page.topLeft * pixelRatio,
          page.bottomRight * pixelRatio,
        ),
        physicalOriginal,
      );
      final a = tester.getSize(keyed('sketch-strip-a'));
      final b = tester.getSize(keyed('sketch-strip-b'));
      expect(a, b);
      expect(rotation == 0 ? a.height : a.width, 72);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets(
    'hardware cutout keeps page fixed and buttons clear on rotation',
    (tester) async {
      const naturalSize = Size(393, 852);
      const cutouts = [
        Rect.fromLTRB(180, 0, 213, 40),
        Rect.fromLTRB(0, 180, 40, 213),
        Rect.fromLTRB(180, 812, 213, 852),
        Rect.fromLTRB(812, 180, 852, 213),
      ];
      final device = MemoryDevice();
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = naturalSize
        ..displayFeatures = [cutout(cutouts.first)];
      addTearDown(tester.view.reset);
      await mount(tester, device);
      final original = screenPage(tester);
      expectRectNear(original, const Rect.fromLTWH(8, 120, 377, 612));
      final viewport = canvas(tester).controller.viewport;
      await draw(tester);
      final pageSize = canvas(tester).controller.pageSize;

      for (final rotation in [0, 1, 2, 3]) {
        final size = rotation.isEven
            ? naturalSize
            : Size(naturalSize.height, naturalSize.width);
        device.rotate(rotation);
        tester.view
          ..physicalSize = size
          ..displayFeatures = [cutout(cutouts[rotation])];
        await settleImages(tester);
        expect(canvas(tester).quarterTurns, (4 - rotation) % 4);
        expect(canvas(tester).controller.viewport, viewport);
        expect(canvas(tester).controller.pageSize, pageSize);
        expectRectNear(
          naturalRect(screenPage(tester), naturalSize, rotation),
          original,
        );
        final a = tester.getSize(keyed('sketch-strip-a'));
        final b = tester.getSize(keyed('sketch-strip-b'));
        expect(a, b);
        expect(rotation.isEven ? a.height : a.width, 112);
        for (final key in [
          'sketch-back',
          'sketch-tool',
          'sketch-color',
          'sketch-size',
          'sketch-undo',
          'sketch-redo',
          'sketch-clear',
          'sketch-save',
        ]) {
          final button = tester.getRect(keyed(key));
          expect(button.overlaps(cutouts[rotation]), isFalse, reason: key);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    },
  );

  for (final size in [const Size(393, 852), const Size(852, 393)]) {
    testWidgets('equal cutout-safe strips ignore text scale at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final portrait = size.height >= size.width;
      final padding = portrait
          ? const EdgeInsets.fromLTRB(3, 28, 5, 12)
          : const EdgeInsets.fromLTRB(28, 3, 12, 5);
      tester.view.displayFeatures = portrait
          ? [
              cutout(const Rect.fromLTWH(180, 0, 33, 28)),
              cutout(const Rect.fromLTWH(0, 200, 5, 20)),
            ]
          : [
              cutout(const Rect.fromLTWH(0, 180, 28, 33)),
              cutout(const Rect.fromLTWH(200, 0, 20, 5)),
            ];
      addTearDown(tester.view.resetDisplayFeatures);
      Rect? before;
      for (final scale in [1.0, 2.0]) {
        await mount(tester, MemoryDevice(), scale: scale, padding: padding);
        final a = tester.getSize(keyed('sketch-strip-a'));
        final b = tester.getSize(keyed('sketch-strip-b'));
        expect(a, b);
        expect(portrait ? a.height : a.width, 100);
        final page = screenPage(tester);
        if (before != null) expectRectNear(page, before);
        before = page;
        expect(portrait ? page.left : page.top, closeTo(13, 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settleImages(tester);
      }
    });
  }

  testWidgets('immersive on open, edge-to-edge on Back and window restored', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final device = MemoryDevice();
    await mount(tester, device);
    expect(
      calls.any(
        (c) =>
            c.method == 'SystemChrome.setEnabledSystemUIMode' &&
            c.arguments == 'SystemUiMode.immersiveSticky',
      ),
      isTrue,
    );
    await tester.tap(keyed('sketch-back'));
    await tester.pump();
    // Restore during the pop transition, before SketchPage is disposed.
    expect(keyed('sketch-back'), findsOneWidget);
    expect(device.sketchWindowCalls, [true, false]);
    expect(
      calls.any(
        (c) =>
            c.method == 'SystemChrome.setEnabledSystemUIMode' &&
            c.arguments == 'SystemUiMode.edgeToEdge',
      ),
      isTrue,
    );
    await settleImages(tester);
    expect(
      calls.any(
        (c) =>
            c.method == 'SystemChrome.setEnabledSystemUIMode' &&
            c.arguments == 'SystemUiMode.edgeToEdge',
      ),
      isTrue,
    );
    expect(device.sketchWindowCalls, [true, false, false]);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'Save status is accessible with fixed size: reduced=$reducedMotion',
      (tester) async {
        final device = PendingGalleryDevice();
        final semantics = tester.ensureSemantics();
        await mount(tester, device, reducedMotion: reducedMotion);
        final size = tester.getSize(keyed('sketch-save'));
        void status(String text) {
          expect(find.byTooltip(text), findsOneWidget);
          expect(find.bySemanticsLabel(text), findsOneWidget);
          expect(
            tester
                .getSemantics(find.bySemanticsLabel(text))
                .flagsCollection
                .isLiveRegion,
            isTrue,
          );
          expect(tester.getSize(keyed('sketch-save')), size);
        }

        status('Save to photos');
        await tester.tap(keyed('sketch-save'));
        for (var i = 0; !device.saving.isCompleted && i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        expect(device.saving.isCompleted, isTrue);

        status('Saving…');
        expect(
          find.byIcon(Icons.hourglass_top_rounded),
          reducedMotion ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(CircularProgressIndicator),
          reducedMotion ? findsNothing : findsOneWidget,
        );
        device.finish.complete();
        await settleImages(tester);
        status('Saved to photos');
        await tester.tap(keyed('sketch-save'));
        await tester.pump();
        status('Already saved to photos');
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
        await settleImages(tester);
      },
    );
  }

  for (final white in [false, true]) {
    testWidgets('legacy PNG loads with contents preserved: white=$white', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final device = MemoryDevice();
      await seedLegacy(tester, device, white: white);
      final fixture = await mount(tester, device);
      final c = canvas(tester).controller;
      if (white) {
        expect(c.isFresh, isTrue);
        expect(c.pageSize, sketchPageSizeFor(c.viewport));
        expect(c.pageSize.width, greaterThan(c.pageSize.height));
      } else {
        expect(c.pageSize, const Size(1080, 1920));
        expect(screenPage(tester).size.aspectRatio, closeTo(1080 / 1920, .001));
        await tester.runAsync(() async {
          final image = await c.flatten();
          expect(await pixel(image, 200, 200), [0, 0, 0, 255]);
          image.dispose();
        });
        await tester.tap(keyed('sketch-clear'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Clear page'));
        await settleImages(tester);
        expect(c.pageSize.width, greaterThan(c.pageSize.height));
        await tester.tap(keyed('sketch-undo'));
        await settleImages(tester);
        expect(c.pageSize, const Size(1080, 1920));
        await tester.runAsync(() async {
          final image = await c.flatten();
          expect(await pixel(image, 200, 200), [0, 0, 0, 255]);
          image.dispose();
        });
      }
      await flushStore(tester, fixture.store);
      expect(device.sketchWrites, white ? 0 : greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    });
  }

  testWidgets(
    'rotation 1 gallery export swaps page dimensions; autosave does not',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(852, 393));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final device = GalleryCaptureDevice()..rotate(1);
      final fixture = await mount(tester, device);
      await draw(tester);
      final page = canvas(tester).controller.pageSize;
      await tester.tap(keyed('sketch-save'));
      await settleImages(tester);
      await flushStore(tester, fixture.store);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(device.exported!);
        final image = (await codec.getNextFrame()).image;
        expect(
          Size(image.width.toDouble(), image.height.toDouble()),
          Size(page.height, page.width),
        );
        image.dispose();
        codec.dispose();
        final saved = device.sketches[fixture.progress.activeProfile!.id]!.png!;
        final savedCodec = await ui.instantiateImageCodec(saved);
        final natural = (await savedCodec.getNextFrame()).image;
        expect(Size(natural.width.toDouble(), natural.height.toDouble()), page);
        natural.dispose();
        savedCodec.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'Rainbow persists, previews, restores, and clears for a crayon: dark=$dark',
      (tester) async {
        final d = MemoryDevice();
        final fixture = await mount(tester, d, dark: dark);
        final id = fixture.progress.activeProfile!.id;
        await tester.tap(keyed('sketch-tool'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-tool-eraser'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-color'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-color-tab-special'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-special-rainbow'));
        await settleImages(tester);
        expect(canvas(tester).tool, SketchTool.brush);
        expect(canvas(tester).special, SketchSpecial.rainbow);
        BoxDecoration decoration(Finder finder) =>
            tester.widget<Container>(finder).decoration! as BoxDecoration;
        Finder swatch() => find.descendant(
          of: keyed('sketch-color'),
          matching: find.byType(Container),
        );
        expect(
          tester
              .widget<SpecialSwatch>(
                find.descendant(
                  of: keyed('sketch-color'),
                  matching: find.byType(SpecialSwatch),
                ),
              )
              .special,
          SketchSpecial.rainbow,
        );
        expect(decoration(swatch()).color, isNull);
        await tester.tap(keyed('sketch-size'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SpecialSwatch>(
                find.descendant(
                  of: keyed('sketch-size-preview'),
                  matching: find.byType(SpecialSwatch),
                ),
              )
              .special,
          SketchSpecial.rainbow,
        );
        await tester.binding.handlePopRoute();
        await settleImages(tester);
        await flushStore(tester, fixture.store);
        final saved = SketchSettings.decode(d.sketches[id]!.settings!);
        expect(saved.special, SketchSpecial.rainbow);
        expect(saved.recentColors, isEmpty);
        await tester.tap(keyed('sketch-tool'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-tool-fill'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-canvas'));
        await waitForFills(tester, canvas(tester).controller);
        final fill = canvas(tester).controller.ops.last as FillOp;
        await tester.runAsync(() async {
          final mask = fill.image!;
          expect(await pixel(mask, mask.width ~/ 2, 10), [229, 57, 53, 255]);
          expect(await pixel(mask, mask.width ~/ 2, mask.height - 10), [
            142,
            54,
            201,
            255,
          ]);
        });
        await tester.tap(keyed('sketch-tool'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-tool-brush'));
        await tester.pumpAndSettle();
        await draw(tester);
        expect(
          (canvas(tester).controller.ops.last as StrokeOp).stroke.special,
          SketchSpecial.rainbow,
        );
        await tester.tap(keyed('sketch-back'));
        await settleImages(tester);
        await tester.pumpWidget(const SizedBox());
        final reopened = await mount(tester, d, dark: dark);
        expect(canvas(tester).special, SketchSpecial.rainbow);
        expect(
          tester
              .widget<SpecialSwatch>(
                find.descendant(
                  of: keyed('sketch-color'),
                  matching: find.byType(SpecialSwatch),
                ),
              )
              .special,
          SketchSpecial.rainbow,
        );
        // The restored ink stays selected while the eraser preview stays white.
        await tester.tap(keyed('sketch-tool'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-tool-eraser'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-size'));
        await tester.pumpAndSettle();
        expect(decoration(keyed('sketch-size-preview')).gradient, isNull);
        expect(
          decoration(keyed('sketch-size-preview')).color,
          const Color(sketchPaperColor),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-color'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-color-tab-crayons'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-preset-3'));
        await settleImages(tester);
        expect(canvas(tester).special, isNull);
        expect(canvas(tester).tool, SketchTool.brush);
        expect(decoration(swatch()).gradient, isNull);
        expect(decoration(swatch()).color, const Color(0xFFE53935));
        await tester.tap(keyed('sketch-back'));
        await settleImages(tester);
        final solid = SketchSettings.decode(d.sketches[id]!.settings!);
        expect(solid.special, isNull);
        expect(solid.recentColors, [0xFFE53935]);
        await tester.pumpWidget(const SizedBox());
        await settleImages(tester);
        fixture.progress.dispose();
        reopened.progress.dispose();
      },
    );
  }

  testWidgets('toolbar, navigation, strokes, history and confirmed clear', (
    tester,
  ) async {
    final d = MemoryDevice()..gallerySupported = false;
    await mount(tester, d);
    expect(find.bySemanticsLabel('Sketch Pad'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    for (final tooltip in [
      'Choose a tool',
      'Choose a color',
      'Brush size',
      'Back to Art Hub',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget);
    }
    expect(keyed('sketch-save'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(keyed('sketch-undo')).onPressed,
      isNull,
    );
    await draw(tester);
    expect(canvas(tester).controller.canUndo, isTrue);
    await tester.tap(keyed('sketch-undo'));
    await tester.pump();
    expect(canvas(tester).controller.canRedo, isTrue);
    await tester.tap(keyed('sketch-redo'));
    await tester.pump();
    await tester.tap(keyed('sketch-clear'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Clear the whole page?'), findsOneWidget);
    expect(canvas(tester).controller.isBlank, isFalse);
    await tester.tap(find.byTooltip('Clear page'));
    await settleImages(tester);
    expect(canvas(tester).controller.isBlank, isTrue);
    await tester.tap(keyed('sketch-undo'));
    await settleImages(tester);
    expect(canvas(tester).controller.isBlank, isFalse);
    await tester.tap(find.byTooltip('Back to Art Hub'));
    await settleImages(tester);
    expect(find.text('Art Hub'), findsOneWidget);
  });

  testWidgets(
    'tool semantics, color changes eraser to brush and saves recent colors',
    (tester) async {
      final d = MemoryDevice();
      final fixture = await mount(tester, d);
      await draw(tester);
      final semantics = tester.ensureSemantics();
      void expectToolSemantics(String tool) {
        final node = tester.getSemantics(keyed('sketch-tool'));
        expect(node.label, contains('Choose a tool'));
        expect(node.value, tool);
        expect(find.byTooltip('Choose a tool'), findsOneWidget);
      }

      expectToolSemantics('Brush');
      await tester.tap(keyed('sketch-tool'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(keyed('sketch-tool-brush'))
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      await tester.tap(keyed('sketch-tool-eraser'));
      await tester.pumpAndSettle();
      expect(canvas(tester).tool, SketchTool.eraser);
      expectToolSemantics('Eraser');
      await tester.tap(keyed('sketch-tool'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(keyed('sketch-tool-eraser'))
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      await tester.tap(keyed('sketch-tool-fill'));
      await tester.pumpAndSettle();
      expect(canvas(tester).tool, SketchTool.fill);
      expectToolSemantics('Fill');
      await tester.tap(keyed('sketch-tool'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('sketch-tool-eraser'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('sketch-color'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('sketch-preset-3'));
      await settleImages(tester);
      expect(canvas(tester).tool, SketchTool.brush);
      await flushStore(tester, fixture.store);
      final settings = SketchSettings.decode(
        d.sketches[fixture.progress.activeProfile!.id]!.settings!,
      );
      expect(settings.color, 0xFFE53935);
      expect(settings.recentColors.first, settings.color);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    },
  );

  testWidgets('fill respects a closed stroke and repeat fill is a no-op', (
    tester,
  ) async {
    final c = SketchCanvasController();
    c.beginStroke(const Offset(200, 200), color: 0xFF000000, width: 32);
    for (final point in [
      const Offset(800, 200),
      const Offset(800, 1000),
      const Offset(200, 1000),
      const Offset(200, 200),
    ]) {
      c.addPoint(point);
    }
    c.endStroke();
    await tester.runAsync(() async {
      expect(
        await c.fill(const Offset(500, 500), const SolidInk(0xFFE53935)),
        isTrue,
      );
      final image = await c.flatten();
      expect(await pixel(image, 500, 500), [229, 57, 53, 255]);
      expect(await pixel(image, 20, 20), [255, 255, 255, 255]);
      image.dispose();
      final operations = c.ops.toList();
      expect(
        await c.fill(const Offset(500, 500), const SolidInk(0xFFE53935)),
        isFalse,
      );
      expect(c.ops, operations);
      c.undo();
      final undone = await c.flatten();
      expect(await pixel(undone, 500, 500), [255, 255, 255, 255]);
      undone.dispose();
    });
    c.dispose();
  });

  testWidgets('back-to-back fills preserve both closed shapes in tap order', (
    tester,
  ) async {
    final c = SketchCanvasController();
    c.beginStroke(const Offset(100, 200), color: 0xFF000000, width: 24);
    for (final p in [
      const Offset(400, 200),
      const Offset(400, 700),
      const Offset(100, 700),
      const Offset(100, 200),
    ]) {
      c.addPoint(p);
    }
    c.endStroke();
    c.beginStroke(const Offset(950, 450), color: 0xFF000000, width: 24);
    for (var i = 1; i <= 64; i++) {
      final angle = i * math.pi / 32;
      c.addPoint(
        Offset(750 + 200 * math.cos(angle), 450 + 200 * math.sin(angle)),
      );
    }
    c.endStroke();
    await tester.runAsync(() async {
      final first = c.fill(const Offset(250, 450), const SolidInk(0xFFFF0000));
      final second = c.fill(const Offset(750, 450), const SolidInk(0xFF0000FF));
      expect(c.busy, isTrue);
      expect(c.ops.whereType<FillOp>(), hasLength(2));
      await c.idle;
      expect(await first, isTrue);
      expect(await second, isTrue);
      final image = await c.flatten();
      expect(await pixel(image, 250, 450), [255, 0, 0, 255]);
      expect(await pixel(image, 750, 450), [0, 0, 255, 255]);
      expect(await pixel(image, 20, 20), [255, 255, 255, 255]);
      image.dispose();
    });
    c.dispose();
  });

  testWidgets('an immediate stroke stays above a pending fill', (tester) async {
    final c = SketchCanvasController();
    await tester.runAsync(() async {
      final fill = c.fill(const Offset(100, 100), const SolidInk(0xFFFF0000));
      c.beginStroke(const Offset(200, 200), color: 0xFF000000, width: 50);
      c.addPoint(const Offset(600, 200));
      c.endStroke();
      expect(c.ops, [isA<FillOp>(), isA<StrokeOp>()]);
      await c.idle;
      expect(await fill, isTrue);
      final image = await c.flatten();
      expect(await pixel(image, 400, 200), [0, 0, 0, 255]);
      expect(await pixel(image, 20, 20), [255, 0, 0, 255]);
      image.dispose();
    });
    c.dispose();
  });

  testWidgets('pending fill can be undone and completed in the redo tail', (
    tester,
  ) async {
    final c = SketchCanvasController();
    await tester.runAsync(() async {
      final fill = c.fill(const Offset(100, 100), const SolidInk(0xFFFF0000));
      c.undo();
      expect(c.canRedo, isTrue);
      await c.idle;
      expect(await fill, isTrue);
      final undone = await c.flatten();
      expect(await pixel(undone, 100, 100), [255, 255, 255, 255]);
      undone.dispose();
      c.redo();
      final redone = await c.flatten();
      expect(await pixel(redone, 100, 100), [255, 0, 0, 255]);
      redone.dispose();
    });
    c.dispose();
  });

  testWidgets('discarding a pending fill keeps a subsequent clear and stroke', (
    tester,
  ) async {
    final c = SketchCanvasController();
    await tester.runAsync(() async {
      final fill = c.fill(const Offset(100, 100), const SolidInk(0xFFFF0000));
      final placeholder = c.ops.single as FillOp;
      c.undo();
      c.clear();
      c.beginStroke(const Offset(200, 200), color: 0xFF000000, width: 50);
      c.endStroke();
      await c.idle;
      expect(await fill, isFalse);
      expect(placeholder.discarded, isTrue);
      expect(placeholder.image, isNull);
      final image = await c.flatten();
      expect(await pixel(image, 100, 100), [255, 255, 255, 255]);
      expect(await pixel(image, 200, 200), [0, 0, 0, 255]);
      image.dispose();
    });
    c.dispose();
  });

  testWidgets('tool sheet opens while fill is pending', (tester) async {
    await mount(tester, MemoryDevice());
    final c = canvas(tester).controller;
    await tester.runAsync(() async {
      final filling = c.fill(
        const Offset(100, 100),
        const SolidInk(0xFFFF0000),
      );
      expect(c.busy, isTrue);
      await tester.pump();
      expect(canvas(tester).enabled, isTrue);
      await tester.tap(keyed('sketch-tool'));
      await tester.pump();
      expect(keyed('sketch-tool-brush'), findsOneWidget);
      await filling;
    });
    await tester.pumpAndSettle();
    await tester.tap(keyed('sketch-tool-eraser'));
    await settleImages(tester);
    expect(canvas(tester).tool, SketchTool.eraser);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets('canvas accepts a second fill tap before the first completes', (
    tester,
  ) async {
    final c = SketchCanvasController();
    final fills = <Future<bool>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SketchCanvas(
          controller: c,
          color: 0xFFFF0000,
          width: 32,
          tool: SketchTool.fill,
          enabled: true,
          onFill: (point) => fills.add(
            c.fill(point, SolidInk(fills.isEmpty ? 0xFFFF0000 : 0xFF0000FF)),
          ),
        ),
      ),
    );
    final center = tester.getCenter(keyed('sketch-canvas'));
    await tester.tapAt(center);
    expect(c.busy, isTrue);
    await tester.tapAt(center + const Offset(20, 20));
    expect(fills, hasLength(2));
    await waitForFills(tester, c);
    await tester.runAsync(() async {
      await c.idle;
      expect(await Future.wait(fills), [true, true]);
      final image = await c.flatten();
      expect(await pixel(image, image.width ~/ 2, image.height ~/ 2), [
        0,
        0,
        255,
        255,
      ]);
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('gallery waits for pending fills before exporting', (
    tester,
  ) async {
    final d = GalleryCaptureDevice();
    await mount(tester, d);
    await tester.runAsync(() async {
      final c = canvas(tester).controller;
      final fill = c.fill(const Offset(100, 100), const SolidInk(0xFFFF0000));
      await tester.tap(keyed('sketch-save'));
      await tester.pump();
      expect(find.byTooltip('Saving…'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(keyed('sketch-save')).onPressed,
        isNull,
      );
      await fill;
    });
    await settleImages(tester);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(d.exported!);
      final image = (await codec.getNextFrame()).image;
      expect(await pixel(image, 100, 100), [255, 0, 0, 255]);
      image.dispose();
      codec.dispose();
    });
    expect(find.byTooltip('Saved to photos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets('leaving during a pending fill persists its completed pixels', (
    tester,
  ) async {
    final d = MemoryDevice();
    final fixture = await mount(tester, d);
    await tester.runAsync(() async {
      final c = canvas(tester).controller;
      final fill = c.fill(const Offset(100, 100), const SolidInk(0xFFFF0000));
      await tester.pumpWidget(const SizedBox());
      await fill;
    });
    await settleImages(tester);
    await tester.runAsync(() async {
      final saved = d.sketches[fixture.progress.activeProfile!.id]!;
      final codec = await ui.instantiateImageCodec(saved.png!);
      final image = (await codec.getNextFrame()).image;
      expect(await pixel(image, 100, 100), [255, 0, 0, 255]);
      image.dispose();
      codec.dispose();
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('compaction waits for fills and preserves captured operations', (
    tester,
  ) async {
    final c = SketchCanvasController();
    await tester.runAsync(() async {
      c.beginStroke(const Offset(100, 100), color: 0xFF000000, width: 32);
      c.endStroke();
      final fill = c.fill(const Offset(500, 500), const SolidInk(0xFFFF0000));
      for (var i = 0; i < 35; i++) {
        c.beginStroke(
          Offset(300 + i * 10.0, 700),
          color: 0xFF0000FF,
          width: 32,
        );
        c.endStroke();
      }
      await fill;
      final second = c.fill(const Offset(500, 500), const SolidInk(0xFF00FF00));
      await second;
      while (c.pendingBaseOps.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final image = await c.flatten();
      expect(await pixel(image, 100, 100), [0, 0, 0, 255]);
      expect(await pixel(image, 500, 500), [0, 255, 0, 255]);
      expect(await pixel(image, 500, 700), [0, 0, 255, 255]);
      image.dispose();
      for (var i = 0; i < 30; i++) {
        c.undo();
      }
      expect(c.canUndo, isFalse);
    });
    c.dispose();
  });

  testWidgets(
    'glitter anchors persist with their PNG and seed the reopened canvas',
    (tester) async {
      final d = MemoryDevice();
      final first = await mount(tester, d, reducedMotion: true);
      await tester.tap(keyed('sketch-color'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('sketch-color-tab-special'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('sketch-special-glitter'));
      await settleImages(tester);
      await draw(tester);
      final c = canvas(tester).controller;
      final anchors = c.visibleTwinkles;
      expect(anchors, isNotEmpty);
      await settleImages(tester);
      await tester.tap(find.byTooltip('Back to Art Hub'));
      await settleImages(tester);
      final saved = d.sketches[first.progress.activeProfile!.id]!;
      expect(SketchSettings.decode(saved.settings!).twinkles, anchors);
      expect(saved.png, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, d, reducedMotion: true);
      expect(canvas(tester).controller.bakedTwinkles, anchors);
      expect(canvas(tester).controller.visibleTwinkles, anchors);
      expect(find.byKey(const ValueKey('sketch-twinkles')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    },
  );

  testWidgets('leaving flushes PNG and reopening restores image and settings', (
    tester,
  ) async {
    final d = MemoryDevice();
    final first = await mount(tester, d);
    await draw(tester);
    await tester.tap(keyed('sketch-tool'));
    await tester.pumpAndSettle();
    await tester.tap(keyed('sketch-tool-eraser'));
    await tester.pumpAndSettle();
    await tester.tap(keyed('sketch-size'));
    await tester.pumpAndSettle();
    await tester.drag(keyed('sketch-size-slider'), const Offset(100, 0));
    await tester.binding.handlePopRoute();
    await settleImages(tester);
    final size = canvas(tester).width;
    expect(size, greaterThan(sketchDefaultBrush));
    await tester.tap(find.byTooltip('Back to Art Hub'));
    await settleImages(tester);
    final saved = d.sketches[first.progress.activeProfile!.id]!;
    expect(saved.png, isNotEmpty);
    expect(saved.settings, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, d);
    expect(canvas(tester).color, SketchSettings.decode(saved.settings!).color);
    expect(canvas(tester).tool, SketchTool.brush);
    expect(canvas(tester).width, size);
    await tester.runAsync(() async {
      final image = await canvas(tester).controller.flatten();
      expect(await pixel(image, image.width ~/ 2, image.height ~/ 2), [
        0,
        0,
        0,
        255,
      ]);
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets(
    'read errors never save; corrupt PNG requires confirmed replacement',
    (tester) async {
      final d = GalleryCaptureDevice()..failSketchLoad = true;
      final fixture = await mount(tester, d);
      expect(find.text("We couldn't open your drawing."), findsOneWidget);
      expect(keyed('sketch-canvas'), findsNothing);
      expect(d.sketchWrites, 0);
      d.failSketchLoad = false;
      d.sketches[fixture.progress.activeProfile!.id] = SketchSnapshot(
        png: Uint8List.fromList([1, 2, 3]),
        settings: const SketchSettings(
          photoUri: 'content://media/external/images/media/99',
        ).encode(),
      );
      await tester.tap(find.text('Try again'));
      await settleImages(tester);
      expect(find.text("This drawing couldn't be opened."), findsOneWidget);
      expect(d.sketchWrites, 0);
      await tester.tap(find.text('Start a new page'));
      await tester.pumpAndSettle();
      expect(d.sketchWrites, 0);
      expect(find.bySemanticsLabel('Start a new page?'), findsOneWidget);
      for (final tooltip in ['Keep it', 'Start new']) {
        final size = tester.getSize(find.byTooltip(tooltip));
        expect(size.width, greaterThanOrEqualTo(56));
        expect(size.height, greaterThanOrEqualTo(56));
      }
      await tester.tap(find.byTooltip('Keep it'));
      await tester.pumpAndSettle();
      expect(keyed('sketch-canvas'), findsNothing);
      expect(d.sketchWrites, 0);
      await tester.tap(find.text('Start a new page'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Start new'));
      await settleImages(tester);
      await flushStore(tester, fixture.store);
      expect(d.sketchWrites, 1);
      expect(
        SketchSettings.decode(
          d.sketches[fixture.progress.activeProfile!.id]!.settings!,
        ).photoUri,
        isNull,
      );
      await tester.tap(keyed('sketch-save'));
      await settleImages(tester);
      expect(d.replaceUris, [null]);
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    },
  );

  testWidgets('failed autosave has stable canvas size and can retry', (
    tester,
  ) async {
    final d = MemoryDevice()..failSketchSave = true;
    final fixture = await mount(tester, d);
    final before = tester.getSize(keyed('sketch-canvas'));
    await draw(tester);
    await flushStore(tester, fixture.store);
    await tester.pump();
    expect(
      find.byTooltip("Couldn't save your drawing. Try again"),
      findsOneWidget,
    );
    expect(tester.getSize(keyed('sketch-canvas')), before);
    d.failSketchSave = false;
    await tester.runAsync(() async {
      await tester.tap(keyed('sketch-save'));
    });
    await settleImages(tester);
    expect(d.sketchWrites, 1);
    expect(
      find.byTooltip("Couldn't save your drawing. Try again"),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets('photo saves reuse the URI until Clear, even after Undo', (
    tester,
  ) async {
    final device = GalleryCaptureDevice();
    final fixture = await mount(tester, device);
    await draw(tester);
    await tester.tap(keyed('sketch-save'));
    await settleImages(tester);
    const uri = 'content://media/external/images/media/1';
    expect(device.replaceUris, [null]);
    await flushStore(tester, fixture.store);
    expect(
      SketchSettings.decode(
        device.sketches[fixture.progress.activeProfile!.id]!.settings!,
      ).photoUri,
      uri,
    );
    await draw(tester);
    await tester.tap(keyed('sketch-save'));
    await settleImages(tester);
    expect(device.replaceUris, [null, uri]);
    await tester.tap(keyed('sketch-clear'));
    await settleImages(tester);
    expect(find.byType(AlertDialog), findsNothing);
    await flushStore(tester, fixture.store);
    expect(
      SketchSettings.decode(
        device.sketches[fixture.progress.activeProfile!.id]!.settings!,
      ).photoUri,
      isNull,
    );
    await tester.tap(keyed('sketch-undo'));
    await settleImages(tester);
    expect(canvas(tester).controller.isBlank, isFalse);
    await tester.tap(keyed('sketch-save'));
    await settleImages(tester);
    expect(device.replaceUris, [null, uri, null]);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets('saved photo URI is reused after reopening the page', (
    tester,
  ) async {
    final device = GalleryCaptureDevice();
    final fixture = await mount(tester, device);
    await draw(tester);
    await tester.tap(keyed('sketch-save'));
    await settleImages(tester);
    await flushStore(tester, fixture.store);
    const uri = 'content://media/external/images/media/1';
    expect(
      SketchSettings.decode(
        device.sketches[fixture.progress.activeProfile!.id]!.settings!,
      ).photoUri,
      uri,
    );
    await tester.tap(find.byTooltip('Back to Art Hub'));
    await settleImages(tester);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
    await mount(tester, device);
    await draw(tester);
    await tester.tap(keyed('sketch-save'));
    await settleImages(tester);
    expect(device.replaceUris, [null, uri]);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  for (final enabled in [true, false]) {
    testWidgets('photo save visibility with parent setting $enabled', (
      tester,
    ) async {
      await mount(tester, MemoryDevice(), saveToPhotos: enabled ? null : false);
      expect(keyed('sketch-save'), enabled ? findsOneWidget : findsNothing);
      await draw(tester);
      await tester.tap(keyed('sketch-clear'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Clear the whole page?'), findsOneWidget);
      await tester.tap(find.byTooltip('Keep drawing'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
    });
  }

  testWidgets('failed autosave can retry with photo saving hidden', (
    tester,
  ) async {
    final device = MemoryDevice()..failSketchSave = true;
    final fixture = await mount(tester, device, saveToPhotos: false);
    expect(keyed('sketch-save'), findsNothing);
    await draw(tester);
    await flushStore(tester, fixture.store);
    await tester.pump();
    expect(
      find.byTooltip("Couldn't save your drawing. Try again"),
      findsOneWidget,
    );
    device.failSketchSave = false;
    await tester.tap(keyed('sketch-save'));
    await settleImages(tester);
    expect(device.sketchWrites, 1);
    expect(device.gallery, isEmpty);
    expect(keyed('sketch-save'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets('gallery export is named and duplicate taps do not export twice', (
    tester,
  ) async {
    final d = MemoryDevice();
    await mount(tester, d);
    await tester.runAsync(() async {
      await tester.tap(keyed('sketch-save'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await settleImages(tester);
    expect(
      d.gallery.single,
      matches(
        RegExp(
          r'^Learning Corner sketch \d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2}\.png$',
        ),
      ),
    );
    expect(find.byTooltip('Saved to photos'), findsOneWidget);
    await tester.tap(keyed('sketch-save'));
    await tester.pump();
    expect(d.gallery, hasLength(1));
    expect(find.byTooltip('Already saved to photos'), findsOneWidget);
    await draw(tester);
    expect(find.byTooltip('Already saved to photos'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  testWidgets(
    'leaving during a stroke cancels temporary ink and flushes safely',
    (tester) async {
      final d = MemoryDevice();
      final fixture = await mount(tester, d);
      await draw(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(keyed('sketch-canvas')) + const Offset(0, 50),
      );
      await gesture.moveBy(const Offset(25, 0));
      expect(canvas(tester).controller.live, isNotNull);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settleImages(tester);
      await gesture.up();
      expect(tester.takeException(), isNull);
      await flushStore(tester, fixture.store);
      expect(d.sketches[fixture.progress.activeProfile!.id]!.png, isNotEmpty);
    },
  );

  testWidgets(
    'history compacts older operations and keeps the last 30 undoable',
    (tester) async {
      final c = SketchCanvasController();
      await tester.runAsync(() async {
        for (var i = 0; i < 31; i++) {
          c.beginStroke(
            Offset(50 + i * 20.0, 100),
            color: 0xFF000000,
            width: 12,
          );
          c.endStroke();
        }
        // Compaction rasterizes in the background without locking input.
        expect(c.busy, isFalse);
        final revision = c.revision;
        c.clear();
        c.undo();
        c.redo();
        expect(c.revision, revision + 3);
        while (c.pendingBaseOps.isNotEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(c.pendingBaseOps, isEmpty);
        expect(c.base, isNotNull);
        for (var i = 0; i < 30; i++) {
          c.undo();
        }
        expect(c.canUndo, isFalse);
        final image = await c.flatten();
        expect(await pixel(image, 50, 100), [0, 0, 0, 255]);
        expect(await pixel(image, 650, 100), [255, 255, 255, 255]);
        image.dispose();
        c.redo();
        c.beginStroke(const Offset(500, 600), color: 0xFF000000, width: 12);
        c.endStroke();
        expect(c.canRedo, isFalse);
      });
      c.dispose();
    },
  );

  testWidgets('drawing continues while an autosave snapshot rasterizes', (
    tester,
  ) async {
    final c = SketchCanvasController();
    await tester.runAsync(() async {
      c.beginStroke(const Offset(100, 100), color: 0xFF000000, width: 12);
      c.endStroke();
      final pending = c.flatten();
      c.beginStroke(const Offset(300, 300), color: 0xFF000000, width: 12);
      c.endStroke();
      expect(c.ops.length, 2);
      final snapshot = await pending;
      // The snapshot was recorded before the second stroke began.
      expect(await pixel(snapshot, 300, 300), [255, 255, 255, 255]);
      snapshot.dispose();
      final latest = await c.flatten();
      expect(await pixel(latest, 300, 300), [0, 0, 0, 255]);
      latest.dispose();
    });
    c.dispose();
  });

  testWidgets(
    'single pointer, margins, cancellation, edge clamping and eraser',
    (tester) async {
      final c = SketchCanvasController();
      var tool = SketchTool.brush;
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 500,
              height: 500,
              child: SketchCanvas(
                controller: c,
                color: 0xFF000000,
                width: 32,
                tool: tool,
                enabled: true,
              ),
            ),
          ),
        ),
      );
      await show();
      final bounds = tester.getRect(keyed('sketch-canvas'));
      final rect = SketchCanvas.pageRect(
        bounds.size,
        c.pageSize,
      ).shift(bounds.topLeft);
      await tester.tapAt(bounds.topLeft - const Offset(5, 5));
      expect(c.canUndo, isFalse);
      final first = await tester.startGesture(rect.center, pointer: 1);
      final second = await tester.startGesture(
        rect.center + const Offset(40, 40),
        pointer: 2,
      );
      await second.moveBy(const Offset(10, 10));
      await second.up();
      expect(c.live!.points, hasLength(1));
      await first.cancel();
      expect(c.canUndo, isFalse);
      expect(c.live, isNull);
      final edge = await tester.startGesture(rect.center);
      await edge.moveTo(Offset(bounds.right + 10, rect.center.dy));
      await edge.up();
      expect(c.ops.single, isA<StrokeOp>());
      expect(
        (c.ops.single as StrokeOp).stroke.points.last.dx,
        c.pageSize.width,
      );
      tool = SketchTool.eraser;
      await show();
      await tester.tapAt(rect.center);
      await tester.runAsync(() async {
        final image = await c.flatten();
        expect(await pixel(image, image.width ~/ 2, image.height ~/ 2), [
          255,
          255,
          255,
          255,
        ]);
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'wrong PNG dimensions are protected and malformed settings default',
    (tester) async {
      final d = MemoryDevice();
      final progress = ProgressController(d);
      await progress.load();
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawPaint(ui.Paint()..color = Colors.white);
        final picture = recorder.endRecording();
        final image = await picture.toImage(2, 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        d.sketches[progress.activeProfile!.id] = SketchSnapshot(
          png: bytes.buffer.asUint8List(),
          settings: '{}',
        );
        image.dispose();
        picture.dispose();
      });
      await mount(tester, d);
      expect(find.text("This drawing couldn't be opened."), findsOneWidget);
      expect(d.sketchWrites, 0);
      await tester.tap(find.text('Start a new page'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Keep it'));
      await tester.pumpAndSettle();
      expect(d.sketchWrites, 0);
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
      d.sketches[progress.activeProfile!.id] = const SketchSnapshot(
        settings: '{}',
      );
      await mount(tester, d);
      expect(canvas(tester).color, sketchDefaultColor);
      expect(canvas(tester).width, sketchDefaultBrush);
      expect(canvas(tester).tool, SketchTool.brush);
      await tester.pumpWidget(const SizedBox());
      await settleImages(tester);
      progress.dispose();
    },
  );

  testWidgets('gallery failure is recoverable and leaves drawing intact', (
    tester,
  ) async {
    final d = GalleryFailureDevice();
    final semantics = tester.ensureSemantics();
    await mount(tester, d);
    final size = tester.getSize(keyed('sketch-save'));
    await draw(tester);
    await tester.tap(keyed('sketch-save'));
    await settleImages(tester);
    expect(
      find.byTooltip("Couldn't save to photos. Try again"),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel("Couldn't save to photos. Try again"),
      findsOneWidget,
    );
    expect(tester.getSize(keyed('sketch-save')), size);
    final button = tester.widget<OutlinedButton>(keyed('sketch-save'));
    expect(
      button.style!.side!.resolve({})!.color,
      GardenTheme.light.colorScheme.error,
    );
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    semantics.dispose();
    expect(canvas(tester).controller.canUndo, isTrue);
    expect(
      tester.widget<OutlinedButton>(keyed('sketch-save')).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    await settleImages(tester);
  });

  for (final haptics in [true, false]) {
    testWidgets(
      'fill taps use saved haptics=$haptics and never award XP or play audio',
      (tester) async {
        final d = MemoryDevice()..haptics = haptics;
        final fixture = await mount(tester, d);
        final xp = fixture.progress.progress!.xp;
        await tester.tap(keyed('sketch-tool'));
        await tester.pumpAndSettle();
        await tester.tap(keyed('sketch-tool-fill'));
        await settleImages(tester);
        await tester.tapAt(tester.getCenter(keyed('sketch-canvas')));
        await waitForFills(tester, canvas(tester).controller);
        await settleImages(tester);
        expect(d.feedbacks, haptics ? [DeviceFeedback.light] : isEmpty);
        expect(fixture.progress.progress!.xp, xp);
        expect(d.clips, isEmpty);
        await tester.tapAt(tester.getCenter(keyed('sketch-canvas')));
        await waitForFills(tester, canvas(tester).controller);
        await settleImages(tester);
        expect(d.feedbacks, haptics ? [DeviceFeedback.light] : isEmpty);
        await tester.pumpWidget(const SizedBox());
        await settleImages(tester);
      },
    );
  }

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 640), const Size(740, 360)]) {
      testWidgets('white paper and no overflow: dark=$dark, size=$size', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await mount(
          tester,
          MemoryDevice(),
          dark: dark,
          scale: size.width == 320 ? 2 : 1,
        );
        expect(tester.takeException(), isNull);
        final rect = SketchCanvas.pageRect(
          tester.getSize(keyed('sketch-canvas')),
          canvas(tester).controller.pageSize,
        );
        expect(
          rect.size.aspectRatio,
          closeTo(tester.getSize(keyed('sketch-canvas')).aspectRatio, .001),
        );
        expect(rect.width, greaterThanOrEqualTo(size.width == 320 ? 140 : 150));
        if (size.width == 320) {
          for (final label in ['Undo', 'Redo', 'Clear']) {
            expect(find.byTooltip(label), findsOneWidget);
            expect(find.text(label), findsNothing);
          }
        }
        await tester.runAsync(() async {
          final image = await canvas(tester).controller.flatten();
          expect(await pixel(image, image.width ~/ 2, image.height ~/ 2), [
            255,
            255,
            255,
            255,
          ]);
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        await settleImages(tester);
      });
    }
  }
}
