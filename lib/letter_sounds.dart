/// Basic sound spellings. c and k intentionally share one phoneme.
class LetterSound {
  const LetterSound(this.letter, this.phoneme, this.word, this.picture);
  final String letter, phoneme, word, picture;
  String get audio => 'sound_$phoneme';
}

const letterSounds = [
  LetterSound('a', 'a', 'apple', '🍎'),
  LetterSound('b', 'b', 'ball', '⚽'),
  LetterSound('c', 'k', 'cat', '🐈'),
  LetterSound('d', 'd', 'dog', '🐕'),
  LetterSound('e', 'e', 'egg', '🥚'),
  LetterSound('f', 'f', 'fish', '🐟'),
  LetterSound('g', 'g', 'goat', '🐐'),
  LetterSound('h', 'h', 'hat', '🎩'),
  LetterSound('i', 'i', 'insect', '🐞'),
  LetterSound('j', 'j', 'jet', '✈️'),
  LetterSound('k', 'k', 'kite', '🪁'),
  LetterSound('l', 'l', 'leaf', '🍃'),
  LetterSound('m', 'm', 'moon', '🌙'),
  LetterSound('n', 'n', 'nose', '👃'),
  LetterSound('o', 'o', 'octopus', '🐙'),
  LetterSound('p', 'p', 'pig', '🐖'),
  LetterSound('r', 'r', 'rabbit', '🐇'),
  LetterSound('s', 's', 'sun', '☀️'),
  LetterSound('t', 't', 'turtle', '🐢'),
  LetterSound('u', 'u', 'umbrella', '☂️'),
  LetterSound('v', 'v', 'van', '🚐'),
  LetterSound('w', 'w', 'web', '🕸️'),
  LetterSound('y', 'y', 'yarn', '🧶'),
  LetterSound('z', 'z', 'zebra', '🦓'),
];

LetterSound soundFor(String letter) =>
    letterSounds.firstWhere((sound) => sound.letter == letter);

class SoundSelection {
  factory SoundSelection(Iterable<String> letters) {
    final ids = Set<String>.unmodifiable(letters);
    if (!isValid(ids)) {
      throw ArgumentError(
        'Choose letters for at least three different sounds.',
      );
    }
    return SoundSelection._(ids);
  }
  const SoundSelection._(this.enabled);
  static const defaults = SoundSelection._({
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'y',
    'z',
  });
  final Set<String> enabled;
  List<String> get letters => [
    for (final sound in letterSounds)
      if (enabled.contains(sound.letter)) sound.letter,
  ];
  static bool isValid(Set<String> letters) =>
      letters.every((id) => letterSounds.any((s) => s.letter == id)) &&
      letterSounds
              .where((s) => letters.contains(s.letter))
              .map((s) => s.phoneme)
              .toSet()
              .length >=
          3;

  factory SoundSelection.fromValue(Object? value) {
    if (value is! List || value.any((id) => id is! String)) {
      throw const FormatException('Invalid letter sounds');
    }
    try {
      return SoundSelection(value.cast<String>());
    } on ArgumentError {
      throw const FormatException('Invalid letter sounds');
    }
  }
}
