import 'widget_test.dart' show nextLearningRound;
import 'package:rainbow_garden/profiles.dart';
import 'package:rainbow_garden/widgets/counting_board.dart';
import 'package:rainbow_garden/letter_sounds.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'settings_test.dart' show unlock;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

String target(WidgetTester tester) {
  final page = tester.widget<GamePage>(find.byType(GamePage));
  if (page.activity.isCounting) {
    return '${tester.widget<CountingBoard>(find.byType(CountingBoard)).scene.quantity}';
  }
  if (page.activity == Activity.letterSounds) {
    final hints = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((t) => t.contains(' — '));
    if (hints.isNotEmpty) return hints.first.split(' — ').first;
    final sound = (page.services as MemoryDevice).clips.last.substring(6);
    final choices = tester
        .widgetList<FilledButton>(find.byType(FilledButton))
        .where(
          (b) =>
              b.key is ValueKey<String> &&
              (b.key as ValueKey<String>).value.startsWith('choice-'),
        )
        .map((b) => (b.key as ValueKey<String>).value.substring(7));
    return choices.singleWhere((c) => soundFor(c).phoneme == sound);
  }
  if (page.activity == Activity.matching) {
    final partner = tester
        .widgetList<Text>(find.byType(Text))
        .singleWhere((t) => t.style?.fontSize == 66)
        .data!;
    return partner == partner.toUpperCase()
        ? partner.toLowerCase()
        : partner.toUpperCase();
  }
  final hints = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((t) => RegExp(r'^Find [a-zA-Z0-9]+$').hasMatch(t));
  if (hints.isNotEmpty) return hints.first.substring(5);
  // In voiced questions the target is observable through the recorded prompt.
  final clip = (page.services as MemoryDevice).clips.last;
  final value = clip.substring(clip.indexOf('_') + 1);
  return (clip.startsWith('upper_') || clip == 'word_i')
      ? value.toUpperCase()
      : value;
}

