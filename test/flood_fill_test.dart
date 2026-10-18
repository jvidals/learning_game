import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/flood_fill.dart';

const red = 0xFFFF0000;
const black = 0xFF000000;
const white = 0xFFFFFFFF;

Uint8List image(int width, int height, [int color = white]) {
  final bytes = Uint8List(width * height * 4);
  for (var i = 0; i < bytes.length; i += 4) {
    bytes[i] = (color >> 16) & 255;
    bytes[i + 1] = (color >> 8) & 255;
    bytes[i + 2] = color & 255;
    bytes[i + 3] = 255;
  }
  return bytes;
}

void pixel(Uint8List bytes, int width, int x, int y, int color) {
  final i = (y * width + x) * 4;
  bytes[i] = (color >> 16) & 255;
  bytes[i + 1] = (color >> 8) & 255;
  bytes[i + 2] = color & 255;
  bytes[i + 3] = 255;
}

void outline(
  Uint8List bytes,
  int width,
  int left,
  int top,
  int right,
  int bottom,
) {
  for (var x = left; x <= right; x++) {
    pixel(bytes, width, x, top, black);
    pixel(bytes, width, x, bottom, black);
  }
  for (var y = top; y <= bottom; y++) {
    pixel(bytes, width, left, y, black);
    pixel(bytes, width, right, y, black);
  }
}

List<int> outputPixel(FloodFillResult result, int x, int y) {
  if (x < result.left ||
      y < result.top ||
      x >= result.left + result.width ||
      y >= result.top + result.height) {
    return [0, 0, 0, 0];
  }
  final i = ((y - result.top) * result.width + x - result.left) * 4;
  return result.rgba.sublist(i, i + 4);
}

