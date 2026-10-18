import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/painting.dart';

import 'flood_fill.dart';
import 'sketch.dart' show SketchStroke;

/// Special inks keep stable names for saved selections.
enum SketchSpecial {
  rainbow,
  glitter,
  neon;

  bool get isEffect => this == glitter || this == neon;

  String get label => switch (this) {
    rainbow => 'Rainbow',
    glitter => 'Glitter',
    neon => 'Neon',
  };
}

sealed class SketchInk {
  const SketchInk();
}

final class SolidInk extends SketchInk {
  const SolidInk(this.argb);

  final int argb;

  @override
  bool operator ==(Object other) => other is SolidInk && other.argb == argb;

  @override
  int get hashCode => Object.hash(SolidInk, argb);
}

final class SpecialInk extends SketchInk {
  const SpecialInk(this.kind);

  final SketchSpecial kind;

  @override
  bool operator ==(Object other) => other is SpecialInk && other.kind == kind;

  @override
  int get hashCode => Object.hash(SpecialInk, kind);
}

const List<int> sketchRainbowBands = [
  0xFFE53935,
  0xFFFF8A00,
  0xFFFFD600,
  0xFF8BD43C,
  0xFF29B6F6,
  0xFF8E36C9,
];

double rainbowBandLength(double width) => math.max(40, width * 1.5);

/// Smoothly cycles through opaque rainbow bands along a stroke.
int rainbowColorAt(double distance, double width) {
  final safeDistance = distance.isFinite && distance >= 0 ? distance : 0.0;
  final position = (safeDistance / rainbowBandLength(width)) % 6;
  final index = position.floor();
  final fraction = position - index;
  final start = sketchRainbowBands[index];
  final end = sketchRainbowBands[(index + 1) % 6];
  int channel(int shift) {
    final a = (start >> shift) & 255;
    final b = (end >> shift) & 255;
    return (a + (b - a) * fraction).round();
  }

  return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

/// Paints short round segments, carrying rainbow distance across contours.
void paintRainbowPath(Canvas canvas, Path path, double width) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..strokeWidth = width;
  var cumulative = 0.0;
  for (final metric in path.computeMetrics()) {
    for (var start = 0.0; start < metric.length; start += 8) {
      paint.color = Color(rainbowColorAt(cumulative + start, width));
      canvas.drawPath(
        metric.extractPath(start, math.min(start + 8, metric.length)),
        paint,
      );
    }
    cumulative += metric.length;
  }
}

// Fixed 32-bit mixing makes replay independent of process or frame state.
int _mix(int value) {
  value = ((value ^ (value >>> 16)) * 0x7FEB352D) & 0xFFFFFFFF;
  value = ((value ^ (value >>> 15)) * 0x846CA68B) & 0xFFFFFFFF;
  return (value ^ (value >>> 16)) & 0xFFFFFFFF;
}

int _pixelHash(int x, int y) => _mix(x ^ _mix(y));

