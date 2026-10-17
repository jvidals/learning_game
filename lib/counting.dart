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
  int _nextId = 0;
  void toggleMark(int index) {
    if (!marked.add(index)) marked.remove(index);
  }

  bool add() {
    if (items.length >= maximum) return false;
    items.add(_nextId++);
    return true;
  }

  bool remove(int id) => items.remove(id);
}
