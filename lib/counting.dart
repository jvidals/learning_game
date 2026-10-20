import 'dart:math';
import 'number_range.dart';

enum CountingObject { apple, flower, gem }

enum CountingArrangement { rows, frame, scattered }

extension CountingObjectContent on CountingObject {
  String get label => switch (this) {
    CountingObject.apple => 'apple',
    CountingObject.flower => 'flower',
    CountingObject.gem => 'gem',
  };
}

int readCountingMax(Object? value) {
  if (value is! int || !const [5, 10, 20].contains(value)) {
    throw const FormatException('Invalid counting range');
  }
  return value;
}

// 38 dp pictures with a 9 dp gap (half the original 18 dp gap).
// This controls placement, independently of the 56 dp accessibility targets.
const double _counterSpacing = 47;

/// Stable scene data: rebuilding or resizing never changes the collection.
class CountingScene {
  CountingScene(this.quantity, Random random)
    : object = CountingObject.values[random.nextInt(3)],
      arrangement = quantity > 10
          ? CountingArrangement.frame
          : CountingArrangement.values[random.nextInt(3)],
      seed = random.nextInt(1 << 30);
  final int quantity, seed;
  final CountingObject object;
  final CountingArrangement arrangement;
}

/// Visit-local manipulatives. No totals are revealed automatically by the UI.
class CountingWork {
  CountingWork(this.maximum) {
    if (maximum < 2 || maximum > NumberRange.countingMaximum)
      throw ArgumentError('Invalid counting capacity');
  }
  final int maximum;
  final Set<int> marked = {};
  final List<int> items = [];
  final Map<int, Point<double>> _positions = {};
  Map<int, Point<double>> get positions => Map.unmodifiable(_positions);
  double _trayWidth = 280;
  double get trayWidth => _trayWidth;
  late double _trayHeight = _initialHeight;
  double get trayHeight => _trayHeight;
  double get _initialHeight =>
      20 +
      (maximum / 5).ceil() * min(72, _trayWidth / 5) +
      (maximum > 10 ? 12 : 0);
  int _nextId = 0;
  void toggleMark(int index) {
    if (!marked.add(index)) marked.remove(index);
  }

  /// Keep centers in logical pixels. Only a width change remaps existing work.
  void resizeTray(double width) {
    if (!width.isFinite || width < 280) {
      throw ArgumentError('Invalid tray width');
    }
    if (width == _trayWidth) return;
    final previousWidth = _trayWidth;
    final previous = Map<int, Point<double>>.of(_positions);
    _trayWidth = width;
    _trayHeight = max(_trayHeight, _initialHeight);
    _positions.clear();
    for (final id in items) {
      final point = previous[id]!;
      _positions[id] = _place(
        Point(
          28 + (point.x - 28) * (width - 56) / (previousWidth - 56),
          point.y,
        ),
      );
    }
  }

  Point<double> _place(Point<double>? requested) {
    while (true) {
      final point = _freeCountingPosition(
        _trayWidth,
        _trayHeight,
        _positions.values,
        requested,
      );
      if (point != null) return point;
      // Add room below without moving counters already placed by the child.
      _trayHeight += _counterSpacing;
    }
  }

  bool add({Point<double>? position}) {
    if (items.length >= maximum) return false;
    if (position != null && (!position.x.isFinite || !position.y.isFinite)) {
      throw ArgumentError('Invalid counter position');
    }
    // Taps may nudge at most one 38 dp picture width. Only the Add button
    // (no requested position) may search farther away or grow the tray.
    final point = position == null
        ? _place(null)
        : _freeCountingPosition(
            _trayWidth,
            _trayHeight,
            _positions.values,
            position,
          );
    if (point == null ||
        (position != null && point.squaredDistanceTo(position) > 38 * 38)) {
      return false;
    }
    final id = _nextId++;
    items.add(id);
    _positions[id] = point;
    return true;
  }

  bool remove(int id) {
    if (!items.remove(id)) return false;
    _positions.remove(id);
    return true;
  }
}

/// The nearest free center lies on the requested axis or an obstacle/border
/// edge. Checking their intersections avoids pixel scanning and grid snapping.
Point<double>? _freeCountingPosition(
  double width,
  double height,
  Iterable<Point<double>> occupied,
  Point<double>? requested,
) {
  final target = requested == null
      ? null
      : Point(
          requested.x.clamp(28.0, width - 28),
          requested.y.clamp(28.0, height - 28),
        );
  final xs = <double>{28, width - 28, if (target != null) target.x};
  final ys = <double>{28, height - 28, if (target != null) target.y};
  for (final p in occupied) {
    xs.addAll([p.x - _counterSpacing, p.x + _counterSpacing]);
    ys.addAll([p.y - _counterSpacing, p.y + _counterSpacing]);
  }
  Point<double>? best;
  var bestDistance = double.infinity;
  for (final y in ys) {
    if (y < 28 || y > height - 28) continue;
    for (final x in xs) {
      if (x < 28 || x > width - 28) continue;
      if (occupied.any(
        (p) =>
            (p.x - x).abs() < _counterSpacing - 1e-8 &&
            (p.y - y).abs() < _counterSpacing - 1e-8,
      )) {
        continue;
      }
      final candidate = Point(x, y);
      final distance = requested == null
          ? 0.0
          : candidate.squaredDistanceTo(requested);
      if (best == null ||
          distance < bestDistance ||
          (distance == bestDistance &&
              (y < best.y || (y == best.y && x < best.x)))) {
        best = candidate;
        bestDistance = distance;
      }
    }
  }
  return best;
}
