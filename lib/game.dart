import 'dart:math';
import 'number_range.dart';
import 'sight_words.dart';
import 'letter_sounds.dart';
import 'counting.dart';
import 'decoding.dart';
import 'number_sense.dart';

enum GameCategory { letters, numbers, words, writing, reflex }

extension GameCategoryContent on GameCategory {
  String get title => switch (this) {
    GameCategory.letters => 'Letters',
    GameCategory.numbers => 'Numbers',
    GameCategory.words => 'Words',
    GameCategory.writing => 'Writing',
    GameCategory.reflex => 'Reflex',
  };
  String get example => switch (this) {
    GameCategory.letters => 'Aa',
    GameCategory.numbers => '123',
    GameCategory.words => 'the',
    GameCategory.writing => 'Aa',
    GameCategory.reflex => '',
  };
  int get colorIndex => switch (this) {
    GameCategory.letters => 5,
    GameCategory.numbers => 1,
    GameCategory.words => 2,
    GameCategory.writing => 4,
    GameCategory.reflex => 0,
  };
  List<Activity> get activities => Activity.values
      .where((activity) => activity.category == this)
      .toList(growable: false);
}

enum Activity {
  uppercase,
  lowercase,
  matching,
  numbers,
  alphabetOrder,
  numberOrder,
  game2048,
  sightWords,
  handwriting,
  tapChallenge,
  letterSounds,
  howMany,
  makeGroup,
  readAndFind,
  makeBelieve,
  wordSprint,
  sameNumber,
  numberParts,
  cursive,
}

extension ActivityContent on Activity {
  bool get isVisualChoice =>
      this == Activity.readAndFind ||
      this == Activity.makeBelieve ||
      this == Activity.sameNumber ||
      this == Activity.numberParts;
  bool get isCounting => this == Activity.howMany || this == Activity.makeGroup;
  bool get hasSpokenTarget => isRecognition && !isCounting;
  bool get isOrdering =>
      this == Activity.alphabetOrder || this == Activity.numberOrder;
  bool get isRecognition =>
      !isVisualChoice &&
      this != Activity.wordSprint &&
      this != Activity.cursive &&
      !isOrdering &&
      this != Activity.game2048 &&
      this != Activity.handwriting &&
      this != Activity.tapChallenge &&
      this != Activity.makeGroup;
  static List<Activity> get recognition =>
      Activity.values.where((a) => a.isRecognition).toList();
  int get colorIndex => switch (this) {
    Activity.uppercase => 5,
    Activity.lowercase => 0,
    Activity.matching => 3,
    Activity.numbers => 1,
    Activity.alphabetOrder => 4,
    Activity.numberOrder => 2,
    Activity.game2048 => 3,
    Activity.sightWords => 2,
    Activity.handwriting => 4,
    Activity.tapChallenge => 0,
    Activity.letterSounds => 5,
    Activity.howMany => 1,
    Activity.makeGroup => 2,
    Activity.readAndFind => 0,
    Activity.makeBelieve => 4,
    Activity.wordSprint => 2,
    Activity.sameNumber => 1,
    Activity.numberParts => 3,
    Activity.cursive => 5,
  };
  GameCategory get category => this == Activity.tapChallenge
      ? GameCategory.reflex
      : this == Activity.handwriting || this == Activity.cursive
      ? GameCategory.writing
      : this == Activity.sightWords ||
            this == Activity.readAndFind ||
            this == Activity.makeBelieve ||
            this == Activity.wordSprint
      ? GameCategory.words
      : isCounting ||
            this == Activity.sameNumber ||
            this == Activity.numberParts ||
            this == Activity.numbers ||
            this == Activity.numberOrder ||
            this == Activity.game2048
      ? GameCategory.numbers
      : GameCategory.letters;
  String get title => switch (this) {
    Activity.uppercase => 'Uppercase letters',
    Activity.lowercase => 'Lowercase letters',
    Activity.matching => 'Letter friends',
    Activity.numbers => 'Number hunt',
    Activity.alphabetOrder => 'Alphabet Order',
    Activity.numberOrder => 'Number Order',
    Activity.game2048 => '2048',
    Activity.sightWords => 'Sight Words',
    Activity.handwriting => 'Handwriting',
    Activity.tapChallenge => 'Tap Challenge',
    Activity.letterSounds => 'Letter Sounds',
    Activity.howMany => 'How many?',
    Activity.makeGroup => 'Make a group',
    Activity.readAndFind => 'Read and find',
    Activity.makeBelieve => 'Make-believe words',
    Activity.wordSprint => 'Word Sprint',
    Activity.sameNumber => 'Same number',
    Activity.numberParts => 'Number parts',
    Activity.cursive => 'Cursive play',
  };
  String get example => switch (this) {
    Activity.uppercase => 'ABC',
    Activity.lowercase => 'abc',
    Activity.matching => 'Aa',
    Activity.numbers => '123',
    Activity.alphabetOrder => 'ABC',
    Activity.numberOrder => '123',
    Activity.game2048 => '2048',
    Activity.sightWords => 'the',
    Activity.handwriting => 'Aa',
    Activity.tapChallenge => '',
    Activity.letterSounds => 'm',
    Activity.howMany => '123',
    Activity.makeGroup => '5',
    Activity.readAndFind => 'cat',
    Activity.makeBelieve => 'pib',
    Activity.wordSprint => 'pos',
    Activity.sameNumber => '5',
    Activity.numberParts => '2+3',
    Activity.cursive => 'ce',
  };
  String get subtitle => switch (this) {
    Activity.uppercase => 'Find uppercase letters',
    Activity.lowercase => 'Find lowercase letters',
    Activity.matching => 'Match uppercase and lowercase letters',
    Activity.numbers => 'Discover numbers 0–10',
    Activity.alphabetOrder => 'Put the ABCs in order',
    Activity.numberOrder => 'Put the numbers in order',
    Activity.game2048 => 'Merge matching numbers',
    Activity.sightWords => 'Find the spoken word',
    Activity.handwriting => 'Trace, then write both letters',
    Activity.tapChallenge => 'Quick taps, new bests',
    Activity.letterSounds => 'Match a sound to its letter',
    Activity.howMany => 'Count the objects',
    Activity.makeGroup => 'Build a matching collection',
    Activity.readAndFind => 'Read the word, find its picture',
    Activity.makeBelieve => 'Read a pretend word, pick its sound',
    Activity.wordSprint => 'Read as many words as you can',
    Activity.sameNumber => 'Match numbers, ten frames and pictures',
    Activity.numberParts => 'Find the missing part',
    Activity.cursive => 'Trace and write cursive letters',
  };
}

