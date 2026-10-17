import 'dart:math';
import 'dart:convert';
import 'package:rainbow_garden/profiles.dart';
import 'package:rainbow_garden/sight_words.dart';
import 'package:rainbow_garden/letter_sounds.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/game_page.dart';

class MemoryDevice implements DeviceServices {
  NumberRange range = NumberRange.defaults;
  NumberGameRanges? _ranges;
  NumberGameRanges get ranges =>
      _ranges ?? NumberGameRanges.fromLegacy(range, countingMax);
  SoundSelection sounds = SoundSelection.defaults;
  int countingMax = 10;
  bool tapNext = true, haptics = true;
  bool orderingLowercase = false;
  bool soundOn = true;
  AppAppearance appearance = AppAppearance.system;
  SightWordPacks wordPacks = SightWordPacks.defaults;
  int settingsWrites = 0;
  final feedbacks = <DeviceFeedback>[];
  @override
  Future<void> feedback(DeviceFeedback kind) async {
    feedbacks.add(kind);
  }

  Future<AppSettings> loadSettings() async => AppSettings(
    numberGameRanges: ranges,
    enabledLetterSounds: sounds,
    tapNext: tapNext,
    haptics: haptics,
    orderingLowercase: orderingLowercase,
    soundOn: soundOn,
    appearance: appearance,
    enabledSightWordPacks: wordPacks,
  );
  Future<void> saveSettings(AppSettings value) async {
    if (failSave) throw StateError('Unavailable');
    _ranges = value.numberGameRanges;
    range = value.numberGameRanges.numberHunt;
    sounds = value.enabledLetterSounds;
    countingMax = value.numberGameRanges.howMany.max;
    tapNext = value.tapNext;
    haptics = value.haptics;
    orderingLowercase = value.orderingLowercase;
    soundOn = value.soundOn;
    appearance = value.appearance;
    wordPacks = value.enabledSightWordPacks;
    settingsWrites++;
    if (profileDocument != null) {
      try {
        final store = ProfileStore.decode(profileDocument!);
        profileDocument = store
            .replace(store.active.copyWith(settings: value))
            .encode();
      } on FormatException {
        /* Recovery can replace an unreadable test catalog. */
      }
    }
  }

  String _document = PlayerProgress().encode();
  String get document => _document;
  set document(String value) {
    _document = value;
    if (profileDocument != null) {
      try {
        final store = ProfileStore.decode(profileDocument!);
        profileDocument = store
            .replace(store.active.copyWith(progressDocument: value))
            .encode();
      } on FormatException {
        /* Recovery can replace an unreadable test catalog. */
      }
    }
  }

  int get xp => PlayerProgress.decode(document).xp;
  set xp(int value) {
    document = PlayerProgress(
      xp: value,
      lastRewardedRound: value > 0 ? 'seed' : null,
    ).encode();
  }

  int writes = 0;
  bool failLoad = false;
  bool failAudio = false;
  bool failSave = false;
  final clips = <String>[];
  Future<String> loadProgress() async {
    if (failLoad) throw StateError('Unavailable');
    return document;
  }

  Future<void> saveProgress(String value) async {
    if (failSave) throw StateError('Unavailable');
    document = value;
    writes++;
  }

  String? profileDocument;
  @override
  Future<String> loadProfiles() async {
    if (failLoad) throw StateError('Unavailable');
    return profileDocument ??= ProfileStore(
      activeId: 'player-1',
      players: [
        PlayerProfile(
          id: 'player-1',
          name: 'Player 1',
          settings: await loadSettings(),
          progressDocument: await loadProgress(),
        ),
      ],
    ).encode();
  }

  @override
  Future<void> saveProfiles(String value) async {
    if (failSave) throw StateError('Unavailable');
    final next = ProfileStore.decode(value);
    try {
      next.active.settings;
      next.active.progressDocument;
    } on FormatException {
      profileDocument = value;
      return;
    }
    final previousSettings = await loadSettings();
    if (jsonEncode(next.active.settings.toMap()) !=
        jsonEncode(previousSettings.toMap())) {
      await saveSettings(next.active.settings);
    } else {
      await saveProgress(next.active.progressDocument);
    }
    profileDocument = value;
    _document = next.active.progressDocument;
    final settings = next.active.settings;
    _ranges = settings.numberGameRanges;
    range = settings.numberGameRanges.numberHunt;
    sounds = settings.enabledLetterSounds;
    countingMax = settings.numberGameRanges.howMany.max;
    tapNext = settings.tapNext;
    haptics = settings.haptics;
    orderingLowercase = settings.orderingLowercase;
    soundOn = settings.soundOn;
    appearance = settings.appearance;
    wordPacks = settings.enabledSightWordPacks;
  }

  @override
  Future<void> play(String clip) async {
    if (failAudio) throw StateError('Unavailable');
    clips.add(clip);
  }

  @override
  Future<void> stop() async {}
}

RoundRewardResult rewardResult(int rounds) => RoundRewardResult(
  PlayerProgress(xp: rounds * 50, lastRewardedRound: 'test-$rounds'),
  levelForXp((rounds - 1) * 50),
);
// Decorative tickers are continuous: advance transitions without waiting for idle.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

