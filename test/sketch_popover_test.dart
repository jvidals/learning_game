import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/widgets/sketch_popover.dart';

void main() {
  for (final landscape in [false, true]) {
    testWidgets(
      'popover opens toward center from ${landscape ? 'left' : 'top'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = landscape
            ? const Size(800, 400)
            : const Size(400, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final anchor = GlobalKey();
        var closed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: GardenTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => Stack(
                  children: [
                    Positioned(
                      left: landscape ? 8 : 180,
                      top: landscape ? 180 : 8,
                      child: IconButton(
                        key: anchor,
                        icon: const Icon(Icons.brush),
                        onPressed: () async {
                          await showSketchPopover<void>(
                            context,
                            anchor: anchor,
                            builder: (_) => const SizedBox(
                              key: ValueKey('content'),
                              width: 200,
                              height: 100,
                            ),
                          );
                          closed = true;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(anchor));
        await tester.pumpAndSettle();
        final icon = tester.getRect(find.byKey(anchor));
        final content = tester.getRect(find.byKey(const ValueKey('content')));
        expect(
          landscape ? content.left : content.top,
          closeTo(landscape ? icon.right : icon.bottom, .01),
        );
        expect(closed, isFalse);
        await tester.tapAt(const Offset(390, 390));
        await tester.pumpAndSettle();
        expect(closed, isTrue);
        expect(find.byKey(const ValueKey('content')), findsNothing);
        await tester.tap(find.byKey(anchor));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('content')), findsNothing);
      },
    );
  }

  testWidgets('open popover follows rotating anchor without dismissal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final anchor = GlobalKey();
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final portrait =
                  MediaQuery.sizeOf(context).height >
                  MediaQuery.sizeOf(context).width;
              return Stack(
                children: [
                  Positioned(
                    left: portrait ? 200 : 8,
                    top: portrait ? 8 : 200,
                    child: IconButton(
                      key: anchor,
                      icon: const Icon(Icons.palette),
                      onPressed: () async {
                        await showSketchPopover<void>(
                          context,
                          anchor: anchor,
                          builder: (_) => const SizedBox(
                            key: ValueKey('content'),
                            width: 200,
                            height: 100,
                          ),
                        );
                        dismissed = true;
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(anchor));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('content'))).dy,
      closeTo(tester.getBottomLeft(find.byKey(anchor)).dy, .01),
    );
    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();
    expect(dismissed, isFalse);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('content'))).dx,
      closeTo(tester.getTopRight(find.byKey(anchor)).dx, .01),
    );
    expect(tester.takeException(), isNull);
  });

  for (final landscape in [false, true]) {
    testWidgets(
      'corner-grouped ${landscape ? 'rail' : 'strip'} icon opens toward the page',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = landscape
            ? const Size(800, 400)
            : const Size(400, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final anchor = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: GardenTheme.light,
            home: Scaffold(
              body: Builder(
                // Like Sketch pad's pickers: grouped at the strip's far end,
                // nearer the side edge than the strip's own edge.
                builder: (context) => Stack(
                  children: [
                    Positioned(
                      right: landscape ? null : 8,
                      left: landscape ? 12 : null,
                      top: landscape ? null : 12,
                      bottom: landscape ? 8 : null,
                      child: IconButton(
                        key: anchor,
                        icon: const Icon(Icons.brush),
                        onPressed: () => showSketchPopover<void>(
                          context,
                          anchor: anchor,
                          builder: (_) => const SizedBox(
                            key: ValueKey('content'),
                            width: 200,
                            height: 100,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(anchor));
        await tester.pumpAndSettle();
        final icon = tester.getRect(find.byKey(anchor));
        final content = tester.getRect(find.byKey(const ValueKey('content')));
        if (landscape) {
          expect(content.left, closeTo(icon.right, .01));
          expect(content.bottom, lessThanOrEqualTo(392.01));
        } else {
          expect(content.top, closeTo(icon.bottom, .01));
          expect(content.right, lessThanOrEqualTo(392.01));
        }
      },
    );
  }
}
