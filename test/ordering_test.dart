import 'widget_test.dart' show nextLearningRound;
import 'package:rainbow_garden/app_theme.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/ordering_game.dart';
import 'package:rainbow_garden/screens/ordering_page.dart';
import 'package:rainbow_garden/widgets/ordering_board.dart';
import 'package:rainbow_garden/widgets/success_celebration.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;
import 'interface_layout_test.dart' show capture, loadCaptureFonts;
import 'settings_test.dart' show unlock;

class ControlledDevice extends MemoryDevice {
  Completer<void>? preferenceGate, rewardGate;
  @override
  Future<void> saveSettings(AppSettings value) async {
    await preferenceGate?.future;
    await super.saveSettings(value);
  }

  @override
  Future<void> saveProgress(String value) async {
    await rewardGate?.future;
    await super.saveProgress(value);
  }
}

Future<void> rest(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 550));
  await tester.pump();
}

Finder card(int value) => find.byKey(ValueKey('ordering-card-$value'));
Future<void> swapSlots(
  WidgetTester tester,
  OrderingRound round,
  int a,
  int b,
) async {
  final first = round.cards[a], second = round.cards[b];
  await tester.ensureVisible(card(first));
  await tester.pump();
  await tester.tap(card(first));
  await tester.pump();
  await tester.ensureVisible(card(second));
  await tester.pump();
  await tester.tap(card(second));
  await rest(tester);
}

Future<void> solve(WidgetTester tester, OrderingRound round) async {
  for (var i = 0; i < round.length; i++) {
    if (!round.correct(i)) {
      await swapSlots(tester, round, round.cards.indexOf(round.targets[i]), i);
    }
  }
}

Future<ProgressController> mount(
  WidgetTester tester,
  MemoryDevice device,
  OrderingRound round, {
  GlobalKey? captureKey,
  bool reduced = false,
}) async {
  final controller = ProgressController(device);
  await controller.load();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        final app = MaterialApp(theme: GardenTheme.light);
        return MaterialApp(
          theme: app.theme,
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              disableAnimations: reduced,
              textScaler: TextScaler.linear(
                tester.platformDispatcher.textScaleFactor,
              ),
            ),
            child: RepaintBoundary(
              key: captureKey,
              child: OrderingPage(
                activity: round.activity,
                controller: controller,
                numberRange: device.range,
                round: round,
              ),
            ),
          ),
        );
      },
    ),
  );
  await rest(tester);
  return controller;
}

