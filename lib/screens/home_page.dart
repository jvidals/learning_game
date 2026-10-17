import 'dart:async';
import 'package:flutter/material.dart';
import '../progress_controller.dart';
import '../companion.dart';
import '../device_services.dart';
import '../game.dart';
import '../garden_art.dart';
import '../app_theme.dart';
import '../widgets/page_body.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/selection_card.dart';
import '../widgets/activity_illustration.dart';
import 'tap_challenge_page.dart';
import '../widgets/tap_challenge_art.dart';
import 'companion_page.dart';
import 'category_page.dart';
import 'game_page.dart';
import 'ordering_page.dart';
import 'game_2048_page.dart';
import 'writing_page.dart';
import 'settings_page.dart';
import 'profiles_sheet.dart';
import '../widgets/profile_portrait.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.services, required this.controller});
  final ProgressController controller;
  final DeviceServices services;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  ProgressController get _controller => widget.controller;
  bool _opening = false;
  bool get _sound => _controller.soundOn;

  Future<void> _toggleSound() async {
    if (_opening || _controller.blocked.value || _controller.progress == null) {
      return;
    }
    final next = !_sound;
    final save = _controller.setSound(next);
    if (!next) unawaited(widget.services.stop().catchError((Object _) {}));
    try {
      await save;
    } catch (_) {
      // The shared save status retains this choice for retry after navigation.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(widget.services.stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.services.stop());
    super.dispose();
  }

  Future<void> _push(Widget page) async {
    if (_opening) return;
    setState(() => _opening = true);
    unawaited(widget.services.stop());
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _start(Activity activity, {bool editRange = false}) async {
    if (_controller.blocked.value) return;
    unawaited(widget.services.stop());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => activity == Activity.tapChallenge
            ? TapChallengePage(controller: _controller)
            : activity == Activity.handwriting
            ? WritingPage(controller: _controller)
            : activity == Activity.game2048
            ? Game2048Page(controller: _controller)
            : activity.isOrdering
            ? OrderingPage(
                activity: activity,
                controller: _controller,
                numberRange: _controller.settings.numberGameRanges.numberOrder,
                openRangeSettings: editRange,
              )
            : GamePage(
                services: widget.services,
                activity: activity,
                sound: _sound,
                wordPacks: _controller.settings.enabledSightWordPacks,
                sounds: _controller.settings.enabledLetterSounds,
                countingRange: activity.isCounting
                    ? _controller.settings.numberGameRanges.forActivity(
                        activity,
                      )
                    : null,
                numberRange: _controller.settings.numberGameRanges.numberHunt,
                openRangeSettings: editRange,
                controller: _controller,
                onCompleteRound: _controller.completeRound,
              ),
      ),
    );
  }

  Future<void> _profiles() async {
    if (_opening || _controller.blocked.value) return;
    setState(() => _opening = true);
    unawaited(widget.services.stop());
    try {
      await openProfiles(context, _controller);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _settings() async {
    if (_opening || _controller.blocked.value) return;
    setState(() => _opening = true);
    unawaited(widget.services.stop());
    try {
      if (!await openParentGate(context) || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SettingsPage(controller: _controller, onReset: _controller.reset),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final p = _controller.progress,
          busy = _controller.blocked.value || _opening;
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    if (_controller.activeProfile != null)
                      IconButton(
                        key: const ValueKey('profile-picker'),
                        tooltip: 'Players: ${_controller.activeProfile!.name}',
                        padding: EdgeInsets.zero,
                        onPressed: busy ? null : _profiles,
                        icon: ProfilePortrait(
                          configuration: _controller.activeProfile!.portrait,
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: _sound ? 'Turn sound off' : 'Turn sound on',
                      onPressed: busy || p == null ? null : _toggleSound,
                      icon: Icon(
                        _sound
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: busy ? null : _settings,
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageBody(
                  children: [
                    Text(
                      _controller.activeProfile == null
                          ? 'Hi!'
                          : 'Hi, ${_controller.activeProfile!.name}!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: GardenColors.of(context).foreground,
                      ),
                    ),
                    if (p != null)
                      CompanionView(
                        key: ValueKey(_controller.activeProfile?.id),
                        configuration: p.companion,
                        height: 240,
                        onPet: () => requestFeedback(
                          widget.services,
                          DeviceFeedback.light,
                          enabled: _controller.settings.haptics,
                        ),
                      ),
                    SaveStatus(controller: _controller),
                    if (p == null) ...[
                      if (_controller.loadFailed) ...[
                        const Text(
                          'Your progress could not open. Try again, or ask a grown-up to reset progress in Settings.',
                          textAlign: TextAlign.center,
                        ),
                        OutlinedButton(
                          onPressed: _controller.load,
                          child: const Text('Try again'),
                        ),
                      ] else
                        const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Opening your progress',
                          ),
                        ),
                    ] else ...[
                      LevelProgress(progress: p),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _push(
                                    CompanionPage(controller: _controller),
                                  ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (p.availableChoices > 0) ...[
                                  ExcludeSemantics(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.card_giftcard_rounded,
                                          size: 40,
                                        ),
                                        const SizedBox(width: 2),
                                        Badge(
                                          label: Text('${p.availableChoices}'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Flexible(
                                  child: Text(
                                    'My unicorn',
                                    textAlign: TextAlign.center,
                                    semanticsLabel: p.availableChoices > 0
                                        ? 'My unicorn, ${p.availableChoices} rewards available'
                                        : 'My unicorn',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SelectionGrid(
                        children: [
                          for (final category in GameCategory.values)
                            SelectionCard(
                              title: category.title,
                              example: category.example,
                              illustration: category == GameCategory.reflex
                                  ? const TapChallengeIllustration()
                                  : category == GameCategory.writing
                                  ? const HandwritingIllustration()
                                  : null,
                              subtitle: '',
                              color: rainbow[category.colorIndex],
                              onTap: busy
                                  ? null
                                  : () => _push(
                                      CategoryPage(
                                        category: category,
                                        controller: _controller,
                                        onEditRange: (activity) =>
                                            _start(activity, editRange: true),
                                        savingReward: _controller.blocked,
                                        onStart: _start,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ],
                    TextButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('For grown-ups'),
                          scrollable: true,
                          content: const Text(
                            'Learning rounds have no timers or penalties. A wrong answer shows a brief fading × and the words “Try again”; you can choose again straight away. Retry haptics follow the Haptics switch and system settings. Five finds earn 50 XP. Levels earn unicorn surprises. Reflex opens Tap Challenge: tap stars (+1) and rainbows (+3), avoid bombs (−2). Rounds last 30 active seconds and scores never go below zero. A completed new personal best earns 50 XP, including the first positive score. Play again whenever you like.\n\nAlphabet Order and Number Order use a full board of cards. Hold and drag, or tap two cards to swap. Read across each row, then down. Correct cards turn green and lock; ordering the whole board earns 50 XP. The alphabet A/a button changes case immediately and remembers your choice. Number Order uses every number in the saved range.\n\nWriting teaches uppercase and lowercase together. Trace the example, then write on the blank lines and tap Check. Both forms earn 10 XP together. Clear lets you practise again without more XP; Skip letter moves on without XP. Your shuffled alphabet and completed forms are saved. Choose a letter opens practice only, without XP.\n\nSight Words uses words from the packs enabled in parent settings. Open Sight Word packs to choose packs; at least one must stay enabled.\n\nVoice is used only for letter, number and word identification and optional Letter friends instructions. Rewards, retries and other screens are silent. The Home and identification voice buttons share a remembered sound setting. Turning voice on in an identification question plays its target. When muted, the speaker gently pulses until you turn voice on or choose Show a hint. Reduced motion keeps a steady highlight. Hints reveal answers only when you ask. Letter friends starts from the remembered setting and has its own optional voice button; its choice lasts through Play again until you leave. Turning that button on is silent.\n\nSettings controls appearance, Tap Next and haptics. Number games have their own range button, with a shortcut beside each activity. Changes apply and save automatically. Appearance follows the phone by default, or a grown-up can choose Light or Dark for each player. Turn Tap Next off for an automatic short pause between finds; the fifth find always waits. Accessible navigation keeps Next. Everything, including speech, works offline. Unfinished learning and Tap Challenge rounds restart when you leave. Clearing app data or uninstalling removes progress.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Back to home'),
                            ),
                          ],
                        ),
                      ),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('For grown-ups'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
