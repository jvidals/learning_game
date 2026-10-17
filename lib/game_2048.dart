import 'dart:math';

const game2048WinXp = 500;

enum Move2048Direction { left, right, up, down }

/// One immutable saved board. Presentation never owns authoritative moves.
class Game2048State {
  Game2048State({
    required this.id,
    required List<int> board,
    this.score = 0,
    this.moves = 0,
    this.won = false,
    this.winAcknowledged = false,
  }) : board = List.unmodifiable(board);

  final String id;
  final List<int> board;
  final int score, moves;
  final bool won, winAcknowledged;
  bool get awaitingContinue => won && !winAcknowledged;
  bool get gameOver {
    if (board.contains(0)) return false;
    for (var i = 0; i < 16; i++) {
      if (i % 4 < 3 && board[i] == board[i + 1]) return false;
      if (i < 12 && board[i] == board[i + 4]) return false;
    }
    return true;
  }

  factory Game2048State.start(String id, Random random) {
    final board = List.filled(16, 0);
    _spawn(board, random);
    _spawn(board, random);
    return Game2048State(id: id, board: board);
  }

  Game2048State acknowledgeWin() => Game2048State(
    id: id,
    board: board,
    score: score,
    moves: moves,
    won: won,
    winAcknowledged: won,
  );

  /// Returns null when the board cannot change. A newly merged tile cannot
  /// merge again until a later move.
  Game2048Move? move(Move2048Direction direction, Random random) {
    if (awaitingContinue || gameOver) return null;
    final next = List.filled(16, 0);
    final flights = <Tile2048Flight>[];
    final merged = <int>{};
    var gain = 0;
    for (var line = 0; line < 4; line++) {
      final slots = List.generate(
        4,
        (offset) => switch (direction) {
          Move2048Direction.left => line * 4 + offset,
          Move2048Direction.right => line * 4 + 3 - offset,
          Move2048Direction.up => offset * 4 + line,
          Move2048Direction.down => (3 - offset) * 4 + line,
        },
      );
      final occupied = slots.where((i) => board[i] != 0).toList();
      var output = 0;
      for (var i = 0; i < occupied.length; i++) {
        final source = occupied[i], destination = slots[output++];
        var value = board[source];
        flights.add(Tile2048Flight(source, destination, value));
        if (i + 1 < occupied.length && board[occupied[i + 1]] == value) {
          flights.add(Tile2048Flight(occupied[++i], destination, value));
          value *= 2;
          gain += value;
          merged.add(destination);
        }
        next[destination] = value;
      }
    }
    if (List.generate(16, (i) => board[i] == next[i]).every((same) => same)) {
      return null;
    }
    final spawn = _spawn(next, random);
    final after = Game2048State(
      id: id,
      board: next,
      score: score + gain,
      moves: moves + 1,
      won: won || next.any((v) => v >= 2048),
      winAcknowledged: winAcknowledged,
    );
    return Game2048Move(this, after, flights, merged, spawn, direction);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'board': board,
    'score': score,
    'moves': moves,
    'won': won,
    'winAcknowledged': winAcknowledged,
  };

  factory Game2048State.fromJson(Map<String, dynamic> json) {
    final state = Game2048State(
      id: json['id'] as String,
      board: (json['board'] as List).cast<int>(),
      score: json['score'] as int,
      moves: json['moves'] as int,
      won: json['won'] as bool,
      winAcknowledged: json['winAcknowledged'] as bool,
    );
    if (state.id.isEmpty ||
        state.board.length != 16 ||
        state.board.where((v) => v != 0).length < 2 ||
        state.board.any((v) => v != 0 && (v < 2 || (v & (v - 1)) != 0)) ||
        state.score < 0 ||
        state.score % 4 != 0 ||
        state.moves < 0 ||
        state.won != state.board.any((v) => v >= 2048) ||
        (state.winAcknowledged && !state.won)) {
      throw const FormatException('Invalid 2048 game');
    }
    // A tile can have started as a 4; every further doubling scores its value.
    final minimumScore = state.board.fold<int>(
      0,
      (sum, value) => sum + (value < 4 ? 0 : value * (value.bitLength - 3)),
    );
    if (state.score < minimumScore) {
      throw const FormatException('Invalid 2048 score');
    }
    return state;
  }
}

int _spawn(List<int> board, Random random) {
  final empty = List.generate(
    16,
    (i) => i,
  ).where((i) => board[i] == 0).toList();
  final slot = empty[random.nextInt(empty.length)];
  board[slot] = random.nextDouble() < .1 ? 4 : 2;
  return slot;
}

class Tile2048Flight {
  const Tile2048Flight(this.from, this.to, this.value);
  final int from, to, value;
}

class Game2048Move {
  Game2048Move(
    this.before,
    this.after,
    List<Tile2048Flight> flights,
    Set<int> merged,
    this.spawn,
    this.direction,
  ) : flights = List.unmodifiable(flights),
      merged = Set.unmodifiable(merged);
  final Game2048State before, after;
  final List<Tile2048Flight> flights;
  final Set<int> merged;
  final int spawn;
  final Move2048Direction direction;
  bool get firstWin => !before.won && after.won;
}

class Game2048Progress {
  const Game2048Progress({this.highScore = 0, this.session});
  final int highScore;
  final Game2048State? session;
  Map<String, dynamic> toJson() => {
    'highScore': highScore,
    'session': session?.toJson(),
  };
  factory Game2048Progress.fromJson(Map<String, dynamic> json) {
    final high = json['highScore'] as int;
    if (!json.containsKey('session')) throw const FormatException();
    final session = json['session'] == null
        ? null
        : Game2048State.fromJson(json['session'] as Map<String, dynamic>);
    if (high < 0 || high % 4 != 0 || high < (session?.score ?? 0)) {
      throw const FormatException('Invalid 2048 high score');
    }
    return Game2048Progress(highScore: high, session: session);
  }
}
