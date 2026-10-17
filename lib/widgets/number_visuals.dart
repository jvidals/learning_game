import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../number_sense.dart';
import 'visual_question.dart';

class SameNumberPrompt extends StatelessWidget {
  const SameNumberPrompt({
    super.key,
    required this.visual,
    required this.context,
  });
  final SameNumberVisual visual;
  final VisualQuestionContext context;

  @override
  Widget build(BuildContext buildContext) => LayoutBuilder(
    builder: (buildContext, constraints) {
      final scale = MediaQuery.textScalerOf(buildContext).scale(16) / 16;
      // Each column needs room for its heading as well as the visual. Larger
      // text increases that minimum instead of squeezing the three headings.
      final wide = (constraints.maxWidth - 16) / 3 >= 96 * math.max(1, scale);
      final visualExtent = wide
          ? math.min(96.0, (constraints.maxWidth - 16) / 3 - 16)
          : 96.0;
      final panels = [
        for (final kind in NumberRepresentation.values)
          _Panel(
            key: ValueKey('same-panel-${kind.name}'),
            title: kind.label,
            label: kind == visual.missingKind && !context.answered
                ? 'Missing ${kind.label.toLowerCase()}'
                : kind.describe(visual.quantity, visual.shape),
            compact: true,
            child: SizedBox(
              height: visualExtent,
              child: Center(
                child: kind == visual.missingKind && !context.answered
                    ? const _QuestionMark()
                    : _Representation(
                        kind: kind,
                        quantity: visual.quantity,
                        shape: visual.shape,
                        seed: visual.seed,
                        hint: context.hint,
                        maxWidth: visualExtent,
                      ),
              ),
            ),
          ),
      ];
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < panels.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: panels[i]),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < panels.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    panels[i],
                  ],
                ],
              ),
      );
    },
  );
}

class SameNumberChoice extends StatelessWidget {
  const SameNumberChoice({
    super.key,
    required this.visual,
    required this.choice,
    required this.context,
  });
  final SameNumberVisual visual;
  final String choice;
  final VisualQuestionContext context;

  @override
  Widget build(BuildContext buildContext) => Semantics(
    label: visual.choiceLabel(choice),
    excludeSemantics: true,
    child: _Representation(
      kind: visual.missingKind,
      quantity: int.parse(choice),
      shape: visual.shape,
      seed: visual.seed,
      hint: context.hint,
      maxWidth: 160,
      compactChoice: true,
    ),
  );
}

class NumberPartsPrompt extends StatelessWidget {
  const NumberPartsPrompt({
    super.key,
    required this.visual,
    required this.context,
  });
  final NumberPartsVisual visual;
  final VisualQuestionContext context;

