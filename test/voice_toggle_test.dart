import 'widget_test.dart' show nextLearningRound;
import 'dart:async';
import 'dart:math';
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'interface_refresh_test.dart' show target, answer;
import 'interface_layout_test.dart' show capture, captureApp, loadCaptureFonts;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

class VoiceDevice extends MemoryDevice {
  int stops = 0;
  @override
  Future<void> stop() async => stops++;
}

class PendingVoiceDevice extends VoiceDevice {
  final pending = <Completer<void>>[];
  @override
  Future<void> play(String clip) {
    clips.add(clip);
    final result = Completer<void>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    throw StateError('Audio unavailable');
  }
}

Finder get voiceOn => find.byTooltip('Turn voice off');
Finder get voiceOff => find.byTooltip('Turn voice on');
Finder get hint => find.text('Show a hint');
Finder get listen => find.text('Listen again');

Future<void> openGame(
  WidgetTester tester,
  VoiceDevice d, {
  bool sound = true,
  Activity activity = Activity.matching,
  GlobalKey<NavigatorState>? navigator,
}) async {
  d.soundOn = sound;
  final controller = ProgressController(d);
  await controller.load();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: GamePage(
        services: d,
        activity: activity,
        sound: sound,
        round: GameRound(activity, random: Random(17)),
        controller: controller,
        onCompleteRound: controller.completeRound,
      ),
    ),
  );
  await settle(tester);
}

String wrong(WidgetTester tester) => tester
    .widgetList<FilledButton>(find.byType(FilledButton))
    .map((b) => b.key)
    .whereType<ValueKey<String>>()
    .map((k) => k.value)
    .firstWhere(
      (key) => key.startsWith('choice-') && key != 'choice-${target(tester)}',
    )
    .substring(7);

