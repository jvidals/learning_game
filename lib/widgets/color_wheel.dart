import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../sketch_ink.dart';
import 'sketch_popover.dart';
import 'special_swatch.dart';

/// A full-brightness hue/saturation disc with a thumb previewing [value].
/// Hue starts at red on the right and increases clockwise. Outside drags clamp
/// to the disc's edge. The wheel fits a square between 160 and 320 logical px
/// wherever its parent's constraints permit.
class ColorWheel extends StatelessWidget {
  const ColorWheel({super.key, required this.value, required this.onChanged});

  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = math
          .min(320.0, math.min(constraints.maxWidth, constraints.maxHeight))
          .clamp(0.0, 320.0);
      void select(Offset position) {
        final delta = position - Offset(side / 2, side / 2);
        final hue =
            (math.atan2(delta.dy, delta.dx) * 180 / math.pi + 360) % 360;
        onChanged(
          value
              .withValue(value.value < .25 ? 1 : value.value)
              .withHue(hue)
              .withSaturation((delta.distance / (side / 2)).clamp(0.0, 1.0)),
        );
      }

      return Semantics(
        label: 'Color wheel',
        value:
            'Hue ${value.hue.round()}, saturation ${(value.saturation * 100).round()} percent',
        increasedValue:
            'Hue ${((value.hue + 10) % 360).round()}, saturation ${(value.saturation * 100).round()} percent',
        decreasedValue:
            'Hue ${((value.hue + 350) % 360).round()}, saturation ${(value.saturation * 100).round()} percent',
        onIncrease: () => onChanged(value.withHue((value.hue + 10) % 360)),
        onDecrease: () => onChanged(value.withHue((value.hue + 350) % 360)),
        // Claims the pointer eagerly, like the writing pads, so dragging on
        // the wheel never scrolls or dismisses the surrounding popover.
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  EagerGestureRecognizer.new,
                  (_) {},
                ),
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => select(event.localPosition),
            onPointerMove: (event) => select(event.localPosition),
            child: FutureBuilder<ui.Image>(
              future: _WheelPainter.discImage,
              builder: (context, snapshot) => CustomPaint(
                size: Size.square(side),
                painter: _WheelPainter(
                  value,
                  GardenColors.of(context).foreground,
                  snapshot.data,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter(this.value, this.foreground, this.image);
  final HSVColor value;
  final Color foreground;
  final ui.Image? image;

  // Shared for the lifetime of the app; individual wheels must not dispose it.
  static final Future<ui.Image> discImage = _createDiscImage();

  static Future<ui.Image> _createDiscImage() {
    const side = 384;
    final pixels = Uint8List(side * side * 4);
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final dx = (x + .5 - side / 2) / (side / 2);
        final dy = (y + .5 - side / 2) / (side / 2);
        final saturation = math.sqrt(dx * dx + dy * dy);
        if (saturation > 1) continue;
        final hue = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
        final color = HSVColor.fromAHSV(1, hue, saturation, 1).toColor();
        final offset = (y * side + x) * 4;
        final argb = color.toARGB32();
        pixels[offset] = (argb >> 16) & 255;
        pixels[offset + 1] = (argb >> 8) & 255;
        pixels[offset + 2] = argb & 255;
        pixels[offset + 3] = 255;
      }
    }
    final result = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      side,
      side,
      ui.PixelFormat.rgba8888,
      result.complete,
    );
    return result.future;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Offset.zero & size;
    final disc = image;
    if (disc == null) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ).createShader(rect),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
            colors: [Colors.white, Color(0x00FFFFFF)],
          ).createShader(rect),
      );
    } else {
      final transform = Matrix4.diagonal3Values(
        size.width / disc.width,
        size.height / disc.height,
        1,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.ImageShader(
            disc,
            TileMode.clamp,
            TileMode.clamp,
            transform.storage,
          )
          ..filterQuality = FilterQuality.medium,
      );
    }
    final angle = value.hue * math.pi / 180;
    final thumb =
        center +
        Offset(math.cos(angle), math.sin(angle)) * radius * value.saturation;
    canvas.drawCircle(thumb, 9, Paint()..color = Colors.white);
    canvas.drawCircle(thumb, 7, Paint()..color = foreground);
    canvas.drawCircle(thumb, 5, Paint()..color = value.toColor());
    canvas.drawCircle(
      thumb,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      value != oldDelegate.value ||
      foreground != oldDelegate.foreground ||
      image != oldDelegate.image;
}

