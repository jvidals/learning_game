import 'widget_test.dart' show nextLearningRound;
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/widgets/progress_widgets.dart';
import 'package:rainbow_garden/widgets/voice_button.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

class SoundDevice extends MemoryDevice {
  Completer<void>? settingsGate, rewardGate;
  bool holdAudio = false;
  final audio = <Completer<void>>[];
  int stops = 0;
  @override
  Future<void> saveSettings(AppSettings value) async {
    await settingsGate?.future;
    await super.saveSettings(value);
  }

  @override
  Future<void> saveProgress(String value) async {
    await rewardGate?.future;
    await super.saveProgress(value);
  }

  @override
  Future<void> play(String clip) {
    if (!holdAudio) return super.play(clip);
    clips.add(clip);
    final pending = Completer<void>();
    audio.add(pending);
    return pending.future;
  }

  @override
  Future<void> stop() async => stops++;
}

final muted = find.byTooltip('Turn voice on');
final voiced = find.byTooltip('Turn voice off');
final halo = find.byKey(const ValueKey('voice-attention-halo'));
final hint = find.text('Show a hint');
Finder answer(String value) => find.byKey(ValueKey('choice-$value'));
double scale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('voice-icon-scale')))
    .transform
    .storage[0];
Finder revealed = find.byWidgetPredicate(
  (w) => w is Text && RegExp(r'^Find [A-Za-z0-9]+$').hasMatch(w.data ?? ''),
);

Future<(ProgressController, GameRound)> open(
  WidgetTester tester,
  SoundDevice d, {
  Activity activity = Activity.uppercase,
  bool reduced = false,
  GlobalKey<NavigatorState>? navigator,
}) async {
  final c = ProgressController(d);
  await c.load();
  addTearDown(c.dispose);
  final round = GameRound(activity, random: Random(17));
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: GamePage(
        activity: activity,
        services: d,
        controller: c,
        sound: d.soundOn,
        round: round,
        onCompleteRound: c.completeRound,
      ),
    ),
  );
  await tester.pump();
  return (c, round);
}

