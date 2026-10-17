import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/tap_challenge_page.dart';
import 'package:rainbow_garden/widgets/tap_challenge_art.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;
import 'progress_test.dart' show SlowDevice;
import 'interface_layout_test.dart' show capture, loadCaptureFonts;

class ManualClock extends Stopwatch {
  Duration value = Duration.zero;
  @override
  Duration get elapsed => value;
  @override
  void reset() {
    super.reset();
    value = Duration.zero;
  }
}

Finder get targets => find.byWidgetPredicate(
  (w) =>
      w is FilledButton &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('tap-target-'),
);
Finder get goodTargets => find.byWidgetPredicate(
  (w) => w is Semantics && (w.properties.label?.contains('plus ') ?? false),
);
Future<void> advance(
  WidgetTester tester,
  ManualClock clock,
  int milliseconds,
) async {
  clock.value = Duration(milliseconds: milliseconds);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

Future<void> scoreSome(WidgetTester tester, ManualClock clock) async {
  final start = clock.value.inMilliseconds;
  for (var ms = start; ms < start + 6000; ms += 600) {
    await advance(tester, clock, ms);
    for (final element in goodTargets.evaluate().toList()) {
      final callback = (element.widget as Semantics).properties.onTap;
      expect(callback, isNotNull);
      callback!();
    }
    await tester.pump();
  }
}

Future<ProgressController> mount(
  WidgetTester tester,
  MemoryDevice device,
  ManualClock clock, {
  TapChallengeSkin skin = TapChallengeSkin.unicorn,
  bool accessible = false,
  Brightness brightness = Brightness.light,
  GlobalKey? boundary,
}) async {
  final c = ProgressController(device);
  await c.load();
  addTearDown(c.dispose);
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? GardenTheme.dark : GardenTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(accessibleNavigation: accessible, disableAnimations: true),
      child: child!,
    ),
    home: TapChallengePage(
      controller: c,
      clock: clock,
      random: Random(9),
      skin: skin,
    ),
  );
  await tester.pumpWidget(
    boundary == null ? app : RepaintBoundary(key: boundary, child: app),
  );
  await settle(tester);
  return c;
}

