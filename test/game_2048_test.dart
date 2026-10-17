import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/game_2048.dart';
import 'widget_test.dart' show MemoryDevice;

class LastEmptyRandom implements Random {
  int calls = 0;
  double tileRoll = .5;
  @override
  int nextInt(int max) {
    calls++;
    return max - 1;
  }

  @override
  double nextDouble() {
    calls++;
    return tileRoll;
  }

  @override
  bool nextBool() => false;
}

Game2048State board2048(
  List<int> values, {
  int score = 0,
  bool won = false,
  bool acknowledged = false,
}) => Game2048State(
  id: 'fixture',
  board: [...values, ...List.filled(16 - values.length, 0)],
  score: score,
  moves: 100,
  won: won,
  winAcknowledged: acknowledged,
);

class Game2048Device extends MemoryDevice {
  Completer<void>? gate;
  bool lostAcknowledgement = false;
  @override
  Future<void> saveProgress(String document) async {
    await gate?.future;
    await super.saveProgress(document);
    if (lostAcknowledgement) throw StateError('Lost acknowledgement');
  }
}

void seed2048(
  MemoryDevice device,
  Game2048State session, {
  int highScore = 0,
  int xp = 0,
}) {
  device.document = PlayerProgress(
    xp: xp,
    lastRewardedRound: xp > 0 ? 'previous-round' : null,
    game2048: Game2048Progress(
      highScore: max(highScore, session.score),
      session: session,
    ),
  ).encode();
}

