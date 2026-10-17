import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../handwriting.dart';

/// Fixed miniature boards keep the activity recognizable between visits.
class OrderingIllustration extends StatelessWidget {
  const OrderingIllustration({super.key, this.numbers = false});

  final bool numbers;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final labels = numbers
        ? const ['3', '1', '4', '2']
        : const ['C', 'A', 'D', 'B'];
    return SizedBox(
      width: 54,
      height: 54,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var row = 0; row < 2; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var column = 0; column < 2; column++)
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.card(colors.rainbow[numbers ? 2 : 4]),
                      border: Border.all(color: colors.primary),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      labels[row * 2 + column],
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: colors.foreground,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Uses the taught letter shapes, including the single-storey lowercase a.
class HandwritingIllustration extends StatelessWidget {
  const HandwritingIllustration({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(62, 54),
    painter: _HandwritingIllustrationPainter(GardenColors.of(context)),
  );
}

class _HandwritingIllustrationPainter extends CustomPainter {
  const _HandwritingIllustrationPainter(this.colors);

  final GardenColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 62, size.height / 54);
    final rule = Paint()
      ..color = colors.writingRule
      ..strokeWidth = 1.5;
    for (final y in [9.0, 45.0]) {
      canvas.drawLine(Offset(3, y), Offset(59, y), rule);
    }
    for (var x = 4.0; x <= 58; x += 4) {
      canvas.drawCircle(Offset(x, 27), .8, rule);
    }
    final ink = Paint()
      ..color = colors.foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (letter, left) in [('A', 4.0), ('a', 32.0)]) {
      for (final stroke in letterTemplates[letter]!.strokes) {
        final path = Path();
        for (var i = 0; i < stroke.length; i++) {
          final point = stroke[i];
          final x = left + point.x * 28, y = 9 + point.y * 36;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, ink);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HandwritingIllustrationPainter oldDelegate) =>
      colors != oldDelegate.colors;
}

/// Counting cues use geometric shapes so they suit any companion theme.
class CountingIllustration extends StatelessWidget {
  const CountingIllustration({super.key, this.makeGroup = false});

  final bool makeGroup;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(62, 54),
      painter: _CountingIllustrationPainter(
        GardenColors.of(context),
        makeGroup,
      ),
    ),
  );
}

class _CountingIllustrationPainter extends CustomPainter {
  const _CountingIllustrationPainter(this.colors, this.makeGroup);

  final GardenColors colors;
  final bool makeGroup;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 62, size.height / 54);
    final outline = Paint()
      ..color = colors.foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;

    void shape(Path path, Color color) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, outline);
    }

    void circle(Offset center, double diameter) => shape(
      Path()..addOval(Rect.fromCircle(center: center, radius: diameter / 2)),
      colors.rainbow[4],
    );

    void triangle(Offset center, double side) => shape(
      Path()
        ..moveTo(center.dx, center.dy - side / 2)
        ..lineTo(center.dx + side / 2, center.dy + side / 2)
        ..lineTo(center.dx - side / 2, center.dy + side / 2)
        ..close(),
      colors.rainbow[2],
    );

    void square(Offset center, double side) => shape(
      Path()
        ..addRect(Rect.fromCenter(center: center, width: side, height: side)),
      colors.rainbow[3],
    );

    if (makeGroup) {
      circle(const Offset(20, 15), 14);
      triangle(const Offset(43, 15), 16);
      triangle(const Offset(10, 38), 14);
      square(const Offset(31, 40), 14);
      circle(const Offset(52, 37), 14);
    } else {
      circle(const Offset(10, 13), 12);
      triangle(const Offset(52, 30), 13);
      square(const Offset(11, 43), 11);
      // A drawn question mark stays rounded and legible without font scaling.
      final question = Path()
        ..moveTo(24, 15)
        ..cubicTo(24, 4, 43, 4, 43, 15)
        ..cubicTo(43, 23, 32, 24, 32, 34);
      canvas.drawPath(
        question,
        Paint()
          ..color = colors.foreground
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        const Offset(32, 44),
        2.7,
        Paint()..color = colors.foreground,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CountingIllustrationPainter oldDelegate) =>
      colors != oldDelegate.colors || makeGroup != oldDelegate.makeGroup;
}
