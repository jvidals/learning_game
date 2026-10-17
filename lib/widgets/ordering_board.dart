import '../app_theme.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../game.dart';
import '../garden_art.dart';
import '../ordering_game.dart';
import 'success_celebration.dart';

/// Fixed row-major slots. Geometry is shared by painting and drop targeting.
class OrderingLayout {
  const OrderingLayout(this.columns, this.side, this.count, this.width);
  final int columns, count;
  final double side, width;
  static const gap = 8.0;
  int get rows => (count / columns).ceil();
  double get height => rows * (side + gap) - gap;
  double get left => (width - columns * (side + gap) + gap) / 2;
  Offset origin(int slot) => Offset(
    left + slot % columns * (side + gap),
    slot ~/ columns * (side + gap),
  );
  int? target(Offset point) {
    final x = point.dx - left + gap / 2, y = point.dy + gap / 2;
    if (x < 0 || y < 0) return null;
    final col = (x / (side + gap)).floor(), row = (y / (side + gap)).floor();
    final slot = row * columns + col;
    if (col >= columns || slot >= count) return null;
    return slot;
  }

  static OrderingLayout fit(Size size, int count, double textScale) {
    final minimum = 48.0 * textScale.clamp(1.0, 1.5);
    final maxColumns = math.max(
      1,
      ((size.width + gap) / (minimum + gap)).floor(),
    );
    OrderingLayout candidate(int columns) {
      final rows = (count / columns).ceil();
      return OrderingLayout(
        columns,
        math.min(
          112.0,
          math.min(
            (size.width - (columns - 1) * gap) / columns,
            (size.height - (rows - 1) * gap) / rows,
          ),
        ),
        count,
        size.width,
      );
    }

    final preferred = [
      for (final c in [3, 4])
        if (c <= maxColumns) candidate(c),
    ]..sort((a, b) => b.side.compareTo(a.side));
    if (preferred.isNotEmpty && preferred.first.side >= math.max(64, minimum)) {
      return preferred.first;
    }
    final fits = [for (var c = 1; c <= maxColumns; c++) candidate(c)]
      ..sort((a, b) => b.side.compareTo(a.side));
    if (fits.first.side >= minimum) return fits.first;
    final columns = math.min(count <= 12 ? 3 : 4, maxColumns);
    return OrderingLayout(
      columns,
      math.min(112, (size.width - (columns - 1) * gap) / columns),
      count,
      size.width,
    );
  }
}

class OrderingBoard extends StatefulWidget {
  const OrderingBoard({
    super.key,
    required this.round,
    required this.lowercase,
    required this.enabled,
    required this.onSwap,
  });
  final OrderingRound round;
  final bool lowercase, enabled;
  final Set<int>? Function(int, int) onSwap;
  @override
  State<OrderingBoard> createState() => _OrderingBoardState();
}

class _Flight {
  const _Flight(this.value, this.from, this.to);
  final int value;
  final Offset from, to;
}

