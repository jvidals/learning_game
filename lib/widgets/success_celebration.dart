import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// A decorative burst that keeps the card's layout and semantics stationary.
class SuccessCelebration extends StatelessWidget {
  const SuccessCelebration({
    super.key,
    required this.animation,
    required this.active,
    required this.child,
  });
  final Animation<double> animation;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final progress = animation.value;
          if (progress <= 0 || progress >= 1) return child!;
          final pop = math.sin(math.pi * (progress / .65).clamp(0, 1));
          return Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(scale: 1 + .08 * pop, child: child),
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      key: const ValueKey('success-sparkles'),
                      painter: _SparklesPainter(
                        progress,
                        GardenColors.of(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  const _SparklesPainter(this.progress, this.colors);
  final GardenColors colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final travel = Curves.easeOut.transform(progress);
    final opacity = (1 - progress) * (progress / .12).clamp(0, 1);
    final radius = 7.0 * (1 - .35 * progress);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final center = Offset(
        size.width / 2 + math.cos(angle) * (size.width / 2 + 18 * travel),
        size.height / 2 + math.sin(angle) * (size.height / 2 + 18 * travel),
      );
      final star = Path();
      for (var point = 0; point < 8; point++) {
        final r = point.isEven ? radius : radius * .35;
        final theta = point * math.pi / 4 - math.pi / 2;
        final x = center.dx + math.cos(theta) * r;
        final y = center.dy + math.sin(theta) * r;
        if (point == 0) {
          star.moveTo(x, y);
        } else {
          star.lineTo(x, y);
        }
      }
      star.close();
      canvas.drawPath(
        star,
        Paint()..color = colors.rainbow[i % 6].withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}
