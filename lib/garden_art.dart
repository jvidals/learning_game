import 'app_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'progress.dart';
import 'companion.dart';

const ink = Color(0xFF39234F);
const rainbow = [
  Color(0xFFF27E98),
  Color(0xFFF3AA6D),
  Color(0xFFF5D477),
  Color(0xFF89CBAA),
  Color(0xFF80BBDD),
  Color(0xFFB6A0DC),
];

/// The learning screen keeps its familiar static rainbow and companion.
class GardenArt extends StatelessWidget {
  const GardenArt({
    super.key,
    this.height = 200,
    this.configuration,
    this.reactionTrigger = 0,
  });
  final double height;
  final CompanionConfiguration? configuration;
  final int reactionTrigger;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RainbowPainter(GardenColors.of(context)),
            ),
          ),
          Positioned.fill(
            top: height * .28,
            child: CompanionView(
              configuration: configuration ?? CompanionConfiguration(),
              reactionTrigger: reactionTrigger,
              reaction: CompanionReaction.happy,
              boundedCelebration: true,
              height: height * .72,
              animate: false,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RainbowPainter extends CustomPainter {
  const _RainbowPainter(this.colors);
  final GardenColors colors;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width / 460, size.height / 240);
    canvas.save();
    canvas.translate(
      (size.width - 460 * scale) / 2,
      (size.height - 240 * scale) / 2,
    );
    canvas.scale(scale);
    for (var i = 0; i < rainbow.length; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(230, 175), radius: 142 - i * 13),
        pi,
        pi,
        false,
        Paint()
          ..color = colors.rainbow[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RainbowPainter old) => old.colors != colors;
}
