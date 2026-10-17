import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../cursive.dart';
import '../progress_controller.dart';
import '../widgets/cursive_pad.dart';
import '../widgets/writing_pad.dart';

enum _Mode { watch, trace, write }

/// Optional lowercase practice. The shared controller is accepted for routing
/// compatibility; cursive deliberately never reads or mutates player progress.
class CursivePage extends StatefulWidget {
  const CursivePage({super.key, required this.controller});
  final ProgressController controller;

  @override
  State<CursivePage> createState() => _CursivePageState();
}

class _CursivePageState extends State<CursivePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _watch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  );
  final _traceInk = WritingInk(), _writeInk = WritingInk();
  final _letterScroll = ScrollController();
  final _letterKeys = {
    for (final character in cursiveLetters.keys) character: GlobalKey(),
  };
  _Mode _mode = _Mode.watch;
  int _familyIndex = 0, _letterIndex = 0;
  bool _reducedMotion = false, _foreground = true, _initialized = false;
  String _message = '';

  CursiveFamily get _family => cursiveFamilies[_familyIndex];
  CursiveLetter get _letter => cursiveLetters[_family.letters[_letterIndex]]!;
  WritingInk get _ink => _mode == _Mode.write ? _writeInk : _traceInk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _writeInk.addListener(_inkChanged);
  }

  void _inkChanged() {
    if (_message.isNotEmpty) setState(() => _message = '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) _watch.stop();
    if (!_initialized) {
      _initialized = true;
      if (!_reducedMotion) _watch.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _watch.stop();
    _traceInk.cancel();
    _writeInk.cancel();
    setState(() => _foreground = state == AppLifecycleState.resumed);
    // A returning child chooses Watch again; movement never resumes by itself.
  }

  @override
  void deactivate() {
    _watch.stop();
    _traceInk.cancel();
    _writeInk.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch.dispose();
    _letterScroll.dispose();
    _writeInk.removeListener(_inkChanged);
    _traceInk.dispose();
    _writeInk.dispose();
    super.dispose();
  }

  void _chooseMode(_Mode mode) {
    _watch.stop();
    _traceInk.cancel();
    _writeInk.cancel();
    setState(() {
      _mode = mode;
      _message = '';
    });
    if (mode == _Mode.watch && !_reducedMotion && _foreground) {
      _watch.forward(from: 0);
    }
  }

  void _chooseLetter({int? family, int? letter}) {
    _watch.stop();
    _traceInk.clear();
    _writeInk.clear();
    setState(() {
      if (family != null) _familyIndex = family;
      _letterIndex = letter ?? 0;
      _mode = _Mode.watch;
      _message = '';
    });
    if (!_reducedMotion && _foreground) _watch.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_letterScroll.hasClients) return;
      final target = _letterKeys[_letter.character]!.currentContext
          ?.findRenderObject();
      if (target == null) return;
      // Only move the horizontal picker; keep the child's pad in place.
      _letterScroll.position.ensureVisible(
        target,
        alignment: .5,
        duration: _reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
      );
    });
  }

  void _clear() {
    _traceInk.clear();
    _writeInk.clear();
    setState(() => _message = '');
  }

  void _check() {
    if (_writeInk.drawing) return;
    setState(() {
      _message = cursiveCoverage(_letter, _writeInk.strokes) >= .60
          ? 'Nice curves!'
          : 'Try tracing first';
    });
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
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 700,
                        minHeight: tablet
                            ? math.max(0, viewport.maxHeight - 24)
                            : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: tablet
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Practice only · no XP',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              _families(),
                              const SizedBox(height: 8),
                              _letters(),
                              const SizedBox(height: 8),
                              _model(),
                              const SizedBox(height: 8),
                              _modes(),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _drawing(),
                          ),
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

  Widget _families() => Semantics(
    label: 'Choose a family',
    child: SingleChildScrollView(
      key: const ValueKey('cursive-families'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < cursiveFamilies.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ChoiceChip(
                key: ValueKey('cursive-family-$i'),
                label: Text(cursiveFamilies[i].name),
                selected: _familyIndex == i,
                onSelected: (_) => _chooseLetter(family: i),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _letters() => SingleChildScrollView(
    key: const ValueKey('cursive-letters'),
    controller: _letterScroll,
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < _family.letters.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Semantics(
            key: _letterKeys[_family.letters[i]],
            label: 'Choose cursive ${_family.letters[i]}',
            selected: _letterIndex == i,
            inMutuallyExclusiveGroup: true,
            child: OutlinedButton(
              key: ValueKey('cursive-letter-${_family.letters[i]}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(56, 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                backgroundColor: _letterIndex == i
                    ? GardenColors.of(context).selectedSurface
                    : null,
                side: BorderSide(
                  color: _letterIndex == i
                      ? GardenColors.of(context).primary
                      : GardenColors.of(context).outline,
                  width: _letterIndex == i ? 2 : 1,
                ),
              ),
              onPressed: () => _chooseLetter(letter: i),
              child: ExcludeSemantics(
                child: Text(
                  _family.letters[i],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _model() => Semantics(
    label:
        'Print ${_letter.character} and cursive ${_letter.character}: the same lowercase letter.',
    child: ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('Print', textAlign: TextAlign.center),
                Text(
                  _letter.character,
                  style: const TextStyle(fontSize: 56, height: 1),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Text('Same letter', textAlign: TextAlign.center),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('Cursive', textAlign: TextAlign.center),
                SizedBox(
                  height: 88,
                  width: 112,
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
        ],
      ),
    ),
  );

  Widget _modes() => LayoutBuilder(
    builder: (context, constraints) {
      final stack =
          constraints.maxWidth < 500 &&
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final buttons = [
        for (final mode in _Mode.values)
          Semantics(
            label: switch (mode) {
              _Mode.watch => 'Watch how to write cursive ${_letter.character}',
              _Mode.trace => 'Trace cursive ${_letter.character}',
              _Mode.write => 'Write cursive ${_letter.character}',
            },
            selected: _mode == mode,
            inMutuallyExclusiveGroup: true,
            child: OutlinedButton(
              key: ValueKey('cursive-mode-${mode.name}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 56),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                backgroundColor: _mode == mode
                    ? GardenColors.of(context).selectedSurface
                    : null,
                side: BorderSide(
                  color: _mode == mode
                      ? GardenColors.of(context).primary
                      : GardenColors.of(context).outline,
                  width: _mode == mode ? 2 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _chooseMode(mode),
              child: ExcludeSemantics(
                child: Text(switch (mode) {
                  _Mode.watch => 'Watch',
                  _Mode.trace => 'Trace',
                  _Mode.write => 'Write',
                }, textAlign: TextAlign.center),
              ),
            ),
          ),
      ];
      return stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  buttons[i],
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(child: buttons[i]),
                ],
              ],
            );
    },
  );

  Widget _drawing() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(switch (_mode) {
        _Mode.watch =>
          _reducedMotion
              ? 'Follow the numbers and arrows'
              : 'Watch the dot. Tap Watch to see it again.',
        _Mode.trace => 'Trace the curves',
        _Mode.write => 'Write over the faint model, then Check',
      }, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).shortestSide >= 600 ? 240 : 210,
            child: AnimatedBuilder(
              animation: _watch,
              builder: (context, _) => CursivePad(
                key: const ValueKey('cursive-pad'),
                letter: _letter,
                ink: _ink,
                enabled: _foreground && _mode != _Mode.watch,
                guidance: _mode != _Mode.write,
                faint: _mode == _Mode.write,
                watchProgress:
                    _mode == _Mode.watch &&
                        !_reducedMotion &&
                        _watch.isAnimating
                    ? _watch.value
                    : null,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _actions() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_message, textAlign: TextAlign.center),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 500 &&
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final buttons = [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _clear,
                    child: const Text('Clear'),
                  ),
                  if (_mode == _Mode.write)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _check,
                      child: const Text('Check'),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => _chooseLetter(
                      letter: (_letterIndex + 1) % _family.letters.length,
                    ),
                    child: const Text(
                      'Next letter',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ];
                return stack
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < buttons.length; i++) ...[
                            if (i > 0) const SizedBox(height: 4),
                            buttons[i],
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          for (var i = 0; i < buttons.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: buttons[i]),
                          ],
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
