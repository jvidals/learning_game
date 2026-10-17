import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'widget_test.dart' show MemoryDevice;
import 'game_2048_test.dart' show board2048;
import 'package:rainbow_garden/game_2048.dart';

String legacy(PlayerProgress progress) {
  final map = jsonDecode(progress.encode()) as Map<String, dynamic>;
  map['version'] = 1;
  map['movesTaken'] = 0;
  map['pendingPlays'] = [];
  map['bests'] = {};
  map.remove('tapChallengeHighScore');
  map.remove('earnedRewardChoices');
  return jsonEncode(map);
}

void main() {
  test('28 stable rewards share seven independent mane and polish colors', () {
    expect(rewardCatalog.length, 28);
    expect(rewardCatalog.map((r) => r.id).toSet().length, 28);
    expect(
      rewardCatalog.where((r) => legacyRewardIds.contains(r.id)).length,
      12,
    );
    final mane = {
      'pink',
      ...rewardCatalog
          .where((r) => r.category == RewardCategory.mane)
          .map((r) => r.tint!),
    };
    final polish = rewardCatalog
        .where((r) => r.category == RewardCategory.polish)
        .map((r) => r.tint!)
        .toSet();
    expect(polish, mane);
    expect(PlayerProgress(xp: 50).choices.map((r) => r.id), [
      'blue',
      'polish_pink',
      'flower',
    ]);
  });

  test('legacy excess levels do not unlock newly added rewards', () {
    final old = PlayerProgress(
      xp: xpForLevel(40),
      owned: legacyRewardIds,
      lastRewardedRound: 'old',
    );
    final migrated = PlayerProgress.decode(legacy(old));
    expect(migrated.earnedRewardChoices, 12);
    expect(migrated.availableChoices, 0);
    expect(migrated.owned, old.owned);
    final persisted = PlayerProgress.decode(migrated.encode());
    expect(persisted.availableChoices, 0);
    expect(persisted.awardXp(150).availableChoices, 0);
    expect(persisted.awardXp(200).availableChoices, 1);
  });

  test(
    'legacy unclaimed gifts remain flexible and independent of later catalog growth',
    () {
      final migrated = PlayerProgress.decode(
        legacy(
          PlayerProgress(
            xp: xpForLevel(17),
            owned: {'blue', 'flower'},
            lastRewardedRound: 'old',
          ),
        ),
      );
      expect(migrated.availableChoices, 10);
      expect(migrated.choices.first.id, 'polish_pink');
      expect(migrated.copyWith(xp: xpForLevel(100)).availableChoices, 10);
    },
  );

  test(
    'new levels accrue exactly once and stop banking at catalog exhaustion',
    () {
      var p = PlayerProgress().awardXp(xpForLevel(29));
      expect(p.earnedRewardChoices, 28);
      p = p.copyWith(
        owned: rewardCatalog.map((r) => r.id).toSet(),
        lastRewardedRound: 'all',
      );
      expect(p.availableChoices, 0);
      p = p.awardXp(10000);
      expect(p.earnedRewardChoices, 28);
      expect(PlayerProgress.decode(p.encode()).availableChoices, 0);
    },
  );

  test(
    'missing or impossible version-two entitlement never silently recovers',
    () {
      final map =
          jsonDecode(PlayerProgress(xp: 50, lastRewardedRound: 'one').encode())
              as Map<String, dynamic>;
      for (final invalid in [null, -1, 2, 1.5, '1']) {
        expect(
          () => PlayerProgress.decode(
            jsonEncode({...map, 'earnedRewardChoices': invalid}),
          ),
          throwsFormatException,
        );
      }
      map.remove('earnedRewardChoices');
      expect(
        () => PlayerProgress.decode(jsonEncode(map)),
        throwsFormatException,
      );
    },
  );

  test(
    'failed future-level awards retain exact XP and gift count for retry',
    () async {
      final device = MemoryDevice()
        ..document = legacy(
          PlayerProgress(
            xp: xpForLevel(18) - 50,
            owned: legacyRewardIds,
            lastRewardedRound: 'old',
          ),
        );
      final c = ProgressController(device);
      await c.load();
      device.failSave = true;
      await expectLater(c.completeRound('new'), throwsStateError);
      expect(c.progress!.availableChoices, 0);
      device.failSave = false;
      await c.retry();
      await c.completeRound('new');
      expect(c.progress!.availableChoices, 1);
      await c.choose('polish_pink');
      expect(c.progress!.companion[RewardCategory.polish], 'polish_pink');
      expect(c.progress!.availableChoices, 0);
      await c.equip(RewardCategory.mane, 'blue');
      expect(c.progress!.companion[RewardCategory.polish], 'polish_pink');
      await c.equip(RewardCategory.polish, null);
      expect(c.progress!.companion[RewardCategory.mane], 'blue');
      final reloaded = ProgressController(device);
      await reloaded.load();
      expect(reloaded.progress!.earnedRewardChoices, 13);
      await reloaded.reset();
      expect(reloaded.progress!.earnedRewardChoices, 0);
      c.dispose();
      reloaded.dispose();
    },
  );
  test(
    'writing credits a newly crossed level after migration and never a duplicate pair',
    () async {
      final device = MemoryDevice()
        ..document = legacy(
          PlayerProgress(
            xp: xpForLevel(18) - 10,
            owned: legacyRewardIds,
            lastRewardedRound: 'old',
          ),
        );
      final c = ProgressController(device);
      await c.load();
      await c.startWriting();
      final writing = c.progress!.writing!;
      await c.completeWritingForm(writing.id, 0, false);
      expect(c.progress!.availableChoices, 0);
      await c.completeWritingForm(writing.id, 0, true);
      await c.completeWritingForm(writing.id, 0, true);
      expect(c.progress!.xp, xpForLevel(18));
      expect(c.progress!.availableChoices, 1);
      expect(PlayerProgress.decode(device.document).earnedRewardChoices, 13);
      c.dispose();
    },
  );

  test(
    'a 2048 victory credits only its newly crossed levels after migration',
    () async {
      final before = PlayerProgress(
        xp: xpForLevel(18) - 50,
        owned: legacyRewardIds,
        lastRewardedRound: 'old',
        game2048: Game2048Progress(
          highScore: 20000,
          session: board2048([1024, 1024], score: 20000),
        ),
      );
      final device = MemoryDevice()..document = legacy(before);
      final c = ProgressController(device);
      await c.load();
      await c.move2048(Move2048Direction.left);
      expect(c.progress!.xp, before.xp + 500);
      expect(c.progress!.availableChoices, 3);
      await c.continue2048();
      await c.move2048(Move2048Direction.right);
      expect(c.progress!.availableChoices, 3);
      c.dispose();
    },
  );
}
