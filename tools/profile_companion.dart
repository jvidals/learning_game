// Optional local performance entrypoint; never used by the normal APK build.
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:rainbow_garden/main.dart' as game;
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'companion_compression_scenario.dart';

const compressionScenario = bool.fromEnvironment('FOAL_COMPRESSION_SCENARIO');

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  var warmup = 120;
  final build = <int>[], raster = <int>[], total = <int>[];
  final vsync = <int>[];
  var peakDecodedBytes = 0;
  binding.addTimingsCallback((frames) {
    final decoded = FoalAssets.ready?.decodedBytes ?? 0;
    if (decoded > peakDecodedBytes) peakDecodedBytes = decoded;
    for (final frame in frames) {
      if (warmup > 0) {
        warmup--;
        continue;
      }
      build.add(frame.buildDuration.inMicroseconds);
      raster.add(frame.rasterDuration.inMicroseconds);
      total.add(frame.totalSpan.inMicroseconds);
      vsync.add(frame.timestampInMicroseconds(ui.FramePhase.vsyncStart));
    }
    if (build.length < 180) return;
    Map<String, double> summary(List<int> values) {
      values.sort();
      return {
        'p50ms': values[values.length ~/ 2] / 1000,
        'p95ms': values[(values.length * .95).floor()] / 1000,
        'maxms': values.last / 1000,
      };
    }

    debugPrint(
      'FOAL_TIMING ${jsonEncode({
        if (compressionScenario) 'scenario': compressionStage,
        'frames': build.length,
        'engineFps': (vsync.length - 1) * 1000000 / (vsync.last - vsync.first),
        'frameInterval': summary([for (var i = 1; i < vsync.length; i++) vsync[i] - vsync[i - 1]]),
        'build': summary(build),
        'raster': summary(raster),
        'total': summary(total),
        'decodedBytes': decoded,
        'peakDecodedBytes': peakDecodedBytes,
        'decodedLimit': FoalAssets.memoryLimit,
      })}',
    );
    build.clear();
    raster.clear();
    total.clear();
    vsync.clear();
  });
  if (compressionScenario) {
    runApp(const CompanionCompressionScenario());
  } else {
    game.main();
  }
}
