import 'widget_test.dart' show nextLearningRound;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/widgets/selection_card.dart';
import 'widget_test.dart' show MemoryDevice, tapVisible, settle;

void main() {
  test('every activity belongs to exactly one category', () {
    expect(GameCategory.letters.activities, [
      Activity.uppercase,
      Activity.lowercase,
      Activity.matching,
      Activity.alphabetOrder,
      Activity.letterSounds,
    ]);
    expect(GameCategory.numbers.activities, [
      Activity.numbers,
      Activity.numberOrder,
      Activity.game2048,
      Activity.howMany,
      Activity.makeGroup,
      Activity.sameNumber,
      Activity.numberParts,
    ]);
    expect(GameCategory.artHub.activities, [Activity.sketchPad]);
    expect(
      GameCategory.values.expand((c) => c.activities).toSet(),
      Activity.values.toSet(),
    );
  });

  testWidgets(
    'home contains only categories; each opens the appropriate game list',
    (tester) async {
      final device = MemoryDevice()
        ..xp = 150
        ..range = NumberRange(20, 30);
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      expect(
        tester
            .widgetList<SelectionCard>(find.byType(SelectionCard))
            .map((c) => c.title),
        ['Letters', 'Numbers', 'Words', 'Writing', 'Reflex', 'Art Hub'],
      );
      expect(find.text('Level 3'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('Turn sound off'), findsOneWidget);
      await tapVisible(tester, find.text('Letters'));
      expect(
        tester
            .widgetList<SelectionCard>(find.byType(SelectionCard))
            .map((c) => c.title),
        [
          'Uppercase Letters',
          'Lowercase Letters',
          'Letter Friends',
          'Alphabet Order',
          'Letter Sounds',
        ],
      );
      await tapVisible(tester, find.byTooltip('Back to home'));
      await tapVisible(tester, find.text('Numbers'));
      expect(find.text('Numbers'), findsOneWidget);
      expect(find.text(Activity.numbers.title), findsOneWidget);
      expect(find.byType(GamePage), findsNothing);
      expect(find.text('20–30'), findsNWidgets(2));
      await tapVisible(tester, find.text(Activity.numbers.title));
      expect(
        int.parse(device.clips.last.substring(7)),
        inInclusiveRange(20, 30),
      );
      await tapVisible(tester, find.byTooltip('Back to numbers'));
      expect(find.text('Numbers'), findsOneWidget);
    },
  );

  for (final category in GameCategory.values.where(
    (c) => c.activities.first.isRecognition,
  )) {
    testWidgets(
      '${category.name}: reward returns directly home and replay keeps its category',
      (tester) async {
        final device = MemoryDevice();
        await tester.pumpWidget(RainbowGardenApp(services: device));
        await settle(tester);
        await tapVisible(tester, find.text(category.title));
        await tapVisible(tester, find.text(category.activities.first.title));
        for (var replay = 0; replay < 2; replay++) {
          for (var i = 0; i < 5; i++) {
            await tapVisible(tester, find.text('Show a hint'));
            final target = tester
                .widgetList<Text>(find.byType(Text))
                .map((t) => t.data ?? '')
                .firstWhere((t) => RegExp(r'^Find [A-Za-z0-9]+$').hasMatch(t))
                .substring(5);
            await tapVisible(tester, find.byKey(ValueKey('choice-$target')));
            await tapVisible(tester, find.text(i == 4 ? 'Rewards' : 'Next'));
          }
          expect(device.xp, (replay + 1) * 50);
          if (replay == 0) {
            await nextLearningRound(tester);
            expect(
              tester.widget<GamePage>(find.byType(GamePage)).activity,
              category.activities.first,
            );
          }
        }
        await tapVisible(tester, find.text('Back to home'));
        expect(find.text('Hi, Player 1!'), findsOneWidget);
        expect(find.text('Level 2'), findsOneWidget);
        await tapVisible(tester, find.text(category.title));
        await tapVisible(tester, find.text(category.activities.first.title));
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(find.text(category.title), findsOneWidget);
      },
    );
  }

  testWidgets('rapid category and game taps create only one route each', (
    tester,
  ) async {
    await tester.pumpWidget(RainbowGardenApp(services: MemoryDevice()));
    await settle(tester);
    final letters = tester
        .widgetList<SelectionCard>(find.byType(SelectionCard))
        .first;
    letters.onTap!();
    letters.onTap!();
    await settle(tester);
    final game = tester
        .widgetList<SelectionCard>(find.byType(SelectionCard))
        .first;
    game.onTap!();
    game.onTap!();
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Letters'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Hi, Player 1!'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 640),
    const Size(640, 320),
    const Size(800, 1100),
  ]) {
    testWidgets('letter-case labels fit $size at 200% text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final device = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: device));
      await settle(tester);
      expect(
        find.text('Uppercase, lowercase, and matching letters'),
        findsNothing,
      );
      await tapVisible(tester, find.text('Letters'));
      for (final activity in GameCategory.letters.activities.where(
        (a) => a.isRecognition,
      )) {
        await tapVisible(tester, find.text(activity.title));
        expect(
          tester.widget<GamePage>(find.byType(GamePage)).activity,
          activity,
        );
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await settle(tester);
      }
      expect(find.text('Match the letter friends'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
