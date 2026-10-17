import '../app_theme.dart';
import 'package:flutter/material.dart';
import '../progress.dart';
import '../companion.dart';
import '../companion/foal_assets.dart';

/// Static and shared: portraits never start animation playback or decode clips.
class ProfilePortrait extends StatefulWidget {
  const ProfilePortrait({
    super.key,
    required this.configuration,
    this.size = 56,
  });
  final CompanionConfiguration? configuration;
  final double size;
  @override
  State<ProfilePortrait> createState() => _ProfilePortraitState();
}

class _ProfilePortraitState extends State<ProfilePortrait> {
  Future<FoalAssets> _load() async {
    final art = await FoalAssets.load();
    final head =
        companionReward(
          widget.configuration?[RewardCategory.accessory],
        )?.geometry ??
        'none';
    await art.ensurePoster('$head-none');
    return art;
  }

  late Future<FoalAssets> _art = _load();
  @override
  void didUpdateWidget(ProfilePortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration != widget.configuration) _art = _load();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: ClipOval(
        child: ColoredBox(
          color: GardenColors.of(context).portrait,
          child: FutureBuilder<FoalAssets>(
            future: _art,
            initialData: FoalAssets.ready,
            builder: (context, snapshot) {
              final configuration = widget.configuration;
              if (!snapshot.hasData || configuration == null) {
                return const Icon(Icons.person_outline_rounded);
              }
              // Headwear and mane define this portrait; wings sit outside its framing.
              final head = CompanionConfiguration({
                for (final category in [
                  RewardCategory.mane,
                  RewardCategory.accessory,
                ])
                  if (configuration[category] != null)
                    category: configuration[category]!,
              });
              return Padding(
                padding: EdgeInsets.all(widget.size * .1),
                child: CustomPaint(
                  painter: CompanionPainter(
                    head,
                    assets: snapshot.data,
                    framing: CompanionFraming.head,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
