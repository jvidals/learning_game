import '../app_theme.dart';
import 'dart:async';
import 'dart:math' as math;
import '../app_settings.dart';
import 'package:flutter/material.dart';
import '../device_services.dart';
import '../progress.dart';
import '../progress_controller.dart';
import '../widgets/learning_reward.dart';
import '../game.dart';
import '../number_range.dart';
import '../sight_words.dart';
import '../letter_sounds.dart';
import '../counting.dart';
import '../widgets/counting_board.dart';
import '../widgets/visual_question.dart';
import '../widgets/number_range_editor.dart';
import '../garden_art.dart';
import '../widgets/page_body.dart';
import '../widgets/success_celebration.dart';
import '../widgets/retry_marker.dart';
import '../widgets/voice_button.dart';
import '../widgets/progress_widgets.dart';

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.services,
    required this.activity,
    required this.sound,
    required this.onCompleteRound,
    this.controller,
    this.round,
    this.numberRange = NumberRange.defaults,
    this.wordPacks = SightWordPacks.defaults,
    this.sounds = SoundSelection.defaults,
    this.countingMax = 10,
    this.countingRange,
    this.openRangeSettings = false,
  });
  final DeviceServices services;
  final Activity activity;
  final bool sound;
  final Future<RoundRewardResult> Function(String) onCompleteRound;
  final ProgressController? controller;
  final GameRound? round;
  final NumberRange numberRange;
  final SightWordPacks wordPacks;
  final SoundSelection sounds;
  final int countingMax;
  final NumberRange? countingRange;
  final bool openRangeSettings;
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final AnimationController _celebration;
  late final AnimationController _retryFade;
  String? _wrongChoice;
  final _answerCardKey = GlobalKey();
  final _visualChoicesKey = GlobalKey();
  (Question, bool, RoundRewardResult?)? _visualLayout;
  Timer? _retryDuration, _retryCooldown;

  void _clearRetry({bool resetCooldown = false}) {
    _retryDuration?.cancel();
    _retryDuration = null;
    _wrongChoice = null;
    _retryFade.reset();
    if (resetCooldown) {
      _retryCooldown?.cancel();
      _retryCooldown = null;
    }
  }

  late GameRound _round;
  late NumberRange _activeRange = widget.activity.isCounting
      ? widget.countingRange ?? NumberRange(0, widget.countingMax)
      : widget.numberRange;
  late CountingWork _counting = CountingWork(
    _countingGame ? _activeRange.max : 10,
  );
  late bool _rangeEditorOpen = widget.openRangeSettings;
  bool _rangeChangePending = false;
  bool get _rangePaused => _rangeEditorOpen || _rangeChangePending;
  bool get _countingGame => widget.activity.isCounting;
  bool get _makeGroup => widget.activity == Activity.makeGroup;
  bool get _silentNumbers =>
      widget.activity == Activity.sameNumber ||
      widget.activity == Activity.numberParts;
  String? _selected;
  bool _hint = false;
  bool _audioFailed = false;
  // Matching keeps a local override; identification uses the shared saved choice.
  late bool _voiceOn = widget.controller?.soundOn ?? widget.sound;
  bool get _matching => widget.activity == Activity.matching;
  bool get _sound =>
      !_countingGame &&
      !_silentNumbers &&
      (_matching ? _voiceOn : widget.controller?.soundOn ?? _voiceOn);
  bool get _writeBlocked =>
      (widget.controller?.blocked.value ?? false) || _rangePaused;
  int _audioRequest = 0;
  Animation<double>? _entryAnimation;
  bool _entryPromptPending = true;
  bool _entryFrameQueued = false;

  void _cancelEntryPrompt() {
    _entryPromptPending = false;
    _entryAnimation?.removeStatusListener(_entryStatusChanged);
    _entryAnimation = null;
  }

  void _entryStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _cancelEntryPrompt();
    } else {
      _scheduleEntryPrompt();
    }
  }

  void _scheduleEntryPrompt() {
    if (!_entryPromptPending || _entryFrameQueued) return;
    if (!_sound ||
        _round.question.audio.isEmpty ||
        _round.answered ||
        _rewardsOpen) {
      _cancelEntryPrompt();
      return;
    }
    if (!_foreground || !_visible || _writeBlocked) return;
    if (_entryAnimation != null && !_entryAnimation!.isCompleted) return;
    // A post-frame callback alone is too early while a pushed route is entering.
    // Wait for both the transition and the visible frame before requesting voice.
    _entryFrameQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryFrameQueued = false;
      if (!mounted || !_entryPromptPending) return;
      if (!_foreground ||
          !_visible ||
          _writeBlocked ||
          !(ModalRoute.isCurrentOf(context) ?? true) ||
          (_entryAnimation != null && !_entryAnimation!.isCompleted))
        return;
      unawaited(_playPrompt());
    });
  }

  Future<void> _toggleVoice() async {
    if (!_foreground || !_visible || _rewardsOpen || _writeBlocked) return;
    _cancelEntryPrompt();
    final next = !_sound;
    setState(() {
      if (_matching || widget.controller == null) _voiceOn = next;
      _audioFailed = false;
      _audioRequest++;
    });
    final save = !_matching ? widget.controller?.setSound(next) : null;
    if (!next) {
      unawaited(_stopSpeech());
    } else if (!_matching && !_round.answered) {
      unawaited(_playPrompt());
    }
    try {
      await save;
    } catch (_) {
      // Keep the shared pending choice; SaveStatus exposes the retained retry.
    }
  }

  void _controllerChanged() {
    _finishRangeChange();
    final progress = widget.controller?.progress;
    if (_round.finished &&
        _reward == null &&
        progress?.lastRewardedRound == _roundId) {
      setState(() {
        _reward = RoundRewardResult(
          progress!,
          levelForXp(progress.xp - roundXp),
        );
        _saving = false;
        _saveFailed = false;
      });
    }
    _scheduleAdvance();
    _scheduleEntryPrompt();
  }

  @override
  void didUpdateWidget(GamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_controllerChanged);
      widget.controller?.addListener(_controllerChanged);
      _scheduleAdvance();
    }
  }

  Future<void> _stopSpeech() async {
    _cancelEntryPrompt();
    _audioRequest++;
    try {
      await widget.services.stop();
    } catch (_) {
      // Optional audio must not block muting or navigation.
    }
  }

  bool _retry = false;
  bool _saving = false;
  bool _saveFailed = false;
  RoundRewardResult? _reward;
  String _roundId = newRoundId();
  final _scroll = ScrollController();
  int _petReaction = 0;
  Timer? _advance;
  bool _foreground = true;
  bool _visible = true;
  bool _manualNext = true;
  AppSettings get _settings =>
      widget.controller?.effectiveSettings ?? const AppSettings();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        (ModalRoute.isCurrentOf(context) ?? true) && TickerMode.of(context);
    if (_entryPromptPending) {
      final animation = ModalRoute.of(context)?.animation;
      if (!identical(animation, _entryAnimation)) {
        _entryAnimation?.removeStatusListener(_entryStatusChanged);
        _entryAnimation = animation;
        _entryAnimation?.addStatusListener(_entryStatusChanged);
      }
    }
    _manualNext =
        _settings.tapNext || MediaQuery.accessibleNavigationOf(context);
    if (!_visible || MediaQuery.disableAnimationsOf(context))
      _celebration.reset();
    if (!_visible) {
      _clearRetry(resetCooldown: true);
      _retry = false;
      unawaited(_stopSpeech());
    }
    _scheduleAdvance();
    _scheduleEntryPrompt();
  }

  void _scheduleAdvance() {
    _manualNext =
        _settings.tapNext || MediaQuery.accessibleNavigationOf(context);
    if (_manualNext ||
        _writeBlocked ||
        !_foreground ||
        !_visible ||
        !_round.answered ||
        (_round.finished && (_reward == null || _saving)) ||
        _rewardsOpen) {
      _advance?.cancel();
      _advance = null;
      return;
    }
    if (_advance != null) return;
    final id = _roundId;
    _advance = Timer(
      _round.finished
          ? roundContinuationDelay
          : const Duration(milliseconds: 800),
      () {
        _advance = null;
        if (mounted &&
            id == _roundId &&
            _foreground &&
            _visible &&
            !_manualNext &&
            !_rewardsOpen)
          _next();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _celebration = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _retryFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _round =
        widget.round ??
        GameRound(
          widget.activity,
          numberRange: _activeRange,
          wordPacks: widget.wordPacks,
          sounds: widget.sounds,
          countingRange: _countingGame ? _activeRange : null,
        );
    widget.controller?.addListener(_controllerChanged);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (widget.openRangeSettings)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editRange(initial: true);
      });
  }

  Future<void> _playPrompt() async {
    _cancelEntryPrompt();
    if (_round.question.audio.isEmpty ||
        !_sound ||
        !_foreground ||
        !_visible ||
        _rewardsOpen ||
        _rangePaused)
      return;
    final request = ++_audioRequest;
    if (_audioFailed) setState(() => _audioFailed = false);
    try {
      await widget.services.play(_round.question.audio);
    } catch (_) {
      if (mounted &&
          request == _audioRequest &&
          _sound &&
          _foreground &&
          _visible) {
        setState(() => _audioFailed = true);
      }
    }
  }

  /// A single request token covers all steps, including their callbacks.
  Future<bool> _playSequence(
    List<List<String>> steps, {
    void Function(int step)? onStep,
  }) async {
    _cancelEntryPrompt();
    final request = ++_audioRequest;
    bool active() =>
        mounted &&
        request == _audioRequest &&
        _sound &&
        _foreground &&
        _visible &&
        !_rewardsOpen &&
        !_rangePaused &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!active()) return false;
    if (_audioFailed) setState(() => _audioFailed = false);
    try {
      // Replace earlier playback before starting this sequence. Check again after
      // stop: navigation or another request may have happened while awaiting it.
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
      if (active()) setState(() => _audioFailed = true);
      return false;
    }
  }

  VisualQuestionContext get _visualContext => VisualQuestionContext(
    hint: _hint,
    answered: _round.answered,
    enabled:
        !_round.answered &&
        !_writeBlocked &&
        _foreground &&
        _visible &&
        !_rewardsOpen,
    soundOn: _sound,
    selected: _selected,
    playSequence: _playSequence,
  );

  void _tapChoice(String choice) {
    final visual = _round.question.visual;
    if (visual?.selectThenCheck != true) {
      _choose(choice);
      return;
    }
    if (!_visualContext.enabled || choice == _wrongChoice) return;
    setState(() => _selected = choice);
    final clip = visual!.choiceClip(choice);
    if (_sound && clip != null) {
      unawaited(
        _playSequence([
          [clip],
        ]),
      );
    } else {
      // Selecting a card without a clip still cancels an earlier preview.
      unawaited(_stopSpeech());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      if (!_foreground) {
        _clearRetry(resetCooldown: true);
        _retry = false;
      }
    });
    _scheduleAdvance();
    _scheduleEntryPrompt();
    if (!_foreground) {
      _celebration.reset();
      unawaited(_stopSpeech());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(_controllerChanged);
    _advance?.cancel();
    _retryDuration?.cancel();
    _retryCooldown?.cancel();
    _retryFade.dispose();
    _celebration.dispose();
    _scroll.dispose();
    unawaited(_stopSpeech());
    super.dispose();
  }

  void _choose(String choice) {
    if (!_foreground ||
        !_visible ||
        _rewardsOpen ||
        _writeBlocked ||
        (choice == _wrongChoice && !_makeGroup))
      return;
    final result = _round.choose(choice);
    if (result == AnswerResult.ignored) return;
    setState(() => _retry = result == AnswerResult.retry);
    if (_retry) {
      _selected = null;
      _clearRetry();
      _wrongChoice = choice;
      if (!MediaQuery.disableAnimationsOf(context)) _retryFade.forward(from: 0);
      _retryDuration = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _clearRetry());
      });
      if (_retryCooldown == null) {
        _retryCooldown = Timer(const Duration(milliseconds: 600), () {
          _retryCooldown = null;
        });
        unawaited(
          requestFeedback(
            widget.services,
            DeviceFeedback.retry,
            enabled: _settings.haptics,
          ),
        );
      }
    } else {
      _clearRetry();
      unawaited(_stopSpeech());
      _petReaction++;
      unawaited(
        requestFeedback(
          widget.services,
          DeviceFeedback.light,
          enabled: _settings.haptics,
        ),
      );
      _scheduleAdvance();
      if (!MediaQuery.disableAnimationsOf(context)) {
        _celebration.forward(from: 0);
      }
    }
    // Save as soon as the fifth answer is correct, even if Back is tapped next.
    if (_round.finished) _award();
  }

  Future<void> _award() async {
    if (_saving || _reward != null) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final id = _roundId;
    try {
      final count = await widget.onCompleteRound(id);
      if (mounted && id == _roundId)
        setState(() {
          _reward = count;
          _saving = false;
        });
      if (mounted && id == _roundId) _scheduleAdvance();
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
    }
  }

  void _next() {
    if (!_foreground ||
        !_visible ||
        _writeBlocked ||
        !_round.answered ||
        _rewardsOpen ||
        (_round.finished && _reward == null))
      return;
    _advance?.cancel();
    _advance = null;
    _clearRetry(resetCooldown: true);
    _celebration.reset();
    if (_round.finished) {
      _again();
    } else if (_round.next()) {
      if (_countingGame && _scroll.hasClients) _scroll.jumpTo(0);
      setState(() {
        _counting = CountingWork(_countingGame ? _activeRange.max : 10);
        _hint = false;
        _selected = null;
        _retry = false;
      });
      _playPrompt();
    }
  }

  bool _rewardsOpen = false;

  Future<void> _openRewards() async {
    if (_rangePaused ||
        _rewardsOpen ||
        !_foreground ||
        !_visible ||
        widget.controller == null)
      return;
    setState(() => _rewardsOpen = true);
    _advance?.cancel();
    _advance = null;
    _celebration.reset();
    unawaited(_stopSpeech());
    await showLearningRewards(context, widget.controller!);
    if (!mounted) return;
    setState(() {
      _rewardsOpen = false;
      _visible = ModalRoute.isCurrentOf(context) ?? true;
      if (!_round.answered) _entryPromptPending = true;
    });
    _scheduleAdvance();
    _scheduleEntryPrompt();
  }

  Widget _completion() => RoundCompletionControls(
    key: ValueKey('completion-$_roundId'),
    reward: _reward,
    controller: widget.controller,
    manual: _manualNext,
    active: _foreground && _visible && !_rewardsOpen,
    services: widget.services,
    haptics: _settings.haptics,
    saving: _saving,
    failed: _saveFailed,
    onRetry: _saving ? null : _award,
    onNext:
        _reward == null ||
            _saving ||
            _writeBlocked ||
            !_foreground ||
            !_visible ||
            _rewardsOpen
        ? null
        : _again,
    onRewards: widget.controller == null ? null : _openRewards,
  );

  void _again() {
    if (_writeBlocked ||
        !_round.finished ||
        _reward == null ||
        _saving ||
        !_foreground ||
        !_visible ||
        _rewardsOpen)
      return;
    _restartRound();
  }

  void _restartRound() {
    unawaited(_stopSpeech());
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _advance?.cancel();
    _advance = null;
    _clearRetry(resetCooldown: true);
    _celebration.reset();
    setState(() {
      _round = GameRound(
        widget.activity,
        numberRange: _activeRange,
        wordPacks: widget.wordPacks,
        sounds: widget.sounds,
        countingRange: _countingGame ? _activeRange : null,
      );
      _counting = CountingWork(_countingGame ? _activeRange.max : 10);
      _roundId = newRoundId();
      _rewardsOpen = false;
      _petReaction = 0;
      _reward = null;
      _hint = false;
      _selected = null;
      _retry = false;
      _saveFailed = false;
    });
    _entryPromptPending = true;
    _scheduleEntryPrompt();
  }

  Future<void> _editRange({bool initial = false}) async {
    final controller = widget.controller;
    if (controller == null ||
        (!initial &&
            (_writeBlocked || !_foreground || !_visible || _rewardsOpen)))
      return;
    setState(() => _rangeEditorOpen = true);
    _advance?.cancel();
    _advance = null;
    _clearRetry(resetCooldown: true);
    _celebration.reset();
    unawaited(_stopSpeech());
    await openNumberRangeEditor(context, controller, widget.activity);
    if (!mounted) return;
    setState(() {
      _rangeEditorOpen = false;
      _visible = ModalRoute.isCurrentOf(context) ?? true;
      _rangeChangePending =
          controller.effectiveSettings.numberGameRanges.forActivity(
            widget.activity,
          ) !=
          _activeRange;
    });
    _finishRangeChange();
    if (!_round.answered) _entryPromptPending = true;
    _scheduleAdvance();
    _scheduleEntryPrompt();
  }

  void _finishRangeChange() {
    if (!mounted ||
        !_rangeChangePending ||
        _rangeEditorOpen ||
        widget.controller!.blocked.value)
      return;
    _activeRange = widget.controller!.settings.numberGameRanges.forActivity(
      widget.activity,
    );
    _rangeChangePending = false;
    _restartRound();
  }

  @override
  Widget build(BuildContext context) => widget.controller == null
      ? _build(context)
      : ListenableBuilder(
          listenable: widget.controller!,
          builder: (context, _) => _build(context),
        );

  void _revealVisualContent(Question question) {
    final layout = (question, _round.answered, _reward);
    if (_visualLayout == layout) return;
    _visualLayout = layout;
    final answered = _round.answered;
    // Preserve the established header/card sizes. When the fixed bar needs
    // room, move just enough to keep the choices (or the revealed answer)
    // above it. Tall accessibility layouts remain manually scrollable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _round.question != question ||
          _round.answered != answered ||
          !_foreground ||
          !_visible ||
          _rewardsOpen) {
        return;
      }
      final target =
          (answered ? _answerCardKey : _visualChoicesKey).currentContext;
      final box = target?.findRenderObject();
      if (target == null || box is! RenderBox || !_scroll.hasClients) return;
      if (!answered && box.size.height > _scroll.position.viewportDimension) {
        return;
      }
      Scrollable.ensureVisible(
        target,
        alignment: 1,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Widget _scrollBottomBar({required bool visual, required Widget child}) {
    const padding = EdgeInsets.fromLTRB(20, 8, 20, 12);
    if (visual && !_round.finished) {
      return ListView(shrinkWrap: true, padding: padding, children: [child]);
    }
    return SingleChildScrollView(padding: padding, child: child);
  }

  Widget _build(BuildContext context) {
    final question = _round.question;
    final showTarget = _hint;
    final visual = question.visual;
    final checkVisual = visual?.selectThenCheck ?? false;
    if (visual != null) _revealVisualContent(question);
    final choicesEnabled =
        !_round.answered &&
        !_writeBlocked &&
        (visual == null || (_foreground && _visible && !_rewardsOpen));
    final heading = numberGameHeading(context, widget.activity);
    final feedback = Semantics(
      liveRegion: true,
      child: Text(
        _round.answered
            ? 'You found it! ✨'
            : _retry
            ? 'Try again'
            : '',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
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
        actions: [
          if (widget.controller != null)
            LearningRewardsButton(
              count: widget.controller!.progress!.availableChoices,
              onPressed: _openRewards,
            ),
          if (!_rewardsOpen && !_countingGame && !_silentNumbers)
            VoiceButton(
              on: _sound,
              onPressed: _writeBlocked ? null : _toggleVoice,
              subject: _matching
                  ? null
                  : widget.activity == Activity.numbers
                  ? 'number'
                  : widget.activity == Activity.sightWords ||
                        widget.activity == Activity.readAndFind ||
                        widget.activity == Activity.makeBelieve
                  ? 'word'
                  : widget.activity == Activity.letterSounds
                  ? 'sound'
                  : 'letter',
              needsVoice:
                  !_matching &&
                  !_sound &&
                  !_hint &&
                  !_round.answered &&
                  (!widget.activity.isVisualChoice ||
                      widget.activity == Activity.makeBelieve),
              active: _foreground && _visible && !_writeBlocked,
            ),
          if (widget.controller != null &&
              NumberGameRanges.appliesTo(widget.activity))
            NumberRangeButton(
              activity: widget.activity,
              range: widget.controller!.effectiveSettings.numberGameRanges
                  .forActivity(widget.activity),
              onPressed: _writeBlocked || _rewardsOpen
                  ? null
                  : () => _editRange(),
            ),
        ],
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back to ${widget.activity.category.title.toLowerCase()}',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _round.finished || _countingGame || visual != null
          ? SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .55,
                ),
                child: _scrollBottomBar(
                  visual: visual != null,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: _round.finished
                          ? _completion()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (visual != null) feedback,
                                if (visual != null) const SizedBox(height: 8),
                                if (checkVisual && !_round.answered)
                                  FilledButton.icon(
                                    key: const ValueKey('check-visual'),
                                    onPressed:
                                        !_visualContext.enabled ||
                                            _selected == null
                                        ? null
                                        : () => _choose(_selected!),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Check'),
                                  ),
                                if (_makeGroup && !_round.answered)
                                  FilledButton.icon(
                                    key: const ValueKey('check-counting'),
                                    onPressed: _writeBlocked
                                        ? null
                                        : () => _choose(
                                            '${_counting.items.length}',
                                          ),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Check'),
                                  ),
                                if (visual != null &&
                                    (!checkVisual || _round.answered))
                                  // Reserve the same action row as Check/Next,
                                  // including when automatic advance is saved.
                                  Visibility(
                                    visible: _round.answered && _manualNext,
                                    maintainState: true,
                                    maintainAnimation: true,
                                    maintainSize: true,
                                    child: FilledButton.icon(
                                      onPressed: _writeBlocked ? null : _next,
                                      icon: const Icon(
                                        Icons.arrow_forward_rounded,
                                      ),
                                      label: Text(
                                        _round.answered && _manualNext
                                            ? 'Next'
                                            : '',
                                      ),
                                    ),
                                  ),
                                if (visual == null &&
                                    _round.answered &&
                                    _manualNext)
                                  FilledButton.icon(
                                    onPressed: _writeBlocked ? null : _next,
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                    ),
                                    label: const Text('Next'),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: PageBody(
        controller: _scroll,
        children: [
          if (widget.controller != null && !_round.finished)
            SaveStatus(controller: widget.controller!),
          Semantics(
            label: '${_round.completed} of 5 found',
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < GameRound.length; i++)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: AnimatedBuilder(
                        animation: _celebration,
                        builder: (context, child) => Transform.scale(
                          key: ValueKey('progress-star-$i'),
                          scale:
                              i == _round.completed - 1 &&
                                  _round.answered &&
                                  !MediaQuery.disableAnimationsOf(context)
                              ? 1 + .25 * math.sin(math.pi * _celebration.value)
                              : 1,
                          child: child,
                        ),
                        child: Icon(
                          i < _round.completed
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: i < _round.completed
                              ? GardenColors.of(context).star
                              : GardenColors.of(context).emptyStar,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          GardenArt(
            height: _countingGame || _silentNumbers ? 64 : 120,
            configuration: widget.controller?.progress?.companion,
            reactionTrigger: _round.answered ? _petReaction : 0,
          ),
          Text(
            question.instruction,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          if (visual != null) buildVisualPrompt(visual, _visualContext),
          if (visual == null && question.partner != null)
            Text(
              question.partner!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 66, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_sound && !_rewardsOpen && question.audio.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _playPrompt,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Listen again'),
                ),
              if (!showTarget)
                TextButton.icon(
                  onPressed: () => setState(() => _hint = true),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Show a hint'),
                ),
            ],
          ),
          if (showTarget && !_makeGroup && visual == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: widget.activity == Activity.letterSounds
                  ? Column(
                      children: [
                        Image.asset(
                          'assets/phonics/${question.answer}.png',
                          width: 96,
                          height: 96,
                          semanticLabel: soundFor(question.answer).word,
                        ),
                        Text(
                          '${question.answer} — ${soundFor(question.answer).word}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Find ${question.answer}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          if (_audioFailed)
            const Text(
              'Sound could not play. You can use the hint.',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 22),
          if (_countingGame)
            SuccessCelebration(
              animation: _celebration,
              active:
                  _makeGroup &&
                  _round.answered &&
                  !MediaQuery.disableAnimationsOf(context),
              child: CountingBoard(
                scene: question.counting!,
                work: _counting,
                makeGroup: _makeGroup,
                maximum: _activeRange.max,
                hint: _hint,
                enabled:
                    !_round.answered &&
                    !_writeBlocked &&
                    _foreground &&
                    _visible,
                onChanged: () => setState(() {
                  _retry = false;
                  _clearRetry();
                }),
              ),
            ),
          if (_countingGame) const SizedBox(height: 16),
          if (!_makeGroup)
            LayoutBuilder(
              builder: (context, constraints) {
                final wordGame = widget.activity == Activity.sightWords;
                const wordStyle = TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                );
                final width = wordGame || (visual?.fullWidthChoices ?? false)
                    ? constraints.maxWidth
                    : ((constraints.maxWidth - 24) / 3).clamp(80.0, 180.0);
                return Wrap(
                  key: visual != null ? _visualChoicesKey : null,
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < question.choices.length; i++)
                      SizedBox(
                        key:
                            visual != null &&
                                question.choices[i] == question.answer
                            ? _answerCardKey
                            : null,
                        width: width,
                        child: Semantics(
                          label: visual != null
                              ? visual.choiceLabel(question.choices[i])
                              : widget.activity == Activity.sightWords
                              ? 'Word ${question.choices[i]}'
                              : (widget.activity == Activity.numbers ||
                                    _countingGame)
                              ? 'Number ${question.choices[i]}'
                              : '${question.choices[i] == question.choices[i].toUpperCase() ? 'Uppercase' : 'Lowercase'} ${question.choices[i]}',
                          selected: visual?.selectThenCheck == true
                              ? _selected == question.choices[i]
                              : null,
                          button: true,
                          enabled: choicesEnabled,
                          onTap: !choicesEnabled
                              ? null
                              : () => _tapChoice(question.choices[i]),
                          child: SuccessCelebration(
                            animation: _celebration,
                            active:
                                _round.answered &&
                                question.choices[i] == question.answer &&
                                !MediaQuery.disableAnimationsOf(context),
                            child: RetryMarker(
                              animation: _retryFade,
                              active: _wrongChoice == question.choices[i],
                              reducedMotion: MediaQuery.disableAnimationsOf(
                                context,
                              ),
                              child: ExcludeSemantics(
                                child: FilledButton(
                                  key: ValueKey(
                                    'choice-${question.choices[i]}',
                                  ),
                                  onPressed: !choicesEnabled
                                      ? null
                                      : () => _tapChoice(question.choices[i]),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(80, 100),
                                    backgroundColor: GardenColors.of(
                                      context,
                                    ).card(rainbow[i * 2], white: .65),
                                    foregroundColor: GardenColors.of(
                                      context,
                                    ).foreground,
                                    disabledBackgroundColor:
                                        _round.answered &&
                                            question.choices[i] ==
                                                question.answer
                                        ? GardenColors.of(
                                            context,
                                          ).successSurface
                                        : GardenColors.of(context).mutedSurface,
                                    disabledForegroundColor: GardenColors.of(
                                      context,
                                    ).foreground,
                                    shape: RoundedRectangleBorder(
                                      side:
                                          visual?.selectThenCheck == true &&
                                              !_round.answered &&
                                              _selected == question.choices[i]
                                          ? BorderSide(
                                              color: GardenColors.of(
                                                context,
                                              ).accent(rainbow[i * 2]),
                                              width: 4,
                                            )
                                          : GardenColors.of(context).isDark
                                          ? BorderSide(
                                              color:
                                                  _round.answered &&
                                                      question.choices[i] ==
                                                          question.answer
                                                  ? GardenColors.of(
                                                      context,
                                                    ).successBorder
                                                  : GardenColors.of(
                                                      context,
                                                    ).accent(rainbow[i * 2]),
                                            )
                                          : BorderSide.none,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: visual != null
                                      ? buildVisualChoice(
                                          visual,
                                          question.choices[i],
                                          _visualContext,
                                        )
                                      : wordGame
                                      ? Text(
                                          question.choices[i],
                                          style: wordStyle,
                                          maxLines: 1,
                                        )
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            question.choices[i],
                                            style: const TextStyle(
                                              fontSize: 56,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (visual == null) ...[
            const SizedBox(height: 20),
            feedback,
            const SizedBox(height: 20),
          ],
          if (!_countingGame &&
              visual == null &&
              _round.answered &&
              !_round.finished &&
              _manualNext)
            FilledButton.icon(
              onPressed: _writeBlocked || (_round.finished && _reward == null)
                  ? null
                  : _next,
              icon: Icon(
                _round.finished
                    ? Icons.auto_awesome
                    : Icons.arrow_forward_rounded,
              ),
              label: const Text('Next'),
            ),
        ],
      ),
    );
  }
}
