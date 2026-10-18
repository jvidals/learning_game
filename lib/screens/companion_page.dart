import '../app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../device_services.dart';
import '../progress.dart';
import '../progress_controller.dart';
import '../companion.dart';
import '../companion/foal_clip.dart';
import '../widgets/companion_choices.dart';
import '../widgets/progress_widgets.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key, required this.controller});
  final ProgressController controller;
  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  RewardCategory _category = RewardCategory.mane;
  int _preview = 0;
  int _previewSequence = 0;
  Timer? _previewCooldown;
  final _choicesScroll = ScrollController();
  CompanionReward? _pendingEquipment;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_equipmentSaved);
  }

  @override
  void didUpdateWidget(CompanionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_equipmentSaved);
      _pendingEquipment = null;
      widget.controller.addListener(_equipmentSaved);
    }
  }

  void _equipmentSaved() {
    final reward = _pendingEquipment;
    if (reward == null ||
        (widget.controller.progress!.companion[reward.category] ?? '') !=
            reward.id) {
      return;
    }
    _pendingEquipment = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _category == RewardCategory.behavior &&
          reward.category == _category &&
          ModalRoute.of(context)!.isCurrent) {
        // A newly saved behavior gets its own complete demonstration; an
        // earlier preview's cooldown must not stretch or suppress this clip.
        _previewCooldown?.cancel();
        _demonstrate(feedback: false);
      }
    });
  }

  void _selectCategory(RewardCategory category) {
    setState(() {
      _category = category;
      _preview = 0;
      _previewCooldown?.cancel();
    });
    if (_choicesScroll.hasClients) _choicesScroll.jumpTo(0);
  }

  void _demonstrate({bool feedback = true}) {
    if (_previewCooldown?.isActive == true) return;
    _previewCooldown = Timer(
      foalReactionDuration(
        behavior:
            widget.controller.progress!.companion[RewardCategory.behavior],
      ),
      () {},
    );
    setState(() => _preview = ++_previewSequence);
    if (feedback) {
      unawaited(
        requestFeedback(
          widget.controller.services,
          DeviceFeedback.light,
          enabled: widget.controller.settings.haptics,
        ),
      );
    }
  }

  Future<void> _equip(CompanionReward reward) async {
    final c = widget.controller;
    if ((c.progress!.companion[reward.category] ?? '') == reward.id) {
      if (reward.category == RewardCategory.behavior) _demonstrate();
      return;
    }
    _pendingEquipment = reward;
    try {
      await c.equip(reward.category, reward.id.isEmpty ? null : reward.id);
    } catch (_) {}
  }

  Future<void> _gifts() async {
    setState(() => _preview = 0);
    final reward = await showModalBottomSheet<CompanionReward>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .8,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close gifts',
                icon: const Icon(Icons.close_rounded),
                constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    SaveStatus(controller: widget.controller),
                    RewardChoices(
                      controller: widget.controller,
                      onChosen: (reward) {
                        if (ModalRoute.of(sheetContext)!.isCurrent) {
                          Navigator.pop(sheetContext, reward);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || reward == null) return;
    _selectCategory(reward.category);
    if (reward.category == RewardCategory.behavior) {
      _demonstrate(feedback: false);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_equipmentSaved);
    _choicesScroll.dispose();
    _previewCooldown?.cancel();
    super.dispose();
  }

  Widget _stage(double height, PlayerProgress p) => Container(
    margin: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: GardenColors.of(context).panel,
      borderRadius: BorderRadius.circular(28),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        CompanionView(
          key: const ValueKey('customization-preview'),
          configuration: p.companion,
          onPet: () => requestFeedback(
            widget.controller.services,
            DeviceFeedback.light,
            enabled: widget.controller.settings.haptics,
          ),
          height: height,
          reactionTrigger: _preview,
          boundedCelebration: true,
          clipToFraming: false,
          framing: switch (_category) {
            RewardCategory.mane ||
            RewardCategory.accessory => CompanionFraming.head,
            RewardCategory.wings => CompanionFraming.wings,
            RewardCategory.behavior ||
            RewardCategory.polish => CompanionFraming.full,
          },
        ),
        if (p.availableChoices > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Semantics(
              label: 'Choose a unicorn surprise (${p.availableChoices} ready)',
              button: true,
              onTap: _gifts,
              excludeSemantics: true,
              child: IconButton.filledTonal(
                tooltip:
                    'Choose a unicorn surprise (${p.availableChoices} ready)',
                constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
                onPressed: _gifts,
                icon: ExcludeSemantics(
                  child: Badge(
                    label: Text('${p.availableChoices}'),
                    child: const Icon(Icons.card_giftcard_rounded, size: 36),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _controls(PlayerProgress p) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: CompanionCategoryTabs(
          selected: _category,
          onSelected: _selectCategory,
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          controller: _choicesScroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                categoryLabel(_category),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SaveStatus(controller: widget.controller),
              CompanionChoiceGrid(
                rewards: [
                  defaultCompanionReward(_category),
                  ...rewardCatalog.where(
                    (r) => r.category == _category && p.owned.contains(r.id),
                  ),
                ],
                selectedId: p.companion[_category] ?? '',
                onSelected: widget.controller.blocked.value ? null : _equip,
              ),
              if (_category == RewardCategory.behavior) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _demonstrate,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 64),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 32),
                  label: const Text('Preview celebration'),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Unicorn')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) {
            final p = widget.controller.progress!;
            final wide = box.maxWidth >= 600;
            if (wide) {
              return Row(
                children: [
                  SizedBox(
                    // Keep five 64 dp picture targets on short landscape phones.
                    width: (box.maxWidth / 2)
                        .clamp(0, box.maxWidth - 368)
                        .toDouble(),
                    child: Center(
                      child: _stage(
                        box.maxHeight.clamp(120, 400).toDouble() - 24,
                        p,
                      ),
                    ),
                  ),
                  Expanded(child: _controls(p)),
                ],
              );
            }
            final height = (box.maxHeight * .32).clamp(120, 260).toDouble();
            return Column(
              children: [
                _stage(height, p),
                Expanded(child: _controls(p)),
              ],
            );
          },
        ),
      ),
    ),
  );
}
