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
];

void main() {
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
