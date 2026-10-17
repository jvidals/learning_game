import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../cursive.dart';
import '../progress_controller.dart';
import '../widgets/cursive_pad.dart';
import '../widgets/success_celebration.dart';
import '../widgets/writing_pad.dart';

/// Visit-local lowercase practice: no player progress or settings are touched.
class CursivePage extends StatefulWidget {
  const CursivePage({super.key, required this.controller});
  final ProgressController controller;

  @override
  State<CursivePage> createState() => _CursivePageState();
}

class _CursivePageState extends State<CursivePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _watch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  );
  late final AnimationController _sparkle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  final _traceInk = WritingInk(), _writeInk = WritingInk();
  final _scroll = ScrollController();
  final _alphabet = 'abcdefghijklmnopqrstuvwxyz'.split('');
  String _character = 'a', _message = '';
  int? _groupIndex;
  bool _faint = true, _passed = false;
  bool _reducedMotion = false, _foreground = true, _visible = true;
  bool _initialized = false;
  Size? _viewport;

  CursiveLetter get _letter => cursiveLetters[_character]!;
  List<String> get _order =>
      _groupIndex == null ? _alphabet : cursiveFamilies[_groupIndex!].letters;
  bool get _enabled => _foreground && _visible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _traceInk.addListener(_traceChanged);
    _writeInk.addListener(_writeChanged);
  }

  void _traceChanged() {
    if (_traceInk.drawing && _watch.isAnimating) {
      setState(_watch.stop);
    }
  }

  void _writeChanged() {
    if (_writeInk.drawing && (_message.isNotEmpty || _passed)) {
      _sparkle.stop();
      setState(() {
        _message = '';
        _passed = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewport = MediaQuery.sizeOf(context);
    if (_viewport != null && _viewport != viewport) {
      // Crossing the stacked/side-by-side breakpoint replaces pad subtrees,
      // so cancellation must also happen here, before their geometry changes.
      _traceInk.cancel();
      _writeInk.cancel();
    }
    _viewport = viewport;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _watch.stop();
      _sparkle.stop();
    }
    if (!_initialized) {
      _initialized = true;
      if (!_reducedMotion) _watch.forward();
    }
  }

  void _interrupt() {
    _watch.stop();
    _sparkle.stop();
    _traceInk.cancel();
    _writeInk.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _interrupt();
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  @override
  void deactivate() {
    _visible = false;
    _interrupt();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _visible = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch.dispose();
    _sparkle.dispose();
    _scroll.dispose();
    _traceInk.removeListener(_traceChanged);
    _writeInk.removeListener(_writeChanged);
    _traceInk.dispose();
    _writeInk.dispose();
    super.dispose();
  }

  void _replay() {
    if (!_enabled) return;
    _traceInk.cancel();
    setState(() {
      _watch.stop();
      if (!_reducedMotion) _watch.forward(from: 0);
    });
  }

  void _chooseLetter(String character, {int? group}) {
    _interrupt();
    _traceInk.clear();
    _writeInk.clear();
    setState(() {
      _character = character;
      _groupIndex = group;
      _message = '';
      _passed = false;
      if (!_reducedMotion && _enabled) _watch.forward(from: 0);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _advance() => _chooseLetter(
    _order[(_order.indexOf(_character) + 1) % _order.length],
    group: _groupIndex,
  );

  void _clear() {
    _sparkle.stop();
    _traceInk.clear();
    _writeInk.clear();
    setState(() {
      _message = '';
      _passed = false;
    });
  }

  void _check() {
    if (!_enabled || _writeInk.drawing || _traceInk.drawing) return;
    setState(() {
      _passed =
          cursiveCoverage(_letter, _writeInk.strokes) >= .60 &&
          cursivePrecision(_letter, _writeInk.strokes) >= .50;
      _message = _passed ? 'Nice curves!' : 'Try tracing first';
    });
    if (_passed && !_reducedMotion) _sparkle.forward(from: 0);
  }

  ButtonStyle _selectionStyle(bool selected) => OutlinedButton.styleFrom(
    minimumSize: const Size(48, 48),
    backgroundColor: selected ? GardenColors.of(context).selectedSurface : null,
    side: selected
        ? BorderSide(color: GardenColors.of(context).primary, width: 2)
        : null,
  );

  Future<void> _picker() async {
    setState(_interrupt);
    final selected = await showModalBottomSheet<({int? group, String letter})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Practice only · no XP',
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Letter groups',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                for (var i = 0; i < cursiveFamilies.length; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: MergeSemantics(
                      child: Semantics(
                        selected: _groupIndex == i,
                        child: OutlinedButton(
                          key: ValueKey('pick-group-$i'),
                          style: _selectionStyle(_groupIndex == i),
                          onPressed: () => Navigator.pop(context, (
                            group: i,
                            letter: cursiveFamilies[i].letters.first,
                          )),
                          child: Text(
                            '${cursiveFamilies[i].name} · ${cursiveFamilies[i].letters.join(' ')}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'All letters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                    for (final character in _alphabet) {
                      painter.text = TextSpan(
                        text: character,
                        style: labelStyle,
                      );
                      painter.layout();
                      labelWidth = math.max(labelWidth, painter.width);
                      labelHeight = math.max(labelHeight, painter.height);
                    }
                    painter.dispose();
                    final cellWidth = math.max(
                      48.0,
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
                          48 * scaler.scale(1),
                          labelHeight.ceilToDouble() + buttonPadding.vertical,
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final character = _alphabet[index];
                        return MergeSemantics(
                          child: Semantics(
                            label: 'Practise cursive $character',
                            selected: character == _character,
                            child: OutlinedButton(
                              key: ValueKey('pick-letter-$character'),
                              style: _selectionStyle(character == _character)
                                  .copyWith(
                                    padding: const WidgetStatePropertyAll(
                                      buttonPadding,
                                    ),
                                  ),
                              onPressed: () => Navigator.pop(context, (
                                group: null,
                                letter: character,
                              )),
                              child: ExcludeSemantics(
                                child: Text(
                                  character,
                                  style: labelStyle,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
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
    _chooseLetter(selected.letter, group: selected.group);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cursive play'),
      leading: IconButton(
        tooltip: 'Back to writing',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      actions: [
        MergeSemantics(
          child: Semantics(
            toggled: _faint,
            child: IconButton(
              key: const ValueKey('cursive-faint-toggle'),
              tooltip: _faint ? 'Hide faint letter' : 'Show faint letter',
              onPressed: () => setState(() => _faint = !_faint),
              icon: Icon(
                _faint
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('cursive-picker'),
          tooltip: 'Choose a letter',
          onPressed: _picker,
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
                final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
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
                        mainAxisAlignment: tablet
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Practice only · no XP · ${_groupIndex == null ? 'a–z' : cursiveFamilies[_groupIndex!].name}',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              _comparison(),
                              const SizedBox(height: 4),
                              if (tablet) _skipLetter(),
                            ],
                          ),
                          _pads(),
                          if (!tablet) _skipLetter(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _actions(),
        ],
      ),
    ),
  );

  Widget _comparison() => Semantics(
    label:
        'Print $_character and cursive $_character: the same lowercase letter.',
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _character,
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('=', style: TextStyle(fontSize: 24)),
          ),
          SizedBox(
            width: 112,
            height: 88,
            child: CustomPaint(
              painter: CursivePainter(
                letter: _letter,
                colors: GardenColors.of(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _skipLetter() => TextButton(
    onPressed: _enabled ? _advance : null,
    child: const Text('Skip letter'),
  );

  Widget _pads() => LayoutBuilder(
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
          final watch = Semantics(
            label: 'Watch how to write cursive $_character',
            child: OutlinedButton.icon(
              key: const ValueKey('cursive-watch'),
              onPressed: _enabled ? _replay : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const ExcludeSemantics(child: Text('Watch')),
            ),
          );
          // Give large text the full label width instead of breaking words
          // into fragments beside the Watch button on narrow windows.
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
            constraints: BoxConstraints(
              minHeight: wide ? 56 : (trace ? 48 : 0),
            ),
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
          builder: (context, _) => CursivePad(
            key: ValueKey(trace ? 'cursive-trace-pad' : 'cursive-pad'),
            letter: _letter,
            ink: trace ? _traceInk : _writeInk,
            enabled: _enabled,
            guidance: trace,
            faint: !trace,
            showModel: trace || _faint,
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

  Widget _actions() => ListenableBuilder(
    listenable: Listenable.merge([_traceInk, _writeInk]),
    builder: (context, _) {
      final clear = OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: _enabled ? _clear : null,
        child: const Text('Clear'),
      );
      final check = FilledButton(
        key: ValueKey(_passed ? 'cursive-next' : 'cursive-check'),
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: !_enabled || _writeInk.drawing || _traceInk.drawing
            ? null
            : (_passed ? _advance : _check),
        child: Text(
          _passed ? 'Next letter' : 'Check',
          textAlign: TextAlign.center,
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_message.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: SuccessCelebration(
                    animation: _sparkle,
                    active: _passed && !_reducedMotion,
                    child: Text(
                      _message,
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
                  children: [clear, const SizedBox(height: 4), check],
                )
              else
                Row(
                  children: [
                    clear,
                    const SizedBox(width: 12),
                    Expanded(child: check),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
