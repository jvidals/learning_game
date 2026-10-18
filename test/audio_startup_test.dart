import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'widget_test.dart' show MemoryDevice, rewardResult, settle, tapVisible;

void main() {
  for (final entry in [
    ('Letters', Activity.uppercase.title),
    ('Letters', Activity.lowercase.title),
    ('Letters', Activity.matching.title),
    ('Numbers', Activity.numbers.title),
    ('Words', 'Sight Words'),
  ]) {
    testWidgets(
      '${entry.$2} speaks once after entrance; replay stays immediate',
      (tester) async {
        final device = MemoryDevice();
        await tester.pumpWidget(RainbowGardenApp(services: device));
        await settle(tester);
        await tapVisible(tester, find.text(entry.$1));
        await tester.tap(find.text(entry.$2));
        await tester.pump();
        expect(device.clips, isEmpty);
        await tester.pump(const Duration(milliseconds: 250));
        expect(device.clips, isEmpty);
        await settle(tester);
        expect(device.clips, hasLength(1));
        final first = device.clips.single;
        await tester.tap(find.text('Listen again'));
        await tester.pump();
        expect(device.clips, [first, first]);
        await settle(tester);
        expect(device.clips, [first, first]);
      },
    );
  }

  for (final duration in [Duration.zero, const Duration(milliseconds: 1200)]) {
    testWidgets('entrance uses actual duration $duration with reduced motion', (
      tester,
    ) async {
      final d = MemoryDevice();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      nav.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: duration,
          pageBuilder: (context, _, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: GamePage(
              services: d,
              activity: Activity.uppercase,
              sound: true,
              onCompleteRound: (_) async => rewardResult(1),
            ),
          ),
        ),
      );
      await tester.pump();
      if (duration != Duration.zero) {
        await tester.pump(const Duration(milliseconds: 600));
        expect(d.clips, isEmpty);
        await tester.pump(const Duration(milliseconds: 700));
      }
      await tester.pump();
      expect(d.clips, hasLength(1));
      await settle(tester);
      expect(d.clips, hasLength(1));
    });
  }

  for (final interruption in [
    'mute',
    'answer',
    'replay',
    'background',
    'cover',
    'back',
    'dispose',
  ]) {
    testWidgets('$interruption cancels deferred entrance speech', (
      tester,
    ) async {
      final d = MemoryDevice();
      final nav = GlobalKey<NavigatorState>();
      final round = GameRound(Activity.uppercase, random: Random(17));
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      nav.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 1200),
          pageBuilder: (_, _, _) => GamePage(
            services: d,
            activity: Activity.uppercase,
            sound: true,
            round: round,
            onCompleteRound: (_) async => rewardResult(1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(d.clips, isEmpty);
      switch (interruption) {
        case 'mute':
          await tester.tap(find.byTooltip('Turn voice off'));
        case 'answer':
          await tester.tap(
            find.byKey(ValueKey('choice-${round.question.answer}')),
          );
        case 'replay':
          await tester.tap(find.text('Listen again'));
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        case 'cover':
          nav.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => const Scaffold()),
          );
        case 'back':
          nav.currentState!.pop();
        case 'dispose':
          await tester.pumpWidget(const SizedBox());
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(d.clips.length, interruption == 'replay' ? 1 : 0);
      if (interruption == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      } else if (interruption == 'cover') {
        nav.currentState!.pop();
      }
      await settle(tester);
      expect(d.clips.length, interruption == 'replay' ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }
}
