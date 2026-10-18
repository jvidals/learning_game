import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/flood_fill.dart';
import 'package:rainbow_garden/sketch.dart';
import 'package:rainbow_garden/sketch_ink.dart';

Uint8List enclosedPixels(int side) {
  final pixels = Uint8List(side * side * 4)..fillRange(0, side * side * 4, 255);
  void black(int x, int y) {
    final offset = (y * side + x) * 4;
    pixels[offset] = pixels[offset + 1] = pixels[offset + 2] = 0;
  }

  for (var i = 8; i < side - 8; i++) {
    black(i, 8);
    black(i, side - 9);
    black(8, i);
    black(side - 9, i);
  }
  for (var y = 56; y < 70; y++) {
    for (var x = 56; x < 70; x++) {
      black(x, y);
    }
  }
  return pixels;
}

void expectSameMask(FloodFillResult result, FloodFillResult mask) {
  expect(
    [result.left, result.top, result.width, result.height],
    [mask.left, mask.top, mask.width, mask.height],
  );
  var transparent = 0;
  for (var i = 0; i < mask.rgba.length; i += 4) {
    expect(result.rgba[i + 3], mask.rgba[i + 3]);
    if (mask.rgba[i + 3] == 0) {
      expect(result.rgba.sublist(i, i + 4), [0, 0, 0, 0]);
      transparent++;
    }
  }
  expect(transparent, greaterThan(0));
}

