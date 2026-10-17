import 'dart:async';
import 'package:flutter/material.dart';
import '../progress.dart';
import '../progress_controller.dart';
import '../device_services.dart';
import '../game.dart';
import '../number_range.dart';
import '../widgets/number_range_editor.dart';
import '../ordering_game.dart';
import '../widgets/ordering_board.dart';
import '../widgets/learning_reward.dart';
import '../widgets/progress_widgets.dart';

class OrderingPage extends StatefulWidget {
  const OrderingPage({
    super.key,
    required this.activity,
    required this.controller,
    required this.numberRange,
    this.round,
    this.openRangeSettings = false,
  });
  final Activity activity;
  final ProgressController controller;
  final NumberRange numberRange;
  final OrderingRound? round;
  final bool openRangeSettings;
  @override
  State<OrderingPage> createState() => _OrderingPageState();
}

class _OrderingPageState extends State<OrderingPage>
    with WidgetsBindingObserver {
  late NumberRange _activeRange = widget.numberRange;
  late bool _rangeEditorOpen = widget.openRangeSettings;
  bool _rangeChangePending = false;
  late OrderingRound _round =
      widget.round ?? OrderingRound(widget.activity, numberRange: _activeRange);
  String _roundId = newRoundId();
  bool _foreground = true, _visible = true, _rewardsOpen = false;
  bool? _casePreview;
  RoundRewardResult? _reward;
  Timer? _advance;
  bool _manualNext = true;
  String _announcement = '';
  ProgressController get _controller => widget.controller;
  bool get _active =>
      _foreground &&
      _visible &&
      !_rewardsOpen &&
      !_rangeEditorOpen &&
      !_rangeChangePending;
  bool get _lowercase => _casePreview ?? _controller.settings.orderingLowercase;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_changed);
    if (widget.openRangeSettings)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editRange(initial: true);
      });
  }

  void _changed() {
    if (!mounted) return;
    _finishRangeChange();
    setState(() {
      if (!_controller.blocked.value) _casePreview = null;
      final p = _controller.progress;
      if (_round.finished && p?.lastRewardedRound == _roundId) {
        _reward ??= RoundRewardResult(p!, levelForXp(p.xp - roundXp));
      }
    });
    _scheduleAdvance();
  }

  Future<void> _stop() async {
    try {
      await _controller.services.stop();
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        (ModalRoute.isCurrentOf(context) ?? true) && TickerMode.of(context);
    if (!_visible) unawaited(_stop());
    _scheduleAdvance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (!_foreground) unawaited(_stop());
    _scheduleAdvance();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _advance?.cancel();
    unawaited(_stop());
    super.dispose();
  }

  Future<void> _toggleCase() async {
    if (!_active ||
        _controller.blocked.value ||
        _rewardsOpen ||
        _round.finished) {
      return;
    }
    final next = !_lowercase;
    setState(() => _casePreview = next);
    try {
      await _controller.saveSettings(
        _controller.effectiveSettings.withOrderingCase(next),
      );
    } catch (_) {}
  }

  Set<int>? _swap(int a, int b) {
    if (!_active || _controller.blocked.value || _round.finished) return null;
    final before = _round.cards;
    final result = _round.swap(a, b);
    if (result == null) return null;
    setState(() {
      _announcement =
          '${_round.label(before[a], lowercase: _lowercase)} and ${_round.label(before[b], lowercase: _lowercase)} swapped. ${_round.completed} of ${_round.length} in order.';
    });
    unawaited(
      requestFeedback(
        _controller.services,
        result.isEmpty ? DeviceFeedback.light : DeviceFeedback.placement,
        enabled: _controller.settings.haptics,
      ),
    );
    if (_round.finished) unawaited(_award());
    return result;
  }

  Future<void> _award() async {
    // The controller retains failed writes even when this page closes.
    final id = _roundId;
    try {
      final reward = await _controller.completeRound(id);
      if (mounted && id == _roundId) {
        setState(() => _reward = reward);
        _scheduleAdvance();
      }
    } catch (_) {}
  }

  void _scheduleAdvance() {
    _manualNext =
        _controller.settings.tapNext ||
        MediaQuery.accessibleNavigationOf(context);
    if (_manualNext ||
        !_active ||
        !_round.finished ||
        _reward == null ||
        _controller.blocked.value) {
      _advance?.cancel();
      _advance = null;
      return;
    }
    if (_advance != null) return;
    final id = _roundId;
    _advance = Timer(roundContinuationDelay, () {
      _advance = null;
      if (mounted && id == _roundId && !_manualNext) _again();
    });
  }

  Future<void> _openRewards() async {
    if (!_active) return;
    setState(() => _rewardsOpen = true);
    _scheduleAdvance();
    unawaited(_stop());
    await showLearningRewards(context, _controller);
    if (!mounted) return;
    setState(() {
      _rewardsOpen = false;
      _visible = ModalRoute.isCurrentOf(context) ?? true;
    });
    _scheduleAdvance();
  }

  void _again() {
    if (_controller.blocked.value ||
        !_active ||
        !_round.finished ||
        _reward == null)
      return;
    _restartRound();
  }

  void _restartRound() {
    _advance?.cancel();
    _advance = null;
    unawaited(_stop());
    setState(() {
      _round = OrderingRound(widget.activity, numberRange: _activeRange);
      _roundId = newRoundId();
      _reward = null;
      _rewardsOpen = false;
      _announcement = '';
    });
  }

  Future<void> _editRange({bool initial = false}) async {
    if (!initial && (!_active || _controller.blocked.value)) return;
    setState(() => _rangeEditorOpen = true);
    _scheduleAdvance();
    unawaited(_stop());
    await openNumberRangeEditor(context, _controller, widget.activity);
    if (!mounted) return;
    setState(() {
      _rangeEditorOpen = false;
      _visible = ModalRoute.isCurrentOf(context) ?? true;
      _rangeChangePending =
          _controller.effectiveSettings.numberGameRanges.forActivity(
            widget.activity,
          ) !=
          _activeRange;
    });
    _finishRangeChange();
    _scheduleAdvance();
  }

  void _finishRangeChange() {
    if (!_rangeChangePending || _rangeEditorOpen || _controller.blocked.value)
      return;
    _activeRange = _controller.settings.numberGameRanges.forActivity(
      widget.activity,
    );
    _rangeChangePending = false;
    _restartRound();
  }

  Future<void> _help() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Put the cards in order'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz_rounded, size: 64),
              Text(
                'Hold a card and drag it onto another card to swap their places. You can also tap one card, then another.',
              ),
              SizedBox(height: 12),
              Text(
                'Start at the top left. Go across each row, then down to the next row. Green cards with a check are in the right place!',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Let’s play'),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_round.finished) {
      return RoundCompletionControls(
        key: ValueKey('completion-$_roundId'),
        reward: _reward,
        controller: _controller,
        manual: _manualNext,
        active: _active,
        services: _controller.services,
        haptics: _controller.settings.haptics,
        onNext: _reward == null || !_active || _controller.blocked.value
            ? null
            : _again,
        onRewards: _openRewards,
      );
    }
    if (_controller.blocked.value) return SaveStatus(controller: _controller);
    return const Center(
      child: Text(
        'Hold and drag, or tap two cards to swap.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heading = numberGameHeading(context, widget.activity);
    return Scaffold(
      appBar: AppBar(
        title: heading != null
            ? null
            : Text(
                widget.activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        bottom: heading,
        leading: IconButton(
          tooltip: 'Back to ${widget.activity.category.title.toLowerCase()}',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          LearningRewardsButton(
            count: _controller.progress!.availableChoices,
            onPressed: _openRewards,
          ),
          if (widget.activity == Activity.alphabetOrder && !_rewardsOpen)
            Semantics(
              label: _lowercase
                  ? 'Switch to uppercase letters'
                  : 'Switch to lowercase letters',
              toggled: _lowercase,
              button: true,
              enabled:
                  _active && !_round.finished && !_controller.blocked.value,
              onTap: !_active || _round.finished || _controller.blocked.value
                  ? null
                  : _toggleCase,
              excludeSemantics: true,
              child: TextButton(
                key: const ValueKey('ordering-case'),
                onPressed:
                    !_active || _round.finished || _controller.blocked.value
                    ? null
                    : _toggleCase,
                style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
                child: Text(
                  _lowercase ? 'a / A' : 'A / a',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          if (!_rewardsOpen)
            IconButton(
              tooltip: 'How to play',
              onPressed: _help,
              icon: const Icon(Icons.help_outline_rounded),
            ),
          if (widget.activity == Activity.numberOrder)
            NumberRangeButton(
              activity: widget.activity,
              range: _controller.effectiveSettings.numberGameRanges.forActivity(
                widget.activity,
              ),
              onPressed: !_active || _controller.blocked.value
                  ? null
                  : () => _editRange(),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Semantics(
                    liveRegion: true,
                    label: _announcement.isEmpty
                        ? '${_round.completed} of ${_round.length} in order'
                        : _announcement,
                    child: ExcludeSemantics(
                      child: Text(
                        '${_round.completed} of ${_round.length} in order',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: OrderingBoard(
                    key: ValueKey(_roundId),
                    round: _round,
                    lowercase: _lowercase,
                    enabled:
                        _active &&
                        (!_controller.blocked.value || _round.finished),
                    onSwap: _swap,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .55,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _footer(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
