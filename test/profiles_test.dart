import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/game_2048.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/profiles.dart';
import 'package:rainbow_garden/sight_words.dart';
import 'widget_test.dart' show MemoryDevice;

class ProfileDevice extends MemoryDevice {
  Completer<void>? gate;
  bool loseAcknowledgement = false;
  final attempts = <String>[];
  @override
  Future<void> saveProfiles(String document) async {
    attempts.add(document);
    await gate?.future;
    await super.saveProfiles(document);
    if (loseAcknowledgement) throw StateError('Lost acknowledgement');
  }
}

Future<ProgressController> open(MemoryDevice device) async {
  final controller = ProgressController(device);
  addTearDown(controller.dispose);
  await controller.load();
  return controller;
}

void main() {
  test('names use visible characters and trim without becoming identities', () {
    expect(normalizePlayerName('  Zoë 🌈  '), 'Zoë 🌈');
    expect(normalizePlayerName('👨‍👩‍👧' * 24), '👨‍👩‍👧' * 24);
    for (final invalid in ['', '  ', 'x' * 25, 'A\nB']) {
      expect(() => normalizePlayerName(invalid), throwsFormatException);
    }
    final first = PlayerProfile.fresh('Sam'),
        second = PlayerProfile.fresh('Sam');
    expect(first.id, isNot(second.id));
  });

  test(
    'collection validates identities and version without discarding damaged progress',
    () {
      final initial = ProfileStore.initial();
      final map = jsonDecode(initial.encode()) as Map<String, dynamic>;
      for (final bad in [
        {...map, 'schemaVersion': 2},
        {...map, 'activeId': 'missing'},
        {...map, 'players': []},
        {
          ...map,
          'players': [map['players'][0], map['players'][0]],
        },
      ]) {
        expect(
          () => ProfileStore.decode(jsonEncode(bad)),
          throwsFormatException,
        );
      }
      final damaged = initial.replace(
        initial.active.copyWith(progressDocument: 'broken'),
      );
      expect(
        ProfileStore.decode(damaged.encode()).active.progressDocument,
        'broken',
      );
    },
  );

  test(
    'existing progress and every setting become Player 1; added player uses defaults',
    () async {
      final d = MemoryDevice()
        ..xp = 900
        ..range = NumberRange(12, 25)
        ..tapNext = false
        ..haptics = false
        ..soundOn = false
        ..orderingLowercase = true
        ..wordPacks = SightWordPacks(SightWordPack.values.toSet());
      final c = await open(d), oldId = c.activeProfile!.id;
      final originalSettings = c.settings.toMap();
      await c.choose('blue');
      await c.choose('flower');
      await c.completeTapChallengeRound('first-best', 9);
      await c.start2048();
      await c.move2048(Move2048Direction.left);
      final original = c.progress!.encode();
      await c.addProfile('  Alex  ');
      final newId = c.activeProfile!.id;
      expect(c.activeProfile!.name, 'Alex');
      expect(c.progress!.encode(), PlayerProgress().encode());
      expect(c.settings.toMap(), const AppSettings().toMap());
      await c.completeRound('alex-round');
      await c.selectProfile(oldId);
      expect(c.progress!.encode(), original);
      expect(c.settings.toMap(), originalSettings);
      await c.selectProfile(newId);
      expect(c.progress!.xp, 50);
      final restarted = await open(d);
      expect(restarted.activeProfile!.id, newId);
      expect(restarted.profiles.length, 2);
      await restarted.selectProfile(oldId);
      expect(restarted.progress!.encode(), original);
    },
  );

  test(
    'identical learning and record IDs in separate profiles do not suppress rewards',
    () async {
      final c = await open(MemoryDevice()), first = c.activeProfile!.id;
      await c.completeRound('round');
      await c.completeTapChallengeRound('record', 7);
      await c.addProfile('Second');
      await c.completeRound('round');
      await c.completeRound('round');
      await c.completeTapChallengeRound('record', 3);
      expect(c.progress!.xp, 100);
      expect(c.progress!.tapChallengeHighScore, 3);
      await c.selectProfile(first);
      expect(c.progress!.tapChallengeHighScore, 7);
    },
  );

  test(
    'rename preserves identity; reset preserves settings; delete keeps another player',
    () async {
      final c = await open(MemoryDevice()), first = c.activeProfile!.id;
      await expectLater(c.deleteProfile(), throwsStateError);
      await c.completeRound('first');
      await c.addProfile('Second');
      final second = c.activeProfile!.id;
      await c.setSound(false);
      await c.completeRound('second');
      await c.renameProfile('New name');
      expect(c.activeProfile!.id, second);
      await c.reset();
      expect(c.activeProfile!.name, 'New name');
      expect(c.settings.soundOn, isFalse);
      expect(c.progress!.xp, 0);
      await c.deleteProfile();
      expect(c.activeProfile!.id, first);
      expect(c.progress!.xp, 50);
      expect(c.settings.soundOn, isTrue);
    },
  );

  test(
    'pending reward blocks switching and management and retries the exact snapshot',
    () async {
      final d = ProfileDevice(), c = await open(d), first = c.activeProfile!.id;
      await c.addProfile('Second');
      final second = c.activeProfile!.id;
      await c.selectProfile(first);
      d.gate = Completer<void>();
      final save = c.completeRound('pending');
      final failure = expectLater(save, throwsStateError);
      await expectLater(c.selectProfile(second), throwsStateError);
      await expectLater(c.addProfile('Third'), throwsStateError);
      await expectLater(c.renameProfile('Changed'), throwsStateError);
      await expectLater(c.deleteProfile(), throwsStateError);
      expect(c.progress!.xp, 0);
      d.failSave = true;
      d.gate!.complete();
      await failure;
      final attempted = d.attempts.last;
      await expectLater(c.selectProfile(second), throwsStateError);
      d.failSave = false;
      await c.retry();
      expect(d.attempts.last, attempted);
      expect(c.progress!.xp, 50);
      await c.selectProfile(second);
      expect(c.progress!.xp, 0);
    },
  );

  for (final operation in ['add', 'select', 'rename', 'delete']) {
    test(
      '$operation survives save failure and lost acknowledgement without duplicate players',
      () async {
        final d = ProfileDevice(),
            c = await open(d),
            first = c.activeProfile!.id;
        await c.addProfile('Second');
        final before = d.profileDocument;
        d.failSave = true;
        Future<void> perform() => switch (operation) {
          'add' => c.addProfile('Third'),
          'select' => c.selectProfile(first),
          'rename' => c.renameProfile('Renamed'),
          _ => c.deleteProfile(),
        };
        await expectLater(perform(), throwsStateError);
        expect(d.profileDocument, before);
        final snapshot = d.attempts.last;
        d.failSave = false;
        d.loseAcknowledgement = true;
        await expectLater(c.retry(), throwsStateError);
        expect(d.profileDocument, snapshot);
        d.loseAcknowledgement = false;
        await c.retry();
        expect(d.attempts.last, snapshot);
        final restarted = await open(d);
        expect(
          restarted.profiles.length,
          operation == 'add'
              ? 3
              : operation == 'delete'
              ? 1
              : 2,
        );
        expect(restarted.activeProfile!.id, c.activeProfile!.id);
      },
    );
  }

  test(
    'damaged progress remains intact when switching and resets only that player',
    () async {
      final d = MemoryDevice()..document = 'not json';
      final c = await open(d), damaged = c.activeProfile!.id;
      expect(c.loadFailed, isTrue);
      expect(c.progress, isNull);
      await c.addProfile('Healthy');
      await c.completeRound('healthy');
      final healthy = c.activeProfile!.id;
      await c.selectProfile(damaged);
      expect(c.loadFailed, isTrue);
      expect(c.activeProfile!.progressDocument, 'not json');
      await c.reset();
      expect(c.loadFailed, isFalse);
      expect(c.progress!.xp, 0);
      await c.selectProfile(healthy);
      expect(c.progress!.xp, 50);
    },
  );

  for (final damagedField in ['settings', 'progress']) {
    test(
      'malformed $damagedField stays with its player during switching and recovery',
      () async {
        final d = MemoryDevice(),
            c = await open(d),
            first = c.activeProfile!.id;
        await c.completeRound('healthy');
        await c.addProfile('Damaged');
        final brokenId = c.activeProfile!.id;
        final map = jsonDecode(d.profileDocument!) as Map<String, dynamic>;
        map['players'][1][damagedField] = 42;
        d.profileDocument = jsonEncode(map);
        final restored = await open(d);
        expect(restored.activeProfile!.id, brokenId);
        expect(restored.loadFailed, isTrue);
        await restored.selectProfile(first);
        expect(restored.progress!.xp, 50);
        expect(jsonDecode(d.profileDocument!)['players'][1][damagedField], 42);
        await restored.selectProfile(brokenId);
        await restored.reset();
        expect(restored.loadFailed, isFalse);
        expect(restored.progress!.xp, 0);
        await restored.selectProfile(first);
        expect(restored.progress!.xp, 50);
      },
    );
  }

  test('unreadable catalog never initializes over existing data', () async {
    final d = MemoryDevice()..profileDocument = '{broken';
    final c = await open(d);
    expect(c.loadFailed, isTrue);
    expect(c.activeProfile, isNull);
    expect(d.profileDocument, '{broken');
    await c.load();
    expect(d.profileDocument, '{broken');
    await c
        .reset(); // UI exposes this only behind gate and reset-all confirmation.
    expect(c.profiles.single.name, 'Player 1');
  });
}
