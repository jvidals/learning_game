import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/profiles.dart';
import 'package:rainbow_garden/tap_challenge.dart';
import 'package:rainbow_garden/writing.dart';
import 'package:rainbow_garden/game_2048.dart';
import 'widget_test.dart' show MemoryDevice;
import 'progress_test.dart' show SlowDevice;
import 'profiles_test.dart' show ProfileDevice;

String legacy(PlayerProgress progress, {int version = 2}) {
  final m = jsonDecode(progress.encode()) as Map<String, dynamic>;
  m['version'] = version;
  m.remove('tapChallengeHighScore');
  m['movesTaken'] = 1;
  m['pendingPlays'] = [1];
  m['bests'] = {'0': 900};
  if (version == 1) m.remove('earnedRewardChoices');
  return jsonEncode(m);
}

Future<ProgressController> open(MemoryDevice device) async {
  final c = ProgressController(device);
  addTearDown(c.dispose);
  await c.load();
  return c;
}

void main() {
  test(
    'every timed round offers balanced target roles in fifty distinct spawns',
    () {
      for (var seed = 0; seed < 20; seed++) {
        var now = Duration.zero;
        final round = TapChallengeRound(
          elapsed: () => now,
          random: Random(seed),
        );
        final seen = <int>{}, batch = <TapTargetKind>[];
        for (var step = 0; step < 50; step++) {
          now = Duration(milliseconds: step * 600);
          round.tick();
          expect(round.targets.length, lessThanOrEqualTo(3));
          expect(
            round.targets.map((t) => t.slot).toSet().length,
            round.targets.length,
          );
          final fresh = round.targets.where((t) => !seen.contains(t.id)).single;
          seen.add(fresh.id);
          batch.add(fresh.kind);
          if (batch.length == 10) {
            expect(batch.where((k) => k == TapTargetKind.regular).length, 6);
            expect(batch.where((k) => k == TapTargetKind.bonus).length, 2);
            expect(batch.where((k) => k == TapTargetKind.hazard).length, 2);
            batch.clear();
          }
        }
        expect(seen.length, 50);
      }
    },
  );
  test('good targets score once, hazards subtract two with a zero floor', () {
    var now = Duration.zero;
    final round = TapChallengeRound(elapsed: () => now, random: Random(4));
    var expected = 0;
    final kinds = <TapTargetKind>{};
    for (var i = 0; i < 20; i++) {
      now = Duration(milliseconds: 600 * i);
      round.tick();
      final target = round.targets.last;
      kinds.add(target.kind);
      expect(round.tap(target.id), target.kind);
      expected = max(0, expected + target.kind.points);
      expect(round.score, expected);
      expect(round.tap(target.id), isNull);
      expect(round.tap(-1), isNull);
      expect(round.score, expected);
    }
    expect(kinds, TapTargetKind.values.toSet());
  });
  test(
    'untapped targets expire exactly and delayed frames cannot extend them',
    () {
      var now = Duration.zero;
      final round = TapChallengeRound(elapsed: () => now, random: Random(2));
      final id = round.targets.single.id;
      now = const Duration(milliseconds: 1799);
      round.tick();
      expect(round.targets.any((t) => t.id == id), isTrue);
      now = const Duration(milliseconds: 1800);
      expect(round.tap(id), isNull);
      now = const Duration(milliseconds: 17123);
      round.tick();
      expect(round.targets.length, 3);
      expect(round.targets.every((t) => t.expires > now), isTrue);
      expect(round.score, 0);
    },
  );
  test(
    'thirty-second boundary rejects taps and freezes final score forever',
    () {
      var now = Duration.zero;
      final round = TapChallengeRound(elapsed: () => now);
      expect(round.secondsLeft, 30);
      now = const Duration(milliseconds: 29999);
      round.tick();
      expect(round.finished, isFalse);
      expect(round.secondsLeft, 1);
      final id = round.targets.last.id;
      now = const Duration(seconds: 30);
      expect(round.tap(id), isNull);
      expect(round.finished, isTrue);
      expect(round.secondsLeft, 0);
      expect(round.targets, isEmpty);
      now = const Duration(minutes: 10);
      round.tick();
      expect(round.score, 0);
    },
  );
  test('paused active time changes neither targets nor countdown', () {
    var now = const Duration(seconds: 4);
    final round = TapChallengeRound(elapsed: () => now);
    final ids = round.targets.map((t) => t.id).toList();
    for (var i = 0; i < 100; i++) {
      round.tick();
    }
    expect(round.secondsLeft, 26);
    expect(round.targets.map((t) => t.id), ids);
    now += const Duration(seconds: 1);
    round.tick();
    expect(round.secondsLeft, 25);
  });
  test(
    'first positive record and later records award fifty; zero and ties do not',
    () async {
      final d = MemoryDevice(), c = await open(d);
      expect((await c.completeTapChallengeRound('zero', 0)).xpAwarded, 0);
      expect((await c.completeTapChallengeRound('one', 1)).xpAwarded, 50);
      expect(c.progress!.availableChoices, 1);
      expect((await c.completeTapChallengeRound('tie', 1)).xpAwarded, 0);
      expect((await c.completeTapChallengeRound('lower', 0)).xpAwarded, 0);
      expect((await c.completeTapChallengeRound('two', 7)).xpAwarded, 50);
      expect((await c.completeTapChallengeRound('two', 7)).xpAwarded, 0);
      expect(c.progress!.xp, 100);
      expect(c.progress!.tapChallengeHighScore, 7);
      final reopened = await open(d);
      await reopened.completeTapChallengeRound('two', 7);
      expect(reopened.progress!.xp, 100);
      await expectLater(
        c.completeTapChallengeRound('bad', -1),
        throwsArgumentError,
      );
    },
  );
  test('only the final submitted score decides a record', () async {
    final c = await open(
      MemoryDevice()
        ..document = PlayerProgress(
          xp: 50,
          lastRewardedRound: 'old',
          tapChallengeHighScore: 10,
        ).encode(),
    );
    expect(
      (await c.completeTapChallengeRound('fell-below-best', 9)).xpAwarded,
      0,
    );
    expect(c.progress!.tapChallengeHighScore, 10);
    expect(c.progress!.xp, 50);
  });
  for (final lost in [false, true]) {
    test(
      'failed record retains exact score and XP, lost acknowledgement=$lost',
      () async {
        final d = ProfileDevice(), c = await open(d);
        await c.addProfile('Second');
        final other = c.profiles.first.id;
        final origin = c.activeProfile!.id;
        d.failSave = !lost;
        d.loseAcknowledgement = lost;
        await expectLater(
          c.completeTapChallengeRound('record', 20),
          throwsStateError,
        );
        expect(c.progress!.xp, 0);
        expect(c.progress!.tapChallengeHighScore, 0);
        final snapshot = d.attempts.last;
        await expectLater(c.selectProfile(other), throwsStateError);
        await expectLater(
          c.completeTapChallengeRound('other', 30),
          throwsStateError,
        );
        await expectLater(c.reset(), throwsStateError);
        d.failSave = false;
        d.loseAcknowledgement = false;
        await c.retry();
        expect(d.attempts.last, snapshot);
        expect(c.activeProfile!.id, origin);
        expect(c.progress!.xp, 50);
        expect(c.progress!.tapChallengeHighScore, 20);
        await c.completeTapChallengeRound('record', 20);
        expect(c.progress!.xp, 50);
        await c.selectProfile(other);
        expect(c.progress!.tapChallengeHighScore, 0);
      },
    );
  }
  test(
    'slow record write publishes only durable progress and blocks other writes',
    () async {
      final d = SlowDevice(), c = await open(d);
      d.pending = Completer<void>();
      final save = c.completeTapChallengeRound('slow', 14);
      expect(c.blocked.value, isTrue);
      expect(c.progress!.xp, 0);
      await expectLater(c.completeRound('learning'), throwsStateError);
      d.pending!.complete();
      await save;
      expect(c.progress!.tapChallengeHighScore, 14);
      expect(c.progress!.xp, 50);
    },
  );
  test(
    'scores and record XP are isolated by profile; reset keeps settings and name',
    () async {
      final c = await open(MemoryDevice());
      final first = c.activeProfile!.id;
      await c.completeTapChallengeRound('shared-id', 12);
      await c.addProfile('Alex');
      await c.setSound(false);
      await c.completeTapChallengeRound('shared-id', 5);
      expect(c.progress!.xp, 50);
      await c.reset();
      expect(c.progress!.tapChallengeHighScore, 0);
      expect(c.activeProfile!.name, 'Alex');
      expect(c.settings.soundOn, isFalse);
      await c.selectProfile(first);
      expect(c.progress!.tapChallengeHighScore, 12);
      expect(c.progress!.xp, 50);
    },
  );
  for (final version in [1, 2]) {
    test(
      'version $version migrates once, preserving unrelated progress and settings',
      () async {
        final writing = WritingProgress.start('writing', Random(2));
        final prior = PlayerProgress(
          xp: 150,
          lastRewardedRound: 'old',
          owned: {'blue'},
          companion: CompanionConfiguration({RewardCategory.mane: 'blue'}),
          writing: writing,
          game2048: const Game2048Progress(highScore: 64),
        );
        final d = MemoryDevice()
          ..document = legacy(prior, version: version)
          ..soundOn = false;
        final c = await open(d);
        expect(c.loadFailed, isFalse);
        expect(c.progress!.xp, 150);
        expect(c.progress!.owned, {'blue'});
        expect(c.progress!.companion[RewardCategory.mane], 'blue');
        expect(c.progress!.availableChoices, 1);
        expect(c.progress!.writing!.toJson(), writing.toJson());
        expect(c.progress!.game2048.highScore, 64);
        expect(c.settings.soundOn, isFalse);
        expect(c.progress!.tapChallengeHighScore, 0);
        final data = jsonDecode(d.document) as Map;
        expect(data['version'], 3);
        expect(data.containsKey('movesTaken'), isFalse);
        expect(data.containsKey('pendingPlays'), isFalse);
        expect(data.containsKey('bests'), isFalse);
        final writes = d.writes;
        await open(d);
        expect(d.writes, writes);
      },
    );
  }
  test(
    'migration normalizes valid inactive players and preserves damaged players verbatim',
    () async {
      final old = PlayerProfile.fresh('Old').copyWith(
        progressDocument: legacy(
          PlayerProgress(xp: 50, lastRewardedRound: 'old'),
        ),
      );
      final broken = PlayerProfile.fresh(
        'Broken',
      ).copyWith(progressDocument: 'not json');
      final fresh = PlayerProfile.fresh('Current');
      final map =
          jsonDecode(
                ProfileStore(
                  activeId: fresh.id,
                  players: [fresh, old, broken],
                ).encode(),
              )
              as Map;
      (map['players'][1]['settings'] as Map)['relaxed'] = true;
      final d = ProfileDevice()..profileDocument = jsonEncode(map);
      final c = await open(d);
      expect(c.loadFailed, isFalse);
      final saved = ProfileStore.decode(d.profileDocument!);
      expect(jsonDecode(saved.players[1].progressDocument)['version'], 3);
      expect(
        (saved.players[1].toMap()['settings'] as Map).containsKey('relaxed'),
        isFalse,
      );
      expect(saved.players[2].progressDocument, 'not json');
      await c.selectProfile(broken.id);
      expect(c.loadFailed, isTrue);
      expect(c.activeProfile!.progressDocument, 'not json');
    },
  );
  test(
    'failed migration remains blocked until the identical snapshot saves',
    () async {
      final d = ProfileDevice()
        ..document = legacy(PlayerProgress(xp: 50, lastRewardedRound: 'old'))
        ..failSave = true;
      final c = await open(d);
      expect(c.blocked.value, isTrue);
      final expected = d.attempts.last;
      expect(jsonDecode(d.document)['version'], 2);
      d.failSave = false;
      await c.retry();
      expect(d.attempts.last, expected);
      expect(jsonDecode(d.document)['version'], 3);
      expect(c.progress!.xp, 50);
    },
  );
  test(
    'malformed retired data and unknown versions require explicit recovery',
    () async {
      for (final change in [
        {'movesTaken': 2},
        {
          'pendingPlays': [1, 1],
        },
        {
          'bests': {'8': 2},
        },
        {'version': 9},
      ]) {
        final m =
            jsonDecode(legacy(PlayerProgress(xp: 50, lastRewardedRound: 'old')))
                as Map;
        m.addAll(change);
        final encoded = jsonEncode(m),
            d = MemoryDevice()..document = jsonEncode(m);
        final c = await open(d);
        expect(c.loadFailed, isTrue);
        expect(d.document, encoded);
        expect(d.writes, 0);
      }
    },
  );
}
