import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/handwriting.dart';
import 'package:rainbow_garden/writing.dart';
import 'fixtures/handwriting_samples.dart';
import 'fixtures/handwriting_screenshots.dart';
import 'widget_test.dart' show MemoryDevice;
import 'progress_test.dart' show SlowDevice;

void main() {
  test('recognizable screenshot Q, j, h and u pass', () {
    for (final entry in screenshotWriting.entries) {
      final result = evaluateWriting(letterTemplates[entry.key]!, entry.value);
      expect(result.accepted, isTrue, reason: '${entry.key}: ${result.reason}');
    }
  });
  test('natural widths and modest slant retain recognizable letters', () {
    for (final entry in writingSamples.entries) {
      for (final width in [.7, 1.4]) {
        final ink = entry.value
            .map(
              (s) =>
                  s.map((p) => InkPoint(.5 + (p.x - .5) * width, p.y)).toList(),
            )
            .toList();
        final result = evaluateWriting(letterTemplates[entry.key]!, ink);
        expect(
          result.accepted,
          isTrue,
          reason: '${entry.key} width $width: ${result.reason}',
        );
      }
      for (final slant in [-.06, .06]) {
        final ink = entry.value
            .map((s) => s.map((p) => InkPoint(p.x + slant * p.y, p.y)).toList())
            .toList();
        final result = evaluateWriting(letterTemplates[entry.key]!, ink);
        expect(
          result.accepted,
          isTrue,
          reason: '${entry.key} slant $slant: ${result.reason}',
        );
      }
    }
  });
  test(
    'lowercase-first saves and retries award the pair exactly once',
    () async {
      final device = SlowDevice();
      var controller = ProgressController(device);
      await controller.load();
      await controller.startWriting();
      final cycle = controller.progress!.writing!;
      await controller.completeWritingForm(cycle.id, 0, true);
      expect(controller.progress!.xp, 0);
      expect(controller.progress!.writing!.currentForms, 2);
      controller.dispose();
      controller = ProgressController(device);
      await controller.load();
      expect(controller.progress!.writing!.currentForms, 2);
      device.commitThenFail = true;
      await expectLater(
        controller.completeWritingForm(cycle.id, 0, false),
        throwsStateError,
      );
      expect(controller.progress!.xp, 0);
      expect(controller.blocked.value, isTrue);
      device.commitThenFail = false;
      await controller.retry();
      expect(controller.progress!.xp, 10);
      await controller.completeWritingForm(cycle.id, 0, false);
      await controller.completeWritingForm(cycle.id, 0, true);
      expect(controller.progress!.xp, 10);
      controller.dispose();
    },
  );
  for (final entry in writingSamples.entries) {
    test(
      '${entry.key}: independent writing passes, including reversed stroke order',
      () {
        final target = letterTemplates[entry.key]!;
        expect(
          evaluateWriting(target, entry.value).accepted,
          isTrue,
          reason: entry.key,
        );
        final reversed = entry.value.reversed
            .map((s) => s.reversed.toList())
            .toList();
        expect(evaluateWriting(target, reversed).accepted, isTrue);
        final moved = entry.value
            .map((s) => s.map((p) => InkPoint(p.x + .45, p.y)).toList())
            .toList();
        expect(evaluateWriting(target, moved).accepted, isTrue);
      },
    );
  }
  test(
    'independent samples are not mistaken for other letters of the same case',
    () {
      final mistakes = <String>[];
      for (final target in letterTemplates.values) {
        for (final sample in writingSamples.entries) {
          if (sample.key == target.character ||
              (sample.key == sample.key.toUpperCase()) !=
                  (target.character == target.character.toUpperCase()))
            continue;
          if (evaluateWriting(target, sample.value).accepted)
            mistakes.add('${sample.key} accepted as ${target.character}');
        }
      }
      expect(mistakes, isEmpty);
    },
  );

  test(
    'profiles isolate partial writing; completing all pairs earns exactly 260 XP',
    () async {
      final device = MemoryDevice();
      final controller = ProgressController(device);
      await controller.load();
      final firstId = controller.activeProfile!.id;
      await controller.startWriting();
      final first = controller.progress!.writing!;
      await controller.completeWritingForm(first.id, 0, false);
      await controller.addProfile('Second');
      expect(controller.progress!.writing, isNull);
      await controller.startWriting();
      final second = controller.progress!.writing!;
      for (var i = 0; i < 26; i++) {
        await controller.completeWritingForm(second.id, i, false);
        await controller.completeWritingForm(second.id, i, true);
        await controller.advanceWriting(second.id, i);
      }
      expect(controller.progress!.xp, 260);
      expect(controller.progress!.level, 4);
      expect(controller.progress!.writing!.finished, isTrue);
      await controller.reset();
      expect(controller.progress!.writing, isNull);
      await controller.selectProfile(firstId);
      expect(controller.progress!.xp, 0);
      expect(controller.progress!.writing!.id, first.id);
      expect(controller.progress!.writing!.currentForms, 1);
      controller.dispose();
    },
  );

  test(
    'all 52 forms reject miniature, giant, displaced and scribbled attempts',
    () {
      expect(letterTemplates.length, 52);
      for (final entry in writingSamples.entries) {
        final template = letterTemplates[entry.key]!;
        for (final scale in [.3, 1.8]) {
          final ink = entry.value
              .map((s) => s.map((p) => InkPoint(p.x, p.y * scale)).toList())
              .toList();
          expect(
            evaluateWriting(template, ink).accepted,
            isFalse,
            reason: '${entry.key} scale $scale',
          );
        }
        final shifted = entry.value
            .map((s) => s.map((p) => InkPoint(p.x, p.y + .4)).toList())
            .toList();
        expect(evaluateWriting(template, shifted).accepted, isFalse);
        expect(
          evaluateWriting(template, [
            ...entry.value,
            ...entry.value,
            ...entry.value,
          ]).accepted,
          isFalse,
        );
      }
    },
  );
  test('missing dots, bars, tails and different letters do not pass', () {
    for (final letter in ['i', 'j']) {
      expect(
        evaluateWriting(letterTemplates[letter]!, [
          writingSamples[letter]!.first,
        ]).accepted,
        isFalse,
      );
    }
    for (final pair in [
      ('A', 'V'),
      ('Q', 'O'),
      ('R', 'P'),
      ('G', 'C'),
      ('d', 'a'),
      ('p', 'b'),
      ('q', 'g'),
      ('o', 'c'),
      ('n', 'h'),
      ('b', 'd'),
      ('u', 'v'),
    ]) {
      expect(
        evaluateWriting(
          letterTemplates[pair.$1]!,
          writingSamples[pair.$2]!,
        ).accepted,
        isFalse,
        reason: '${pair.$1} vs ${pair.$2}',
      );
    }
    expect(
      evaluateWriting(
        letterTemplates['A']!,
        writingSamples['A']!.take(2).toList(),
      ).accepted,
      isFalse,
    );
    expect(
      evaluateWriting(letterTemplates['t']!, [
        writingSamples['t']!.first,
      ]).accepted,
      isFalse,
    );
    expect(evaluateWriting(letterTemplates['a']!, []).accepted, isFalse);
    expect(
      evaluateWriting(letterTemplates['a']!, [
        [const InkPoint(.5, .5)],
      ]).accepted,
      isFalse,
    );
  });
  test('asymmetric mirrored letters and excess marks fail', () {
    for (final letter in [
      'B',
      'D',
      'E',
      'F',
      'G',
      'J',
      'K',
      'L',
      'P',
      'R',
      'a',
      'b',
      'd',
      'e',
      'f',
      'g',
      'j',
      'k',
      'p',
      'q',
      'r',
    ]) {
      final ink = writingSamples[letter]!
          .map((s) => s.map((p) => InkPoint(1 - p.x, p.y)).toList())
          .toList();
      expect(
        evaluateWriting(letterTemplates[letter]!, ink).accepted,
        isFalse,
        reason: letter,
      );
    }
    expect(
      evaluateWriting(letterTemplates['l']!, [
        ...writingSamples['l']!,
        [const InkPoint(.1, .5), const InkPoint(.9, .5)],
      ]).accepted,
      isFalse,
    );
  });
  test(
    'each shuffle covers 26 letters, varies order and avoids boundary repeat',
    () {
      final orders = <String>{};
      for (var seed = 0; seed < 300; seed++) {
        final p = WritingProgress.start(
          'cycle-$seed',
          Random(seed),
          previous: 5,
        );
        expect(p.order.toSet(), Set.from(List.generate(26, (i) => i)));
        expect(p.order.first, isNot(5));
        orders.add(p.order.join(','));
      }
      expect(orders.length, greaterThan(290));
    },
  );
  test('partial forms, skipping and summary survive serialization', () {
    var p = WritingProgress.start('cycle', Random(8));
    final lowerFirst = WritingProgress.fromJson(p.complete(true).toJson());
    expect(lowerFirst.currentForms, 2);
    expect(lowerFirst.complete(false).pairComplete, isTrue);
    expect(
      WritingProgress.fromJson({...p.toJson(), 'version': 1}).currentForms,
      0,
    );
    p = p.complete(false);
    expect(p.currentForms, 1);
    p = WritingProgress.fromJson(p.toJson());
    expect(p.currentForms, 1);
    p = p.advance().complete(false).complete(true);
    expect(p.completedPairs, 1);
    while (!p.finished) {
      p = p.advance();
    }
    expect(p.index, 26);
    expect(p.completedPairs, 1);
  });
  test(
    'invalid saved Writing is rejected, absent old fields initialize safely',
    () {
      final p = WritingProgress.start('cycle', Random(0));
      for (final bad in [
        {...p.toJson(), 'order': List.filled(26, 0)},
        {...p.toJson(), 'index': 27},
        {
          ...p.toJson(),
          'forms': [4, ...List.filled(25, 0)],
        },
        {
          ...p.toJson(),
          'forms': [0, 1, ...List.filled(24, 0)],
        },
        {...p.toJson(), 'version': 9},
      ]) {
        final json =
            jsonDecode(PlayerProgress().encode()) as Map<String, dynamic>;
        json['writing'] = bad;
        expect(
          () => PlayerProgress.decode(jsonEncode(json)),
          throwsFormatException,
        );
      }
      expect(PlayerProgress.decode(PlayerProgress().encode()).writing, isNull);
      expect(
        PlayerProgress.decode(
          PlayerProgress(xp: 10, lastRewardedRound: 'writing').encode(),
        ).xp,
        10,
      );
    },
  );
  test(
    'only both forms earn XP, stale callbacks and repeated checks cannot duplicate',
    () async {
      final device = MemoryDevice();
      final controller = ProgressController(device);
      await controller.load();
      await controller.startWriting(random: Random(2));
      final p = controller.progress!.writing!;
      await controller.completeWritingForm(p.id, p.index, false);
      expect(controller.progress!.xp, 0);
      final reopened = ProgressController(device);
      await reopened.load();
      expect(reopened.progress!.writing!.currentForms, 1);
      await reopened.completeWritingForm(p.id, p.index, true);
      await reopened.completeWritingForm(p.id, p.index, true);
      expect(reopened.progress!.xp, 10);
      await reopened.advanceWriting(p.id, p.index);
      await reopened.completeWritingForm(p.id, p.index, true);
      expect(reopened.progress!.xp, 10);
      expect(reopened.progress!.writing!.index, 1);
      await reopened.reset();
      expect(reopened.progress!.writing, isNull);
      expect(reopened.progress!.xp, 0);
    },
  );
  test(
    'failed pair commit is retained, blocks switches and retries exact XP once',
    () async {
      final device = SlowDevice();
      final controller = ProgressController(device);
      await controller.load();
      await controller.startWriting();
      final p = controller.progress!.writing!;
      await controller.completeWritingForm(p.id, p.index, false);
      device.commitThenFail = true;
      await expectLater(
        controller.completeWritingForm(p.id, p.index, true),
        throwsStateError,
      );
      expect(controller.progress!.xp, 0);
      expect(device.xp, 10);
      await expectLater(controller.addProfile('Second'), throwsStateError);
      device.commitThenFail = false;
      await controller.retry();
      await controller.completeWritingForm(p.id, p.index, true);
      expect(controller.progress!.xp, 10);
      final restored = ProgressController(device);
      await restored.load();
      expect(restored.progress!.writing!.pairComplete, isTrue);
      expect(restored.progress!.xp, 10);
    },
  );
}
