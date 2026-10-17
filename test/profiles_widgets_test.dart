import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/profiles.dart';
import 'package:rainbow_garden/widgets/profile_portrait.dart';
import 'interface_layout_test.dart' show capture, captureApp;
import 'profiles_test.dart' show ProfileDevice;
import 'settings_test.dart' show unlock;
import 'widget_test.dart' show MemoryDevice, settle, tapVisible;

final picker = find.byKey(const ValueKey('profile-picker'));
Future<void> passGate(WidgetTester tester) async {
  final challenge = tester
      .widget<Text>(find.byKey(const ValueKey('parent-challenge')))
      .data!;
  final values = RegExp(
    r'\d+',
  ).allMatches(challenge).map((m) => int.parse(m[0]!)).toList();
  await tester.enterText(find.byType(TextField), '${values[0] * values[1]}');
  await tapVisible(tester, find.text('Continue'));
}

Future<void> add(WidgetTester tester, String name) async {
  await tapVisible(tester, picker);
  await tapVisible(tester, find.text('Add player'));
  await passGate(tester);
  await tester.enterText(find.byType(TextField), name);
  await tapVisible(tester, find.text('Save'));
}

MemoryDevice fixture({int count = 3}) {
  final players = List.generate(
    count,
    (index) => PlayerProfile(
      id: 'player-$index',
      name: index == 0 ? 'Alexandra Rainbow Garden' : 'Player ${index + 1}',
      settings: const AppSettings(),
      progressDocument: PlayerProgress(
        xp: xpForLevel(rewardCatalog.length + 1),
        earnedRewardChoices: rewardCatalog.length,
        lastRewardedRound: 'seed-$index',
        owned: rewardCatalog.map((r) => r.id).toSet(),
        companion: CompanionConfiguration({
          RewardCategory.mane: ['blue', 'mint', 'gold'][index % 3],
          RewardCategory.accessory: ['bow', 'flower', 'star'][index % 3],
        }),
      ).encode(),
    ),
  );
  return MemoryDevice()
    ..profileDocument = ProfileStore(
      activeId: players.first.id,
      players: players,
    ).encode();
}

