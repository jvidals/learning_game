import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/ordering_game.dart';
import 'package:rainbow_garden/profiles.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'widget_test.dart' show MemoryDevice;

class ControlledSettingsDevice extends MemoryDevice {
  final attempts = <String>[];
  final gates = <Completer<void>>[];
  int activeWrites = 0, peakWrites = 0;
  bool delay = true;
  @override
  Future<void> saveProfiles(String document) async {
    attempts.add(document);
    final gate = Completer<void>();
    gates.add(gate);
    activeWrites++;
    peakWrites = max(peakWrites, activeWrites);
    try {
      if (delay) await gate.future;
      await super.saveProfiles(document);
    } finally {
      activeWrites--;
    }
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'four independent inclusive ranges round-trip and reject activity caps',
    () {
      final settings = const AppSettings()
          .withNumberRange(Activity.numbers, NumberRange(90, 100))
          .withNumberRange(Activity.numberOrder, NumberRange(1, 20))
          .withNumberRange(Activity.howMany, NumberRange(2, 8))
          .withNumberRange(Activity.makeGroup, NumberRange(1, 15));
      final restored = AppSettings.fromMap(
        settings.toMap(),
      ).withSound(false).withOrderingCase(true);
      expect(restored.numberGameRanges.numberHunt, NumberRange(90, 100));
      expect(restored.numberGameRanges.numberOrder, NumberRange(1, 20));
      expect(restored.numberGameRanges.howMany, NumberRange(2, 8));
      expect(restored.numberGameRanges.makeGroup, NumberRange(1, 15));
      expect(
        () => settings.withNumberRange(Activity.makeGroup, NumberRange(0, 21)),
        throwsArgumentError,
      );
      expect(
        () => settings.withNumberRange(Activity.howMany, NumberRange(0, 100)),
        throwsArgumentError,
      );
      expect(
        () => settings.withNumberRange(Activity.game2048, NumberRange(0, 10)),
        throwsArgumentError,
      );
      expect(() => NumberRange(0, 10000), throwsArgumentError);
      expect(() => NumberRange(14, 15), throwsArgumentError);
    },
  );

  test(
    'legacy ranges migrate independently; all missing settings use defaults',
    () {
      final legacy = AppSettings.fromMap({
        'min': 12,
        'max': 30,
        'countingMax': 20,
      });
      expect(legacy.numberGameRanges.numberHunt, NumberRange(12, 30));
      expect(legacy.numberGameRanges.numberOrder, NumberRange(12, 30));
      expect(legacy.numberGameRanges.howMany, NumberRange(0, 20));
      expect(legacy.numberGameRanges.makeGroup, NumberRange(0, 20));
      final defaults = AppSettings.fromMap({});
      for (final a in [
        Activity.numbers,
        Activity.numberOrder,
        Activity.howMany,
        Activity.makeGroup,
      ]) {
        expect(defaults.numberGameRanges.forActivity(a), NumberRange.defaults);
      }
    },
  );

