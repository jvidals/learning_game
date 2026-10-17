import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../app_theme.dart';
import '../device_services.dart';
import '../garden_art.dart' show rainbow;
import '../progress.dart';
import '../progress_controller.dart';
import '../widgets/page_body.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/sound_it_out.dart';
import '../widgets/success_celebration.dart';
import '../word_bank.dart';
import '../word_sprint.dart';

class WordSprintPage extends StatefulWidget {
  const WordSprintPage({
    super.key,
    required this.controller,
    required this.services,
  });
  final ProgressController controller;
  final DeviceServices services;
  @override
  State<WordSprintPage> createState() => _WordSprintPageState();
}

class _WordSprintPageState extends State<WordSprintPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  WordSprintMode _mode = WordSprintMode.mix;
  WordSprintSession? _session;
  WordSprintResult? _result;
  Timer? _timer;
  int _remainingMs = 60000, _audioRequest = 0, _startingBest = 0;
  String? _roundId;
  bool _timed = true, _paused = false, _sheetOpen = false;
  bool _foreground = true, _eligible = false, _saving = false;
  bool _awaitingSave = false;
  final _sheetChanges = ValueNotifier(0);
  final _gridScroll = ScrollController();
  late final AnimationController _celebration;
  ProgressController get _controller => widget.controller;
  int get _seconds => (_remainingMs / 1000).ceil();
  bool get _active =>
      _session != null &&
      !_session!.finished &&
      !_paused &&
      !_sheetOpen &&
      _foreground;

  @override
  void initState() {
    super.initState();
    _celebration = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_saved);
  }

  void _saved() {
    if (!mounted) return;
    if (!_controller.soundOn) _cancelAudio();
    _sheetChanges.value++;
    // SaveStatus owns retries. Recover this exact result after its pending
    // snapshot is durably saved, without submitting the run a second time.
    if (_awaitingSave &&
        !_saving &&
        !_controller.blocked.value &&
        _controller.failure == null &&
        (_controller.progress?.wordSprintBest ?? 0) >= _session!.count) {
      _acceptResult(
        WordSprintResult(
          _session!.count,
          _controller.progress!.wordSprintBest,
          _session!.count > _startingBest,
        ),
      );
    }
    setState(() {});
  }

  void _acceptResult(WordSprintResult result) {
    _result = result;
    _awaitingSave = false;
    if (result.newBest && !MediaQuery.disableAnimationsOf(context)) {
      _celebration.forward(from: 0);
    }
  }

  void _start() {
    if (_controller.blocked.value) return;
    _timer?.cancel();
    _celebration.reset();
    setState(() {
      _session = WordSprintSession(mode: _mode);
      _roundId = newRoundId();
      _remainingMs = 60000;
      _timed = _controller.settings.wordSprintTimer;
      _startingBest = _controller.progress?.wordSprintBest ?? 0;
      _result = null;
      _paused = !_foreground;
      _eligible = _saving = _awaitingSave = false;
    });
    _runTimer();
  }

  void _runTimer() {
    _timer?.cancel();
    if (!_active || !_timed) return;
    final initialMs = _remainingMs;
    // Timer.tick includes missed ticks, and is driven by fake time in tests.
    // Each resumed segment starts from its saved remaining active time.
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_active) return;
      setState(() {
        _remainingMs = math.max(0, initialMs - timer.tick * 100);
      });
      if (_remainingMs == 0) unawaited(_finish(completed: true));
    });
  }

  void _pause() {
    _timer?.cancel();
    _cancelAudio();
    if (_session != null && !_session!.finished) {
      setState(() => _paused = true);
    }
    _sheetChanges.value++;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _pause();
  }

  void _resume() {
    if (!_foreground || _controller.blocked.value) return;
    setState(() => _paused = false);
    _runTimer();
  }

  void _mark(int index) {
    if (!_active || _controller.blocked.value) return;
    setState(() => _session!.mark(index));
    unawaited(
      requestFeedback(
        widget.services,
        DeviceFeedback.light,
        enabled: _controller.settings.haptics,
      ),
    );
  }

  Future<void> _finish({bool completed = false}) async {
    final session = _session;
    if (session == null || session.finished) return;
    _timer?.cancel();
    _cancelAudio();
    setState(() {
      session.finish();
      _eligible = _timed && completed;
      _awaitingSave = _saving = _eligible;
    });
    if (!_eligible) return;
    try {
      final result = await _controller.recordWordSprint(
        _roundId!,
        session.count,
      );
      if (mounted) setState(() => _acceptResult(result));
    } catch (_) {
      // The shared SaveStatus retries the originating player's exact snapshot.
    } finally {
      if (mounted) {
        _saving = false;
        _saved();
      }
    }
  }

  void _cancelAudio() {
    _audioRequest++;
    unawaited(widget.services.stop().catchError((Object _) {}));
  }

  Future<bool> _playSequence(
    List<List<String>> steps, {
    void Function(int step)? onStep,
  }) async {
    final request = ++_audioRequest;
    bool active() =>
        mounted &&
        request == _audioRequest &&
        _sheetOpen &&
        !_paused &&
        _foreground &&
        _controller.soundOn;
    if (!active()) return false;
    try {
      await widget.services.stop();
      for (var step = 0; step < steps.length; step++) {
        if (!active()) return false;
        onStep?.call(step);
        for (final clip in steps[step]) {
          if (!active()) return false;
          await widget.services.play(clip);
          if (!active()) return false;
        }
      }
      return active();
    } catch (_) {
      return false;
    }
  }

  Future<void> _showSound(DecodableWord word) async {
    if (!_active || _controller.blocked.value) return;
    _timer?.cancel();
    _cancelAudio();
    setState(() => _sheetOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => ListenableBuilder(
          listenable: _sheetChanges,
          builder: (_, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Sound it out', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                SoundItOut(
                  word: word,
                  includeWholeWord: word.real,
                  playSequence: _playSequence,
                  soundOn: _controller.soundOn,
                  enabled: _foreground && !_paused,
                  fontSize: 48,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _cancelAudio();
      if (mounted) {
        setState(() => _sheetOpen = false);
        _runTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelAudio();
    _controller.removeListener(_saved);
    WidgetsBinding.instance.removeObserver(this);
    _celebration.dispose();
    _gridScroll.dispose();
    _sheetChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) return;
      _foreground = false;
      _timer?.cancel();
      _cancelAudio();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Word Sprint'),
        leading: IconButton(
          tooltip: 'Back to words',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            _timer?.cancel();
            _cancelAudio();
            Navigator.pop(context);
          },
        ),
      ),
      body: _session == null
          ? _startView()
          : _session!.finished
          ? _results()
          : _paused
          ? _pauseView()
          : _runView(),
    ),
  );

  Widget _startView() => PageBody(
    children: [
      const Text(
        'Read each word out loud, then tap it.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 20),
      for (final mode in WordSprintMode.values) ...[
        Semantics(
          key: ValueKey('sprint-mode-${mode.name}'),
          selected: _mode == mode,
          inMutuallyExclusiveGroup: true,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 56),
              padding: const EdgeInsets.all(12),
              backgroundColor: _mode == mode
                  ? GardenColors.of(context).selectedSurface
                  : GardenColors.of(context).surface,
              side: BorderSide(
                color: _mode == mode
                    ? GardenColors.of(context).primary
                    : GardenColors.of(context).outline,
                width: _mode == mode ? 2 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => setState(() => _mode = mode),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: _mode == mode ? const Icon(Icons.check_rounded) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(mode.label)),
              ],
            ),
          ),
        ),
        if (mode != WordSprintMode.values.last) const SizedBox(height: 8),
      ],
      const SizedBox(height: 16),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('1-minute timer'),
        value: _controller.effectiveSettings.wordSprintTimer,
        onChanged: _controller.blocked.value
            ? null
            : (value) async {
                try {
                  await _controller.setWordSprintTimer(value);
                } catch (_) {}
              },
      ),
      if (_controller.effectiveSettings.wordSprintTimer &&
          (_controller.progress?.wordSprintBest ?? 0) > 0)
        Text(
          'Best: ${_controller.progress!.wordSprintBest} words',
          textAlign: TextAlign.center,
        ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _controller.blocked.value ? null : _start,
        child: const Text('Start'),
      ),
      SaveStatus(controller: _controller),
    ],
  );

  Widget _count({bool compact = false}) => Semantics(
    liveRegion: true,
    child: Text(
      'Words read: ${_session!.count}',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: compact ? 20 : 22,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _countdown({bool compact = false}) => Text(
    compact ? '${_seconds}s' : '$_seconds seconds',
    key: const ValueKey('sprint-time'),
    semanticsLabel: '$_seconds seconds',
    style: TextStyle(fontSize: compact ? 20 : 24, fontWeight: FontWeight.w800),
  );

  Widget _timeProgress() => LinearProgressIndicator(
    value: _remainingMs / 60000,
    minHeight: 8,
    color: GardenColors.of(context).primary,
    backgroundColor: GardenColors.of(context).panel,
    semanticsLabel: 'Time left',
    semanticsValue: '$_seconds seconds',
  );

  Widget _time() => Column(
    children: [_countdown(), const SizedBox(height: 8), _timeProgress()],
  );

  Widget _pauseView() => PageBody(
    children: [
      const Text(
        'Paused',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      _count(),
      if (_timed) _time(),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _controller.blocked.value ? null : _resume,
        child: const Text('Resume'),
      ),
      OutlinedButton(onPressed: () => _finish(), child: const Text('Stop')),
      SaveStatus(controller: _controller),
    ],
  );

  Widget _runView() => SafeArea(
    child: LayoutBuilder(
      builder: (context, box) {
        final font = MediaQuery.textScalerOf(context).scale(40);
        final compact = box.maxHeight < 500 && box.maxWidth >= 600;
        final preferred = box.maxWidth >= 600 ? 5 : 3;
        // Reserve enough width for three letters at the current text scale.
        final columns = math.max(
          1,
          math.min(preferred, ((box.maxWidth - 24) / (font * 2 + 28)).floor()),
        );
        return Column(
          children: [
            // Keep status visible; short, wide windows share a compact row.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * .45),
              child: SingleChildScrollView(
                primary: false,
                padding: EdgeInsets.fromLTRB(
                  12,
                  compact ? 4 : 8,
                  12,
                  compact ? 4 : 8,
                ),
                child: Column(
                  children: [
                    if (compact) ...[
                      Row(
                        children: [
                          Expanded(child: _count(compact: true)),
                          if (_timed) ...[
                            const SizedBox(width: 16),
                            _countdown(compact: true),
                          ],
                        ],
                      ),
                      if (_timed) ...[
                        const SizedBox(height: 6),
                        _timeProgress(),
                      ],
                    ] else ...[
                      _count(),
                      if (_timed) ...[const SizedBox(height: 8), _time()],
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                key: PageStorageKey('word-sprint-grid-$_roundId'),
                controller: _gridScroll,
                slivers: [
                  if (!compact)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      sliver: SliverToBoxAdapter(
                        child: const Text(
                          'Hold a word to sound it out.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: math.max(
                          100,
                          font * 1.3 + (compact ? 24 : 32),
                        ),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _wordTile(index),
                        childCount: _session!.words.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 8 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (compact) ...[
                    const Expanded(
                      child: Text(
                        'Hold a word to sound it out.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    flex: compact ? 0 : 1,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (!_timed)
                          FilledButton(
                            onPressed: () => _finish(),
                            child: const Text('Done'),
                          ),
                        OutlinedButton(
                          onPressed: () => _finish(),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _wordTile(int index) {
    final word = _session!.words[index];
    final marked = _session!.isMarked(index);
    final colors = GardenColors.of(context);
    final enabled = _active && !_controller.blocked.value;
    return Semantics(
      key: ValueKey('sprint-word-$index'),
      label: '${word.spelling}, ${marked ? 'read' : 'not read'}',
      button: true,
      toggled: marked,
      enabled: enabled,
      onTap: enabled ? () => _mark(index) : null,
      customSemanticsActions: enabled
          ? {
              const CustomSemanticsAction(label: 'Sound it out'): () =>
                  _showSound(word),
            }
          : null,
      child: ExcludeSemantics(
        child: Material(
          color: marked
              ? colors.successSurface
              : colors.card(rainbow[(index % 3) * 2], white: .65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: marked
                ? BorderSide(color: colors.successBorder)
                : colors.isDark
                ? BorderSide(color: colors.accent(rainbow[(index % 3) * 2]))
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => _mark(index) : null,
            onLongPress: enabled ? () => _showSound(word) : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      word.spelling,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ),
                if (marked)
                  Positioned(
                    top: 4,
                    right: 6,
                    child: Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: colors.successText,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results() => PageBody(
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          'You read ${_session!.count} words!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 20),
      if (_result?.newBest == true)
        SuccessCelebration(
          animation: _celebration,
          active: !MediaQuery.disableAnimationsOf(context),
          child: Semantics(
            liveRegion: true,
            child: Text(
              'New best!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: GardenColors.of(context).successText,
              ),
            ),
          ),
        )
      else if (_result != null)
        const Text('Well read!', textAlign: TextAlign.center),
      if (_result != null) ...[
        const SizedBox(height: 8),
        Text('Best: ${_result!.best} words', textAlign: TextAlign.center),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _controller.blocked.value || (_eligible && _result == null)
            ? null
            : _start,
        child: const Text('Play again'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to words'),
      ),
      SaveStatus(controller: _controller),
    ],
  );
}
