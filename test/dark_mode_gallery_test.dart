import 'package:rainbow_garden/game.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/game_2048.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/writing.dart';
import 'package:rainbow_garden/widgets/companion_choices.dart';
import 'interface_layout_test.dart' show capture, loadCaptureFonts;
import 'interface_refresh_test.dart' show target, answer;
import 'settings_test.dart' show unlock;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;
import 'writing_widgets_test.dart' show drawSample;

MemoryDevice galleryDevice(AppAppearance appearance) => MemoryDevice()
  ..appearance = appearance
  ..soundOn = false
  ..document = PlayerProgress(
    xp: 650,
    lastRewardedRound: 'gallery',
    game2048: Game2048Progress(
      highScore: 500000,
      session: Game2048State(
        id: 'gallery-2048',
        score: 500000,
        moves: 12000,
        won: true,
        winAcknowledged: true,
        board: [for (var i = 1; i <= 14; i++) 1 << i, 0, 0],
      ),
    ),
    writing: WritingProgress(
      id: 'gallery-alphabet',
      order: List.generate(26, (i) => i),
      index: 0,
      forms: List.filled(26, 0),
    ),
  ).encode();

void main() {
  setUpAll(() async {
    await loadCaptureFonts();
    if (const bool.fromEnvironment('CAPTURE_REFRESH')) {
      final art = await FoalAssets.load();
      await art.ensurePoster('none-none');
    }
  });
  for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
    for (final (name, size) in [
      ('small', const Size(320, 640)),
      ('phone', const Size(393, 852)),
      ('landscape', const Size(740, 360)),
      ('tablet', const Size(800, 1100)),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${appearance.name} complete gallery $name $scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: scale == 2);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final key = GlobalKey(), device = galleryDevice(appearance);
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: RainbowGardenApp(services: device),
            ),
          );
          Future<void> snap(String screen) async {
            // Let enabled/disabled button text reach its final contrast.
            await tester.pump(const Duration(milliseconds: 250));
            if (const bool.fromEnvironment('CAPTURE_REFRESH')) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 150)),
              );
              await tester.pump();
            }
            expect(tester.takeException(), isNull, reason: screen);
            await capture(
              tester,
              key,
              '${appearance.name}-$name-${scale.toInt()}x-$screen',
              directory: '0150',
            );
          }

          Future<void> home() async {
            Navigator.of(
              tester.element(find.byType(Scaffold).last),
            ).popUntil((r) => r.isFirst);
            await settle(tester);
          }

          await settle(tester);
          await snap('home');
          await tapVisible(
            tester,
            find.byKey(const ValueKey('profile-picker')),
          );
          await snap('players');
          await tapVisible(tester, find.byTooltip('Close players'));
          await tapVisible(tester, find.byTooltip('Settings'));
          await snap('parent-gate');
          await tapVisible(tester, find.text('Cancel'));
          await unlock(tester);
          await snap('settings');
          await tapVisible(tester, find.text('Sight Word packs'));
          await tapVisible(tester, find.byType(CheckboxListTile).first);
          await tester.ensureVisible(find.text('Keep at least one pack.'));
          await tester.pump();
          await snap('settings-error');
          await home();

          await tapVisible(tester, find.text('My Unicorn'));
          await snap('unicorn');
          await tester.tap(
            find.descendant(
              of: find.byType(CompanionCategoryTabs),
              matching: find.bySemanticsLabel('Nail polish'),
            ),
          );
          await settle(tester);
          await snap('unicorn-polish');
          await home();
          await tapVisible(tester, find.text('Letters'));
          await snap('letters');
          await tapVisible(tester, find.text(Activity.matching.title));
          await snap('question');
          final correct = target(tester);
          final wrong = find
              .byWidgetPredicate(
                (w) =>
                    w is FilledButton &&
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith('choice-') &&
                    (w.key! as ValueKey<String>).value != 'choice-$correct',
              )
              .first;
          await tester.ensureVisible(wrong);
          await tester.tap(wrong);
          await tester.pump(const Duration(milliseconds: 100));
          await snap('retry');
          for (var i = 0; i < 5; i++) {
            await tapVisible(tester, answer(target(tester)));
            if (i == 0) await snap('correct');
            await tapVisible(tester, find.text(i == 4 ? 'Rewards' : 'Next'));
          }
          await snap('reward');
          await tapVisible(tester, find.text('Back to home'));

          await tapVisible(tester, find.text('Letters'));
          await tapVisible(tester, find.text('Alphabet Order'));
          await snap('ordering');
          await home();
          await tapVisible(tester, find.text('Words'));
          await tapVisible(tester, find.text('Sight Words'));
          await tapVisible(tester, find.text('Show a hint'));
          await snap('words');
          await home();
          await tapVisible(tester, find.text('Numbers'));
          await tapVisible(tester, find.text('2048').first);
          await snap('2048');
          await tapVisible(tester, find.text('Start over'));
          await snap('2048-dialog');
          await tapVisible(tester, find.text('Keep playing'));
          await home();

          await tapVisible(tester, find.text('Writing'));
          await tapVisible(tester, find.text('Handwriting'));
          await snap('writing');
          await drawSample(tester, 'A', kind: ui.PointerDeviceKind.stylus);
          await snap('writing-ink');
          await tapVisible(tester, find.text('Check'));
          await snap('writing-success');
          await tapVisible(tester, find.byTooltip('Choose a letter'));
          await snap('writing-picker');
          await home();

          await tapVisible(tester, find.text('Reflex'));
          await snap('reflex');
          await tapVisible(tester, find.text('Tap Challenge'));
          await tapVisible(tester, find.text('Start'));
          await snap('tap-challenge');
          await tapVisible(tester, find.text('Pause'));
          await snap('tap-challenge-paused');
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
