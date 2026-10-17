import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/profiles.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/word_sprint_page.dart';
import 'package:rainbow_garden/widgets/sound_it_out.dart';
import 'package:rainbow_garden/word_sprint.dart';

class SprintDevice implements DeviceServices {
  String document = ProfileStore.initial().encode();
  int writes = 0, stops = 0;
  bool failSave = false, failAudio = false;
  Completer<void>? saveHold, audioHold;
  final clips = <String>[];
  final feedbacks = <DeviceFeedback>[];
  @override
  Future<String> loadProfiles() async => document;
  @override
  Future<void> saveProfiles(String value) async {
    writes++;
    await saveHold?.future;
    if (failSave) throw StateError('Unavailable');
    document = value;
  }

  @override
  Future<void> play(String clip) async {
    clips.add(clip);
    if (failAudio) throw StateError('Audio unavailable');
    await audioHold?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> feedback(DeviceFeedback kind) async {
    feedbacks.add(kind);
  }
}

class SprintController extends ProgressController {
  SprintController(super.services);
  int records = 0;
  @override
  Future<WordSprintResult> recordWordSprint(String id, int words) {
    records++;
    return super.recordWordSprint(id, words);
  }
}

Future<SprintController> mount(
  WidgetTester tester,
  SprintDevice device, {
  bool timed = true,
  int best = 0,
  double scale = 1,
  bool dark = false,
  bool reduced = false,
}) async {
  final c = SprintController(device);
  await c.load();
  if (!timed) await c.setWordSprintTimer(false);
  if (best > 0) await c.recordWordSprint('seed', best);
  c.records = 0;
  addTearDown(c.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? GardenTheme.dark : GardenTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => WordSprintPage(controller: c, services: device),
              ),
            ),
            child: const Text('Words'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Words'));
  await tester.pumpAndSettle();
  return c;
}

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> finishMinute(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 60));
  await tester.pump();
}

Finder word(int index) => find.byKey(ValueKey('sprint-word-$index'));

