import '../app_theme.dart';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../handwriting.dart';

class WritingInk extends ChangeNotifier {
  final List<InkStroke> _strokes = [];
  List<InkStroke> get strokes =>
      List.unmodifiable(_strokes.map((s) => List<InkPoint>.unmodifiable(s)));
  bool get isEmpty => _strokes.isEmpty;
  bool drawing = false, overflow = false;
  int _points = 0;

  void begin(InkPoint point) {
    if (drawing || overflow) return;
    if (_strokes.length >= 64 || _points >= 4096) {
      overflow = true;
      notifyListeners();
      return;
    }
    _strokes.add([point]);
    _points++;
    drawing = true;
    notifyListeners();
  }

  void add(InkPoint point) {
    if (!drawing || overflow || _strokes.last.last.distance(point) < .003)
      return;
    if (_points >= 4096) {
      overflow = true;
    } else {
      _strokes.last.add(point);
      _points++;
    }
    notifyListeners();
  }

  void end() {
    if (!drawing) return;
    drawing = false;
    notifyListeners();
  }

  void cancel() {
    if (!drawing) return;
    _points -= _strokes.removeLast().length;
    drawing = false;
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _points = 0;
    drawing = false;
    overflow = false;
    notifyListeners();
  }
}

class WritingPadGeometry {
  WritingPadGeometry(Size size)
    : height = math.min((size.height - 36) / 1.35, size.width / 1.35),
      width = size.width;
  final double height, width;
  Offset position(InkPoint p) =>
      Offset((width - height) / 2 + p.x * height, 20 + p.y * height);
  InkPoint point(Offset p) =>
      InkPoint((p.dx - (width - height) / 2) / height, (p.dy - 20) / height);
}

/// Eager pointer ownership keeps a vertical pen stroke from scrolling the page.
/// Scrolling remains available in the margins and outside either drawing area.
class WritingPad extends StatefulWidget {
  const WritingPad({
    super.key,
    required this.ink,
    required this.template,
    required this.trace,
    required this.enabled,
  });
  final WritingInk ink;
  final LetterTemplate template;
  final bool trace, enabled;
  @override
  State<WritingPad> createState() => _WritingPadState();
}

class _WritingPadState extends State<WritingPad> {
  int? _pointer;
  Size? _size;
  bool _outside = false;

  @override
  void didUpdateWidget(WritingPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.template != oldWidget.template) {
      // The owning page cancels ink before changing form/lifecycle state.
      _pointer = null;
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.trace
        ? 'Trace ${widget.template.character}. Numbered circles show where each stroke starts; arrows show its direction.'
        : 'Write ${widget.template.character} here. Solid top and bottom lines, dotted middle line. Draw with a finger or stylus, then tap Check.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_size != null && size != _size) {
          _pointer = null;
          // Avoid notifying while laying out; the unfinished stroke is removed
          // before the next input frame. Finished strokes use normalized units.
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
              if (!widget.enabled || event.pointer != _pointer || _outside)
                return;
              if (!(Offset.zero & size).contains(event.localPosition)) {
                _outside = true;
                return;
              }
              widget.ink.add(geometry.point(event.localPosition));
            },
            onPointerUp: (event) {
              if (event.pointer != _pointer) return;
              if (!_outside &&
                  (Offset.zero & size).contains(event.localPosition)) {
                widget.ink.add(geometry.point(event.localPosition));
              }
              widget.ink.end();
              _pointer = null;
            },
            onPointerCancel: (event) {
              if (event.pointer != _pointer) return;
              widget.ink.cancel();
              _pointer = null;
            },
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CustomPaint(
                  painter: _WritingPainter(
                    widget.ink,
                    widget.template,
                    widget.trace,
                    GardenColors.of(context),
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

class _WritingPainter extends CustomPainter {
  _WritingPainter(this.ink, this.template, this.trace, this.colors)
    : super(repaint: ink);
  final WritingInk ink;
  final LetterTemplate template;
  final bool trace;
  final GardenColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = WritingPadGeometry(size);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.surface);
    final rule = Paint()
      ..color = colors.writingRule
      ..strokeWidth = 1.5;
    for (final y in [0.0, 1.0]) {
      final py = geometry.position(InkPoint(0, y)).dy;
      canvas.drawLine(Offset(12, py), Offset(size.width - 12, py), rule);
    }
    final middle = geometry.position(const InkPoint(0, .5)).dy;
    for (var x = 12.0; x < size.width - 12; x += 12) {
      canvas.drawLine(
        Offset(x, middle),
        Offset(math.min(x + 6, size.width - 12), middle),
        rule,
      );
    }
    void stroke(InkStroke points, Paint paint) {
      if (points.isEmpty) return;
      if (points.length == 1) {
        canvas.drawCircle(
          geometry.position(points.first),
          paint.strokeWidth / 2,
          Paint()..color = paint.color,
        );
        return;
      }
      final first = geometry.position(points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in points.skip(1)) {
        final at = geometry.position(point);
        path.lineTo(at.dx, at.dy);
      }
      canvas.drawPath(path, paint);
    }

    if (trace) {
      final guide = Paint()
        ..color = colors.writingGuide
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final points in template.strokes) stroke(points, guide);
    }
    final pen = Paint()
      ..color = colors.writingInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final points in ink._strokes) stroke(points, pen);
    if (trace) {
      final used = <Offset>[];
      for (var i = 0; i < template.samples.length; i++) {
        final points = template.samples[i];
        final start = geometry.position(points.first);
        var badge = start + const Offset(-14, -10);
        while (used.any((p) => (p - badge).distance < 22)) {
          badge += const Offset(24, 0);
        }
        used.add(badge);
        canvas.drawLine(
          start,
          badge,
          Paint()
            ..color = colors.writingDirection
            ..strokeWidth = 1,
        );
        canvas.drawCircle(badge, 10, Paint()..color = colors.writingDirection);
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
        if (points.length > 3) {
          final at = (points.length * .35).floor().clamp(1, points.length - 2);
          final from = geometry.position(points[at - 1]),
              to = geometry.position(points[at + 1]);
          final direction = (to - from) / (to - from).distance;
          final center = geometry.position(points[at]);
          final normal = Offset(-direction.dy, direction.dx);
          final arrow = Path()
            ..moveTo((center + direction * 7).dx, (center + direction * 7).dy)
            ..lineTo(
              (center - direction * 4 + normal * 5).dx,
              (center - direction * 4 + normal * 5).dy,
            )
            ..lineTo(
              (center - direction * 4 - normal * 5).dx,
              (center - direction * 4 - normal * 5).dy,
            )
            ..close();
          canvas.drawPath(arrow, Paint()..color = colors.writingDirection);
        }
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()
        ..color = colors.writingGuide
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_WritingPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.template != template ||
      oldDelegate.trace != trace ||
      oldDelegate.colors != colors;
}
