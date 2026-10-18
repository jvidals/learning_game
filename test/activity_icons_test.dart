import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/widgets/activity_illustration.dart';
import 'package:rainbow_garden/widgets/selection_card.dart';
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

const newIcons = <Widget>[
  CursiveIllustration(),
  SameNumberIllustration(),
  WordSprintIllustration(),
  ReadAndFindIllustration(),
  MakeBelieveIllustration(),
  NumberPartsIllustration(),
  SketchPadIllustration(),
];

void main() {
  testWidgets('Same number uses a typed, unscaled 3 at 48 pixels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GardenTheme.dark,
        home: const Scaffold(
          body: SizedBox(
            width: 48,
            height: 54 * 48 / 62,
            child: FittedBox(child: SameNumberIllustration()),
          ),
        ),
      ),
    );
    final glyph = tester.widget<Text>(
      find.descendant(
        of: find.byType(SameNumberIllustration),
        matching: find.text('3'),
      ),
    );
    expect(glyph.style?.fontWeight, FontWeight.w800);
    expect(glyph.textScaler, TextScaler.noScaling);
    final context = tester.element(find.byType(SameNumberIllustration));
    expect(glyph.style?.color, GardenColors.of(context).foreground);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final small in [false, true]) {
      testWidgets('new icons paint: dark=$dark, fitted=$small', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? GardenTheme.dark : GardenTheme.light,
            home: Scaffold(
              body: Column(
                children: [
                  for (final icon in newIcons)
                    if (small)
                      SizedBox(
                        width: 48,
                        height: 54,
                        child: FittedBox(child: icon),
                      )
                    else
                      SizedBox(width: 62, height: 54, child: icon),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final icon in newIcons) {
          expect(
            find.descendant(
              of: find.byType(icon.runtimeType),
              matching: find.byType(ExcludeSemantics),
            ),
            findsOneWidget,
          );
        }
      });
    }
  }

  for (final (size, scale) in [
    (const Size(360, 640), 2.0),
    (const Size(393, 852), 1.0),
  ]) {
    for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
      for (final category in [
        GameCategory.words,
        GameCategory.numbers,
        GameCategory.writing,
        GameCategory.artHub,
      ]) {
        testWidgets(
          '${category.name} cards at $size/$scale/${appearance.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.pumpWidget(
              RainbowGardenApp(
                services: MemoryDevice()..appearance = appearance,
              ),
            );
            await settle(tester);
            await tapVisible(tester, find.text(category.title));
            final finder = find.byType(SelectionCard);
            final cards = tester.widgetList<SelectionCard>(finder).toList();
            const types = <Activity, Type>{
              Activity.numberOrder: OrderingIllustration,
              Activity.howMany: CountingIllustration,
              Activity.makeGroup: CountingIllustration,
              Activity.sameNumber: SameNumberIllustration,
              Activity.numberParts: NumberPartsIllustration,
              Activity.readAndFind: ReadAndFindIllustration,
              Activity.makeBelieve: MakeBelieveIllustration,
              Activity.wordSprint: WordSprintIllustration,
              Activity.handwriting: HandwritingIllustration,
              Activity.cursive: CursiveIllustration,
              Activity.sketchPad: SketchPadIllustration,
            };
            for (final activity in category.activities) {
              final card = cards.singleWhere((c) => c.title == activity.title);
              if (types.containsKey(activity)) {
                expect(card.illustration?.runtimeType, types[activity]);
              }
              if (activity == Activity.game2048) {
                expect(card.illustration, isNull);
                expect(card.example, '2048');
              }
            }
            if (category == GameCategory.numbers) {
              expect({
                for (var i = 0; i < cards.length; i++)
                  tester.getSize(finder.at(i)).height,
              }, hasLength(1));
            }
            for (final activity in category.activities) {
              await tester.ensureVisible(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is SelectionCard && widget.title == activity.title,
                ),
              );
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
