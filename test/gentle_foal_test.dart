import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/companion/foal_clip.dart';
import 'package:rainbow_garden/companion/foal_playback.dart';
import 'package:rainbow_garden/companion/foal_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await FoalAssets.load();
  });
  CompanionPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<CompanionPainter>()
      .first;
  testWidgets('pet taps react once for 550ms and celebrations end at 1400ms', (
    tester,
  ) async {
    var pets = 0;
    Widget app({int trigger = 0}) => MaterialApp(
      home: CompanionView(
        configuration: CompanionConfiguration(),
        animate: false,
        reactionTrigger: trigger,
        onPet: () => pets++,
      ),
    );
    await tester.pumpWidget(app());
    await tester.tap(find.byType(CompanionView));
    await tester.pump();
    await tester.tap(find.byType(CompanionView));
    await tester.pump(const Duration(milliseconds: 549));
    expect(pets, 1);
    expect(painter(tester).happy, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(painter(tester).happy, isFalse);
    await tester.pumpWidget(app(trigger: 1));
    await tester.pump(const Duration(milliseconds: 1399));
    expect(painter(tester).celebrating, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(painter(tester).celebrating, isFalse);
    await tester.pumpWidget(app(trigger: 1));
    expect(painter(tester).celebrating, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('bow and twirl remain active for the full two seconds', (
    tester,
  ) async {
    for (final behavior in ['bowing', 'twirl']) {
      await tester.pumpWidget(
        MaterialApp(
          home: CompanionView(
            key: ValueKey(behavior),
            configuration: CompanionConfiguration({
              RewardCategory.behavior: behavior,
            }),
            animate: false,
            reactionTrigger: 1,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(painter(tester).celebrating, isTrue);
      await tester.pump(const Duration(milliseconds: 499));
      expect(painter(tester).celebrating, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(painter(tester).celebrating, isFalse);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('changing behavior cannot reuse an earlier reaction duration', (
    tester,
  ) async {
    Widget app(String behavior, int trigger) => MaterialApp(
      home: CompanionView(
        configuration: CompanionConfiguration({
          RewardCategory.behavior: behavior,
        }),
        reactionTrigger: trigger,
        animate: false,
      ),
    );
    await tester.pumpWidget(app('twirl', 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(app('hop', 1));
    expect(painter(tester).celebrating, isFalse);
    await tester.pumpWidget(app('hop', 2));
    await tester.pump(const Duration(milliseconds: 1399));
    expect(painter(tester).celebrating, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(painter(tester).celebrating, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'hidden and backgrounded reactions cancel without replay; reduced motion is static',
    (tester) async {
      Widget app(bool visible, {bool reduced = false, int trigger = 1}) =>
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                enabled: visible,
                child: CompanionView(
                  configuration: CompanionConfiguration({
                    RewardCategory.behavior: 'twirl',
                  }),
                  reactionTrigger: trigger,
                ),
              ),
            ),
          );
      await tester.pumpWidget(app(true));
      await tester.pump(const Duration(milliseconds: 250));
      expect(painter(tester).celebrating, isTrue);
      await tester.pumpWidget(app(false));
      expect(painter(tester).celebrating, isFalse);
      await tester.pumpWidget(app(true));
      expect(painter(tester).celebrating, isFalse);
      await tester.pumpWidget(app(true, trigger: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(painter(tester).celebrating, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(painter(tester).celebrating, isFalse);
      await tester.pumpWidget(app(true, reduced: true, trigger: 3));
      await tester.pump(const Duration(milliseconds: 300));
      expect(painter(tester).reduced, isTrue);
      expect(painter(tester).response, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('idle resumes after feedback and stays paused when hidden', (
    tester,
  ) async {
    Widget app({
      bool visible = true,
      bool reduced = false,
      bool animate = true,
    }) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
          enabled: visible,
          child: CompanionView(
            configuration: CompanionConfiguration(),
            animate: animate,
            onPet: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 2));
    final phase = painter(tester).phase;
    expect(phase, greaterThan(0));
    await tester.tap(find.byType(CompanionView));
    await tester.pump(const Duration(milliseconds: 200));
    expect(painter(tester).happy, isTrue);
    await tester.pump(const Duration(milliseconds: 350));
    expect(painter(tester).happy, isFalse);
    expect(painter(tester).phase, greaterThan(phase));
    await tester.pumpWidget(app(visible: false));
    final paused = painter(tester).phase;
    await tester.pump(const Duration(seconds: 2));
    expect(painter(tester).phase, paused);
    await tester.pumpWidget(app(reduced: true));
    final reducedPhase = painter(tester).phase;
    await tester.pump(const Duration(seconds: 2));
    expect(painter(tester).phase, reducedPhase);
    await tester.pumpWidget(app(animate: false));
    await tester.pump(const Duration(seconds: 9));
    expect(painter(tester).phase, 0);
    expect(painter(tester).happy, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'asset failure can retry and concurrent loads share a single request',
    (tester) async {
      await tester.runAsync(() async {
        final assets = await FoalAssets.load();
        var attempts = 0;
        final cache = FoalAssetCache(() async {
          if (++attempts == 1) throw StateError('fixture missing image');
          return assets;
        });
        final first = cache.load();
        expect(identical(first, cache.load()), isTrue);
        await expectLater(first, throwsStateError);
        expect(cache.ready, isNull);
        expect(await cache.load(), same(assets));
        expect(await cache.load(), same(assets));
        expect(attempts, 2);
      });
    },
  );

  test(
    'clip timing preserves learning feedback and gives bow/twirl two seconds',
    () {
      expect(foalReactionDuration(happy: true).inMilliseconds, 550);
      for (final behavior in [null, 'hop', 'bowing', 'twirl']) {
        expect(
          foalReactionDuration(behavior: behavior).inMilliseconds,
          behavior == 'bowing' || behavior == 'twirl' ? 2000 : 1400,
        );
        final reduced = FoalClipSample.evaluate(
          reaction: .5,
          celebrating: true,
          behavior: behavior,
          reduced: true,
        );
        expect(reduced.clip, 'idle');
        expect(reduced.frame, 0);
      }
      expect(FoalClipSample.evaluate(reduced: true, happy: true).clip, 'happy');
      expect(FoalClipSample.evaluate(idle: 1).frame, 0);
      expect(
        FoalClipSample.evaluate(
          reaction: 1,
          celebrating: true,
          behavior: 'twirl',
        ).frame,
        119,
      );
    },
  );

  testWidgets(
    'all twenty-five fitted posters have genuine transparent backgrounds',
    (tester) async {
      await tester.runAsync(() async {
        final art = await FoalAssets.load();
        expect(art.posters.length, greaterThanOrEqualTo(25));
        expect(art.decodedBytes, lessThanOrEqualTo(FoalAssets.memoryLimit));
        for (final entry in art.posters.entries.where(
          (e) => !e.key.startsWith('__'),
        )) {
          final image = entry.value;
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final count = image.width * image.width;
          var clear = 0, coat = 0, hair = 0;
          for (var p = 0; p < count; p++) {
            if (pixels[p * 4 + 3] == 0) clear++;
            if (pixels[p * 4 + 3] > 240) coat++;
            if (pixels[(count + p) * 4 + 3] > 240) hair++;
          }
          expect(clear, greaterThan(count * .35), reason: entry.key);
          expect(coat, greaterThan(count * .05), reason: entry.key);
          expect(hair, greaterThan(0), reason: entry.key);
          expect(hair, lessThan(coat), reason: entry.key);
        }
      });
    },
  );

  test(
    'manifest rejects missing outfits, broken timing and invalid segments',
    () {
      final original = FoalAssets.ready!.manifest;
      Map<String, dynamic> copy() =>
          jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      var bad = copy();
      (bad['outfits'] as Map).remove('none-none');
      expect(() => FoalAssets.validateManifest(bad), throwsFormatException);
      bad = copy();
      bad['clips']['bowing']['durationMs'] = 1400;
      expect(() => FoalAssets.validateManifest(bad), throwsFormatException);
      bad = copy();
      bad['outfits']['none-none']['idle']['segments'][0]['firstFrame'] = 1;
      expect(() => FoalAssets.validateManifest(bad), throwsFormatException);
      bad = copy();
      bad['outfits']['none-none']['idle']['segments'][0]['sampleFrames'] = [0];
      expect(() => FoalAssets.validateManifest(bad), throwsFormatException);
      bad = copy();
      bad['outfits']['none-none']['idle']['segments'][0]['decodedFrameCount'] =
          99;
      expect(() => FoalAssets.validateManifest(bad), throwsFormatException);
    },
  );

  testWidgets(
    'playback releases frames after cancellation and rejects stale outfits',
    (tester) async {
      await tester.runAsync(() async {
        final assets = await FoalAssets.load();
        final baseline = assets.decodedBytes;
        final player = FoalPlayback(assets);
        player.request('star-feather', const FoalClipSample('bowing', 20));
        await player.pending;
        expect(player.error, isNull);
        expect(player.imageFor('star-feather'), isNotNull);
        expect(player.imageFor('bow-butterfly'), isNull);
        expect(assets.decodedBytes, lessThanOrEqualTo(FoalAssets.memoryLimit));
        player.request('bow-butterfly', const FoalClipSample('twirl', 60));
        player.cancel();
        // Replacement work can arrive before the cancelled decode completes.
        player.request('none-none', const FoalClipSample('idle', 0));
        await player.pending;
        expect(player.imageFor('none-none'), isNotNull);
        expect(player.imageFor('bow-butterfly'), isNull);
        player.cancel();
        await player.pending;
        expect(player.image, isNull);
        expect(assets.decodedBytes, baseline);
        player.request('none-none', const FoalClipSample('idle', 0));
        await player.pending;
        expect(player.imageFor('none-none'), isNotNull);
        player.dispose();
        expect(assets.decodedBytes, baseline);
      });
    },
  );

  testWidgets(
    'rapid frame changes and repeated outfits keep the image budget bounded',
    (tester) async {
      await tester.runAsync(() async {
        final assets = await FoalAssets.load();
        final baseline = assets.decodedBytes;
        final player = FoalPlayback(assets);
        for (var pass = 0; pass < 2; pass++) {
          for (final outfit in ['none-none', 'star-feather', 'bow-butterfly']) {
            for (final frame in [0, 10, 14, 15, 31, 60, 119]) {
              player.request(
                outfit,
                FoalClipSample('twirl', frame),
                width: 1024,
              );
              await player.pending;
              expect(player.error, isNull);
              expect(player.imageFor(outfit), isNotNull);
              expect(
                assets.decodedBytes,
                lessThanOrEqualTo(FoalAssets.memoryLimit),
              );
            }
          }
        }
        player.dispose();
        expect(assets.decodedBytes, baseline);
      });
    },
  );

  testWidgets(
    'mane recoloring changes hair but leaves coat and fitted equipment alone',
    (tester) async {
      await tester.runAsync(() async {
        final assets = await FoalAssets.load();
        final poster = assets.posters['star-feather']!;
        final packed = (await poster.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        Future<List<int>> render(String? mane) async {
          final configuration = CompanionConfiguration({
            RewardCategory.accessory: 'star',
            RewardCategory.wings: 'feather',
            RewardCategory.mane: ?mane,
          });
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(poster.width / 1000);
          FoalRenderer(assets, configuration, maneColor(mane)).draw(canvas);
          final picture = recorder.endRecording();
          final image = await picture.toImage(poster.width, poster.width);
          picture.dispose();
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          image.dispose();
          return rgba;
        }

        final pink = await render(null), blue = await render('blue');
        final count = poster.width * poster.width;
        var unchanged = 0, changedHair = 0;
        for (var p = 0; p < count; p++) {
          final offset = p * 4;
          if (packed[offset + 3] < 250) continue;
          final mask = packed[(count + p) * 4 + 3];
          if (mask == 0) {
            expect(
              blue.sublist(offset, offset + 4),
              pink.sublist(offset, offset + 4),
            );
            unchanged++;
          } else if (mask > 250 && blue[offset] != pink[offset]) {
            changedHair++;
          }
        }
        expect(unchanged, greaterThan(2000));
        expect(changedHair, greaterThan(300));
      });
    },
  );

  testWidgets(
    'celebration cards use distinct static poses without animation decoding',
    (tester) async {
      await tester.runAsync(() async {
        final assets = await FoalAssets.load();
        expect(assets.posters['__items']!.height, 2048);
        final baseline = assets.decodedBytes;
        final pictures = <List<int>>[];
        for (final behavior in <String?>[null, 'hop', 'bowing', 'twirl']) {
          final recorder = ui.PictureRecorder();
          CompanionItemPainter(
            RewardCategory.behavior,
            behavior,
            assets: assets,
          ).paint(Canvas(recorder), const Size(128, 128));
          final picture = recorder.endRecording();
          final image = await picture.toImage(128, 128);
          pictures.add(
            (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List(),
          );
          image.dispose();
          picture.dispose();
        }
        for (var i = 0; i < pictures.length; i++) {
          for (var j = i + 1; j < pictures.length; j++) {
            expect(pictures[i], isNot(equals(pictures[j])));
          }
        }
        expect(assets.decodedBytes, baseline);
      });
    },
  );

  testWidgets(
    'all reward geometry and tint variants render through the shared painter',
    (tester) async {
      await tester.runAsync(() async {
        final assets = await FoalAssets.load();
        for (final color in [
          null,
          ...rewardCatalog
              .where((r) => r.category == RewardCategory.mane)
              .map((r) => r.id),
        ]) {
          for (final head in [
            null,
            ...rewardCatalog
                .where((r) => r.category == RewardCategory.accessory)
                .map((r) => r.id),
          ]) {
            for (final wings in [
              null,
              ...rewardCatalog
                  .where((r) => r.category == RewardCategory.wings)
                  .map((r) => r.id),
            ]) {
              final configuration = CompanionConfiguration({
                RewardCategory.mane: ?color,
                RewardCategory.accessory: ?head,
                RewardCategory.wings: ?wings,
                RewardCategory.polish: "polish_${color ?? 'pink'}",
              });
              final recorder = ui.PictureRecorder();
              CompanionPainter(
                configuration,
                assets: assets,
              ).paint(Canvas(recorder), const Size(160, 160));
              final picture = recorder.endRecording();
              final image = await picture.toImage(160, 160);
              image.dispose();
              picture.dispose();
              expect(
                assets.posters.containsKey(FoalRenderer.outfit(configuration)),
                isTrue,
              );
            }
          }
        }
      });
    },
  );
}