Future<ProgressController> load2048(
  Game2048Device device, {
  Random? random,
}) async {
  final controller = ProgressController(device, game2048Random: random);
  await controller.load();
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('2048 belongs to Numbers and cannot become a recognition round', () {
    expect(Activity.game2048.category, GameCategory.numbers);
    expect(ActivityContent.recognition, isNot(contains(Activity.game2048)));
    expect(() => GameRound(Activity.game2048), throwsArgumentError);
  });
  test('starting board has two tiles and uses the 90/10 spawn boundary', () {
    final random = LastEmptyRandom();
    expect(Game2048State.start('first', random).board.where((v) => v != 0), [
      2,
      2,
    ]);
    random.tileRoll = .099;
    expect(Game2048State.start('second', random).board.where((v) => v != 0), [
      4,
      4,
    ]);
    random.tileRoll = .1;
    expect(Game2048State.start('third', random).board.where((v) => v != 0), [
      2,
      2,
    ]);
  });
  test('compresses gaps, merges once and preserves the original board', () {
    final before = board2048([2, 0, 2, 4]);
    final move = before.move(Move2048Direction.left, LastEmptyRandom())!;
    expect(before.board.take(4), [2, 0, 2, 4]);
    expect(move.after.board.take(4), [4, 4, 0, 0]);
    expect(move.after.score, 4);
    expect(move.merged, {0});
    expect(move.after.board[15], 2);
    expect(move.flights.length, 3);
  });
  test('four equal tiles make two merges, not one chained merge', () {
    final move = board2048([
      2,
      2,
      2,
      2,
    ]).move(Move2048Direction.left, LastEmptyRandom())!;
    expect(move.after.board.take(4), [4, 4, 0, 0]);
    expect(move.after.score, 8);
    expect(move.merged, {0, 1});
  });
  for (final (direction, source, destination) in [
    (Move2048Direction.left, [2, 2, 4, 0], [4, 4, 0, 0]),
    (Move2048Direction.right, [2, 2, 4, 0], [0, 0, 4, 4]),
    (Move2048Direction.up, [2, 2, 4, 0], [4, 4, 0, 0]),
    (Move2048Direction.down, [2, 2, 4, 0], [0, 0, 4, 4]),
  ]) {
    test('merges toward ${direction.name} in the correct order', () {
      final values = List.filled(16, 0);
      final vertical =
          direction == Move2048Direction.up ||
          direction == Move2048Direction.down;
      for (var i = 0; i < 4; i++) {
        values[vertical ? i * 4 : i] = source[i];
      }
      final after = board2048(values).move(direction, LastEmptyRandom())!.after;
      expect(
        List.generate(4, (i) => after.board[vertical ? i * 4 : i]),
        destination,
      );
      expect(after.score, 4);
    });
  }
  test('unchanged moves do not consume randomness', () {
    final random = LastEmptyRandom();
    expect(board2048([2, 4]).move(Move2048Direction.left, random), isNull);
    expect(random.calls, 0);
  });
  test('full board only ends when no adjacent merge exists', () {
    final blocked = board2048([2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2]);
    expect(blocked.gameOver, isTrue);
    for (final direction in Move2048Direction.values) {
      expect(blocked.move(direction, LastEmptyRandom()), isNull);
    }
    expect(
      board2048([2, 2, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2]).gameOver,
      isFalse,
    );
  });
  test('a win can also be the last possible move', () {
    final move = board2048([
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
    ], score: 20000).move(Move2048Direction.left, LastEmptyRandom())!;
    expect(move.firstWin, isTrue);
    expect(move.after.gameOver, isTrue);
    expect(move.after.awaitingContinue, isTrue);
  });
  test('continuation permits larger tiles without another win', () {
    final session = board2048([2048, 2048], score: 40000, won: true);
    expect(session.move(Move2048Direction.left, LastEmptyRandom()), isNull);
    final move = session.acknowledgeWin().move(
      Move2048Direction.left,
      LastEmptyRandom(),
    )!;
    expect(move.after.board.first, 4096);
    expect(move.firstWin, isFalse);
    expect(move.after.score, 44096);
  });
  test('seeded play preserves mass and round-trips valid saved states', () {
    for (var seed = 0; seed < 20; seed++) {
      final random = Random(seed);
      var state = Game2048State.start('seed-$seed', random);
      for (var turn = 0; turn < 400 && !state.gameOver; turn++) {
        final move = state.move(
          Move2048Direction.values[random.nextInt(4)],
          random,
        );
        if (move == null) continue;
        final beforeSum = state.board.reduce((a, b) => a + b);
        state = move.after;
        expect(state.board.reduce((a, b) => a + b) - beforeSum, anyOf(2, 4));
        expect(Game2048State.fromJson(state.toJson()).toJson(), state.toJson());
        if (state.awaitingContinue) state = state.acknowledgeWin();
      }
    }
  });
  test(
    'initialization is saved once and reopening preserves the exact board',
    () async {
      final device = Game2048Device(), controller = await load2048(device);
      await controller.start2048();
      final saved = device.document;
      await controller.start2048();
      expect(device.writes, 1);
      final reopened = await load2048(device);
      expect(reopened.progress!.encode(), saved);
    },
  );
  test(
    'changed moves save score and high score; no-op does not write',
    () async {
      final device = Game2048Device();
      seed2048(device, board2048([2, 2, 4, 4]));
      final controller = await load2048(device, random: LastEmptyRandom());
      await controller.move2048(Move2048Direction.left);
      expect(controller.progress!.game2048.highScore, 12);
      expect(controller.progress!.game2048.session!.score, 12);
      expect(device.writes, 1);
      final restored = await load2048(device);
      expect(
        restored.progress!.game2048.toJson(),
        controller.progress!.game2048.toJson(),
      );
      seed2048(device, board2048([2, 4]));
      final noOp = await load2048(device);
      await noOp.move2048(Move2048Direction.left);
      expect(device.writes, 1);
    },
  );
  test('a winning save awards exactly 500 XP and all crossed levels', () async {
    final device = Game2048Device();
    seed2048(device, board2048([1024, 1024], score: 20000));
    final controller = await load2048(device, random: LastEmptyRandom());
    await controller.move2048(Move2048Direction.left);
    expect(controller.progress!.xp, 500);
    expect(controller.progress!.level, 5);
    expect(controller.progress!.availableChoices, 4);
    expect(controller.progress!.game2048.session!.won, isTrue);
    await controller.move2048(Move2048Direction.right);
    expect(device.writes, 1);
    final reopened = await load2048(device, random: LastEmptyRandom());
    await reopened.continue2048();
    await reopened.move2048(Move2048Direction.right);
    expect(reopened.progress!.xp, 500);
    expect(reopened.progress!.game2048.session!.winAcknowledged, isTrue);
  });
  test(
    'delayed save publishes nothing early and blocks every conflicting write',
    () async {
      final device = Game2048Device();
      seed2048(device, board2048([1024, 1024], score: 20000));
      final controller = await load2048(device, random: LastEmptyRandom());
      device.gate = Completer<void>();
      final pending = controller.move2048(Move2048Direction.left);
      expect(controller.progress!.xp, 0);
      expect(controller.progress!.game2048.session!.won, isFalse);
      await expectLater(controller.start2048(restart: true), throwsStateError);
      await expectLater(
        controller.move2048(Move2048Direction.right),
        throwsStateError,
      );
      await expectLater(controller.reset(), throwsStateError);
      await expectLater(
        controller.saveSettings(const AppSettings()),
        throwsStateError,
      );
      device.gate!.complete();
      await pending;
      expect(controller.progress!.xp, 500);
    },
  );
  for (final lostAck in [false, true]) {
    test(
      'failed win retry retains random spawn and XP, lost acknowledgement=$lostAck',
      () async {
        final device = Game2048Device(), random = LastEmptyRandom();
        seed2048(device, board2048([1024, 1024], score: 20000));
        final controller = await load2048(device, random: random);
        device.failSave = !lostAck;
        device.lostAcknowledgement = lostAck;
        await expectLater(
          controller.move2048(Move2048Direction.left),
          throwsStateError,
        );
        final randomCalls = random.calls;
        expect(controller.progress!.xp, 0);
        expect(controller.blocked.value, isTrue);
        if (lostAck) {
          final reloaded = await load2048(device);
          expect(reloaded.progress!.xp, 500);
          expect(reloaded.progress!.game2048.session!.awaitingContinue, isTrue);
        }
        device.failSave = false;
        device.lostAcknowledgement = false;
        await controller.retry();
        final saved = device.document;
        await controller.retry();
        expect(device.document, saved);
        expect(random.calls, randomCalls);
        expect(controller.progress!.xp, 500);
        expect(controller.progress!.game2048.session!.board[15], 2);
      },
    );
  }
  test(
    'restart retains high score and XP; reset clears game and preserves settings',
    () async {
      final device = Game2048Device();
      seed2048(device, board2048([2048, 2], score: 20000, won: true), xp: 500);
      final controller = await load2048(device);
      await controller.saveSettings(const AppSettings(haptics: false));
      await controller.start2048(restart: true);
      expect(controller.progress!.xp, 500);
      expect(controller.progress!.game2048.highScore, 20000);
      expect(controller.progress!.game2048.session!.score, 0);
      expect(controller.progress!.game2048.session!.won, isFalse);
      expect(controller.progress!.game2048.session!.id, isNot('fixture'));
      await controller.choose('blue');
      await controller.completeRound('learning');
      final savedGame = controller.progress!.game2048.toJson();
      expect(savedGame['highScore'], 20000);
      expect((await load2048(device)).progress!.game2048.toJson(), savedGame);
      await controller.reset();
      expect(
        controller.progress!.game2048.toJson(),
        const Game2048Progress().toJson(),
      );
      expect(controller.settings.haptics, isFalse);
    },
  );
  test('legacy saves load without altering other progress', () {
    final legacy =
        jsonDecode(PlayerProgress(xp: 150, lastRewardedRound: 'old').encode())
            as Map<String, dynamic>;
    legacy.remove('game2048');
    final restored = PlayerProgress.decode(jsonEncode(legacy));
    expect(restored.xp, 150);
    expect(restored.game2048.session, isNull);
    expect(restored.game2048.highScore, 0);
  });
  test(
    'initialization and acknowledgement failures keep their exact pending operation',
    () async {
      final device = Game2048Device(), random = LastEmptyRandom();
      final controller = await load2048(device, random: random);
      device.failSave = true;
      await expectLater(controller.start2048(), throwsStateError);
      expect(controller.progress!.game2048.session, isNull);
      final calls = random.calls;
      device.failSave = false;
      await controller.retry();
      expect(random.calls, calls);
      expect(
        controller.progress!.game2048.session!.board
            .where((v) => v != 0)
            .length,
        2,
      );
      seed2048(device, board2048([2048, 2], score: 20000, won: true), xp: 500);
      final won = await load2048(device);
      device.failSave = true;
      await expectLater(won.continue2048(), throwsStateError);
      expect(won.progress!.game2048.session!.awaitingContinue, isTrue);
      await expectLater(
        won.move2048(Move2048Direction.right),
        throwsStateError,
      );
      device.failSave = false;
      await won.retry();
      expect(won.progress!.game2048.session!.awaitingContinue, isFalse);
      expect(won.progress!.xp, 500);
      expect(
        (await load2048(device)).progress!.game2048.session!.winAcknowledged,
        isTrue,
      );
    },
  );
  test(
    'failed restart retains the existing board and retries the same fresh game',
    () async {
      final device = Game2048Device(), random = LastEmptyRandom();
      seed2048(device, board2048([4, 2], score: 4), highScore: 100);
      final controller = await load2048(device, random: random);
      final original = controller.progress!.game2048.toJson();
      device.lostAcknowledgement = true;
      await expectLater(controller.start2048(restart: true), throwsStateError);
      expect(controller.progress!.game2048.toJson(), original);
      final intended = device.document, calls = random.calls;
      device.lostAcknowledgement = false;
      await controller.retry();
      expect(device.document, intended);
      expect(random.calls, calls);
      expect(controller.progress!.game2048.highScore, 100);
    },
  );
  test(
    'malformed games stay untouched and expose recoverable load errors',
    () async {
      final good = board2048([2, 4]).toJson();
      for (final patch in <Map<String, dynamic>>[
        {
          'board': [2, 4],
        },
        {
          'board': [3, 4, ...List.filled(14, 0)],
        },
        {
          'board': [2, 4, ...List.filled(14, -2)],
        },
        {'score': -4},
        {'score': 3},
        {'moves': -1},
        {'id': ''},
        {'won': true},
        {'winAcknowledged': true},
        {
          'board': [8, 2, ...List.filled(14, 0)],
        },
      ]) {
        final document =
            jsonDecode(PlayerProgress().encode()) as Map<String, dynamic>;
        document['game2048'] = {
          'highScore': 0,
          'session': {...good, ...patch},
        };
        final device = Game2048Device()..document = jsonEncode(document);
        final original = device.document;
        final controller = await load2048(device);
        expect(controller.loadFailed, isTrue, reason: '$patch');
        expect(device.document, original);
        expect(device.writes, 0);
      }
      for (final value in [
        null,
        {},
        {'highScore': -1, 'session': null},
        {
          'highScore': 0,
          'session': board2048([4, 2], score: 4).toJson(),
        },
      ]) {
        final doc =
            jsonDecode(PlayerProgress().encode()) as Map<String, dynamic>;
        doc['game2048'] = value;
        expect(
          () => PlayerProgress.decode(jsonEncode(doc)),
          throwsFormatException,
        );
      }
    },
  );
}
