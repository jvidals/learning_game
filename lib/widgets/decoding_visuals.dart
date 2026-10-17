import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../decoding.dart';
import '../word_bank.dart';
import 'sound_it_out.dart';
import 'visual_question.dart';

class ReadAndFindPrompt extends StatelessWidget {
  const ReadAndFindPrompt({
    super.key,
    required this.visual,
    required this.context,
  });
  final ReadAndFindVisual visual;
  final VisualQuestionContext context;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        children: [
          _PrintedWord(visual.word),
          if (this.context.answered)
            Image.asset(
              visual.word.pictureAsset!,
              width: 96,
              height: 96,
              semanticLabel: visual.word.label,
            ),
        ],
      ),
      if (this.context.hint) ...[
        const SizedBox(height: 12),
        SoundItOut(
          key: ValueKey(visual.word.spelling),
          word: visual.word,
          playSequence: this.context.playSequence,
          includeWholeWord: true,
          soundOn: this.context.soundOn,
          enabled: this.context.enabled,
        ),
      ],
    ],
  );
}

class ReadAndFindChoice extends StatelessWidget {
  const ReadAndFindChoice({
    super.key,
    required this.visual,
    required this.choice,
    required this.context,
  });
  final ReadAndFindVisual visual;
  final String choice;
  final VisualQuestionContext context;

  @override
  Widget build(BuildContext context) => Image.asset(
    realWord(choice).pictureAsset!,
    width: 112,
    height: 112,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

class MakeBelievePrompt extends StatelessWidget {
  const MakeBelievePrompt({
    super.key,
    required this.visual,
    required this.context,
  });
  final MakeBelieveVisual visual;
  final VisualQuestionContext context;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 18,
            color: GardenColors.of(context).primary,
          ),
          Text(
            'Make-believe',
            style: TextStyle(color: GardenColors.of(context).secondary),
          ),
        ],
      ),
      _PrintedWord(visual.word),
      if (!this.context.soundOn)
        const Text(
          'Turn on sound to hear the choices.',
          textAlign: TextAlign.center,
        ),
      if (this.context.hint) ...[
        const SizedBox(height: 12),
        SoundItOut(
          key: ValueKey(visual.word.spelling),
          word: visual.word,
          playSequence: this.context.playSequence,
          includeWholeWord: false,
          soundOn: this.context.soundOn,
          enabled: this.context.enabled,
        ),
      ],
    ],
  );
}

class MakeBelieveChoice extends StatelessWidget {
  const MakeBelieveChoice({
    super.key,
    required this.visual,
    required this.choice,
    required this.context,
  });
  final MakeBelieveVisual visual;
  final String choice;
  final VisualQuestionContext context;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        this.context.selected == choice
            ? Icons.volume_up_rounded
            : Icons.volume_up_outlined,
        size: 32,
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          visual.choiceLabel(choice),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
      if (this.context.selected == choice) ...[
        const SizedBox(width: 8),
        const Icon(Icons.check_circle_outline),
      ],
    ],
  );
}

/// Keep the word together; scale with accessibility text until the available
/// width is filled, then fit the whole word rather than clipping a letter.
class _PrintedWord extends StatelessWidget {
  const _PrintedWord(this.word);
  final DecodableWord word;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      word.spelling,
      maxLines: 1,
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: GardenColors.of(context).foreground,
      ),
    ),
  );
}
