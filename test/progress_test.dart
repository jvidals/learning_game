import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/number_range.dart';
import 'widget_test.dart' show MemoryDevice;

class SlowDevice extends MemoryDevice {
  Completer<void>? pending;
  bool commitThenFail = false;
  @override
  Future<void> saveProgress(String value) async {
    await pending?.future;
    await super.saveProgress(value);
    if (commitThenFail) throw StateError('Lost acknowledgement');
  }
}

Future<ProgressController> controller(MemoryDevice device) async {
  final c = ProgressController(device);
  await c.load();
  return c;
}

void main() {
  test('XP boundaries and four-round cap are centralized', () {
    expect(List.generate(10, (i) => xpForLevel(i + 1)), [
      0,
      50,
      150,
      250,
      400,
      550,
      700,
      900,
      1100,
      1300,
    ]);
    for (var level = 2; level < 1000; level++) {
      final boundary = xpForLevel(level);
      expect(levelForXp(boundary), level);
      expect(levelForXp(boundary - 1), level - 1);
      if (level >= 8) expect(boundary - xpForLevel(level - 1), 200);
    }
  });
  test(
    'round save is idempotent and survives a lost acknowledgement',
    () async {
      final d = SlowDevice(), c = await controller(d);
      d.commitThenFail = true;
      await expectLater(c.completeRound('one'), throwsStateError);
      expect(c.progress!.xp, 0);
      expect(d.xp, 50);
      expect(c.blocked.value, isTrue);
      await expectLater(c.completeRound('two'), throwsStateError);
      await expectLater(c.reset(), throwsStateError);
      d.commitThenFail = false;
      await c.completeRound('one');
      await c.completeRound('one');
      expect(c.progress!.xp, 50);
      expect(c.progress!.availableChoices, 1);
      final reloaded = await controller(d);
      expect(reloaded.progress!.xp, 50);
    },
  );
  test(
    'delayed writes block mutations and publish only after commit',
    () async {
      final d = SlowDevice(), c = await controller(d);
      d.pending = Completer<void>();
      final save = c.completeRound('round');
      expect(c.writing, isTrue);
      expect(c.progress!.xp, 0);
      await expectLater(
        c.saveSettings(const AppSettings(haptics: false)),
        throwsStateError,
      );
      await expectLater(c.reset(), throwsStateError);
      d.pending!.complete();
      await save;
      expect(c.progress!.xp, 50);
      expect(c.blocked.value, isFalse);
    },
  );
  test(
    'legacy gifts remain flexible and exhaust at their saved entitlement',
    () async {
      final d = MemoryDevice()..xp = xpForLevel(18), c = await controller(d);
      expect(c.progress!.choices.map((r) => r.id), [
        'blue',
        'polish_pink',
        'flower',
      ]);
      await c.choose('flower');
      expect(c.progress!.companion[RewardCategory.accessory], 'flower');
      expect(c.progress!.choices.map((r) => r.id), [
        'blue',
        'polish_pink',
        'lavender',
      ]);
      await expectLater(c.equip(RewardCategory.mane, 'gold'), throwsStateError);
      await expectLater(
        c.equip(RewardCategory.mane, 'flower'),
        throwsStateError,
      );
      while (c.progress!.choices.isNotEmpty) {
        await c.choose(c.progress!.choices.first.id);
      }
      expect(c.progress!.owned.length, 12);
      expect(c.progress!.availableChoices, 0);
      await c.equip(RewardCategory.accessory, null);
      expect(c.progress!.companion[RewardCategory.accessory], isNull);
      await c.equip(RewardCategory.mane, 'blue');
      expect(c.progress!.companion[RewardCategory.mane], 'blue');
      await c.completeRound('more');
      expect(c.progress!.owned.length, 12);
    },
  );
  test('reset clears progress and preserves settings', () async {
    final d = MemoryDevice()
          ..xp = 900
          ..range = NumberRange(20, 30),
        c = await controller(d);
    await c.choose('blue');
    await c.completeTapChallengeRound('record', 9);
    await c.reset();
    expect(c.progress!.encode(), PlayerProgress().encode());
    expect(c.settings.numberGameRanges.numberHunt, NumberRange(20, 30));
    final restarted = await controller(d);
    expect(restarted.progress!.xp, 0);
  });
  test(
    'malformed documents never silently reset and can recover explicitly',
    () async {
      for (final bad in [
        '{}',
        'not json',
        PlayerProgress().encode().replaceFirst('"xp":0', '"xp":-50'),
        PlayerProgress().encode().replaceFirst(
          '"tapChallengeHighScore":0',
          '"tapChallengeHighScore":-1',
        ),
      ]) {
        final d = MemoryDevice()..document = bad, c = await controller(d);
        expect(c.loadFailed, isTrue);
        expect(c.progress, isNull);
        expect(d.document, bad);
        await c.reset();
        expect(c.progress!.xp, 0);
        expect(c.loadFailed, isFalse);
      }
    },
  );
  test('strict document validation rejects impossible rewards and scores', () {
    final p = PlayerProgress(xp: 50, lastRewardedRound: 'round');
    expect(PlayerProgress.decode(p.encode()).encode(), p.encode());
    for (final broken in [
      p.copyWith(owned: {'unknown'}),
      p.copyWith(tapChallengeHighScore: -1),
      p.copyWith(
        companion: CompanionConfiguration({RewardCategory.mane: 'gold'}),
      ),
    ]) {
      expect(
        () => PlayerProgress.decode(broken.encode()),
        throwsFormatException,
      );
    }
  });
}
