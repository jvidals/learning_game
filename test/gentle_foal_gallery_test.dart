import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/widgets/companion_choices.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

const _reviewRoot = String.fromEnvironment(
  'FOAL_REVIEW_ROOT',
  defaultValue: 'artifacts/foal-review',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await FoalAssets.load();
    final fonts = Directory(
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
    );
    for (final family in ['Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final suffix
          in family == 'Roboto'
              ? ['Regular.ttf', 'Medium.ttf', 'Bold.ttf']
              : ['Regular.otf']) {
        final file = File('${fonts.path}/$family-$suffix');
        if (await file.exists()) {
          loader.addFont(file.readAsBytes().then(ByteData.sublistView));
        }
      }
      await loader.load();
    }
  });
  for (final (name, size) in [
    ('small-phone', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('gentle foal art at $name and ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(
              disableAnimations: bool.fromEnvironment('FOAL_REVIEW_REDUCED'),
            );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final device = MemoryDevice()
          ..document = PlayerProgress(
            xp: xpForLevel(rewardCatalog.length + 1),
            earnedRewardChoices: rewardCatalog.length,
            lastRewardedRound: 'fixture',
            owned: rewardCatalog.map((r) => r.id).toSet(),
            companion: CompanionConfiguration({
              if (const bool.fromEnvironment('FOAL_REVIEW_REWARDS')) ...{
                RewardCategory.mane: 'lavender',
                RewardCategory.accessory: 'heart',
                RewardCategory.wings: 'fairy',
                RewardCategory.polish: 'polish_teal',
              } else if (const bool.fromEnvironment(
                'FOAL_REVIEW_FLOWER_FEATHER',
              )) ...{
                RewardCategory.accessory: 'flower',
                RewardCategory.wings: 'feather',
              } else if (!const bool.fromEnvironment(
                'FOAL_REVIEW_DEFAULT',
              )) ...{
                RewardCategory.mane: 'blue',
                RewardCategory.accessory: 'bow',
                RewardCategory.wings: 'butterfly',
              },
              RewardCategory.behavior: 'twirl',
            }),
          ).encode();
        final key = GlobalKey();
        Future<void> capture(String screen) async {
          // Fake animation time is held still while real image decoding
          // finishes; capture a decoded frame, not the loading poster.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)),
          );
          for (var attempt = 0; attempt < 50; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
            final painters = tester
                .widgetList<CustomPaint>(find.byType(CustomPaint))
                .map((w) => w.painter)
                .whereType<CompanionPainter>();
            if (painters.every((p) => p.frame != null)) break;
          }
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('$_reviewRoot/$name-${scale}x-$screen.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: RainbowGardenApp(services: device),
          ),
        );
        await settle(tester);
        await capture('garden');
        await tapVisible(tester, find.text('My unicorn'));
        await settle(tester);
        await capture('colors');
        await tester.tap(find.byKey(const ValueKey('customization-preview')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await capture('pet');
        await tester.pump(const Duration(milliseconds: 400));
        for (final label in [
          'Headwear',
          'Wings',
          'Nail polish',
          'Celebrations',
        ]) {
          await tester.tap(
            find.descendant(
              of: find.byType(CompanionCategoryTabs),
              matching: find.bySemanticsLabel(label),
            ),
          );
          await tester.pump();
          // Finish tab-border and framing transitions before freezing capture time.
          await tester.pump(const Duration(milliseconds: 350));
          await capture(label.toLowerCase().replaceAll(' ', '-'));
        }
        await tester.ensureVisible(find.text('Preview celebration'));
        await tester.pump();
        await tester.tap(find.text('Preview celebration'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));
        await capture('twirl');
        expect(find.byType(CompanionView), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
