import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../tap_challenge.dart';

/// A companion supplies presentation only. Legend and arena use this same map.
class TapTargetAppearance {
  const TapTargetAppearance({required this.label, required this.builder});
  final String label;
  final WidgetBuilder builder;
}

class TapChallengeSkin {
  const TapChallengeSkin({
    required this.regular,
    required this.bonus,
    required this.hazard,
  });
  final TapTargetAppearance regular, bonus, hazard;
  TapTargetAppearance operator [](TapTargetKind kind) => switch (kind) {
    TapTargetKind.regular => regular,
    TapTargetKind.bonus => bonus,
    TapTargetKind.hazard => hazard,
  };
  static const unicorn = TapChallengeSkin(
    regular: TapTargetAppearance(label: 'Star', builder: _star),
    bonus: TapTargetAppearance(label: 'Rainbow', builder: _rainbow),
    hazard: TapTargetAppearance(label: 'Bomb', builder: _bomb),
  );
  static Widget _star(BuildContext context) =>
      _TargetArt(kind: TapTargetKind.regular, colors: GardenColors.of(context));
  static Widget _rainbow(BuildContext context) =>
      _TargetArt(kind: TapTargetKind.bonus, colors: GardenColors.of(context));
  static Widget _bomb(BuildContext context) =>
      _TargetArt(kind: TapTargetKind.hazard, colors: GardenColors.of(context));
}

class TapChallengeIllustration extends StatelessWidget {
  const TapChallengeIllustration({super.key});
  @override
  Widget build(BuildContext context) => Icon(
    Icons.touch_app_rounded,
    size: 56,
    color: GardenColors.of(context).foreground,
  );
}

class _TargetArt extends StatelessWidget {
  const _TargetArt({required this.kind, required this.colors});
  final TapTargetKind kind;
  final GardenColors colors;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _TargetPainter(kind, colors),
      child: const SizedBox.expand(),
    ),
  );
}

class _TargetPainter extends CustomPainter {
  const _TargetPainter(this.kind, this.colors);
  final TapTargetKind kind;
  final GardenColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);
    if (kind == TapTargetKind.regular) {
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final a = -pi / 2 + i * pi / 5;
        final radius = i.isEven ? 40.0 : 19.0;
        final x = 50 + cos(a) * radius, y = 51 + sin(a) * radius;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = colors.rainbow[2]);
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.foreground
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if (kind == TapTargetKind.bonus) {
      // A contrasting silhouette keeps the pastel rainbow readable in Light.
      for (final radius in [43.5, 9.5]) {
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(50, 72), radius: radius),
          pi,
          pi,
          false,
          Paint()
            ..color = colors.foreground
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      for (var i = 0; i < 6; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(50, 72), radius: 40.0 - i * 5.5),
          pi,
          pi,
          false,
          Paint()
            ..color = colors.rainbow[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.5,
        );
      }
      for (final x in [12.0, 88.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, 74), width: 20, height: 13),
          Paint()..color = colors.foreground,
        );
      }
    } else {
      final outline = Paint()
        ..color = colors.foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawPath(
        Path()
          ..moveTo(56, 26)
          ..quadraticBezierTo(55, 10, 73, 14),
        outline,
      );
      canvas.drawCircle(
        const Offset(48, 58),
        31,
        Paint()..color = const Color(0xFF292631),
      );
      canvas.drawCircle(
        const Offset(48, 58),
        31,
        Paint()
          ..color = colors.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, 23, 17, 12),
          const Radius.circular(3),
        ),
        Paint()..color = colors.foreground,
      );
      final mark = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(40, 50), const Offset(56, 66), mark);
      canvas.drawLine(const Offset(56, 50), const Offset(40, 66), mark);
      canvas.drawCircle(
        const Offset(77, 14),
        5,
        Paint()..color = colors.rainbow[1],
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TargetPainter old) =>
      old.kind != kind || old.colors != colors;
}
