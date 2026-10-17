import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/widgets/page_body.dart';

import 'widget_test.dart' show MemoryDevice;

const visualActivities = [
  Activity.readAndFind,
  Activity.makeBelieve,
  Activity.sameNumber,
  Activity.numberParts,
];

Future<GameRound> openGame(
  WidgetTester tester,
  Activity activity, {
  Size size = const Size(411, 914),
  double scale = 1,
  bool dark = false,
  bool manual = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final device = MemoryDevice()..tapNext = manual;
  final controller = ProgressController(device);
  await controller.load();
  addTearDown(controller.dispose);
  final round = GameRound(activity, random: Random(12));
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? GardenTheme.dark : GardenTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: scale == 2,
        ),
        child: child!,
      ),
      home: GamePage(
        services: device,
        activity: activity,
        sound: true,
        round: round,
        controller: controller,
        onCompleteRound: controller.completeRound,
      ),
    ),
  );
  await tester.pump();
  return round;
}

Finder bottomBar(WidgetTester tester) {
  final bar = tester
      .widget<Scaffold>(find.byType(Scaffold))
      .bottomNavigationBar;
  expect(bar, isNotNull);
  return find.byWidget(bar!);
}

void expectFullyVisible(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  final viewport = Offset.zero & tester.view.physicalSize;
  expect(rect.left, greaterThanOrEqualTo(viewport.left));
  expect(rect.top, greaterThanOrEqualTo(viewport.top));
  expect(rect.right, lessThanOrEqualTo(viewport.right));
  expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
  expect(finder.hitTestable(), findsOneWidget);
}

void expectBarFeedback(WidgetTester tester, String text) {
  final feedback = find.text(text);
  expectFullyVisible(tester, feedback);
  expect(
    find.descendant(of: bottomBar(tester), matching: feedback),
    findsOneWidget,
  );
  expect(
    tester
        .getSemantics(feedback)
        .getSemanticsData()
        .flagsCollection
        .isLiveRegion,
    isTrue,
  );
}

void expectBarNext(WidgetTester tester) {
  expect(find.text('Next'), findsOneWidget);
  final next = find.ancestor(
    of: find.text('Next'),
    matching: find.byWidgetPredicate((widget) => widget is FilledButton),
  );
  expectFullyVisible(tester, next);
  expect(
    find.descendant(of: bottomBar(tester), matching: next),
    findsOneWidget,
  );
}

Future<void> choose(WidgetTester tester, GameRound round, String answer) async {
  final card = find.byKey(ValueKey('choice-$answer'));
  await tester.ensureVisible(card);
  await tester.pump();
  await tester.tap(card);
  await tester.pump();
  if (round.question.visual?.selectThenCheck == true) {
    // The fixed Check must be reachable after selecting any card, without
    // scrolling the body back to a particular position.
    final check = find.byKey(const ValueKey('check-visual'));
    expectFullyVisible(tester, check);
    await tester.tap(check);
    await tester.pump();
  }
}

void main() {
  for (final dark in [false, true]) {
    for (final activity in visualActivities) {
      testWidgets(
        '${activity.name}: phone feedback and Next are fixed, dark=$dark',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final round = await openGame(tester, activity, dark: dark);
          if (activity == Activity.makeBelieve) {
            final check = find.byKey(const ValueKey('check-visual'));
            expectFullyVisible(tester, check);
            final wrong = round.question.choices.firstWhere(
              (choice) => choice != round.question.answer,
            );
            await choose(tester, round, wrong);
            expect(round.answered, isFalse);
            expectBarFeedback(tester, 'Try again');
            expectFullyVisible(tester, check);
            expect(find.text('Next'), findsNothing);
          }
          await choose(tester, round, round.question.answer);
          expect(round.answered, isTrue);
          expectBarFeedback(tester, 'You found it! ✨');
          expectBarNext(tester);
          expect(find.byKey(const ValueKey('check-visual')), findsNothing);
          await tester.tap(find.text('Next'));
          await tester.pump();
          expect(round.answered, isFalse);
          expect(find.text('You found it! ✨'), findsNothing);
          expect(find.text('Next'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
        },
      );
    }
  }

  for (final activity in visualActivities) {
    testWidgets('${activity.name}: small 2x bar controls remain reachable', (
      tester,
    ) async {
      final round = await openGame(
        tester,
        activity,
        size: const Size(360, 640),
        scale: 2,
      );
      final bar = bottomBar(tester);
      final barScroll = find.descendant(
        of: bar,
        matching: find.byType(Scrollable),
      );
      expect(barScroll, findsOneWidget);
      expect(
        tester.getSize(bottomBar(tester)).height,
        lessThanOrEqualTo(640 * .55),
      );
      if (activity == Activity.makeBelieve) {
        await choose(
          tester,
          round,
          round.question.choices.firstWhere((c) => c != round.question.answer),
        );
        await tester.ensureVisible(find.text('Try again'));
        await tester.pump();
        expectFullyVisible(tester, find.text('Try again'));
      }
      await choose(tester, round, round.question.answer);
      await tester.ensureVisible(find.text('Next'));
      await tester.pump();
      expectBarNext(tester);
      expect(
        tester.getSize(bottomBar(tester)).height,
        lessThanOrEqualTo(640 * .55),
      );
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(round.answered, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('${activity.name}: Tap Next off retains automatic advance', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final round = await openGame(tester, activity, manual: false);
      await choose(tester, round, round.question.answer);
      expectBarFeedback(tester, 'You found it! ✨');
      expect(find.text('Next'), findsNothing);
      await tester.pump(const Duration(milliseconds: 799));
      expect(round.answered, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(round.answered, isFalse);
      expect(find.text('You found it! ✨'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    });
  }

  testWidgets('Number hunt retains feedback and Next in the scrolling body', (
    tester,
  ) async {
    final round = await openGame(tester, Activity.numbers);
    await choose(
      tester,
      round,
      round.question.choices.firstWhere((c) => c != round.question.answer),
    );
    expect(
      find.descendant(
        of: find.byType(PageBody),
        matching: find.text('Try again'),
      ),
      findsOneWidget,
    );
    await choose(tester, round, round.question.answer);
    for (final text in ['You found it! ✨', 'Next']) {
      expect(find.text(text), findsOneWidget);
      expect(
        find.descendant(of: find.byType(PageBody), matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
