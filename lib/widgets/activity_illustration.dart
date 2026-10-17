import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../handwriting.dart';
import '../cursive.dart';

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

/// Decorative activity cues share the existing 62 × 54 miniature canvas.
class CursiveIllustration extends StatelessWidget {
  const CursiveIllustration({super.key});
  @override
  Widget build(BuildContext context) =>
      _activityIcon(context, _ActivityIcon.cursive);
}

class SameNumberIllustration extends StatelessWidget {
  const SameNumberIllustration({super.key});
  @override
  Widget build(BuildContext context) =>
      _activityIcon(context, _ActivityIcon.sameNumber);
}

class WordSprintIllustration extends StatelessWidget {
  const WordSprintIllustration({super.key});
  @override
  Widget build(BuildContext context) =>
      _activityIcon(context, _ActivityIcon.wordSprint);
}

class ReadAndFindIllustration extends StatelessWidget {
  const ReadAndFindIllustration({super.key});
  @override
  Widget build(BuildContext context) =>
      _activityIcon(context, _ActivityIcon.readAndFind);
}

class MakeBelieveIllustration extends StatelessWidget {
  const MakeBelieveIllustration({super.key});
  @override
  Widget build(BuildContext context) =>
      _activityIcon(context, _ActivityIcon.makeBelieve);
}

class NumberPartsIllustration extends StatelessWidget {
  const NumberPartsIllustration({super.key});
  @override
  Widget build(BuildContext context) =>
      _activityIcon(context, _ActivityIcon.numberParts);
}

enum _ActivityIcon {
  cursive,
  sameNumber,
  wordSprint,
  readAndFind,
  makeBelieve,
  numberParts,
}

Widget _activityIcon(BuildContext context, _ActivityIcon icon) =>
    ExcludeSemantics(
      child: CustomPaint(
        size: const Size(62, 54),
        painter: _ActivityIconPainter(GardenColors.of(context), icon),
      ),
    );

