// Verification only. Asset generation lives in tools/export_foal.py.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';

void main() {
  test('every bundled outfit has complete ordered 60 Hz clips', () {
    final manifest =
        jsonDecode(
              File('${FoalAssets.directory}/manifest.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    FoalAssets.validateManifest(manifest);
    for (final outfit in (manifest['outfits'] as Map).values) {
      for (final clip in (outfit as Map).values) {
        var samples = 0;
        for (final segment in clip['segments'] as List) {
          final mapping = (segment['sampleFrames'] as List).cast<int>();
          expect(mapping.length, segment['frameCount']);
          expect(mapping.first, 0);
          expect(mapping.last, lessThan(segment['decodedFrameCount'] as int));
          for (var i = 1; i < mapping.length; i++) {
            expect(mapping[i], greaterThanOrEqualTo(mapping[i - 1]));
          }
          final file = File('${FoalAssets.directory}/${segment['asset']}');
          expect(file.existsSync(), isTrue);
          expect(file.lengthSync(), greaterThan(0));
          samples += mapping.length;
        }
        expect(samples, clip['frameCount']);
      }
    }
  });

  test(
    'asset checksums and source provenance verify without rewriting files',
    () async {
      final manifest = File('${FoalAssets.directory}/manifest.json');
      final before = manifest.readAsBytesSync();
      final result = await Process.run('python3', [
        'tools/export_foal.py',
        '--verify',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(manifest.readAsBytesSync(), before);
    },
  );
}
