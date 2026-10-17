import '../app_theme.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../progress_controller.dart';
import '../companion.dart';
import '../device_services.dart';
import '../game_2048.dart';
import '../garden_art.dart';
import '../widgets/board_2048.dart';

class Game2048Page extends StatefulWidget {
  const Game2048Page({super.key, required this.controller});
  final ProgressController controller;
  @override
  State<Game2048Page> createState() => _Game2048PageState();
}

class _Game2048PageState extends State<Game2048Page>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Game2048State? _previous;
  Game2048Move? _move;
  bool _foreground = true, _visible = true, _reduced = false;
  bool _dialog = false, _gestureReady = false;
  bool _gameOverQueued = false;
  String? _gameOverShownFor;
  Offset _swipe = Offset.zero;
  Size? _window;
  int _celebration = 0;
  String _announcement = '';
  ProgressController get _controller => widget.controller;
  Game2048State? get _session => _controller.progress?.game2048.session;
  bool get _active => _foreground && _visible && !_dialog;
  bool get _canMove =>
      _active &&
      !_controller.blocked.value &&
      !_animation.isAnimating &&
      _session != null &&
      !_session!.awaitingContinue &&
      !_session!.gameOver;

  @override
  void initState() {
    super.initState();
    _previous = _session;
    _controller.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _move = null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _session != null) return;
      try {
        await _controller.start2048();
      } catch (_) {}
    });
  }

  void _changed() {
    if (!mounted) return;
    final session = _session;
    if (!identical(_previous, session)) {
      final transition = _controller.last2048Move;
      final animate =
          transition != null &&
          identical(transition.before, _previous) &&
          identical(transition.after, session) &&
          _active;
      _cancelMotion();
      if (animate) {
        _announcement =
            'Moved ${transition.direction.name}. Score ${session!.score}.';
        if (transition.firstWin) {
          _celebration++;
          _announcement = 'You made 2048! 500 XP earned!';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
          });
        } else if (session.gameOver) {
          _announcement += ' No moves left.';
        }
        if (!_reduced) {
          _move = transition;
          _animation.forward(from: 0);
        }
        unawaited(
          requestFeedback(
            _controller.services,
            transition.firstWin
                ? DeviceFeedback.confirm
                : transition.merged.isEmpty
                ? DeviceFeedback.light
                : DeviceFeedback.placement,
            enabled: _controller.settings.haptics,
          ),
        );
      }
      _previous = session;
    }
    setState(() {});
  }

  void _cancelMotion() {
    _gestureReady = false;
    _swipe = Offset.zero;
    _animation.stop();
    _move = null;
    _celebration = 0;
  }

  Future<void> _stopFeedback() async {
    try {
      await _controller.services.stop();
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        (ModalRoute.isCurrentOf(context) ?? true) && TickerMode.of(context);
    final window = MediaQuery.sizeOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!visible ||
        (_window != null && _window != window) ||
        reduced != _reduced) {
      _cancelMotion();
      unawaited(_stopFeedback());
    }
    _window = window;
    _visible = visible;
    _reduced = reduced;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) _cancelMotion();
    });
    if (!_foreground) unawaited(_stopFeedback());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _animation.dispose();
    _focus.dispose();
    _scroll.dispose();
    unawaited(_stopFeedback());
    super.dispose();
  }

  Future<void> _takeMove(Move2048Direction direction) async {
    if (!_canMove) return;
    try {
      await _controller.move2048(direction);
    } catch (_) {}
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.keyA => Move2048Direction.left,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => Move2048Direction.right,
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.keyW => Move2048Direction.up,
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.keyS => Move2048Direction.down,
      _ => null,
    };
    if (direction == null || !_active) return KeyEventResult.ignored;
    if (event is KeyDownEvent) unawaited(_takeMove(direction));
    return KeyEventResult.handled;
  }

  void _endSwipe(DragEndDetails _) {
    final delta = _swipe, eligible = _gestureReady;
    _gestureReady = false;
    _swipe = Offset.zero;
    final major = max(delta.dx.abs(), delta.dy.abs());
    final minor = min(delta.dx.abs(), delta.dy.abs());
    if (!eligible || major < 24 || major < minor * 1.2) return;
    unawaited(
      _takeMove(
        delta.dx.abs() > delta.dy.abs()
            ? (delta.dx < 0 ? Move2048Direction.left : Move2048Direction.right)
            : (delta.dy < 0 ? Move2048Direction.up : Move2048Direction.down),
      ),
    );
  }

  bool get _shouldShowGameOver =>
      _active &&
      !_controller.blocked.value &&
      !_animation.isAnimating &&
      _session != null &&
      _session!.gameOver &&
      !_session!.awaitingContinue &&
      _gameOverShownFor != _session!.id;

  void _queueGameOver() {
    if (_gameOverQueued || !_shouldShowGameOver) return;
    _gameOverQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameOverQueued = false;
      if (mounted && _shouldShowGameOver) {
        unawaited(_restart(gameOver: true));
      }
    });
  }

  Future<void> _restart({bool gameOver = false}) async {
    if (!_active || _controller.blocked.value || _animation.isAnimating) return;
    final sessionId = _session!.id;
    if (gameOver) _gameOverShownFor = sessionId;
    setState(() {
      _dialog = true;
      _cancelMotion();
    });
    unawaited(_stopFeedback());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(gameOver ? 'Game over' : 'Start over?'),
        content: Text(
          gameOver
              ? 'No moves left. Start a fresh board? '
                    'Your high score and earned XP will stay.'
              : 'Start a fresh board? Your high score and earned XP will stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(gameOver ? 'View board' : 'Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _dialog = false);
    _focus.requestFocus();
    if (confirmed == true && _session?.id == sessionId) {
      try {
        await _controller.start2048(restart: true);
      } catch (_) {}
    }
  }

  Widget _score(String label, int score) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GardenColors.of(
          context,
        ).card(rainbow[label == 'Score' ? 4 : 2], white: .78),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(label, textAlign: TextAlign.center),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$score',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header() {
    final session = _session!, progress = _controller.progress!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _score('Score', session.score),
            const SizedBox(width: 12),
            _score('High score', progress.game2048.highScore),
          ],
        ),
        if (session.awaitingContinue) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GardenColors.of(context).card(rainbow[2], white: .8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text(
                  'You made 2048!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Text(
                  '500 XP earned!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                CompanionView(
                  configuration: progress.companion,
                  height: 120,
                  animate: false,
                  reactionTrigger: _celebration,
                  boundedCelebration: true,
                ),
                FilledButton(
                  onPressed: _controller.blocked.value
                      ? null
                      : () async {
                          try {
                            await _controller.continue2048();
                          } catch (_) {}
                          if (mounted) _focus.requestFocus();
                        },
                  child: const Text('Keep playing'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Swipe to slide. Match numbers to make 2048.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'Keyboard: arrow keys or W A S D.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          // Keep the same shade while input is briefly guarded during a move.
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            disabledForegroundColor: colors.primary,
            side: BorderSide(color: colors.outline),
          ),
          onPressed:
              !_active || _controller.blocked.value || _animation.isAnimating
              ? null
              : _restart,
          child: const Text('Start over'),
        ),
        if (_controller.failure != null) _saveError(),
      ],
    );
  }

  Widget _saveError() => Column(
    children: [
      const Text('Could not save yet.', textAlign: TextAlign.center),
      TextButton(
        onPressed: _controller.writing
            ? null
            : () async {
                try {
                  await _controller.retry();
                } catch (_) {}
              },
        child: const Text('Try saving again'),
      ),
    ],
  );

  Widget _board(double side) => SizedBox(
    width: side,
    height: side,
    child: GestureDetector(
      key: const ValueKey('2048-swipe'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        _focus.requestFocus();
        _gestureReady = _canMove;
        _swipe = Offset.zero;
      },
      onPanUpdate: (details) => _swipe += details.delta,
      onPanEnd: _endSwipe,
      onPanCancel: () {
        _gestureReady = false;
        _swipe = Offset.zero;
      },
      child: Board2048(session: _session!, animation: _animation, move: _move),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('2048'),
      leading: IconButton(
        tooltip: 'Back to numbers',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_session == null) {
              return Center(
                child: _controller.failure != null
                    ? _saveError()
                    : const CircularProgressIndicator(
                        semanticsLabel: 'Starting 2048',
                      ),
              );
            }
            _queueGameOver();
            final wide =
                constraints.maxWidth >= 600 &&
                constraints.maxWidth > constraints.maxHeight;
            final side = wide
                ? min(
                    500.0,
                    min(constraints.maxHeight - 32, constraints.maxWidth * .52),
                  )
                : min(500.0, constraints.maxWidth - 32);
            final fitPortrait =
                !wide &&
                !_session!.awaitingContinue &&
                _controller.failure == null &&
                constraints.maxHeight >= 480 &&
                MediaQuery.textScalerOf(context).scale(16) <= 20;
            return Semantics(
              child: Stack(
                children: [
                  if (fitPortrait)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: Column(
                            children: [
                              _header(),
                              const SizedBox(height: 16),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (_, space) => Align(
                                    alignment: Alignment.topCenter,
                                    child: _board(min(side, space.maxHeight)),
                                  ),
                                ),
                              ),
                              _footer(),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _board(side),
                                const SizedBox(width: 24),
                                Flexible(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 350,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [_header(), _footer()],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 500,
                                ),
                                child: Column(
                                  children: [
                                    _header(),
                                    const SizedBox(height: 16),
                                    _board(side),
                                    _footer(),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  Semantics(
                    liveRegion: true,
                    label: _announcement,
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
