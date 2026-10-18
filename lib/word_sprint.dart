import 'dart:math';

import 'word_bank.dart';

enum WordSprintMode {
  realWords('Real words'),
  makeBelieve('Make-believe'),
  mix('Mix');

  const WordSprintMode(this.label);
  final String label;
}

const wordSprintSessionLength = 48;

/// Reading is self-reported. This session owns marks, never time or rewards.
class WordSprintSession {
  WordSprintSession({this.mode = WordSprintMode.mix, Random? random}) {
    final rng = random ?? Random();
    final pretendPool = <String, DecodableWord>{
      for (final item in makeBelieveItems)
        item.target: makeBelieveWord(item.target),
      for (final word in sprintOnlyPretendWords) word.spelling: word,
    };
    final pool = <DecodableWord>[
      if (mode != WordSprintMode.makeBelieve) ...realWords,
      if (mode != WordSprintMode.realWords) ...pretendPool.values,
    ];
    final generated = <DecodableWord>[];
    while (generated.length < wordSprintSessionLength) {
      final cycle = [...pool]..shuffle(rng);
      if (generated.isNotEmpty &&
          generated.last.spelling == cycle.first.spelling) {
        final other = 1 + rng.nextInt(cycle.length - 1);
        final first = cycle.first;
        cycle[0] = cycle[other];
        cycle[other] = first;
      }
      generated.addAll(cycle.take(wordSprintSessionLength - generated.length));
    }
    words = List.unmodifiable(generated);
  }

  final WordSprintMode mode;
  late final List<DecodableWord> words;
  final _marked = <int>{};
  bool _finished = false;
  bool get finished => _finished;
  int get count => _marked.length;
  bool isMarked(int index) => _marked.contains(index);

  void mark(int index) {
    if (_finished) return;
    RangeError.checkValidIndex(index, words);
    if (!_marked.remove(index)) _marked.add(index);
  }

  void finish() => _finished = true;
}
