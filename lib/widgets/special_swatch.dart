import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sketch_ink.dart';

/// A static ink sample shared by the picker, strip and brush-size preview.
class SpecialSwatch extends StatelessWidget {
  const SpecialSwatch({
    super.key,
    required this.special,
    required this.base,
    this.shape = BoxShape.rectangle,
    this.radius = 12,
  });

  final SketchSpecial special;
  final Color base;
  final BoxShape shape;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SpecialSwatchPainter(special, base, shape, radius),
    child: const SizedBox.expand(),
  );
}

class _SpecialSwatchPainter extends CustomPainter {
  const _SpecialSwatchPainter(this.special, this.base, this.shape, this.radius);

  final SketchSpecial special;
  final Color base;
  final BoxShape shape;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final clip = Path();
    if (shape == BoxShape.circle) {
      clip.addOval(rect);
    } else {
      clip.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }
    canvas.save();
    canvas.clipPath(clip);
    switch (special) {
      case SketchSpecial.rainbow:
        canvas.drawRect(
          rect,
          Paint()..shader = sketchRainbowSwatch.createShader(rect),
        );
      case SketchSpecial.glitter:
        canvas.drawRect(rect, Paint()..color = base);
        const positions = [
          Offset(.23, .28),
          Offset(.69, .22),
          Offset(.49, .56),
          Offset(.22, .76),
          Offset(.77, .73),
        ];
        for (var i = 0; i < positions.length; i++) {
          final center = Offset(
            positions[i].dx * size.width,
            positions[i].dy * size.height,
          );
          final arm = size.shortestSide * (i.isEven ? .12 : .08);
          final star = Path()
            ..moveTo(center.dx, center.dy - arm)
            ..lineTo(center.dx + arm * .24, center.dy - arm * .24)
            ..lineTo(center.dx + arm, center.dy)
            ..lineTo(center.dx + arm * .24, center.dy + arm * .24)
            ..lineTo(center.dx, center.dy + arm)
            ..lineTo(center.dx - arm * .24, center.dy + arm * .24)
            ..lineTo(center.dx - arm, center.dy)
            ..lineTo(center.dx - arm * .24, center.dy - arm * .24)
            ..close();
          canvas.drawPath(
            star,
            Paint()..color = i.isEven ? Colors.white : const Color(0xFFFFD54F),
          );
        }
      case SketchSpecial.neon:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF101018));
        final ringRadius = size.shortestSide * .28;
        final ring = Paint()
          ..color = base
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * .19;
        canvas.drawCircle(
          rect.center,
          ringRadius,
          ring
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(1, size.shortestSide * .1),
            ),
        );
        canvas.drawCircle(rect.center, ringRadius, ring..maskFilter = null);
        canvas.drawCircle(
          rect.center,
          ringRadius,
          ring
            ..color = Color.lerp(base, Colors.white, .55)!
            ..strokeWidth = size.shortestSide * .075,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpecialSwatchPainter oldDelegate) =>
      special != oldDelegate.special ||
      base != oldDelegate.base ||
      shape != oldDelegate.shape ||
      radius != oldDelegate.radius;
}