void main() {
  test(
    'pending sound is immediate, retained on failure and saved without altering other settings',
    () async {
      final d = SoundDevice()
        ..tapNext = false
        ..haptics = false
        ..orderingLowercase = true
        ..settingsGate = Completer<void>();
      final c = ProgressController(d);
      await c.load();
      final save = c.setSound(false);
      final failed = expectLater(save, throwsStateError);
      expect(c.soundOn, isFalse);
      expect(c.settings.soundOn, isTrue);
      expect(c.blocked.value, isTrue);
      await expectLater(c.setSound(true), throwsStateError);
      await expectLater(c.completeRound('conflict'), throwsStateError);
      d.failSave = true;
      d.settingsGate!.complete();
      await failed;
      expect(c.soundOn, isFalse);
      expect(c.savingSound, isTrue);
      final restarted = ProgressController(d);
      await restarted.load();
      expect(
        restarted.soundOn,
        isTrue,
      ); // Only successful writes survive restart.
      restarted.dispose();
      d.failSave = false;
      d.settingsGate = null;
      await c.retry();
      expect(c.blocked.value, isFalse);
      expect(d.soundOn, isFalse);
      expect(d.settingsWrites, 1);
      expect(
        c.settings.toMap(),
        const AppSettings(
          tapNext: false,
          haptics: false,
          orderingLowercase: true,
          soundOn: false,
        ).toMap(),
      );
      await c.saveSettings(c.settings.withOrderingCase(false));
      await c.reset();
      expect(c.settings.soundOn, isFalse);
      expect(d.soundOn, isFalse);
      expect(d.orderingLowercase, isFalse);
      c.dispose();
    },
  );

  for (final activity in [
    Activity.uppercase,
    Activity.lowercase,
    Activity.numbers,
    Activity.sightWords,
  ]) {
    testWidgets(
      '${activity.name}: muted challenge, immediate unmute, explicit hint, silent reward and muted replay',
      (tester) async {
        final d = SoundDevice()..soundOn = false;
        final (_, round) = await open(tester, d, activity: activity);
        expect(d.clips, isEmpty);
        expect(revealed, findsNothing);
        expect(halo, findsOneWidget);
        final bounds = tester.getRect(muted);
        await tester.pump(const Duration(milliseconds: 900));
        expect(scale(tester), closeTo(1.12, .001));
        expect(tester.getRect(muted), bounds);
        await tester.tap(muted);
        await tester.pump();
        expect(d.clips, [round.question.audio]);
        expect(d.soundOn, isTrue);
        expect(revealed, findsNothing);
        expect(halo, findsNothing);
        final stops = d.stops;
        await tester.tap(voiced);
        await tester.pump();
        expect(d.stops, stops + 1);
        expect(d.soundOn, isFalse);
        expect(d.clips.length, 1);
        await tapVisible(tester, hint);
        expect(find.text('Find ${round.question.answer}'), findsOneWidget);
        expect(halo, findsNothing);
        for (var q = 0; q < 5; q++) {
          if (q > 0) {
            expect(revealed, findsNothing);
            expect(halo, findsOneWidget);
          }
          await tapVisible(tester, answer(round.question.answer));
          expect(halo, findsNothing);
          await tapVisible(tester, find.text(q == 4 ? 'Rewards' : 'Next'));
        }
        expect(d.xp, 50);
        expect(d.writes, 1);
        expect(find.byType(VoiceButton), findsNothing);
        expect(d.clips.length, 1);
        await nextLearningRound(tester);
        expect(muted, findsOneWidget);
        expect(revealed, findsNothing);
        expect(halo, findsOneWidget);
        expect(d.clips.length, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'home and identification share sound across visits and restart; matching remains local',
    (tester) async {
      final d = SoundDevice();
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      await tapVisible(tester, find.byTooltip('Turn sound off'));
      expect(d.soundOn, isFalse);
      await tapVisible(tester, find.text('Letters'));
      await tapVisible(tester, find.text(Activity.uppercase.title));
      expect(muted, findsOneWidget);
      expect(revealed, findsNothing);
      await tapVisible(tester, muted);
      expect(d.clips.length, 1);
      expect(d.soundOn, isTrue);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byTooltip('Turn sound off'), findsOneWidget);
      await tapVisible(tester, find.text('Numbers'));
      await tapVisible(tester, find.text(Activity.numbers.title));
      expect(d.clips.last, startsWith('number_'));
      await tapVisible(tester, voiced);
      expect(d.soundOn, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      expect(find.byTooltip('Turn sound on'), findsOneWidget);
      await tapVisible(tester, find.text('Letters'));
      await tapVisible(tester, find.text(Activity.matching.title));
      expect(muted, findsOneWidget);
      expect(halo, findsNothing);
      final writes = d.settingsWrites, requests = d.clips.length;
      await tapVisible(tester, muted);
      expect(d.soundOn, isFalse);
      expect(d.settingsWrites, writes);
      expect(d.clips.length, requests);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending unmute blocks answers without revealing colors; failed save retries after leaving without speech',
    (tester) async {
      final d = SoundDevice()
        ..soundOn = false
        ..settingsGate = Completer<void>();
      final (c, round) = await open(tester, d);
      await tester.tap(muted);
      await tester.pump();
      expect(c.soundOn, isTrue);
      expect(c.settings.soundOn, isFalse);
      expect(d.clips, [round.question.audio]);
      expect(revealed, findsNothing);
      final colors = <Color?>{};
      for (final value in round.question.choices) {
        final button = tester.widget<FilledButton>(answer(value));
        expect(button.onPressed, isNull);
        colors.add(
          button.style!.backgroundColor!.resolve({WidgetState.disabled}),
        );
      }
      expect(colors.length, 1);
      final toggle = tester.widget<IconButton>(
        find.ancestor(of: voiced, matching: find.byType(IconButton)),
      );
      expect(toggle.onPressed, isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SaveStatus(controller: c)),
        ),
      );
      d.failSave = true;
      d.settingsGate!.complete();
      await settle(tester);
      expect(find.text('Try saving again'), findsOneWidget);
      d.failSave = false;
      d.settingsGate = null;
      await tapVisible(tester, find.text('Try saving again'));
      expect(c.soundOn, isTrue);
      expect(d.soundOn, isTrue);
      expect(d.clips.length, 1);
      expect(d.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'sound save pauses automatic advancement and cannot overlap fifth-answer XP',
    (tester) async {
      final d = SoundDevice()..tapNext = false;
      final (c, round) = await open(tester, d);
      await tester.tap(answer(round.question.answer));
      await tester.pump(const Duration(milliseconds: 400));
      d.settingsGate = Completer<void>();
      await tester.tap(voiced);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(round.completed, 1);
      expect(round.answered, isTrue);
      d.settingsGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 799));
      expect(round.answered, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(round.answered, isFalse);
      for (var q = 1; q < 4; q++) {
        await tester.ensureVisible(answer(round.question.answer));
        await tester.tap(answer(round.question.answer));
        await tester.pump(const Duration(milliseconds: 800));
      }
      d.settingsGate = Completer<void>();
      await tester.tap(muted);
      await tester.pump();
      expect(round.completed, 4);
      expect(
        tester.widget<FilledButton>(answer(round.question.answer)).onPressed,
        isNull,
      );
      d.settingsGate!.complete();
      await tester.pump();
      d.rewardGate = Completer<void>();
      await tester.ensureVisible(answer(round.question.answer));
      await tester.tap(answer(round.question.answer));
      await tester.pump();
      expect(c.blocked.value, isTrue);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: voiced, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNull,
      );
      expect(d.xp, 0);
      d.rewardGate!.complete();
      await tester.pump();
      expect(d.xp, 50);
      expect(d.writes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pulse stops on background and route coverage, resumes without speech, and disposes safely',
    (tester) async {
      final d = SoundDevice()..soundOn = false;
      final nav = GlobalKey<NavigatorState>();
      await open(tester, d, navigator: nav);
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(tester), greaterThan(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(scale(tester), 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(tester), greaterThan(1));
      unawaited(
        showDialog<void>(
          context: nav.currentContext!,
          builder: (_) => const AlertDialog(title: Text('Covered')),
        ),
      );
      await settle(tester);
      expect(
        tester.widget<VoiceButton>(find.byType(VoiceButton)).active,
        isFalse,
      );
      expect(scale(tester), 1);
      nav.currentState!.pop();
      await settle(tester);
      expect(
        tester.widget<VoiceButton>(find.byType(VoiceButton)).active,
        isTrue,
      );
      expect(d.clips, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion uses a static reminder and meaningful semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final d = SoundDevice()..soundOn = false;
      await open(tester, d, activity: Activity.numbers, reduced: true);
      expect(halo, findsOneWidget);
      expect(
        tester.getSemantics(muted).label,
        'Turn voice on to hear the number',
      );
      final decoration = tester.widget<DecoratedBox>(halo).decoration;
      await tester.pump(const Duration(milliseconds: 900));
      expect(scale(tester), 1);
      expect(tester.widget<DecoratedBox>(halo).decoration, decoration);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'mute cancels a preparing identification prompt and ignores its late error',
    (tester) async {
      final d = SoundDevice()..holdAudio = true;
      await open(tester, d);
      await tester.tap(voiced);
      await tester.pump();
      d.audio.first.completeError(StateError('Canceled'));
      await tester.pump();
      expect(revealed, findsNothing);
      expect(find.textContaining('Sound could not play'), findsNothing);
      await tester.tap(muted);
      await tester.pump();
      expect(d.audio.length, 2);
      d.audio.last.completeError(StateError('Unavailable'));
      await tester.pump();
      expect(revealed, findsNothing);
      expect(hint, findsOneWidget);
      expect(find.textContaining('Sound could not play'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(740, 360),
    const Size(800, 1100),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('identification controls fit $size at $textScale text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final activity in [
          Activity.uppercase,
          Activity.lowercase,
          Activity.numbers,
          Activity.sightWords,
        ]) {
          await open(
            tester,
            SoundDevice()..soundOn = false,
            activity: activity,
          );
          final bounds = tester.getRect(muted);
          expect(bounds.size, const Size(56, 56));
          expect(bounds.right, lessThanOrEqualTo(size.width));
          await tester.pump(const Duration(milliseconds: 900));
          expect(tester.getRect(muted), bounds);
          expect(revealed, findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
