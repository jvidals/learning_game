import 'package:flutter/material.dart';
import '../progress.dart';
import '../progress_controller.dart';
import 'companion_choices.dart';

class LevelProgress extends StatelessWidget {
  const LevelProgress({super.key, required this.progress});
  final PlayerProgress progress;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'Level ${progress.level}',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: progress.levelXp / progress.nextLevelXp,
        minHeight: 10,
        borderRadius: BorderRadius.circular(8),
        semanticsLabel: 'Learning XP',
        semanticsValue:
            '${progress.levelXp} of ${progress.nextLevelXp} to next level',
      ),
      const SizedBox(height: 8),
      Text(
        '${progress.levelXp} / ${progress.nextLevelXp} XP to level ${progress.level + 1}',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class SaveStatus extends StatelessWidget {
  const SaveStatus({super.key, required this.controller});
  final ProgressController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      children: [
        if (controller.savingSettings && controller.writing)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Semantics(liveRegion: true, child: Text('Saving settings…')),
          ),
        if (controller.writing && !controller.savingSettings)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                CircularProgressIndicator(
                  semanticsLabel: 'Saving your progress',
                ),
                SizedBox(height: 8),
                Text('Saving your progress…'),
              ],
            ),
          ),
        if (controller.failure != null) ...[
          Text(controller.failure!, textAlign: TextAlign.center),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 32),
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 64)),
            onPressed: controller.writing
                ? null
                : () async {
                    try {
                      await controller.retry();
                    } catch (_) {}
                  },
            label: const Text('Try saving again'),
          ),
        ],
      ],
    ),
  );
}

class RewardChoices extends StatefulWidget {
  const RewardChoices({super.key, required this.controller, this.onChosen});
  final ProgressController controller;
  final ValueChanged<CompanionReward>? onChosen;
  @override
  State<RewardChoices> createState() => _RewardChoicesState();
}

class _RewardChoicesState extends State<RewardChoices> {
  CompanionReward? _pending;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_saved);
  }

  @override
  void didUpdateWidget(RewardChoices oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_saved);
      _pending = null;
      widget.controller.addListener(_saved);
    }
  }

  void _saved() {
    final reward = _pending;
    if (reward == null ||
        !widget.controller.progress!.owned.contains(reward.id))
      return;
    _pending = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChosen?.call(reward);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_saved);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final p = widget.controller.progress!;
      if (p.availableChoices <= 0) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.card_giftcard_rounded, size: 40),
          Text(
            'Choose a reward',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          CompanionChoiceGrid(
            rewards: p.choices,
            onSelected: widget.controller.blocked.value
                ? null
                : (reward) async {
                    _pending = reward;
                    try {
                      await widget.controller.choose(reward.id);
                    } catch (_) {}
                  },
          ),
        ],
      );
    },
  );
}
