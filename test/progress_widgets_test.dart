import 'package:rainbow_garden/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/companion.dart';
import 'package:rainbow_garden/main.dart';
import 'widget_test.dart' show MemoryDevice, tapVisible, settle;
import 'settings_test.dart' show unlock;

Future<void> finishLearning(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tapVisible(tester, find.text('Show a hint'));
    final target = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((s) => RegExp(r'^Find [A-Za-z0-9]+$').hasMatch(s))
        .substring(5);
    await tapVisible(tester, find.byKey(ValueKey('choice-$target')));
    await tapVisible(tester, find.text(i == 4 ? 'Rewards' : 'Next'));
  }
}

void main() {
  testWidgets('learning reward choice returns to root home', (tester) async {
    final d = MemoryDevice();
    await tester.pumpWidget(RainbowGardenApp(services: d));
    await settle(tester);
    await tapVisible(tester, find.text('Letters'));
    await tapVisible(tester, find.text(Activity.uppercase.title));
    await finishLearning(tester);
    expect(d.xp, 50);
    await tapVisible(tester, find.text('Blue mane'));
    expect(PlayerProgress.decode(d.document).owned, {'blue'});
    expect(
      tester
          .widget<CompanionView>(find.byType(CompanionView).last)
          .configuration[RewardCategory.mane],
      'blue',
    );
    expect(find.text('Adventure'), findsNothing);
    await tapVisible(tester, find.text('Back to home'));
    expect(find.text('Hi, Player 1!'), findsOneWidget);
    expect(find.text(Activity.uppercase.title), findsNothing);
  });
  testWidgets(
    'failed fifth-answer save survives navigation and retries on home',
    (tester) async {
      final d = MemoryDevice();
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      await tapVisible(tester, find.text('Numbers'));
      await tapVisible(tester, find.text(Activity.numbers.title));
      d.failSave = true;
      for (var i = 0; i < 5; i++) {
        final clip = d.clips.lastWhere((s) => s.startsWith('number_'));
        await tapVisible(
          tester,
          find.byKey(ValueKey('choice-${clip.substring(7)}')),
        );
        if (i < 4) await tapVisible(tester, find.text('Next'));
      }
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(d.xp, 0);
      expect(find.text('Try saving again'), findsOneWidget);
      d.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(d.xp, 50);
      expect(find.text('Level 2'), findsOneWidget);
    },
  );
  testWidgets(
    'malformed progress exposes parent-gated reset and preserves settings',
    (tester) async {
      final d = MemoryDevice()
        ..document = 'broken'
        ..haptics = false;
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      expect(d.document, 'broken');
      await unlock(tester);
      await tapVisible(tester, find.text('Reset progress'));
      await tapVisible(tester, find.text('Reset progress').last);
      expect(d.xp, 0);
      expect(d.haptics, isFalse);
    },
  );
  testWidgets('every companion unlock renders together without exceptions', (
    tester,
  ) async {
    for (var i = 0; i < 3; i++) {
      final configuration = CompanionConfiguration({
        for (final category in RewardCategory.values)
          category: rewardCatalog
              .where((r) => r.category == category)
              .elementAt(i)
              .id,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CompanionView(configuration: configuration, reactionTrigger: 1),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
