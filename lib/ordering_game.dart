import 'dart:math';
import 'game.dart';
import 'number_range.dart';

/// A permutation of unique values. Correct positions cannot be disturbed.
class OrderingRound {
  OrderingRound(
    this.activity, {
    NumberRange numberRange = NumberRange.defaults,
    Random? random,
  }) {
    if (!activity.isOrdering) {
      throw ArgumentError('Expected an ordering activity');
    }
    targets = List.unmodifiable(
      List.generate(
        activity == Activity.alphabetOrder ? 26 : numberRange.count,
        (i) => activity == Activity.alphabetOrder ? i : numberRange.min + i,
      ),
    );
    _cards = [...targets]..shuffle(random ?? Random());
    // Repair fixed points without unbounded shuffle retries.
    final fixed = [
      for (var i = 0; i < targets.length; i++)
        if (_cards[i] == targets[i]) i,
    ];
    if (fixed.length == 1) {
      final a = fixed.single, b = (a + 1) % targets.length;
      final value = _cards[a];
      _cards[a] = _cards[b];
      _cards[b] = value;
    } else if (fixed.isNotEmpty) {
      final first = _cards[fixed.first];
      for (var i = 0; i < fixed.length - 1; i++) {
        _cards[fixed[i]] = _cards[fixed[i + 1]];
      }
      _cards[fixed.last] = first;
    }
  }
  final Activity activity;
  late final List<int> targets;
  late final List<int> _cards;
  List<int> get cards => List.unmodifiable(_cards);
  int get length => _cards.length;
  bool correct(int slot) => _cards[slot] == targets[slot];
  int get completed => [
    for (var i = 0; i < length; i++)
      if (correct(i)) i,
  ].length;
  bool get finished => completed == length;
  String label(int value, {bool lowercase = false}) =>
      activity == Activity.alphabetOrder
      ? String.fromCharCode((lowercase ? 97 : 65) + value)
      : '$value';

  /// Null means ignored; an empty set is a valid swap with no new correct cards.
  Set<int>? swap(int a, int b) {
    if (a < 0 ||
        b < 0 ||
        a >= length ||
        b >= length ||
        a == b ||
        correct(a) ||
        correct(b)) {
      return null;
    }
    final value = _cards[a];
    _cards[a] = _cards[b];
    _cards[b] = value;
    return {if (correct(a)) _cards[a], if (correct(b)) _cards[b]};
  }
}
