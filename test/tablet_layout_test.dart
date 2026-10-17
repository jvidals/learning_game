import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/widgets/writing_pad.dart';
import 'interface_layout_test.dart' show capture, captureApp, loadCaptureFonts;
import 'widget_test.dart' show settle, tapVisible;
import 'writing_widgets_test.dart' show seeded, openWriting, drawSample;

final _freehand = find.byKey(const ValueKey('freehand-pad'));
final _trace = find.byKey(const ValueKey('trace-pad'));

Finder _writingScroll() => find
    .ancestor(of: _freehand, matching: find.byType(SingleChildScrollView))
    .first;

void _visibleAction(WidgetTester tester, String key) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
}

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
      ('phone-landscape', const Size(740, 360)),
      ('tablet-small', const Size(600, 960)),
      ('tablet-small-landscape', const Size(960, 600)),
      ('tablet', const Size(800, 1100)),
      ('tablet-landscape', const Size(1100, 800)),
      ('split', const Size(540, 900)),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${appearance.name} tablet layout $name text $scale', (
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
          final device = seeded()..appearance = appearance;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(key: boundary, child: captureApp(device)),
          );
          await settle(tester);
          Future<void> snap(String screen) async {
            await tester.pump(const Duration(milliseconds: 250));
            if (const bool.fromEnvironment('CAPTURE_REFRESH')) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 150)),
              );
              await tester.pump();
            }
            expect(tester.takeException(), isNull);
            await capture(
              tester,
              boundary,
              '${appearance.name}-$name-${scale.toInt()}x-$screen',
              directory: '0160',
            );
          }

          final profile = find.byKey(const ValueKey('profile-picker'));
          final settings = find.byTooltip('Settings');
          final profileRect = tester.getRect(profile);
          final settingsRect = tester.getRect(settings);
          expect(profileRect.left, 20);
          expect(settingsRect.right, size.width - 20);
          expect(profileRect.size.shortestSide, greaterThanOrEqualTo(48));
          expect(settingsRect.size.shortestSide, greaterThanOrEqualTo(48));
          expect(
            tester.getRect(find.byTooltip('Turn sound off')).right,
            lessThanOrEqualTo(settingsRect.left),
          );
          await snap('home');
          await tester.ensureVisible(find.text('Writing'));
          await tester.pump();
          expect(tester.getRect(profile), profileRect);
          expect(tester.getRect(settings), settingsRect);
          expect(profile.hitTestable(), findsOneWidget);
          expect(settings.hitTestable(), findsOneWidget);
          await tapVisible(tester, find.text('Writing'));
          await tapVisible(tester, find.text('Handwriting'));
          _visibleAction(tester, 'writing-check');
          final viewport = tester.getRect(_writingScroll());
          final freehand = tester.getRect(_freehand);
          final trace = tester.getRect(_trace);
          final scroll = tester
              .state<ScrollableState>(
                find.descendant(
                  of: _writingScroll(),
                  matching: find.byType(Scrollable),
                ),
              )
              .position;
          if (size.shortestSide >= 600) {
            expect(
              tester.getRect(find.text('Skip letter')).bottom,
              lessThanOrEqualTo(trace.top),
            );
            if (scroll.maxScrollExtent == 0) {
              expect(freehand.bottom, closeTo(viewport.bottom - 16, .01));
              expect(trace.top, greaterThanOrEqualTo(viewport.top));
            } else {
              // Large text keeps the pads at their normal size and scrolls.
              await tester.ensureVisible(_freehand);
              await tester.pump();
              expect(scroll.pixels, greaterThan(0));
              expect(
                tester.getRect(_freehand).bottom,
                lessThanOrEqualTo(viewport.bottom),
              );
            }
            if (scale == 1) expect(scroll.maxScrollExtent, 0);
          } else {
            expect(
              tester.getRect(find.text('Skip letter')).top,
              greaterThanOrEqualTo(freehand.bottom),
            );
          }
          if (size.width - 32 >= 640) {
            expect(trace.height, 240);
            expect(freehand.height, 240);
            expect(freehand.left, greaterThan(trace.right));
          } else {
            expect(freehand.top, greaterThan(trace.bottom));
            expect(freehand.height, size.height >= 800 ? 200 : 180);
          }
          await snap('writing');
          await tester.ensureVisible(_freehand);
          await tester.pump();
          _visibleAction(tester, 'writing-check');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('Home header respects cutouts and navigation insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      left: 30,
      top: 24,
      right: 18,
      bottom: 24,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(captureApp(seeded()));
    await settle(tester);
    final profile = tester.getRect(
      find.byKey(const ValueKey('profile-picker')),
    );
    final settings = tester.getRect(find.byTooltip('Settings'));
    expect(profile.left, 50);
    expect(profile.top, 32);
    expect(settings.right, 1100 - 18 - 20);
    await tapVisible(tester, find.byKey(const ValueKey('profile-picker')));
    expect(find.byTooltip('Close players'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Close players'));
    await tapVisible(tester, find.byTooltip('Settings'));
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets(
    'tablet reflow preserves ink and Clear preserves completion and XP',
    (tester) async {
      tester.view.physicalSize = const Size(600, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final device = seeded();
      await openWriting(tester, device);
      await drawSample(tester, 'A');
      final ink = tester.widget<WritingPad>(_freehand).ink;
      final saved = ink.strokes;
      final unfinished = await tester.startGesture(tester.getCenter(_freehand));
      await unfinished.moveBy(const Offset(10, 15));
      for (final size in [
        const Size(960, 600),
        const Size(540, 900),
        const Size(800, 1100),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        await tester.pump();
        expect(tester.widget<WritingPad>(_freehand).ink, same(ink));
        expect(ink.strokes, saved);
        expect(ink.drawing, isFalse);
      }
      await unfinished.up();
      // Empty tablet space is not a drawing surface.
      final margin = await tester.startGesture(const Offset(8, 400));
      await margin.moveBy(const Offset(0, 30));
      await margin.up();
      expect(ink.strokes, saved);
      await tapVisible(tester, find.text('Check'));
      _visibleAction(tester, 'writing-continue');
      await tapVisible(tester, find.text('Clear'));
      expect(ink.isEmpty, isTrue);
      expect(PlayerProgress.decode(device.document).writing!.currentForms, 1);
      expect(device.xp, 0);
      await tapVisible(tester, find.byKey(const ValueKey('case-lower')));
      await drawSample(tester, 'a', kind: PointerDeviceKind.stylus);
      await tapVisible(tester, find.text('Check'));
      expect(device.xp, 10);
      await tapVisible(tester, find.text('Clear'));
      expect(PlayerProgress.decode(device.document).writing!.currentForms, 3);
      expect(device.xp, 10);
      _visibleAction(tester, 'writing-continue');
      expect(tester.takeException(), isNull);
    },
  );
}