/// Replay directly, dismissing optional reward review when that journey opened it.
Future<void> nextLearningRound(WidgetTester tester) async {
  if (find.text('Back to game').evaluate().isNotEmpty) {
    await tester.tap(find.text('Back to game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
  await tester.ensureVisible(find.text('Next round'));
  await tester.tap(find.text('Next round'));
  await settle(tester);
}

void main() {
  testWidgets('home opens category and activity; Back unwinds to Home', (
    tester,
  ) async {
    final device = MemoryDevice()..xp = 150;
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    expect(find.text('Level 3'), findsOneWidget);
    await tapVisible(tester, find.text('Letters'));
    await tapVisible(tester, find.text('Uppercase letters'));
    expect(find.text('Listen, then tap!'), findsOneWidget);
    expect(device.clips.last, startsWith('upper_'));
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Letters'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Hi, Player 1!'), findsOneWidget);
  });

  testWidgets('retry, hint, five correct answers, one saved reward, play again', (
    tester,
  ) async {
    final device = MemoryDevice();
    final round = GameRound(Activity.numbers, random: Random(9));
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          services: device,
          activity: Activity.numbers,
          sound: true,
          round: round,
          onCompleteRound: (id) async {
            final p = PlayerProgress(xp: device.xp + 50, lastRewardedRound: id);
            await device.saveProgress(p.encode());
            return RoundRewardResult(p, levelForXp(p.xp - 50));
          },
        ),
      ),
    );
    await settle(tester);
    await tapVisible(
      tester,
      find.byKey(
        ValueKey(
          'choice-${round.question.choices.firstWhere((c) => c != round.question.answer)}',
        ),
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
    await tapVisible(tester, find.text('Show a hint'));
    expect(find.text('Find ${round.question.answer}'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tapVisible(
        tester,
        find.byKey(ValueKey('choice-${round.question.answer}')),
      );
      if (i < 4) await tapVisible(tester, find.text('Next'));
    }
    expect(device.xp, 50);
    expect(device.writes, 1);
    expect(find.text('50 XP earned!'), findsOneWidget);
    await nextLearningRound(tester);
    expect(find.text('Listen, then tap!'), findsOneWidget);
    expect(device.writes, 1);
  });

  testWidgets(
    'storage read failure can recover without resetting saved rewards',
    (tester) async {
      final device = MemoryDevice()
        ..xp = 350
        ..failLoad = true;
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      expect(find.text('Uppercase letters'), findsNothing);
      expect(find.text('Hi!'), findsOneWidget);
      device.failLoad = false;
      await tapVisible(tester, find.text('Try again'));
      expect(find.text('Level 4'), findsOneWidget);
      expect(find.text('Hi, Player 1!'), findsOneWidget);
      expect(device.writes, 0);
    },
  );

  testWidgets('audio failure keeps the target behind an explicit hint', (
    tester,
  ) async {
    final device = MemoryDevice()..failAudio = true;
    final round = GameRound(Activity.lowercase, random: Random(1));
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          services: device,
          activity: Activity.lowercase,
          sound: true,
          round: round,
          onCompleteRound: (_) async => rewardResult(1),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Find ${round.question.answer}'), findsNothing);
    await tapVisible(tester, find.text('Show a hint'));
    expect(find.text('Find ${round.question.answer}'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(ValueKey('choice-${round.question.answer}')),
    );
    expect(find.text('You found it! ✨'), findsOneWidget);
  });

  testWidgets('failed reward save retries without awarding twice', (
    tester,
  ) async {
    final device = MemoryDevice()..failSave = true;
    final round = GameRound(Activity.uppercase, random: Random(2));
    await tester.pumpWidget(
      MaterialApp(
        home: GamePage(
          services: device,
          activity: Activity.uppercase,
          sound: false,
          round: round,
          onCompleteRound: (id) async {
            final p = PlayerProgress(xp: 50, lastRewardedRound: id);
            await device.saveProgress(p.encode());
            return RoundRewardResult(p, 1);
          },
        ),
      ),
    );
    await settle(tester);
    for (var i = 0; i < 5; i++) {
      await tapVisible(
        tester,
        find.byKey(ValueKey('choice-${round.question.answer}')),
      );
      if (i < 4) await tapVisible(tester, find.text('Next'));
    }
    expect(find.text('Your XP could not be saved yet.'), findsOneWidget);
    device.failSave = false;
    await tapVisible(tester, find.text('Try saving again'));
    expect(device.writes, 1);
    expect(find.text('Next round'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 640),
    const Size(800, 1100),
    const Size(740, 360),
  ]) {
    testWidgets('home and game fit $size at 200% text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(RainbowGardenApp(services: MemoryDevice()));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Letters'));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Letter friends'));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Show a hint'));
      expect(tester.takeException(), isNull);
      final target = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .firstWhere((text) => RegExp(r'^Find [A-Za-z]$').hasMatch(text))
          .substring(5);
      final answer = find.byKey(ValueKey('choice-$target'));
      await tester.ensureVisible(answer);
      await settle(tester);
      // Compare within scroll content: shorter feedback can clamp the viewport.
      Offset contentCenter() =>
          tester.getCenter(answer) +
          Offset(0, Scrollable.of(tester.element(answer)).position.pixels);
      final center = contentCenter();
      await tester.tap(answer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect((contentCenter() - center).distance, lessThan(.01));
      await settle(tester);
    });
  }
}