void main() {
  test('enclosed square fills only the interior with a tight crop', () {
    final bytes = image(9, 9);
    outline(bytes, 9, 1, 1, 7, 7);
    final before = Uint8List.fromList(bytes);
    final result = floodFill(bytes, 9, 9, 4, 4, red, grow: 0)!;
    expect(
      (result.left, result.top, result.width, result.height),
      (2, 2, 5, 5),
    );
    for (var y = 0; y < 9; y++) {
      for (var x = 0; x < 9; x++) {
        expect(
          outputPixel(result, x, y),
          x >= 2 && x <= 6 && y >= 2 && y <= 6
              ? [255, 0, 0, 255]
              : [0, 0, 0, 0],
        );
      }
    }
    expect(bytes, before);
  });

  test(
    'opening leaks into the entire connected area but leaves walls transparent',
    () {
      final bytes = image(9, 9);
      outline(bytes, 9, 1, 1, 7, 7);
      pixel(bytes, 9, 4, 1, white);
      final result = floodFill(bytes, 9, 9, 4, 4, red, grow: 0)!;
      expect(
        (result.left, result.top, result.width, result.height),
        (0, 0, 9, 9),
      );
      for (var y = 0; y < 9; y++) {
        for (var x = 0; x < 9; x++) {
          final isWall = bytes[(y * 9 + x) * 4] == 0;
          expect(
            outputPixel(result, x, y),
            isWall ? [0, 0, 0, 0] : [255, 0, 0, 255],
          );
        }
      }
    },
  );

  test(
    'growth covers the grey halo and dilates diagonally with a square mask',
    () {
      final bytes = image(11, 11);
      outline(bytes, 11, 1, 1, 9, 9);
      for (var y = 2; y <= 8; y++) {
        for (var x = 2; x <= 8; x++) {
          if (x == 2 || x == 8 || y == 2 || y == 8) {
            pixel(bytes, 11, x, y, 0xFFAAAAAA);
          }
        }
      }
      final plain = floodFill(bytes, 11, 11, 5, 5, red, grow: 0)!;
      expect(outputPixel(plain, 2, 2), [0, 0, 0, 0]);
      final grown = floodFill(bytes, 11, 11, 5, 5, red, grow: 1)!;
      expect((grown.left, grown.top, grown.width, grown.height), (2, 2, 7, 7));
      expect(outputPixel(grown, 2, 2), [255, 0, 0, 255]);
      expect(outputPixel(grown, 8, 8), [255, 0, 0, 255]);
      expect(outputPixel(grown, 1, 5), [0, 0, 0, 0]);
      final defaultGrowth = floodFill(bytes, 11, 11, 5, 5, red)!;
      expect(
        (
          defaultGrowth.left,
          defaultGrowth.top,
          defaultGrowth.width,
          defaultGrowth.height,
        ),
        (1, 1, 9, 9),
      );
    },
  );

  test('equal RGB and out-of-bounds seeds return null', () {
    final bytes = image(3, 3, red);
    expect(floodFill(bytes, 3, 3, 1, 1, 0x00FF0000), isNull);
    for (final point in [(-1, 0), (0, -1), (3, 0), (0, 3)]) {
      expect(floodFill(bytes, 3, 3, point.$1, point.$2, white), isNull);
    }
    expect(floodFill(Uint8List(0), 0, 0, 0, 0, red), isNull);
  });

  test('all edges and corners work and growth clamps to the image', () {
    for (final point in [
      (0, 0),
      (4, 0),
      (0, 4),
      (4, 4),
      (2, 0),
      (0, 2),
      (4, 2),
      (2, 4),
    ]) {
      final bytes = image(5, 5, black);
      pixel(bytes, 5, point.$1, point.$2, white);
      final result = floodFill(bytes, 5, 5, point.$1, point.$2, red, grow: 0)!;
      expect(
        (result.left, result.top, result.width, result.height),
        (point.$1, point.$2, 1, 1),
      );
      final grown = floodFill(
        bytes,
        5,
        5,
        point.$1,
        point.$2,
        0x01FF0000,
        grow: 100,
      )!;
      expect((grown.left, grown.top, grown.width, grown.height), (0, 0, 5, 5));
      expect(grown.rgba.where((value) => value == 255).length, 50);
    }
  });

  test('tolerance compares each channel to the seed, inclusively', () {
    for (final shift in [0, 8, 16]) {
      final bytes = image(4, 1, 0xFF646464);
      pixel(bytes, 4, 1, 0, 0xFF646464 + (40 << shift));
      pixel(bytes, 4, 2, 0, 0xFF646464 + (41 << shift));
      pixel(bytes, 4, 3, 0, 0xFF646464);
      final result = floodFill(bytes, 4, 1, 0, 0, red, grow: 0)!;
      expect((result.left, result.width), (0, 2));
      expect(outputPixel(result, 1, 0), [255, 0, 0, 255]);
      expect(outputPixel(result, 2, 0), [0, 0, 0, 0]);
    }
  });

  test('connectivity excludes diagonal-only neighbors', () {
    final bytes = image(2, 2, black);
    pixel(bytes, 2, 0, 0, white);
    pixel(bytes, 2, 1, 1, white);
    final result = floodFill(bytes, 2, 2, 0, 0, red, grow: 0)!;
    expect((result.width, result.height), (1, 1));
    expect(outputPixel(result, 1, 1), [0, 0, 0, 0]);
  });

  test('wrong buffer lengths throw ArgumentError', () {
    expect(
      () => floodFill(Uint8List(15), 2, 2, 0, 0, red),
      throwsArgumentError,
    );
    expect(
      () => floodFill(Uint8List(17), 2, 2, -1, -1, red),
      throwsArgumentError,
    );
  });

  test('background isolate returns the same crop and bytes', () async {
    final bytes = image(13, 17);
    outline(bytes, 13, 1, 3, 10, 14);
    final sync = floodFill(bytes, 13, 17, 5, 5, red, tolerance: 5, grow: 1)!;
    final async = (await floodFillInBackground(
      bytes,
      13,
      17,
      5,
      5,
      red,
      tolerance: 5,
      grow: 1,
    ))!;
    expect(
      (async.left, async.top, async.width, async.height),
      (sync.left, sync.top, sync.width, sync.height),
    );
    expect(async.rgba, sync.rgba);
    expect(await floodFillInBackground(bytes, 13, 17, -1, 0, red), isNull);
  });

  test('branching regions match a simple pixel traversal and dilation', () {
    final random = Random(714);
    for (var trial = 0; trial < 300; trial++) {
      final width = 1 + random.nextInt(12);
      final height = 1 + random.nextInt(12);
      final grow = random.nextInt(5);
      final tolerance = random.nextInt(3) * 20;
      final bytes = image(width, height);
      for (var i = 0; i < bytes.length; i += 4) {
        for (var channel = 0; channel < 3; channel++) {
          bytes[i + channel] = 100 + 20 * random.nextInt(4);
        }
      }
      final seedX = random.nextInt(width);
      final seedY = random.nextInt(height);
      final seed = seedY * width + seedX;
      final region = <int>{seed};
      final queue = [seed];
      for (var cursor = 0; cursor < queue.length; cursor++) {
        final x = queue[cursor] % width;
        final y = queue[cursor] ~/ width;
        for (final point in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]) {
          if (point.$1 < 0 ||
              point.$1 >= width ||
              point.$2 < 0 ||
              point.$2 >= height) {
            continue;
          }
          final index = point.$2 * width + point.$1;
          if (region.contains(index)) continue;
          if (List.generate(
            3,
            (channel) =>
                (bytes[index * 4 + channel] - bytes[seed * 4 + channel]).abs(),
          ).every((diff) => diff <= tolerance)) {
            region.add(index);
            queue.add(index);
          }
        }
      }
      final mask = <int>{};
      for (final index in region) {
        final x = index % width;
        final y = index ~/ width;
        for (var dy = -grow; dy <= grow; dy++) {
          for (var dx = -grow; dx <= grow; dx++) {
            if (x + dx >= 0 &&
                x + dx < width &&
                y + dy >= 0 &&
                y + dy < height) {
              mask.add((y + dy) * width + x + dx);
            }
          }
        }
      }
      final result = floodFill(
        bytes,
        width,
        height,
        seedX,
        seedY,
        red,
        tolerance: tolerance,
        grow: grow,
      )!;
      final xs = mask.map((index) => index % width).toList()..sort();
      final ys = mask.map((index) => index ~/ width).toList()..sort();
      expect(
        (result.left, result.top, result.width, result.height),
        (xs.first, ys.first, xs.last - xs.first + 1, ys.last - ys.first + 1),
        reason: 'trial $trial crop',
      );
      expect(result.rgba.length, result.width * result.height * 4);
      for (var index = 0; index < width * height; index++) {
        expect(
          outputPixel(result, index % width, index ~/ width),
          mask.contains(index) ? [255, 0, 0, 255] : [0, 0, 0, 0],
          reason: 'trial $trial pixel $index',
        );
      }
    }
  });

  test('full page with large closed outline fills in under three seconds', () {
    final bytes = image(1080, 1920);
    outline(bytes, 1080, 40, 40, 1039, 1879);
    final watch = Stopwatch()..start();
    final result = floodFill(bytes, 1080, 1920, 540, 960, red)!;
    watch.stop();
    // Visible in the test report even when the timing assertion passes.
    debugPrint('1080x1920 flood fill: ${watch.elapsedMilliseconds} ms');
    expect(watch.elapsedMilliseconds, lessThan(3000));
    expect(
      (result.left, result.top, result.width, result.height),
      (39, 39, 1002, 1842),
    );
    expect(outputPixel(result, 540, 960), [255, 0, 0, 255]);
    expect(outputPixel(result, 0, 0), [0, 0, 0, 0]);
  });
}