void main() {
  setUpAll(loadCaptureFonts);
  for (final initialSound in [true, false]) {
    for (final manual in [true, false]) {
      testWidgets(
        'matching sound=$initialSound manual=$manual: silent rounds preserve challenge, cues and replay',
        (tester) async {
          final d = VoiceDevice()..tapNext = manual;
          await openGame(tester, d, sound: initialSound);
          expect(initialSound ? voiceOn : voiceOff, findsOneWidget);
          expect(d.clips.length, initialSound ? 1 : 0);
          if (initialSound) {
            await tester.tap(voiceOn);
            await tester.pump();
            expect(d.stops, 1);
          }
          final initialClips = List<String>.of(d.clips);
          final directions = <bool>{};
          for (var replay = 0; replay < 2; replay++) {
            for (var q = 0; q < 5; q++) {
              final value = target(tester);
              directions.add(value == value.toUpperCase());
              expect(find.text('Find $value'), findsNothing);
              expect(hint, findsOneWidget);
              expect(listen, findsNothing);
              await tester.ensureVisible(answer(wrong(tester)));
              await tester.tap(answer(wrong(tester)));
              await tester.pump();
              expect(
                find.byKey(const ValueKey('retry-marker')),
                findsOneWidget,
              );
              expect(d.feedbacks.last, DeviceFeedback.retry);
              await tester.tap(answer(value));
              await tester.pump();
              expect(
                d.feedbacks.last,
                q == 4 && replay == 0
                    ? DeviceFeedback.confirm
                    : DeviceFeedback.light,
              );
              if (q == 4) {
                await tester.pump(const Duration(milliseconds: 100));
                expect(find.text('50 XP earned!'), findsOneWidget);
                await tapVisible(tester, find.text('Rewards'));
              } else if (manual) {
                await tapVisible(tester, find.text('Next'));
              } else {
                await tester.pump(const Duration(milliseconds: 800));
                await tester.pump();
              }
            }
            expect(d.xp, 50 * (replay + 1));
            expect(voiceOff, findsNothing);
            expect(voiceOn, findsNothing);
            expect(d.clips, initialClips);
            if (replay == 0) {
              expect(find.text('Back to game'), findsOneWidget);
              expect(listen, findsNothing);
              expect(d.clips, initialClips);
              await nextLearningRound(tester);
              expect(voiceOff, findsOneWidget);
            }
          }
          expect(directions, {true, false});
          await nextLearningRound(tester);
          expect(voiceOff, findsOneWidget);
          await tester.tap(voiceOff);
          await tester.pump();
          expect(d.clips, initialClips); // Enabling voice itself stays silent.
          await tapVisible(tester, listen);
          expect(d.clips.last, startsWith('match_'));
          final beforeRetry = d.clips.length;
          await tapVisible(tester, answer(wrong(tester)));
          expect(d.clips.length, beforeRetry);
          await tapVisible(tester, hint);
          expect(find.text('Find ${target(tester)}'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final activity in ActivityContent.recognition.where(
    (a) => a.hasSpokenTarget,
  )) {
    testWidgets(
      '${activity.name}: only question prompts play through two rounds',
      (tester) async {
        final d = VoiceDevice();
        await openGame(tester, d, activity: activity);
        final expected = <String>[];
        for (var replay = 0; replay < 2; replay++) {
          for (var q = 0; q < 5; q++) {
            final prompt = d.clips.last;
            expect(
              prompt,
              matches(
                r'^(upper_[a-z]|lower_[a-z]|sound_[a-z]|number_\d+|word_[a-z]+|match_(upper|lower))$',
              ),
            );
            expected.add(prompt);
            expect(d.clips, expected);
            await tapVisible(tester, listen);
            expected.add(prompt);
            expect(d.clips, expected);
            await tapVisible(tester, hint);
            await tapVisible(tester, answer(wrong(tester)));
            expect(d.clips, expected);
            expect(d.feedbacks.last, DeviceFeedback.retry);
            await tapVisible(tester, answer(target(tester)));
            expect(d.clips, expected);
            expect(
              d.feedbacks.last,
              q == 4 && replay == 0
                  ? DeviceFeedback.confirm
                  : DeviceFeedback.light,
            );
            await tapVisible(tester, find.text(q == 4 ? 'Rewards' : 'Next'));
          }
          expect(d.xp, (replay + 1) * 50);
          expect(d.writes, replay + 1);
          expect(find.text('50 XP earned!'), findsOneWidget);
          expect(d.clips, expected);
          expect(voiceOn, findsNothing);
          expect(voiceOff, findsNothing);
          expect(listen, findsNothing);
          if (replay == 0) {
            await nextLearningRound(tester);
            if (activity == Activity.matching) expect(voiceOn, findsOneWidget);
          }
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('reward stops a preparing prompt and ignores its late failure', (
    tester,
  ) async {
    final d = PendingVoiceDevice();
    await openGame(tester, d);
    for (var q = 0; q < 5; q++) {
      await tapVisible(tester, answer(target(tester)));
      if (q < 4) await tapVisible(tester, find.text('Next'));
    }
    // Listen again remains available on the solved question before reward entry.
    final replayPrompt = tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Listen again'),
        )
        .onPressed!;
    await tapVisible(tester, listen);
    final stops = d.stops, requests = d.clips.length;
    await tapVisible(tester, find.text('Rewards'));
    expect(d.stops, greaterThanOrEqualTo(stops + 1));
    replayPrompt(); // A stale callback cannot play over the reward.
    for (final pending in d.pending) {
      pending.completeError(StateError('Canceled prompt'));
    }
    await tester.pump();
    expect(d.clips.length, requests);
    expect(find.textContaining('Sound could not play'), findsNothing);
    expect(tester.takeException(), isNull);
    await nextLearningRound(tester);
    expect(voiceOn, findsOneWidget);
    expect(d.clips.length, requests + 1);
    expect(find.textContaining('Sound could not play'), findsNothing);
    d.pending.last.complete();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'mute, background, route coverage and disposal ignore late audio failures',
    (tester) async {
      final d = PendingVoiceDevice();
      final nav = GlobalKey<NavigatorState>();
      await openGame(tester, d, navigator: nav);
      await tester.tap(voiceOn);
      await tester.pump();
      d.pending[0].completeError(StateError('Canceled initial audio'));
      await tester.pump();
      expect(find.textContaining('Sound could not play'), findsNothing);
      expect(find.text('Find ${target(tester)}'), findsNothing);
      await tester.tap(voiceOff);
      await tester.pump();
      expect(d.pending.length, 1);
      await tapVisible(tester, listen);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      d.pending[1].completeError(StateError('Paused'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(voiceOn, findsOneWidget);
      expect(find.textContaining('Sound could not play'), findsNothing);
      await tapVisible(tester, listen);
      unawaited(
        showDialog<void>(
          context: nav.currentContext!,
          builder: (_) => const AlertDialog(title: Text('Covered')),
        ),
      );
      await tester.pump();
      d.pending[2].completeError(StateError('Covered'));
      await tester.pump();
      nav.currentState!.pop();
      await settle(tester);
      expect(find.textContaining('Sound could not play'), findsNothing);
      await tapVisible(tester, listen);
      await tester.pumpWidget(const SizedBox());
      d.pending[3].completeError(StateError('Disposed'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('audio failure leaves matching answer behind an explicit hint', (
    tester,
  ) async {
    final d = VoiceDevice()..failAudio = true;
    await openGame(tester, d);
    expect(find.textContaining('Sound could not play'), findsOneWidget);
    expect(find.text('Find ${target(tester)}'), findsNothing);
    await tapVisible(tester, hint);
    expect(find.text('Find ${target(tester)}'), findsOneWidget);
    await tester.tap(voiceOn);
    await tester.pump();
    expect(find.textContaining('Sound could not play'), findsNothing);
    expect(find.text('Find ${target(tester)}'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'voice choice stays local and each visit inherits the Home setting',
    (tester) async {
      final d = VoiceDevice();
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      await tapVisible(tester, find.text('Letters'));
      await tapVisible(tester, find.text(Activity.matching.title));
      await tapVisible(tester, voiceOn);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(voiceOff, findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tapVisible(tester, find.text(Activity.matching.title));
      expect(voiceOn, findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byTooltip('Turn sound off'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Turn sound off'));
      await tapVisible(tester, find.text('Letters'));
      await tapVisible(tester, find.text(Activity.matching.title));
      expect(voiceOff, findsOneWidget);
      await tapVisible(tester, voiceOff);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tapVisible(tester, find.text(Activity.uppercase.title));
      expect(voiceOn, findsNothing);
      expect(voiceOff, findsOneWidget);
      expect(listen, findsNothing);
      expect(find.textContaining('Find ', findRichText: false), findsNothing);
      expect(hint, findsOneWidget);
      expect(d.writes, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final activity in [
    Activity.uppercase,
    Activity.lowercase,
    Activity.numbers,
    Activity.sightWords,
  ]) {
    testWidgets('${activity.name}: restored voice toggle and explicit hints', (
      tester,
    ) async {
      for (final sound in [true, false]) {
        await openGame(tester, VoiceDevice(), sound: sound, activity: activity);
        expect(voiceOn, sound ? findsOneWidget : findsNothing);
        expect(voiceOff, sound ? findsNothing : findsOneWidget);
        expect(listen, sound ? findsOneWidget : findsNothing);
        expect(hint, findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  for (final (name, size) in [
    ('phone', const Size(320, 640)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('voice control accessible at $name / $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: boundary, child: captureApp(VoiceDevice())),
        );
        await settle(tester);
        await tapVisible(tester, find.text('Letters'));
        await tapVisible(tester, find.text(Activity.matching.title));
        for (final on in [true, false]) {
          final toggle = on ? voiceOn : voiceOff;
          final bounds = tester.getRect(toggle);
          expect(bounds.width, 56);
          expect(bounds.height, 56);
          expect(bounds.right, lessThanOrEqualTo(size.width));
          expect(
            tester.getSemantics(toggle).label,
            on ? 'Turn voice off' : 'Turn voice on',
          );
          expect(
            tester
                .getSemantics(toggle)
                .getSemanticsData()
                .flagsCollection
                .isToggled,
            on ? Tristate.isTrue : Tristate.isFalse,
          );
          expect(find.text('Find ${target(tester)}'), findsNothing);
          expect(hint, findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            boundary,
            'voice-${on ? 'on' : 'off'}-$name-${scale.toInt()}x',
            directory: '052',
          );
          if (on) await tapVisible(tester, toggle);
        }
        await tapVisible(tester, hint);
        expect(find.text('Find ${target(tester)}'), findsOneWidget);
        await tapVisible(tester, answer(target(tester)));
        expect(find.text('You found it! ✨'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      });
    }
  }
}
