import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/companion/foal_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real outfit masks tint four materials without changing coat or alpha',
    () async {
      const source = String.fromEnvironment(
        'FOAL_MATERIAL_SOURCE',
        defaultValue: 'assets/companion/foal_3d/flower-feather-poster.webp',
      );
      final codec = await ui.instantiateImageCodec(
        await File(source).readAsBytes(),
        targetWidth: 1024,
      );
      final frame = (await codec.getNextFrame()).image;
      codec.dispose();
      final assets = FoalAssets(
        {
          'palette': jsonDecode(
            File('art/foal/reward_palette.json').readAsStringSync(),
          ),
        },
        {},
        await ui.FragmentProgram.fromAsset('shaders/companion_hair.frag'),
      );
      Future<ui.Image> render(CompanionConfiguration config) async {
        final recorder = ui.PictureRecorder();
        FoalRenderer(
          assets,
          config,
          assets.paletteColor(config[RewardCategory.mane] ?? 'pink'),
        ).draw(Canvas(recorder)..scale(1024 / 1000), frame: frame);
        final picture = recorder.endRecording();
        final image = await picture.toImage(1024, 1024);
        picture.dispose();
        return image;
      }

      ui.Image? original, tinted;
      try {
        expect(frame.width, 1024);
        expect(frame.height, 5120);
        original = await render(
          CompanionConfiguration({
            RewardCategory.accessory: 'flower',
            RewardCategory.wings: 'feather',
          }),
        );
        tinted = await render(
          CompanionConfiguration({
            RewardCategory.mane: 'coral',
            RewardCategory.polish: 'polish_gold',
            RewardCategory.accessory: 'flower_lavender',
            RewardCategory.wings: 'feather_mint',
          }),
        );
        final packed = (await frame.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final before = (await original.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final after = (await tinted.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        const pixels = 1024 * 1024;
        var coatPixels = 0, changedCoat = 0, changedAlpha = 0;
        final changedMaterials = [0, 0, 0, 0];
        for (var p = 0; p < pixels; p++) {
          final at = p * 4;
          if (before[at + 3] != after[at + 3]) changedAlpha++;
          if (before[at + 3] <= 200) continue;
          var delta = 0;
          for (var channel = 0; channel < 3; channel++) {
            final difference = (before[at + channel] - after[at + channel])
                .abs();
            if (difference > delta) delta = difference;
          }
          var outsideMasks = true;
          for (var material = 0; material < 4; material++) {
            final mask = packed[((material + 1) * pixels + p) * 4 + 3];
            if (mask != 0) outsideMasks = false;
            if (mask > 200 && delta > 10) changedMaterials[material]++;
          }
          if (outsideMasks) {
            coatPixels++;
            if (delta > 1) changedCoat++;
          }
        }
        expect(coatPixels, greaterThan(10000));
        expect(changedCoat, 0);
        expect(changedAlpha, 0);
        for (final count in changedMaterials) {
          expect(count, greaterThan(20));
        }
        const capture = String.fromEnvironment('FOAL_MATERIAL_CAPTURE');
        if (capture.isNotEmpty) {
          final png = await tinted.toByteData(format: ui.ImageByteFormat.png);
          await File(capture).writeAsBytes(png!.buffer.asUint8List());
        }
      } finally {
        original?.dispose();
        tinted?.dispose();
        frame.dispose();
      }
    },
  );
}
