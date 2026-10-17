import '../app_theme.dart';
import 'package:flutter/material.dart';

/// Paints feedback above the card without changing its layout or hit target.
class RetryMarker extends StatelessWidget {
  const RetryMarker({
    super.key,
    required this.animation,
    required this.active,
    required this.reducedMotion,
    required this.child,
  });

  final Animation<double> animation;
  final bool active, reducedMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    clipBehavior: Clip.none,
    children: [
      child,
      if (active)
        PositionedDirectional(
          top: 2,
          end: 2,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: animation,
                child: DecoratedBox(
                  key: const ValueKey('retry-marker'),
                  decoration: BoxDecoration(
                    color: GardenColors.of(context).retrySurface,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 24,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: GardenColors.of(context).retryInk,
                    ),
                  ),
                ),
                builder: (context, marker) => Opacity(
                  opacity: reducedMotion
                      ? 1
                      : 1 - const Interval(.25, 1).transform(animation.value),
                  child: marker,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