void main() {
  testWidgets('timer preference saves immediately and Start waits for saving', (
    tester,
  ) async {
    final d = SprintDevice(), c = await mount(tester, d);
    d.saveHold = Completer<void>();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(c.blocked.value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
          .onPressed,
      isNull,
    );
    d.saveHold!.complete();
    await tester.pumpAndSettle();
    expect(c.settings.wordSprintTimer, isFalse);
    expect(
      ProfileStore.decode(d.document).active.settings.wordSprintTimer,
      isFalse,
    );
    await tap(tester, 'Start');
    expect(find.text('Done'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('marks toggle with haptics and accessible toggle labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final d = SprintDevice(), c = await mount(tester, d);
    await tap(tester, 'Start');
    await tester.tap(word(0));
    await tester.pump();
    expect(find.text('Words read: 1'), findsOneWidget);
    expect(
      tester.getSemantics(word(0)).flagsCollection.isToggled,
      Tristate.isTrue,
    );
    expect(tester.getSemantics(word(0)).label, endsWith(', read'));
    expect(d.feedbacks, [DeviceFeedback.light]);
    await tester.tap(word(0));
    await tester.pump();
    expect(find.text('Words read: 0'), findsOneWidget);
    expect(tester.getSemantics(word(0)).label, endsWith(', not read'));
    expect(c.records, 0);
    expect(d.clips, isEmpty);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets(
    'completed minute records once, saves before celebrating, no XP',
    (tester) async {
      final d = SprintDevice(), c = await mount(tester, d);
      await tap(tester, 'Start');
      await tester.tap(word(0));
      await tester.pump();
      d.saveHold = Completer<void>();
      await finishMinute(tester);
      expect(find.text('You read 1 words!'), findsOneWidget);
      expect(find.text('New best!'), findsNothing);
      expect(find.text('Best: 1 words'), findsNothing);
      expect(c.records, 1);
      d.saveHold!.complete();
      await tester.pumpAndSettle();
      expect(find.text('New best!'), findsOneWidget);
      expect(find.text('Best: 1 words'), findsOneWidget);
      expect(c.progress!.wordSprintBest, 1);
      expect(c.progress!.xp, 0);
      expect(c.progress!.earnedRewardChoices, 0);
      await tester.pump(const Duration(seconds: 60));
      expect(c.records, 1);
      expect(d.clips, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final count in [0, 1]) {
    testWidgets('tie/lower ($count) shows saved best without celebration', (
      tester,
    ) async {
      final d = SprintDevice(), c = await mount(tester, d, best: 1);
      await tap(tester, 'Start');
      if (count > 0) await tester.tap(word(0));
      await finishMinute(tester);
      expect(find.text('Well read!'), findsOneWidget);
      expect(find.text('Best: 1 words'), findsOneWidget);
      expect(find.text('New best!'), findsNothing);
      expect(c.records, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final timed in [true, false]) {
    testWidgets('${timed ? 'Stop early' : 'untimed Done'} records nothing', (
      tester,
    ) async {
      final d = SprintDevice(), c = await mount(tester, d, timed: timed);
      await tap(tester, 'Start');
      await tester.tap(word(0));
      await tester.pump(const Duration(seconds: 2));
      await tap(tester, timed ? 'Stop' : 'Done');
      expect(find.text('You read 1 words!'), findsOneWidget);
      expect(find.textContaining('Best:'), findsNothing);
      expect(c.records, 0);
      await tap(tester, 'Play again');
      expect(find.text('Words read: 0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('long press opens sound help, freezes time, then resumes', (
    tester,
  ) async {
    final d = SprintDevice();
    await mount(tester, d);
    await tap(tester, 'Start');
    await tester.pump(const Duration(seconds: 5));
    await tester.longPress(word(0));
    await tester.pumpAndSettle();
    expect(find.byType(SoundItOut), findsOneWidget);
    expect(find.text('Words read: 0'), findsOneWidget);
    final remaining = tester
        .widget<Text>(find.byKey(const ValueKey('sprint-time')))
        .data;
    await tester.pump(const Duration(seconds: 30));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('sprint-time'))).data,
      remaining,
    );
    expect(d.clips, isEmpty);
    await tap(tester, 'Close');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('sprint-time'))).data,
      isNot(remaining),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'background pauses until explicit Resume, including during help',
    (tester) async {
      final d = SprintDevice();
      await mount(tester, d);
      await tap(tester, 'Start');
      await tester.longPress(word(0));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        tester.widget<SoundItOut>(find.byType(SoundItOut)).enabled,
        isFalse,
      );
      await tap(tester, 'Close');
      await tester.pumpAndSettle();
      expect(find.text('Resume'), findsOneWidget);
      await tester.pump(const Duration(seconds: 80));
      expect(find.text('Resume'), findsOneWidget);
      expect(find.textContaining('You read'), findsNothing);
      await tap(tester, 'Resume');
      await finishMinute(tester);
      expect(find.text('You read 0 words!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed best save retries exact result and celebrates only after success',
    (tester) async {
      final d = SprintDevice(), c = await mount(tester, d);
      await tap(tester, 'Start');
      await tester.tap(word(0));
      d.failSave = true;
      await finishMinute(tester);
      expect(find.text('You read 1 words!'), findsOneWidget);
      expect(find.text('Try saving again'), findsOneWidget);
      expect(find.text('New best!'), findsNothing);
      d.failSave = false;
      await tap(tester, 'Try saving again');
      await tester.pumpAndSettle();
      expect(find.text('New best!'), findsOneWidget);
      expect(c.progress!.wordSprintBest, 1);
      expect(c.records, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Back to words pops to category from start and results', (
    tester,
  ) async {
    final d = SprintDevice();
    await mount(tester, d);
    await tester.tap(find.byTooltip('Back to words'));
    await tester.pumpAndSettle();
    expect(find.text('Words'), findsOneWidget);
    await tap(tester, 'Words');
    await tester.pumpAndSettle();
    await tap(tester, 'Start');
    await tap(tester, 'Stop');
    await tap(tester, 'Back to words');
    await tester.pumpAndSettle();
    expect(find.text('Words'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('system Back cancels a nearly completed minute immediately', (
    tester,
  ) async {
    final d = SprintDevice(), c = await mount(tester, d);
    await tap(tester, 'Start');
    await tester.tap(word(0));
    await tester.pump(const Duration(milliseconds: 59900));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Words'), findsOneWidget);
    expect(c.records, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'sound help plays ordered steps, fails safely, and respects mute',
    (tester) async {
      final d = SprintDevice(), c = await mount(tester, d);
      await tap(tester, 'Start');
      await tester.longPress(word(0));
      await tester.pumpAndSettle();
      final play = tester
          .widget<SoundItOut>(find.byType(SoundItOut))
          .playSequence;
      final steps = <int>[];
      expect(
        await play([
          ['first', 'second'],
          ['third'],
        ], onStep: steps.add),
        isTrue,
      );
      expect(steps, [0, 1]);
      expect(d.clips, ['first', 'second', 'third']);
      d.failAudio = true;
      expect(
        await play([
          ['failed'],
          ['never'],
        ]),
        isFalse,
      );
      expect(d.clips.last, 'failed');
      await c.setSound(false);
      await tester.pump();
      expect(
        tester.widget<SoundItOut>(find.byType(SoundItOut)).soundOn,
        isFalse,
      );
      expect(
        await play([
          ['muted'],
        ]),
        isFalse,
      );
      expect(d.clips, isNot(contains('muted')));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final cancellation in ['close', 'background', 'mute', 'dispose']) {
    testWidgets('sound sequence cancels on $cancellation', (tester) async {
      final d = SprintDevice(), c = await mount(tester, d);
      await tap(tester, 'Start');
      await tester.longPress(word(0));
      await tester.pumpAndSettle();
      d.audioHold = Completer<void>();
      final result = tester
          .widget<SoundItOut>(find.byType(SoundItOut))
          .playSequence([
            ['first', 'second'],
            ['third'],
          ]);
      await tester.pump();
      expect(d.clips, ['first']);
      switch (cancellation) {
        case 'close':
          await tap(tester, 'Close');
          await tester.pumpAndSettle();
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        case 'mute':
          await c.setSound(false);
          await tester.pump();
        case 'dispose':
          await tester.pumpWidget(const SizedBox());
      }
      d.audioHold!.complete();
      await tester.pump();
      expect(await result, isFalse);
      expect(d.clips, ['first']);
      expect(d.stops, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('semantics Sound it out action opens help without marking', (
    tester,
  ) async {
    final d = SprintDevice();
    await mount(tester, d);
    await tap(tester, 'Start');
    final actions = tester
        .widget<Semantics>(word(0))
        .properties
        .customSemanticsActions!;
    expect(actions.keys.single.label, 'Sound it out');
    actions.values.single();
    await tester.pumpAndSettle();
    expect(find.byType(SoundItOut), findsOneWidget);
    expect(find.text('Words read: 0'), findsOneWidget);
    await tap(tester, 'Close');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('count and countdown remain visible while the grid scrolls', (
    tester,
  ) async {
    final d = SprintDevice();
    await mount(tester, d);
    await tap(tester, 'Start');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    final gridTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(
      tester.getBottomLeft(find.text('Words read: 0')).dy,
      lessThanOrEqualTo(gridTop),
    );
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('sprint-time'))).dy,
      lessThanOrEqualTo(gridTop),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('320px 2x mode cards wrap and expose exclusive selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await mount(tester, SprintDevice(), scale: 2);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('sprint-mode-mix')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    for (final mode in WordSprintMode.values) {
      final option = find.byKey(ValueKey('sprint-mode-${mode.name}'));
      expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(option).width, lessThanOrEqualTo(320));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      expect(
        tester.getSemantics(option).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      for (final other in WordSprintMode.values.where(
        (other) => other != mode,
      )) {
        expect(
          tester
              .getSemantics(find.byKey(ValueKey('sprint-mode-${other.name}')))
              .flagsCollection
              .isSelected,
          Tristate.isFalse,
        );
      }
      expect(
        find.descendant(of: option, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('marking leaves the word centered in the same card position', (
    tester,
  ) async {
    await mount(tester, SprintDevice());
    await tap(tester, 'Start');
    final text = find.descendant(of: word(0), matching: find.byType(Text));
    final before = tester.getRect(text);
    final card = tester.getRect(word(0));
    expect(before.center.dy, closeTo(card.center.dy, .01));
    await tester.tap(word(0));
    await tester.pump();
    expect(tester.getRect(text), before);
    expect(tester.getRect(word(0)), card);
    expect(
      find.descendant(of: word(0), matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('740x360 2x shows a full word row and reachable Stop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, SprintDevice(), scale: 2, dark: true);
    await tap(tester, 'Start');
    final viewport = tester.getRect(find.byType(CustomScrollView));
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final columns =
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;
    for (var i = 0; i < columns; i++) {
      final card = tester.getRect(word(i));
      expect(card.top, greaterThanOrEqualTo(viewport.top));
      expect(card.bottom, lessThanOrEqualTo(viewport.bottom));
    }
    final count = tester.getRect(find.text('Words read: 0'));
    final countdown = tester.getRect(find.byKey(const ValueKey('sprint-time')));
    expect(
      count.overlaps(
        Rect.fromLTRB(count.left, countdown.top, count.right, countdown.bottom),
      ),
      isTrue,
    );
    final stop = find.widgetWithText(OutlinedButton, 'Stop');
    expect(tester.getRect(stop).bottom, lessThanOrEqualTo(360));
    expect(stop.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(stop);
    await tester.pump();
    expect(find.text('You read 0 words!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [360.0, 800.0]) {
    testWidgets('grid uses ${width < 600 ? 3 : 5} columns at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = SprintDevice();
      await mount(tester, d);
      await tap(tester, 'Start');
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        width < 600 ? 3 : 5,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      '360x640 2x text ${dark ? 'dark' : 'light'} and reduced motion',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final d = SprintDevice();
        await mount(tester, d, dark: dark, scale: 2, reduced: true);
        expect(tester.takeException(), isNull);
        await tap(tester, 'Start');
        await tester.scrollUntilVisible(
          word(0),
          150,
          scrollable: find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(word(0));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.longPress(word(0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tap(tester, 'Close');
        await tester.pumpAndSettle();
        await finishMinute(tester);
        expect(find.text('New best!'), findsOneWidget);
        expect(find.byKey(const ValueKey('success-sparkles')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
