import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../sketch_ink.dart';
import 'sketch_popover.dart';
import 'special_swatch.dart';

/// Changes brush size live. All dismissal paths keep the last value.
/// The preview diameter is the page-unit size multiplied by [previewScale].
Future<void> showBrushSizePopover(
  BuildContext context, {
  required GlobalKey anchor,
  required double size,
  required double min,
  required double max,
  required double previewScale,
  required Color color,
  SketchSpecial? special,
  required ValueChanged<double> onChanged,
}) async {
  assert(min < max);
  assert(previewScale >= 0);
  var selected = size.clamp(min, max);
  await showSketchPopover<void>(
    context,
    anchor: anchor,
    semanticLabel: 'Brush size',
    builder: (context) => SizedBox(
      width: 360,
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: math.max(80, max * previewScale + 16),
              child: Center(
                child: Semantics(
                  label: 'Brush preview',
                  child: Container(
                    key: const ValueKey('sketch-size-preview'),
                    width: selected * previewScale,
                    height: selected * previewScale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: special == null ? color : null,
                      border: Border.all(
                        color: GardenColors.of(context).outline,
                        width: 1.5,
                      ),
                    ),
                    child: special == null
                        ? null
                        : SpecialSwatch(
                            special: special,
                            base: color,
                            shape: BoxShape.circle,
                          ),
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'Brush size',
              child: Slider(
                key: const ValueKey('sketch-size-slider'),
                min: min,
                max: max,
                value: selected,
                onChanged: (value) {
                  setState(() => selected = value);
                  onChanged(value);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
