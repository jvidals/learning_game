import 'package:rainbow_garden/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/game_2048.dart';
import 'package:rainbow_garden/garden_art.dart' show ink, rainbow;
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/game_2048_page.dart';
import 'package:rainbow_garden/widgets/board_2048.dart';
import 'game_2048_test.dart'
    show Game2048Device, LastEmptyRandom, board2048, seed2048;
import 'interface_layout_test.dart' show capture, loadCaptureFonts;
import 'widget_test.dart' show settle, tapVisible;

Future<void> rest2048(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 310));
  await tester.pump();
}

Future<ProgressController> mount2048(
  WidgetTester tester,
  Game2048Device device, {
  bool reduced = false,
  GlobalKey? captureKey,
}) async {
  await tester.pumpWidget(const SizedBox());
  final controller = ProgressController(
    device,
    game2048Random: LastEmptyRandom(),
  );
  await controller.load();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        final app = MaterialApp(theme: GardenTheme.light);
        final theme = app.theme!;
        ButtonStyle font(ButtonStyle style) => style.copyWith(
          textStyle: WidgetStatePropertyAll(
            style.textStyle!.resolve({})!.copyWith(fontFamily: 'Roboto'),
          ),
        );
        return RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: !const bool.fromEnvironment('CAPTURE_REFRESH')
                ? theme
                : theme.copyWith(
                    filledButtonTheme: FilledButtonThemeData(
                      style: font(theme.filledButtonTheme.style!),
                    ),
                    outlinedButtonTheme: OutlinedButtonThemeData(
                      style: font(theme.outlinedButtonTheme.style!),
                    ),
                  ),
            home: MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                disableAnimations: reduced,
                textScaler: TextScaler.linear(
                  tester.platformDispatcher.textScaleFactor,
                ),
              ),
              child: Game2048Page(controller: controller),
            ),
          ),
        );
      },
    ),
  );
  await rest2048(tester);
  return controller;
}

Game2048State visibleBoard(WidgetTester tester) =>
    tester.widget<Board2048>(find.byType(Board2048)).session;

Future<void> swipe2048(WidgetTester tester, Offset offset) async {
  final board = find.byKey(const ValueKey('2048-swipe'));
  await tester.ensureVisible(board);
  await tester.pump();
  await tester.drag(board, offset);
  await rest2048(tester);
}

