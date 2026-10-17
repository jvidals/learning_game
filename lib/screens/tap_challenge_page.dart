import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../companion.dart';
import '../device_services.dart';
import '../progress.dart';
import '../progress_controller.dart';
import '../tap_challenge.dart';
import '../widgets/page_body.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/tap_challenge_art.dart';

class TapChallengePage extends StatefulWidget {
  const TapChallengePage({
    super.key,
    required this.controller,
    this.skin = TapChallengeSkin.unicorn,
    this.clock,
    this.random,
  });
  final ProgressController controller;
  final TapChallengeSkin skin;
  final Stopwatch? clock;
  final Random? random;
  @override
  State<TapChallengePage> createState() => _TapChallengePageState();
}

class _TapChallengePageState extends State<TapChallengePage>
    with WidgetsBindingObserver {
  late final _clock = widget.clock ?? Stopwatch();
  late final _skin = widget.skin;
  Timer? _timer;
  TapChallengeRound? _round;
  TapChallengeResult? _result;
  String? _roundId;
  bool _paused = false, _finishing = false;
  int _startingBest = 0;
  Size? _size;
  final _feedback = <int, (String, Duration)>{};
  ProgressController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_saved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    final covered = ModalRoute.isCurrentOf(context) == false;
    if ((_size != null && _size != size) || covered) _pause();
    _size = size;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _saved() {
    if (!mounted) return;
    final round = _round, progress = _controller.progress;
    if (round?.finished == true &&
        progress != null &&
        progress.lastRewardedRound == 'tap:$_roundId' &&
        !_controller.blocked.value) {
      _result ??= TapChallengeResult(
        round!.score,
        progress.tapChallengeHighScore,
        50,
      );
    }
    setState(() {});
  }

  void _pause() {
    if (_round == null || _round!.finished || _paused) return;
    _clock.stop();
    _timer?.cancel();
    unawaited(_controller.services.stop());
    setState(() => _paused = true);
  }

  void _run() {
    _clock.start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        _round!.tick();
        _feedback.removeWhere((_, value) => value.$2 <= _clock.elapsed);
      });
      if (_round!.finished) unawaited(_finish());
    });
  }

  void _start() {
    if (_controller.blocked.value) return;
    _clock.reset();
    _startingBest = _controller.progress!.tapChallengeHighScore;
    setState(() {
      _roundId = newRoundId();
      _round = TapChallengeRound(
        elapsed: () => _clock.elapsed,
        random: widget.random,
      );
      _result = null;
      _feedback.clear();
      _paused = false;
      _finishing = false;
    });
    _run();
  }

  void _tap(TapTarget target) {
    if (_paused || _round!.finished) return;
    final kind = _round!.tap(target.id);
    if (_round!.finished) {
      unawaited(_finish());
      return;
    }
    if (kind == null) return;
    setState(
      () => _feedback[target.slot] = (
        kind.points > 0 ? '+${kind.points}' : '${kind.points}',
        _clock.elapsed + const Duration(milliseconds: 250),
      ),
    );
    unawaited(
      requestFeedback(
        _controller.services,
        kind == TapTargetKind.hazard
            ? DeviceFeedback.retry
            : DeviceFeedback.light,
        enabled: _controller.settings.haptics,
      ),
    );
  }

  Future<void> _finish() async {
    if (_finishing || _result != null) return;
    _clock.stop();
    _timer?.cancel();
    setState(() => _finishing = true);
    try {
      final result = await _controller.completeTapChallengeRound(
        _roundId!,
        _round!.score,
      );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      // SaveStatus retries the controller's exact snapshot, even after Back.
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    _controller.removeListener(_saved);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.services.stop());
    super.dispose();
  }

  Widget _legend() => Column(
    children: [
      for (final kind in TapTargetKind.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 56,
                child: _skin[kind].builder(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${kind == TapTargetKind.hazard ? 'Avoid' : 'Tap'} ${_skin[kind].label} · ${kind.points > 0 ? '+' : ''}${kind.points}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final round = _round;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap Challenge'),
        leading: IconButton(
          tooltip: 'Back to Reflex',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: round != null && !round.finished && !_paused
          ? _activeBody(round)
          : PageBody(
              children: [
                if (round == null) ...[
                  const Text(
                    'How many can you tap in 30 seconds?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  _legend(),
                  Text(
                    'Best: ${_controller.progress!.tapChallengeHighScore}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _controller.blocked.value ? null : _start,
                    child: const Text('Start'),
                  ),
                ] else if (_paused && !round.finished) ...[
                  const Text(
                    'Paused',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${round.secondsLeft} seconds left · Score: ${round.score}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      setState(() => _paused = false);
                      _run();
                    },
                    child: const Text('Resume'),
                  ),
                ] else ...[
                  Text(
                    'Score: ${round.score}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Best: ${_result?.highScore ?? _startingBest}',
                    textAlign: TextAlign.center,
                  ),
                  if (_result?.xpAwarded == 50) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'New best! 50 XP earned!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    CompanionView(
                      configuration: _controller.progress!.companion,
                      height: 150,
                      reactionTrigger: 1,
                      animate: false,
                    ),
                    LevelProgress(progress: _controller.progress!),
                    RewardChoices(controller: _controller),
                  ] else if (_result != null)
                    const Text('Well played!', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _result == null || _controller.blocked.value
                        ? null
                        : _start,
                    child: const Text('Play again'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Reflex'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    child: const Text('Back to home'),
                  ),
                ],
                SaveStatus(controller: _controller),
              ],
            ),
    );
  }

  Widget _activeBody(TapChallengeRound round) => SafeArea(
    child: LayoutBuilder(
      builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight * 1.2;
        final status = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${round.secondsLeft} seconds',
              key: const ValueKey('tap-time'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              'Score: ${round.score}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text('Best: $_startingBest'),
            TextButton.icon(
              onPressed: _pause,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Pause'),
            ),
          ],
        );
        final maxSide = landscape
            ? min(box.maxHeight - 24, box.maxWidth * .55)
            : min(box.maxWidth - 24, 420.0);
        final arena = SizedBox.square(dimension: maxSide, child: _arena(round));
        if (landscape) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: SingleChildScrollView(child: status)),
                const SizedBox(width: 12),
                arena,
              ],
            ),
          );
        }
        return Column(
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(8), child: status),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: arena,
            ),
          ],
        );
      },
    ),
  );

  Widget _arena(TapChallengeRound round) {
    final colors = GardenColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.boardSlot,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: List.generate(9, (slot) {
            final targets = round.targets.where(
              (target) => target.slot == slot,
            );
            final target = targets.isEmpty ? null : targets.first;
            if (target == null) {
              return Center(
                child: Text(
                  _feedback[slot]?.$1 ?? '',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: colors.foreground,
                  ),
                ),
              );
            }
            final appearance = _skin[target.kind];
            return Semantics(
              label:
                  '${appearance.label}, ${target.kind == TapTargetKind.hazard ? 'avoid, minus 2 points' : 'plus ${target.kind.points} points'}',
              button: true,
              onTap: () => _tap(target),
              child: ExcludeSemantics(
                child: FilledButton(
                  key: ValueKey('tap-target-${target.id}'),
                  onPressed: () => _tap(target),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(10),
                    backgroundColor: colors.surface,
                    foregroundColor: colors.foreground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: colors.outline),
                    ),
                  ),
                  child: appearance.builder(context),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
