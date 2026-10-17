import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/number_sense.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/widgets/number_visuals.dart';
import 'package:rainbow_garden/widgets/visual_question.dart';
import 'widget_test.dart' show MemoryDevice, rewardResult, settle, tapVisible;

VisualQuestionContext visualContext({
  bool hint = false,
  bool answered = false,
}) => VisualQuestionContext(
  hint: hint,
  answered: answered,
  enabled: !answered,
  soundOn: true,
  selected: null,
  playSequence: (_, {onStep}) =>
      throw StateError('Number games must stay silent'),
);

Future<void> showPrompt(
  WidgetTester tester,
  Widget prompt, {
  bool dark = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? GardenTheme.dark : GardenTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Scaffold(body: SingleChildScrollView(child: prompt)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final kind in NumberRepresentation.values) {
    testWidgets('same number completes the missing ${kind.name} panel', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final visual = SameNumberVisual(quantity: 7, missingKind: kind);
      Widget prompt(bool answered) => SameNumberPrompt(
        visual: visual,
        context: visualContext(answered: answered),
      );
      await showPrompt(tester, prompt(false));
      final missing = find.byKey(ValueKey('same-panel-${kind.name}'));
      expect(
        find.descendant(of: missing, matching: find.text('?')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Missing ${kind.label.toLowerCase()}'),
        findsOneWidget,
      );
      await showPrompt(tester, prompt(true));
      expect(find.text('?'), findsNothing);
      expect(find.bySemanticsLabel('Number 7'), findsOneWidget);
      expect(find.bySemanticsLabel('Ten frame showing 7'), findsOneWidget);
      expect(find.bySemanticsLabel('7 circles'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets(
    'only an explicit hint adds frame numbering, five bracket and picture counts',
    (tester) async {
      const visual = SameNumberVisual(
        quantity: 7,
        missingKind: NumberRepresentation.numeral,
      );
      await showPrompt(
        tester,
        SameNumberPrompt(visual: visual, context: visualContext()),
      );
      expect(find.byKey(const ValueKey('five-bracket')), findsNothing);
      expect(find.byKey(const ValueKey('count-number-1')), findsNothing);
      await showPrompt(
        tester,
        SameNumberPrompt(visual: visual, context: visualContext(hint: true)),
      );
      expect(find.byKey(const ValueKey('five-bracket')), findsOneWidget);
      for (var n = 1; n <= 7; n++) {
        expect(find.byKey(ValueKey('count-number-$n')), findsNWidgets(2));
      }
      expect(find.text('?'), findsOneWidget);
    },
  );

  testWidgets(
    'same number keeps three columns until panels would be too narrow',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const visual = SameNumberVisual(quantity: 10);
      Widget prompt() =>
          SameNumberPrompt(visual: visual, context: visualContext());
      Finder panel(NumberRepresentation kind) =>
          find.byKey(ValueKey('same-panel-${kind.name}'));
      await showPrompt(tester, prompt());
      final numeral = panel(NumberRepresentation.numeral);
      final picture = panel(NumberRepresentation.picture);
      expect(tester.getTopLeft(numeral).dy, tester.getTopLeft(picture).dy);
      expect(
        tester.getTopLeft(numeral).dx,
        lessThan(tester.getTopLeft(picture).dx),
      );
      final firstSize = tester.getSize(numeral);
      expect(firstSize, tester.getSize(picture));
      expect(firstSize.height, lessThan(180));
      tester.view.physicalSize = const Size(320, 640);
      await showPrompt(tester, prompt(), scale: 2);
      expect(tester.getTopLeft(numeral).dx, tester.getTopLeft(picture).dx);
      expect(
        tester.getTopLeft(numeral).dy,
        lessThan(tester.getTopLeft(picture).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ten frame counts top left to right then bottom; scatter stays put on hint',
    (tester) async {
      const visual = SameNumberVisual(
        quantity: 10,
        missingKind: NumberRepresentation.numeral,
        shape: NumberShape.triangle,
        seed: 51,
      );
      Widget prompt(bool hint) => SameNumberPrompt(
        visual: visual,
        context: visualContext(hint: hint),
      );
      final frame = find.byKey(const ValueKey('same-panel-tenFrame'));
      final picture = find.byKey(const ValueKey('same-panel-picture'));
      await showPrompt(tester, prompt(false));
      Finder positions() =>
          find.descendant(of: picture, matching: find.byType(Positioned));
      List<Offset> offsets() => tester
          .widgetList<Positioned>(positions())
          .map((p) => Offset(p.left!, p.top!))
          .toList();
      final before = offsets();
      expect(before, hasLength(10));
      await showPrompt(tester, prompt(true));
      expect(offsets(), before);
      Rect number(int n) => tester.getRect(
        find
            .ancestor(
              of: find.descendant(
                of: frame,
                matching: find.byKey(ValueKey('count-number-$n')),
              ),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(number(1).top, number(5).top);
      expect(number(6).top, number(10).top);
      expect(number(1).center.dx, number(6).center.dx);
      expect(number(5).center.dx, number(10).center.dx);
      expect(number(5).top, lessThan(number(6).top));
      for (var n = 2; n <= 5; n++) {
        expect(number(n).left, greaterThan(number(n - 1).left));
      }
      final pictureNumbers = [
        for (var n = 1; n <= 10; n++)
          tester.getCenter(
            find
                .ancestor(
                  of: find.descendant(
                    of: picture,
                    matching: find.byKey(ValueKey('count-number-$n')),
                  ),
                  matching: find.byType(CustomPaint),
                )
                .first,
          ),
      ];
      // Small jitter is allowed within each visual row. A new row starts
      // only when the horizontal position resets, at a distinctly lower y.
      for (var i = 1; i < pictureNumbers.length; i++) {
        final previous = pictureNumbers[i - 1];
        final current = pictureNumbers[i];
        if ((current.dy - previous.dy).abs() < 10) {
          expect(current.dx, greaterThan(previous.dx));
        } else {
          expect(current.dy, greaterThan(previous.dy));
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty pictures, frames and zero parts remain usable without numbering',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await showPrompt(
        tester,
        SameNumberPrompt(
          visual: const SameNumberVisual(
            quantity: 0,
            missingKind: NumberRepresentation.numeral,
          ),
          context: visualContext(hint: true),
        ),
      );
      expect(find.bySemanticsLabel('0 circles'), findsOneWidget);
      expect(find.bySemanticsLabel('Ten frame showing 0'), findsOneWidget);
      expect(find.byKey(const ValueKey('five-bracket')), findsNothing);
      expect(find.byKey(const ValueKey('count-number-1')), findsNothing);
      await showPrompt(
        tester,
        NumberPartsPrompt(
          visual: const NumberPartsVisual(total: 10, part: 10, makeTen: true),
          context: visualContext(answered: true),
        ),
        scale: 2,
        dark: true,
      );
      expect(find.bySemanticsLabel('0 circles'), findsOneWidget);
      expect(find.text('10 + 0 = 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  for (final makeTen in [false, true]) {
    testWidgets(
      'parts ${makeTen ? 'make-ten' : 'bond'} hint outlines the missing part and completion joins it',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final visual = NumberPartsVisual(
          total: makeTen ? 10 : 5,
          part: 2,
          makeTen: makeTen,
        );
        Widget prompt({bool hint = false, bool answered = false}) =>
            NumberPartsPrompt(
              visual: visual,
              context: visualContext(hint: hint, answered: answered),
            );
        await showPrompt(tester, prompt());
        expect(find.byKey(const ValueKey('part-whole-hint')), findsNothing);
        expect(find.text('?'), findsOneWidget);
        expect(find.bySemanticsLabel('2 circles'), findsOneWidget);
        if (makeTen) {
          expect(find.bySemanticsLabel('Ten frame showing 2'), findsOneWidget);
        }
        await showPrompt(tester, prompt(hint: true));
        expect(find.byKey(const ValueKey('part-whole-hint')), findsOneWidget);
        expect(find.text('?'), findsOneWidget);
        await showPrompt(tester, prompt(answered: true));
        expect(find.text('?'), findsNothing);
        expect(
          find.text('2 + ${visual.missing} = ${visual.total}'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('${visual.missing} circles'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('same number choices are fully visible on a 393x852 phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seenKinds = <NumberRepresentation>{};
    // Fresh pages keep their initial scroll position. Multiple seeded rounds
    // cover every representation and the largest picture/frame choices.
    for (var seed = 0; seed < 12; seed++) {
      final round = GameRound(Activity.sameNumber, random: Random(seed));
      seenKinds.add((round.question.visual! as SameNumberVisual).missingKind);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: GardenTheme.light,
          home: GamePage(
            services: MemoryDevice(),
            activity: Activity.sameNumber,
            sound: true,
            round: round,
            onCompleteRound: (_) async => rewardResult(1),
          ),
        ),
      );
      await settle(tester);
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      for (final choice in round.question.choices) {
        final card = find.byKey(ValueKey('choice-$choice'));
        final rect = tester.getRect(card);
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(card.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
    expect(seenKinds, NumberRepresentation.values.toSet());
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'parts choices center dice and five-frame patterns without numerals',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (var quantity = 0; quantity <= 10; quantity++) {
        await showPrompt(
          tester,
          Center(
            child: SizedBox(
              width: 96,
              child: NumberPartsChoice(
                visual: const NumberPartsVisual(total: 10, part: 2),
                choice: '$quantity',
                context: visualContext(),
              ),
            ),
          ),
        );
        final choice = find.byType(NumberPartsChoice);
        expect(
          find.descendant(of: choice, matching: find.byType(Text)),
          findsNothing,
        );
        final dots = find.descendant(
          of: choice,
          matching: find.byType(Positioned),
        );
        expect(dots, findsNWidgets(quantity));
        final bounds = tester.getRect(choice);
        final positions = tester.widgetList<Positioned>(dots).toList();
        if (quantity == 0) {
          expect(find.byKey(const ValueKey('empty-dot-frame')), findsOneWidget);
          expect(find.bySemanticsLabel('no dots'), findsOneWidget);
        } else {
          final centers = [
            for (final dot in positions)
              Offset(dot.left! + dot.width! / 2, dot.top! + dot.height! / 2),
          ];
          final x = centers.map((p) => p.dx).reduce((a, b) => a + b) / quantity;
          if (quantity <= 6 || quantity == 10) {
            expect(x, closeTo(bounds.width / 2, .01));
          }
          if (quantity <= 6) {
            // Dice occupy a centered square, never the top-left of a wide card.
            final y =
                centers.map((p) => p.dy).reduce((a, b) => a + b) / quantity;
            expect(y, closeTo(bounds.height / 2, .01));
            final left = centers.where((p) => p.dx < x - 1).length;
            final middle = centers.where((p) => (p.dx - x).abs() < 1).length;
            final right = centers.where((p) => p.dx > x + 1).length;
            // One centered pip; opposite diagonals for 2/3; four corners
            // for 4/5; two columns of three for 6.
            expect(left, quantity ~/ 2);
            expect(right, quantity ~/ 2);
            expect(middle, quantity.isOdd ? 1 : 0);
            if (quantity == 2 || quantity == 3) {
              for (final point in centers) {
                expect(point.dx - x, closeTo(point.dy - y, .01));
              }
            }
            if (quantity == 4 || quantity == 5) {
              for (final point in centers.where((p) => (p.dx - x).abs() > 1)) {
                expect(
                  (point.dx - x).abs(),
                  closeTo((point.dy - y).abs(), .01),
                );
              }
            }
          } else {
            expect(centers.take(5).map((p) => p.dy).toSet(), hasLength(1));
            expect(centers.skip(5).map((p) => p.dy).toSet(), hasLength(1));
            expect(centers.first.dy, lessThan(centers.last.dy));
            for (var i = 1; i < 5; i++) {
              expect(centers[i].dx, greaterThan(centers[i - 1].dx));
            }
          }
        }
        expect(bounds.height, lessThanOrEqualTo(104));
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
    },
  );

  testWidgets('make ten has one frame and no separate whole-dot row', (
    tester,
  ) async {
    await showPrompt(
      tester,
      NumberPartsPrompt(
        visual: const NumberPartsVisual(total: 10, part: 8, makeTen: true),
        context: visualContext(),
      ),
    );
    expect(find.text('10'), findsOneWidget);
    // Only the given part uses positioned dots. The whole uses ten cells.
    expect(find.byType(Positioned), findsNWidgets(8));
    expect(find.text('?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final activity in [Activity.sameNumber, Activity.numberParts]) {
    for (final dark in [false, true]) {
      testWidgets(
        '${activity.name} stays silent and fits 360x640 at 2x in ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          final device = MemoryDevice();
          final round = GameRound(activity, random: Random(28));
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? GardenTheme.dark : GardenTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: GamePage(
                services: device,
                activity: activity,
                sound: true,
                round: round,
                onCompleteRound: (_) async => rewardResult(1),
              ),
            ),
          );
          await settle(tester);
          final seenKinds = <NumberRepresentation>{};
          for (var i = 0; i < 5; i++) {
            final q = round.question;
            if (q.visual is SameNumberVisual) {
              seenKinds.add((q.visual! as SameNumberVisual).missingKind);
            }
            expect(find.text('?'), findsOneWidget);
            await tapVisible(tester, find.text('Show a hint'));
            for (final choice in q.choices) {
              final card = find.byKey(ValueKey('choice-$choice'));
              final size = tester.getSize(card);
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
              if (activity == Activity.numberParts) {
                expect(size.height, lessThanOrEqualTo(140));
                final firstCard = find.byKey(
                  ValueKey('choice-${q.choices.first}'),
                );
                expect(
                  tester.getTopLeft(card).dy,
                  tester.getTopLeft(firstCard).dy,
                );
              }
              expect(
                find.bySemanticsLabel(q.visual!.choiceLabel(choice)),
                findsWidgets,
              );
            }
            final wrong = q.choices.firstWhere((choice) => choice != q.answer);
            await tapVisible(tester, find.byKey(ValueKey('choice-$wrong')));
            expect(round.answered, isFalse);
            await tapVisible(
              tester,
              find.byKey(ValueKey('choice-${q.answer}')),
            );
            expect(round.answered, isTrue);
            expect(find.text('?'), findsNothing);
            if (q.visual is NumberPartsVisual) {
              final v = q.visual! as NumberPartsVisual;
              expect(
                find.text('${v.part} + ${v.missing} = ${v.total}'),
                findsOneWidget,
              );
            }
            expect(device.clips, isEmpty);
            expect(tester.takeException(), isNull);
            if (i < 4) await tapVisible(tester, find.text('Next'));
          }
          if (activity == Activity.sameNumber) {
            expect(seenKinds, NumberRepresentation.values.toSet());
          }
          expect(find.text('50 XP earned!'), findsOneWidget);
          expect(device.clips, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
        },
      );
    }
  }
}
