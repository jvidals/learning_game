import 'dart:math';
import 'game.dart';

enum NumberRepresentation {
  numeral,
  tenFrame,
  picture;

  String get label => switch (this) {
    numeral => 'Numeral',
    tenFrame => 'Ten frame',
    picture => 'Picture',
  };

  String describe(int quantity, NumberShape shape) => switch (this) {
    numeral => 'Number $quantity',
    tenFrame => 'Ten frame showing $quantity',
    picture => '$quantity ${quantity == 1 ? shape.singular : shape.plural}',
  };
}

enum NumberShape {
  circle,
  triangle,
  square;

  String get singular => name;
  String get plural => '${name}s';
}

class SameNumberVisual extends QuestionVisual {
  const SameNumberVisual({
    required this.quantity,
    this.missingKind = NumberRepresentation.tenFrame,
    this.shape = NumberShape.circle,
    this.seed = 0,
  });
  final int quantity;
  final NumberRepresentation missingKind;
  final NumberShape shape;

  /// Keeps the scattered picture unchanged across hints, retries and resizing.
  final int seed;

  @override
  bool get fullWidthChoices => true;

  @override
  String choiceLabel(String choice) =>
      missingKind.describe(int.parse(choice), shape);
}

class NumberPartsVisual extends QuestionVisual {
  const NumberPartsVisual({
    required this.total,
    required this.part,
    this.makeTen = false,
  });
  final int total, part;
  final bool makeTen;
  int get missing => total - part;

  @override
  bool get fullWidthChoices => false;

  @override
  String choiceLabel(String choice) => choice == '0'
      ? 'no dots'
      : '$choice ${choice == '1' ? 'circle' : 'circles'}';
}

/// Two nearby foils, including both neighbours at the ends of the range.
/// Same number reserves zero for occasional deliberate zero questions.
List<String> _choices(
  Random rng,
  int answer,
  int slot, {
  bool avoidZero = false,
}) {
  final foils = [
    for (var n = max(0, answer - 2); n <= min(10, answer + 2); n++)
      if (n != answer && (!avoidZero || n != 0)) n,
  ]..shuffle(rng);
  final choices = foils.take(2).map((n) => '$n').toList()
    ..insert(slot, '$answer');
  return List.unmodifiable(choices);
}

List<Question> buildSameNumberQuestions(Random rng, List<int> answerSlots) {
  final quantities = List.generate(10, (i) => i + 1)..shuffle(rng);
  if (rng.nextInt(5) == 0) quantities[rng.nextInt(GameRound.length)] = 0;
  final kinds = [...NumberRepresentation.values]..shuffle(rng);
  return List.generate(GameRound.length, (i) {
    final quantity = quantities[i];
    final visual = SameNumberVisual(
      quantity: quantity,
      missingKind: kinds[i % kinds.length],
      shape: NumberShape.values[rng.nextInt(NumberShape.values.length)],
      seed: rng.nextInt(1 << 30),
    );
    return Question(
      answer: '$quantity',
      choices: _choices(
        rng,
        quantity,
        answerSlots[i],
        avoidZero: quantity != 0,
      ),
      audio: '',
      instruction: 'Find the same number.',
      visual: visual,
    );
  });
}

List<Question> buildNumberPartsQuestions(Random rng, List<int> answerSlots) {
  final largerWholes = [6, 7, 8, 9, 10]..shuffle(rng);
  // Begin with making five; use a zero part occasionally, at most once.
  final zeroQuestion = rng.nextInt(5) == 0 ? rng.nextInt(GameRound.length) : -1;
  var firstPart = -1;
  return List.generate(GameRound.length, (i) {
    final total = i < 2
        ? 5
        : i == 4
        ? 10
        : largerWholes[i - 2];
    final parts = [
      for (var part = 1; part < total; part++)
        if (i != 1 || part != firstPart && part != total - firstPart) part,
    ];
    final part = i == zeroQuestion
        ? (rng.nextBool() ? 0 : total)
        : parts[rng.nextInt(parts.length)];
    if (i == 0) firstPart = part;
    final visual = NumberPartsVisual(total: total, part: part, makeTen: i == 4);
    return Question(
      answer: '${visual.missing}',
      choices: _choices(rng, visual.missing, answerSlots[i]),
      audio: '',
      instruction: visual.makeTen ? 'Make 10.' : 'Find the missing part.',
      visual: visual,
    );
  });
}
