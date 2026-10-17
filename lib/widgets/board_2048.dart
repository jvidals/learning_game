import '../app_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../game_2048.dart';

/// The 16 slots stay fixed while temporary tile faces slide above them.
class Board2048 extends StatelessWidget {
  const Board2048({
    super.key,
    required this.session,
    required this.animation,
    this.move,
  });
  final Game2048State session;
  final Animation<double> animation;
  final Game2048Move? move;

  Widget _tile(BuildContext context, int value, double side) {
    final colors = GardenColors.of(context);
    final color = colors.tile(value);
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value == 2048 ? colors.goldBorder : colors.tileBorder,
          width: value == 2048 ? 3 : 2,
        ),
        boxShadow: value == 0
            ? null
            : [BoxShadow(color: colors.shadow, offset: const Offset(0, 3))],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: value == 0
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                maxLines: 1,
                style: TextStyle(
                  fontSize: min(38, side * .46),
                  fontWeight: FontWeight.w800,
                  color: colors.foreground,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final side = (constraints.maxWidth - gap * 3 - 4) / 4;
        Offset origin(int slot) =>
            Offset(2 + (slot % 4) * (side + gap), (slot ~/ 4) * (side + gap));
        Widget at(int slot, Widget child) => Positioned(
          left: origin(slot).dx,
          top: origin(slot).dy,
          width: side,
          height: side,
          child: child,
        );
        return Semantics(
          label: '2048 board',
          explicitChildNodes: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final slide = move != null && animation.value < .6;
                    final pop = move == null
                        ? 1.0
                        : ((animation.value - .6) / .4).clamp(0.0, 1.0);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < 16; i++)
                          at(i, _tile(context, 0, side)),
                        if (slide)
                          for (final flight in move!.flights)
                            Positioned(
                              left: Offset.lerp(
                                origin(flight.from),
                                origin(flight.to),
                                Curves.easeOutCubic.transform(
                                  animation.value / .6,
                                ),
                              )!.dx,
                              top: Offset.lerp(
                                origin(flight.from),
                                origin(flight.to),
                                Curves.easeOutCubic.transform(
                                  animation.value / .6,
                                ),
                              )!.dy,
                              child: _tile(context, flight.value, side),
                            )
                        else
                          for (var i = 0; i < 16; i++)
                            if (session.board[i] != 0)
                              at(
                                i,
                                Transform.scale(
                                  scale: move?.spawn == i
                                      ? .75 +
                                            .25 * Curves.easeOut.transform(pop)
                                      : move?.merged.contains(i) == true
                                      ? 1 + .1 * sin(pi * pop)
                                      : 1,
                                  child: _tile(context, session.board[i], side),
                                ),
                              ),
                      ],
                    );
                  },
                ),
              ),
              for (var i = 0; i < 16; i++)
                at(
                  i,
                  Semantics(
                    key: ValueKey('2048-cell-$i'),
                    label: 'Row ${i ~/ 4 + 1}, column ${i % 4 + 1}',
                    value: session.board[i] == 0
                        ? 'Empty'
                        : '${session.board[i]}',
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
