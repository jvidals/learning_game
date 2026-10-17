import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'interface_refresh_test.dart' show target, answer;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

Future<void> capture(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  String directory = '051',
}) async {
  if (!const bool.fromEnvironment('CAPTURE_REFRESH')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    const root = String.fromEnvironment('SCREENSHOT_ROOT');
    final folder = root.isEmpty ? 'docs/screenshots/$directory' : root;
    final file = File('$folder/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

// Flutter tests use Ahem when a custom button TextStyle omits a font family.
// Android uses Roboto; specify that same fallback only for rendered captures.
Widget captureApp(MemoryDevice device) =>
    RainbowGardenApp(key: ObjectKey(device), services: device);

Future<void> loadCaptureFonts() async {
  const fontDir = String.fromEnvironment('REFRESH_FONT_DIR');
  if (fontDir.isEmpty) return;
  for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
    final loader = FontLoader(family);
    for (final suffix
        in family != 'MaterialIcons'
            ? ['Regular.ttf', 'Medium.ttf', 'Bold.ttf', 'Black.ttf']
            : ['Regular.otf']) {
      loader.addFont(
        File(
          '$fontDir/${family == 'Ahem' ? 'Roboto' : family}-$suffix',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await loader.load();
  }
}

void main() {
  setUpAll(loadCaptureFonts);
  for (final (name, size) in [
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('home and reward scenarios at $name, text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final boundary = GlobalKey();
        ThemeData? appTheme;
        for (final (xp, count) in [(0, 0), (50, 1), (150, 2), (2700, 12)]) {
          final d = MemoryDevice()..xp = xp;
          await tester.pumpWidget(
            RepaintBoundary(key: boundary, child: captureApp(d)),
          );
          await settle(tester);
          appTheme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
          await tester.ensureVisible(find.text('My unicorn'));
          await tester.pump();
          final label = tester.getRect(find.text('My unicorn'));
          final button = tester.getRect(
            find.ancestor(
              of: find.text('My unicorn'),
              matching: find.byType(OutlinedButton),
            ),
          );
          expect(find.text('Adventure'), findsNothing);
          if (count == 0) {
            expect(find.byIcon(Icons.card_giftcard_rounded), findsNothing);
            expect(label.center.dx, closeTo(button.center.dx, .01));
            expect(label.center.dy, closeTo(button.center.dy, .01));
          } else {
            final icon = tester.getRect(
              find.byIcon(Icons.card_giftcard_rounded),
            );
            final badge = tester.getRect(find.byType(Badge));
            expect(icon.size, const Size(40, 40));
            expect(badge.left - icon.right, greaterThanOrEqualTo(2));
            expect(label.left - badge.right, greaterThanOrEqualTo(12));
            expect(button.contains(badge.topLeft), isTrue);
            expect(button.contains(badge.bottomRight), isTrue);
          }
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            boundary,
            'home-$count-$name-${scale.toInt()}x',
          );
          await tapVisible(tester, find.text('My unicorn'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
        for (final gifts in [true, false]) {
          final device = MemoryDevice()
            ..soundOn = false
            ..document = PlayerProgress(
              xp: gifts ? 0 : xpForLevel(rewardCatalog.length + 1),
              earnedRewardChoices: gifts ? 0 : rewardCatalog.length,
              lastRewardedRound: gifts ? null : 'fixture',
              owned: gifts ? {} : rewardCatalog.map((r) => r.id).toSet(),
            ).encode();
          final controller = ProgressController(device);
          await controller.load();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: appTheme,
                home: GamePage(
                  services: device,
                  activity: Activity.numbers,
                  sound: false,
                  controller: controller,
                  onCompleteRound: controller.completeRound,
                ),
              ),
            ),
          );
          await settle(tester);
          for (var i = 0; i < 5; i++) {
            await tapVisible(tester, find.text('Show a hint'));
            await tapVisible(tester, answer(target(tester)));
            await tapVisible(tester, find.text(i == 4 ? 'Rewards' : 'Next'));
          }
          expect(
            find.text('Choose a reward'),
            gifts ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            boundary,
            'reward-${gifts ? 'gift' : 'collected'}-$name-${scale.toInt()}x',
          );
          await tester.ensureVisible(find.text('Back to game'));
          await tester.pump();
          expect(find.text('Adventure'), findsNothing);
          await tester.ensureVisible(find.text('Back to home'));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      });
    }
  }
}
