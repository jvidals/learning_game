// Explicit staged WebP comparison; never changes production assets.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/companion/foal_renderer.dart';

const reviewRoot = String.fromEnvironment('COMPRESSION_REVIEW_ROOT');
const baselineRoot = String.fromEnvironment(
  'COMPRESSION_BASELINE',
  defaultValue:
      'artifacts/companion-compression/baseline/assets/companion/foal_3d',
);
const profiles = String.fromEnvironment('COMPRESSION_PROFILES');
const assetFilter = String.fromEnvironment('COMPRESSION_ASSET_FILTER');
const passes = int.fromEnvironment(
  'COMPRESSION_TIMING_PASSES',
  defaultValue: 4,
);
const outputSuffix = String.fromEnvironment(
  'COMPRESSION_OUTPUT_SUFFIX',
  defaultValue: 'flutter-review',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'compare staged real codecs, material rendering and decode timings',
    () async {
      expect(reviewRoot, isNotEmpty);
      final report =
          jsonDecode(File('$reviewRoot/report.json').readAsStringSync()) as Map;
      final rows = (report['results'] as List).cast<Map>();
      final selected = profiles.split(',').toSet();
      final output = Directory('$reviewRoot/$outputSuffix')
        ..createSync(recursive: true);
      final manifest =
          jsonDecode(File('$baselineRoot/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final assets = FoalAssets(
        manifest,
        {},
        await ui.FragmentProgram.fromAsset('shaders/companion_hair.frag'),
      );
      final font = File(
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/Roboto-Regular.ttf',
      );
      if (await font.exists()) {
        await (FontLoader(
          'Roboto',
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
      final results = <Map<String, dynamic>>[];
      final baselineTimings = <String, Map<String, dynamic>>{};

      Future<Map<String, dynamic>> measure(String path, Map metadata) async {
        final bytes = await File(path).readAsBytes();
        final times = <int>[];
        final rounds = <Map<String, dynamic>>[];
        for (var pass = 0; pass < passes; pass++) {
          final codec = await ui.instantiateImageCodec(bytes);
          expect(codec.frameCount, metadata['decodedFrameCount']);
          final local = <int>[];
          var duration = Duration.zero;
          try {
            for (var i = 0; i < codec.frameCount; i++) {
              final clock = Stopwatch()..start();
              final frame = await codec.getNextFrame();
              local.add(clock.elapsedMicroseconds);
              expect(frame.image.width, 1024);
              expect(frame.image.height, 5120);
              duration += frame.duration;
              frame.image.dispose();
            }
          } finally {
            codec.dispose();
          }
          if ((metadata['decodedFrameCount'] as int) > 1) {
            final first = metadata['firstFrame'] as int;
            final count = metadata['frameCount'] as int;
            expect(
              duration.inMilliseconds,
              ((first + count) * 1000 / 60).round() -
                  (first * 1000 / 60).round(),
            );
          }
          if (pass > 0) {
            times.addAll(local);
            local.sort();
            rounds.add({
              'p95us': local[(local.length * .95).floor()],
              'durationMs': duration.inMilliseconds,
              'decodedFrames': local.length,
            });
          }
        }
        times.sort();
        return {
          'p50us': times[times.length ~/ 2],
          'p95us': times[(times.length * .95).floor()],
          'rounds': rounds,
        };
      }

      Future<ui.Image> frameAt(String path, int index) async {
        final codec = await ui.instantiateImageCodec(
          await File(path).readAsBytes(),
        );
        ui.Image? image;
        try {
          for (var i = 0; i <= index; i++) {
            image?.dispose();
            image = (await codec.getNextFrame()).image;
          }
          return image!;
        } finally {
          codec.dispose();
        }
      }

      void label(Canvas canvas, String text, double x, double y, Color color) {
        final paragraph =
            (ui.ParagraphBuilder(
                    ui.ParagraphStyle(fontSize: 18, fontFamily: 'Roboto'),
                  )
                  ..pushStyle(ui.TextStyle(color: color))
                  ..addText(text))
                .build()
              ..layout(const ui.ParagraphConstraints(width: 500));
        canvas.drawParagraph(paragraph, Offset(x, y));
        paragraph.dispose();
      }

      for (final row in rows) {
        final profile = row['profile'] as String;
        if (!selected.contains(profile)) continue;
        final name = row['asset'] as String;
        if (assetFilter.isNotEmpty && name != assetFilter) continue;
        final candidatePath = '$reviewRoot/$profile/assets/$name';
        final baselinePath = '$baselineRoot/$name';
        final metadata = row['metadata'] as Map;
        final worst = ((row['audit'] as Map)['worst'] as Map)['frame'] as int;
        final sample = worst - (metadata['firstFrame'] as int);
        final parts = name.split('-');
        final outfit = '${parts[0]}-${parts[1]}';
        final action = parts[2];
        final oldSegments =
            (((manifest['outfits'] as Map)[outfit] as Map)[action]
                    as Map)['segments']
                as List;
        final old = oldSegments.cast<Map>().firstWhere(
          (s) => s['asset'] == name,
        );
        baselineTimings[name] ??= await measure(baselinePath, old);
        final candidateTiming = await measure(candidatePath, metadata);
        results.add({
          'asset': name,
          'profile': profile,
          'baseline': baselineTimings[name],
          'candidate': candidateTiming,
        });
        final before = await frameAt(
          baselinePath,
          (old['sampleFrames'] as List)[sample] as int,
        );
        final after = await frameAt(
          candidatePath,
          (metadata['sampleFrames'] as List)[sample] as int,
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        try {
          for (var variant = 0; variant < 4; variant++) {
            final dark = variant.isOdd;
            final tinted = variant >= 2;
            final background = dark ? Colors.black : const Color(0xfffff7fc);
            final config = CompanionConfiguration({
              if (parts[0] != 'none')
                RewardCategory.accessory: tinted && parts[0] == 'flower'
                    ? 'flower_lavender'
                    : tinted && parts[0] == 'bow'
                    ? 'bow_coral'
                    : parts[0],
              if (parts[1] != 'none')
                RewardCategory.wings: tinted && parts[1] == 'feather'
                    ? 'feather_mint'
                    : tinted && parts[1] == 'butterfly'
                    ? 'butterfly_lavender'
                    : parts[1],
              if (tinted) RewardCategory.mane: 'teal',
              if (tinted) RewardCategory.polish: 'polish_gold',
            });
            for (var column = 0; column < 2; column++) {
              canvas.save();
              canvas.translate(column * 512.0, variant * 540.0);
              canvas.drawRect(
                const Rect.fromLTWH(0, 0, 512, 540),
                Paint()..color = background,
              );
              label(
                canvas,
                '${column == 0 ? 'Baseline' : profile} · ${tinted ? 'tinted' : 'original'}',
                8,
                4,
                dark ? Colors.white : Colors.black,
              );
              canvas.translate(0, 28);
              canvas.scale(512 / 1000);
              FoalRenderer(
                assets,
                config,
                assets.paletteColor(tinted ? 'teal' : 'pink'),
              ).draw(canvas, frame: column == 0 ? before : after);
              canvas.restore();
            }
          }
          final picture = recorder.endRecording();
          final image = await picture.toImage(1024, 2160);
          picture.dispose();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/$profile-$name.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        } finally {
          before.dispose();
          after.dispose();
        }
      }
      await File(
        '${output.path}/timings.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      expect(results, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
