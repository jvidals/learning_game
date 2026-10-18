import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/category_page.dart';
import 'package:rainbow_garden/widgets/selection_card.dart';
import 'package:rainbow_garden/number_range.dart';
import 'package:rainbow_garden/widgets/counting_board.dart';
import 'package:rainbow_garden/widgets/number_range_editor.dart';
import 'package:rainbow_garden/widgets/ordering_board.dart';
import 'settings_test.dart' show answerGate, unlock;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;
import 'interface_layout_test.dart' show capture, loadCaptureFonts;

class SlowRangeDevice extends MemoryDevice {
  Completer<void>? hold;
  @override
  Future<void> saveProfiles(String value) async {
    await hold?.future;
    await super.saveProfiles(value);
  }
}

Future<void> openGame(
  WidgetTester tester,
  MemoryDevice device,
  Activity activity,
) async {
  await tester.pumpWidget(RainbowGardenApp(services: device));
  await settle(tester);
  await tapVisible(tester, find.text('Numbers'));
  await tapVisible(tester, find.text(activity.title));
}

Future<void> editRange(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('number-range-button')));
  await answerGate(tester);
}

Future<void> changeRange(WidgetTester tester, int min, int max) async {
  tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
    RangeValues(min.toDouble(), max.toDouble()),
  );
  await settle(tester);
}

Future<void> closeRange(WidgetTester tester) =>
    tapVisible(tester, find.byTooltip('Close range settings'));
CountingBoard counting(WidgetTester tester) =>
    tester.widget<CountingBoard>(find.byType(CountingBoard));