/// Optional per-question payload for activities with custom visuals.
abstract class QuestionVisual {
  const QuestionVisual();

  /// Choices are selected first (optionally playing [choiceClip]) and
  /// submitted with a Check button instead of answering on tap.
  bool get selectThenCheck => false;

  /// Bundled clip played when a choice is selected, if any.
  String? choiceClip(String choice) => null;

  /// Accessible label for a choice card.
  String choiceLabel(String choice) => choice;

  /// Stack choice cards full width instead of three per row.
  bool get fullWidthChoices => false;
}

class Question {
  const Question({
    required this.answer,
    required this.choices,
    required this.audio,
    required this.instruction,
    this.partner,
    this.counting,
    this.visual,
  });
  final String answer;
  final List<String> choices;
  final String audio;
  final String instruction;
  final String? partner;
  final CountingScene? counting;
  final QuestionVisual? visual;
}

enum AnswerResult { correct, retry, ignored }

/// One short round. No UI or platform dependencies.
class GameRound {
  GameRound(
    this.activity, {
    Random? random,
    NumberRange numberRange = NumberRange.defaults,
    SightWordPacks wordPacks = SightWordPacks.defaults,
    SoundSelection sounds = SoundSelection.defaults,
    int countingMax = 10,
    NumberRange? countingRange,
  }) {
    if (!activity.isRecognition &&
        !activity.isCounting &&
        !activity.isVisualChoice) {
      throw ArgumentError('Use the activity’s own game engine');
    }
    final rng = random ?? Random();
    if (activity.isVisualChoice) {
      final repeatedSlots = [0, 1, 2]..shuffle(rng);
      final answerSlots = [0, 1, 2, ...repeatedSlots.take(2)]..shuffle(rng);
      questions = List.unmodifiable(switch (activity) {
        Activity.readAndFind => buildReadAndFindQuestions(rng, answerSlots),
        Activity.makeBelieve => buildMakeBelieveQuestions(rng, answerSlots),
        Activity.sameNumber => buildSameNumberQuestions(rng, answerSlots),
        Activity.numberParts => buildNumberPartsQuestions(rng, answerSlots),
        _ => throw StateError('Unknown visual activity'),
      });
      return;
    }
    final quantities = countingRange ?? NumberRange(0, countingMax);
    if (activity.isCounting && quantities.max > NumberRange.countingMaximum) {
      throw ArgumentError('Counting supports at most 20 objects.');
    }
    final pool = activity == Activity.letterSounds
        ? sounds.letters
        : activity.isCounting
        ? List.generate(quantities.count, (i) => '${quantities.min + i}')
        : activity == Activity.sightWords
        ? wordPacks.words
        : activity == Activity.numbers
        ? List.generate(numberRange.count, (i) => '${numberRange.min + i}')
        : List.generate(26, (i) => String.fromCharCode(65 + i));
    final targets = <String>[];
    while (targets.length < length) {
      final cycle = [...pool]..shuffle(rng);
      if (targets.isNotEmpty && cycle.first == targets.last) {
        final first = cycle.removeAt(0);
        cycle.add(first);
      }
      targets.addAll(cycle.take(length - targets.length));
    }
    // Every round uses each slot once or twice; randomly choose the singleton.
    final repeatedSlots = [0, 1, 2]..shuffle(rng);
    final answerSlots = [0, 1, 2, ...repeatedSlots.take(2)]..shuffle(rng);
    final firstIsLower = rng.nextBool();
    questions = List.unmodifiable(
      List.generate(length, (index) {
        final target = targets[index];
        final lower =
            activity == Activity.lowercase ||
            (activity == Activity.matching && (index.isEven == firstIsLower));
        String display(String value) => lower ? value.toLowerCase() : value;
        final distractors =
            pool
                .where(
                  (value) =>
                      value != target &&
                      (activity != Activity.letterSounds ||
                          soundFor(value).phoneme != soundFor(target).phoneme),
                )
                .toList()
              ..shuffle(rng);
        if (activity == Activity.numbers) {
          final number = int.parse(target);
          // The shuffled order chooses uniformly within the first available
          // category. Draw the second choice independently from the remainder.
          final categories = <List<int>>[
            if (target.length == 2 &&
                !target.contains('0') &&
                target[0] != target[1])
              [int.parse('${target[1]}${target[0]}')],
            [
              for (var digit = 0; digit < target.length; digit++)
                if (target[digit] == '6' || target[digit] == '9')
                  int.parse(
                    target.replaceRange(
                      digit,
                      digit + 1,
                      target[digit] == '6' ? '9' : '6',
                    ),
                  ),
            ],
            [
              if (number >= 13 && number <= 19) (number - 10) * 10,
              if (number >= 30 && number <= 90 && number % 10 == 0)
                10 + number ~/ 10,
            ],
            [number - 10, number + 10],
            [number - 1, number + 1],
          ];
          for (final category in categories) {
            final preferred = distractors.indexWhere(
              (value) => category.contains(int.parse(value)),
            );
            if (preferred == -1) continue;
            distractors.insert(0, distractors.removeAt(preferred));
            final second = 1 + rng.nextInt(distractors.length - 1);
            distractors.insert(1, distractors.removeAt(second));
            break;
          }
        }
        final distinctSounds = <String>{};
        final eligible = activity == Activity.letterSounds
            ? distractors.where(
                (letter) => distinctSounds.add(soundFor(letter).phoneme),
              )
            : distractors;
        final choices = eligible.take(2).map(display).toList()
          ..insert(answerSlots[index], display(target));
        final matching = activity == Activity.matching;
        return Question(
          answer: display(target),
          choices: List.unmodifiable(choices),
          counting: activity.isCounting
              ? CountingScene(int.parse(target), rng)
              : null,
          partner: matching ? (lower ? target : target.toLowerCase()) : null,
          instruction: activity == Activity.howMany
              ? 'How many?'
              : activity == Activity.makeGroup
              ? 'Make a group'
              : matching
              ? 'Find its letter friend!'
              : 'Listen, then tap!',
          audio: activity.isCounting
              ? ''
              : activity == Activity.letterSounds
              ? soundFor(target).audio
              : matching
              ? (lower ? 'match_lower' : 'match_upper')
              : activity == Activity.sightWords
              ? 'word_${target.toLowerCase()}'
              : activity == Activity.numbers
              ? 'number_$target'
              : '${lower ? 'lower' : 'upper'}_${target.toLowerCase()}',
        );
      }),
    );
  }

  static const length = 5;
  final Activity activity;
  late final List<Question> questions;
  int _index = 0;
  bool _answered = false;
  int get completed => _index + (_answered ? 1 : 0);
  bool get answered => _answered;
  bool get finished => completed == length;
  Question get question => questions[_index];

  AnswerResult choose(String choice) {
    if (_answered ||
        (activity == Activity.makeGroup
            ? int.tryParse(choice) == null || int.parse(choice) < 0
            : !question.choices.contains(choice)))
      return AnswerResult.ignored;
    if (choice != question.answer) return AnswerResult.retry;
    _answered = true;
    return AnswerResult.correct;
  }

  bool next() {
    if (!_answered || finished) return false;
    _index++;
    _answered = false;
    return true;
  }
}
