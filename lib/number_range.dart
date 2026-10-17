/// Inclusive practice range. Three choices require at least three numbers.
class NumberRange {
  factory NumberRange(int min, int max) {
    if (min < 0 || max > 100 || max - min < 2) {
      throw ArgumentError('Choose at least three numbers between 0 and 100.');
    }
    return NumberRange._(min, max);
  }
  const NumberRange._(this.min, this.max);
  static const defaults = NumberRange._(0, 10);
  static const countingMaximum = 20;
  final int min;
  final int max;
  int get count => max - min + 1;
  String get label => '$min–$max';

  factory NumberRange.fromMap(Map<dynamic, dynamic>? values) {
    final min = values?['min'];
    final max = values?['max'];
    if (min is! int || max is! int) return defaults;
    try {
      return NumberRange(min, max);
    } on ArgumentError {
      return defaults;
    }
  }
  Map<String, int> toMap() => {'min': min, 'max': max};
  @override
  bool operator ==(Object other) =>
      other is NumberRange && min == other.min && max == other.max;
  @override
  int get hashCode => Object.hash(min, max);
}