void main() {
  setUpAll(() async {
    await loadCaptureFonts();
    if (const bool.fromEnvironment('CAPTURE_REFRESH')) {
      final art = await FoalAssets.load();
      await art.ensurePoster('none-none');
    }
  });
  testWidgets(
    'category shortcut has separate semantics and suppresses the initial prompt',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final d = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      await tapVisible(tester, find.text('Numbers'));
      expect(find.bySemanticsLabel('Number Hunt'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Change Number Hunt range, 0–10'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const ValueKey('range-numbers')));
      expect(d.clips, isEmpty);
      await answerGate(tester);
      expect(d.clips, isEmpty);
      await changeRange(tester, 98, 100);
      expect(d.clips, isEmpty);
      await closeRange(tester);
      expect(d.clips, hasLength(1));
      expect(int.parse(d.clips.single.substring(7)), inInclusiveRange(98, 100));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(
        find.bySemanticsLabel('Change Number Hunt range, 98–100'),
        findsOneWidget,
      );
      expect(d.ranges.numberOrder, NumberRange.defaults);
      semantics.dispose();
    },
  );

  testWidgets(
    'cancel and unchanged final range preserve an ordering board; changes restart once',
    (tester) async {
      final d = MemoryDevice()..soundOn = false;
      await openGame(tester, d, Activity.numberOrder);
      final original = tester
          .widget<OrderingBoard>(find.byType(OrderingBoard))
          .round;
      await tapVisible(
        tester,
        find.byKey(const ValueKey('number-range-button')),
      );
      await tapVisible(tester, find.text('Cancel'));
      expect(
        tester.widget<OrderingBoard>(find.byType(OrderingBoard)).round,
        same(original),
      );
      await editRange(tester);
      await changeRange(tester, 1, 20);
      await changeRange(tester, 0, 10);
      await closeRange(tester);
      expect(
        tester.widget<OrderingBoard>(find.byType(OrderingBoard)).round,
        same(original),
      );
      await editRange(tester);
      await changeRange(tester, 1, 20);
      await closeRange(tester);
      final next = tester
          .widget<OrderingBoard>(find.byType(OrderingBoard))
          .round;
      expect(next, isNot(same(original)));
      expect(next.targets, List.generate(20, (i) => i + 1));
      await settle(tester);
      expect(
        tester.widget<OrderingBoard>(find.byType(OrderingBoard)).round,
        same(next),
      );
      expect(d.xp, 0);
      expect(d.ranges.numberHunt, NumberRange.defaults);
      expect(d.ranges.howMany, NumberRange.defaults);
    },
  );

  testWidgets(
    'counting edits preserve unchanged work and apply a custom 1–15 group',
    (tester) async {
      final d = MemoryDevice();
      await openGame(tester, d, Activity.makeGroup);
      await tapVisible(tester, find.byKey(const ValueKey('add-count-object')));
      final original = counting(tester).work;
      expect(original.items, hasLength(1));
      await editRange(tester);
      expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).max, 20);
      await closeRange(tester);
      expect(counting(tester).work, same(original));
      await editRange(tester);
      await changeRange(tester, 1, 15);
      await closeRange(tester);
      expect(counting(tester).work, isNot(same(original)));
      expect(counting(tester).work.items, isEmpty);
      expect(counting(tester).scene.quantity, inInclusiveRange(1, 15));
      expect(counting(tester).maximum, 15);
      for (var i = 0; i < 15; i++) {
        await tapVisible(
          tester,
          find.byKey(const ValueKey('add-count-object')),
        );
      }
      expect(counting(tester).work.items, hasLength(15));
      expect(counting(tester).work.add(), isFalse);
      expect(d.ranges.howMany, NumberRange.defaults);
      expect(d.clips, isEmpty);
      expect(d.xp, 0);
    },
  );

  testWidgets(
    'close during a failed background save pauses work until retry then restarts once',
    (tester) async {
      final d = SlowRangeDevice();
      await openGame(tester, d, Activity.makeGroup);
      final original = counting(tester).work;
      await editRange(tester);
      d.hold = Completer<void>();
      await changeRange(tester, 1, 15);
      await closeRange(tester);
      expect(counting(tester).work, same(original));
      expect(counting(tester).enabled, isFalse);
      expect(find.text('Saving settings…'), findsOneWidget);
      d.failSave = true;
      d.hold!.complete();
      await settle(tester);
      expect(counting(tester).work, same(original));
      expect(counting(tester).enabled, isFalse);
      d.hold = null;
      d.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      final next = counting(tester).work;
      expect(next, isNot(same(original)));
      expect(counting(tester).maximum, 15);
      expect(counting(tester).enabled, isTrue);
      await settle(tester);
      expect(counting(tester).work, same(next));
      expect(d.xp, 0);
    },
  );

  for (final activity in [Activity.howMany, Activity.makeGroup]) {
    testWidgets(
      '${activity.name} retains zero and nonzero bounds through a completed round and replay',
      (tester) async {
        final d = MemoryDevice()..soundOn = false;
        await openGame(tester, d, activity);
        await editRange(tester);
        await changeRange(tester, 0, 2);
        await closeRange(tester);
        final seen = <int>{};
        for (var i = 0; i < 5; i++) {
          final target = counting(tester).scene.quantity;
          seen.add(target);
          if (activity == Activity.makeGroup) {
            for (var j = 0; j < target; j++) {
              await tapVisible(
                tester,
                find.byKey(const ValueKey('add-count-object')),
              );
            }
            await tapVisible(
              tester,
              find.byKey(const ValueKey('check-counting')),
            );
          } else {
            await tapVisible(tester, find.byKey(ValueKey('choice-$target')));
          }
          if (i < 4) await tapVisible(tester, find.text('Next'));
        }
        expect(seen, {0, 1, 2});
        expect(d.xp, 50);
        await tapVisible(tester, find.text('Next round'));
        expect(counting(tester).scene.quantity, inInclusiveRange(0, 2));
        expect(d.xp, 50);
        expect(d.clips, isEmpty);
      },
    );
  }

  for (final (name, size) in [
    ('small', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('range controls fit $name ${appearance.name} ${scale}x', (
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
          final d = MemoryDevice()
            ..appearance = appearance
            ..soundOn = false;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: RainbowGardenApp(services: d),
            ),
          );
          await settle(tester);
          await tapVisible(tester, find.text('Numbers'));
          void checkUniformCards() {
            final cards = find.byType(SelectionCard);
            expect(cards, findsNWidgets(7));
            final heights = [
              for (var i = 0; i < 7; i++) tester.getSize(cards.at(i)).height,
            ];
            expect(heights.toSet(), hasLength(1));
            if (name == 'phone' &&
                scale == 1 &&
                const String.fromEnvironment('REFRESH_FONT_DIR').isNotEmpty) {
              expect(heights.first, 102);
            }
            expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
            expect(tester.takeException(), isNull);
          }

          checkUniformCards();
          final prefix = '$name-${appearance.name}-${scale.toInt()}x';
          await capture(
            tester,
            boundary,
            '$prefix-category',
            directory: '0200',
          );
          for (final activity in [
            Activity.numbers,
            Activity.numberOrder,
            Activity.howMany,
            Activity.makeGroup,
          ]) {
            final shortcut = find.byKey(ValueKey('range-${activity.name}'));
            await tester.ensureVisible(shortcut);
            await settle(tester);
            final buttonRect = tester.getRect(shortcut);
            final surfaceRect = tester.getRect(
              find
                  .ancestor(of: shortcut, matching: find.byType(Material))
                  .first,
            );
            expect(buttonRect.height, greaterThanOrEqualTo(48));
            expect(buttonRect.width, greaterThanOrEqualTo(48));
            expect(buttonRect.center.dy, closeTo(surfaceRect.center.dy, .01));
            expect(surfaceRect.contains(buttonRect.topLeft), isTrue);
            expect(surfaceRect.contains(buttonRect.bottomRight), isTrue);
            await tapVisible(tester, shortcut);
            await answerGate(tester);
            expect(find.byType(NumberRangeEditor), findsOneWidget);
            await capture(
              tester,
              boundary,
              '$prefix-${activity.name}-editor',
              directory: '0200',
            );
            await tapVisible(tester, find.byTooltip('Increase end'));
            expect(d.ranges.forActivity(activity), NumberRange(0, 11));
            await tester.ensureVisible(find.byTooltip('Increase end'));
            await tester.pump();
            await capture(
              tester,
              boundary,
              '$prefix-${activity.name}-controls',
              directory: '0200',
            );
            await closeRange(tester);
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('number-range-button')))
                  .width,
              greaterThanOrEqualTo(56),
            );
            expect(tester.takeException(), isNull);
            await capture(
              tester,
              boundary,
              '$prefix-${activity.name}-game',
              directory: '0200',
            );
            await tester.binding.handlePopRoute();
            await settle(tester);
          }
          final controller = tester
              .widget<CategoryPage>(find.byType(CategoryPage))
              .controller;
          await controller.updateSettings(
            (settings) => settings
                .withNumberRange(Activity.numbers, NumberRange(0, 100))
                .withNumberRange(Activity.numberOrder, NumberRange(98, 100)),
          );
          await settle(tester);
          checkUniformCards();
          await tester.ensureVisible(find.byType(SelectionCard).first);
          await settle(tester);
          await capture(
            tester,
            boundary,
            '$prefix-category-long-ranges',
            directory: '0202',
          );
          for (final activity in [Activity.numbers, Activity.numberOrder]) {
            final shortcut = find.byKey(ValueKey('range-${activity.name}'));
            await tester.ensureVisible(shortcut);
            await settle(tester);
            final card = find.ancestor(
              of: shortcut,
              matching: find.byType(SelectionCard),
            );
            final controlRect = tester.getRect(shortcut);
            final cardRect = tester.getRect(card);
            expect(cardRect.contains(controlRect.topLeft), isTrue);
            expect(cardRect.contains(controlRect.bottomRight), isTrue);
            expect(controlRect.center.dy, closeTo(cardRect.center.dy, .01));
          }
          expect(d.clips, isEmpty);
          await tester.binding.handlePopRoute();
          await settle(tester);
          await unlock(tester);
          await capture(
            tester,
            boundary,
            '$prefix-app-settings',
            directory: '0200',
          );
          expect(find.text('Save settings'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
