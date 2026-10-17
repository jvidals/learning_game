import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../game.dart';
import '../garden_art.dart';
import '../app_settings.dart';
import '../progress_controller.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/page_body.dart';
import '../widgets/selection_card.dart';
import '../widgets/activity_illustration.dart';
import '../widgets/tap_challenge_art.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    required this.category,
    required this.controller,
    required this.onEditRange,
    required this.savingReward,
    required this.onStart,
  });
  final GameCategory category;
  final ProgressController controller;
  final Future<void> Function(Activity) onEditRange;
  final ValueListenable<bool> savingReward;
  final Future<void> Function(Activity) onStart;
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  bool _openingGame = false;
  Future<void> _start(Activity activity, {bool editRange = false}) async {
    if (_openingGame || widget.savingReward.value) return;
    setState(() => _openingGame = true);
    try {
      await (editRange
          ? widget.onEditRange(activity)
          : widget.onStart(activity));
    } finally {
      if (mounted) setState(() => _openingGame = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(widget.category.title),
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: widget.savingReward,
        builder: (context, saving, _) => PageBody(
          children: [
            SelectionGrid(
              uniformHeight: widget.category == GameCategory.numbers,
              children: [
                for (final activity in widget.category.activities)
                  SelectionCard(
                    title: activity.title,
                    showPlayArrow: widget.category != GameCategory.numbers,
                    example: activity.example,
                    illustration: switch (activity) {
                      Activity.tapChallenge => const TapChallengeIllustration(),
                      Activity.alphabetOrder => const OrderingIllustration(),
                      Activity.numberOrder => const OrderingIllustration(
                        numbers: true,
                      ),
                      Activity.handwriting => const HandwritingIllustration(),
                      Activity.howMany => const CountingIllustration(),
                      Activity.makeGroup => const CountingIllustration(
                        makeGroup: true,
                      ),
                      Activity.cursive => const CursiveIllustration(),
                      Activity.sameNumber => const SameNumberIllustration(),
                      Activity.wordSprint => const WordSprintIllustration(),
                      Activity.readAndFind => const ReadAndFindIllustration(),
                      Activity.makeBelieve => const MakeBelieveIllustration(),
                      Activity.numberParts => const NumberPartsIllustration(),
                      _ => null,
                    },
                    trailingAction: NumberGameRanges.appliesTo(activity)
                        ? SelectionCardAction(
                            key: ValueKey('range-${activity.name}'),
                            onPressed: saving || _openingGame
                                ? null
                                : () => _start(activity, editRange: true),
                            label: widget
                                .controller
                                .effectiveSettings
                                .numberGameRanges
                                .forActivity(activity)
                                .label,
                            semanticsLabel:
                                'Change ${activity.title} range, ${widget.controller.effectiveSettings.numberGameRanges.forActivity(activity).label}',
                          )
                        : null,
                    subtitle:
                        activity.category == GameCategory.numbers &&
                            activity != Activity.game2048
                        ? ''
                        : activity == Activity.readAndFind ||
                              activity == Activity.makeBelieve ||
                              activity == Activity.wordSprint ||
                              activity == Activity.letterSounds ||
                              activity == Activity.tapChallenge ||
                              activity == Activity.game2048 ||
                              activity == Activity.handwriting ||
                              activity == Activity.cursive
                        ? activity.subtitle
                        : activity == Activity.matching
                        ? 'Match the letter friends'
                        : '',
                    color: rainbow[activity.colorIndex],
                    onTap: saving || _openingGame
                        ? null
                        : () => _start(activity),
                  ),
              ],
            ),
            SaveStatus(controller: widget.controller),
          ],
        ),
      ),
    ),
  );
}
