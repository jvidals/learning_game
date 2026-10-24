import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sketch_page_test.dart' as page;
import 'widget_test.dart' show MemoryDevice;

void main() {
  for (final size in [
    const Size(393, 852),
    const Size(852, 393),
    const Size(1280, 800),
  ]) {
    testWidgets('blank strip accepts a short run-in beside the paper at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = await page.mount(
        tester,
        MemoryDevice(),
        reducedMotion: true,
      );
      final paper = page.screenPage(tester);
      final c = page.canvas(tester).controller;
      final portrait = size.height > size.width;
      final starts = portrait
          ? [
              paper.topCenter - const Offset(0, 20),
              paper.bottomCenter + const Offset(0, 20),
            ]
          : [
              paper.centerLeft - const Offset(20, 0),
              paper.centerRight + const Offset(20, 0),
            ];
      for (final start in starts) {
        final before = c.ops.length;
        final gesture = await tester.startGesture(start);
        await gesture.moveTo(paper.center);
        await gesture.up();
        expect(
          c.ops.length,
          before + 1,
          reason:
              'a touch 20 logical pixels outside paper must enter the drawing',
        );
      }
      expect(
        page.screenPage(tester),
        paper,
        reason: 'touch extension must not resize paper',
      );
      final before = c.ops.length;
      final outside = await tester.startGesture(starts.first);
      await outside.moveBy(
        portrait ? const Offset(15, 0) : const Offset(0, 15),
      );
      await outside.up();
      expect(c.ops.length, before, reason: 'margin-only motion leaves no mark');
      final beyond = await tester.startGesture(
        portrait
            ? paper.topCenter - const Offset(0, 28)
            : paper.centerLeft - const Offset(28, 0),
      );
      await beyond.moveTo(paper.center);
      await beyond.up();
      expect(
        c.ops.length,
        before,
        reason: 'the whole toolbar is not a drawing surface',
      );
      final tool = tester.getRect(page.keyed('sketch-tool'));
      final onButton = await tester.startGesture(
        portrait
            ? tool.bottomCenter - const Offset(0, 1)
            : tool.centerRight - const Offset(1, 0),
      );
      await onButton.moveTo(paper.center);
      await onButton.up();
      expect(
        c.ops.length,
        before,
        reason: 'a drag beginning on a control must not draw',
      );
      await tester.tap(page.keyed('sketch-tool'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Eraser'), findsOneWidget);
      expect(c.ops.length, before, reason: 'toolbar still owns its taps');
      await tester.pumpWidget(const SizedBox());
      await page.settleImages(tester);
      state.progress.dispose();
    });
  }
}
