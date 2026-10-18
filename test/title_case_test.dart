import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/game.dart';

const _minorWords = {
  'a',
  'an',
  'and',
  'the',
  'of',
  'in',
  'on',
  'to',
  'for',
  'or',
};

bool _isTitleCase(String title) {
  final words = title
      .split(RegExp(r'[\s-]+'))
      .map((word) => word.replaceAll(RegExp('[^A-Za-z]'), ''))
      .where((word) => word.isNotEmpty)
      .toList();
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    final lower = word.toLowerCase();
    final expected = i > 0 && _minorWords.contains(lower)
        ? lower
        : '${lower[0].toUpperCase()}${lower.substring(1)}';
    if (word != expected) return false;
  }
  return true;
}

void main() {
  for (final activity in Activity.values) {
    test('${activity.name} has a Title Case title', () {
      expect(_isTitleCase(activity.title), isTrue, reason: activity.title);
    });
  }

  for (final category in GameCategory.values) {
    test('${category.name} has a Title Case category title', () {
      expect(_isTitleCase(category.title), isTrue, reason: category.title);
    });
  }

  test('activity titles preserve minor words, hyphens and punctuation', () {
    expect(Activity.readAndFind.title, 'Read and Find');
    expect(Activity.makeBelieve.title, 'Make-Believe Words');
    expect(Activity.sketchPad.title, 'Sketch Pad');
    expect(Activity.howMany.title, 'How Many?');
  });

  test('Title Case rule handles minor words and non-letter tokens', () {
    expect(_isTitleCase('The Group of 2048 Stars!'), isTrue);
    expect(_isTitleCase('Make-Believe Words'), isTrue);
    expect(_isTitleCase('2048'), isTrue);
    expect(_isTitleCase('Read and Find'), isTrue);
    expect(_isTitleCase('a Group'), isFalse);
    expect(_isTitleCase('Read And Find'), isFalse);
    expect(_isTitleCase('Make-believe Words'), isFalse);
    expect(_isTitleCase('How many?'), isFalse);
  });
}