Finder answer(String value) => find.byKey(ValueKey('choice-$value'));
CompanionPainter pet(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<CompanionPainter>()
    .first;

Future<ProgressController> game(
  WidgetTester tester,
  MemoryDevice device, {
  Activity activity = Activity.uppercase,
  bool accessible = false,
  bool reduced = false,
  GlobalKey<NavigatorState>? navigator,
}) async {
  final controller = ProgressController(device);
  await controller.load();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          accessibleNavigation: accessible,
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: GamePage(
        services: device,
        activity: activity,
        sound: true,
        controller: controller,
        round: GameRound(activity, random: Random(9)),
        onCompleteRound: controller.completeRound,
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  test('old and absent settings default on; false values round trip', () {
    for (final map in [
      null,
      <String, dynamic>{'relaxed': true},
    ]) {
      final settings = AppSettings.fromMap(map);
      expect(settings.tapNext, isTrue);
      expect(settings.haptics, isTrue);
      expect(settings.soundOn, isTrue);
    }
    final settings = AppSettings.fromMap(
      const AppSettings(tapNext: false, haptics: false, soundOn: false).toMap(),
    );
    expect(settings.tapNext, isFalse);
    expect(settings.haptics, isFalse);
    expect(settings.soundOn, isFalse);
  });

  testWidgets(
    'native channel carries settings and typed feedback; optional feedback failure is harmless',
    (tester) async {
      const channel = MethodChannel('rainbow_garden/device');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'loadProfiles') {
          final initial = ProfileStore.decode(call.arguments as String);
          return initial
              .replace(
                initial.active.copyWith(
                  settings: const AppSettings(
                    tapNext: false,
                    haptics: false,
                    soundOn: false,
                  ),
                ),
              )
              .encode();
        }
        if (call.method == 'feedback')
          throw PlatformException(code: 'unavailable');
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final device = AndroidServices();
      final store = ProfileStore.decode(await device.loadProfiles());
      final loaded = store.active.settings;
      expect(loaded.tapNext, isFalse);
      expect(loaded.haptics, isFalse);
      expect(loaded.soundOn, isFalse);
      await device.saveProfiles(store.encode());
      expect(calls.last.method, 'saveProfiles');
      expect(calls.last.arguments, store.encode());
      await device.feedback(DeviceFeedback.confirm);
      expect(calls.last.arguments, 'confirm');
      await device.feedback(DeviceFeedback.retry);
      expect(calls.last.arguments, 'retry');
      await device.feedback(DeviceFeedback.placement);
      expect(calls.last.arguments, 'placement');
    },
  );

  for (final activity in ActivityContent.recognition) {
    for (final manual in [true, false]) {
      testWidgets(
        '${activity.name}: tapNext=$manual, two rounds balance slots and complete inline',
        (tester) async {
          final device = MemoryDevice()..tapNext = manual;
          await game(tester, device, activity: activity);
          for (var round = 0; round < 2; round++) {
            final positions = <int>[];
            for (var q = 0; q < 5; q++) {
              final value = target(tester);
              final buttons = tester
                  .widgetList<FilledButton>(find.byType(FilledButton))
                  .where((b) => b.key.toString().contains('choice-'))
                  .toList();
              positions.add(
                buttons.indexWhere((b) => b.key == ValueKey('choice-$value')),
              );
              await tester.ensureVisible(answer(value));
              await tester.tap(answer(value));
              await tester.pump();
              final cueCount = device.feedbacks.length;
              await tester.tap(answer(value));
              await tester.pump(const Duration(milliseconds: 100));
              expect(device.feedbacks.length, cueCount);
              expect(pet(tester).happy, isTrue);
              for (var star = 0; star < 5; star++) {
                final transform = tester.widget<Transform>(
                  find.byKey(ValueKey('progress-star-$star')),
                );
                expect(
                  transform.transform.storage[0],
                  star == q ? greaterThan(1) : 1,
                );
              }
              await tester.pump(const Duration(milliseconds: 699));
              expect(target(tester), value);
              if (q == 4) {
                expect(find.text('50 XP earned!'), findsOneWidget);
                expect(find.text('Rewards'), findsOneWidget);
                await tapVisible(tester, find.text('Rewards'));
              } else if (manual) {
                expect(find.text('Next'), findsOneWidget);
                await tapVisible(tester, find.text('Next'));
              } else {
                expect(find.text('Next'), findsNothing);
                await tester.pump(const Duration(milliseconds: 1));
                await tester.pump();
                expect(find.text('You found it! ✨'), findsNothing);
              }
            }
            final counts = List.generate(
              3,
              (slot) => positions.where((p) => p == slot).length,
            )..sort();
            expect(counts, [1, 2, 2]);
            expect(device.xp, (round + 1) * 50);
            if (round == 0) await nextLearningRound(tester);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'automatic transition restarts after background and covered routes; feedback does not replay',
    (tester) async {
      final device = MemoryDevice()..tapNext = false;
      final navigator = GlobalKey<NavigatorState>();
      await game(tester, device, navigator: navigator);
      final first = target(tester);
      await tester.tap(answer(first));
      await tester.pump(const Duration(milliseconds: 400));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(target(tester), first);
      expect(pet(tester).happy, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 799));
      expect(target(tester), first);
      await tester.pump(const Duration(milliseconds: 1));
      final second = target(tester);
      expect(second, isNot(first));
      await tester.tap(answer(second));
      await tester.pump(const Duration(milliseconds: 400));
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(title: Text('Covered')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 799));
      expect(target(tester), second);
      expect(pet(tester).happy, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(target(tester), isNot(second));
      expect(device.feedbacks, [DeviceFeedback.light, DeviceFeedback.light]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final accessible in [true, false]) {
    testWidgets(
      'reduced motion stays static; accessible=$accessible overrides auto pacing',
      (tester) async {
        final d = MemoryDevice()
          ..tapNext = false
          ..haptics = false;
        await game(tester, d, accessible: accessible, reduced: true);
        final value = target(tester);
        await tester.tap(answer(value));
        await tester.pump();
        expect(pet(tester).happy, isTrue);
        expect(pet(tester).phase, 0);
        expect(
          tester
              .widget<Transform>(find.byKey(const ValueKey('progress-star-0')))
              .transform
              .storage[0],
          1,
        );
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text('Next'), accessible ? findsOneWidget : findsNothing);
        expect(target(tester) == value, accessible);
        expect(d.feedbacks, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'failed XP save keeps fifth paused; saved level-up celebrates once before optional review',
    (tester) async {
      final d = MemoryDevice()
        ..tapNext = false
        ..failSave = true;
      await game(tester, d);
      for (var i = 0; i < 5; i++) {
        await tester.tap(answer(target(tester)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
      }
      expect(d.xp, 0);
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
      expect(d.feedbacks.where((f) => f == DeviceFeedback.confirm), isEmpty);
      d.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(d.xp, 50);
      await tester.ensureVisible(find.text('Rewards'));
      await tester.tap(find.text('Rewards'));
      await tester.pump();
      expect(find.text('Level up!'), findsOneWidget);
      expect(d.feedbacks.where((f) => f == DeviceFeedback.confirm).length, 1);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(d.feedbacks.where((f) => f == DeviceFeedback.confirm).length, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(d.feedbacks.where((f) => f == DeviceFeedback.confirm).length, 1);
      expect(d.feedbacks.where((f) => f == DeviceFeedback.confirm).length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'automatic settings and Back, retained failed retry and reset preserve all switches',
    (tester) async {
      final d = MemoryDevice()..soundOn = false;
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      await unlock(tester);
      await tapVisible(tester, find.text('Tap Next'));
      await tapVisible(tester, find.text('Haptics'));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(d.tapNext, isFalse);
      expect(d.haptics, isFalse);
      expect(d.soundOn, isFalse);
      await unlock(tester);
      d.failSave = true;
      await tapVisible(tester, find.text('Tap Next'));
      await tapVisible(tester, find.text('Haptics'));
      expect(d.tapNext, isFalse);
      d.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(d.tapNext, isTrue);
      expect(d.haptics, isTrue);
      expect(d.soundOn, isFalse);
      await tapVisible(tester, find.text('Reset progress'));
      await tapVisible(tester, find.text('Reset progress').last);
      expect(d.tapNext, isTrue);
      expect(d.haptics, isTrue);
      expect(d.soundOn, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final xp in [0, 50, 150, 2700]) {
    testWidgets('home badge and pet at $xp XP; sound toggle is silent', (
      tester,
    ) async {
      final d = MemoryDevice()..xp = xp;
      final count = xp == 0
          ? 0
          : xp == 50
          ? 1
          : xp == 150
          ? 2
          : 12;
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.semanticsLabel ==
                  (count > 0
                      ? 'My Unicorn, $count rewards available'
                      : 'My Unicorn'),
        ),
        findsOneWidget,
      );
      expect(find.byType(Badge), count > 0 ? findsOneWidget : findsNothing);
      await tester.tap(find.bySemanticsLabel('Pet your unicorn'));
      await tester.pump();
      expect(pet(tester).happy, isTrue);
      await tester.tap(find.bySemanticsLabel('Pet your unicorn'));
      expect(d.feedbacks, [DeviceFeedback.light]);
      await tester.pump(const Duration(milliseconds: 550));
      expect(pet(tester).happy, isFalse);
      await tapVisible(tester, find.byTooltip('Turn sound off'));
      await tapVisible(tester, find.byTooltip('Turn sound on'));
      expect(d.clips, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('home updates to centered plain button after final gift saves', (
    tester,
  ) async {
    final d = MemoryDevice()..xp = 50;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(RainbowGardenApp(services: d));
    await settle(tester);
    expect(
      find.bySemanticsLabel('My Unicorn, 1 rewards available'),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('My Unicorn'));
    await tapVisible(
      tester,
      find.byTooltip('Choose a unicorn surprise (1 ready)'),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('companion-choice-mane-blue')),
    );
    expect(PlayerProgress.decode(d.document).availableChoices, 0);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.bySemanticsLabel('My Unicorn'), findsOneWidget);
    expect(find.byIcon(Icons.card_giftcard_rounded), findsNothing);
    final label = tester.getCenter(find.text('My Unicorn'));
    final button = tester.getCenter(
      find.ancestor(
        of: find.text('My Unicorn'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(label, button);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets(
    'saved equipment appears inside puzzle rainbow; successful retry adds one cue',
    (tester) async {
      final d = MemoryDevice()..xp = 50;
      final c = await game(tester, d);
      d.failSave = true;
      await expectLater(c.choose('blue'), throwsStateError);
      expect(d.feedbacks, isEmpty);
      d.failSave = false;
      await c.retry();
      await tester.pump();
      expect(pet(tester).configuration[RewardCategory.mane], 'blue');
      expect(d.feedbacks, [DeviceFeedback.light]);
      await c.retry();
      expect(d.feedbacks.length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