void main() {
  setUpAll(() async {
    await loadCaptureFonts();
    if (const bool.fromEnvironment('CAPTURE_REFRESH')) {
      await FoalAssets.load();
    }
  });
  testWidgets('Numbers opens 2048, Back returns there, and reentry resumes', (
    tester,
  ) async {
    final device = Game2048Device();
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    await tapVisible(tester, find.text('Numbers'));
    await tapVisible(tester, find.text('2048').first);
    expect(find.byType(Game2048Page), findsOneWidget);
    final initial = visibleBoard(tester).toJson();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await rest2048(tester);
    final saved = visibleBoard(tester).toJson();
    expect(saved['id'], initial['id']);
    await tapVisible(tester, find.byTooltip('Back to numbers'));
    expect(find.text('Numbers'), findsOneWidget);
    await tapVisible(tester, find.text('2048').first);
    expect(visibleBoard(tester).toJson(), saved);
    expect(device.clips, isEmpty);
  });
  for (final (offset, key) in [
    (const Offset(-100, 0), LogicalKeyboardKey.arrowLeft),
    (const Offset(100, 0), LogicalKeyboardKey.keyD),
    (const Offset(0, -100), LogicalKeyboardKey.keyW),
    (const Offset(0, 100), LogicalKeyboardKey.arrowDown),
  ]) {
    testWidgets('swipe $offset and keyboard $key make the same move', (
      tester,
    ) async {
      final device = Game2048Device();
      final initial = board2048([0, 0, 0, 0, 0, 2, 2, 0, 0, 4, 4, 0]);
      seed2048(device, initial);
      await mount2048(tester, device);
      await swipe2048(tester, offset);
      final swiped = visibleBoard(tester).toJson();
      expect(swiped['moves'], 101);
      seed2048(device, initial);
      await mount2048(tester, device);
      await tester.sendKeyEvent(key);
      await rest2048(tester);
      expect(visibleBoard(tester).toJson(), swiped);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(tester.widgetList<IconButton>(find.byType(IconButton)).length, 1);
    });
  }
  testWidgets(
    'keyboard repeat, rapid moves and tiny gestures do not create extra moves',
    (tester) async {
      final device = Game2048Device();
      seed2048(device, board2048([0, 2, 2]));
      await mount2048(tester, device);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await rest2048(tester);
      expect(device.writes, 1);
      await swipe2048(tester, const Offset(5, 0));
      expect(device.writes, 1);
      expect(device.feedbacks, [DeviceFeedback.placement]);
    },
  );
  testWidgets('moves save silently and keep restart colors and layout steady', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final device = Game2048Device();
    seed2048(device, board2048([0, 2, 2]));
    await mount2048(tester, device);
    final button = find.widgetWithText(OutlinedButton, 'Start over');
    final board = find.byKey(const ValueKey('2048-swipe'));
    final original = visibleBoard(tester).toJson();
    final boardBounds = tester.getRect(board);
    final buttonBounds = tester.getRect(button);
    (Color?, ShapeBorder?) appearance() => (
      tester
          .widget<RichText>(
            find.descendant(of: button, matching: find.byType(RichText)),
          )
          .text
          .style
          ?.color,
      tester
          .widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)),
          )
          .shape,
    );
    final colors = appearance();
    void expectSteady() {
      expect(appearance(), colors);
      expect(tester.getRect(board), boardBounds);
      expect(tester.getRect(button), buttonBounds);
      expect(find.textContaining('Saving'), findsNothing);
    }

    device.gate = Completer<void>();
    await tester.drag(board, const Offset(-100, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expectSteady();
    expect(visibleBoard(tester).toJson(), original);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    await tester.tap(button);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    device.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expectSteady();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    await rest2048(tester);
    expectSteady();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(visibleBoard(tester).score, 4);
    expect(device.writes, 1);
  });
  testWidgets(
    'restart asks first, blocks keyboard behind dialog, and preserves best',
    (tester) async {
      final device = Game2048Device();
      seed2048(device, board2048([4, 2], score: 4), highScore: 100, xp: 500);
      await mount2048(tester, device);
      final original = visibleBoard(tester).toJson();
      await tapVisible(tester, find.text('Start over'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await rest2048(tester);
      expect(device.writes, 0);
      await tapVisible(tester, find.text('Keep playing'));
      expect(visibleBoard(tester).toJson(), original);
      await tapVisible(tester, find.text('Start over'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start over'));
      expect(visibleBoard(tester).id, isNot('fixture'));
      expect(visibleBoard(tester).score, 0);
      final saved = PlayerProgress.decode(device.document);
      expect(saved.game2048.highScore, 100);
      expect(saved.xp, 500);
    },
  );
  testWidgets(
    'win waits for saving and shows the customized unicorn exactly once',
    (tester) async {
      final device = Game2048Device();
      seed2048(device, board2048([1024, 1024], score: 20000), xp: 900);
      final p = PlayerProgress.decode(device.document);
      device.document = p
          .copyWith(
            owned: {'blue', 'flower', 'feather', 'hop'},
            companion: CompanionConfiguration({
              RewardCategory.mane: 'blue',
              RewardCategory.accessory: 'flower',
              RewardCategory.wings: 'feather',
              RewardCategory.behavior: 'hop',
            }),
          )
          .encode();
      await mount2048(tester, device);
      device.gate = Completer<void>();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('500 XP earned!'), findsNothing);
      expect(device.feedbacks, isEmpty);
      expect(visibleBoard(tester).won, isFalse);
      device.gate!.complete();
      await rest2048(tester);
      expect(find.text('500 XP earned!'), findsOneWidget);
      final unicorn = tester.widget<CompanionView>(find.byType(CompanionView));
      expect(unicorn.configuration.equipped, {
        RewardCategory.mane: 'blue',
        RewardCategory.accessory: 'flower',
        RewardCategory.wings: 'feather',
        RewardCategory.behavior: 'hop',
      });
      expect(unicorn.animate, isFalse);
      expect(unicorn.reactionTrigger, 1);
      expect(device.feedbacks, [DeviceFeedback.confirm]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await rest2048(tester);
      expect(
        tester
            .widget<CompanionView>(find.byType(CompanionView))
            .reactionTrigger,
        0,
      );
      expect(device.feedbacks, [DeviceFeedback.confirm]);
      await mount2048(tester, device);
      expect(find.text('500 XP earned!'), findsOneWidget);
      expect(
        tester
            .widget<CompanionView>(find.byType(CompanionView))
            .reactionTrigger,
        0,
      );
      await tapVisible(tester, find.text('Keep playing'));
      expect(find.text('500 XP earned!'), findsNothing);
      final id = visibleBoard(tester).id, score = visibleBoard(tester).score;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await rest2048(tester);
      expect(visibleBoard(tester).id, id);
      expect(visibleBoard(tester).score, greaterThanOrEqualTo(score));
      expect(device.xp, 1400);
      expect(device.clips, isEmpty);
    },
  );
  testWidgets(
    'failed winning move retries without early feedback or duplicate XP',
    (tester) async {
      final device = Game2048Device();
      seed2048(device, board2048([1024, 1024], score: 20000));
      await mount2048(tester, device);
      device.failSave = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await rest2048(tester);
      expect(find.text('Try saving again'), findsOneWidget);
      expect(find.text('500 XP earned!'), findsNothing);
      expect(device.feedbacks, isEmpty);
      device.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(device.xp, 500);
      expect(find.text('500 XP earned!'), findsOneWidget);
      expect(device.feedbacks, [DeviceFeedback.confirm]);
    },
  );
  testWidgets('leaving during a failed save keeps retry available at home', (
    tester,
  ) async {
    final device = Game2048Device();
    seed2048(device, board2048([1024, 1024], score: 20000));
    await tester.pumpWidget(RainbowGardenApp(services: device));
    await settle(tester);
    await tapVisible(tester, find.text('Numbers'));
    await tapVisible(tester, find.text('2048').first);
    device.failSave = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await rest2048(tester);
    await tapVisible(tester, find.byTooltip('Back to numbers'));
    await tapVisible(tester, find.byTooltip('Back to home'));
    device.failSave = false;
    await tapVisible(tester, find.text('Try saving again'));
    expect(device.xp, 500);
    expect(device.feedbacks, isEmpty);
    await tapVisible(tester, find.text('Numbers'));
    await tapVisible(tester, find.text('2048').first);
    expect(find.text('500 XP earned!'), findsOneWidget);
    expect(device.feedbacks, isEmpty);
  });
  testWidgets(
    'background and covered routes cancel gestures and suppress late win effects',
    (tester) async {
      final device = Game2048Device();
      seed2048(device, board2048([1024, 1024], score: 20000));
      await mount2048(tester, device);
      final board = find.byKey(const ValueKey('2048-swipe'));
      final gesture = await tester.startGesture(tester.getCenter(board));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await gesture.up();
      await tester.pump();
      expect(device.writes, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      device.gate = Completer<void>();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      device.gate!.complete();
      await rest2048(tester);
      expect(device.xp, 500);
      expect(device.feedbacks, isEmpty);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('500 XP earned!'), findsOneWidget);
      expect(
        tester
            .widget<CompanionView>(find.byType(CompanionView))
            .reactionTrigger,
        0,
      );
    },
  );
  testWidgets(
    'reduced motion and Haptics off preserve moves and static winning state',
    (tester) async {
      final device = Game2048Device()..haptics = false;
      seed2048(device, board2048([1024, 1024], score: 20000));
      await mount2048(tester, device, reduced: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump();
      expect(visibleBoard(tester).won, isTrue);
      expect(tester.widget<Board2048>(find.byType(Board2048)).move, isNull);
      expect(device.feedbacks, isEmpty);
      expect(find.text('500 XP earned!'), findsOneWidget);
    },
  );
  final finished = board2048([2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2]);
  final lastMove = board2048([
    2,
    4,
    2,
    4,
    4,
    2,
    4,
    2,
    2,
    4,
    2,
    4,
    4,
    2,
    8,
    8,
  ], score: 100);
  testWidgets('finished board popup dismisses once and returns on reentry', (
    tester,
  ) async {
    final device = Game2048Device();
    seed2048(device, finished, highScore: 200, xp: 500);
    await mount2048(tester, device);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Game over'), findsOneWidget);
    expect(find.text('No moves left'), findsNothing);
    final saved = device.document;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tapVisible(tester, find.text('View board'));
    expect(find.byType(AlertDialog), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await rest2048(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(device.document, saved);
    expect(device.writes, 0);
    await mount2048(tester, device);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Game over'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Start over'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(visibleBoard(tester).board.where((v) => v != 0).length, 2);
    expect(visibleBoard(tester).score, 0);
    final progress = PlayerProgress.decode(device.document);
    expect(progress.game2048.highScore, 200);
    expect(progress.xp, 500);
    expect(device.writes, 1);
  });
  testWidgets('game over waits for final save and tile motion', (tester) async {
    final device = Game2048Device();
    seed2048(device, lastMove);
    await mount2048(tester, device);
    device.gate = Completer<void>();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(visibleBoard(tester).gameOver, isFalse);
    device.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(visibleBoard(tester).gameOver, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Game over'), findsOneWidget);
    expect(device.writes, 1);
    expect(device.feedbacks, [DeviceFeedback.placement]);
  });
  testWidgets('failed final move and popup restart retain exact retry', (
    tester,
  ) async {
    final device = Game2048Device();
    seed2048(device, lastMove, highScore: 200, xp: 500);
    await mount2048(tester, device, reduced: true);
    device.failSave = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await rest2048(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Try saving again'), findsOneWidget);
    device.failSave = false;
    await tapVisible(tester, find.text('Try saving again'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Game over'), findsOneWidget);
    final terminal = visibleBoard(tester).toJson();
    device.failSave = true;
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Start over'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(visibleBoard(tester).toJson(), terminal);
    expect(find.text('Try saving again'), findsOneWidget);
    device.failSave = false;
    await tapVisible(tester, find.text('Try saving again'));
    expect(visibleBoard(tester).gameOver, isFalse);
    expect(visibleBoard(tester).score, 0);
    final progress = PlayerProgress.decode(device.document);
    expect(progress.xp, 500);
    expect(progress.game2048.highScore, 200);
  });
  for (final covered in [false, true]) {
    testWidgets(
      'late game over waits for ${covered ? 'route' : 'foreground'}',
      (tester) async {
        final device = Game2048Device();
        seed2048(device, lastMove);
        await mount2048(tester, device);
        device.gate = Completer<void>();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        if (covered) {
          unawaited(
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Covered')),
              ),
            ),
          );
          await tester.pumpAndSettle();
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
        }
        device.gate!.complete();
        await rest2048(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(device.feedbacks, isEmpty);
        if (covered) {
          navigator.pop();
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AlertDialog, 'Game over'), findsOneWidget);
        expect(device.feedbacks, isEmpty);
      },
    );
  }
  testWidgets('a terminal winning move shows the win before game over', (
    tester,
  ) async {
    final device = Game2048Device();
    seed2048(
      device,
      board2048([
        1024,
        1024,
        4,
        8,
        2,
        8,
        16,
        4,
        4,
        16,
        8,
        2,
        2,
        8,
        16,
        4,
      ], score: 20000),
    );
    await mount2048(tester, device, reduced: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await rest2048(tester);
    expect(find.text('500 XP earned!'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tapVisible(tester, find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Game over'), findsOneWidget);
    expect(device.xp, 500);
  });
  testWidgets(
    'tile semantics expose position and value without directional buttons',
    (tester) async {
      final handle = tester.ensureSemantics();

      final device = Game2048Device();
      seed2048(device, board2048([2, 4]));
      await mount2048(tester, device);
      final cell = tester.getSemantics(
        find.byKey(const ValueKey('2048-cell-0')),
      );
      expect(cell.label, 'Row 1, column 1');
      expect(cell.value, '2');
      expect(
        tester.getSemantics(find.byKey(const ValueKey('2048-cell-2'))).value,
        'Empty',
      );
      expect(find.widgetWithText(OutlinedButton, 'Start over'), findsOneWidget);
      expect(tester.widgetList<IconButton>(find.byType(IconButton)).length, 1);
      handle.dispose();
    },
  );
  BoxDecoration tileDecoration(WidgetTester tester, int value) =>
      tester
              .widget<Container>(
                find
                    .ancestor(
                      of: find
                          .descendant(
                            of: find.byType(Board2048),
                            matching: find.text('$value'),
                          )
                          .first,
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  testWidgets(
    'fourteen distinct tile colors preserve contrast and small tiles',
    (tester) async {
      final values = List.generate(14, (i) => 1 << (i + 1));
      final device = Game2048Device();
      seed2048(
        device,
        board2048(values, score: 400000, won: true, acknowledged: true),
        xp: 500,
      );
      await mount2048(tester, device);
      final colors = [
        for (final value in values) tileDecoration(tester, value).color!,
      ];
      expect(colors.toSet().length, 14);
      for (var i = 0; i < rainbow.length; i++) {
        expect(colors[i], Color.lerp(rainbow[i], Colors.white, .76));
      }
      for (final color in colors) {
        final contrast =
            (color.computeLuminance() + .05) / (ink.computeLuminance() + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
      expect(
        tileDecoration(tester, 2048).border,
        Border.all(color: const Color(0xFFC29127), width: 3),
      );
      expect(
        tileDecoration(tester, 16384).border,
        Border.all(color: Colors.white, width: 2),
      );
    },
  );

  testWidgets(
    'large tile colors persist through slides, merges and beyond 16384',
    (tester) async {
      final before = board2048(
        [8192, 8192],
        score: 400000,
        won: true,
        acknowledged: true,
      );
      final move = before.move(Move2048Direction.left, LastEmptyRandom())!;
      Future<void> draw(
        Game2048State session, {
        Game2048Move? move,
        double progress = 1,
      }) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              child: Board2048(
                session: session,
                move: move,
                animation: AlwaysStoppedAnimation(progress),
              ),
            ),
          ),
        ),
      );
      await draw(before);
      final source = tileDecoration(tester, 8192).color;
      await draw(move.after, move: move, progress: .3);
      expect(tileDecoration(tester, 8192).color, source);
      await draw(move.after, move: move);
      final merged = tileDecoration(tester, 16384).color;
      expect(merged, isNot(source));
      await draw(
        board2048(
          [16384, 32768, 65536],
          score: 2000000,
          won: true,
          acknowledged: true,
        ),
      );
      expect(tileDecoration(tester, 16384).color, merged);
      expect(tileDecoration(tester, 32768).color, merged);
      expect(tileDecoration(tester, 65536).color, merged);
    },
  );
  for (final (name, size) in [
    ('small-phone', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('short-phone', const Size(411, 731)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('2048 layout $name at $scale text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final key = GlobalKey(), device = Game2048Device();
        for (final victory in [false, true]) {
          seed2048(
            device,
            board2048(
              victory
                  ? [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048]
                  : List.generate(14, (i) => 1 << (i + 1)),
              score: 400000,
              won: true,
              acknowledged: !victory,
            ),
            highScore: 500000,
            xp: 900,
          );
          if (victory) {
            device.document = PlayerProgress.decode(device.document)
                .copyWith(
                  owned: {'blue', 'flower', 'feather', 'hop'},
                  companion: CompanionConfiguration({
                    RewardCategory.mane: 'blue',
                    RewardCategory.accessory: 'flower',
                    RewardCategory.wings: 'feather',
                    RewardCategory.behavior: 'hop',
                  }),
                )
                .encode();
          }
          await mount2048(tester, device, captureKey: key);
          expect(tester.takeException(), isNull);
          expect(tester.widget<Text>(find.text('400000')).maxLines, 1);
          expect(tester.widget<Text>(find.text('500000')).maxLines, 1);
          if (scale == 1 && !victory) {
            final rect = tester.getRect(
              find.byKey(const ValueKey('2048-swipe')),
            );
            expect(rect.bottom, lessThanOrEqualTo(size.height - 16));
            expect(rect.left, greaterThanOrEqualTo(16));
          }
          final button = find.widgetWithText(OutlinedButton, 'Start over');
          if (size.height > size.width) {
            final board = tester.getRect(
              find.byKey(const ValueKey('2048-swipe')),
            );
            final instructions = tester.getRect(
              find.text('Swipe to slide. Match numbers to make 2048.'),
            );
            expect(
              tester.getRect(find.text('High score')).bottom,
              lessThan(board.top),
            );
            expect(instructions.top, greaterThanOrEqualTo(board.bottom));
            expect(
              tester.getRect(button).top,
              greaterThan(instructions.bottom),
            );
            if (scale == 1 && !victory) {
              expect(
                tester.getRect(button).bottom,
                lessThanOrEqualTo(size.height - 16),
              );
            }
          }
          await tester.ensureVisible(button);
          await tester.pump();
          expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
          await tester.dragFrom(const Offset(8, 120), const Offset(0, 1000));
          await rest2048(tester);
          await capture(
            tester,
            key,
            '${victory ? 'win' : 'board'}-$name-${scale.toInt()}x',
            directory: '0131',
          );
          await tester.ensureVisible(find.byKey(const ValueKey('2048-swipe')));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        seed2048(device, finished);
        await mount2048(tester, device, captureKey: key);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AlertDialog, 'Game over'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final restart = find.widgetWithText(FilledButton, 'Start over');
        expect(tester.getSize(restart).height, greaterThanOrEqualTo(56));
        expect(tester.getRect(restart).bottom, lessThan(size.height));
        await capture(
          tester,
          key,
          'game-over-$name-${scale.toInt()}x',
          directory: '0131',
        );
        await tapVisible(tester, restart);
        expect(visibleBoard(tester).gameOver, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
