import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../progress.dart';
import 'foal_assets.dart';

/// Equipment geometry is attached and occluded in each source frame.
class FoalRenderer {
  FoalRenderer(this.assets, this.configuration, this.tint);
  final FoalAssets assets;
  final CompanionConfiguration configuration;
  final Color tint;
  static String outfit(CompanionConfiguration configuration) =>
      '${companionReward(configuration[RewardCategory.accessory])?.geometry ?? 'none'}-${companionReward(configuration[RewardCategory.wings])?.geometry ?? 'none'}';

  void draw(Canvas canvas, {ui.Image? frame}) {
    final image = frame ?? assets.poster(outfit(configuration));
    final shader = assets.hair.fragmentShader();
    final floats = <double>[
      0,
      0,
      1000,
      1000,
      tint.r,
      tint.g,
      tint.b,
      configuration[RewardCategory.mane] == null ? 0 : 1,
      for (final category in [
        RewardCategory.polish,
        RewardCategory.accessory,
        RewardCategory.wings,
      ])
        ..._tint(category),
    ];
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(i, floats[i]);
    }
    shader.setImageSampler(0, image);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1000, 1000),
      Paint()..shader = shader,
    );
    shader.dispose();
  }

  List<double> _tint(RewardCategory category) {
    final id = companionReward(configuration[category])?.tint;
    final color = id == null ? Colors.white : assets.paletteColor(id);
    return [color.r, color.g, color.b, id == null ? 0 : 1];
  }
}