enum SketchColorTab { crayons, special, mix }

sealed class SketchPick {
  const SketchPick();
}

final class PickSolid extends SketchPick {
  const PickSolid(this.argb);
  final int argb;
}

final class PickSpecial extends SketchPick {
  const PickSpecial(this.kind);
  final SketchSpecial kind;
}

final class PickPlain extends SketchPick {
  const PickPlain();
}

/// Swatches return immediately. Mixed ink previews live and commits once on
/// dismissal; an untouched picker returns null. [base] is the saved solid color
/// used by Glitter and Neon, even when [current] is a special ink.
Future<SketchPick?> showSketchInkPopover(
  BuildContext context, {
  required GlobalKey anchor,
  required ValueChanged<SolidInk> onPreview,
  required SketchInk current,
  required Color base,
  required List<({Color color, String name})> presets,
  required List<Color> recent,
  SketchColorTab initialTab = SketchColorTab.crayons,
  ValueChanged<SketchColorTab>? onTabChanged,
  List<SketchSpecial> specials = SketchSpecial.values,
}) async {
  var tab = initialTab;
  var mixed = HSVColor.fromColor(
    current is SolidInk ? Color(current.argb) : base,
  );
  SolidInk? lastMixed;
  final selected = await showSketchPopover<SketchPick>(
    context,
    anchor: anchor,
    semanticLabel: 'Choose a color',
    builder: (context) => SizedBox(
      width: 420,
      child: StatefulBuilder(
        builder: (context, setState) {
          final colors = GardenColors.of(context);
          void previewMix(HSVColor value) {
            setState(() => mixed = value);
            lastMixed = SolidInk(value.toColor().toARGB32());
            onPreview(lastMixed!);
          }

          Widget swatch(
            SketchPick pick,
            String label,
            Key key, {
            double extent = 52,
          }) {
            final special =
                lastMixed == null ||
                    (current is SpecialInk && current.kind.isEffect)
                ? (current is SpecialInk ? current.kind : null)
                : null;
            final currentColor =
                lastMixed?.argb ??
                (current is SolidInk ? current.argb : base.toARGB32());
            final selected = switch (pick) {
              PickSolid(:final argb) =>
                argb == currentColor && (special == null || special.isEffect),
              PickSpecial(:final kind) => kind == special,
              PickPlain() => special == null,
            };
            final color = switch (pick) {
              PickSolid(:final argb) => Color(argb),
              PickPlain() => Color(currentColor),
              PickSpecial() => null,
            };
            return Center(
              child: MergeSemantics(
                child: Semantics(
                  key: key,
                  selected: selected,
                  button: true,
                  label: label,
                  excludeSemantics: true,
                  onTap: () => Navigator.pop(context, pick),
                  child: Tooltip(
                    message: label,
                    excludeFromSemantics: true,
                    child: SizedBox.square(
                      dimension: extent,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.square(48),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.all(5),
                          backgroundColor: selected
                              ? colors.selectedSurface
                              : null,
                          side: BorderSide(
                            color: selected ? colors.primary : colors.outline,
                            width: selected ? 2 : 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, pick),
                        child: ExcludeSemantics(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (pick is PickSpecial)
                                SpecialSwatch(
                                  special: pick.kind,
                                  base: Color(currentColor),
                                )
                              else
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colors.outline,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              if (selected)
                                Center(
                                  child: pick is PickSpecial
                                      ? const DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            size: 24,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Icon(
                                          Icons.check,
                                          size: 24,
                                          color: color!.computeLuminance() > .5
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          Widget tabButton(SketchColorTab value, String label, IconData icon) {
            final selected = tab == value;
            void select() {
              if (tab == value) return;
              setState(() => tab = value);
              onTabChanged?.call(value);
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  key: ValueKey('sketch-color-tab-${value.name}'),
                  selected: selected,
                  button: true,
                  label: label,
                  excludeSemantics: true,
                  onTap: select,
                  child: Tooltip(
                    message: label,
                    excludeFromSemantics: true,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        backgroundColor: selected
                            ? colors.selectedSurface
                            : null,
                        foregroundColor: selected
                            ? colors.primary
                            : colors.foreground,
                        side: BorderSide(
                          color: selected ? colors.primary : colors.outline,
                          width: selected ? 2 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: select,
                      child: ExcludeSemantics(child: Icon(icon)),
                    ),
                  ),
                ),
              ),
            );
          }

          Widget crayons() => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(304, constraints.maxWidth),
                child: GridView.count(
                  padding: const EdgeInsets.all(8),
                  crossAxisCount: 6,
                  mainAxisSpacing: 4,
                  childAspectRatio:
                      (math.max(304, constraints.maxWidth) - 16) / 6 / 56,
                  children: [
                    for (var i = 0; i < presets.length; i++)
                      swatch(
                        PickSolid(presets[i].color.toARGB32()),
                        presets[i].name,
                        ValueKey('sketch-preset-$i'),
                      ),
                  ],
                ),
              ),
            ),
          );

          Widget mix() => LayoutBuilder(
            builder: (context, constraints) {
              final wheelSize = math.min(
                142.0,
                math.max(0.0, (constraints.maxWidth - 24) / 2),
              );
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: wheelSize,
                        child: ColorWheel(
                          key: const ValueKey('sketch-color-wheel'),
                          value: mixed,
                          onChanged: previewMix,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Tooltip(
                              message: 'Brightness',
                              excludeFromSemantics: true,
                              child: Icon(
                                Icons.light_mode_rounded,
                                semanticLabel: 'Brightness',
                              ),
                            ),
                            Semantics(
                              label: 'Brightness',
                              child: Slider(
                                semanticFormatterCallback: (value) =>
                                    '${(value * 100).round()} percent',
                                label: 'Brightness',
                                value: mixed.value,
                                onChanged: (value) =>
                                    previewMix(mixed.withValue(value)),
                              ),
                            ),
                            Semantics(
                              label: 'New color preview',
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: mixed.toColor(),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colors.outline,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recent.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final count = math.min(
                        math.min(10, recent.length),
                        math.max(0, ((constraints.maxWidth - 28) / 48).floor()),
                      );
                      return Row(
                        children: [
                          const Tooltip(
                            message: 'Recent colors',
                            excludeFromSemantics: true,
                            child: Icon(
                              Icons.history_rounded,
                              semanticLabel: 'Recent colors',
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 4),
                          for (var i = 0; i < count; i++)
                            swatch(
                              PickSolid(recent[i].toARGB32()),
                              'Recent color ${i + 1}',
                              ValueKey('sketch-recent-$i'),
                              extent: 48,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    tabButton(
                      SketchColorTab.crayons,
                      'Crayons',
                      Icons.palette_rounded,
                    ),
                    tabButton(
                      SketchColorTab.special,
                      'Special colors',
                      Icons.auto_awesome_rounded,
                    ),
                    tabButton(
                      SketchColorTab.mix,
                      'Mix a color',
                      Icons.colorize_rounded,
                    ),
                  ],
                ),
              ),
              SizedBox(
                key: const ValueKey('sketch-color-content'),
                height: 150,
                child: switch (tab) {
                  SketchColorTab.crayons => crayons(),
                  SketchColorTab.special => GridView(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 76,
                          mainAxisExtent: 64,
                        ),
                    children: [
                      swatch(
                        const PickPlain(),
                        'Plain',
                        const ValueKey('sketch-special-plain'),
                      ),
                      for (final special in specials)
                        swatch(
                          PickSpecial(special),
                          special.label,
                          ValueKey('sketch-special-${special.name}'),
                        ),
                    ],
                  ),
                  SketchColorTab.mix => mix(),
                },
              ),
            ],
          );
        },
      ),
    ),
  );
  return selected ?? (lastMixed == null ? null : PickSolid(lastMixed!.argb));
}