void main() {
  test('glitter twinkles share deterministic start and path placements', () {
    final stroke = SketchStroke(
      color: 0xFF204080,
      width: 24,
      special: SketchSpecial.glitter,
      points: const [
        Offset(20, 60),
        Offset(55, 35),
        Offset(110, 75),
        Offset(290, 65),
      ],
    );
    final anchors = glitterTwinkles(stroke);
    expect(anchors, isNotEmpty);
    expect(anchors, glitterTwinkles(stroke));
    expect(anchors.first.x, 20);
    expect(anchors.first.y, 60);
    expect(anchors.first.hashCode, glitterTwinkles(stroke).first.hashCode);
    expect(anchors.every((a) => a.size >= 6 && a.size <= 18), isTrue);
    expect(
      glitterTwinkles(
        SketchStroke(
          color: 0,
          width: 24,
          special: SketchSpecial.glitter,
          points: [],
        ),
      ),
      isEmpty,
    );
    expect(
      glitterTwinkles(
        SketchStroke(
          color: 0,
          width: 24,
          special: SketchSpecial.glitter,
          points: const [Offset(20, 60)],
        ),
      ),
      [anchors.first],
    );
  });

  test(
    'glitter fill anchors are sparse, deterministic and inside its mask',
    () async {
      final pixels = enclosedPixels(96);
      final a = glitterFloodFill(pixels, 96, 96, 20, 20, 0xFF204080)!;
      final b = (await glitterFloodFillInBackground(
        pixels,
        96,
        96,
        20,
        20,
        0xFF204080,
      ))!;
      expect(a.twinkles, isNotEmpty);
      expect(a.twinkles.length, lessThanOrEqualTo(150));
      expect(a.twinkles, b.twinkles);
      for (final t in a.twinkles) {
        final i = ((t.y.floor() - a.top) * a.width + t.x.floor() - a.left) * 4;
        expect(a.rgba[i + 3], greaterThan(0));
      }
    },
  );

  for (final special in [SketchSpecial.glitter, SketchSpecial.neon]) {
    test('${special.name} settings round-trip the special and base color', () {
      final settings = SketchSettings(color: 0xFF204080, special: special);
      expect(SketchSettings.decode(settings.encode()), settings);
      expect(
        special.label,
        special == SketchSpecial.glitter ? 'Glitter' : 'Neon',
      );
    });
  }

  test(
    'glitter fill preserves its mask and deterministically sparkles over base',
    () async {
      const side = 96;
      const base = 0xFF204080;
      final pixels = enclosedPixels(side);
      final original = Uint8List.fromList(pixels);
      final mask = floodFill(pixels, side, side, 20, 20, base)!;
      final result = glitterFloodFill(pixels, side, side, 20, 20, base)!;
      expectSameMask(result, mask);
      expect(
        glitterFloodFill(pixels, side, side, 20, 20, base)!.rgba,
        result.rgba,
      );
      expect(
        (await glitterFloodFillInBackground(
          pixels,
          side,
          side,
          20,
          20,
          base,
        ))!.rgba,
        result.rgba,
      );
      var basePixels = 0;
      var sparkles = 0;
      for (var i = 0; i < result.rgba.length; i += 4) {
        if (result.rgba[i + 3] == 0) continue;
        final rgb = result.rgba.sublist(i, i + 3);
        if (rgb[0] == 32 && rgb[1] == 64 && rgb[2] == 128) {
          basePixels++;
        } else {
          expect(rgb, anyOf(equals([255, 255, 255]), equals([255, 213, 79])));
          sparkles++;
        }
      }
      expect(sparkles, greaterThan(0));
      expect(basePixels, greaterThan(sparkles * 4));
      expect(pixels, original);
    },
  );

  test('neon fill lightens inward from every mask edge', () async {
    const side = 96;
    const base = 0xFF204080;
    final pixels = enclosedPixels(side);
    final original = Uint8List.fromList(pixels);
    final result = neonFloodFill(pixels, side, side, 20, 20, base)!;
    expectSameMask(result, floodFill(pixels, side, side, 20, 20, base)!);
    List<int> at(int x, int y) {
      final i = ((y - result.top) * result.width + x - result.left) * 4;
      return result.rgba.sublist(i, i + 3);
    }

    final edge = at(result.left, 30);
    final center = at(32, 32);
    final holeEdge = at(57, 60);
    for (var c = 0; c < 3; c++) {
      final channel = (base >> (16 - c * 8)) & 255;
      expect(edge[c], channel);
      expect(center[c], closeTo(channel + (255 - channel) * .55, 1));
      expect(
        (holeEdge[c] - channel).abs(),
        lessThan((center[c] - channel).abs()),
      );
    }
    expect(
      (await neonFloodFillInBackground(pixels, side, side, 20, 20, base))!.rgba,
      result.rgba,
    );
    expect(pixels, original);
  });

  test(
    'new fills validate input and can recolor a base-colored seed',
    () async {
      for (final fill in [glitterFloodFill, neonFloodFill]) {
        expect(
          () => fill(Uint8List(3), 1, 1, 0, 0, 0xFF204080),
          throwsArgumentError,
        );
        expect(
          () => fill(Uint8List(0), -1, 0, 0, 0, 0xFF204080),
          throwsArgumentError,
        );
        expect(fill(Uint8List(4), 1, 1, -1, 0, 0xFF204080), isNull);
        expect(fill(Uint8List(4), 1, 1, 1, 0, 0xFF204080), isNull);
        expect(
          fill(Uint8List.fromList([32, 64, 128, 255]), 1, 1, 0, 0, 0xFF204080),
          isNotNull,
        );
      }
      expect(
        await glitterFloodFillInBackground(
          Uint8List(4),
          1,
          1,
          0,
          1,
          0xFF204080,
        ),
        isNull,
      );
      expect(
        await neonFloodFillInBackground(Uint8List(4), 1, 1, 0, 1, 0xFF204080),
        isNull,
      );
    },
  );

  test('rainbow bands interpolate, wrap and stay opaque', () {
    expect(rainbowBandLength(2), 40);
    expect(rainbowBandLength(80), 120);
    for (final width in [2.0, 80.0]) {
      final length = rainbowBandLength(width);
      for (var i = 0; i < 6; i++) {
        expect(rainbowColorAt(i * length, width), sketchRainbowBands[i]);
      }
      expect(rainbowColorAt(6 * length, width), sketchRainbowBands.first);
      final halfway = rainbowColorAt(length / 2, width);
      expect((halfway >> 24) & 255, 255);
      for (final shift in [0, 8, 16]) {
        final a = (sketchRainbowBands[0] >> shift) & 255;
        final b = (sketchRainbowBands[1] >> shift) & 255;
        expect((halfway >> shift) & 255, closeTo((a + b) / 2, 1));
      }
    }
    for (final distance in [-1.0, double.nan, double.infinity]) {
      expect(rainbowColorAt(distance, 20), sketchRainbowBands.first);
    }
  });

  test('inks have value equality and stable hashes', () {
    expect(const SolidInk(0xFF123456), const SolidInk(0xFF123456));
    expect(const SolidInk(1), isNot(const SolidInk(2)));
    expect(
      const SpecialInk(SketchSpecial.rainbow),
      const SpecialInk(SketchSpecial.rainbow),
    );
    expect(const SolidInk(1), isNot(const SpecialInk(SketchSpecial.rainbow)));
    expect(const SolidInk(1).hashCode, SolidInk(1).hashCode);
    expect(
      const SpecialInk(SketchSpecial.rainbow).hashCode,
      SpecialInk(SketchSpecial.rainbow).hashCode,
    );
    expect(SketchSpecial.rainbow.name, 'rainbow');
    expect(SketchSpecial.rainbow.label, 'Rainbow');
  });

  test('fill stripes follow crop rows and preserve unfilled mask pixels', () {
    const side = 24;
    final pixels = Uint8List(side * side * 4)
      ..fillRange(0, side * side * 4, 255);
    void black(int x, int y) {
      final offset = (y * side + x) * 4;
      pixels[offset] = pixels[offset + 1] = pixels[offset + 2] = 0;
    }

    for (var i = 2; i <= 21; i++) {
      black(i, 2);
      black(i, 21);
      black(2, i);
      black(21, i);
    }
    // An interior obstacle leaves a transparent hole after edge growth.
    for (var y = 8; y <= 15; y++) {
      for (var x = 8; x <= 15; x++) {
        black(x, y);
      }
    }
    final original = Uint8List.fromList(pixels);
    final result = rainbowFloodFill(pixels, side, side, 4, 4)!;
    final mask = floodFill(pixels, side, side, 4, 4, 0xFF123456)!;
    expect(
      [result.left, result.top, result.width, result.height],
      [mask.left, mask.top, mask.width, mask.height],
    );
    final seen = <int>{};
    var transparent = 0;
    for (var row = 0; row < result.height; row++) {
      for (var col = 0; col < result.width; col++) {
        final offset = (row * result.width + col) * 4;
        if (mask.rgba[offset + 3] == 0) {
          expect(result.rgba.sublist(offset, offset + 4), [0, 0, 0, 0]);
          transparent++;
        } else {
          final color = sketchRainbowBands[(row * 6) ~/ result.height];
          expect(result.rgba.sublist(offset, offset + 4), [
            (color >> 16) & 255,
            (color >> 8) & 255,
            color & 255,
            255,
          ]);
          seen.add(color);
        }
      }
    }
    expect(seen.length, 6);
    expect(transparent, greaterThan(0));
    expect(pixels, original);
    expect(rainbowFloodFill(pixels, side, side, -1, 0), isNull);
    expect(rainbowFloodFill(pixels, side, side, side, 0), isNull);
    expect(
      () => rainbowFloodFill(Uint8List(3), 1, 1, 0, 0),
      throwsArgumentError,
    );
    expect(
      () => rainbowFloodFill(Uint8List(0), -1, 0, 0, 0),
      throwsArgumentError,
    );
  });

  test('red seed fills synchronously and in the background', () async {
    final pixels = Uint8List.fromList([229, 57, 53, 255]);
    final result = rainbowFloodFill(pixels, 1, 1, 0, 0)!;
    expect(result.rgba, pixels);
    final background = await rainbowFloodFillInBackground(pixels, 1, 1, 0, 0);
    expect(background!.rgba, result.rgba);
    expect(await rainbowFloodFillInBackground(pixels, 1, 1, 0, 1), isNull);
  });

  testWidgets('painted path changes color and continues across contours', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintRainbowPath(
        canvas,
        Path()
          ..moveTo(10, 20)
          ..lineTo(230, 20)
          ..moveTo(10, 50)
          ..lineTo(250, 50),
        8,
      );
      paintRainbowPath(canvas, Path()..moveTo(0, 0), 8);
      final picture = recorder.endRecording();
      final image = await picture.toImage(270, 70);
      final data = (await image.toByteData())!;
      final colors = <int>{};
      for (var band = 0; band < 6; band++) {
        final x = 12 + band * 40;
        final offset = (20 * 270 + x) * 4;
        final expected = sketchRainbowBands[band];
        expect(data.getUint8(offset), closeTo((expected >> 16) & 255, 2));
        expect(data.getUint8(offset + 1), closeTo((expected >> 8) & 255, 2));
        expect(data.getUint8(offset + 2), closeTo(expected & 255, 2));
        expect(data.getUint8(offset + 3), 255);
        colors.add(
          (data.getUint8(offset) << 16) |
              (data.getUint8(offset + 1) << 8) |
              data.getUint8(offset + 2),
        );
      }
      expect(colors.length, greaterThanOrEqualTo(3));
      final first = (20 * 270 + 12) * 4;
      final next = (50 * 270 + 12) * 4;
      expect(
        data.buffer.asUint8List(next, 4),
        isNot(data.buffer.asUint8List(first, 4)),
      );
      final expected = rainbowColorAt(220, 8);
      expect(data.buffer.asUint8List(next, 4), [
        (expected >> 16) & 255,
        (expected >> 8) & 255,
        expected & 255,
        255,
      ]);
      image.dispose();
      picture.dispose();
    });
  });
}
