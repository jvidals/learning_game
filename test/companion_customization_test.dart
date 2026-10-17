import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/screens/companion_page.dart';
import 'package:rainbow_garden/widgets/companion_choices.dart';
import 'progress_test.dart' show SlowDevice;
import 'widget_test.dart' show MemoryDevice, tapVisible, settle;

Finder choice(RewardCategory category, String id) =>
    find.byKey(ValueKey('companion-choice-${category.name}-$id'));
Finder get preview => find.byKey(const ValueKey('customization-preview'));

Future<ProgressController> openCompanion(
  WidgetTester tester,
  MemoryDevice d,
) async {
  final c = ProgressController(d);
  await c.load();
  await tester.pumpWidget(MaterialApp(home: CompanionPage(controller: c)));
  await settle(tester);
  addTearDown(c.dispose);
  return c;
}

Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CompanionCategoryTabs),
      matching: find.bySemanticsLabel(label),
    ),
  );
  await tester.pump();
}

PlayerProgress collection({Set<String>? owned}) => PlayerProgress(
  xp: xpForLevel(rewardCatalog.length + 1),
  earnedRewardChoices: rewardCatalog.length,
  lastRewardedRound: 'fixture',
  owned: owned ?? rewardCatalog.map((r) => r.id).toSet(),
);