void main() {
  setUpAll(() async {
    await FoalAssets.load();
    final fonts = Directory(
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
    );
    for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
      final loader = FontLoader(family);
      for (final weight
          in family == 'MaterialIcons'
              ? ['Regular']
              : ['Regular', 'Medium', 'Bold', 'Black']) {
        loader.addFont(
          File(
            '${fonts.path}/${family == 'MaterialIcons' ? 'MaterialIcons' : 'Roboto'}-$weight.${family == 'MaterialIcons' ? 'otf' : 'ttf'}',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });

  testWidgets(
    'add is gated, invalid name stays open, switching is free and remembered',
    (tester) async {
      final d = MemoryDevice()
        ..xp = 150
        ..soundOn = false;
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      await tapVisible(tester, picker);
      expect(find.text('Player 1'), findsOneWidget);
      await tapVisible(tester, find.text('Add player'));
      await tester.enterText(find.byType(TextField), '0');
      await tapVisible(tester, find.text('Continue'));
      expect(find.text('Try again.'), findsOneWidget);
      await passGate(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tapVisible(tester, find.text('Save'));
      expect(find.text('Use a name with 1–24 characters.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Sam');
      await tapVisible(tester, find.text('Save'));
      await settle(tester);
      expect(find.text('Players'), findsNothing);
      expect(find.text('Hi, Sam!'), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.byTooltip('Turn sound off'), findsOneWidget);
      await tapVisible(tester, picker);
      await tapVisible(tester, find.text('Player 1'));
      await settle(tester);
      expect(find.text('Grown-ups only'), findsNothing);
      expect(find.text('Level 3'), findsOneWidget);
      expect(find.byTooltip('Turn sound on'), findsOneWidget);
      expect(ProfileStore.decode(d.profileDocument!).active.name, 'Player 1');
      expect(find.text('Hi, Player 1!'), findsOneWidget);
    },
  );

  testWidgets(
    'edit cancel, rename, delete cancel and confirmed delete preserve other player',
    (tester) async {
      final d = MemoryDevice()..xp = 150;
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      await add(tester, 'Sam');
      await settle(tester);
      await tapVisible(tester, picker);
      await tapVisible(tester, find.byTooltip('Edit Sam'));
      await passGate(tester);
      await tester.enterText(find.byType(TextField), 'Discard');
      await tapVisible(tester, find.text('Cancel'));
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Hi, Sam!', skipOffstage: false), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Edit Sam'));
      await passGate(tester);
      await tester.enterText(find.byType(TextField), 'Robin');
      await tapVisible(tester, find.text('Save'));
      expect(find.text('Robin'), findsOneWidget);
      expect(find.text('Hi, Robin!', skipOffstage: false), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Edit Robin'));
      await passGate(tester);
      await tapVisible(tester, find.text('Delete player'));
      await tapVisible(tester, find.text('Cancel'));
      expect(ProfileStore.decode(d.profileDocument!).players.length, 2);
      await tapVisible(tester, find.byTooltip('Edit Robin'));
      await passGate(tester);
      await tapVisible(tester, find.text('Delete player'));
      expect(find.text('Delete Robin?'), findsOneWidget);
      await tapVisible(tester, find.text('Delete player'));
      await settle(tester);
      expect(find.text('Level 3'), findsOneWidget);
      await tapVisible(tester, picker);
      await tapVisible(tester, find.byTooltip('Edit Player 1'));
      await passGate(tester);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Delete player'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'pending add can close picker and retry from Home without duplicate players',
    (tester) async {
      final d = ProfileDevice();
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      d.gate = Completer<void>();
      await add(tester, 'Sam');
      expect(ProfileStore.decode(d.profileDocument!).players.length, 1);
      await tapVisible(tester, find.byTooltip('Close players'));
      d.failSave = true;
      d.gate!.complete();
      await settle(tester);
      expect(tester.widget<IconButton>(picker).onPressed, isNull);
      d.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(ProfileStore.decode(d.profileDocument!).players.length, 2);
      expect(find.byTooltip('Players: Sam'), findsOneWidget);
      expect(find.text('Hi, Sam!'), findsOneWidget);
    },
  );

  testWidgets(
    'greeting keeps saved name through pending rename, failure, retry and restart',
    (tester) async {
      final d = ProfileDevice();
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      await add(tester, 'Sam');
      await tapVisible(tester, picker);
      await tapVisible(tester, find.byTooltip('Edit Sam'));
      await passGate(tester);
      await tester.enterText(find.byType(TextField), 'Robin');
      d.gate = Completer<void>();
      await tapVisible(tester, find.text('Save'));
      await tapVisible(tester, find.byTooltip('Close players'));
      expect(find.text('Hi, Sam!'), findsOneWidget);
      expect(find.text('Hi, Robin!'), findsNothing);
      d.failSave = true;
      d.gate!.complete();
      await settle(tester);
      expect(find.text('Hi, Sam!'), findsOneWidget);
      expect(tester.widget<IconButton>(picker).onPressed, isNull);
      d.failSave = false;
      await tapVisible(tester, find.text('Try saving again'));
      expect(find.text('Hi, Robin!'), findsOneWidget);
      expect(ProfileStore.decode(d.profileDocument!).active.name, 'Robin');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RainbowGardenApp(services: d));
      await settle(tester);
      expect(find.text('Hi, Robin!'), findsOneWidget);
      expect(d.clips, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('settings identify player and reset only that player', (
    tester,
  ) async {
    final d = fixture(count: 2);
    await tester.pumpWidget(RainbowGardenApp(services: d));
    await settle(tester);
    await unlock(tester);
    expect(find.text('Settings for Alexandra Rainbow Garden'), findsOneWidget);
    await tapVisible(tester, find.text('Reset progress'));
    expect(
      find.text('Reset Alexandra Rainbow Garden’s progress?'),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Reset progress').last);
    final store = ProfileStore.decode(d.profileDocument!);
    expect(store.active.progress.xp, 0);
    expect(
      store.players.last.progress.xp,
      xpForLevel(rewardCatalog.length + 1),
    );
  });

  testWidgets(
    'profile semantics expose current name and editing; portraits are decorative',
    (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(RainbowGardenApp(services: fixture()));
      await settle(tester);
      expect(
        find.byTooltip('Players: Alexandra Rainbow Garden'),
        findsOneWidget,
      );
      expect(tester.getSize(picker).shortestSide, greaterThanOrEqualTo(56));
      await tapVisible(tester, picker);
      expect(find.byTooltip('Edit Alexandra Rainbow Garden'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Current player')), findsWidgets);
      expect(
        await tester.runAsync(() async => FoalAssets.ready?.decodedBytes ?? 0),
        lessThanOrEqualTo(FoalAssets.memoryLimit),
      );
      handle.dispose();
    },
  );

  for (final (name, size) in [
    ('small', const Size(320, 640)),
    ('phone', const Size(393, 852)),
    ('landscape', const Size(740, 360)),
    ('tablet', const Size(800, 1100)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('minimal picker and editor fit $name at $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: captureApp(fixture(count: 9))),
        );
        await settle(tester);
        await capture(tester, key, '$name-${scale}x-home', directory: '0110');
        await tapVisible(tester, picker);
        expect(tester.takeException(), isNull);
        await capture(tester, key, '$name-${scale}x-picker', directory: '0110');
        await tapVisible(
          tester,
          find.byTooltip('Edit Alexandra Rainbow Garden'),
        );
        await passGate(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, key, '$name-${scale}x-editor', directory: '0110');
        // Keyboard inset must keep the name and Save reachable.
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.text('Cancel'));
        tester.view.resetViewInsets();
        await settle(tester);
        await tester.scrollUntilVisible(
          find.text('Player 9'),
          160,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final row = find
            .ancestor(of: find.text('Player 9'), matching: find.byType(InkWell))
            .first;
        await tapVisible(
          tester,
          find.descendant(of: row, matching: find.byType(ProfilePortrait)),
        );
        await settle(tester);
        expect(find.byTooltip('Players: Player 9'), findsOneWidget);
      });
    }
  }

  testWidgets('failed saves stay reachable in landscape at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = MemoryDevice();
    await tester.pumpWidget(RainbowGardenApp(services: d));
    await settle(tester);
    d.failSave = true;
    await add(tester, 'Sam');
    expect(tester.takeException(), isNull);
    expect(find.text('Try saving again'), findsWidgets);
    await tapVisible(tester, find.byTooltip('Close players'));
    d.failSave = false;
    await tapVisible(tester, find.text('Try saving again'));
    expect(find.byTooltip('Players: Sam'), findsOneWidget);
  });

  testWidgets('all mane and headwear portraits use shared static art', (
    tester,
  ) async {
    await tester.runAsync(FoalAssets.load);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Wrap(
              children: [
                for (final mane in [null, 'blue', 'mint', 'gold'])
                  for (final head in [null, 'flower', 'bow', 'star'])
                    ProfilePortrait(
                      size: 100,
                      configuration: CompanionConfiguration({
                        RewardCategory.mane: ?mane,
                        RewardCategory.accessory: ?head,
                        RewardCategory.wings: 'rainbow',
                      }),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(ProfilePortrait), findsNWidgets(16));
    expect(
      FoalAssets.ready!.decodedBytes,
      lessThanOrEqualTo(FoalAssets.memoryLimit),
    );
    await capture(tester, key, 'portraits', directory: '0110');
    expect(tester.takeException(), isNull);
  });
}
