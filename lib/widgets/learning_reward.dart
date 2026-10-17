import 'dart:async';
import 'package:flutter/material.dart';
import '../progress.dart';
import '../progress_controller.dart';
import '../device_services.dart';
import '../companion.dart';
import 'progress_widgets.dart';
import 'success_celebration.dart';

const roundContinuationDelay = Duration(seconds: 2);

/// A quiet entry point that remains available even when there are no gifts.
class LearningRewardsButton extends StatelessWidget {
  const LearningRewardsButton({
    super.key,
    required this.count,
    required this.onPressed,
  });
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = count > 0 ? 'Rewards, $count unclaimed gifts' : 'Rewards';
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: onPressed,
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(Icons.card_giftcard_rounded),
        ),
      ),
    );
  }
}

/// The solved game stays on screen; saving always gates continuation.
class RoundCompletionControls extends StatefulWidget {
  const RoundCompletionControls({
    super.key,
    required this.reward,
    required this.manual,
    required this.active,
    required this.services,
    required this.haptics,
    required this.onNext,
    this.controller,
    this.onRewards,
    this.saving = false,
    this.failed = false,
    this.onRetry,
  });
  final RoundRewardResult? reward;
  final ProgressController? controller;
  final bool manual, active, haptics, saving, failed;
  final DeviceServices services;
  final VoidCallback? onNext, onRewards, onRetry;

  @override
  State<RoundCompletionControls> createState() =>
      _RoundCompletionControlsState();
}

class _RoundCompletionControlsState extends State<RoundCompletionControls>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkle;
  @override
  void initState() {
    super.initState();
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  bool _celebrated = false;

  void _sync() {
    if (!widget.active) {
      _sparkle.stop();
      _sparkle.value = 0;
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _sparkle.stop();
      _sparkle.value = 0;
    }
    if (widget.reward == null || _celebrated) return;
    _celebrated = true;
    if (widget.reward!.levelsEarned <= 0) return;
    if (!MediaQuery.disableAnimationsOf(context)) _sparkle.forward(from: 0);
    unawaited(
      requestFeedback(
        widget.services,
        DeviceFeedback.confirm,
        enabled: widget.haptics,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RoundCompletionControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.reward != null)
        Semantics(
          liveRegion: true,
          child: SuccessCelebration(
            animation: _sparkle,
            active: widget.active && !MediaQuery.disableAnimationsOf(context),
            child: Column(
              children: [
                const Text(
                  '50 XP earned!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                if (widget.reward!.levelsEarned > 0)
                  const Text('Level up!', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      if (widget.controller != null)
        SaveStatus(controller: widget.controller!)
      else ...[
        if (widget.saving)
          const Text('Saving your progress…', textAlign: TextAlign.center),
        if (widget.failed) ...[
          const Text(
            'Your XP could not be saved yet.',
            textAlign: TextAlign.center,
          ),
          OutlinedButton(
            onPressed: widget.onRetry,
            child: const Text('Try saving again'),
          ),
        ],
      ],
      if (!widget.manual && widget.reward != null && widget.onNext != null)
        const Text('Next round starting soon.', textAlign: TextAlign.center),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: widget.onNext,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Next round'),
      ),
      if (widget.onRewards != null) ...[
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: widget.onRewards,
          icon: const Icon(Icons.card_giftcard_rounded),
          label: const Text('Rewards'),
        ),
      ],
    ],
  );
}

/// No round snapshot: the sheet always reflects committed player progress.
Future<void> showLearningRewards(
  BuildContext context,
  ProgressController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _LearningRewardsSheet(controller: controller),
);

class _LearningRewardsSheet extends StatefulWidget {
  const _LearningRewardsSheet({required this.controller});
  final ProgressController controller;
  @override
  State<_LearningRewardsSheet> createState() => _LearningRewardsSheetState();
}

class _LearningRewardsSheetState extends State<_LearningRewardsSheet> {
  final _preview = GlobalKey();
  int _demonstration = 0;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final progress = widget.controller.progress!;
        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 20),
                const Expanded(
                  child: Text(
                    'Rewards',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close rewards',
                  constraints: const BoxConstraints(
                    minWidth: 56,
                    minHeight: 56,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CompanionView(
                          key: _preview,
                          configuration: progress.companion,
                          reactionTrigger: _demonstration,
                          boundedCelebration: true,
                        ),
                        LevelProgress(progress: progress),
                        const SizedBox(height: 16),
                        SaveStatus(controller: widget.controller),
                        if (progress.availableChoices > 0)
                          RewardChoices(
                            controller: widget.controller,
                            onChosen: (reward) {
                              if (reward.category == RewardCategory.behavior) {
                                setState(() => _demonstration++);
                              }
                              final preview = _preview.currentContext;
                              if (preview != null) {
                                Scrollable.ensureVisible(preview);
                              }
                            },
                          )
                        else
                          const Text(
                            'No gifts to choose right now.',
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('Back to home'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to game'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
