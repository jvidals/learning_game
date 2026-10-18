import 'dart:isolate';
import 'dart:math' show max, min;
import 'dart:typed_data';

import 'sketch_ink.dart' show SketchTwinkle;

/// A tight crop of a fill mask, ready to composite over the flattened page.
class FloodFillResult {
  const FloodFillResult({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.rgba,
    this.twinkles = const [],
  });

  final int left, top, width, height;
  final Uint8List rgba;
  final List<SketchTwinkle> twinkles;
}

/// Fills the four-connected region matching the seed's RGB within [tolerance].
/// Square dilation by [grow] covers antialiased edges. The input is unchanged;
/// output mask pixels are either transparent black or opaque [fillColor] RGB.
/// Work and temporary memory are linear in the number of input pixels.
FloodFillResult? floodFill(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
  int fillColor, {
  int tolerance = 40,
  int grow = 2,
}) {
  if (width < 0 || height < 0 || rgba.length != width * height * 4) {
    throw ArgumentError('RGBA buffer length must equal width * height * 4.');
  }
  if (tolerance < 0) throw ArgumentError.value(tolerance, 'tolerance');
  if (grow < 0) throw ArgumentError.value(grow, 'grow');
  if (x < 0 || x >= width || y < 0 || y >= height) return null;

  final seed = (y * width + x) * 4;
  final seedR = rgba[seed];
  final seedG = rgba[seed + 1];
  final seedB = rgba[seed + 2];
  final fillR = (fillColor >> 16) & 255;
  final fillG = (fillColor >> 8) & 255;
  final fillB = fillColor & 255;
  if (seedR == fillR && seedG == fillG && seedB == fillB) return null;

  bool matches(int index) {
    final offset = index * 4;
    return (rgba[offset] - seedR).abs() <= tolerance &&
        (rgba[offset + 1] - seedG).abs() <= tolerance &&
        (rgba[offset + 2] - seedB).abs() <= tolerance;
  }

  final count = width * height;
  // 0 = unseen, 1 = queued scanline seed, 2 = filled. Each pixel can be
  // queued at most once, so a fixed-size typed stack cannot overflow.
  final visited = Uint8List(count);
  final stack = Int32List(count);
  var stackLength = 1;
  stack[0] = y * width + x;
  visited[stack[0]] = 1;
  var left = x;
  var right = x;
  var top = y;
  var bottom = y;

  while (stackLength > 0) {
    final index = stack[--stackLength];
    if (visited[index] == 2) continue;
    final row = index ~/ width;
    final rowStart = row * width;
    var start = index;
    var end = index;
    while (start > rowStart && visited[start - 1] != 2 && matches(start - 1)) {
      start--;
    }
    while (end + 1 < rowStart + width &&
        visited[end + 1] != 2 &&
        matches(end + 1)) {
      end++;
    }
    visited.fillRange(start, end + 1, 2);
    left = min(left, start - rowStart);
    right = max(right, end - rowStart);
    top = min(top, row);
    bottom = max(bottom, row);

    // A matching span on either adjacent row only needs one queued seed.
    for (var adjacent = row - 1; adjacent <= row + 1; adjacent += 2) {
      if (adjacent < 0 || adjacent >= height) continue;
      final delta = (adjacent - row) * width;
      var inSpan = false;
      for (var i = start + delta; i <= end + delta; i++) {
        if (visited[i] == 2 || !matches(i)) {
          inSpan = false;
        } else {
          if (!inSpan && visited[i] == 0) {
            visited[i] = 1;
            stack[stackLength++] = i;
          }
          inSpan = true;
        }
      }
    }
  }

  // Separable sliding-window dilation is O(pixels), independent of grow.
  // First dilate horizontally, then keep column counts for the vertical pass.
  final radius = min(grow, max(width, height));
  final cropLeft = max(0, left - radius);
  final cropRight = min(width - 1, right + radius);
  final cropTop = max(0, top - radius);
  final cropBottom = min(height - 1, bottom + radius);
  final cropWidth = cropRight - cropLeft + 1;
  final cropHeight = cropBottom - cropTop + 1;
  final horizontal = Uint8List(cropWidth * (bottom - top + 1));
  for (var row = top; row <= bottom; row++) {
    final rowStart = row * width;
    var sum = 0;
    for (
      var col = max(0, cropLeft - radius);
      col <= min(width - 1, cropLeft + radius);
      col++
    ) {
      if (visited[rowStart + col] == 2) sum++;
    }
    for (var col = cropLeft; col <= cropRight; col++) {
      final offset = (row - top) * cropWidth + col - cropLeft;
      if (sum > 0) horizontal[offset] = 1;
      final leaving = col - radius;
      final entering = col + radius + 1;
      if (leaving >= 0 && visited[rowStart + leaving] == 2) sum--;
      if (entering < width && visited[rowStart + entering] == 2) sum++;
    }
  }

  final output = Uint8List(cropWidth * cropHeight * 4);
  final columns = Int32List(cropWidth);
  void addRow(int row, int sign) {
    if (row < top || row > bottom) return;
    final rowStart = (row - top) * cropWidth;
    for (var col = 0; col < cropWidth; col++) {
      columns[col] += sign * horizontal[rowStart + col];
    }
  }

  for (
    var row = max(top, cropTop - radius);
    row <= min(bottom, cropTop + radius);
    row++
  ) {
    addRow(row, 1);
  }
  for (var row = cropTop; row <= cropBottom; row++) {
    final rowStart = (row - cropTop) * cropWidth * 4;
    for (var col = 0; col < cropWidth; col++) {
      if (columns[col] == 0) continue;
      final offset = rowStart + col * 4;
      output[offset] = fillR;
      output[offset + 1] = fillG;
      output[offset + 2] = fillB;
      output[offset + 3] = 255;
    }
    addRow(row - radius, -1);
    addRow(row + radius + 1, 1);
  }
  return FloodFillResult(
    left: cropLeft,
    top: cropTop,
    width: cropWidth,
    height: cropHeight,
    rgba: output,
  );
}

/// Copies the input into a background isolate; no canvas or UI is captured.
Future<FloodFillResult?> floodFillInBackground(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
  int fillColor, {
  int tolerance = 40,
  int grow = 2,
}) => Isolate.run(
  () => floodFill(
    rgba,
    width,
    height,
    x,
    y,
    fillColor,
    tolerance: tolerance,
    grow: grow,
  ),
);
