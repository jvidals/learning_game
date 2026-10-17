import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../game.dart';
import '../number_range.dart';
import '../progress_controller.dart';
import 'parent_gate.dart';
import 'progress_widgets.dart';

/// The caller pauses its game before entering the gate, including canceled gates.
Future<void> openNumberRangeEditor(
  BuildContext context,
  ProgressController controller,
  Activity activity,
) async {
  if (!controller.canEditSettings) return;
  if (!await openParentGate(context, purpose: 'change the number range') ||
      !context.mounted)
    return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        NumberRangeEditor(controller: controller, activity: activity),
  );
}

/// Give large text its measured height without shrinking the toolbar controls.
PreferredSizeWidget? numberGameHeading(
  BuildContext context,
  Activity activity,
) {
  if (!NumberGameRanges.appliesTo(activity) ||
      MediaQuery.sizeOf(context).width >= 400 ||
      MediaQuery.textScalerOf(context).scale(20) <= 30) {
    return null;
  }
  final style = Theme.of(
    context,
  ).textTheme.titleLarge!.copyWith(fontSize: 20, height: 1.3);
  final painter = TextPainter(
    text: TextSpan(text: activity.title, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: MediaQuery.sizeOf(context).width - 32);
  final height = painter.height + 8;
  painter.dispose();
  return PreferredSize(
    preferredSize: Size.fromHeight(height),
    child: SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Semantics(
          header: true,
          child: Text(
            activity.title,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ),
    ),
  );
}

class NumberRangeButton extends StatelessWidget {
  const NumberRangeButton({
    super.key,
    required this.activity,
    required this.range,
    required this.onPressed,
  });
  final Activity activity;
  final NumberRange range;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('number-range-button'),
    tooltip: '${activity.title} range: ${range.label}',
    constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
    onPressed: onPressed,
    icon: const Icon(Icons.tune_rounded),
  );
}

class NumberRangeEditor extends StatelessWidget {
  const NumberRangeEditor({
    super.key,
    required this.controller,
    required this.activity,
  });
  final ProgressController controller;
  final Activity activity;
  Future<void> _set(int min, int max) async {
    try {
      await controller.updateSettings(
        (s) => s.withNumberRange(activity, NumberRange(min, max)),
      );
    } catch (_) {
      /* SaveStatus offers the controller's retained retry. */
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final range = controller.effectiveSettings.numberGameRanges
              .forActivity(activity);
          final cap = NumberGameRanges.capFor(activity);
          final enabled = controller.canEditSettings;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close range settings',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('number-range-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Range for ${controller.activeProfile!.name}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Changes start a fresh round.',
                        style: TextStyle(fontSize: 14),
                      ),
                      SaveStatus(controller: controller),
                      const SizedBox(height: 16),
                      Text(
                        'Numbers ${range.label}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      RangeSlider(
                        min: 0,
                        max: cap.toDouble(),
                        divisions: cap,
                        values: RangeValues(
                          range.min.toDouble(),
                          range.max.toDouble(),
                        ),
                        labels: RangeLabels('${range.min}', '${range.max}'),
                        semanticFormatterCallback: (value) =>
                            '${value.round()}',
                        onChanged: enabled
                            ? (v) {
                                if (v.end.round() - v.start.round() >= 2)
                                  _set(v.start.round(), v.end.round());
                              }
                            : null,
                      ),
                      _Endpoint(
                        label: 'Start',
                        value: range.min,
                        decrease: enabled && range.min > 0
                            ? () => _set(range.min - 1, range.max)
                            : null,
                        increase: enabled && range.count > 3
                            ? () => _set(range.min + 1, range.max)
                            : null,
                      ),
                      _Endpoint(
                        label: 'End',
                        value: range.max,
                        decrease: enabled && range.count > 3
                            ? () => _set(range.min, range.max - 1)
                            : null,
                        increase: enabled && range.max < cap
                            ? () => _set(range.min, range.max + 1)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          for (final max in [5, 10, 20])
                            OutlinedButton(
                              onPressed: enabled ? () => _set(0, max) : null,
                              child: Text('Use 0–$max'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Choose at least 3 numbers from 0 to $cap.'),
                      const SizedBox(height: 8),
                      const Text(
                        'Changes save automatically. Closing starts a fresh round if the range changed. Unfinished work earns no XP.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.value,
    this.decrease,
    this.increase,
  });
  final String label;
  final int value;
  final VoidCallback? decrease, increase;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text('$label: $value', style: const TextStyle(fontSize: 20)),
      ),
      IconButton(
        tooltip: 'Decrease ${label.toLowerCase()}',
        onPressed: decrease,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        icon: const Icon(Icons.remove_circle_outline),
      ),
      IconButton(
        tooltip: 'Increase ${label.toLowerCase()}',
        onPressed: increase,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}