class _OrderingBoardState extends State<OrderingBoard>
    with TickerProviderStateMixin {
  final _viewport = GlobalKey();
  final _scroll = ScrollController();
  final _avatarVisible = ValueNotifier(false);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final AnimationController _sparkle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Ticker _autoScroll;
  OrderingLayout? _layout;
  Size? _size, _windowSize;
  double? _textScale;
  int? _selected, _dragValue, _candidate;
  int _generation = 0;
  Offset _anchor = Offset.zero, _dragCenter = Offset.zero;
  Duration _lastTick = Duration.zero;
  List<_Flight> _flights = [];
  Set<int> _celebrating = {};
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  bool get _ready =>
      widget.enabled && !_settle.isAnimating && _dragValue == null;

  @override
  void initState() {
    super.initState();
    _autoScroll = createTicker(_tickScroll);
    _settle.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _flights = []);
        if (!_reduced && _celebrating.isNotEmpty) _sparkle.forward(from: 0);
      }
    });
  }

  @override
  void didUpdateWidget(OrderingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        oldWidget.round != widget.round ||
        oldWidget.lowercase != widget.lowercase) {
      _cancel();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.of(context) ||
        !(ModalRoute.isCurrentOf(context) ?? true) ||
        _reduced) {
      _cancel();
    }
  }

  void _cancel() {
    _generation++;
    _selected = _dragValue = _candidate = null;
    // The feedback lives in a sibling overlay, outside this build subtree.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dragValue == null) _avatarVisible.value = false;
      });
    } else {
      _avatarVisible.value = false;
    }
    _autoScroll.stop();
    _settle.reset();
    _sparkle.reset();
    _flights = [];
    _celebrating = {};
  }

  @override
  void dispose() {
    _cancel();
    _autoScroll.dispose();
    _settle.dispose();
    _sparkle.dispose();
    _scroll.dispose();
    _avatarVisible.dispose();
    super.dispose();
  }

  Offset _local(Offset global) =>
      (_viewport.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);
  Offset _visibleOrigin(int slot) =>
      _layout!.origin(slot) -
      Offset(0, _scroll.hasClients ? _scroll.offset : 0);
  int? _target() {
    if (_layout == null || _size == null) return null;
    final point = _local(_dragCenter);
    if (point.dy < 0 ||
        point.dy > _size!.height ||
        point.dx < 0 ||
        point.dx > _size!.width) {
      return null;
    }
    final slot = _layout!.target(point + Offset(0, _scroll.offset));
    if (slot == null || widget.round.correct(slot)) return null;
    return slot;
  }

  void _tickScroll(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    if (_dragValue == null ||
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent == 0) {
      return;
    }
    final y = _local(_dragCenter).dy;
    const edge = 48.0;
    final direction = y < edge
        ? -((edge - y) / edge).clamp(0, 1)
        : y > _size!.height - edge
        ? ((y - _size!.height + edge) / edge).clamp(0, 1)
        : 0.0;
    if (direction == 0) return;
    final next = (_scroll.offset + direction * 360 * dt.clamp(0, .05)).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.jumpTo(next);
    final candidate = _target();
    if (_candidate != candidate) setState(() => _candidate = candidate);
  }

  void _tap(int slot) {
    if (!_ready || widget.round.correct(slot)) return;
    if (_selected == null) {
      setState(() => _selected = slot);
    } else if (_selected == slot) {
      setState(() => _selected = null);
    } else {
      _drop(_selected!, slot, _visibleOrigin(_selected!));
    }
  }

  void _drop(int source, int? destination, Offset from) {
    final cards = widget.round.cards;
    final moved = destination == null
        ? null
        : widget.onSwap(source, destination);
    setState(() {
      _selected = _dragValue = _candidate = null;
      _avatarVisible.value = false;
      _autoScroll.stop();
      _sparkle.reset();
      _celebrating = moved ?? {};
      _flights = [
        _Flight(
          cards[source],
          from,
          _visibleOrigin(moved == null ? source : destination!),
        ),
        if (moved != null)
          _Flight(
            cards[destination!],
            _visibleOrigin(destination),
            _visibleOrigin(source),
          ),
      ];
    });
    if (_reduced) {
      setState(() => _flights = []);
    } else {
      _settle.forward(from: 0);
    }
  }

  Widget _face(
    int value,
    double side, {
    bool selected = false,
    bool correct = false,
    bool lifted = false,
  }) => Container(
    width: side,
    height: side,
    decoration: BoxDecoration(
      color: correct
          ? GardenColors.of(context).successSurface
          : GardenColors.of(
              context,
            ).card(rainbow[value % rainbow.length], white: .83),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: correct
            ? GardenColors.of(context).successBorder
            : selected
            ? GardenColors.of(context).primary
            : GardenColors.of(context).tileBorder,
        width: selected || correct ? 2.5 : 2,
      ),
      boxShadow: [
        BoxShadow(
          color: GardenColors.of(context).shadow,
          blurRadius: lifted ? 14 : 5,
          offset: Offset(0, lifted ? 8 : 3),
        ),
      ],
    ),
    child: Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.round.label(value, lowercase: widget.lowercase),
                style: TextStyle(
                  fontSize: side * .52,
                  fontWeight: FontWeight.w700,
                  color: GardenColors.of(context).foreground,
                ),
              ),
            ),
          ),
        ),
        if (correct)
          Positioned(
            right: 3,
            top: 3,
            child: Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: GardenColors.of(context).successText,
            ),
          ),
      ],
    ),
  );
  Widget _card(int slot) {
    final value = widget.round.cards[slot],
        correct = widget.round.correct(slot);
    final side = _layout!.side, generation = _generation;
    final hidden = _dragValue == value || _flights.any((f) => f.value == value);
    final enabled = _ready && !correct;
    final label = widget.round.label(value, lowercase: widget.lowercase);
    final semantics =
        '${widget.round.activity == Activity.alphabetOrder ? (widget.lowercase ? 'Lowercase' : 'Uppercase') : 'Number'} $label. Position ${slot + 1} of ${widget.round.length}${correct ? '. Correct, locked' : ''}';
    final visual = SuccessCelebration(
      animation: _sparkle,
      active: !_reduced && _celebrating.contains(value),
      child: Stack(
        children: [
          if (hidden)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GardenColors.of(context).resolve(
                    ink.withValues(alpha: .025),
                    GardenColors.of(context).surface,
                  ),
                  border: Border.all(
                    color: GardenColors.of(context).resolve(
                      ink.withValues(alpha: .14),
                      GardenColors.of(context).outline,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          Opacity(
            opacity: hidden ? 0 : 1,
            child: _face(
              value,
              side,
              selected: _selected == slot || _candidate == slot,
              correct: correct,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      key: ValueKey('ordering-card-$value'),
      label: semantics,
      button: !correct,
      selected: _selected == slot,
      enabled: enabled,
      onTap: enabled ? () => _tap(slot) : null,
      hint: correct
          ? null
          : _selected == null
          ? 'Tap to select, or hold and drag'
          : 'Tap to swap with the selected card',
      child: ExcludeSemantics(
        child: LongPressDraggable<int>(
          data: value,
          delay: const Duration(milliseconds: 300),
          hapticFeedbackOnStart: false,
          maxSimultaneousDrags: enabled ? 1 : 0,
          dragAnchorStrategy: (draggable, context, position) {
            _anchor = (context.findRenderObject()! as RenderBox).globalToLocal(
              position,
            );
            return _anchor;
          },
          onDragStarted: () {
            if (!_ready || generation != _generation) return;
            setState(() {
              _selected = null;
              _dragValue = value;
              _candidate = slot;
            });
            _avatarVisible.value = true;
            final box =
                _viewport.currentContext!.findRenderObject()! as RenderBox;
            _dragCenter = box.localToGlobal(
              _visibleOrigin(slot) + Offset(side / 2, side / 2),
            );
            _lastTick = Duration.zero;
            _autoScroll.start();
          },
          onDragUpdate: (details) {
            if (_dragValue != value || generation != _generation) return;
            _dragCenter =
                details.globalPosition - _anchor + Offset(side / 2, side / 2);
            final target = _target();
            if (_candidate != target) setState(() => _candidate = target);
          },
          onDragEnd: (_) {
            if (_dragValue != value ||
                generation != _generation ||
                !widget.enabled) {
              return;
            }
            _drop(
              slot,
              _target(),
              _local(_dragCenter) - Offset(side / 2, side / 2),
            );
          },
          feedback: ValueListenableBuilder<bool>(
            valueListenable: _avatarVisible,
            builder: (_, visible, child) => Opacity(
              opacity: visible && generation == _generation ? 1 : 0,
              child: child,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: _reduced ? 1 : 1.06),
                duration: const Duration(milliseconds: 150),
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: _face(value, side, lifted: true),
              ),
            ),
          ),
          child: GestureDetector(
            onTap: enabled ? () => _tap(slot) : null,
            child: _PressCard(
              enabled: enabled,
              reduced: _reduced,
              child: visual,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final windowSize = MediaQuery.sizeOf(context);
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final layout = OrderingLayout.fit(
        Size(size.width, math.max(1, size.height - 8)),
        widget.round.length,
        MediaQuery.textScalerOf(context).scale(16) / 16,
      );
      if (_size != size ||
          _layout?.columns != layout.columns ||
          _layout?.side != layout.side) {
        // The completion footer can resize a solved board during its final
        // placement. Snap the flight and preserve its single burst on the new
        // cells. Window/text changes and interruptions still cancel feedback.
        final preserve =
            widget.round.finished &&
            widget.enabled &&
            !_reduced &&
            _windowSize == windowSize &&
            _textScale == textScale &&
            (_settle.isAnimating || _sparkle.isAnimating);
        final celebrating = preserve ? Set<int>.of(_celebrating) : <int>{};
        final progress = _settle.isAnimating ? 0.0 : _sparkle.value;
        _cancel();
        if (celebrating.isNotEmpty) {
          _celebrating = celebrating;
          _sparkle.forward(from: progress);
        }
      }
      _size = size;
      _windowSize = windowSize;
      _textScale = textScale;
      _layout = layout;
      return Listener(
        onPointerCancel: (_) {
          if (_dragValue != null) setState(_cancel);
        },
        child: Stack(
          key: _viewport,
          clipBehavior: Clip.hardEdge,
          children: [
            GridView.builder(
              key: const ValueKey('ordering-grid'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(layout.left, 0, layout.left, 8),
              physics: _settle.isAnimating || _dragValue != null
                  ? const NeverScrollableScrollPhysics()
                  : null,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: layout.columns,
                mainAxisExtent: layout.side,
                mainAxisSpacing: OrderingLayout.gap,
                crossAxisSpacing: OrderingLayout.gap,
              ),
              itemCount: widget.round.length,
              itemBuilder: (_, slot) => _KeptCard(
                keep: _dragValue == widget.round.cards[slot],
                child: _card(slot),
              ),
            ),
            AnimatedBuilder(
              animation: _settle,
              builder: (_, _) => Stack(
                children: [
                  for (final flight in _flights)
                    Positioned(
                      left: Offset.lerp(
                        flight.from,
                        flight.to,
                        Curves.easeOutCubic.transform(_settle.value),
                      )!.dx,
                      top: Offset.lerp(
                        flight.from,
                        flight.to,
                        Curves.easeOutCubic.transform(_settle.value),
                      )!.dy,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: _face(
                            flight.value,
                            layout.side,
                            correct: _celebrating.contains(flight.value),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Keep the drag recognizer alive when its original row scrolls off screen.
class _KeptCard extends StatefulWidget {
  const _KeptCard({required this.keep, required this.child});
  final bool keep;
  final Widget child;
  @override
  State<_KeptCard> createState() => _KeptCardState();
}

class _KeptCardState extends State<_KeptCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keep;
  @override
  void didUpdateWidget(_KeptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _PressCard extends StatefulWidget {
  const _PressCard({
    required this.enabled,
    required this.reduced,
    required this.child,
  });
  final bool enabled, reduced;
  final Widget child;
  @override
  State<_PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<_PressCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      if (widget.enabled) setState(() => _pressed = true);
    },
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed && widget.enabled && !widget.reduced ? .97 : 1,
      duration: const Duration(milliseconds: 80),
      child: widget.child,
    ),
  );
}
