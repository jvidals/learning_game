import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/widgets/selection_card.dart';
import 'interface_layout_test.dart' show loadCaptureFonts;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

Finder iconBox(Finder card) => find.descendant(
  of: card,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).borderRadius ==
            BorderRadius.circular(18),
  ),
);

void main() {
  setUpAll(loadCaptureFonts);
  for (final (size, scale) in [
    (const Size(393, 852), 1.0),
    (const Size(360, 640), 2.0),
    (const Size(800, 1100), 1.0),
    (const Size(800, 1100), 2.0),
  ]) {
    for (final category in GameCategory.values) {
      testWidgets('${category.name} uniform cards at $size/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(RainbowGardenApp(services: MemoryDevice()));
        await settle(tester);
        await tapVisible(tester, find.text(category.title));
        final cards = find.byType(SelectionCard);
        expect(cards, findsNWidgets(category.activities.length));
        final heights = <String, double>{};
        final iconSizes = <Size>{};
        for (var i = 0; i < category.activities.length; i++) {
          final card = cards.at(i);
          await tester.ensureVisible(card);
          await tester.pump();
          expect(tester.takeException(), isNull);
          final widget = tester.widget<SelectionCard>(card);
          heights[widget.title] = tester.getSize(card).height;
          expect(iconBox(card), findsOneWidget);
          iconSizes.add(tester.getSize(iconBox(card)));
          // The measured height must contain the title/subtitle at the actual
          // available width, including the play arrow or separate range action.
          final bounds = tester.getRect(card).deflate(17);
          for (final text in [widget.title, widget.subtitle]) {
            if (text.isEmpty) continue;
            final rect = tester.getRect(
              find.descendant(
                of: card,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Text &&
                      w.data == text &&
                      (w.style?.fontSize == 20 || w.style?.fontSize == 14),
                ),
              ),
            );
            expect(bounds.contains(rect.topLeft), isTrue);
            expect(bounds.contains(rect.bottomRight), isTrue);
          }
        }
        // Useful diagnostics when reviewing a future subtitle or font change.
        debugPrint('${category.name} $size/$scale: $heights; icons=$iconSizes');
        expect(heights.values.toSet(), hasLength(1));
        expect(iconSizes, hasLength(1));
        // Roboto preserves the production 102 dp height. The test runner's
        // default Ahem font has wider glyphs and wraps the 2048 subtitle.
        if (category == GameCategory.numbers &&
            scale == 1 &&
            size.width == 393 &&
            const String.fromEnvironment('REFRESH_FONT_DIR').isNotEmpty) {
          expect(heights.values, everyElement(102));
        }
        if (size.width == 800 && category.activities.length > 1) {
          expect(
            tester.getTopLeft(cards.at(1)).dx,
            greaterThan(tester.getTopLeft(cards.first).dx),
          );
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('Home category cards share the normal phone height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RainbowGardenApp(services: MemoryDevice()));
    await settle(tester);
    final cards = find.byType(SelectionCard);
    expect(cards, findsNWidgets(GameCategory.values.length));
    expect(
      tester
          .elementList(cards)
          .map((e) => tester.getSize(find.byWidget(e.widget)).height),
      everyElement(102),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