void main() {
  setUpAll(loadCaptureFonts);
  test(
    'all shuffled boards contain the exact set, start unlocked and can be solved',
    () {
      for (final range in [
        NumberRange(0, 2),
        NumberRange.defaults,
        NumberRange(20, 30),
        NumberRange(0, 100),
      ]) {
        for (final activity in [Activity.alphabetOrder, Activity.numberOrder]) {
          for (var seed = 0; seed < 100; seed++) {
            final round = OrderingRound(
              activity,
              numberRange: range,
              random: Random(seed),
            );
            expect(round.completed, 0);
            expect(round.cards.toSet(), round.targets.toSet());
            expect(
              round.length,
              activity == Activity.alphabetOrder ? 26 : range.count,
            );
            for (var i = 0; i < round.length; i++) {
              if (round.correct(i)) continue;
              final a = round.cards.indexOf(round.targets[i]),
                  before = round.cards;
              final result = round.swap(a, i)!;
              expect(result, contains(round.targets[i]));
              for (var j = 0; j < round.length; j++) {
                if (j != a && j != i) expect(round.cards[j], before[j]);
              }
              expect(round.swap(i, (i + 1) % round.length), isNull);
            }
            expect(round.cards, round.targets);
            expect(round.finished, isTrue);
            expect(round.swap(0, 1), isNull);
          }
        }
      }
    },
  );
  test('invalid swaps, case-independent identity, and recognition guard', () {
    final round = OrderingRound(Activity.alphabetOrder, random: Random(2));
    final before = round.cards;
    expect(round.swap(-1, 2), isNull);
    expect(round.swap(0, 26), isNull);
    expect(round.swap(2, 2), isNull);
    expect(round.label(0), 'A');
    expect(round.label(25, lowercase: true), 'z');
    expect(round.cards, before);
    expect(() => GameRound(Activity.alphabetOrder), throwsArgumentError);
    expect(() => OrderingRound(Activity.numbers), throwsArgumentError);
  });
  test(
    'layout targets include gutters but never wrap into nonexistent slots',
    () {
      const layout = OrderingLayout(4, 64, 26, 300);
      expect(layout.target(layout.origin(5) + const Offset(67, 32)), 5);
      expect(layout.target(layout.origin(5) + const Offset(69, 32)), 6);
      expect(layout.target(layout.origin(26) + const Offset(32, 32)), isNull);
      expect(layout.target(const Offset(-10, 30)), isNull);
      expect(layout.target(const Offset(500, 30)), isNull);
    },
  );
  test(
    'case preference defaults, round trips and survives progress reset',
    () async {
      expect(AppSettings.fromMap(null).orderingLowercase, isFalse);
      final original = AppSettings(
        numberGameRanges: NumberGameRanges.fromLegacy(NumberRange(20, 30), 10),
        haptics: false,
        tapNext: false,
      );
      final settings = original.withOrderingCase(true);
      expect(AppSettings.fromMap(settings.toMap()).orderingLowercase, isTrue);
      final device = MemoryDevice();
      final c = ProgressController(device);
      await c.load();
      await c.saveSettings(settings);
      await c.reset();
      expect(c.settings.orderingLowercase, isTrue);
      expect(
        c.settings.numberGameRanges.numberOrder,
        original.numberGameRanges.numberOrder,
      );
      expect(c.settings.haptics, isFalse);
      expect(c.settings.tapNext, isFalse);
      c.dispose();
    },
  );
  testWidgets(
    'tap swaps lock correct cards and save 50 XP once; replay keeps range',
    (tester) async {
      final device = MemoryDevice()..range = NumberRange(20, 22);
      final round = OrderingRound(
        Activity.numberOrder,
        numberRange: device.range,
        random: Random(4),
      );
      await mount(tester, device, round);
      await solve(tester, round);
      expect(device.xp, 50);
      expect(device.writes, 1);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
      await tester.tap(card(20));
      await rest(tester);
      expect(device.writes, 1);
      await tapVisible(tester, find.text('Rewards'));
      expect(find.text('50 XP earned!'), findsOneWidget);
      await nextLearningRound(tester);
      final next = tester
          .widget<OrderingBoard>(find.byType(OrderingBoard))
          .round;
      expect(next.targets, [20, 21, 22]);
      expect(next.completed, 0);
      expect(device.writes, 1);
    },
  );
  testWidgets(
    'valid drag settles both cards; invalid and canceled drags change nothing',
    (tester) async {
      final device = MemoryDevice()..range = NumberRange(0, 5);
      final round = OrderingRound(
        Activity.numberOrder,
        numberRange: device.range,
        random: Random(4),
      );
      await mount(tester, device, round);
      final before = round.cards,
          from = tester.getCenter(card(round.cards[0])),
          to = tester.getCenter(card(round.cards[1]));
      final drag = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 310));
      await drag.moveTo(to);
      await tester.pump();
      expect(round.cards, before);
      await drag.up();
      await rest(tester);
      expect(round.cards[1], before[0]);
      expect(round.cards[0], before[1]);
      final source = round.cards.indexWhere(
        (v) => !round.correct(round.cards.indexOf(v)),
      );
      final current = round.cards;
      final invalid = await tester.startGesture(
        tester.getCenter(card(current[source])),
      );
      await tester.pump(const Duration(milliseconds: 310));
      await invalid.moveTo(const Offset(-100, -100));
      await invalid.up();
      await rest(tester);
      expect(round.cards, current);
      final canceled = await tester.startGesture(
        tester.getCenter(card(current[source])),
      );
      await tester.pump(const Duration(milliseconds: 310));
      await canceled.moveTo(
        tester.getCenter(card(current[(source + 1) % round.length])),
      );
      await canceled.cancel();
      await rest(tester);
      expect(round.cards, current);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'live case change preserves arrangement and locks, saves and survives visits',
    (tester) async {
      final device = MemoryDevice();
      final round = OrderingRound(Activity.alphabetOrder, random: Random(4));
      await mount(tester, device, round);
      await swapSlots(tester, round, round.cards.indexOf(0), 0);
      final before = round.cards, complete = round.completed;
      await tester.tap(find.byKey(const ValueKey('ordering-case')));
      await rest(tester);
      expect(device.orderingLowercase, isTrue);
      expect(round.cards, before);
      expect(round.completed, complete);
      expect(
        tester.widget<Semantics>(card(0)).properties.label,
        contains('Lowercase a'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      await tapVisible(tester, find.text('Letters'));
      await tapVisible(tester, find.text('Alphabet Order'));
      expect(
        tester.widget<OrderingBoard>(find.byType(OrderingBoard)).lowercase,
        isTrue,
      );
      expect(
        tester
            .widget<OrderingBoard>(find.byType(OrderingBoard))
            .round
            .completed,
        0,
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await unlock(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(device.orderingLowercase, isTrue);
    },
  );
  testWidgets(
    'pending case save blocks swaps; failed preference survives navigation for retry',
    (tester) async {
      final device = ControlledDevice()..preferenceGate = Completer<void>();
      final round = OrderingRound(Activity.alphabetOrder, random: Random(2));
      final controller = await mount(tester, device, round);
      final before = round.cards;
      await tester.tap(find.byKey(const ValueKey('ordering-case')));
      await tester.pump();
      expect(
        tester.widget<OrderingBoard>(find.byType(OrderingBoard)).lowercase,
        isTrue,
      );
      expect(controller.settings.orderingLowercase, isFalse);
      await tester.tap(card(before[0]));
      await tester.tap(card(before[1]));
      await tester.pump();
      expect(round.cards, before);
      device.failSave = true;
      device.preferenceGate!.complete();
      await rest(tester);
      expect(controller.blocked.value, isTrue);
      await tester.pumpWidget(const SizedBox());
      device.failSave = false;
      await controller.retry();
      expect(controller.settings.orderingLowercase, isTrue);
      expect(device.orderingLowercase, isTrue);
    },
  );
  testWidgets(
    'completion save survives leaving; delayed or retried writes never double award',
    (tester) async {
      final device = ControlledDevice()
        ..range = NumberRange(0, 2)
        ..rewardGate = Completer<void>();
      final round = OrderingRound(
        Activity.numberOrder,
        numberRange: device.range,
        random: Random(2),
      );
      final controller = await mount(tester, device, round);
      await solve(tester, round);
      expect(device.xp, 0);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Next round'),
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      device.failSave = true;
      device.rewardGate!.complete();
      await tester.pump();
      expect(controller.blocked.value, isTrue);
      device.failSave = false;
      await controller.retry();
      await controller.retry();
      expect(device.xp, 50);
      expect(device.writes, 1);
    },
  );
  testWidgets(
    'reduced motion and disabled haptics retain correct/selected semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      final device = MemoryDevice()
        ..range = NumberRange(0, 2)
        ..haptics = false;
      final round = OrderingRound(
        Activity.numberOrder,
        numberRange: device.range,
      );
      await mount(tester, device, round, reduced: true);
      await tester.tap(card(round.cards[0]));
      await tester.pump();
      expect(
        tester.widget<Semantics>(card(round.cards[0])).properties.selected,
        isTrue,
      );
      await tester.tap(card(round.cards[0]));
      await tester.pump();
      await solve(tester, round);
      expect(device.feedbacks, isEmpty);
      expect(find.byKey(const ValueKey('success-sparkles')), findsNothing);
      expect(
        tester.widget<Semantics>(card(0)).properties.label,
        contains('Correct, locked'),
      );
      handle.dispose();
    },
  );
  testWidgets(
    'background during a drag cancels it and prevents stale release',
    (tester) async {
      final device = MemoryDevice()..range = NumberRange(0, 5);
      final round = OrderingRound(
        Activity.numberOrder,
        numberRange: device.range,
      );
      await mount(tester, device, round);
      final before = round.cards;
      final drag = await tester.startGesture(tester.getCenter(card(before[0])));
      await tester.pump(const Duration(milliseconds: 310));
      await drag.moveTo(tester.getCenter(card(before[1])));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await drag.up();
      await rest(tester);
      expect(round.cards, before);
      expect(device.feedbacks, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'long drag auto-scrolls beyond the source row and swaps at the bottom',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = MemoryDevice()..range = NumberRange(0, 100);
      final round = OrderingRound(
        Activity.numberOrder,
        numberRange: device.range,
        random: Random(4),
      );
      await mount(tester, device, round);
      final before = round.cards,
          grid = find.byKey(const ValueKey('ordering-grid'));
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find.descendant(of: grid, matching: find.byType(Scrollable)),
          )
          .position;
      final drag = await tester.startGesture(tester.getCenter(card(before[0])));
      await tester.pump(const Duration(milliseconds: 310));
      await tester.pump();
      await drag.moveTo(tester.getRect(grid).bottomCenter - const Offset(0, 2));
      for (
        var i = 0;
        i < 300 && position().pixels < position().maxScrollExtent;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(position().pixels, closeTo(position().maxScrollExtent, .01));
      expect(card(before.last), findsOneWidget);
      await drag.moveTo(tester.getCenter(card(before.last)));
      await tester.pump();
      await drag.up();
      await rest(tester);
      expect(round.cards.last, before.first);
      expect(round.cards.first, before.last);
      expect(device.feedbacks.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'ordinary swap ticks, two correct cards sparkle with one confirmation, locked targets reject',
    (tester) async {
      final device = MemoryDevice()..range = NumberRange(0, 5);
      final round = OrderingRound(
        Activity.numberOrder,
        numberRange: device.range,
        random: Random(5),
      );
      await mount(tester, device, round);
      var first = 0, second = 1;
      outer:
      for (var a = 0; a < round.length; a++) {
        for (var b = a + 1; b < round.length; b++) {
          if (round.cards[a] != round.targets[b] &&
              round.cards[b] != round.targets[a]) {
            first = a;
            second = b;
            break outer;
          }
        }
      }
      await swapSlots(tester, round, first, second);
      expect(device.feedbacks, [DeviceFeedback.light]);
      while (round.length - round.completed > 2) {
        final slot = List.generate(
          round.length,
          (i) => i,
        ).firstWhere((i) => !round.correct(i));
        await swapSlots(
          tester,
          round,
          round.cards.indexOf(round.targets[slot]),
          slot,
        );
      }
      // A permutation's last two misplaced cards necessarily solve each other.
      final remaining = [
        for (var i = 0; i < round.length; i++)
          if (!round.correct(i)) i,
      ];
      expect(remaining.length, 2);
      final count = device.feedbacks.length;
      await tester.tap(card(round.cards[remaining[0]]));
      await tester.pump();
      await tester.tap(card(round.cards[remaining[1]]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 80));
      expect(device.feedbacks.skip(count), [
        DeviceFeedback.placement,
        DeviceFeedback.confirm,
      ]);
      expect(
        find.byKey(const ValueKey('success-sparkles')),
        findsNWidgets(3),
        reason: tester
            .widgetList<SuccessCelebration>(find.byType(SuccessCelebration))
            .map((w) => '${w.active} ${w.animation.value}')
            .join(','),
      );
      await rest(tester);
    },
  );
  for (final activity in [Activity.alphabetOrder, Activity.numberOrder]) {
    testWidgets(
      '${activity.name} navigation, reward, replay and fresh re-entry',
      (tester) async {
        final device = MemoryDevice()
          ..range = NumberRange(0, 2)
          ..orderingLowercase = true;
        await tester.pumpWidget(RainbowGardenApp(services: device));
        await settle(tester);
        await tapVisible(tester, find.text(activity.category.title));
        await tapVisible(tester, find.text(activity.title));
        final round = tester
            .widget<OrderingBoard>(find.byType(OrderingBoard))
            .round;
        await solve(tester, round);
        expect(device.xp, 50);
        await tapVisible(tester, find.text('Rewards'));
        expect(device.clips, isEmpty);
        await nextLearningRound(tester);
        final board = tester.widget<OrderingBoard>(find.byType(OrderingBoard));
        expect(board.round.completed, 0);
        expect(board.lowercase, isTrue);
        await solve(tester, board.round);
        expect(device.xp, 100);
        await tapVisible(tester, find.text('Rewards'));
        expect(device.clips, isEmpty);
        await tapVisible(tester, find.text('Back to home'));
        expect(find.text('Hi, Player 1!'), findsOneWidget);
        await tapVisible(tester, find.text(activity.category.title));
        await tapVisible(tester, find.text(activity.title));
        expect(
          tester
              .widget<OrderingBoard>(find.byType(OrderingBoard))
              .round
              .completed,
          0,
        );
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(find.text(activity.category.title), findsOneWidget);
      },
    );
  }
  for (final (name, size) in [
    ('small-phone', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('ordering layouts $name at $scale text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final key = GlobalKey();
        for (final (activity, range) in [
          (Activity.alphabetOrder, NumberRange.defaults),
          (Activity.numberOrder, NumberRange.defaults),
          (Activity.numberOrder, NumberRange(0, 100)),
        ]) {
          final device = MemoryDevice()..range = range;
          final round = OrderingRound(
            activity,
            numberRange: range,
            random: Random(7),
          );
          await mount(tester, device, round, captureKey: key);
          final scrollable = find.descendant(
            of: find.byKey(const ValueKey('ordering-grid')),
            matching: find.byType(Scrollable),
          );
          final position = tester.state<ScrollableState>(scrollable).position;
          if (scale == 1 && range.count <= 26) {
            expect(position.maxScrollExtent, closeTo(0, .000001));
          }
          expect(
            tester.getSize(card(round.cards.first)).shortestSide,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            key,
            '${activity.name}-${range.max}-$name-${scale.toInt()}x',
            directory: '060',
          );
          if (activity == Activity.alphabetOrder) {
            await tester.tap(find.byKey(const ValueKey('ordering-case')));
            await rest(tester);
            await capture(
              tester,
              key,
              'lowercase-$name-${scale.toInt()}x',
              directory: '060',
            );
          }
          await tester.drag(
            find.byKey(const ValueKey('ordering-grid')),
            const Offset(0, -10000),
          );
          await rest(tester);
          expect(card(round.cards.last), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
