import 'dart:math';
import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/counting.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/widgets/counting_board.dart';

import 'learning_expansion_widgets_test.dart' as games;
import 'interface_layout_test.dart' show capture, loadCaptureFonts;
import 'widget_test.dart' show MemoryDevice, tapVisible;

void expectSeparate(CountingWork work) {
  final points = work.positions.values.toList();
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    expect(p.x, inInclusiveRange(28, work.trayWidth - 28));
    expect(p.y, inInclusiveRange(28, work.trayHeight - 28));
    for (var j = 0; j < i; j++) {
      expect(
        (p.x - points[j].x).abs() >= 47 - .001 ||
            (p.y - points[j].y).abs() >= 47 - .001,
        isTrue,
      );
    }
  }
}

void main() {
  setUpAll(loadCaptureFonts);
  test('places at the tap, clamps edges and nudges only the new object', () {
    final work = CountingWork(10)..resizeTray(320);
    work.add(position: const Point(130, 60));
    expect(work.positions[0], const Point(130.0, 60.0));
    work.add(position: const Point(150, 60));
    expect(work.positions[0], const Point(130.0, 60.0));
    expect(work.positions[1], const Point(177.0, 60.0));
    work.add(position: const Point(10, 10));
    expect(work.positions[2], const Point(28.0, 28.0));
    expect(work.add(position: const Point(500, 500)), isFalse);
    expectSeparate(work);
  });

  test('icons fit 47 dp apart with half the old picture gap', () {
    final work = CountingWork(10);
    expect(work.add(position: const Point(100, 65)), isTrue);
    expect(work.add(position: const Point(147, 65)), isTrue);
    expect(work.positions[1], const Point(147.0, 65.0));
    expect(work.positions[1]!.x - work.positions[0]!.x - 38, 9);
    expectSeparate(work);
    final added = CountingWork(10)
      ..add()
      ..add();
    expect(added.positions[1]!.x - added.positions[0]!.x, 47);
  });

  test('Add fills capacity, removes without moving, and caps at maximum', () {
    final work = CountingWork(20);
    final initialHeight = work.trayHeight;
    for (var i = 0; i < 20; i++) {
      expect(work.add(), isTrue);
      expectSeparate(work);
    }
    expect(work.add(), isFalse);
    final before = Map<int, Point<double>>.of(work.positions);
    final height = work.trayHeight;
    expect(height, greaterThanOrEqualTo(initialHeight));
    work.remove(4);
    before.remove(4);
    expect(work.positions, before);
    expect(work.trayHeight, height);
    expect(work.add(), isTrue);
    expectSeparate(work);
  });

  test('resize preserves IDs, resolves collisions and remains stable', () {
    final work = CountingWork(20)..resizeTray(680);
    for (var i = 0; i < 20; i++) {
      work.add();
    }
    final ids = List<int>.of(work.items);
    work.resizeTray(280);
    expect(work.items, ids);
    expectSeparate(work);
    final positions = Map<int, Point<double>>.of(work.positions);
    work.resizeTray(280);
    expect(work.positions, positions);
    work.resizeTray(680);
    expectSeparate(work);
  });

  test(
    'scattered taps stay nearby and Add fills capacity after rejections',
    () {
      for (var maximum = 2; maximum <= 20; maximum++) {
        final work = CountingWork(maximum)..resizeTray(360);
        final random = Random(maximum);
        for (var i = 0; i < maximum; i++) {
          final requested = Point(
            random.nextDouble() * work.trayWidth,
            random.nextDouble() * work.trayHeight,
          );
          if (work.add(position: requested)) {
            expect(
              work.positions[work.items.last]!.distanceTo(requested),
              lessThanOrEqualTo(38),
            );
          }
          expectSeparate(work);
        }
        while (work.items.length < maximum) {
          expect(work.add(), isTrue);
        }
        work.resizeTray(280);
        expectSeparate(work);
        expect(work.items.length, maximum);
      }
    },
  );

  test('a crowded single row extends without moving the first counter', () {
    final work = CountingWork(5);
    work.add(position: const Point(70, 38));
    final first = work.positions[0];
    final initialHeight = work.trayHeight;
    for (var i = 1; i < 5; i++) {
      work.add();
    }
    expect(work.trayHeight, greaterThan(initialHeight));
    expect(work.positions[0], first);
    expectSeparate(work);
  });

  test(
    'nearby limit accepts 38 and rejects larger horizontal or diagonal moves',
    () {
      final horizontal = CountingWork(10);
      expect(horizontal.add(position: const Point(-10, 60)), isTrue);
      expect(horizontal.positions[0], const Point(28.0, 60.0));
      final outside = CountingWork(10);
      expect(outside.add(position: const Point(-10.01, 60)), isFalse);
      final diagonal = CountingWork(10);
      expect(diagonal.add(position: const Point(0, 0)), isFalse);
      expect(diagonal.add(position: const Point(2, 2)), isTrue);
      expect(diagonal.positions[0], const Point(28.0, 28.0));
    },
  );

  test('blocked cluster taps preserve counters, IDs and tray dimensions', () {
    final work = CountingWork(10);
    work.add(position: const Point(100, 65));
    work.add(position: const Point(156, 65));
    final before = Map<int, Point<double>>.of(work.positions);
    final height = work.trayHeight;
    for (final tap in [const Point(128.0, 65.0), const Point(124.0, 65.0)]) {
      expect(work.add(position: tap), isFalse);
      expect(work.positions, before);
      expect(work.items, [0, 1]);
      expect(work.trayHeight, height);
    }
    expect(work.add(position: const Point(240, 65)), isTrue);
    expect(work.items, [0, 1, 2]);
  });

  test('tap never grows a packed tray but Add still can', () {
    final work = CountingWork(5);
    for (final x in [28.0, 100.0, 172.0, 244.0]) {
      expect(work.add(position: Point(x, 38)), isTrue);
    }
    final height = work.trayHeight;
    expect(work.add(position: const Point(60, 60)), isFalse);
    expect(work.trayHeight, height);
    expect(work.add(), isTrue);
    expect(work.trayHeight, greaterThan(height));
    expectSeparate(work);
  });

  Future<void> showBoard(
    WidgetTester tester,
    CountingWork work, {
    bool enabled = true,
    bool hint = false,
    CountingScene? scene,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  CountingBoard(
                    scene: scene ?? CountingScene(3, Random(7)),
                    work: work,
                    makeGroup: true,
                    maximum: work.maximum,
                    hint: hint,
                    enabled: enabled,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('empty-space taps place precisely; object taps only remove', (
    tester,
  ) async {
    final work = CountingWork(10);
    await showBoard(tester, work);
    final tray = find.byKey(const ValueKey('counting-collection'));
    final location = tester.getTopLeft(tray) + const Offset(150, 65);
    await tester.tapAt(location);
    await tester.pump();
    expect(work.items, [0]);
    expect(
      tester.getCenter(find.byKey(const ValueKey('count-object-0'))),
      location,
    );
    await tester.tap(find.byKey(const ValueKey('add-count-object')));
    await tester.pump();
    expect(work.items.length, 2);
    final second = work.positions[1];
    await tester.tapAt(location);
    await tester.pump();
    expect(work.items, [1]);
    expect(work.positions[1], second);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nearby taps add instead of removing through invisible padding', (
    tester,
  ) async {
    final work = CountingWork(10);
    await showBoard(tester, work);
    final center =
        tester.getTopLeft(find.byKey(const ValueKey('counting-collection'))) +
        const Offset(150, 65);
    await tester.tapAt(center);
    await tester.pump();
    final original = work.positions[0];
    // Inside the old 56 dp target, but outside the 38 dp picture.
    await tester.tapAt(center + const Offset(24, 0));
    await tester.pump();
    expect(work.items, [0, 1]);
    expect(work.positions[0], original);
    expectSeparate(work);
    await tester.tapAt(center);
    await tester.pump();
    expect(work.items, [1]);
  });

  for (final object in CountingObject.values) {
    testWidgets(
      '${object.name} empty corners obey nearby limit; visible parts remove',
      (tester) async {
        var seed = 0;
        var scene = CountingScene(3, Random(seed));
        while (scene.object != object) {
          scene = CountingScene(3, Random(++seed));
        }
        final work = CountingWork(10);
        await showBoard(tester, work, scene: scene);
        final center =
            tester.getTopLeft(
              find.byKey(const ValueKey('counting-collection')),
            ) +
            const Offset(150, 65);
        await tester.tapAt(center);
        await tester.pump();
        // Inside the picture's square, outside every object's silhouette.
        await tester.tapAt(center + const Offset(-16, -16));
        await tester.pump();
        expect(work.items, [0, 1]); // A 31 dp nudge now fits the limit.
        expectSeparate(work);
        // Off-center visible apple body, flower petal or gem facet.
        await tester.tapAt(center + const Offset(10, 0));
        await tester.pump();
        expect(work.items, [1]);
      },
    );
  }

  testWidgets('closer neighbors stay put and each can still be removed', (
    tester,
  ) async {
    final work = CountingWork(10);
    await showBoard(tester, work);
    final origin = tester.getTopLeft(
      find.byKey(const ValueKey('counting-collection')),
    );
    await tester.tapAt(origin + const Offset(150, 65));
    await tester.pump();
    await tester.tapAt(origin + const Offset(170, 65));
    await tester.pump();
    expect(work.positions[0], const Point(150.0, 65.0));
    expect(work.positions[1], const Point(197.0, 65.0));
    await tester.tapAt(origin + const Offset(150, 65));
    await tester.pump();
    expect(work.items, [1]);
    expect(work.positions[1], const Point(197.0, 65.0));
    await tester.tapAt(origin + const Offset(197, 65));
    await tester.pump();
    expect(work.items, isEmpty);
  });

  testWidgets('screen reader removal keeps the full accessible action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final work = CountingWork(10)..add();
    await showBoard(tester, work);
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('.*?, remove')),
    );
    expect(node.rect.size, const Size(56, 56));
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        nodeId: node.id,
        viewId: tester.view.viewId,
        type: SemanticsAction.tap,
      ),
    );
    await tester.pump();
    expect(work.items, isEmpty);
    semantics.dispose();
  });

  testWidgets(
    'cluster taps do nothing; a clear tap adds and direct tap removes',
    (tester) async {
      final work = CountingWork(10);
      await showBoard(tester, work);
      work.add(position: const Point(100, 65));
      work.add(position: const Point(156, 65));
      await showBoard(tester, work);
      final origin = tester.getTopLeft(
        find.byKey(const ValueKey('counting-collection')),
      );
      final before = Map<int, Point<double>>.of(work.positions);
      for (final dx in [128.0, 124.0]) {
        await tester.tapAt(origin + Offset(dx, 65));
        await tester.pump();
        expect(work.positions, before);
      }
      await tester.tapAt(origin + const Offset(240, 65));
      await tester.pump();
      expect(work.items, [0, 1, 2]);
      await tester.tapAt(origin + const Offset(100, 65));
      await tester.pump();
      expect(work.items, [1, 2]);
    },
  );

  testWidgets('scrolling and disabled trays do not add or remove', (
    tester,
  ) async {
    final work = CountingWork(10);
    await showBoard(tester, work);
    final tray = find.byKey(const ValueKey('counting-collection'));
    await tester.drag(tray, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(work.items, isEmpty);
    await showBoard(tester, work, enabled: false);
    await tester.ensureVisible(tray);
    await tester.tap(tray);
    await tester.pump();
    expect(work.items, isEmpty);
    work.add();
    await showBoard(tester, work, enabled: false);
    await tester.tap(find.byKey(const ValueKey('count-object-0')));
    await tester.pump();
    expect(work.items.length, 1);
  });

  testWidgets('cancelled and interrupted taps never place a counter', (
    tester,
  ) async {
    final work = CountingWork(10);
    await showBoard(tester, work);
    final tray = find.byKey(const ValueKey('counting-collection'));
    final gesture = await tester.startGesture(tester.getCenter(tray));
    await tester.pump(const Duration(milliseconds: 150));
    expect(work.items, isEmpty);
    await gesture.cancel();
    await tester.pump();
    expect(work.items, isEmpty);
    final interrupted = await tester.startGesture(tester.getCenter(tray));
    await tester.pump(const Duration(milliseconds: 150));
    await showBoard(tester, work, enabled: false);
    await interrupted.up();
    await tester.pump();
    expect(work.items, isEmpty);
  });

  testWidgets(
    'rebuilds retain positions and resizing keeps accessible targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(740, 640);
      final work = CountingWork(10);
      await showBoard(tester, work);
      final tray = find.byKey(const ValueKey('counting-collection'));
      await tester.tapAt(tester.getTopLeft(tray) + const Offset(610, 65));
      await tester.pump();
      final before = Map<int, Point<double>>.of(work.positions);
      await showBoard(tester, work, hint: true);
      expect(work.positions, before);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pump();
      expectSeparate(work);
      final item = find.byKey(const ValueKey('count-object-0'));
      expect(tester.getSize(item), const Size(56, 56));
      expect(find.bySemanticsLabel(RegExp('1, .*?, remove')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'capacity blocks addition but still permits removal; hint is inert',
    (tester) async {
      final work = CountingWork(2);
      await showBoard(tester, work, hint: true);
      final add = find.byKey(const ValueKey('add-count-object'));
      await tester.tap(add);
      await tester.pump();
      await tester.tap(add);
      await tester.pump();
      final tray = find.byKey(const ValueKey('counting-collection'));
      await tester.tapAt(tester.getTopRight(tray) + const Offset(-35, 35));
      await tester.pump();
      expect(work.items.length, 2);
      await tester.tap(find.byKey(const ValueKey('counting-example')));
      await tester.pump();
      expect(work.items.length, 2);
      await tester.tap(find.byKey(const ValueKey('count-object-0')));
      await tester.pump();
      expect(work.items.length, 1);
      expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
    },
  );

  testWidgets(
    'tap-built rounds require Check, clear next question and save once',
    (tester) async {
      final device = MemoryDevice()..countingMax = 5;
      final round = GameRound(
        Activity.makeGroup,
        countingMax: 5,
        random: Random(7),
      );
      await games.open(tester, device, Activity.makeGroup, round: round);
      for (var question = 0; question < 5; question++) {
        final board = tester.widget<CountingBoard>(find.byType(CountingBoard));
        expect(board.work.items, isEmpty);
        expect(board.work.positions, isEmpty);
        final tray = find.byKey(const ValueKey('counting-collection'));
        await tester.ensureVisible(tray);
        await tester.pump();
        final origin = tester.getTopLeft(tray);
        for (var i = 0; i < board.scene.quantity; i++) {
          await tester.tapAt(origin + Offset(28.0 + i * 56, 38));
          await tester.pump();
        }
        expect(round.answered, isFalse);
        await tapVisible(tester, find.byKey(const ValueKey('check-counting')));
        expect(round.answered, isTrue);
        if (question < 4) await tapVisible(tester, find.text('Next'));
      }
      expect(device.xp, 50);
      expect(device.writes, 1);
      expect(device.clips, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final (name, size, scale) in [
    ('phone', const Size(393, 852), 1.0),
    ('small', const Size(320, 640), 2.0),
    ('landscape', const Size(740, 360), 1.0),
    ('tablet', const Size(800, 1100), 1.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('tap placement fits $name, dark=$dark', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final boundary = GlobalKey();
        await games.open(
          tester,
          MemoryDevice(),
          Activity.makeGroup,
          boundary: boundary,
          theme: dark ? ThemeMode.dark : ThemeMode.light,
          reduced: true,
        );
        final tray = find.byKey(const ValueKey('counting-collection'));
        await tester.ensureVisible(tray);
        await tester.pumpAndSettle();
        final rect = tester.getRect(tray);
        // On short landscape screens, scroll each intended position into view.
        final board = tester.widget<CountingBoard>(find.byType(CountingBoard));
        for (final p in [
          Offset(rect.width * .24, 35),
          Offset(rect.width * .52, 95),
          Offset(rect.width * .8, 35),
        ]) {
          await tester.ensureVisible(tray);
          await tester.pumpAndSettle();
          await tester.tapAt(tester.getTopLeft(tray) + p);
          await tester.pump();
        }
        // Show a close neighbor as well as the scattered placements.
        await tester.ensureVisible(tray);
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getTopLeft(tray) + Offset(rect.width * .24 + 20, 35),
        );
        await tester.pump();
        expect(board.work.items.length, 4);
        expectSeparate(board.work);
        expect(
          find.byKey(const ValueKey('check-counting')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          boundary,
          'tap-place-$name-${dark ? 'dark' : 'light'}',
          directory: '0280',
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
