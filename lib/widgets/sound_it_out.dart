import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../word_bank.dart';

/// Plays steps in order; each step is a list of clip IDs played back to back.
/// [onStep] runs before each step. Resolves true only when every step finished
/// without cancellation.
typedef PlaySequence =
    Future<bool> Function(
      List<List<String>> steps, {
      void Function(int step)? onStep,
    });

/// Explicit blending help. The owner supplies lifecycle-aware offline playback.
class SoundItOut extends StatefulWidget {
  const SoundItOut({
    super.key,
    required this.word,
    required this.playSequence,
    this.includeWholeWord = true,
    this.soundOn = true,
    this.enabled = true,
    this.fontSize = 64,
  });

  final DecodableWord word;
  final PlaySequence playSequence;

  /// Pretend-word hints stop after the sounds so the child still blends.
  final bool includeWholeWord;
  final bool soundOn, enabled;
  final double fontSize;

  @override
  State<SoundItOut> createState() => _SoundItOutState();
}

class _SoundItOutState extends State<SoundItOut>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _sweep;
  int _request = 0;
  int? _highlight;

  bool get _canPlay => widget.soundOn && widget.enabled;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _clear() {
    _request++;
    _highlight = null;
    _sweep.stop();
  }

  @override
  void didUpdateWidget(covariant SoundItOut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canPlay ||
        oldWidget.word.spelling != widget.word.spelling ||
        oldWidget.includeWholeWord != widget.includeWholeWord) {
      _clear();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) setState(_clear);
  }

  Future<void> _play({int? letter}) async {
    if (!_canPlay) return;
    final request = ++_request;
    final sounds = widget.word.letterSounds;
    final steps = letter == null
        ? [
            ...sounds,
            if (widget.includeWholeWord) [widget.word.clip],
          ]
        : [sounds[letter]];
    bool active() => mounted && request == _request && _canPlay;
    try {
      await widget.playSequence(
        steps,
        onStep: (step) {
          if (!active()) return;
          final highlight = letter ?? step;
          setState(() => _highlight = highlight);
          if (highlight == sounds.length &&
              !MediaQuery.disableAnimationsOf(context)) {
            _sweep.forward(from: 0);
          } else {
            _sweep.stop();
          }
        },
      );
    } finally {
      if (active()) setState(_clear);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _request++;
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final letters = widget.word.spelling.split('');
    final wholeWord = _highlight == letters.length;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < letters.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  key: ValueKey('sound-letter-$i'),
                  label: 'Letter ${letters[i]}',
                  button: true,
                  enabled: _canPlay,
                  selected: _highlight == i,
                  excludeSemantics: true,
                  onTap: _canPlay ? () => _play(letter: i) : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: Material(
                      color: _highlight == i
                          ? colors.selectedSurface
                          : colors.panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _highlight == i
                              ? colors.primary
                              : colors.outline,
                          width: _highlight == i ? 3 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _canPlay ? () => _play(letter: i) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  letters[i],
                                  style: TextStyle(
                                    fontSize: widget.fontSize,
                                    fontWeight: FontWeight.w600,
                                    color: colors.foreground,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _highlight == i
                                      ? colors.primary
                                      : colors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(
          height: 10,
          child: wholeWord
              ? AnimatedBuilder(
                  key: const ValueKey('whole-word-underline'),
                  animation: _sweep,
                  builder: (context, child) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: reducedMotion ? 1 : _sweep.value,
                      child: child,
                    ),
                  ),
                  child: Container(height: 4, color: colors.primary),
                )
              : null,
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: _canPlay ? () => _play() : null,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.volume_up_outlined),
          label: const Text('Sound it out', textAlign: TextAlign.center),
        ),
        if (!widget.soundOn) ...[
          const SizedBox(height: 8),
          const Text('Turn on sound to hear it.', textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
