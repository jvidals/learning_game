import '../app_theme.dart';
import 'package:flutter/material.dart';
import '../progress.dart';
import '../companion.dart';

String categoryLabel(RewardCategory category) => switch (category) {
  RewardCategory.mane => 'Colors',
  RewardCategory.accessory => 'Headwear',
  RewardCategory.wings => 'Wings',
  RewardCategory.behavior => 'Celebrations',
  RewardCategory.polish => 'Nail polish',
};

CompanionReward defaultCompanionReward(RewardCategory category) =>
    CompanionReward('', switch (category) {
      RewardCategory.mane => 'Pink mane',
      RewardCategory.accessory => 'No headwear',
      RewardCategory.wings => 'No wings',
      RewardCategory.behavior => 'Simple celebration',
      RewardCategory.polish => 'No polish',
    }, category);

class CompanionChoiceArt extends StatelessWidget {
  const CompanionChoiceArt({
    super.key,
    required this.category,
    this.id,
    this.swatch = false,
  });
  final RewardCategory category;
  final String? id;
  final bool swatch;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      fit: StackFit.expand,
      children: [
        CompanionItemArt(category: category, id: id),
        if (category == RewardCategory.behavior)
          Align(
            alignment: Alignment.topRight,
            child: Icon(switch (id) {
              'hop' => Icons.arrow_upward_rounded,
              'bowing' => Icons.south_east_rounded,
              'twirl' => Icons.rotate_right_rounded,
              _ => Icons.auto_awesome_rounded,
            }, size: 26),
          ),
      ],
    ),
  );
}

/// A single semantics node and a full-card Material tap target.
class CompanionChoiceCard extends StatelessWidget {
  const CompanionChoiceCard({
    super.key,
    required this.reward,
    required this.onPressed,
    this.selected = false,
  });
  final CompanionReward reward;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: reward.label,
      button: true,
      selected: selected,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? colors.primaryContainer
            : GardenColors.of(context).panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 76,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CompanionChoiceArt(
                          category: reward.category,
                          id: reward.id.isEmpty ? null : reward.id,
                          swatch: true,
                        ),
                      ),
                      if (selected)
                        Align(
                          alignment: Alignment.topLeft,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: colors.primary,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reward.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

class CompanionChoiceGrid extends StatelessWidget {
  const CompanionChoiceGrid({
    super.key,
    required this.rewards,
    required this.onSelected,
    this.selectedId,
  });
  final List<CompanionReward> rewards;
  final ValueChanged<CompanionReward>? onSelected;
  final String? selectedId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 420 ? 3 : 2;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final reward in rewards)
            SizedBox(
              width: width,
              child: CompanionChoiceCard(
                key: ValueKey(
                  'companion-choice-${reward.category.name}-${reward.id}',
                ),
                reward: reward,
                selected: selectedId == reward.id,
                onPressed: onSelected == null
                    ? null
                    : () => onSelected!(reward),
              ),
            ),
        ],
      );
    },
  );
}

class CompanionCategoryTabs extends StatelessWidget {
  const CompanionCategoryTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final RewardCategory selected;
  final ValueChanged<RewardCategory> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 350 ? 5 : 3;
      final width = box.maxWidth / columns;
      return Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 6,
        children: [
          for (final category in RewardCategory.values)
            SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Semantics(
                  label: categoryLabel(category),
                  button: true,
                  selected: selected == category,
                  onTap: () => onSelected(category),
                  excludeSemantics: true,
                  child: Tooltip(
                    message: categoryLabel(category),
                    child: Material(
                      color: selected == category
                          ? Theme.of(context).colorScheme.primaryContainer
                          : GardenColors.of(context).panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          width: selected == category ? 3 : 1,
                          color: selected == category
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelected(category),
                        child: SizedBox(
                          height: 72,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: CompanionChoiceArt(
                              category: category,
                              id: switch (category) {
                                RewardCategory.mane => 'mint',
                                RewardCategory.accessory => 'star',
                                RewardCategory.wings => 'feather',
                                RewardCategory.behavior => 'hop',
                                RewardCategory.polish => 'polish_pink',
                              },
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
  );
}
