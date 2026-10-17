// Explicit check of one completed staged segment, before the full export ends.
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
    'the real codec and shader support all five full-resolution planes',
    () async {
      final data = await File(
        'artifacts/rewards-0140/pilot-segment.webp',
      ).readAsBytes();
      final codec = await ui.instantiateImageCodec(data, targetWidth: 512);
      try {
        final frame = await codec.getNextFrame();
        try {
          expect(frame.image.width, 1024);
          expect(frame.image.height, 5120);
          final pixels = (await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          const plane = 1024 * 1024;
          var hair = 0, hoof = 0;
          for (var p = 0; p < plane; p++) {
            if (pixels[(plane + p) * 4 + 3] > 200) hair++;
            if (pixels[(plane * 2 + p) * 4 + 3] > 200) hoof++;
          }
          expect(hair, greaterThan(1000));
          expect(hoof, greaterThan(1000));
          final assets = FoalAssets(
            {
              'palette': jsonDecode(
                File('art/foal/reward_palette.json').readAsStringSync(),
              ),
            },
            {},
            await ui.FragmentProgram.fromAsset('shaders/companion_hair.frag'),
          );
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)
            ..drawColor(const Color(0xFFF3EDF8), BlendMode.src)
            ..scale(512 / 1000);
          FoalRenderer(
            assets,
            CompanionConfiguration({
              RewardCategory.mane: 'lavender',
              RewardCategory.polish: 'polish_teal',
            }),
            assets.paletteColor('lavender'),
          ).draw(canvas, frame: frame.image);
          final picture = recorder.endRecording();
          final image = await picture.toImage(512, 512);
          picture.dispose();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'artifacts/rewards-0140/pilot-polish.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    },
  );
}
