import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'interface_layout_test.dart' show capture, loadCaptureFonts;
import 'widget_test.dart' show tapVisible;
import 'writing_widgets_test.dart' show openWriting, seeded;

void main() {
  setUpAll(loadCaptureFonts);
  for (final brightness in Brightness.values) {
    for (final (name, size) in [
      ('small', const Size(320, 640)),
      ('phone', const Size(393, 852)),
      ('pixel', const Size(427, 952)),
      ('landscape', const Size(740, 360)),
      ('tablet', const Size(800, 1100)),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('all picker pairs fit $name $brightness text $scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final boundary = GlobalKey();
          final device = seeded();
          await openWriting(tester, device, boundary: boundary);
          final saved = device.document;
          await tapVisible(tester, find.byTooltip('Choose a letter'));
          final scrollable = find
              .descendant(
                of: find.byKey(const ValueKey('letter-picker-scroll')),
                matching: find.byType(Scrollable),
              )
              .first;
          await capture(
            tester,
            boundary,
            '$name-${brightness.name}-$scale-top',
            directory: '0151',
          );
          for (var i = 0; i < 26; i++) {
            final upper = String.fromCharCode(65 + i);
            final pair = '$upper${upper.toLowerCase()}';
            final button = find.byKey(ValueKey('pick-letter-$upper'));
            await tester.scrollUntilVisible(
              button,
              120,
              scrollable: scrollable,
            );
            await tester.pumpAndSettle();
            final label = find.descendant(
              of: button,
              matching: find.byType(RichText),
            );
            final paragraph = tester.renderObject<RenderParagraph>(label);
            final boxes = paragraph.getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 2),
            );
            expect(paragraph.text.toPlainText(), pair);
            expect(boxes, hasLength(1), reason: '$pair must stay on one line');
            expect(boxes.single.left, greaterThanOrEqualTo(-.5));
            expect(
              boxes.single.right,
              lessThanOrEqualTo(paragraph.size.width + .5),
            );
            expect(
              boxes.single.bottom,
              lessThanOrEqualTo(paragraph.size.height + .5),
            );
            final natural = TextPainter(
              text: paragraph.text,
              textDirection: paragraph.textDirection,
              textScaler: paragraph.textScaler,
              maxLines: 1,
            )..layout();
            expect(
              natural.width,
              lessThanOrEqualTo(paragraph.size.width + .5),
              reason: '$pair must fit without clipping',
            );
            natural.dispose();
            expect(
              tester.getSize(button).shortestSide,
              greaterThanOrEqualTo(48),
            );
            if (upper == 'W') {
              await capture(
                tester,
                boundary,
                '$name-${brightness.name}-$scale-wide',
                directory: '0151',
              );
            }
          }
          await tapVisible(tester, find.byKey(const ValueKey('pick-letter-Z')));
          expect(find.text('Practice only · no XP'), findsOneWidget);
          expect(device.document, saved);
          await tapVisible(tester, find.byTooltip('Choose a letter'));
          await tapVisible(tester, find.byKey(const ValueKey('pick-shuffle')));
          expect(device.document, saved);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
