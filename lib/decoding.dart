import 'dart:math';

import 'game.dart';
import 'word_bank.dart';

class ReadAndFindVisual extends QuestionVisual {
  const ReadAndFindVisual({required this.word});
  final DecodableWord word;

  @override
  String choiceLabel(String choice) => realWord(choice).label ?? choice;
}

class MakeBelieveVisual extends QuestionVisual {
  const MakeBelieveVisual({required this.word, this.choices = const []});
  final DecodableWord word;

  /// The spoken options' display order; labels never expose their spellings.
  final List<String> choices;

  @override
  bool get selectThenCheck => true;
  @override
  String? choiceClip(String choice) => makeBelieveWord(choice).clip;
  @override
  String choiceLabel(String choice) {
    final index = choices.indexOf(choice);
    return index < 0 ? 'Sound option' : 'Sound ${index + 1}';
  }

  @override
  bool get fullWidthChoices => true;
}

List<int> _sharedPositions(DecodableWord target, DecodableWord candidate) => [
  for (var i = 0; i < target.spelling.length; i++)
    if (target.spelling[i] == candidate.spelling[i]) i,
];

List<Question> buildReadAndFindQuestions(Random rng, List<int> answerSlots) {
  final remaining = [...realWords]..shuffle(rng);
  final positionUse = [0, 0, 0];
  String? previousVowel;
  return List.generate(GameRound.length, (i) {
    final index = remaining.indexWhere((w) => w.vowel != previousVowel);
    final word = remaining.removeAt(index < 0 ? 0 : index);
    previousVowel = word.vowel;
    final candidates = realWords
        .where((w) => w.picture != word.picture)
        .toList();
    final foils = <DecodableWord>[];
    for (var foil = 0; foil < 2; foil++) {
      // Prefer overlapping letters so a single cue cannot reliably identify the
      // picture. Track positions across both foils and the round to vary cues.
      final overlapping = candidates
          .where((w) => _sharedPositions(word, w).isNotEmpty)
          .toList();
      final pool = overlapping.isEmpty ? candidates.toList() : overlapping;
      int score(DecodableWord candidate) {
        final positions = _sharedPositions(word, candidate);
        return positions.length * 4 -
            positions.fold(0, (sum, p) => sum + positionUse[p]);
      }

      pool.shuffle(rng);
      var best = pool.first;
      for (final candidate in pool.skip(1)) {
        if (score(candidate) > score(best)) best = candidate;
      }
      foils.add(best);
      candidates.removeWhere((w) => w.picture == best.picture);
      for (final p in _sharedPositions(word, best)) {
        positionUse[p]++;
      }
    }
    foils.shuffle(rng);
    final choices = foils.map((w) => w.spelling).toList()
      ..insert(answerSlots[i], word.spelling);
    return Question(
      answer: word.spelling,
      choices: List.unmodifiable(choices),
      audio: '',
      instruction: 'Read the word. Find its picture.',
      visual: ReadAndFindVisual(word: word),
    );
  });
}

List<Question> buildMakeBelieveQuestions(Random rng, List<int> answerSlots) {
  final items = [...makeBelieveItems]..shuffle(rng);
  return List.generate(GameRound.length, (i) {
    final item = items[i];
    final choices = [...item.foils]..shuffle(rng);
    choices.insert(answerSlots[i], item.target);
    final order = List<String>.unmodifiable(choices);
    return Question(
      answer: item.target,
      choices: order,
      audio: '',
      instruction: 'Read the pretend word. Which sound matches?',
      visual: MakeBelieveVisual(
        word: makeBelieveWord(item.target),
        choices: order,
      ),
    );
  });
}