void main() {
  setUpAll(loadCaptureFonts);
  setUpAll(() async {
    final assets = await FoalAssets.load();
    await assets.ensurePoster("none-none");
  });
  testWidgets(
    'Reflex category opens Tap Challenge freely and Back returns through category',
    (tester) async {
      final d = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      expect(find.text('Adventure'), findsNothing);
      expect(find.textContaining('moves ready'), findsNothing);
      await tapVisible(tester, find.text('Reflex'));
      expect(find.text('Tap Challenge'), findsOneWidget);
      await tapVisible(tester, find.text('Tap Challenge'));
      expect(find.text('How many can you tap in 30 seconds?'), findsOneWidget);
      await tapVisible(tester, find.text('Start'));
      expect(targets, findsWidgets);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Reflex'), findsOneWidget);
      expect(find.text('Tap Challenge'), findsOneWidget);
      expect(d.xp, 0);
      expect(d.clips, isEmpty);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Hi, Player 1!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'timed play, one saved record, gifts, and free replay stay silent',
    (tester) async {
      final d = MemoryDevice(),
          clock = ManualClock(),
          c = await mount(tester, d, clock);
      await tapVisible(tester, find.text('Start'));
      await scoreSome(tester, clock);
      expect(c.progress!.xp, 0);
      await advance(tester, clock, 30000);
      await settle(tester);
      expect(find.text('New best! 50 XP earned!'), findsOneWidget);
      expect(find.text('Choose a reward'), findsOneWidget);
      expect(c.progress!.xp, 50);
      expect(c.progress!.tapChallengeHighScore, 12);
      await tapVisible(tester, find.text('Blue mane'));
      expect(c.progress!.owned, {'blue'});
      expect(c.progress!.xp, 50);
      await tapVisible(tester, find.text('Play again'));
      expect(find.text('30 seconds'), findsOneWidget);
      expect(find.text('Score: 0'), findsOneWidget);
      await advance(tester, clock, 30000);
      await settle(tester);
      expect(find.text('New best! 50 XP earned!'), findsNothing);
      expect(c.progress!.xp, 50);
      expect(find.text('Best: 12'), findsOneWidget);
      expect(d.clips, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a held pointer cannot activate a replacement target or repeat score',
    (tester) async {
      final d = MemoryDevice(), clock = ManualClock();
      await mount(tester, d, clock);
      await tapVisible(tester, find.text('Start'));
      final gesture = await tester.startGesture(
        tester.getCenter(targets.first),
      );
      await advance(tester, clock, 2400);
      await gesture.up();
      await tester.pump();
      expect(find.text('Score: 0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'background and resize pause exact active time and require Resume',
    (tester) async {
      final d = MemoryDevice(), clock = ManualClock();
      await mount(tester, d, clock);
      await tapVisible(tester, find.text('Start'));
      await advance(tester, clock, 2400);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(clock.isRunning, isFalse);
      await tester.pump(const Duration(minutes: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);
      await tapVisible(tester, find.text('Resume'));
      expect(clock.isRunning, isTrue);
      expect(find.text('28 seconds'), findsOneWidget);
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);
      expect(clock.isRunning, isFalse);
      expect(d.xp, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'covering the game pauses until explicit Resume after uncovering',
    (tester) async {
      final d = MemoryDevice(), clock = ManualClock();
      await mount(tester, d, clock);
      await tapVisible(tester, find.text('Start'));
      final context = tester.element(find.byType(TapChallengePage));
      final nav = Navigator.of(context);
      unawaited(
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await settle(tester);
      expect(clock.isRunning, isFalse);
      nav.pop();
      await settle(tester);
      expect(find.text('Resume'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed record retries after screen disposal with no duplicate XP',
    (tester) async {
      final d = SlowDevice(),
          clock = ManualClock(),
          c = await mount(tester, d, clock);
      await tapVisible(tester, find.text('Start'));
      await scoreSome(tester, clock);
      d.failSave = true;
      await advance(tester, clock, 30000);
      await settle(tester);
      expect(find.text('Try saving again'), findsOneWidget);
      expect(find.text('New best! 50 XP earned!'), findsNothing);
      expect(c.progress!.xp, 0);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Play again'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      d.failSave = false;
      await c.retry();
      expect(c.progress!.xp, 50);
      expect(c.progress!.tapChallengeHighScore, 12);
      await c.retry();
      expect(c.progress!.xp, 50);
    },
  );
  testWidgets(
    'delayed save does not announce XP before commit and same-screen retry updates result',
    (tester) async {
      final d = SlowDevice(),
          clock = ManualClock(),
          c = await mount(tester, d, clock);
      await tapVisible(tester, find.text('Start'));
      await scoreSome(tester, clock);
      d.pending = Completer<void>();
      d.failSave = true;
      await advance(tester, clock, 30000);
      expect(find.text('New best! 50 XP earned!'), findsNothing);
      expect(c.progress!.xp, 0);
      d.pending!.complete();
      await settle(tester);
      d.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(find.text('New best! 50 XP earned!'), findsOneWidget);
      expect(c.progress!.xp, 50);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'alternate companion skin changes names and pictures, never scoring',
    (tester) async {
      final skin = TapChallengeSkin(
        regular: TapTargetAppearance(
          label: 'Leaf',
          builder: (_) => const Icon(Icons.eco),
        ),
        bonus: TapTargetAppearance(
          label: 'Gem',
          builder: (_) => const Icon(Icons.diamond),
        ),
        hazard: TapTargetAppearance(
          label: 'Rock',
          builder: (_) => const Icon(Icons.circle),
        ),
      );
      final d = MemoryDevice()..haptics = false,
          clock = ManualClock(),
          c = await mount(tester, d, clock, skin: skin, accessible: true);
      expect(find.text('Tap Leaf · +1'), findsOneWidget);
      expect(find.text('Tap Gem · +3'), findsOneWidget);
      expect(find.text('Avoid Rock · -2'), findsOneWidget);
      await tapVisible(tester, find.text('Start'));
      final semantics = tester.ensureSemantics();
      await scoreSome(tester, clock);
      await advance(tester, clock, 6600);
      final target = targets.first;
      expect(
        tester
            .getSemantics(target)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await advance(tester, clock, 30000);
      await settle(tester);
      expect(c.progress!.tapChallengeHighScore, 12);
      expect(c.progress!.xp, 50);
      expect(d.feedbacks, isEmpty);
      expect(d.clips, isEmpty);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(740, 360),
    const Size(600, 960),
    const Size(800, 1100),
    const Size(1100, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        final name =
            '${size.width.toInt()}x${size.height.toInt()}-${scale.toInt()}x-${brightness.name}';
        testWidgets('entry, arena, pause and results fit $name', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final boundary = GlobalKey(),
              d = MemoryDevice(),
              clock = ManualClock();
          await mount(
            tester,
            d,
            clock,
            brightness: brightness,
            boundary: boundary,
          );
          expect(tester.takeException(), isNull);
          await capture(tester, boundary, 'tap-$name-entry', directory: '0170');
          await tapVisible(tester, find.text('Start'));
          await advance(tester, clock, 4200);
          for (final item in targets.evaluate()) {
            final rect = tester.getRect(find.byWidget(item.widget));
            expect(rect.width, greaterThanOrEqualTo(64));
            expect(rect.height, greaterThanOrEqualTo(64));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
          }
          expect(tester.takeException(), isNull);
          await capture(tester, boundary, 'tap-$name-play', directory: '0170');
          await tapVisible(tester, find.text('Pause'));
          expect(clock.isRunning, isFalse);
          await capture(tester, boundary, 'tap-$name-pause', directory: '0170');
          await tapVisible(tester, find.text('Resume'));
          await scoreSome(tester, clock);
          await advance(tester, clock, 30000);
          await settle(tester);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            boundary,
            'tap-$name-result',
            directory: '0170',
          );
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
