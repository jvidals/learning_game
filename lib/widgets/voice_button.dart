import 'package:flutter/material.dart';

/// A fixed touch target; only its icon and highlight animate.
class VoiceButton extends StatefulWidget {
  const VoiceButton({
    super.key,
    required this.on,
    required this.onPressed,
    required this.needsVoice,
    required this.active,
    this.subject,
  });
  final bool on, needsVoice, active;
  final VoidCallback? onPressed;
  final String? subject;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _reduced = false, _tickerEnabled = true;

  void _sync() {
    final animate =
        widget.needsVoice && widget.active && !_reduced && _tickerEnabled;
    if (animate) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.of(context);
    _sync();
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = widget.on ? 'Turn voice off' : 'Turn voice on';
    final label = !widget.on && widget.subject != null
        ? 'Turn voice on to hear the ${widget.subject!}'
        : tooltip;
    return Semantics(
      label: label,
      button: true,
      enabled: widget.onPressed != null,
      toggled: widget.on,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 56, height: 56),
        onPressed: widget.onPressed,
        icon: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final value = Curves.easeInOut.transform(_pulse.value);
              return SizedBox.square(
                dimension: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.needsVoice)
                      Positioned.fill(
                        child: DecoratedBox(
                          key: const ValueKey('voice-attention-halo'),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary
                                .withValues(
                                  alpha: _reduced ? .16 : .10 + .12 * value,
                                ),
                          ),
                        ),
                      ),
                    Transform.scale(
                      key: const ValueKey('voice-icon-scale'),
                      scale: _reduced ? 1 : 1 + .12 * value,
                      child: Icon(
                        widget.on
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                      ),
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
}
