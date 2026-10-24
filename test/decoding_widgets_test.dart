import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/widgets/decoding_visuals.dart';
import 'package:rainbow_garden/widgets/sound_it_out.dart';
import 'package:rainbow_garden/widgets/voice_button.dart';
import 'package:rainbow_garden/word_bank.dart';

import 'widget_test.dart' show MemoryDevice, rewardResult, settle, tapVisible;

class HeldDevice extends MemoryDevice {
  Completer<void>? hold;
  @override
  Future<void> play(String clip) async {
    await super.play(clip);
    await hold?.future;
  }
}

Future<GameRound> openGame(
  WidgetTester tester,
  MemoryDevice device,
  Activity activity, {
  bool largeDark = false,
}) async {
  final round = GameRound(activity, random: Random(12));
  await tester.pumpWidget(
    MaterialApp(
      theme: largeDark ? GardenTheme.dark : GardenTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(largeDark ? 2 : 1),
          disableAnimations: largeDark,
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
  return round;
}

void main() {
  testWidgets(
    'read pictures are silent, hint explicit, meaning appears on answer',
    (tester) async {
      final d = MemoryDevice();
      final round = await openGame(tester, d, Activity.readAndFind);
      expect(find.byType(ReadAndFindChoice), findsNWidgets(3));
      for (final choice in round.question.choices) {
        expect(
          find.image(AssetImage(realWord(choice).pictureAsset!)),
          findsOneWidget,
        );
        expect(find.text(realWord(choice).label!), findsNothing);
      }
      expect(d.clips, isEmpty);
      expect(find.byType(SoundItOut), findsNothing);
      await tapVisible(tester, find.text('Show a hint'));
      expect(find.byType(SoundItOut), findsOneWidget);
      expect(d.clips, isEmpty);
      await tapVisible(tester, find.text('Sound it out'));
      final word = realWord(round.question.answer);
      expect(d.clips, [...word.letterSounds.expand((s) => s), word.clip]);
      await tapVisible(
        tester,
        find.byKey(ValueKey('choice-${round.question.answer}')),
      );
      expect(
        find.image(AssetImage(realWord(round.question.answer).pictureAsset!)),
        findsNWidgets(2),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final spelling in ['cat', 'fox']) {
    testWidgets(
      '$spelling hint plays sounds then word and highlights each step',
      (tester) async {
        final steps = <List<String>>[];
        final pending = <Completer<void>>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SoundItOut(
                word: realWord(spelling),
                playSequence: (sequence, {onStep}) async {
                  for (var i = 0; i < sequence.length; i++) {
                    onStep?.call(i);
                    steps.add(sequence[i]);
                    final hold = Completer<void>();
                    pending.add(hold);
                    await hold.future;
                  }
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Sound it out'));
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          final tile = tester.widget<Semantics>(
            find.byKey(ValueKey('sound-letter-$i')),
          );
          expect(tile.properties.selected, isTrue);
          pending.last.complete();
          await tester.pump();
        }
        expect(
          find.byKey(const ValueKey('whole-word-underline')),
          findsOneWidget,
        );
        pending.last.complete();
        await tester.pumpAndSettle();
        expect(
          steps.expand((s) => s),
          spelling == 'cat'
              ? ['sound_k', 'sound_a', 'sound_t', 'cvc_cat']
              : ['sound_f', 'sound_o', 'sound_k', 'sound_s', 'cvc_fox'],
        );
        expect(
          find.byKey(const ValueKey('whole-word-underline')),
          findsNothing,
        );
        for (var i = 0; i < 3; i++) {
          expect(
            tester
                .widget<Semantics>(find.byKey(ValueKey('sound-letter-$i')))
                .properties
                .selected,
            isFalse,
          );
        }
      },
    );
  }

  testWidgets('pretend x hint keeps two clips in its final letter step', (
    tester,
  ) async {
    final steps = <List<String>>[];
    final pending = <Completer<void>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoundItOut(
            word: const DecodableWord('dax'),
            includeWholeWord: false,
            playSequence: (sequence, {onStep}) async {
              for (var i = 0; i < sequence.length; i++) {
                onStep?.call(i);
                steps.add(sequence[i]);
                final hold = Completer<void>();
                pending.add(hold);
                await hold.future;
              }
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sound it out'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      expect(steps, hasLength(i + 1));
      expect(
        tester
            .widget<Semantics>(find.byKey(ValueKey('sound-letter-$i')))
            .properties
            .selected,
        isTrue,
      );
      expect(find.byKey(const ValueKey('whole-word-underline')), findsNothing);
      pending.last.complete();
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(steps, [
      ['sound_d'],
      ['sound_a'],
      ['sound_k', 'sound_s'],
    ]);
    expect(steps.expand((clips) => clips), [
      'sound_d',
      'sound_a',
      'sound_k',
      'sound_s',
    ]);
    expect(find.byKey(const ValueKey('whole-word-underline')), findsNothing);
    for (var i = 0; i < 3; i++) {
      expect(
        tester
            .widget<Semantics>(find.byKey(ValueKey('sound-letter-$i')))
            .properties
            .selected,
        isFalse,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'single letter taps play its clips and dispose safely mid-sequence',
    (tester) async {
      final hold = Completer<bool>();
      List<List<String>>? played;
      void Function(int)? callback;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoundItOut(
              word: realWord('fox'),
              playSequence: (steps, {onStep}) {
                played = steps;
                callback = onStep;
                onStep?.call(0);
                return hold.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('sound-letter-2')));
      await tester.pump();
      expect(played, [
        ['sound_k', 'sound_s'],
      ]);
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('sound-letter-2')))
            .properties
            .selected,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      callback?.call(0);
      hold.complete(false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pretend hint omits whole word; muted controls explain sound', (
    tester,
  ) async {
    final d = MemoryDevice();
    final r = await openGame(tester, d, Activity.makeBelieve);
    expect(find.text('Make-believe'), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      expect(find.text('Sound $i'), findsOneWidget);
    }
    final choice = r.question.choices.first;
    await tapVisible(tester, find.byKey(ValueKey('choice-$choice')));
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(d.clips, [makeBelieveWord(choice).clip]);
    d.clips.clear();
    await tapVisible(tester, find.text('Show a hint'));
    expect(
      tester.widget<SoundItOut>(find.byType(SoundItOut)).includeWholeWord,
      isFalse,
    );
    await tapVisible(tester, find.text('Sound it out'));
    expect(
      d.clips,
      makeBelieveWord(r.question.answer).letterSounds.expand((s) => s),
    );
    tester.widget<VoiceButton>(find.byType(VoiceButton)).onPressed!();
    await settle(tester);
    expect(find.text('Turn on sound to hear the choices.'), findsOneWidget);
    expect(find.text('Turn on sound to hear it.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Sound it out'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    for (var i = 0; i < 3; i++) {
      final tile = tester.widget<Semantics>(
        find.byKey(ValueKey('sound-letter-$i')),
      );
      expect(tile.properties.enabled, isFalse);
      expect(tile.properties.onTap, isNull);
      expect(tile.properties.label, 'Letter ${r.question.answer[i]}');
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('muting cancels the visible highlight during held playback', (
    tester,
  ) async {
    final d = HeldDevice();
    await openGame(tester, d, Activity.readAndFind);
    await tapVisible(tester, find.text('Show a hint'));
    d.hold = Completer<void>();
    await tapVisible(tester, find.text('Sound it out'));
    final tile = find.byKey(const ValueKey('sound-letter-0'));
    expect(tester.widget<Semantics>(tile).properties.selected, isTrue);
    tester.widget<VoiceButton>(find.byType(VoiceButton)).onPressed!();
    await settle(tester);
    expect(tester.widget<Semantics>(tile).properties.selected, isFalse);
    d.hold!.complete();
    await settle(tester);
    expect(d.clips, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion uses a static whole-word underline', (
    tester,
  ) async {
    final hold = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SoundItOut(
              word: realWord('cat'),
              playSequence: (steps, {onStep}) {
                onStep?.call(3);
                return hold.future;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sound it out'));
    await tester.pump();
    final underline = find.descendant(
      of: find.byKey(const ValueKey('whole-word-underline')),
      matching: find.byType(FractionallySizedBox),
    );
    expect(tester.widget<FractionallySizedBox>(underline).widthFactor, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<FractionallySizedBox>(underline).widthFactor, 1);
    hold.complete(false);
    await tester.pump();
    expect(find.byKey(const ValueKey('whole-word-underline')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled hints keep letters visible and never play', (
    tester,
  ) async {
    var plays = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoundItOut(
            word: realWord('cat'),
            enabled: false,
            playSequence: (steps, {onStep}) async {
              plays++;
              return true;
            },
          ),
        ),
      ),
    );
    expect(find.text('Turn on sound to hear it.'), findsNothing);
    expect(find.bySemanticsLabel('Letter c'), findsOneWidget);
    await tester.tap(find.text('Sound it out'));
    await tester.tap(find.byKey(const ValueKey('sound-letter-0')));
    await tester.pump();
    expect(plays, 0);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  for (final activity in [Activity.readAndFind, Activity.makeBelieve]) {
    testWidgets(
      '${activity.name} handles dark reduced motion and 2x phone text',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await openGame(tester, MemoryDevice(), activity, largeDark: true);
        await tapVisible(tester, find.text('Show a hint'));
        await tester.ensureVisible(find.text('Sound it out'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
