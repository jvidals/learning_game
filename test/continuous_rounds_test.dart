import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/ordering_game.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/screens/ordering_page.dart';
import 'package:rainbow_garden/widgets/counting_board.dart';
import 'package:rainbow_garden/widgets/learning_reward.dart';
import 'package:rainbow_garden/widgets/ordering_board.dart';
import 'package:rainbow_garden/widgets/voice_button.dart';
import 'widget_test.dart' show MemoryDevice;
import 'interface_refresh_test.dart' show target, answer;
import 'interface_layout_test.dart' show capture, loadCaptureFonts;

class RoundDevice extends MemoryDevice {
  Completer<void>? gate;
  int stops = 0;
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> saveProfiles(String value) async {
    await gate?.future;
    await super.saveProfiles(value);
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<ProgressController> mount(
  WidgetTester tester,
  RoundDevice device, {
  Activity activity = Activity.matching,
  bool accessible = false,
  bool reduced = false,
  ThemeMode theme = ThemeMode.light,
  GlobalKey? boundary,
  GlobalKey<NavigatorState>? navigator,
}) async {
  final controller = ProgressController(device);
  await controller.load();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        navigatorKey: navigator,
        debugShowCheckedModeBanner: false,
        theme: GardenTheme.light,
        darkTheme: GardenTheme.dark,
        themeMode: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            accessibleNavigation: accessible,
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: activity.isOrdering
            ? OrderingPage(
                activity: activity,
                controller: controller,
                numberRange: device.range,
                round: OrderingRound(
                  activity,
                  numberRange: device.range,
                  random: Random(27),
                ),
              )
            : GamePage(
                services: device,
                activity: activity,
                sound: device.soundOn,
                controller: controller,
                onCompleteRound: controller.completeRound,
                numberRange: device.range,
                wordPacks: device.wordPacks,
                sounds: device.sounds,
                countingMax: device.countingMax,
                round: GameRound(
                  activity,
                  numberRange: device.range,
                  wordPacks: device.wordPacks,
                  sounds: device.sounds,
                  countingMax: device.countingMax,
                  random: Random(27),
                ),
              ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

Future<int?> correct(WidgetTester tester, Activity activity) async {
  if (!activity.isCounting && activity != Activity.matching) {
    await tap(tester, find.text('Show a hint'));
  }
  final value = target(tester);
  if (activity == Activity.makeGroup) {
    final board = tester.widget<CountingBoard>(find.byType(CountingBoard));
    while (board.work.items.length < int.parse(value)) {
      await tap(tester, find.byKey(const ValueKey('add-count-object')));
    }
    await tap(tester, find.text('Check'));
    return null;
  }
  final keys = tester
      .widgetList<FilledButton>(find.byType(FilledButton))
      .map((b) => b.key)
      .whereType<ValueKey<String>>()
      .where((key) => key.value.startsWith('choice-'))
      .toList();
  final slot = keys.indexOf(ValueKey('choice-$value'));
  await tap(tester, answer(value));
  return slot;
}

Future<void> finish(
  WidgetTester tester,
  Activity activity, {
  bool manual = true,
}) async {
  if (activity.isOrdering) {
    final round = tester
        .widget<OrderingBoard>(find.byType(OrderingBoard))
        .round;
    for (var i = 0; i < round.length; i++) {
      if (round.correct(i)) continue;
      await tester.pump(const Duration(milliseconds: 300));
      final first = round.cards[i], second = round.targets[i];
      await tap(tester, find.byKey(ValueKey('ordering-card-$first')));
      await tap(tester, find.byKey(ValueKey('ordering-card-$second')));
    }
  } else {
    for (var q = 0; q < 5; q++) {
      await correct(tester, activity);
      if (q < 4) {
        if (manual) {
          await tap(tester, find.text('Next'));
        } else {
          await tester.pump(const Duration(milliseconds: 800));
          await tester.pump();
        }
      }
    }
  }
}

Future<void> openRewards(WidgetTester tester) async {
  await tap(tester, find.byType(LearningRewardsButton));
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> closeRewards(WidgetTester tester) async {
  await tap(tester, find.text('Back to game'));
  await tester.pump(const Duration(milliseconds: 350));
}

Finder get next => find.ancestor(
  of: find.text('Next round'),
  matching: find.byWidgetPredicate((w) => w is FilledButton),
);

Future<void> captureReady(
  WidgetTester tester,
  GlobalKey key,
  String label,
) async {
  if (!const bool.fromEnvironment('CAPTURE_REFRESH')) return;
  // Static game companions deliberately paint decoded posters without an
  // animation frame; wait for widget loads, then verify the shared art exists.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
  expect(FoalAssets.ready, isNotNull);
  expect(find.byTooltip('Reload reward art'), findsNothing);
  await capture(tester, key, label, directory: '0190');
}

void main() {
  setUpAll(() async {
    await loadCaptureFonts();
    if (const bool.fromEnvironment('CAPTURE_REFRESH')) await FoalAssets.load();
  });
  for (final count in [0, 1, 25]) {
    testWidgets('gift button announces Rewards and its full count: $count', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                LearningRewardsButton(
                  count: count,
                  onPressed: () => opened = true,
                ),
              ],
            ),
          ),
        ),
      );
      final label = count > 0 ? 'Rewards, $count unclaimed gifts' : 'Rewards';
      expect(
        tester.getSemantics(find.byType(LearningRewardsButton)).label,
        label,
      );
      final bounds = tester.getRect(find.byType(LearningRewardsButton));
      expect(bounds.width, greaterThanOrEqualTo(56));
      expect(bounds.height, greaterThanOrEqualTo(56));
      await tester.tap(find.bySemanticsLabel(label));
      expect(opened, isTrue);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final activity in [
    ...ActivityContent.recognition,
    Activity.alphabetOrder,
    Activity.numberOrder,
  ]) {
    for (final manual in [true, false]) {
      testWidgets(
        '${activity.name}: three consecutive rounds bank XP and gifts, manual=$manual',
        (tester) async {
          final d = RoundDevice()
            ..tapNext = manual
            ..range = NumberRange(98, 100);
          final c = await mount(tester, d, activity: activity);
          final ids = <String>{};
          for (var cycle = 0; cycle < 3; cycle++) {
            await finish(tester, activity, manual: manual);
            expect(find.text('50 XP earned!'), findsOneWidget);
            expect(d.xp, (cycle + 1) * 50);
            expect(d.writes, cycle + 1);
            expect(c.progress!.owned, isEmpty);
            ids.add(c.progress!.lastRewardedRound!);
            if (manual) {
              await tester.pump(const Duration(seconds: 4));
              expect(next, findsOneWidget);
              await tap(tester, next);
            } else {
              await tester.pump(const Duration(milliseconds: 1999));
              expect(next, findsOneWidget);
              await tester.pump(const Duration(milliseconds: 1));
              await tester.pump();
            }
            expect(next, findsNothing);
            expect(find.text('Back to game'), findsNothing);
            if (activity.isOrdering) {
              final board = tester.widget<OrderingBoard>(
                find.byType(OrderingBoard),
              );
              expect(board.round.finished, isFalse);
            }
          }
          expect(ids.length, 3);
          expect(c.progress!.availableChoices, 2);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final activity in [
    Activity.matching,
    Activity.makeGroup,
    Activity.numberOrder,
  ]) {
    testWidgets(
      '${activity.name}: accessibility requires manual round continuation',
      (tester) async {
        final d = RoundDevice()
          ..tapNext = false
          ..range = NumberRange(0, 2);
        await mount(
          tester,
          d,
          activity: activity,
          accessible: true,
          reduced: true,
        );
        await finish(tester, activity);
        await tester.pump(const Duration(seconds: 10));
        expect(next, findsOneWidget);
        expect(find.text('Next round starting soon.'), findsNothing);
        await tap(tester, next);
        expect(next, findsNothing);
        expect(d.xp, 50);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'XP save gates automatic replay, retry restarts the full delay, no duplicate awards',
    (tester) async {
      final d = RoundDevice()..tapNext = false;
      final c = await mount(tester, d);
      d.gate = Completer<void>();
      await finish(tester, Activity.matching, manual: false);
      await tester.pump(const Duration(seconds: 30));
      expect(d.xp, 0);
      expect(find.text('50 XP earned!'), findsNothing);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      d.failSave = true;
      d.gate!.complete();
      await tester.pump();
      expect(c.blocked.value, isTrue);
      d.failSave = false;
      await tap(tester, find.text('Try saving again'));
      expect(d.xp, 50);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(next, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(next, findsNothing);
      expect(d.writes, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reward review suspends completion; closing gives a full new delay and no repeated feedback',
    (tester) async {
      final d = RoundDevice()..tapNext = false;
      await mount(tester, d);
      await finish(tester, Activity.matching, manual: false);
      await tester.pump(const Duration(milliseconds: 1500));
      final confirms = d.feedbacks
          .where((f) => f == DeviceFeedback.confirm)
          .length;
      await openRewards(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(d.xp, 50);
      expect(find.text('Back to game'), findsOneWidget);
      expect(find.byType(VoiceButton), findsNothing);
      await closeRewards(tester);
      await tester.pump(const Duration(milliseconds: 1649));
      expect(next, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(next, findsNothing);
      expect(
        d.feedbacks.where((f) => f == DeviceFeedback.confirm).length,
        confirms,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final ordering in [false, true]) {
    testWidgets(
      'background, coverage and rebuild respect round timers: ordering=$ordering',
      (tester) async {
        final activity = ordering ? Activity.numberOrder : Activity.matching;
        final d = RoundDevice()
          ..tapNext = false
          ..range = NumberRange(0, 2);
        final nav = GlobalKey<NavigatorState>();
        await mount(tester, d, activity: activity, navigator: nav);
        await finish(tester, activity, manual: false);
        await tester.pump(const Duration(milliseconds: 1500));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(seconds: 8));
        expect(next, findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 1500));
        unawaited(
          nav.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Covered')),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 8));
        nav.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        // An ordinary rebuild must not restart the active delay.
        tester
            .element(find.byType(ordering ? OrderingPage : GamePage))
            .markNeedsBuild();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 499));
        expect(next, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(next, findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'a captured replay callback and timer cannot skip or award a fresh round',
    (tester) async {
      final d = RoundDevice()..tapNext = false;
      await mount(tester, d);
      await finish(tester, Activity.matching, manual: false);
      final replay = tester.widget<FilledButton>(next).onPressed!;
      await tester.pump(const Duration(milliseconds: 1999));
      replay();
      replay();
      await tester.pump(const Duration(milliseconds: 1));
      expect(next, findsNothing);
      expect(d.writes, 1);
      final current = target(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(target(tester), current);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unanswered reward review preserves hints and replays only its voiced target',
    (tester) async {
      final d = RoundDevice();
      await mount(tester, d, activity: Activity.numbers);
      await tap(tester, find.text('Show a hint'));
      final value = target(tester), prompt = d.clips.last;
      await openRewards(tester);
      final requests = d.clips.length;
      await tester.pump(const Duration(seconds: 5));
      expect(d.clips.length, requests);
      await closeRewards(tester);
      await tester.pump();
      expect(target(tester), value);
      expect(find.text('Find $value'), findsOneWidget);
      expect(d.clips, [...List.filled(requests, prompt), prompt]);
      expect(d.xp, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final activity in [
    Activity.howMany,
    Activity.makeGroup,
    Activity.numberOrder,
  ]) {
    testWidgets('${activity.name}: unfinished work survives reward review', (
      tester,
    ) async {
      final d = RoundDevice()..range = NumberRange(0, 5);
      await mount(tester, d, activity: activity);
      Object snapshot;
      if (activity.isOrdering) {
        snapshot = tester
            .widget<OrderingBoard>(find.byType(OrderingBoard))
            .round;
      } else {
        final board = tester.widget<CountingBoard>(find.byType(CountingBoard));
        if (activity == Activity.makeGroup) {
          await tap(tester, find.byKey(const ValueKey('add-count-object')));
        } else if (board.scene.quantity > 0) {
          await tap(tester, find.byKey(const ValueKey('count-object-0')));
        }
        snapshot = board.work;
      }
      await openRewards(tester);
      await closeRewards(tester);
      expect(
        activity.isOrdering
            ? tester.widget<OrderingBoard>(find.byType(OrderingBoard)).round
            : tester.widget<CountingBoard>(find.byType(CountingBoard)).work,
        same(snapshot),
      );
      expect(d.writes, 0);
      expect(d.clips, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'gift save can outlive sheet; failed write blocks play and retries without losing work',
    (tester) async {
      final d = RoundDevice()..xp = 50;
      final c = await mount(tester, d);
      final value = target(tester);
      await openRewards(tester);
      d.gate = Completer<void>();
      await tap(tester, find.text('Blue mane'));
      expect(c.progress!.owned, isEmpty);
      await closeRewards(tester);
      final oldAnswer = tester.widget<FilledButton>(answer(value)).onPressed;
      oldAnswer?.call();
      await tester.pump();
      expect(find.text('You found it! ✨'), findsNothing);
      d.failSave = true;
      d.gate!.complete();
      await tester.pump();
      expect(c.blocked.value, isTrue);
      await expectLater(c.addProfile('Other player'), throwsStateError);
      d.failSave = false;
      await tap(tester, find.text('Try saving again'));
      expect(c.progress!.owned, {'blue'});
      expect(c.progress!.companion[RewardCategory.mane], 'blue');
      expect(target(tester), value);
      expect(d.writes, 1);
      await openRewards(tester);
      expect(find.text('No gifts to choose right now.'), findsOneWidget);
      await closeRewards(tester);
      await correct(tester, Activity.matching);
      expect(find.text('You found it! ✨'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await c.load();
      expect(c.progress!.owned, {'blue'});
    },
  );

  for (final (name, size) in [
    ('small', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final activity in [
          Activity.matching,
          Activity.sightWords,
          Activity.makeGroup,
          Activity.numberOrder,
        ]) {
          testWidgets('layout $name $scale ${theme.name} ${activity.name}', (
            tester,
          ) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              tester.platformDispatcher.clearTextScaleFactorTestValue();
            });
            final key = GlobalKey();
            final d = RoundDevice()..range = NumberRange(0, 2);
            await mount(
              tester,
              d,
              activity: activity,
              reduced: scale == 2,
              theme: theme,
              boundary: key,
            );
            await finish(tester, activity);
            await tester.pump(const Duration(milliseconds: 1500));
            await tester.ensureVisible(next);
            await tester.pump();
            final bounds = tester.getRect(next);
            expect(bounds.height, greaterThanOrEqualTo(48));
            expect(bounds.bottom, lessThanOrEqualTo(size.height));
            expect(tester.takeException(), isNull);
            final label = '$name-${scale}x-${theme.name}-${activity.name}';
            await captureReady(tester, key, '$label-completion');
            await openRewards(tester);
            final closeBounds = tester.getRect(find.byTooltip('Close rewards'));
            expect(closeBounds.width, greaterThanOrEqualTo(48));
            expect(
              tester.getRect(find.text('Back to game')).bottom,
              lessThan(size.height),
            );
            expect(find.text('Choose a reward'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await captureReady(tester, key, '$label-rewards');
            await tap(tester, find.text('Blue mane'));
            expect(find.text('No gifts to choose right now.'), findsOneWidget);
            await closeRewards(tester);
            await tap(tester, next);
            expect(find.text('50 XP earned!'), findsNothing);
            await tester.pumpWidget(const SizedBox());
          });
        }
      }
    }
  }
}