  @override
  Widget build(BuildContext buildContext) {
    final showPartition = context.hint || context.answered;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Panel(
            title: 'Whole',
            includeChildSemantics: visual.makeTen,
            label: visual.makeTen
                ? 'Whole: Number 10'
                : 'Whole: Number ${visual.total}, ${visual.total} circles${showPartition ? ', ${visual.part} filled and ${visual.missing} outlined' : ''}',
            child: Column(
              children: [
                ExcludeSemantics(child: _Numeral(visual.total)),
                if (visual.makeTen)
                  Semantics(
                    label:
                        'Ten frame showing ${context.answered ? 10 : visual.part}${showPartition ? ', ${visual.missing} ${context.answered ? 'joined' : 'empty'} cells' : ''}',
                    excludeSemantics: true,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: _TenFrame(
                          key: showPartition
                              ? const ValueKey('part-whole-hint')
                              : null,
                          quantity: context.answered ? 10 : visual.part,
                          partition: showPartition ? visual.part : null,
                          joined: context.answered,
                        ),
                      ),
                    ),
                  )
                else
                  _Collection(
                    key: showPartition
                        ? const ValueKey('part-whole-hint')
                        : null,
                    quantity: visual.total,
                    filled: showPartition ? visual.part : null,
                    joined: context.answered,
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: CustomPaint(
              painter: _BondLines(GardenColors.of(buildContext).foreground),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Panel(
                  title: 'Part',
                  label:
                      '${visual.part} ${visual.part == 1 ? 'circle' : 'circles'}',
                  child: _Collection(quantity: visual.part),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Panel(
                  title: 'Part',
                  label: context.answered
                      ? '${visual.missing} ${visual.missing == 1 ? 'circle' : 'circles'}'
                      : 'Missing part',
                  child: context.answered
                      ? _Collection(quantity: visual.missing, outlined: true)
                      : const _QuestionMark(),
                ),
              ),
            ],
          ),
          if (context.answered)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '${visual.part} + ${visual.missing} = ${visual.total}',
                key: const ValueKey('parts-equation'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: GardenColors.of(buildContext).foreground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NumberPartsChoice extends StatelessWidget {
  const NumberPartsChoice({
    super.key,
    required this.visual,
    required this.choice,
    required this.context,
  });
  final NumberPartsVisual visual;
  final String choice;
  final VisualQuestionContext context;

  @override
  Widget build(BuildContext buildContext) => Semantics(
    label: visual.choiceLabel(choice),
    excludeSemantics: true,
    child: _Collection(quantity: int.parse(choice)),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.title,
    required this.label,
    required this.child,
    this.compact = false,
    this.includeChildSemantics = false,
  });
  final bool compact, includeChildSemantics;
  final String title, label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    return Semantics(
      label: label,
      container: includeChildSemantics,
      explicitChildNodes: includeChildSemantics,
      excludeSemantics: !includeChildSemantics,
      child: Container(
        padding: EdgeInsets.all(compact ? 8 : 10),
        decoration: BoxDecoration(
          color: colors.mutedSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: colors.secondary),
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuestionMark extends StatelessWidget {
  const _QuestionMark();
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      '?',
      style: TextStyle(fontSize: 56, fontWeight: FontWeight.w600),
    ),
  );
}

class _Numeral extends StatelessWidget {
  const _Numeral(this.quantity);
  final int quantity;
  @override
  Widget build(BuildContext context) => Text(
    '$quantity',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w600,
      color: GardenColors.of(context).foreground,
    ),
  );
}

class _Representation extends StatelessWidget {
  const _Representation({
    required this.kind,
    required this.quantity,
    required this.shape,
    required this.seed,
    required this.hint,
    this.maxWidth = 160,
    this.compactChoice = false,
  });
  final bool compactChoice;
  final double maxWidth;
  final NumberRepresentation kind;
  final int quantity, seed;
  final NumberShape shape;
  final bool hint;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: switch (kind) {
        NumberRepresentation.numeral => _Numeral(quantity),
        NumberRepresentation.tenFrame => _TenFrame(
          quantity: quantity,
          hint: hint,
        ),
        NumberRepresentation.picture => _Collection(
          quantity: quantity,
          shape: shape,
          seed: seed,
          scattered: true,
          squarePicture: !compactChoice,
          hint: hint,
        ),
      },
    ),
  );
}

/// A ten frame always keeps ten outlined cells, including when empty.
class _TenFrame extends StatelessWidget {
  const _TenFrame({
    super.key,
    required this.quantity,
    this.hint = false,
    this.partition,
    this.joined = false,
  });
  final int quantity;
  final bool hint, joined;
  final int? partition;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hint && quantity >= 5)
          Column(
            key: const ValueKey('five-bracket'),
            children: [
              Text(
                '5',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
              SizedBox(
                height: 10,
                width: double.infinity,
                child: CustomPaint(painter: _BracketPainter(colors.foreground)),
              ),
            ],
          ),
        for (var row = 0; row < 2; row++)
          Row(
            children: [
              for (var col = 0; col < 5; col++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      // Fixed padding left only a few pixels for each dot in
                      // compact three-column panels; scale it with the cell.
                      builder: (context, cell) => Container(
                        margin: const EdgeInsets.all(.5),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.foreground),
                        ),
                        padding: EdgeInsets.all(
                          (cell.maxWidth * .08).clamp(1.0, 3.0),
                        ),
                        child: row * 5 + col < quantity || partition != null
                            ? _Shape(
                                shape: NumberShape.circle,
                                outlined:
                                    partition != null &&
                                    row * 5 + col >= partition!,
                                joined: joined,
                                number: hint && row * 5 + col < quantity
                                    ? row * 5 + col + 1
                                    : null,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Neutral shapes have no individual boxes. Pictures use stable shuffled
/// positions; part dots use familiar dice patterns, then two rows of five.
class _Collection extends StatelessWidget {
  const _Collection({
    super.key,
    required this.quantity,
    this.shape = NumberShape.circle,
    this.seed = 0,
    this.scattered = false,
    this.squarePicture = true,
    this.hint = false,
    this.filled,
    this.outlined = false,
    this.joined = false,
  });
  final int quantity, seed;
  final NumberShape shape;
  final bool scattered, squarePicture, hint, outlined, joined;
  final int? filled;

  // Coordinates on a three-by-three die. Six uses two columns of three.
  static const _dice = <List<int>>[
    [],
    [4],
    [0, 8],
    [0, 4, 8],
    [0, 2, 6, 8],
    [0, 2, 4, 6, 8],
    [0, 2, 3, 5, 6, 8],
  ];

  @override
  Widget build(BuildContext context) => Center(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          scattered ? (squarePicture ? 96.0 : 112.0) : 144.0,
          constraints.maxWidth,
        );
        final height = scattered && squarePicture ? width : 64.0;
        final rng = math.Random(seed);
        final columns = scattered
            ? 4
            : quantity <= 6
            ? 3
            : 5;
        final rows = scattered
            ? 3
            : quantity <= 6
            ? 3
            : 2;
        final slots = scattered
            ? (List.generate(
                12,
                (i) => i,
              )..shuffle(rng)).take(quantity).toList()
            : quantity <= 6
            ? _dice[quantity]
            : List.generate(quantity, (i) => i);
        // A die is square and centered even inside a wide part panel.
        final patternWidth = !scattered && quantity <= 6
            ? math.min(width, height)
            : width;
        final cellWidth = patternWidth / columns;
        final cellHeight = height / rows;
        // Scattered pictures keep little jitter, so shapes can fill more of
        // their cell and stay countable in compact three-column panels.
        final size = math.min(
          28.0,
          math.min(cellWidth, cellHeight) * (scattered ? .95 : .78),
        );
        final points = [
          for (final slot in slots)
            Offset(
              (width - patternWidth) / 2 +
                  (slot % columns + .5) * cellWidth +
                  (scattered ? (rng.nextDouble() - .5) * cellWidth * .04 : 0),
              (slot ~/ columns + .5) * cellHeight +
                  (scattered ? (rng.nextDouble() - .5) * cellHeight * .04 : 0),
            ),
        ];
        // Number hints by reading rows, then columns. Slot rows remain stable
        // despite the small jitter, and hinting never moves the objects.
        final readingOrder = List.generate(quantity, (i) => i)
          ..sort((a, b) {
            final row = (slots[a] ~/ columns).compareTo(slots[b] ~/ columns);
            return row != 0 ? row : points[a].dx.compareTo(points[b].dx);
          });
        return SizedBox(
          width: width,
          height: height,
          child: quantity == 0 && !scattered
              ? Center(
                  child: Container(
                    key: const ValueKey('empty-dot-frame'),
                    width: math.min(width, 64),
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: GardenColors.of(context).outline,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    for (var i = 0; i < quantity; i++)
                      Positioned(
                        left: points[i].dx - size / 2,
                        top: points[i].dy - size / 2,
                        width: size,
                        height: size,
                        child: _Shape(
                          shape: shape,
                          outlined: outlined || filled != null && i >= filled!,
                          joined: joined,
                          number: hint ? readingOrder.indexOf(i) + 1 : null,
                        ),
                      ),
                  ],
                ),
        );
      },
    ),
  );
}

class _Shape extends StatelessWidget {
  const _Shape({
    required this.shape,
    this.outlined = false,
    this.joined = false,
    this.number,
  });
  final NumberShape shape;
  final bool outlined, joined;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    return CustomPaint(
      painter: _ShapePainter(
        shape,
        outlined ? colors.successText : colors.primary,
        outlined,
        joined,
      ),
      child: number == null
          ? null
          : Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$number',
                  key: ValueKey('count-number-$number'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.onDirection,
                  ),
                ),
              ),
            ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter(this.shape, this.color, this.outlined, this.joined);
  final NumberShape shape;
  final Color color;
  final bool outlined, joined;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final path = switch (shape) {
      NumberShape.circle => Path()..addOval(rect),
      NumberShape.square => Path()..addRect(rect.deflate(2)),
      NumberShape.triangle =>
        Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close(),
    };
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = outlined ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 2.5
        ..isAntiAlias = true,
    );
    // A small centre dot keeps the second part visibly distinct after joining.
    if (outlined && joined) {
      canvas.drawCircle(
        rect.center,
        math.min(size.width, size.height) * .12,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.outlined != outlined ||
      oldDelegate.joined != joined;
}

class _BondLines extends CustomPainter {
  const _BondLines(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 4, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width * .75, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BondLines oldDelegate) => oldDelegate.color != color;
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(2, size.height)
        ..lineTo(2, 2)
        ..lineTo(size.width - 2, 2)
        ..lineTo(size.width - 2, size.height),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) => oldDelegate.color != color;
}
