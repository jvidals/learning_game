import 'dart:math';

const writingPairXp = 10;

/// A shuffled alphabet shared by both cases. Bit 1 is uppercase, bit 2 lowercase.
/// Ink is deliberately not part of the saved document.
class WritingProgress {
  WritingProgress({
    required this.id,
    required List<int> order,
    this.index = 0,
    List<int>? forms,
  }) : order = List.unmodifiable(order),
       forms = List.unmodifiable(forms ?? List.filled(26, 0)) {
    if (id.isEmpty ||
        this.order.length != 26 ||
        this.order.toSet().length != 26 ||
        this.order.any((v) => v < 0 || v > 25) ||
        index < 0 ||
        index > 26 ||
        this.forms.length != 26 ||
        this.forms.any((v) => v < 0 || v > 3) ||
        List.generate(
          26,
          (i) => i,
        ).any((i) => i > index && this.forms[i] != 0)) {
      throw const FormatException('Invalid writing progress');
    }
  }

  factory WritingProgress.start(String id, Random random, {int? previous}) {
    final order = List.generate(26, (i) => i)..shuffle(random);
    if (order.first == previous) {
      final swap = 1 + random.nextInt(25);
      final first = order[0];
      order[0] = order[swap];
      order[swap] = first;
    }
    return WritingProgress(id: id, order: order);
  }

  final String id;
  final List<int> order, forms;
  final int index;
  bool get finished => index == 26;
  int get letter => order[min(index, 25)];
  int get currentForms => finished ? 3 : forms[index];
  bool get pairComplete => currentForms == 3;
  int get completedPairs => forms.where((v) => v == 3).length;
  bool completed(bool lowercase) => (currentForms & (lowercase ? 2 : 1)) != 0;

  WritingProgress complete(bool lowercase) {
    if (finished || completed(lowercase)) return this;
    final next = [...forms];
    next[index] |= lowercase ? 2 : 1;
    return WritingProgress(id: id, order: order, index: index, forms: next);
  }

  WritingProgress advance() => finished
      ? this
      : WritingProgress(id: id, order: order, index: index + 1, forms: forms);

  Map<String, Object> toJson() => {
    'version': 2,
    'id': id,
    'order': order,
    'index': index,
    'forms': forms,
  };

  factory WritingProgress.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 && json['version'] != 2)
      throw const FormatException('Unknown writing version');
    if (json['version'] == 1 && (json['forms'] as List).contains(2)) {
      throw const FormatException('Invalid legacy writing progress');
    }
    return WritingProgress(
      id: json['id'] as String,
      order: (json['order'] as List).cast<int>(),
      index: json['index'] as int,
      forms: (json['forms'] as List).cast<int>(),
    );
  }
}
