import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_settings.dart';
import 'package:rainbow_garden/decoding.dart';
import 'package:rainbow_garden/game.dart';
import 'package:rainbow_garden/main.dart';
import 'package:rainbow_garden/progress.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/screens/game_page.dart';
import 'package:rainbow_garden/screens/word_sprint_page.dart';
import 'package:rainbow_garden/widgets/decoding_visuals.dart';
import 'package:rainbow_garden/widgets/activity_illustration.dart';
import 'package:rainbow_garden/widgets/number_visuals.dart';
import 'package:rainbow_garden/widgets/selection_card.dart';
import 'package:rainbow_garden/widgets/visual_question.dart';
import 'package:rainbow_garden/widgets/voice_button.dart';
import 'widget_test.dart' show MemoryDevice, rewardResult, settle, tapVisible;

const visualActivities = [
  Activity.readAndFind,
  Activity.makeBelieve,
  Activity.sameNumber,
  Activity.numberParts,
];

class SequenceDevice extends MemoryDevice {
  Completer<void>? hold;
  bool loseAcknowledgement = false;
  @override
  Future<void> play(String clip) async {
    await super.play(clip);
    await hold?.future;
  }

  @override
  Future<void> saveProfiles(String value) async {
    await super.saveProfiles(value);
    if (loseAcknowledgement) throw StateError('Lost acknowledgement');
  }
}

class UnknownVisual extends QuestionVisual {
  const UnknownVisual();
}

Future<GameRound> openVisual(
  WidgetTester tester,
  MemoryDevice device,
  Activity activity, {
  ProgressController? controller,
}) async {
  final round = GameRound(activity, random: Random(12));
  await tester.pumpWidget(
    MaterialApp(
      home: GamePage(
        services: device,
        activity: activity,
        sound: true,
        round: round,
        controller: controller,
        onCompleteRound: (_) async => rewardResult(1),
      ),
    ),
  );
  await settle(tester);
  return round;
}

VisualQuestionContext visualContext(WidgetTester tester) =>
    tester.widget<MakeBelievePrompt>(find.byType(MakeBelievePrompt)).context;