int _lightCore(int base) {
  int channel(int shift) {
    final value = (base >> shift) & 255;
    return (value + (255 - value) * .55).round();
  }

  return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

Paint _roundPen(int color, double width) => Paint()
  ..color = Color(color)
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = width;

// Each contour is an immutable section of the smoothed stroke. Rasterizing
// separately also fixes the blur/antialias bounds while later sections grow.
void _paintSections(Canvas canvas, Path path, Paint pen) {
  for (final metric in path.computeMetrics()) {
    canvas.drawPath(metric.extractPath(0, metric.length), pen);
  }
}

/// A persistent page-unit anchor; animation never changes the saved raster.
class SketchTwinkle {
  const SketchTwinkle(this.x, this.y, this.phase, this.size);
  final double x, y;
  final int phase;
  final double size;

  @override
  bool operator ==(Object other) =>
      other is SketchTwinkle &&
      x == other.x &&
      y == other.y &&
      phase == other.phase &&
      size == other.size;
  @override
  int get hashCode => Object.hash(x, y, phase, size);
}

/// The same smoothed path is used by raster ink and its animation anchors.
Path sketchStrokePath(SketchStroke stroke) {
  final points = stroke.points;
  if (points.length < 2) return Path();
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  // Separate contours prevent extending a special stroke from changing the
  // rasterizer's subdivision/antialiasing of already-painted curve sections.
  final stableSections =
      stroke.special == SketchSpecial.glitter ||
      stroke.special == SketchSpecial.neon;
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final midpoint = (previous + points[i]) / 2;
    if (stableSections && i > 1) {
      final start = (points[i - 2] + previous) / 2;
      path.moveTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(previous.dx, previous.dy, midpoint.dx, midpoint.dy);
  }
  if (stableSections) {
    final tail = (points[points.length - 2] + points.last) / 2;
    path.moveTo(tail.dx, tail.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

typedef _GlitterSparkle = ({Offset center, int index, int hash});

Iterable<_GlitterSparkle> _glitterSparkles(
  Path path,
  double width,
  Offset start,
  bool isDot,
) sync* {
  final seed = _mix(
    _pixelHash(start.dx.round(), start.dy.round()) ^
        _mix((width * 100).round()),
  );
  final size = (width * .14).clamp(2.0, 5.0);
  final radius = math.max(0.0, width / 2 - size);
  _GlitterSparkle sparkle(Offset center, int index) =>
      (center: center, index: index, hash: _mix(seed ^ _mix(index)));
  yield sparkle(start, 0);
  for (var i = 1; i <= 2; i++) {
    final hash = _mix(seed ^ i);
    final angle = (hash & 65535) / 65535 * math.pi * 2;
    final distance = radius * (.35 + ((hash >>> 16) & 255) / 255 * .6);
    yield sparkle(
      start + Offset(math.cos(angle), math.sin(angle)) * distance,
      -i,
    );
  }
  if (isDot) return;
  final spacing = math.max(1.0, width * .5);
  var index = 1;
  var cumulative = 0.0;
  for (final metric in path.computeMetrics()) {
    while (index * spacing <= cumulative + metric.length) {
      final tangent = metric.getTangentForOffset(index * spacing - cumulative);
      if (tangent != null) {
        final hash = _mix(seed ^ _mix(index));
        final offset = (((hash >>> 16) & 65535) / 65535 * 2 - 1) * radius;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        yield sparkle(tangent.position + normal * offset, index);
      }
      index++;
    }
    cumulative += metric.length;
  }
}

/// Every third path sparkle, plus the fixed start sparkle. Unfinished strokes
/// are deliberately omitted by the caller.
List<SketchTwinkle> glitterTwinkles(SketchStroke stroke) {
  if (stroke.special != SketchSpecial.glitter || stroke.points.isEmpty) {
    return const [];
  }
  return [
    for (final sparkle in _glitterSparkles(
      sketchStrokePath(stroke),
      stroke.width,
      stroke.points.first,
      stroke.points.length == 1,
    ))
      if (sparkle.index == 0 || (sparkle.index > 0 && sparkle.index % 3 == 0))
        SketchTwinkle(
          sparkle.center.dx,
          sparkle.center.dy,
          sparkle.hash,
          (stroke.width * .4).clamp(6.0, 18.0),
        ),
  ];
}

/// Base-color ink with fixed sparkle indices at cumulative path distances.
/// The start cluster also stays in place when a dot becomes a growing stroke.
void paintGlitterPath(
  Canvas canvas,
  Path path,
  double width,
  int base, {
  required Offset start,
  bool isDot = false,
}) {
  final pen = _roundPen(base, width);
  if (isDot) {
    canvas.drawCircle(start, width / 2, pen..style = PaintingStyle.fill);
  } else {
    _paintSections(canvas, path, pen);
  }
  final size = (width * .14).clamp(2.0, 5.0);
  final sparkle = Paint()..isAntiAlias = true;
  void drawSparkle(Offset center, int hash) {
    sparkle.color = Color(switch (hash % 3) {
      0 => 0xFFFFFFFF,
      1 => 0xFFFFD54F,
      _ => _lightCore(_lightCore(base)),
    });
    final extent = size * (.7 + ((hash >>> 8) & 255) / 255 * .3);
    if ((hash & 4) == 0) {
      canvas.drawCircle(center, extent * .55, sparkle);
    } else {
      final twinkle = Path()
        ..moveTo(center.dx, center.dy - extent)
        ..lineTo(center.dx + extent * .28, center.dy - extent * .28)
        ..lineTo(center.dx + extent, center.dy)
        ..lineTo(center.dx + extent * .28, center.dy + extent * .28)
        ..lineTo(center.dx, center.dy + extent)
        ..lineTo(center.dx - extent * .28, center.dy + extent * .28)
        ..lineTo(center.dx - extent, center.dy)
        ..lineTo(center.dx - extent * .28, center.dy - extent * .28)
        ..close();
      canvas.drawPath(twinkle, sparkle);
    }
  }

  for (final sparkle in _glitterSparkles(path, width, start, isDot)) {
    drawSparkle(sparkle.center, sparkle.hash);
  }
}

/// A soft saturated halo behind a narrow, white-tinted core.
void paintNeonPath(
  Canvas canvas,
  Path path,
  double width,
  int base, {
  Offset? dot,
}) {
  final core = _roundPen(_lightCore(base), width * .55);
  if (dot != null) {
    canvas.drawCircle(
      dot,
      width * .95,
      Paint()
        ..color = Color(base).withValues(alpha: .55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * .45),
    );
    canvas.drawCircle(
      dot,
      core.strokeWidth / 2,
      core..style = PaintingStyle.fill,
    );
    return;
  }
  // The halo is an opaque stroke in a blurred, translucent layer. Explicit
  // layer bounds keep perfectly straight lines (zero-height path bounds) from
  // losing a mask-filtered glow, and opaque sections never stack at joins.
  final sigma = width * .45;
  canvas.saveLayer(
    path.getBounds().inflate(width * .95 + sigma * 3),
    Paint()
      ..color = const Color(0x8C000000)
      ..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
  );
  _paintSections(canvas, path, _roundPen(base, width * 1.9));
  canvas.restore();
  _paintSections(canvas, path, core);
}

/// Six hard-edged stripes, top to bottom, matching the rainbow fill. A sweep
/// gradient showed seams on small swatches.
const Gradient sketchRainbowSwatch = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFE53935),
    Color(0xFFE53935),
    Color(0xFFFF8A00),
    Color(0xFFFF8A00),
    Color(0xFFFFD600),
    Color(0xFFFFD600),
    Color(0xFF8BD43C),
    Color(0xFF8BD43C),
    Color(0xFF29B6F6),
    Color(0xFF29B6F6),
    Color(0xFF8E36C9),
    Color(0xFF8E36C9),
  ],
  stops: [
    0,
    1 / 6,
    1 / 6,
    2 / 6,
    2 / 6,
    3 / 6,
    3 / 6,
    4 / 6,
    4 / 6,
    5 / 6,
    5 / 6,
    1,
  ],
);

/// Colors the fill mask in six horizontal bands across its cropped height.
FloodFillResult? rainbowFloodFill(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
) {
  if (width < 0 || height < 0 || rgba.length != width * height * 4) {
    throw ArgumentError('RGBA buffer length must equal width * height * 4.');
  }
  if (x < 0 || x >= width || y < 0 || y >= height) return null;
  final seed = (y * width + x) * 4;
  final seedRgb = (rgba[seed] << 16) | (rgba[seed + 1] << 8) | rgba[seed + 2];
  final result = floodFill(
    rgba,
    width,
    height,
    x,
    y,
    0xFF000000 | (seedRgb ^ 0x000001),
  );
  if (result == null) return null;
  for (var row = 0; row < result.height; row++) {
    final band = ((row * 6) ~/ result.height).clamp(0, 5);
    final color = sketchRainbowBands[band];
    for (var col = 0; col < result.width; col++) {
      final offset = (row * result.width + col) * 4;
      if (result.rgba[offset + 3] == 0) continue;
      result.rgba[offset] = (color >> 16) & 255;
      result.rgba[offset + 1] = (color >> 8) & 255;
      result.rgba[offset + 2] = color & 255;
    }
  }
  return FloodFillResult(
    left: result.left,
    top: result.top,
    width: result.width,
    height: result.height,
    rgba: result.rgba,
  );
}

/// Runs the fill without capturing a canvas or UI in the isolate.
Future<FloodFillResult?> rainbowFloodFillInBackground(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
) => Isolate.run(() => rainbowFloodFill(rgba, width, height, x, y));

// Match Rainbow's mask selection, including its antialiased-edge growth. The
// placeholder must differ from the seed even if the selected base matches it.
FloodFillResult? _specialFillMask(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
) {
  if (width < 0 || height < 0 || rgba.length != width * height * 4) {
    throw ArgumentError('RGBA buffer length must equal width * height * 4.');
  }
  if (x < 0 || x >= width || y < 0 || y >= height) return null;
  final seed = (y * width + x) * 4;
  final seedRgb = (rgba[seed] << 16) | (rgba[seed + 1] << 8) | rgba[seed + 2];
  return floodFill(
    rgba,
    width,
    height,
    x,
    y,
    0xFF000000 | (seedRgb ^ 0x000001),
  );
}

void _setRgb(Uint8List rgba, int offset, int color) {
  rgba[offset] = (color >> 16) & 255;
  rgba[offset + 1] = (color >> 8) & 255;
  rgba[offset + 2] = color & 255;
}

/// Scatters 2–3 px sparkle clusters over the base, anchored to page pixels.
FloodFillResult? glitterFloodFill(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
  int base,
) {
  final result = _specialFillMask(rgba, width, height, x, y);
  if (result == null) return null;
  final pixels = result.rgba;
  final twinkles = <SketchTwinkle>[];
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] != 0) _setRgb(pixels, i, base);
  }
  for (var row = 0; row < result.height; row++) {
    for (var col = 0; col < result.width; col++) {
      if (pixels[(row * result.width + col) * 4 + 3] == 0) continue;
      final hash = _pixelHash(result.left + col, result.top + row);
      if (hash >= 51539608) continue; // 1.2% of 2^32 are cluster anchors.
      // A subset of the exact raster cluster anchors: about .08% of mask pixels.
      if (hash < 3435974) {
        twinkles.add(
          SketchTwinkle(
            (result.left + col).toDouble(),
            (result.top + row).toDouble(),
            hash,
            10,
          ),
        );
      }
      final size = 2 + ((hash >>> 16) & 1);
      final color = (hash & 1) == 0 ? 0xFFFFFFFF : 0xFFFFD54F;
      for (var dy = 0; dy < size && row + dy < result.height; dy++) {
        for (var dx = 0; dx < size && col + dx < result.width; dx++) {
          final offset = ((row + dy) * result.width + col + dx) * 4;
          if (pixels[offset + 3] != 0) _setRgb(pixels, offset, color);
        }
      }
    }
  }
  // Keep the smallest hashes when capped, so large fills still twinkle across
  // the whole region rather than just its first rows.
  if (twinkles.length > 150) {
    twinkles.sort((a, b) => a.phase.compareTo(b.phase));
  }
  return FloodFillResult(
    left: result.left,
    top: result.top,
    width: result.width,
    height: result.height,
    rgba: pixels,
    twinkles: List.unmodifiable(twinkles.take(150)),
  );
}

