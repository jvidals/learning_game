import '../app_theme.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../progress_controller.dart';
import '../device_services.dart';
import '../handwriting.dart';
import '../writing.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/success_celebration.dart';
import '../widgets/writing_pad.dart';
import '../widgets/watch_button.dart';

class _FormDraft {
  final trace = WritingInk(), freehand = WritingInk();
  bool passed = false;
  String message = '';
  void clear() {
    trace.clear();
    freehand.clear();
    passed = false;
    message = '';
  }

  void cancel() {
    trace.cancel();
    freehand.cancel();
  }

  void dispose() {
    trace.dispose();
    freehand.dispose();
  }
}

class _PairDraft {
  final upper = _FormDraft(), lower = _FormDraft();
  bool lowercase = false;
  _FormDraft get current => lowercase ? lower : upper;
  void clear() {
    upper.clear();
    lower.clear();
    lowercase = false;
  }

  void cancel() {
    upper.cancel();
    lower.cancel();
  }

  void dispose() {
    upper.dispose();
    lower.dispose();
  }
}

class WritingPage extends StatefulWidget {
  const WritingPage({super.key, required this.controller});
  final ProgressController controller;
  @override
  State<WritingPage> createState() => _WritingPageState();
}

class _WritingPageState extends State<WritingPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _shuffledDraft = _PairDraft(), _practiceDraft = _PairDraft();
  _PairDraft get _pairDraft => _practice ? _practiceDraft : _shuffledDraft;
  _FormDraft get _draft => _pairDraft.current;
  WritingInk get _trace => _draft.trace;
  WritingInk get _freehand => _draft.freehand;
  bool get _lowercase => _pairDraft.lowercase;
  set _lowercase(bool value) => _pairDraft.lowercase = value;
  bool get _justPassed => _draft.passed;
  set _justPassed(bool value) => _draft.passed = value;
  String get _message => _draft.message;
  set _message(String value) => _draft.message = value;
  bool _pendingEarned = false;
  late final AnimationController _watch;
  late final AnimationController _sparkle;
  final _scroll = ScrollController();
  bool _foreground = true, _visible = true;
  bool _checking = false;
  // A new saved letter can arrive while its write still blocks input. Play
  // once it is ready, without replaying for ordinary controller rebuilds.
  bool _reducedMotion = false, _watchPending = true;
  int? _practiceLetter;
  int _practiceForms = 0;
  String? _position, _pendingSuccess;
  ProgressController get _controller => widget.controller;
  WritingProgress? get _progress => _controller.progress?.writing;
  bool get _practice => _practiceLetter != null;
  bool get _active => _foreground && _visible;
  bool get _enabled => _active && !_controller.blocked.value && !_checking;
  int get _letter => _practiceLetter ?? _progress?.letter ?? 0;
  String get _upper => String.fromCharCode(65 + _letter);
  String get _character => _lowercase ? _upper.toLowerCase() : _upper;
  int get _forms => _practice ? _practiceForms : (_progress?.currentForms ?? 0);
  String get _formToken => '${_progress?.id}:${_progress?.index}:$_lowercase';
  Iterable<WritingInk> get _traceInks => [
    _shuffledDraft.upper.trace,
    _shuffledDraft.lower.trace,
    _practiceDraft.upper.trace,
    _practiceDraft.lower.trace,
  ];

  @override
  void initState() {
    super.initState();
    _watch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_changed);
    for (final ink in _traceInks) {
      ink.addListener(_traceChanged);
    }
    _position = '${_progress?.id}:${_progress?.index}';
    _lowercase = _forms == 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _progress == null && !_controller.blocked.value) {
        unawaited(_start());
      }
    });
  }

  Future<void> _start({bool restart = false}) async {
    try {
      await _controller.startWriting(restart: restart);
    } catch (_) {}
  }

  void _clearInk() {
    _trace.clear();
    _freehand.clear();
    _justPassed = false;
    _message = '';
    _sparkle.reset();
  }

  void _changed() {
    if (!mounted) return;
    if (_controller.blocked.value) _watch.stop();
    final nextPosition = '${_progress?.id}:${_progress?.index}';
    if (nextPosition != _position && !_practice) {
      _position = nextPosition;
      _shuffledDraft.clear();
      _lowercase = _forms == 1;
      _pendingSuccess = null;
      _clearInk();
      _watchPending = true;
    }
    if (_pendingSuccess == _formToken &&
        !_controller.blocked.value &&
        _progress?.completed(_lowercase) == true) {
      _pendingSuccess = null;
      _success(earned: _pendingEarned);
    }
    _playPendingWatch();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        (ModalRoute.isCurrentOf(context) ?? true) && TickerMode.of(context);
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _watch.stop();
      _sparkle.stop();
    }
    if (!_visible) _interrupt();
    _playPendingWatch();
  }

  void _traceChanged() {
    if (_trace.drawing && _watch.isAnimating) setState(_watch.stop);
  }

  void _playPendingWatch() {
    if (!_watchPending ||
        !_enabled ||
        _progress == null ||
        (!_practice && _progress!.finished)) {
      return;
    }
    _watchPending = false;
    if (!_reducedMotion) _watch.forward(from: 0);
  }

  void _replay() {
    if (!_enabled) return;
    _trace.cancel();
    setState(() {
      _watch.stop();
      _watchPending = true;
      _playPendingWatch();
    });
  }

  void _interrupt() {
    _watchPending = false;
    _watch.stop();
    _shuffledDraft.cancel();
    _practiceDraft.cancel();
    _sparkle.stop();
  }

  @override
  void didChangeMetrics() {
    _interrupt();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _interrupt();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    for (final ink in _traceInks) {
      ink.removeListener(_traceChanged);
    }
    _watch.dispose();
    _shuffledDraft.dispose();
    _practiceDraft.dispose();
    _sparkle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _success({required bool earned}) {
    _justPassed = true;
    _message = earned
        ? 'Both letters complete! 10 XP earned!'
        : 'Lovely writing!';
    if (_active) {
      if (!MediaQuery.disableAnimationsOf(context)) _sparkle.forward(from: 0);
      unawaited(
        requestFeedback(
          _controller.services,
          DeviceFeedback.placement,
          enabled: _controller.settings.haptics,
        ),
      );
    }
  }

  Future<void> _check() async {
    if (!_enabled ||
        _justPassed ||
        _freehand.isEmpty ||
        _freehand.drawing ||
        _freehand.overflow)
      return;
    setState(() {
      _watch.stop();
      _checking = true;
    });
    final result = evaluateWriting(
      letterTemplates[_character]!,
      _freehand.strokes,
    );
    if (!result.accepted) {
      setState(() {
        _message = result.message;
        _checking = false;
      });
      unawaited(
        requestFeedback(
          _controller.services,
          DeviceFeedback.retry,
          enabled: _controller.settings.haptics,
        ),
      );
      return;
    }
    if (_practice) {
      setState(() {
        _practiceForms |= _lowercase ? 2 : 1;
        _success(earned: false);
        _checking = false;
      });
      return;
    }
    final progress = _progress!;
    if (progress.completed(_lowercase)) {
      setState(() {
        _success(earned: false);
        _checking = false;
      });
      return;
    }
    _pendingEarned = progress.completed(!_lowercase);
    _pendingSuccess = _formToken;
    try {
      await _controller.completeWritingForm(
        progress.id,
        progress.index,
        _lowercase,
      );
    } catch (_) {
      // SaveStatus retries the exact intended profile document, even after Back.
    }
    if (mounted) setState(() => _checking = false);
  }

  void _selectCase(bool lowercase) {
    if (!_enabled || lowercase == _lowercase) return;
    _interrupt();
    setState(() {
      _lowercase = lowercase;
      _watchPending = true;
      _playPendingWatch();
    });
    _toTop();
  }

  Future<void> _advance() async {
    if (!_enabled || _practice) return;
    final progress = _progress!;
    try {
      await _controller.advanceWriting(progress.id, progress.index);
    } catch (_) {}
    if (mounted && !_controller.blocked.value) _toTop();
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _picker() async {
    if (!_enabled || _progress == null) return;
    _interrupt();
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: SingleChildScrollView(
            key: const ValueKey('letter-picker-scroll'),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Choose a letter',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close letter picker',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('pick-shuffle'),
                      onPressed: () => Navigator.pop(context, -1),
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Shuffled alphabet'),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Practice only · no XP',
                    textAlign: TextAlign.center,
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gridPadding = 16.0, spacing = 10.0;
                    const buttonPadding = EdgeInsets.all(16);
                    final scaler = MediaQuery.textScalerOf(context);
                    final theme = Theme.of(context);
                    final labelStyle =
                        (theme.outlinedButtonTheme.style?.textStyle?.resolve(
                                  {},
                                ) ??
                                theme.textTheme.labelLarge!)
                            .copyWith(fontSize: 26);
                    final painter = TextPainter(
                      textDirection: Directionality.of(context),
                      textScaler: scaler,
                      maxLines: 1,
                    );
                    var labelWidth = 0.0, labelHeight = 0.0;
                    for (var i = 0; i < 26; i++) {
                      final upper = String.fromCharCode(65 + i);
                      painter.text = TextSpan(
                        text: '$upper${upper.toLowerCase()}',
                        style: labelStyle,
                      );
                      painter.layout();
                      labelWidth = math.max(labelWidth, painter.width);
                      labelHeight = math.max(labelHeight, painter.height);
                    }
                    painter.dispose();
                    // Include both grid and button padding; wide pairs such as
                    // Mm must fit at the user's font size without wrapping.
                    final cellWidth = math.max(
                      56.0,
                      labelWidth.ceilToDouble() + buttonPadding.horizontal,
                    );
                    final available = constraints.maxWidth - 2 * gridPadding;
                    final columns =
                        ((available + spacing) / (cellWidth + spacing))
                            .floor()
                            .clamp(1, 6);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(gridPadding),
                      itemCount: 26,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        mainAxisExtent: math.max(
                          64 * scaler.scale(1),
                          labelHeight.ceilToDouble() + buttonPadding.vertical,
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final upper = String.fromCharCode(65 + index);
                        return Semantics(
                          label:
                              'Practise uppercase $upper and lowercase ${upper.toLowerCase()}',
                          selected: index == _letter,
                          child: OutlinedButton(
                            key: ValueKey('pick-letter-$upper'),
                            style: OutlinedButton.styleFrom(
                              padding: buttonPadding,
                            ),
                            onPressed: () => Navigator.pop(context, index),
                            child: ExcludeSemantics(
                              child: Text(
                                '$upper${upper.toLowerCase()}',
                                style: labelStyle,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == -1) {
      _resumeShuffle();
      return;
    }
    setState(() {
      _practiceDraft.clear();
      _practiceLetter = selected;
      _practiceForms = 0;
      _lowercase = false;
      _watchPending = true;
      _playPendingWatch();
    });
    _toTop();
  }

  void _resumeShuffle() {
    if (_controller.blocked.value || _checking) return;
    setState(() {
      _practiceLetter = null;
      _position = '${_progress?.id}:${_progress?.index}';
      _watchPending = true;
      _playPendingWatch();
    });
    _toTop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Handwriting'),
      leading: IconButton(
        tooltip: 'Back to writing',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          key: const ValueKey('writing-picker'),
          tooltip: 'Choose a letter',
          onPressed: _enabled ? _picker : null,
          icon: const Icon(Icons.grid_view_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final tablet =
                    MediaQuery.sizeOf(context).shortestSide >= 600 &&
                    _progress != null &&
                    (_practice || !_progress!.finished);
                return SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(16, 4, 16, tablet ? 16 : 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 1000,
                        minHeight: tablet
                            ? math.max(0, viewport.maxHeight - 20)
                            : 0,
                      ),
                      child: Column(
                        // A minimum viewport height places spare space between
                        // the lesson header and pads. Taller content still scrolls.
                        mainAxisAlignment: tablet
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_progress == null) ...[
                            const Text(
                              'Opening your alphabet…',
                              textAlign: TextAlign.center,
                            ),
                            if (!_controller.blocked.value)
                              FilledButton(
                                onPressed: _start,
                                child: const Text('Open alphabet'),
                              ),
                          ] else if (!_practice && _progress!.finished)
                            ..._summary()
                          else
                            ..._lesson(tablet: tablet),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_progress != null && (_practice || !_progress!.finished))
            _actions(),
          SaveStatus(controller: _controller),
        ],
      ),
    ),
  );

  List<Widget> _lesson({required bool tablet}) => tablet
      ? [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._lessonHeader(),
              // Keep Watch beside Skip so the pads fit at 960×600 without scrolling.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 24,
                children: [
                  _watchButton(),
                  if (!_practice && _forms != 3) _skipLetter(),
                ],
              ),
            ],
          ),
          _pads(tablet: true),
        ]
      : [
          ..._lessonHeader(),
          _pads(tablet: false),
          if (!_practice && _forms != 3) _skipLetter(),
        ];

  Widget _watchButton() => WatchButton(
    buttonKey: const ValueKey('writing-watch'),
    semanticsLabel: 'Watch how to write $_character',
    onPressed: _enabled ? _replay : null,
  );

  Widget _skipLetter() => TextButton(
    onPressed: _enabled ? _advance : null,
    child: const Text('Skip letter'),
  );

  List<Widget> _lessonHeader() => [
    Text(
      _practice
          ? 'Practice only · no XP'
          : 'Letter ${_progress!.index + 1} of 26 · ${_progress!.completedPairs} ${_progress!.completedPairs == 1 ? 'pair' : 'pairs'} complete',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 4),
    Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      children: [
        _formBadge(_upper, false, (_forms & 1) != 0),
        _formBadge(_upper.toLowerCase(), true, (_forms & 2) != 0),
      ],
    ),
    if (!_practice)
      Text(
        _forms == 3
            ? '10 XP already saved for this letter.'
            : 'Write both letters to earn 10 XP.',
        textAlign: TextAlign.center,
      ),
    const SizedBox(height: 8),
  ];

  Widget _pads({required bool tablet}) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      final height = wide
          ? 240.0
          : (MediaQuery.sizeOf(context).height >= 800 ? 200.0 : 180.0);
      Widget header(bool trace) => LayoutBuilder(
        builder: (context, header) {
          final label = Text(
            trace ? 'Trace the example' : 'Now write it yourself',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          );
          if (tablet) return label;
          final watch = _watchButton();
          if (trace &&
              header.maxWidth < 500 &&
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                Align(alignment: Alignment.centerRight, child: watch),
              ],
            );
          }
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: wide || trace ? 48 : 0),
            child: Row(
              children: [
                Expanded(child: label),
                if (trace) watch,
              ],
            ),
          );
        },
      );
      Widget pad(bool trace) => SizedBox(
        height: height,
        child: AnimatedBuilder(
          animation: _watch,
          builder: (context, _) => WritingPad(
            key: ValueKey(trace ? 'trace-pad' : 'freehand-pad'),
            ink: trace ? _trace : _freehand,
            template: letterTemplates[_character]!,
            trace: trace,
            enabled: _enabled,
            watchProgress:
                trace && _watch.isAnimating && !_reducedMotion && _enabled
                ? _watch.value
                : null,
          ),
        ),
      );
      Widget area(bool trace) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header(trace), const SizedBox(height: 4), pad(trace)],
      );
      Widget pair(Widget left, Widget right) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 20),
          Expanded(child: right),
        ],
      );
      return wide
          ? Column(
              children: [
                pair(header(true), header(false)),
                const SizedBox(height: 4),
                pair(pad(true), pad(false)),
              ],
            )
          : Column(
              children: [area(true), const SizedBox(height: 8), area(false)],
            );
    },
  );

  String get _continueLabel => _forms != 3
      ? (_lowercase ? 'Next: uppercase' : 'Next: lowercase')
      : _practice
      ? 'Practice this letter again'
      : _progress!.index == 25
      ? 'See alphabet reward'
      : 'Next letter';

  void _continue() {
    if (!_enabled) return;
    if (_forms != 3) {
      _selectCase(!_lowercase);
    } else if (_practice) {
      setState(() {
        _practiceDraft.clear();
        _practiceForms = 0;
        _watchPending = true;
        _playPendingWatch();
      });
      _toTop();
    } else {
      unawaited(_advance());
    }
  }

  Widget _actions() => ListenableBuilder(
    listenable: _freehand,
    builder: (context, _) {
      final complete = (_forms & (_lowercase ? 2 : 1)) != 0;
      final canCheck =
          _enabled &&
          !_justPassed &&
          !_freehand.isEmpty &&
          !_freehand.drawing &&
          !_freehand.overflow;
      final retry = complete && !_justPassed && !_freehand.isEmpty;
      final message = _freehand.overflow
          ? 'Clear the space and write one letter.'
          : _message;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: SuccessCelebration(
                    animation: _sparkle,
                    active:
                        _justPassed && !MediaQuery.disableAnimationsOf(context),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              if (MediaQuery.sizeOf(context).width < 500 &&
                  MediaQuery.textScalerOf(context).scale(1) > 1.3)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: _enabled ? () => setState(_clearInk) : null,
                      child: const Text('Clear'),
                    ),
                    const SizedBox(height: 4),
                    complete
                        ? FilledButton(
                            key: const ValueKey('writing-continue'),
                            onPressed: _enabled ? _continue : null,
                            child: Text(
                              _continueLabel,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : FilledButton(
                            key: const ValueKey('writing-check'),
                            onPressed: canCheck ? _check : null,
                            child: const Text('Check'),
                          ),
                  ],
                )
              else
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _enabled ? () => setState(_clearInk) : null,
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: complete
                          ? FilledButton(
                              key: const ValueKey('writing-continue'),
                              onPressed: _enabled ? _continue : null,
                              child: Text(
                                _continueLabel,
                                textAlign: TextAlign.center,
                              ),
                            )
                          : FilledButton(
                              key: const ValueKey('writing-check'),
                              onPressed: canCheck ? _check : null,
                              child: const Text('Check'),
                            ),
                    ),
                  ],
                ),
              if (retry)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton.icon(
                    key: const ValueKey('writing-check'),
                    onPressed: canCheck ? _check : null,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Check'),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _formBadge(
    String character,
    bool lowercase,
    bool complete,
  ) => Semantics(
    label:
        '${lowercase ? 'Lowercase' : 'Uppercase'} $character, ${complete ? 'complete' : 'not complete'}',
    selected: _lowercase == lowercase,
    button: true,
    enabled: _enabled,
    onTap: _enabled ? () => _selectCase(lowercase) : null,
    child: ExcludeSemantics(
      child: OutlinedButton(
        key: ValueKey(lowercase ? 'case-lower' : 'case-upper'),
        onPressed: _enabled ? () => _selectCase(lowercase) : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          backgroundColor: _lowercase == lowercase
              ? GardenColors.of(context).selectedSurface
              : Colors.transparent,
          side: BorderSide(
            color: _lowercase == lowercase
                ? GardenColors.of(context).primary
                : Colors.transparent,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              character,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            ),
            if (complete)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: GardenColors.of(context).resolve(
                    const Color(0xFF28744C),
                    GardenColors.of(context).successText,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _summary() => [
    const Text(
      'Alphabet finished!',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 12),
    Text(
      '${_progress!.completedPairs} ${_progress!.completedPairs == 1 ? 'pair' : 'pairs'} complete · ${_progress!.completedPairs * writingPairXp} XP earned',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 22),
    ),
    const SizedBox(height: 20),
    LevelProgress(progress: _controller.progress!),
    const SizedBox(height: 20),
    RewardChoices(controller: _controller),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: _enabled ? () => _start(restart: true) : null,
      child: const Text('New shuffled alphabet'),
    ),
    const SizedBox(height: 12),
    OutlinedButton(
      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: const Text('Back to home'),
    ),
  ];
}
