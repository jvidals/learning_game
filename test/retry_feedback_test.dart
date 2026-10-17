import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;
import 'success_feedback_test.dart' show choice, sparkles;

final marker = find.byKey(const ValueKey('retry-marker'));

double opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: marker, matching: find.byType(Opacity)).first,
    )
    .opacity;

class FailingFeedback extends MemoryDevice {
  @override
  Future<void> feedback(DeviceFeedback kind) async =>
      throw PlatformException(code: 'unavailable');
}

Future<GameRound> open(
  WidgetTester tester,
  MemoryDevice device, {
  Activity activity = Activity.numbers,
  bool reduced = false,
  GlobalKey<NavigatorState>? navigator,
}) async {
  final controller = ProgressController(device);
  await controller.load();
  addTearDown(controller.dispose);
  final round = GameRound(activity, random: Random(42));
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: GamePage(
        services: device,
        activity: activity,
        sound: true,
        controller: controller,
        round: round,
        onCompleteRound: controller.completeRound,
      ),
    ),
  );
  await settle(tester);
  await tester.ensureVisible(choice(round.question.choices.first));
  await tester.pump();
  return round;
}

void main() {
  for (final activity in ActivityContent.recognition) {
    for (final manual in [true, false]) {
      testWidgets(
        '${activity.name}, manual=$manual: retry replaces, throttles, fades; correction stays immediate',
        (tester) async {
          final d = MemoryDevice()..tapNext = manual;
          final round = await open(tester, d, activity: activity);
          final wrong = round.question.choices
              .where((c) => c != round.question.answer)
              .toList();
          final bounds = tester.getRect(choice(wrong[0]));
          await tester.tap(choice(wrong[0]));
          await tester.pump();
          expect(marker, findsOneWidget);
          expect(tester.getRect(choice(wrong[0])), bounds);
          expect(tester.getSize(marker), const Size(24, 24));
          expect(opacity(tester), 1);
          expect(find.text('Try again'), findsOneWidget);
          expect(
            d.clips,
            activity.hasSpokenTarget ? [round.question.audio] : isEmpty,
          );
          expect(d.feedbacks, [DeviceFeedback.retry]);
          await tester.pump(const Duration(milliseconds: 150));
          expect(opacity(tester), 1);
          await tester.tap(choice(wrong[0])); // Must not restart the fade.
          await tester.pump(const Duration(milliseconds: 225));
          expect(opacity(tester), closeTo(.5, .01));
          await tester.tap(choice(wrong[1]));
          await tester.pump();
          expect(opacity(tester), 1);
          expect(
            tester.getCenter(marker).dx,
            greaterThan(tester.getCenter(choice(wrong[1])).dx),
          );
          expect(d.feedbacks, [DeviceFeedback.retry]);
          await tester.pump(
            const Duration(milliseconds: 225),
          ); // First cue's cooldown ends.
          await tester.tap(choice(wrong[0]));
          await tester.pump();
          expect(d.feedbacks, [DeviceFeedback.retry, DeviceFeedback.retry]);
          await tester.pump(const Duration(milliseconds: 599));
          expect(marker, findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1));
          expect(marker, findsNothing);
          await tester.tap(choice(wrong[0]));
          await tester.pump();
          expect(marker, findsOneWidget);
          await tester.tap(choice(round.question.answer));
          await tester.pump();
          expect(marker, findsNothing);
          await tester.pump(const Duration(milliseconds: 16));
          expect(sparkles, findsOneWidget);
          expect(round.completed, 1);
          expect(d.feedbacks.last, DeviceFeedback.light);
          expect(d.writes, 0);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'reduced motion is static for 600 ms; marker has no semantics or hit handling',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final d = MemoryDevice()..haptics = false;
      final round = await open(tester, d, reduced: true);
      final wrong = round.question.choices.firstWhere(
        (c) => c != round.question.answer,
      );
      await tester.tap(choice(wrong));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 599));
      expect(opacity(tester), 1);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: marker, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );
      expect(
        find.ancestor(of: marker, matching: find.byType(ExcludeSemantics)),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.text('Try again'))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      expect(d.feedbacks, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(marker, findsNothing);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'background, route coverage and disposal cancel retry without restoring it',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final d = MemoryDevice();
      final round = await open(tester, d, navigator: nav);
      final wrong = round.question.choices.firstWhere(
        (c) => c != round.question.answer,
      );
      await tester.tap(choice(wrong));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(marker, findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(marker, findsNothing);
      await tester.tap(choice(wrong));
      await tester.pump();
      unawaited(
        showDialog<void>(
          context: nav.currentContext!,
          builder: (_) => const AlertDialog(title: Text('Covered')),
        ),
      );
      await tester.pump();
      expect(marker, findsNothing);
      nav.currentState!.pop();
      await settle(tester);
      expect(marker, findsNothing);
      await tester.tap(choice(wrong));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('platform failures keep retry, hints and correction available', (
    tester,
  ) async {
    final d = FailingFeedback()..failAudio = true;
    final round = await open(tester, d);
    await tester.tap(
      choice(
        round.question.choices.firstWhere((c) => c != round.question.answer),
      ),
    );
    await tester.pump();
    expect(marker, findsOneWidget);
    expect(find.text('Find ${round.question.answer}'), findsNothing);
    await tapVisible(tester, find.text('Show a hint'));
    expect(find.text('Find ${round.question.answer}'), findsOneWidget);
    await tester.tap(choice(round.question.answer));
    await tester.pump();
    expect(round.completed, 1);
    expect(marker, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