Future<FloodFillResult?> glitterFloodFillInBackground(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
  int base,
) => Isolate.run(() => glitterFloodFill(rgba, width, height, x, y, base));

/// Two chamfer passes (axial 3, diagonal 4) measure distance to every mask edge.
/// Capping at 45 keeps storage to a byte: 3 for the edge + 14 inward pixels.
FloodFillResult? neonFloodFill(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
  int base,
) {
  final result = _specialFillMask(rgba, width, height, x, y);
  if (result == null) return null;
  final w = result.width;
  final h = result.height;
  final pixels = result.rgba;
  final distances = Uint8List(w * h);
  for (var row = 0; row < h; row++) {
    for (var col = 0; col < w; col++) {
      final i = row * w + col;
      distances[i] = pixels[i * 4 + 3] == 0
          ? 0
          : row == 0 || col == 0 || row == h - 1 || col == w - 1
          ? 3
          : 45;
    }
  }
  for (var row = 0; row < h; row++) {
    for (var col = 0; col < w; col++) {
      final i = row * w + col;
      if (distances[i] == 0) continue;
      var d = distances[i];
      if (col > 0) d = math.min(d, distances[i - 1] + 3);
      if (row > 0) {
        d = math.min(d, distances[i - w] + 3);
        if (col > 0) d = math.min(d, distances[i - w - 1] + 4);
        if (col + 1 < w) d = math.min(d, distances[i - w + 1] + 4);
      }
      distances[i] = d;
    }
  }
  for (var row = h - 1; row >= 0; row--) {
    for (var col = w - 1; col >= 0; col--) {
      final i = row * w + col;
      if (distances[i] == 0) continue;
      var d = distances[i];
      if (col + 1 < w) d = math.min(d, distances[i + 1] + 3);
      if (row + 1 < h) {
        d = math.min(d, distances[i + w] + 3);
        if (col > 0) d = math.min(d, distances[i + w - 1] + 4);
        if (col + 1 < w) d = math.min(d, distances[i + w + 1] + 4);
      }
      distances[i] = d;
    }
  }
  final core = _lightCore(base);
  for (var i = 0; i < distances.length; i++) {
    if (pixels[i * 4 + 3] == 0) continue;
    final amount = ((distances[i] - 3) / 42).clamp(0.0, 1.0);
    for (var channel = 0; channel < 3; channel++) {
      final shift = 16 - channel * 8;
      final a = (base >> shift) & 255;
      final b = (core >> shift) & 255;
      pixels[i * 4 + channel] = (a + (b - a) * amount).round();
    }
  }
  return result;
}

Future<FloodFillResult?> neonFloodFillInBackground(
  Uint8List rgba,
  int width,
  int height,
  int x,
  int y,
  int base,
) => Isolate.run(() => neonFloodFill(rgba, width, height, x, y, base));