void main() {
  test('new activities append in order with their categories and metadata', () {
    expect(Activity.values.skip(13), [
      Activity.readAndFind,
      Activity.makeBelieve,
      Activity.wordSprint,
      Activity.sameNumber,
      Activity.numberParts,
      Activity.cursive,
      Activity.sketchPad,
    ]);
    expect(GameCategory.artHub.activities, [Activity.sketchPad]);
    expect(GameCategory.writing.activities, [
      Activity.handwriting,
      Activity.cursive,
    ]);
    expect(GameCategory.words.activities, [
      Activity.sightWords,
      Activity.readAndFind,
      Activity.makeBelieve,
      Activity.wordSprint,
    ]);
    expect(GameCategory.numbers.activities, [
      Activity.numbers,
      Activity.numberOrder,
      Activity.game2048,
      Activity.howMany,
      Activity.makeGroup,
      Activity.sameNumber,
      Activity.numberParts,
    ]);
    final titles = [
      'Read and Find',
      'Make-Believe Words',
      'Word Sprint',
      'Same Number',
      'Number Parts',
      'Cursive Play',
      'Sketch Pad',
    ];
    final examples = ['cat', 'pib', 'pos', '5', '2+3', 'ce', ''];
    final added = Activity.values.skip(13).toList();
    expect(added.map((a) => a.title), titles);
    expect(added.map((a) => a.example), examples);
    expect(added.map((a) => a.colorIndex).toSet(), hasLength(6));
    for (final activity in added) {
      expect(activity.isVisualChoice, visualActivities.contains(activity));
      expect(activity.isRecognition, isFalse);
      expect(ActivityContent.recognition, isNot(contains(activity)));
      expect(activity.hasSpokenTarget, isFalse);
      expect(activity.isCounting, isFalse);
      expect(NumberGameRanges.appliesTo(activity), isFalse);
    }
    expect(() => GameRound(Activity.wordSprint), throwsArgumentError);
    expect(() => GameRound(Activity.cursive), throwsArgumentError);
    expect(() => GameRound(Activity.sketchPad), throwsArgumentError);
  });

  for (final activity in visualActivities) {
    test('${activity.name} rounds balance valid visual choices across seeds', () {
      final singletons = <int>{};
      final sequences = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        final round = GameRound(activity, random: Random(seed));
        expect(round.questions, hasLength(5));
        final slots = <int>[];
        for (final q in round.questions) {
          expect(q.choices, hasLength(3));
          expect(q.choices.toSet(), hasLength(3));
          expect(q.visual, isNotNull);
          expect(q.audio, isEmpty);
          expect(q.instruction, isNotEmpty);
          final slot = q.choices.indexOf(q.answer);
          expect(slot, inInclusiveRange(0, 2));
          slots.add(slot);
        }
        // The visual branch generates its slot schedule before calling a builder.
        final rng = Random(seed);
        final repeated = [0, 1, 2]..shuffle(rng);
        final expected = [0, 1, 2, ...repeated.take(2)]..shuffle(rng);
        expect(slots, expected);
        final counts = List.generate(
          3,
          (slot) => slots.where((s) => s == slot).length,
        );
        expect([...counts]..sort(), [1, 2, 2]);
        singletons.add(counts.indexOf(1));
        sequences.add(slots.join());
      }
      expect(singletons, {0, 1, 2});
      expect(sequences.length, greaterThan(20));
    });
  }

  test('existing seed 73 rounds retain their exact targets, choices and prompts', () {
    const expected = {
      'uppercase':
          'Z:T,S,Z:upper_z::Listen, then tap!|H:N,H,S:upper_h::Listen, then tap!|N:C,N,H:upper_n::Listen, then tap!|P:Z,E,P:upper_p::Listen, then tap!|F:F,Y,C:upper_f::Listen, then tap!',
      'lowercase':
          'z:t,s,z:lower_z::Listen, then tap!|h:n,h,s:lower_h::Listen, then tap!|n:c,n,h:lower_n::Listen, then tap!|p:z,e,p:lower_p::Listen, then tap!|f:f,y,c:lower_f::Listen, then tap!',
      'matching':
          'z:t,s,z:match_lower:Z:Find its letter friend!|H:N,H,S:match_upper:h:Find its letter friend!|n:c,n,h:match_lower:N:Find its letter friend!|P:Z,E,P:match_upper:p:Find its letter friend!|f:f,y,c:match_lower:F:Find its letter friend!',
      'numbers':
          '5:4,1,5:number_5::Listen, then tap!|4:5,2,4:number_4::Listen, then tap!|0:0,10,2:number_0::Listen, then tap!|7:6,7,1:number_7::Listen, then tap!|8:7,8,10:number_8::Listen, then tap!',
      'sightWords':
          'my:I,a,my:word_my::Listen, then tap!|I:I,see,my:word_i::Listen, then tap!|a:a,by,the:word_a::Listen, then tap!|by:a,by,see:word_by::Listen, then tap!|go:my,go,a:word_go::Listen, then tap!',
      'letterSounds':
          'k:h,e,k:sound_k::Listen, then tap!|m:m,k,p:sound_m::Listen, then tap!|l:l,o,d:sound_l::Listen, then tap!|i:v,i,s:sound_i::Listen, then tap!|b:o,b,i:sound_b::Listen, then tap!',
      'howMany':
          '5:10,9,5:::How many?|4:1,2,4:::How many?|0:0,5,2:::How many?|7:6,7,4:::How many?|8:2,8,3:::How many?',
      'makeGroup':
          '5:10,9,5:::Make a group|4:1,2,4:::Make a group|0:0,5,2:::Make a group|7:6,7,4:::Make a group|8:2,8,3:::Make a group',
    };
    for (final entry in expected.entries) {
      final round = GameRound(
        Activity.values.byName(entry.key),
        random: Random(73),
      );
      expect(
        round.questions
            .map(
              (q) =>
                  '${q.answer}:${q.choices.join(',')}:${q.audio}:${q.partner ?? ''}:${q.instruction}',
            )
            .join('|'),
        entry.value,
      );
    }
  });

  test(
    'settings timer round-trips and tolerates absent and non-false values',
    () {
      expect(const AppSettings().wordSprintTimer, isTrue);
      final settings = const AppSettings().withWordSprintTimer(false);
      expect(AppSettings.fromMap(settings.toMap()).wordSprintTimer, isFalse);
      expect(settings.copyWith(soundOn: false).wordSprintTimer, isFalse);
      for (final value in [null, true, 1, 'false']) {
        expect(
          AppSettings.fromMap({'wordSprintTimer': value}).wordSprintTimer,
          isTrue,
        );
      }
      expect(AppSettings.fromMap({}).wordSprintTimer, isTrue);
    },
  );

  test(
    'score round-trips; all legacy versions default absent score to zero',
    () {
      final progress = PlayerProgress(wordSprintBest: 19);
      expect(PlayerProgress.decode(progress.encode()).wordSprintBest, 19);
      expect(progress.copyWith(xp: 0).wordSprintBest, 19);
      for (final version in [1, 2, 3]) {
        final map =
            jsonDecode(PlayerProgress().encode()) as Map<String, dynamic>;
        map['version'] = version;
        if (version != 3) {
          map['movesTaken'] = 0;
          map['pendingPlays'] = [];
          map['bests'] = {};
        }
        map.remove('wordSprintBest');
        expect(PlayerProgress.decode(jsonEncode(map)).wordSprintBest, 0);
        for (final invalid in [null, '3', 1.5, true, -1]) {
          expect(
            () => PlayerProgress.decode(
              jsonEncode({...map, 'wordSprintBest': invalid}),
            ),
            throwsFormatException,
          );
        }
      }
      expect(jsonDecode(progress.encode())['version'], 3);
    },
  );

  test(
    'Word Sprint saves only records without XP, gifts or learning id changes',
    () async {
      final d = SequenceDevice()..xp = 50;
      final c = ProgressController(d);
      await c.load();
      addTearDown(c.dispose);
      final before = c.progress!;
      final writes = d.writes;
      expect((await c.recordWordSprint('zero', 0)).newBest, isFalse);
      expect(d.writes, writes);
      final result = await c.recordWordSprint('one', 12);
      expect([result.words, result.best], [12, 12]);
      expect(result.newBest, isTrue);
      expect(d.writes, writes + 1);
      await c.recordWordSprint('one', 12);
      await c.recordWordSprint('tie', 12);
      await c.recordWordSprint('lower', 8);
      expect(d.writes, writes + 1);
      expect(c.progress!.xp, before.xp);
      expect(c.progress!.earnedRewardChoices, before.earnedRewardChoices);
      expect(c.progress!.lastRewardedRound, before.lastRewardedRound);
      expect(PlayerProgress.decode(d.document).wordSprintBest, 12);
      await c.setWordSprintTimer(false);
      expect(c.settings.wordSprintTimer, isFalse);
      final reload = ProgressController(d);
      await reload.load();
      expect(reload.progress!.wordSprintBest, 12);
      expect(reload.settings.wordSprintTimer, isFalse);
      reload.dispose();
      await c.reset();
      expect(c.progress!.wordSprintBest, 0);
      expect(c.settings.wordSprintTimer, isFalse);
    },
  );

  test(
    'Word Sprint lost acknowledgement retries exact score and pins its player',
    () async {
      final d = SequenceDevice();
      final c = ProgressController(d);
      await c.load();
      addTearDown(c.dispose);
      d.loseAcknowledgement = true;
      await expectLater(c.recordWordSprint('one', 7), throwsStateError);
      expect(c.progress!.wordSprintBest, 0);
      expect(c.blocked.value, isTrue);
      await expectLater(c.addProfile('Other'), throwsStateError);
      await expectLater(c.recordWordSprint('two', 20), throwsStateError);
      d.loseAcknowledgement = false;
      final retried = await c.recordWordSprint('one', 99);
      expect([retried.words, retried.best], [7, 7]);
      expect(c.progress!.wordSprintBest, 7);
      await c.recordWordSprint('one', 99);
      expect(c.progress!.wordSprintBest, 7);
      await c.addProfile('Other');
      await c.recordWordSprint('one', 3);
      expect(c.progress!.wordSprintBest, 3);
      expect(c.progress!.xp, 0);
      await expectLater(c.recordWordSprint('', 3), throwsArgumentError);
      await expectLater(
        c.recordWordSprint('negative', -1),
        throwsArgumentError,
      );
    },
  );

  test(
    'malformed sprint scores retain the recovery path without rewriting data',
    () async {
      final document = jsonEncode({
        ...jsonDecode(PlayerProgress().encode()) as Map<String, dynamic>,
        'wordSprintBest': 'broken',
      });
      final d = MemoryDevice()..document = document;
      final c = ProgressController(d);
      await c.load();
      expect(c.loadFailed, isTrue);
      expect(c.progress, isNull);
      expect(d.document, document);
      expect(d.writes, 0);
      c.dispose();
    },
  );

  testWidgets(
    'Numbers keeps seven uniform cards; only 2048 keeps its description',
    (tester) async {
      await tester.pumpWidget(RainbowGardenApp(services: MemoryDevice()));
      await settle(tester);
      await tapVisible(tester, find.text('Numbers'));
      final finder = find.byType(SelectionCard);
      final cards = tester.widgetList<SelectionCard>(finder).toList();
      expect(cards, hasLength(7));
      expect({
        for (final c in cards) c.title: c.subtitle,
      }, containsPair('2048', Activity.game2048.subtitle));
      expect(
        cards.where((c) => c.title != '2048').every((c) => c.subtitle.isEmpty),
        isTrue,
      );
      expect(
        List.generate(7, (i) => tester.getSize(finder.at(i)).height).toSet(),
        hasLength(1),
      );
      for (final card in cards.skip(5)) {
        expect(
          card.illustration,
          card.title == 'Same Number'
              ? isA<SameNumberIllustration>()
              : isA<NumberPartsIllustration>(),
        );
        expect(card.trailingAction, isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'visual choice widths, labels and muted voice follow their payloads',
    (tester) async {
      final d = MemoryDevice();
      for (final activity in [Activity.readAndFind, Activity.makeBelieve]) {
        await tester.pumpWidget(const SizedBox());
        final round = await openVisual(tester, d, activity);
        final q = round.question;
        final first = find.byKey(ValueKey('choice-${q.choices.first}'));
        final second = find.byKey(ValueKey('choice-${q.choices[1]}'));
        if (q.visual!.fullWidthChoices) {
          expect(tester.getTopLeft(first).dx, tester.getTopLeft(second).dx);
          expect(
            tester.getTopLeft(first).dy,
            lessThan(tester.getTopLeft(second).dy),
          );
        } else {
          expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        }
        final voice = tester.widget<VoiceButton>(find.byType(VoiceButton));
        expect(voice.subject, 'word');
        voice.onPressed!();
        await settle(tester);
        expect(
          tester.widget<VoiceButton>(find.byType(VoiceButton)).needsVoice,
          activity == Activity.makeBelieve,
        );
        expect(d.clips, isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final activity in visualActivities) {
    testWidgets('${activity.name} enters silently and passes explicit hint', (
      tester,
    ) async {
      final d = MemoryDevice();
      final round = await openVisual(tester, d, activity);
      expect(d.clips, isEmpty);
      expect(find.text('Listen again'), findsNothing);
      VisualQuestionContext readContext() => switch (activity) {
        Activity.readAndFind =>
          tester
              .widget<ReadAndFindPrompt>(find.byType(ReadAndFindPrompt))
              .context,
        Activity.makeBelieve => visualContext(tester),
        Activity.sameNumber =>
          tester
              .widget<SameNumberPrompt>(find.byType(SameNumberPrompt))
              .context,
        _ =>
          tester
              .widget<NumberPartsPrompt>(find.byType(NumberPartsPrompt))
              .context,
      };
      expect(readContext().hint, isFalse);
      await tapVisible(tester, find.text('Show a hint'));
      expect(readContext().hint, isTrue);
      expect(find.text('Find ${round.question.answer}'), findsNothing);
      expect(
        find.byType(VoiceButton),
        activity.category == GameCategory.words ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'select then Check retries, clears selection and advances explicitly',
    (tester) async {
      final d = MemoryDevice();
      final r = await openVisual(tester, d, Activity.makeBelieve);
      final q = r.question;
      final wrong = q.choices.firstWhere((c) => c != q.answer);
      final check = find.byKey(const ValueKey('check-visual'));
      expect(tester.widget<FilledButton>(check).onPressed, isNull);
      await tapVisible(tester, find.byKey(ValueKey('choice-$wrong')));
      expect(r.answered, isFalse);
      expect(visualContext(tester).selected, wrong);
      expect(d.clips, [(q.visual! as MakeBelieveVisual).choiceClip(wrong)]);
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(ValueKey('choice-$wrong')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.selected, isTrue);
      await tapVisible(tester, check);
      expect(r.answered, isFalse);
      expect(find.text('Try again'), findsOneWidget);
      expect(visualContext(tester).selected, isNull);
      expect(tester.widget<FilledButton>(check).onPressed, isNull);
      await tapVisible(tester, find.byKey(ValueKey('choice-${q.answer}')));
      await tapVisible(tester, check);
      expect(r.answered, isTrue);
      expect(find.text('You found it! ✨'), findsOneWidget);
      await tapVisible(tester, find.text('Next'));
      expect(r.completed, 1);
      expect(visualContext(tester).selected, isNull);
      expect(visualContext(tester).hint, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'sequence plays steps in order and reports failure without revealing hints',
    (tester) async {
      final d = SequenceDevice();
      await openVisual(tester, d, Activity.makeBelieve);
      final ctx = visualContext(tester);
      final steps = <int>[];
      expect(
        await ctx.playSequence([
          ['a', 'b'],
          ['c'],
        ], onStep: steps.add),
        isTrue,
      );
      expect(d.clips, ['a', 'b', 'c']);
      expect(steps, [0, 1]);
      d.failAudio = true;
      expect(
        await ctx.playSequence([
          ['fail'],
        ]),
        isFalse,
      );
      await tester.pump();
      expect(
        find.text('Sound could not play. You can use the hint.'),
        findsOneWidget,
      );
      expect(visualContext(tester).hint, isFalse);
      final unknown = const UnknownVisual();
      expect(() => buildVisualPrompt(unknown, ctx), throwsArgumentError);
      expect(() => buildVisualChoice(unknown, 'a', ctx), throwsArgumentError);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final cancel in ['correct answer', 'mute', 'gift sheet', 'background']) {
    testWidgets('sequence cancels on $cancel', (tester) async {
      final d = SequenceDevice();
      final c = ProgressController(d);
      await c.load();
      final r = await openVisual(
        tester,
        d,
        Activity.makeBelieve,
        controller: c,
      );
      // Select before holding audio so a Check can cancel the sequence itself.
      await tapVisible(
        tester,
        find.byKey(ValueKey('choice-${r.question.answer}')),
      );
      d.clips.clear();
      d.hold = Completer<void>();
      final result = visualContext(tester).playSequence([
        ['first', 'second'],
        ['third'],
      ]);
      await tester.pump();
      expect(d.clips, ['first']);
      switch (cancel) {
        case 'correct answer':
          await tapVisible(tester, find.byKey(const ValueKey('check-visual')));
        case 'mute':
          tester.widget<VoiceButton>(find.byType(VoiceButton)).onPressed!();
          await settle(tester);
        case 'gift sheet':
          await tapVisible(tester, find.byTooltip('Rewards'));
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
      }
      d.hold!.complete();
      await tester.pump();
      expect(await result, isFalse);
      expect(d.clips, ['first']);
      if (cancel == 'background')
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets('Words metadata and Word Sprint routing preserve category Back', (
    tester,
  ) async {
    final d = MemoryDevice();
    await tester.pumpWidget(RainbowGardenApp(services: d));
    await settle(tester);
    await tapVisible(tester, find.text('Words'));
    final cards = tester
        .widgetList<SelectionCard>(find.byType(SelectionCard))
        .toList();
    expect(cards.map((c) => c.subtitle), [
      '',
      'Read the word, find its picture',
      'Read a pretend word, pick its sound',
      'Read as many words as you can',
    ]);
    for (final card in cards.skip(1)) {
      expect(card.illustration, switch (card.title) {
        'Read and Find' => isA<ReadAndFindIllustration>(),
        'Make-Believe Words' => isA<MakeBelieveIllustration>(),
        _ => isA<WordSprintIllustration>(),
      });
      expect(card.trailingAction, isNull);
    }
    await tapVisible(tester, find.text('Word Sprint'));
    expect(find.byType(WordSprintPage), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Back to words'));
    expect(find.text('Words'), findsOneWidget);
    expect(find.byType(SelectionCard), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox());
  });
}
