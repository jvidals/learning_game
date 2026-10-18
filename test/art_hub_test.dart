import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/screens/sketch_page.dart';
import 'package:rainbow_garden/widgets/activity_illustration.dart';
import 'package:rainbow_garden/widgets/selection_card.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

void main() {
  test('Sketch pad is a silent activity with its own engine', () {
    expect(GameCategory.values.last, GameCategory.artHub);
    expect(Activity.values.last, Activity.sketchPad);
    expect(GameCategory.artHub.activities, [Activity.sketchPad]);
    expect(GameCategory.artHub.example, isEmpty);
    expect(GameCategory.artHub.colorIndex, 3);
    expect(Activity.sketchPad.example, isEmpty);
    expect(Activity.sketchPad.colorIndex, 3);
    expect(Activity.sketchPad.isRecognition, isFalse);
    expect(Activity.sketchPad.isCounting, isFalse);
    expect(Activity.sketchPad.isOrdering, isFalse);
    expect(Activity.sketchPad.hasSpokenTarget, isFalse);
    expect(() => GameRound(Activity.sketchPad), throwsArgumentError);
  });

  for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
    for (final (size, scale) in [
      (const Size(393, 852), 1.0),
      (const Size(320, 640), 2.0),
    ]) {
      testWidgets('Art Hub navigation at $size/$scale/${appearance.name}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final device = MemoryDevice()..appearance = appearance;
        await tester.pumpWidget(RainbowGardenApp(services: device));
        await settle(tester);

        final homeCard = find.byWidgetPredicate(
          (w) => w is SelectionCard && w.title == 'Art Hub',
        );
        expect(homeCard, findsOneWidget);
        expect(
          find.descendant(
            of: homeCard,
            matching: find.byType(SketchPadIllustration),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(homeCard);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.text('Art Hub'));

        final cards = find.byType(SelectionCard);
        expect(cards, findsOneWidget);
        final card = tester.widget<SelectionCard>(cards);
        expect(card.title, 'Sketch Pad');
        expect(card.subtitle, 'Draw, erase and fill');
        expect(card.illustration, isA<SketchPadIllustration>());
        expect(card.showPlayArrow, isTrue);
        expect(find.text(card.subtitle), findsOneWidget);
        await tester.ensureVisible(cards);
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tapVisible(tester, find.text(Activity.sketchPad.title));
        expect(find.byType(SketchPage), findsOneWidget);
        // Full-screen page: no AppBar, the route is named for screen readers.
        expect(find.byType(AppBar), findsNothing);
        expect(find.bySemanticsLabel('Sketch Pad'), findsOneWidget);
        await tapVisible(tester, find.byTooltip('Back to Art Hub'));
        expect(find.byType(SketchPage), findsNothing);
        expect(find.text(Activity.sketchPad.title), findsOneWidget);
        expect(find.text('Art Hub'), findsOneWidget);
        await tapVisible(tester, find.byTooltip('Back to home'));
        expect(find.text('Hi, Player 1!'), findsOneWidget);
        expect(homeCard, findsOneWidget);
        expect(device.xp, 0);
        expect(device.clips, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
