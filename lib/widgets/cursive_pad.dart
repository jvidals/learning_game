import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../cursive.dart';
import '../handwriting.dart';
import 'writing_pad.dart';

/// Temporary finger/stylus ink, with eager pointer ownership just like Writing.
/// Page scrolling is available outside the pad. The page owns and disposes ink.
class CursivePad extends StatefulWidget {
  const CursivePad({
    super.key,
    required this.letter,
    required this.ink,
    required this.enabled,
    required this.guidance,
    this.faint = false,
    this.showModel = true,
    this.watchProgress,
  });
  final CursiveLetter letter;
  final WritingInk ink;
  final bool enabled, guidance, faint, showModel;
  final double? watchProgress;

  @override
  State<CursivePad> createState() => _CursivePadState();
}

class _CursivePadState extends State<CursivePad> {
  int? _pointer;
  Size? _size;
  bool _outside = false;

  @override
  void didUpdateWidget(CursivePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        oldWidget.letter != widget.letter ||
        oldWidget.ink != widget.ink) {
      _pointer = null;
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.guidance
        ? 'Trace cursive ${widget.letter.character} with a finger or stylus. Numbered circles mark stroke starts; arrows show direction.'
        : 'Write cursive ${widget.letter.character} with a finger or stylus, then tap Check. Use Clear to start again, or Skip letter to move on.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_size != null && size != _size) {
          _pointer = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.ink.cancel();
          });
        }
        _size = size;
        final geometry = WritingPadGeometry(size);
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: widget.enabled
              ? {
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EagerGestureRecognizer
                      >(EagerGestureRecognizer.new, (_) {}),
                }
              : const {},
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (!widget.enabled || _pointer != null) return;
              _pointer = event.pointer;
              _outside = false;
              widget.ink.begin(geometry.point(event.localPosition));
            },
            onPointerMove: (event) {
              if (!widget.enabled || _pointer != event.pointer || _outside) {
                return;
              }
              if (!(Offset.zero & size).contains(event.localPosition)) {
                _outside = true;
                return;
              }
              widget.ink.add(geometry.point(event.localPosition));
            },
            onPointerUp: (event) {
              if (_pointer != event.pointer) return;
              if (!_outside &&
                  (Offset.zero & size).contains(event.localPosition)) {
                widget.ink.add(geometry.point(event.localPosition));
              }
              widget.ink.end();
              _pointer = null;
            },
            onPointerCancel: (event) {
              if (_pointer != event.pointer) return;
              widget.ink.cancel();
              _pointer = null;
            },
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CustomPaint(
                  painter: CursivePainter(
                    letter: widget.letter,
                    colors: GardenColors.of(context),
                    ink: widget.ink,
                    guidance: widget.guidance,
                    faint: widget.faint,
                    showModel: widget.showModel,
                    watchProgress: widget.watchProgress,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Shared by the live pad, the always-visible model, and the dev contact sheet.
class CursivePainter extends CustomPainter {
  CursivePainter({
    required this.letter,
    required this.colors,
    this.ink,
    this.guidance = false,
    this.faint = false,
    this.showModel = true,
    this.watchProgress,
  }) : super(repaint: ink);
  final CursiveLetter letter;
  final GardenColors colors;
  final WritingInk? ink;
  final bool guidance, faint, showModel;
  final double? watchProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = WritingPadGeometry(size);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.surface);
    final rule = Paint()
      ..color = colors.writingRule
      ..strokeWidth = 1.5;
    for (final y in [0.0, 1.0, 1.35]) {
      final height = geometry.position(InkPoint(0, y)).dy;
      canvas.drawLine(
        Offset(12, height),
        Offset(size.width - 12, height),
        rule,
      );
    }
    final middle = geometry.position(const InkPoint(0, .5)).dy;
    for (var x = 12.0; x < size.width - 12; x += 12) {
      canvas.drawLine(
        Offset(x, middle),
        Offset(math.min(x + 6, size.width - 12), middle),
        rule,
      );
    }
    void stroke(InkStroke points, Color color, double width) {
      if (points.isEmpty) return;
      final pen = Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (points.length == 1) {
        canvas.drawCircle(
          geometry.position(points.first),
          width / 2,
          Paint()..color = color,
        );
      } else {
        final first = geometry.position(points.first);
        final path = Path()..moveTo(first.dx, first.dy);
        for (final point in points.skip(1)) {
          final at = geometry.position(point);
          path.lineTo(at.dx, at.dy);
        }
        canvas.drawPath(path, pen);
      }
    }

    // Standalone examples need a strong, readable line. Practice pads use the
    // softer guide so the child's ink remains distinct from the template.
    final modelColor = ink == null ? colors.writingInk : colors.writingGuide;
    for (final points in showModel ? letter.strokes : <InkStroke>[]) {
      stroke(
        points,
        faint ? modelColor.withValues(alpha: .5) : modelColor,
        // Keep the counter open in the compact comparison as well as the pad.
        math.min(faint ? 4 : 7, geometry.height * (faint ? .032 : .055)),
      );
    }
    for (final points in ink?.strokes ?? <InkStroke>[]) {
      stroke(points, colors.writingInk, 5);
    }
    if (!showModel) {
      canvas.drawCircle(
        geometry.position(letter.strokes.first.first),
        4,
        Paint()..color = colors.writingDirection,
      );
    }
    if (guidance) {
      for (var i = 0; i < letter.samples.length; i++) {
        final points = letter.samples[i];
        final start = geometry.position(points.first);
        final badge = start + const Offset(-12, -13);
        canvas.drawLine(start, badge, Paint()..color = colors.writingDirection);
        canvas.drawCircle(badge, 9, Paint()..color = colors.writingDirection);
        final text = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: colors.onDirection,
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, badge - Offset(text.width / 2, text.height / 2));
        text.dispose();
        if (points.length < 4) continue;
        final index = (points.length * .24).floor().clamp(1, points.length - 2);
        final from = geometry.position(points[index - 1]);
        final to = geometry.position(points[index + 1]);
        final delta = to - from;
        if (delta.distance < .001) continue;
        final direction = delta / delta.distance;
        final normal = Offset(-direction.dy, direction.dx);
        final center = geometry.position(points[index]);
        final tip = center + direction * 6;
        final a = center - direction * 4 + normal * 4;
        final b = center - direction * 4 - normal * 4;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..close(),
          Paint()..color = colors.writingDirection,
        );
      }
    }
    if (watchProgress != null) {
      final point = geometry.position(letter.watchPoint(watchProgress!));
      canvas.drawCircle(point, 8, Paint()..color = colors.writingInk);
      canvas.drawCircle(
        point,
        9,
        Paint()
          ..color = colors.writingDirection
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()
        ..color = colors.writingGuide
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(CursivePainter oldDelegate) =>
      oldDelegate.letter != letter ||
      oldDelegate.colors != colors ||
      oldDelegate.ink != ink ||
      oldDelegate.guidance != guidance ||
      oldDelegate.faint != faint ||
      oldDelegate.showModel != showModel ||
      oldDelegate.watchProgress != watchProgress;
}
