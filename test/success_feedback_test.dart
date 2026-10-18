import 'widget_test.dart' show nextLearningRound;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/widgets/success_celebration.dart';
import 'interface_refresh_test.dart' show target;
import 'widget_test.dart' show MemoryDevice, tapVisible, settle, rewardResult;

Finder get sparkles => find.byKey(const ValueKey('success-sparkles'));
Finder choice(String answer) => find.byKey(ValueKey('choice-$answer'));

class AudioDevice extends MemoryDevice {
  int stops = 0;
  @override
  Future<void> stop() async {
    stops++;
  }
}

Future<void> openGame(
  WidgetTester tester,
  AudioDevice device,
  GameRound round, {
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: GamePage(
        services: device,
        activity: round.activity,
        sound: true,
        round: round,
        onCompleteRound: (_) async => rewardResult(1),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  for (final activity in ActivityContent.recognition) {
    testWidgets(
      '${activity.name}: actual buttons use balanced positions through Next and Play again',
      (tester) async {
        final range = NumberRange(98, 100);
        final round = GameRound(
          activity,
          random: Random(42),
          numberRange: range,
        );
        final device = AudioDevice();
        var rounds = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: GamePage(
              services: device,
              activity: activity,
              sound: false,
              round: round,
              numberRange: range,
              onCompleteRound: (_) async => rewardResult(++rounds),
            ),
          ),
        );
        await settle(tester);
        for (var game = 0; game < 2; game++) {
          final positions = <int>[];
          for (var question = 0; question < 5; question++) {
            expect(
              tester.widget<CompanionView>(find.byType(CompanionView)).animate,
              isFalse,
            );
            await tapVisible(tester, find.text('Show a hint'));
            final value = target(tester);
            final buttons = tester
                .widgetList<FilledButton>(find.byType(FilledButton))
                .where(
                  (w) =>
                      w.key is ValueKey<String> &&
                      (w.key! as ValueKey<String>).value.startsWith('choice-'),
                )
                .toList();
            buttons.sort(
              (a, b) => tester
                  .getCenter(find.byKey(a.key!))
                  .dx
                  .compareTo(tester.getCenter(find.byKey(b.key!)).dx),
            );
            expect(buttons.length, 3);
            positions.add(
              buttons.indexWhere(
                (button) => button.key == ValueKey('choice-$value'),
              ),
            );
            if (game == 0) {
              expect(
                buttons.map((b) => (b.key! as ValueKey<String>).value),
                round.questions[question].choices.map((c) => 'choice-$c'),
              );
            }
            if (activity == Activity.numbers)
              expect(int.parse(value), inInclusiveRange(98, 100));
            if (question == 0) {
              final wrong = buttons.firstWhere(
                (b) => b.key != ValueKey('choice-$value'),
              );
              await tester.ensureVisible(find.byKey(wrong.key!));
              await settle(tester);
              final centers = buttons
                  .map((b) => tester.getCenter(find.byKey(b.key!)))
                  .toList();
              await tester.tap(find.byKey(wrong.key!));
              await settle(tester);
              expect(
                buttons
                    .map((b) => tester.getCenter(find.byKey(b.key!)))
                    .toList(),
                centers,
              );
              expect(sparkles, findsNothing);
            }
            await tapVisible(tester, choice(value));
            if (question < 4)
              await tapVisible(tester, find.text('Next'));
            else
              expect(find.text('50 XP earned!'), findsOneWidget);
          }
          final counts = List.generate(
            3,
            (slot) => positions.where((value) => value == slot).length,
          )..sort();
          expect(counts, [1, 2, 2]);
          expect(rounds, game + 1);
          if (game == 0) await nextLearningRound(tester);
        }
        expect(device.clips, isEmpty);
      },
    );
  }

  testWidgets(
    'correct answer stops speech, celebrates once, and leaves Next available',
    (tester) async {
      final device = AudioDevice();
      final round = GameRound(Activity.uppercase, random: Random(5));
      await openGame(tester, device, round);
      final wrong = round.question.choices.firstWhere(
        (c) => c != round.question.answer,
      );
      await tapVisible(tester, choice(wrong));
      expect(device.clips, [round.question.audio]);
      expect(sparkles, findsNothing);
      final answer = choice(round.question.answer);
      await tester.ensureVisible(answer);
      final centerBefore = tester.getCenter(answer);
      final widthBefore = tester.getSize(answer).width;
      await tester.tap(answer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sparkles, findsOneWidget);
      expect(tester.getCenter(answer), centerBefore);
      expect(tester.getSize(answer).width, widthBefore);
      expect(device.stops, 1);
      expect(device.clips, isNot(contains('correct')));
      expect(find.text('Next'), findsOneWidget);
      await tester.tap(answer);
      await tester.pump(const Duration(milliseconds: 500));
      expect(sparkles, findsNothing);
      expect(round.completed, 1);
      expect(device.stops, 1);
    },
  );

  testWidgets(
    'early Next and background cancel sparkles without replaying them',
    (tester) async {
      final device = AudioDevice();
      final round = GameRound(Activity.lowercase, random: Random(7));
      await openGame(tester, device, round);
      await tester.tap(choice(round.question.answer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sparkles, findsOneWidget);
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(sparkles, findsNothing);
      expect(device.clips.last, round.question.audio);
      await tester.tap(choice(round.question.answer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sparkles, findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(sparkles, findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(sparkles, findsNothing);
      expect(find.text('You found it! ✨'), findsOneWidget);
    },
  );

  testWidgets(
    'reduced motion uses static success without a sparkle animation',
    (tester) async {
      final device = AudioDevice();
      final round = GameRound(Activity.numbers, random: Random(8));
      await openGame(tester, device, round, reducedMotion: true);
      await tester.tap(choice(round.question.answer));
      await tester.pump();
      expect(sparkles, findsNothing);
      for (final effect in tester.widgetList<SuccessCelebration>(
        find.byType(SuccessCelebration),
      )) {
        expect(effect.active, isFalse);
        expect(effect.animation.status, AnimationStatus.dismissed);
      }
      expect(find.text('You found it! ✨'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(device.clips, isNot(contains('correct')));
    },
  );

  testWidgets('Back during celebration disposes the animation safely', (
    tester,
  ) async {
    final device = AudioDevice();
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    await tapVisible(tester, find.text('Letters'));
    await tapVisible(tester, find.text(Activity.uppercase.title));
    final target = device.clips.last.substring(6).toUpperCase();
    await tester.tap(choice(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(sparkles, findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Letters'), findsOneWidget);
    expect(sparkles, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
