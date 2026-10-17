import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/companion/foal_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('expanded focus reveals art only inside the viewport', () async {
    final assets = FoalAssets(
      {
        'framing': {
          'head': [250, 250, 500, 500],
          'wings': [250, 250, 500, 500],
        },
      },
      {},
      await ui.FragmentProgram.fromAsset('shaders/companion_hair.frag'),
    );
    // An opaque color plane makes both the old crop and any viewport leak
    // observable independently of a particular unicorn outfit or animation.
    final input = ui.PictureRecorder();
    Canvas(
      input,
    ).drawRect(const Rect.fromLTWH(0, 0, 32, 32), Paint()..color = Colors.red);
    final inputPicture = input.endRecording();
    final packed = await inputPicture.toImage(32, 160);
    inputPicture.dispose();
    addTearDown(packed.dispose);
    for (final framing in [CompanionFraming.head, CompanionFraming.wings]) {
      for (final size in [const Size(200, 100), const Size(100, 200)]) {
        for (final expanded in [false, true]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..translate(30, 30);
          final configuration = CompanionConfiguration({});
          final painter = expanded
              ? CompanionPainter(
                  configuration,
                  assets: assets,
                  frame: packed,
                  framing: framing,
                  clipToFraming: false,
                )
              : CompanionPainter(
                  configuration,
                  assets: assets,
                  frame: packed,
                  framing: framing,
                );
          painter.paint(canvas, size);
          final picture = recorder.endRecording();
          final width = size.width.toInt() + 60;
          final image = await picture.toImage(width, size.height.toInt() + 60);
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          int alpha(int x, int y) => rgba[(y * width + x) * 4 + 3];
          final cx = 30 + size.width ~/ 2, cy = 30 + size.height ~/ 2;
          expect(alpha(cx, cy), 255);
          // Inside the viewport, outside the smaller centered focus crop.
          expect(
            size.width > size.height ? alpha(35, cy) : alpha(cx, 35),
            expanded ? 255 : 0,
          );
          expect(alpha(29, cy), 0);
          expect(alpha(30 + size.width.toInt(), cy), 0);
          expect(alpha(cx, 29), 0);
          expect(alpha(cx, 30 + size.height.toInt()), 0);
          image.dispose();
          picture.dispose();
        }
      }
    }
  });

  test('transparent hair edges receive the same tint as opaque hair', () async {
    final assets = FoalAssets(
      {},
      {},
      await ui.FragmentProgram.fromAsset('shaders/companion_hair.frag'),
    );
    Future<List<int>> render(int alpha) async {
      final input = ui.PictureRecorder();
      final inputCanvas = Canvas(input);
      inputCanvas.drawRect(
        const Rect.fromLTWH(0, 0, 32, 32),
        Paint()..color = Color.fromARGB(alpha, 200, 132, 166),
      );
      inputCanvas.drawRect(
        const Rect.fromLTWH(0, 32, 32, 32),
        Paint()..color = Color.fromARGB(alpha, 0, 0, 0),
      );
      final inputPicture = input.endRecording();
      final packed = await inputPicture.toImage(32, 160);
      inputPicture.dispose();
      final output = ui.PictureRecorder();
      final canvas = Canvas(output)..scale(32 / 1000);
      FoalRenderer(
        assets,
        CompanionConfiguration({RewardCategory.mane: 'blue'}),
        Colors.blue,
      ).draw(canvas, frame: packed);
      final picture = output.endRecording();
      final image = await picture.toImage(32, 32);
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final pixel = rgba.sublist((16 * 32 + 16) * 4, (16 * 32 + 16) * 4 + 4);
      image.dispose();
      picture.dispose();
      packed.dispose();
      return pixel;
    }

    final opaque = await render(255), edge = await render(128);
    expect(opaque[3], 255);
    expect(edge[3], 128);
    for (var channel = 0; channel < 3; channel++) {
      expect(edge[channel], closeTo(opaque[channel] * 128 / 255, 2));
    }
  });
  test('each material tint changes only its own visible coverage', () async {
    final palette = jsonDecode(
      File('art/foal/reward_palette.json').readAsStringSync(),
    );
    final assets = FoalAssets(
      {'palette': palette},
      {},
      await ui.FragmentProgram.fromAsset('shaders/companion_hair.frag'),
    );
    Future<List<int>> render(
      Map<RewardCategory, String> equipment, {
      int alpha = 255,
    }) async {
      final input = ui.PictureRecorder();
      final c = Canvas(input);
      c.drawRect(
        const Rect.fromLTWH(0, 0, 40, 40),
        Paint()..color = Color.fromARGB(alpha, 160, 120, 180),
      );
      for (var plane = 1; plane <= 4; plane++) {
        c.drawRect(
          Rect.fromLTWH(plane * 8.0, plane * 40.0, 8, 40),
          Paint()..color = Color.fromARGB(alpha, 0, 0, 0),
        );
      }
      final inputPicture = input.endRecording();
      final packed = await inputPicture.toImage(40, 200);
      inputPicture.dispose();
      final output = ui.PictureRecorder();
      FoalRenderer(
        assets,
        CompanionConfiguration(equipment),
        const Color(0xFF80BBDD),
      ).draw(Canvas(output)..scale(40 / 1000), frame: packed);
      final picture = output.endRecording();
      final result = await picture.toImage(40, 40);
      final rgba = (await result.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      result.dispose();
      picture.dispose();
      packed.dispose();
      return rgba;
    }

    List<int> pixel(List<int> rgba, int region) {
      final offset = (20 * 40 + region * 8 + 4) * 4;
      return rgba.sublist(offset, offset + 4);
    }

    final equipment = {
      RewardCategory.mane: 'blue',
      RewardCategory.polish: 'polish_pink',
      RewardCategory.accessory: 'flower_lavender',
      RewardCategory.wings: 'feather_mint',
    };
    final original = await render({});
    final combined = await render(equipment);
    var region = 1;
    for (final entry in equipment.entries) {
      final individual = await render({entry.key: entry.value});
      for (var area = 0; area < 5; area++) {
        expect(
          pixel(individual, area),
          area == region
              ? isNot(equals(pixel(original, area)))
              : equals(pixel(original, area)),
        );
      }
      expect(pixel(combined, region), pixel(individual, region));
      region++;
    }
    expect(pixel(combined, 0), pixel(original, 0));
    final edge = await render(equipment, alpha: 128);
    for (var area = 0; area < 5; area++) {
      final opaquePixel = pixel(combined, area), edgePixel = pixel(edge, area);
      expect(edgePixel[3], 128);
      for (var channel = 0; channel < 3; channel++) {
        expect(
          edgePixel[channel],
          closeTo(opaquePixel[channel] * 128 / 255, 2),
        );
      }
    }
  });
}
