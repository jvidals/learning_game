import 'dart:math';

/// Artwork belongs to the selected skin, never to the scoring rules.
enum TapTargetKind {
  regular(1),
  bonus(3),
  hazard(-2);

  const TapTargetKind(this.points);
  final int points;
}

class TapTarget {
  const TapTarget(this.id, this.slot, this.kind, this.expires);
  final int id, slot;
  final TapTargetKind kind;
  final Duration expires;
}

/// The UI supplies monotonic active time, stopped while paused.
class TapChallengeRound {
  TapChallengeRound({required this.elapsed, Random? random})
    : _random = random ?? Random() {
    tick();
  }
  static const length = Duration(seconds: 30);
  static const spawnInterval = Duration(milliseconds: 600);
  static const targetLife = Duration(milliseconds: 1800);
  final Duration Function() elapsed;
  final Random _random;
  final _targets = <TapTarget>[];
  final _bag = <TapTargetKind>[];
  var _nextSpawn = Duration.zero;
  var _nextId = 0;
  int score = 0;
  bool finished = false;
  List<TapTarget> get targets => List.unmodifiable(_targets);
  int get secondsLeft =>
      max(0, ((length - elapsed()).inMilliseconds / 1000).ceil());

  void tick() {
    if (finished) return;
    final now = elapsed();
    if (now >= length) {
      finished = true;
      _targets.clear();
      return;
    }
    // Process scheduled instants, not timer callback counts. Frame delays never
    // extend target lifetimes or leave a burst of expired targets on screen.
    while (_nextSpawn <= now) {
      _targets.removeWhere((t) => t.expires <= _nextSpawn);
      if (_bag.isEmpty) {
        _bag.addAll(
          [
            ...List.filled(6, TapTargetKind.regular),
            ...List.filled(2, TapTargetKind.bonus),
            ...List.filled(2, TapTargetKind.hazard),
          ]..shuffle(_random),
        );
      }
      final free = List.generate(9, (i) => i)
        ..removeWhere((slot) => _targets.any((t) => t.slot == slot));
      _targets.add(
        TapTarget(
          ++_nextId,
          free[_random.nextInt(free.length)],
          _bag.removeLast(),
          _nextSpawn + targetLife,
        ),
      );
      _nextSpawn += spawnInterval;
    }
    _targets.removeWhere((t) => t.expires <= now);
  }

  TapTargetKind? tap(int id) {
    tick();
    if (finished) return null;
    final index = _targets.indexWhere((t) => t.id == id);
    if (index < 0) return null;
    final kind = _targets.removeAt(index).kind;
    score = max(0, score + kind.points);
    return kind;
  }
}
