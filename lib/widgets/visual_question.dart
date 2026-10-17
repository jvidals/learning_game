import 'package:flutter/widgets.dart';
import '../game.dart';
import '../decoding.dart';
import '../number_sense.dart';
import 'decoding_visuals.dart';
import 'number_visuals.dart';

class VisualQuestionContext {
  const VisualQuestionContext({
    required this.hint,
    required this.answered,
    required this.enabled,
    required this.soundOn,
    required this.selected,
    required this.playSequence,
  });
  final bool hint, answered, enabled, soundOn;

  /// Currently selected choice in select-then-check.
  final String? selected;

  /// Plays steps in order; each step is a list of clip IDs played back to
  /// back. [onStep] is called with the step index before it plays. Resolves
  /// true only if every step finished without cancellation, muting,
  /// backgrounding, gift sheet, navigation or audio failure.
  final Future<bool> Function(
    List<List<String>> steps, {
    void Function(int step)? onStep,
  })
  playSequence;
}

Widget buildVisualPrompt(QuestionVisual visual, VisualQuestionContext context) {
  if (visual is ReadAndFindVisual) {
    return ReadAndFindPrompt(visual: visual, context: context);
  }
  if (visual is MakeBelieveVisual) {
    return MakeBelievePrompt(visual: visual, context: context);
  }
  if (visual is SameNumberVisual) {
    return SameNumberPrompt(visual: visual, context: context);
  }
  if (visual is NumberPartsVisual) {
    return NumberPartsPrompt(visual: visual, context: context);
  }
  throw ArgumentError.value(visual, 'visual', 'Unknown question visual');
}

Widget buildVisualChoice(
  QuestionVisual visual,
  String choice,
  VisualQuestionContext context,
) {
  if (visual is ReadAndFindVisual) {
    return ReadAndFindChoice(visual: visual, choice: choice, context: context);
  }
  if (visual is MakeBelieveVisual) {
    return MakeBelieveChoice(visual: visual, choice: choice, context: context);
  }
  if (visual is SameNumberVisual) {
    return SameNumberChoice(visual: visual, choice: choice, context: context);
  }
  if (visual is NumberPartsVisual) {
    return NumberPartsChoice(visual: visual, choice: choice, context: context);
  }
  throw ArgumentError.value(visual, 'visual', 'Unknown question visual');
}
