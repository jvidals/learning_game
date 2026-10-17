// Explicit visual review, never run by the normal test-directory suite.
// flutter test tools/foal_review_test.dart --concurrency=1
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/companion/foal_clip.dart';
import 'package:rainbow_garden/companion/foal_playback.dart';

const _reviewRoot = String.fromEnvironment(
  'FOAL_REVIEW_ROOT',
  defaultValue: 'artifacts/foal-review',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'capture all fitted looks and real decoded grounding/action poses',
    () async {
      final assets = await FoalAssets.load();
      final font = File(
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/Roboto-Regular.ttf',
      );
      if (await font.exists()) {
        await (FontLoader(
          'Roboto',
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
      final folder = Directory('$_reviewRoot/rig');
      await folder.create(recursive: true);
      void label(Canvas canvas, String text, double x, double y) {
        final paragraph =
            (ui.ParagraphBuilder(
                    ui.ParagraphStyle(fontFamily: 'Roboto', fontSize: 13),
                  )
                  ..pushStyle(ui.TextStyle(color: const Color(0xff443854)))
                  ..addText(text))
                .build()
              ..layout(const ui.ParagraphConstraints(width: 252));
        canvas.drawParagraph(paragraph, Offset(x, y));
        paragraph.dispose();
      }

      Future<void> save(
        ui.PictureRecorder recorder,
        String path,
        int width,
        int height,
      ) async {
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        picture.dispose();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }

      final gallery = ui.PictureRecorder();
      final canvas = Canvas(gallery)
        ..drawColor(const Color(0xfffff7fc), BlendMode.src);
      var index = 0;
      for (final outfit
          in (assets.manifest['outfits'] as Map).keys.cast<String>()) {
        final parts = outfit.split('-');
        await assets.ensurePoster(outfit);
        for (final color in <String?>[
          null,
          'blue',
          'mint',
          'gold',
          'lavender',
          'coral',
          'teal',
        ]) {
          final configuration = CompanionConfiguration({
            if (parts[0] != 'none') RewardCategory.accessory: parts[0],
            if (parts[1] != 'none') RewardCategory.wings: parts[1],
            RewardCategory.mane: ?color,
            RewardCategory.polish: "polish_${color ?? 'pink'}",
          });
          final x = (index % 8) * 256.0, y = (index ~/ 8) * 280.0;
          canvas.save();
          canvas.translate(x, y);
          CompanionPainter(
            configuration,
            assets: assets,
          ).paint(canvas, const Size(256, 256));
          label(canvas, '$outfit · ${color ?? 'pink'}', 4, 257);
          canvas.restore();
          index++;
        }
        final player = FoalPlayback(assets);
        final poses = ui.PictureRecorder();
        final poseCanvas = Canvas(poses)
          ..drawColor(const Color(0xfffff7fc), BlendMode.src);
        final configuration = CompanionConfiguration({
          if (parts[0] != 'none')
            RewardCategory.accessory: switch (parts[0]) {
              'flower' => 'flower_lavender',
              'bow' => 'bow_coral',
              _ => parts[0],
            },
          if (parts[1] != 'none')
            RewardCategory.wings: switch (parts[1]) {
              'feather' => 'feather_mint',
              'butterfly' => 'butterfly_lavender',
              _ => parts[1],
            },
          RewardCategory.mane: 'blue',
          RewardCategory.polish: 'polish_teal',
        });
        const clips = ['idle', 'happy', 'simple', 'hop', 'bowing', 'twirl'];
        for (var row = 0; row < clips.length; row++) {
          final clip = clips[row];
          final lastFrame = (foalDurations[clip]! * 60 / 1000).round() - 1;
          for (var col = 0; col < 5; col++) {
            final frame = (lastFrame * [0, .25, .5, .75, 1][col]).round();
            player.request(outfit, FoalClipSample(clip, frame), width: 1024);
            await player.pending;
            expect(player.error, isNull);
            expect(player.imageFor(outfit), isNotNull);
            poseCanvas.save();
            poseCanvas.translate(col * 256.0, row * 280.0);
            // Flatten each pose before composing the sheet: retaining full
            // 20 MiB frames in a Picture would bypass managed-image accounting.
            final cell = ui.PictureRecorder();
            CompanionPainter(
              configuration,
              assets: assets,
              frame: player.image,
            ).paint(Canvas(cell), const Size(256, 256));
            final cellPicture = cell.endRecording();
            final thumbnail = await cellPicture.toImage(256, 256);
            cellPicture.dispose();
            poseCanvas.drawImage(thumbnail, Offset.zero, Paint());
            thumbnail.dispose();
            label(poseCanvas, '$clip · frame $frame', 4, 257);
            poseCanvas.restore();
          }
        }
        await save(
          poses,
          '${folder.path}/$outfit-poses.png',
          1280,
          clips.length * 280,
        );
        player.dispose();
      }
      await save(
        gallery,
        '${folder.path}/all-175-looks.png',
        2048,
        ((index + 7) ~/ 8) * 280,
      );

      // Include tint-only rewards explicitly: the geometry contact sheet alone
      // cannot establish that petals, bow fabric or wing membranes recolor well.
      final variants = <(String, CompanionConfiguration)>[
        ('Original pink · no polish', CompanionConfiguration()),
        for (final reward in rewardCatalog)
          if (reward.category != RewardCategory.behavior)
            (
              reward.label,
              CompanionConfiguration({reward.category: reward.id}),
            ),
        (
          'Lavender mane · teal polish',
          CompanionConfiguration({
            RewardCategory.mane: 'lavender',
            RewardCategory.polish: 'polish_teal',
            RewardCategory.accessory: 'heart',
            RewardCategory.wings: 'fairy',
          }),
        ),
        (
          'Coral · gold · flower/mint wings',
          CompanionConfiguration({
            RewardCategory.mane: 'coral',
            RewardCategory.polish: 'polish_gold',
            RewardCategory.accessory: 'flower_lavender',
            RewardCategory.wings: 'feather_mint',
          }),
        ),
        (
          'Teal · blue · bow/lavender wings',
          CompanionConfiguration({
            RewardCategory.mane: 'teal',
            RewardCategory.polish: 'polish_blue',
            RewardCategory.accessory: 'bow_coral',
            RewardCategory.wings: 'butterfly_lavender',
          }),
        ),
      ];
      final variantSheet = ui.PictureRecorder();
      final variantCanvas = Canvas(variantSheet)
        ..drawColor(const Color(0xfffff7fc), BlendMode.src);
      for (var i = 0; i < variants.length; i++) {
        final (name, configuration) = variants[i];
        final head =
            companionReward(
              configuration[RewardCategory.accessory],
            )?.geometry ??
            'none';
        final wing =
            companionReward(configuration[RewardCategory.wings])?.geometry ??
            'none';
        await assets.ensurePoster('$head-$wing');
        variantCanvas.save();
        variantCanvas.translate((i % 3) * 256.0, (i ~/ 3) * 300.0);
        CompanionPainter(
          configuration,
          assets: assets,
        ).paint(variantCanvas, const Size(256, 256));
        label(variantCanvas, name, 4, 258);
        variantCanvas.restore();
      }
      await save(
        variantSheet,
        '${folder.path}/reward-variants.png',
        768,
        ((variants.length + 2) ~/ 3) * 300,
      );

      final video = Directory('$_reviewRoot/review-video');
      await video.create(recursive: true);
      final player = FoalPlayback(assets);
      final configuration = CompanionConfiguration({
        RewardCategory.accessory: 'heart',
        RewardCategory.wings: 'fairy',
        RewardCategory.mane: 'lavender',
        RewardCategory.polish: 'polish_teal',
      });
      for (var i = 0; i < 240; i++) {
        player.request(
          'heart-fairy',
          FoalClipSample(i < 120 ? 'bowing' : 'twirl', i % 120),
          width: 1024,
        );
        await player.pending;
        expect(player.error, isNull);
        final recorder = ui.PictureRecorder();
        final frameCanvas = Canvas(recorder)
          ..drawColor(const Color(0xfffff7fc), BlendMode.src);
        CompanionPainter(
          configuration,
          assets: assets,
          frame: player.image,
        ).paint(frameCanvas, const Size(512, 512));
        await save(
          recorder,
          '${video.path}/${i.toString().padLeft(4, '0')}.png',
          512,
          512,
        );
      }
      player.dispose();
      final idleVideo = Directory('$_reviewRoot/idle-video');
      await idleVideo.create(recursive: true);
      final idlePlayer = FoalPlayback(assets);
      for (var i = 0; i < 960; i++) {
        idlePlayer.request('heart-fairy', FoalClipSample('idle', i % 480));
        await idlePlayer.pending;
        expect(idlePlayer.error, isNull);
        expect(assets.decodedBytes, lessThanOrEqualTo(FoalAssets.memoryLimit));
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..drawColor(const Color(0xfffff7fc), BlendMode.src);
        CompanionPainter(
          configuration,
          assets: assets,
          frame: idlePlayer.image,
        ).paint(canvas, const Size(256, 256));
        await save(
          recorder,
          '${idleVideo.path}/${i.toString().padLeft(4, '0')}.png',
          256,
          256,
        );
      }
      idlePlayer.dispose();
      expect(assets.decodedBytes, assets.posterBytes);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