void main() {
  testWidgets(
    'picture tabs show owned choices and preserve the visible preview',
    (tester) async {
      final d = MemoryDevice()
        ..document = collection(owned: {'blue', 'flower'}).encode();
      final c = await openCompanion(tester, d);
      expect(choice(RewardCategory.mane, ''), findsOneWidget);
      expect(choice(RewardCategory.mane, 'blue'), findsOneWidget);
      expect(choice(RewardCategory.mane, 'mint'), findsNothing);
      await tapVisible(tester, choice(RewardCategory.mane, 'blue'));
      expect(c.progress!.companion[RewardCategory.mane], 'blue');
      expect(
        tester
            .widget<CompanionChoiceCard>(choice(RewardCategory.mane, 'blue'))
            .selected,
        isTrue,
      );
      await tab(tester, 'Headwear');
      expect(
        tester.widget<CompanionView>(preview).framing,
        CompanionFraming.head,
      );
      expect(choice(RewardCategory.accessory, 'bow'), findsNothing);
      await tapVisible(tester, choice(RewardCategory.accessory, 'flower'));
      expect(c.progress!.companion[RewardCategory.accessory], 'flower');
      await tapVisible(tester, choice(RewardCategory.accessory, ''));
      expect(c.progress!.companion[RewardCategory.accessory], isNull);
      await tab(tester, 'Wings');
      expect(
        tester.widget<CompanionView>(preview).framing,
        CompanionFraming.wings,
      );
      expect(choice(RewardCategory.wings, ''), findsOneWidget);
      await tab(tester, 'Celebrations');
      expect(
        tester.widget<CompanionView>(preview).framing,
        CompanionFraming.full,
      );
      expect(tester.getRect(preview).top, greaterThanOrEqualTo(0));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: CompanionPage(controller: c)));
      await settle(tester);
      expect(
        tester
            .widget<CompanionView>(preview)
            .configuration[RewardCategory.mane],
        'blue',
      );
      expect(
        PlayerProgress.decode(d.document).companion[RewardCategory.accessory],
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'equipment is published only after saving and rapid taps cannot overlap',
    (tester) async {
      final d = SlowDevice()..document = collection().encode();
      final c = await openCompanion(tester, d);
      d.pending = Completer<void>();
      await tester.tap(choice(RewardCategory.mane, 'blue'));
      await tester.pump();
      expect(c.writing, isTrue);
      expect(
        tester
            .widget<CompanionView>(preview)
            .configuration[RewardCategory.mane],
        isNull,
      );
      expect(
        tester
            .widget<CompanionChoiceCard>(choice(RewardCategory.mane, ''))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<CompanionChoiceCard>(choice(RewardCategory.mane, 'blue'))
            .onPressed,
        isNull,
      );
      d.pending!.complete();
      await settle(tester);
      expect(c.progress!.companion[RewardCategory.mane], 'blue');
      expect(
        tester
            .widget<CompanionChoiceCard>(choice(RewardCategory.mane, 'blue'))
            .selected,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed equipment save retries after reopening the page', (
    tester,
  ) async {
    final d = MemoryDevice()..document = collection().encode();
    final c = await openCompanion(tester, d);
    d.failSave = true;
    await tapVisible(tester, choice(RewardCategory.mane, 'blue'));
    expect(c.progress!.companion[RewardCategory.mane], isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: CompanionPage(controller: c)));
    await settle(tester);
    d.failSave = false;
    await tapVisible(tester, find.text('Try saving again'));
    expect(c.progress!.companion[RewardCategory.mane], 'blue');
    expect(
      tester.widget<CompanionView>(preview).configuration[RewardCategory.mane],
      'blue',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'gift pictures collect once, close after saving and select the matching tab',
    (tester) async {
      final d = MemoryDevice()..xp = 150;
      final c = await openCompanion(tester, d);
      expect(
        find.bySemanticsLabel('Choose a unicorn surprise (2 ready)'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Choose a unicorn surprise (2 ready)'));
      await settle(tester);
      await tapVisible(tester, choice(RewardCategory.accessory, 'flower'));
      await settle(tester);
      expect(find.byTooltip('Close gifts'), findsNothing);
      expect(c.progress!.owned, {'flower'});
      expect(c.progress!.availableChoices, 1);
      expect(
        tester
            .widget<CompanionChoiceCard>(
              choice(RewardCategory.accessory, 'flower'),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<CompanionView>(preview)
            .configuration[RewardCategory.accessory],
        'flower',
      );
      expect(
        find.byTooltip('Choose a unicorn surprise (1 ready)'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'gift failure keeps the picker open and retry completes collection',
    (tester) async {
      final d = MemoryDevice()..xp = 50;
      final c = await openCompanion(tester, d);
      await tester.tap(find.byTooltip('Choose a unicorn surprise (1 ready)'));
      await settle(tester);
      d.failSave = true;
      await tapVisible(tester, choice(RewardCategory.accessory, 'flower'));
      expect(c.progress!.owned, isEmpty);
      expect(find.byTooltip('Close gifts'), findsOneWidget);
      d.failSave = false;
      // The sheet's retry is the last copy; the page keeps its own retry too.
      await tapVisible(tester, find.text('Try saving again').last);
      await settle(tester);
      expect(c.progress!.owned, {'flower'});
      expect(find.byTooltip('Close gifts'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'celebration demonstrations finish, replay and stop on backgrounding',
    (tester) async {
      final d = MemoryDevice()..document = collection().encode();
      await openCompanion(tester, d);
      await tab(tester, 'Celebrations');
      await tapVisible(tester, choice(RewardCategory.behavior, 'hop'));
      CompanionPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: preview,
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as CompanionPainter;
      expect(painter().celebrating, isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(painter().celebrating, isFalse);
      await tapVisible(tester, find.text('Preview celebration'));
      expect(painter().celebrating, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(painter().celebrating, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(painter().celebrating, isFalse);
      await tab(tester, 'Colors');
      expect(painter().celebrating, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('closing a gift during its save never pops the companion page', (
    tester,
  ) async {
    final d = SlowDevice()..xp = 50;
    final c = await openCompanion(tester, d);
    await tester.tap(find.byTooltip('Choose a unicorn surprise (1 ready)'));
    await settle(tester);
    d.pending = Completer<void>();
    await tester.tap(choice(RewardCategory.mane, 'blue'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close gifts'));
    // Finish while the sheet is still mounted for its exit animation.
    d.pending!.complete();
    await settle(tester);
    expect(find.byType(CompanionPage), findsOneWidget);
    expect(find.byTooltip('Close gifts'), findsNothing);
    expect(c.progress!.owned, {'blue'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'picture controls expose selected state and accessible tap targets',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final d = MemoryDevice()..document = collection().encode();
      await openCompanion(tester, d);
      expect(
        tester.getSemantics(choice(RewardCategory.mane, '')),
        matchesSemantics(
          label: 'Pink mane',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(640, 320),
    const Size(800, 1100),
  ]) {
    testWidgets('all picture choices remain reachable at $size and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final d = MemoryDevice()..document = collection().encode();
      final c = await openCompanion(tester, d);
      final fatalTaps = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal = fatalTaps,
      );
      for (final category in RewardCategory.values) {
        final target = find.descendant(
          of: find.byType(CompanionCategoryTabs),
          matching: find.bySemanticsLabel(categoryLabel(category)),
        );
        expect(tester.getSize(target).width, greaterThanOrEqualTo(64));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(64));
        await tab(tester, categoryLabel(category));
        final before = tester.getRect(preview);
        for (final reward in rewardCatalog.where(
          (r) => r.category == category,
        )) {
          final card = choice(category, reward.id);
          // Very tall large-text cards can exceed the scroll viewport. Bring
          // their center into view and require an actual successful selection.
          await Scrollable.ensureVisible(tester.element(card), alignment: .5);
          await settle(tester);
          await tester.tap(card);
          await settle(tester);
          expect(c.progress!.companion[category], reward.id);
          expect(tester.getSize(card).width, greaterThanOrEqualTo(88));
          expect(tester.takeException(), isNull);
          expect(tester.getRect(preview), before);
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'polish retries across tabs, persists independently and can be removed',
    (tester) async {
      final device = MemoryDevice()..document = collection().encode();
      final c = await openCompanion(tester, device);
      await tapVisible(tester, choice(RewardCategory.mane, 'blue'));
      await tab(tester, 'Nail polish');
      expect(
        tester.widget<CompanionView>(preview).framing,
        CompanionFraming.full,
      );
      device.failSave = true;
      await tapVisible(tester, choice(RewardCategory.polish, 'polish_teal'));
      expect(c.progress!.companion[RewardCategory.polish], isNull);
      expect(c.progress!.companion[RewardCategory.mane], 'blue');
      expect(c.blocked.value, isTrue);
      await tab(tester, 'Colors');
      device.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(c.progress!.companion[RewardCategory.polish], 'polish_teal');
      await tester.pumpWidget(const SizedBox());
      final reopened = await openCompanion(tester, device);
      expect(reopened.progress!.companion[RewardCategory.mane], 'blue');
      expect(
        reopened.progress!.companion[RewardCategory.polish],
        'polish_teal',
      );
      await tab(tester, 'Nail polish');
      expect(
        tester
            .widget<CompanionChoiceCard>(
              choice(RewardCategory.polish, 'polish_teal'),
            )
            .selected,
        isTrue,
      );
      await tapVisible(tester, choice(RewardCategory.polish, ''));
      expect(reopened.progress!.companion[RewardCategory.polish], isNull);
      expect(reopened.progress!.companion[RewardCategory.mane], 'blue');
      expect(reopened.progress!.owned, contains('polish_teal'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('new players have natural hooves and no free polish rewards', (
    tester,
  ) async {
    final c = await openCompanion(tester, MemoryDevice());
    await tab(tester, 'Nail polish');
    expect(choice(RewardCategory.polish, ''), findsOneWidget);
    expect(choice(RewardCategory.polish, 'polish_pink'), findsNothing);
    expect(c.progress!.companion[RewardCategory.polish], isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
