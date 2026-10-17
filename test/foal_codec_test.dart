import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'packed WebP keeps color and four material coverage planes separate',
    (tester) async {
      await tester.runAsync(() async {
        final bytes = await File(
          'assets/companion/foal_3d/star-feather-bowing-000.webp',
        ).readAsBytes();
        for (final width in [512, 1024]) {
          final codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: width,
          );
          final timings = <int>[];
          var duration = Duration.zero;
          try {
            for (var i = 0; i < codec.frameCount; i++) {
              final watch = Stopwatch()..start();
              final frame = await codec.getNextFrame();
              timings.add(watch.elapsedMicroseconds);
              duration += frame.duration;
              try {
                expect(frame.image.width, 1024);
                expect(frame.image.height, 5120);
                if (i == 0) {
                  final rgba = (await frame.image.toByteData(
                    format: ui.ImageByteFormat.rawRgba,
                  ))!.buffer.asUint8List();
                  final pixels = frame.image.width * frame.image.width;
                  var coat = 0, hair = 0;
                  for (var p = 0; p < pixels; p++) {
                    if (rgba[p * 4 + 3] > 200) coat++;
                    if (rgba[(pixels + p) * 4 + 3] > 200) hair++;
                  }
                  expect(coat, greaterThan(pixels * .05));
                  expect(hair, greaterThan(pixels * .01));
                  expect(hair, lessThan(coat));
                  var hooves = 0;
                  for (var p = 0; p < pixels; p++) {
                    if (rgba[(pixels * 2 + p) * 4 + 3] > 200) hooves++;
                  }
                  expect(hooves, greaterThan(0));
                  expect(hooves, lessThan(coat));
                }
              } finally {
                frame.image.dispose();
              }
            }
            expect(duration.inMilliseconds, 250);
            timings.sort();
            // Diagnostic timing is not a physical Android performance claim.
            debugPrint(
              'FOAL_CODEC width=$width frames=${timings.length} p95us=${timings[(timings.length * .95).floor()]}',
            );
          } finally {
            codec.dispose();
          }
        }
      });
    },
  );
}