  test(
    'present malformed or partial game ranges never fall back to legacy/defaults',
    () {
      final valid = const NumberGameRanges().toMap();
      for (final malformed in [
        null,
        {},
        {
          'numberHunt': {'min': 0, 'max': 10},
        },
        {
          ...valid,
          'makeGroup': {'min': 0, 'max': 21},
        },
        {
          ...valid,
          'howMany': {'min': 1, 'max': 2},
        },
        {
          ...valid,
          'numberOrder': {'min': '0', 'max': 20},
        },
      ]) {
        expect(
          () => AppSettings.fromMap({
            'numberGameRanges': malformed,
            'min': 0,
            'max': 10,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => AppSettings.fromMap({'min': 10, 'max': 0}),
        throwsFormatException,
      );
      expect(
        () =>
            AppSettings.fromMap({'numberGameRanges': valid, 'countingMax': 7}),
        throwsFormatException,
      );
    },
  );

  test('profile migration preserves malformed neighbors and is idempotent', () {
    final store = ProfileStore.initial();
    final data = jsonDecode(store.encode()) as Map<String, dynamic>;
    final player = (data['players'] as List).single as Map<String, dynamic>;
    player['settings'] = {'min': 12, 'max': 30, 'countingMax': 20};
    final broken = {
      ...player,
      'id': 'broken',
      'settings': {'min': 0, 'max': 10000},
    };
    (data['players'] as List).add(broken);
    final migrated = ProfileStore.decode(jsonEncode(data)).migrateProgress()!;
    expect(
      migrated.active.settings.numberGameRanges.numberOrder,
      NumberRange(12, 30),
    );
    expect(migrated.players.last.toMap(), broken);
    expect(migrated.migrateProgress(), isNull);
    expect(migrated.active.progressDocument, player['progress']);
  });

  for (final activity in [
    Activity.numbers,
    Activity.howMany,
    Activity.makeGroup,
  ]) {
    test(
      '${activity.name} uses nonzero endpoints and balanced answer positions',
      () {
        final range = NumberRange(
          activity == Activity.numbers ? 98 : 18,
          activity == Activity.numbers ? 100 : 20,
        );
        final seen = <int>{};
        for (var seed = 0; seed < 40; seed++) {
          final round = GameRound(
            activity,
            random: Random(seed),
            numberRange: range,
            countingRange: activity.isCounting ? range : null,
          );
          final slots = [0, 0, 0];
          for (final q in round.questions) {
            expect(
              q.choices.map(int.parse),
              everyElement(inInclusiveRange(range.min, range.max)),
            );
            seen.add(int.parse(q.answer));
            slots[q.choices.indexOf(q.answer)]++;
            if (activity.isCounting) expect(q.audio, isEmpty);
          }
          slots.sort();
          expect(slots, [1, 2, 2]);
        }
        expect(seen, {range.min, range.min + 1, range.max});
      },
    );
  }

  test(
    'ordering uses each endpoint and counting accepts arbitrary safe maxima',
    () {
      expect(
        OrderingRound(
          Activity.numberOrder,
          numberRange: NumberRange(1, 20),
        ).targets,
        List.generate(20, (i) => i + 1),
      );
      final round = GameRound(
        Activity.makeGroup,
        countingRange: NumberRange(1, 15),
      );
      expect(
        round.questions.map((q) => int.parse(q.answer)),
        everyElement(inInclusiveRange(1, 15)),
      );
      expect(
        () => GameRound(Activity.howMany, countingRange: NumberRange(0, 21)),
        throwsArgumentError,
      );
    },
  );

  test(
    'rapid edits apply immediately and serialize the latest complete snapshot',
    () async {
      final device = ControlledSettingsDevice();
      final c = ProgressController(device);
      await c.load();
      final blocked = <bool>[];
      c.blocked.addListener(() => blocked.add(c.blocked.value));
      final first = c.updateSettings(
        (s) => s.copyWith(appearance: AppAppearance.dark),
      );
      final second = c.updateSettings(
        (s) => s.withNumberRange(Activity.makeGroup, NumberRange(1, 15)),
      );
      final third = c.updateSettings((s) => s.copyWith(haptics: false));
      expect(c.settings.appearance, AppAppearance.system);
      expect(c.effectiveSettings.appearance, AppAppearance.dark);
      expect(
        c.effectiveSettings.numberGameRanges.makeGroup,
        NumberRange(1, 15),
      );
      expect(c.effectiveSettings.haptics, isFalse);
      expect(c.canEditSettings, isTrue);
      expect(device.attempts, hasLength(1));
      await expectLater(c.addProfile('Other'), throwsStateError);
      await expectLater(c.completeRound('no-early-xp'), throwsStateError);
      await expectLater(c.reset(), throwsStateError);
      device.gates.first.complete();
      await flush();
      expect(device.attempts, hasLength(2));
      expect(blocked, [true]);
      expect(c.effectiveSettings.haptics, isFalse);
      device.gates.last.complete();
      await Future.wait([first, second, third]);
      expect(device.peakWrites, 1);
      expect(blocked, [true, false]);
      expect(c.settings.appearance, AppAppearance.dark);
      expect(c.settings.numberGameRanges.makeGroup, NumberRange(1, 15));
      expect(c.settings.haptics, isFalse);
      expect(c.progress!.xp, 0);
      c.dispose();
    },
  );

  test(
    'failed exact write retries before newer edits, preserving player and progress',
    () async {
      final device = ControlledSettingsDevice()..xp = 150;
      final c = ProgressController(device);
      await c.load();
      final id = c.activeProfile!.id;
      final first = c.updateSettings(
        (s) => s.withNumberRange(Activity.numberOrder, NumberRange(1, 20)),
      );
      final failure = expectLater(first, throwsStateError);
      device.failSave = true;
      device.gates.first.complete();
      await failure;
      await c.updateSettings(
        (s) => s.withNumberRange(Activity.makeGroup, NumberRange(1, 15)),
      );
      await c.updateSettings((s) => s.copyWith(tapNext: false));
      expect(device.attempts, hasLength(1));
      expect(c.effectiveSettings.tapNext, isFalse);
      await expectLater(c.selectProfile(id), throwsStateError);
      device.failSave = false;
      final retry = c.retry();
      expect(device.attempts[1], device.attempts[0]);
      device.gates[1].complete();
      await flush();
      expect(device.attempts, hasLength(3));
      device.gates[2].complete();
      await retry;
      expect(c.activeProfile!.id, id);
      expect(c.progress!.xp, 150);
      expect(c.settings.numberGameRanges.numberOrder, NumberRange(1, 20));
      expect(c.settings.numberGameRanges.makeGroup, NumberRange(1, 15));
      device.delay = false;
      await c.reset();
      await c.addProfile('Other');
      expect(c.settings.numberGameRanges.makeGroup, NumberRange.defaults);
      await c.selectProfile(id);
      expect(c.settings.numberGameRanges.makeGroup, NumberRange(1, 15));
      expect(c.settings.tapNext, isFalse);
      c.dispose();
      final reopened = ProgressController(device);
      await reopened.load();
      expect(
        reopened.settings.numberGameRanges.numberOrder,
        NumberRange(1, 20),
      );
      reopened.dispose();
    },
  );

  test(
    'editing back to original during an in-flight write persists the final choice',
    () async {
      final device = ControlledSettingsDevice();
      final c = ProgressController(device);
      await c.load();
      final first = c.updateSettings((s) => s.copyWith(haptics: false));
      final undo = c.updateSettings((s) => s.copyWith(haptics: true));
      device.gates.first.complete();
      await flush();
      expect(c.effectiveSettings.haptics, isTrue);
      device.gates.last.complete();
      await Future.wait([first, undo]);
      expect(c.settings.haptics, isTrue);
      c.dispose();
    },
  );
  test('edits made during manual retry wait for their queued write', () async {
    final d = ControlledSettingsDevice();
    final c = ProgressController(d);
    await c.load();
    final first = c.updateSettings((s) => s.copyWith(haptics: false));
    final failed = expectLater(first, throwsStateError);
    d.failSave = true;
    d.gates.first.complete();
    await failed;
    d.failSave = false;
    final retry = c.retry();
    var completed = false;
    final edit = c
        .updateSettings((s) => s.copyWith(tapNext: false))
        .then((_) => completed = true);
    await flush();
    expect(completed, isFalse);
    d.gates[1].complete();
    await flush();
    expect(completed, isFalse);
    d.gates[2].complete();
    await retry;
    await edit;
    expect(completed, isTrue);
    expect(c.settings.tapNext, isFalse);
    c.dispose();
  });
}