class _ActivityIconPainter extends CustomPainter {
  const _ActivityIconPainter(this.colors, this.icon);
  final GardenColors colors;
  final _ActivityIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 62, size.height / 54);
    final outline = Paint()
      ..color = colors.foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void shape(Path path, int color, {bool textSurface = false}) {
      canvas.drawPath(
        path,
        Paint()
          ..color = textSurface
              ? colors.card(colors.rainbow[color], white: .55)
              : colors.rainbow[color],
      );
      canvas.drawPath(path, outline);
    }

    void circle(
      Offset center,
      double radius,
      int color, {
      bool textSurface = false,
    }) => shape(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      color,
      textSurface: textSurface,
    );
    void label(String text, Offset center, double fontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: colors.foreground,
            fontSize: fontSize,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }

    void tile(Rect rect, String text, int color, double fontSize) {
      shape(
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5))),
        color,
        textSurface: true,
      );
      label(text, rect.center, fontSize);
    }

    switch (icon) {
      case _ActivityIcon.cursive:
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
        // A slanted, looped capital with a sweeping crossbar and exit stroke.
        canvas.drawPath(
          Path()
            ..moveTo(4, 44)
            ..cubicTo(11, 41, 23, 13, 25, 11)
            ..cubicTo(30, 3, 16, 10, 18, 17)
            ..cubicTo(21, 25, 23, 40, 28, 44)
            ..cubicTo(30, 46, 33, 43, 34, 40)
            ..moveTo(8, 33)
            ..cubicTo(13, 29, 23, 29, 28, 30),
          ink,
        );
        for (final stroke in cursiveLetters['a']!.strokes) {
          final path = Path();
          for (var i = 0; i < stroke.length; i++) {
            final point = stroke[i];
            final x = 32 + point.x * 26, y = 9 + point.y * 36;
            if (i == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, ink);
        }
      case _ActivityIcon.sameNumber:
        canvas.drawPath(
          Path()
            ..moveTo(6, 7)
            ..cubicTo(19, 0, 26, 17, 13, 18)
            ..cubicTo(29, 18, 23, 33, 7, 27),
          Paint()
            ..color = colors.foreground
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.8
            ..strokeCap = StrokeCap.round,
        );
        circle(const Offset(34, 17), 5.2, 4);
        shape(
          Path()
            ..moveTo(45.5, 10.5)
            ..lineTo(51.5, 22)
            ..lineTo(39.5, 22)
            ..close(),
          2,
        );
        shape(Path()..addRect(const Rect.fromLTWH(52.5, 12, 9.5, 9.5)), 3);
        final frame = Rect.fromLTWH(5, 33, 52, 18);
        canvas.drawRect(frame, outline);
        canvas.drawLine(const Offset(5, 42), const Offset(57, 42), outline);
        for (var i = 1; i < 5; i++) {
          canvas.drawLine(
            Offset(5 + i * 10.4, 33),
            Offset(5 + i * 10.4, 51),
            outline,
          );
        }
        for (var i = 0; i < 3; i++) {
          circle(Offset(10.2 + i * 10.4, 37.5), 3.6, 5);
        }
      case _ActivityIcon.wordSprint:
        tile(const Rect.fromLTWH(3, 20, 48, 29), 'pib', 4, 23);
        shape(
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(44, 3, 10, 5),
              const Radius.circular(1),
            ),
          ),
          0,
        );
        canvas.drawLine(const Offset(49, 8), const Offset(49, 11), outline);
        circle(const Offset(49, 20), 10, 0, textSurface: true);
        canvas.drawPath(
          Path()
            ..moveTo(49, 13)
            ..lineTo(49, 20)
            ..lineTo(54, 23),
          outline..strokeWidth = 1.8,
        );
      case _ActivityIcon.readAndFind:
        tile(const Rect.fromLTWH(2, 3, 35, 23), 'cat', 4, 19);
        canvas.drawPath(
          Path()
            ..moveTo(12, 29)
            ..lineTo(12, 38)
            ..lineTo(24, 38)
            ..moveTo(20, 34)
            ..lineTo(24, 38)
            ..lineTo(20, 42),
          outline..strokeWidth = 1.8,
        );
        shape(
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(29, 24, 31, 28),
              const Radius.circular(4),
            ),
          ),
          3,
          textSurface: true,
        );
        shape(
          Path()
            ..moveTo(33, 36)
            ..lineTo(33, 28)
            ..lineTo(41, 32)
            ..lineTo(48, 32)
            ..lineTo(56, 28)
            ..lineTo(56, 37)
            ..close(),
          1,
        );
        circle(const Offset(44.5, 40), 10, 1);
        final dots = Paint()..color = colors.foreground;
        for (final x in [41.0, 48.0]) {
          canvas.drawCircle(Offset(x, 38), 1.2, dots);
        }
        canvas.drawPath(
          Path()
            ..moveTo(43, 42)
            ..lineTo(46, 42)
            ..lineTo(44.5, 44)
            ..close(),
          dots,
        );
      case _ActivityIcon.makeBelieve:
        tile(const Rect.fromLTWH(2, 21, 36, 28), 'pib', 2, 21);
        for (final (x, spread) in [(40.0, 5.0), (45.0, 9.0), (50.0, 13.0)]) {
          canvas.drawPath(
            Path()
              ..moveTo(x, 34 - spread)
              ..quadraticBezierTo(x + spread * .7, 34, x, 34 + spread),
            outline..strokeWidth = 1.8,
          );
        }
        shape(
          Path()
            ..moveTo(39, 2)
            ..quadraticBezierTo(40, 11, 47, 12)
            ..quadraticBezierTo(40, 13, 39, 20)
            ..quadraticBezierTo(38, 13, 31, 12)
            ..quadraticBezierTo(38, 11, 39, 2)
            ..close(),
          0,
        );
      case _ActivityIcon.numberParts:
        canvas.drawLine(
          const Offset(31, 15),
          const Offset(15, 40),
          outline..strokeWidth = 1.8,
        );
        canvas.drawLine(const Offset(31, 15), const Offset(47, 40), outline);
        for (final (center, text, color) in [
          (const Offset(31, 13), '5', 1),
          (const Offset(14, 41), '2', 4),
          (const Offset(48, 41), '3', 0),
        ]) {
          circle(center, 11, color, textSurface: true);
          label(text, center, 19);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ActivityIconPainter oldDelegate) =>
      colors != oldDelegate.colors || icon != oldDelegate.icon;
}
