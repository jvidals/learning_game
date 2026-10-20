import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../app_theme.dart';
import '../counting.dart';

class CountingPicture extends StatelessWidget {
  const CountingPicture({super.key, required this.object, this.size = 38});
  final CountingObject object;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ObjectPainter(object, GardenColors.of(context).isDark),
      ),
    ),
  );
}

class CountingBoard extends StatelessWidget {
  const CountingBoard({
    super.key,
    required this.scene,
    required this.work,
    required this.makeGroup,
    required this.maximum,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });
  final CountingScene scene;
  final CountingWork work;
  final bool makeGroup, hint, enabled;
  final int maximum;
  final VoidCallback onChanged;

  Widget _editableTray(BuildContext context) {
    final colors = GardenColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        work.resizeTray(math.max(280.0, constraints.maxWidth));
        final positions = work.positions;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // The Add button supplies the accessible, coordinate-free action.
            excludeFromSemantics: true,
            onTapUp: !enabled || work.items.length >= maximum
                ? null
                : (details) {
                    if (work.add(
                      position: math.Point(
                        details.localPosition.dx,
                        details.localPosition.dy,
                      ),
                    )) {
                      onChanged();
                    }
                  },
            child: SizedBox(
              key: const ValueKey('counting-collection'),
              width: work.trayWidth,
              height: work.trayHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.mutedSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Stack(
                  children: [
                    for (final (i, id) in work.items.indexed)
                      Positioned(
                        key: ValueKey('placed-counter-$id'),
                        left: positions[id]!.x - 28,
                        top: positions[id]!.y - 28,
                        width: 56,
                        height: 56,
                        child: Semantics(
                          label: hint
                              ? '${i + 1}, ${scene.object.label}, remove'
                              : '${scene.object.label}, remove',
                          button: true,
                          enabled: enabled,
                          child: _CounterHitRegion(
                            object: scene.object,
                            child: InkWell(
                              key: ValueKey('count-object-$i'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: !enabled
                                  ? null
                                  : () {
                                      if (work.remove(id)) onChanged();
                                    },
                              child: ExcludeSemantics(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CountingPicture(object: scene.object),
                                    if (hint)
                                      Positioned(
                                        right: 1,
                                        bottom: 1,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _collection(BuildContext context, {bool example = false}) {
    final count = scene.quantity;
    final frame = example || scene.arrangement == CountingArrangement.frame;
    final capacity = frame
        ? (count <= 5
              ? 5
              : count <= 10
              ? 10
              : 20)
        : count;
    final colors = GardenColors.of(context);
    final random = math.Random(scene.seed);
    return Container(
      key: ValueKey(example ? 'counting-example' : 'counting-collection'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: colors.mutedSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Five full 56 dp targets fit the standard 320 dp phone body.
          // Narrower windows scroll the frame rather than shrinking hit targets.
          final width = math.max(
            280.0,
            math.min(360.0, constraints.maxWidth - 2),
          );
          final cell = width / 5;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(width, constraints.maxWidth - 2),
              child: Center(
                child: SizedBox(
                  width: width,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      if (capacity == 0) const SizedBox(height: 72),
                      for (var i = 0; i < capacity; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            top: i >= 10 && i < 15 ? 12 : 0,
                          ),
                          child: SizedBox(
                            width: cell,
                            height: cell,
                            child: i >= count
                                ? const SizedBox.shrink()
                                : Semantics(
                                    label: hint || example
                                        ? '${i + 1}, ${scene.object.label}'
                                        : '${scene.object.label}${work.marked.contains(i) ? ', counted' : ', not marked'}',
                                    button: !example,
                                    selected:
                                        !example && work.marked.contains(i),
                                    child: InkWell(
                                      key: ValueKey(
                                        example
                                            ? 'example-object-$i'
                                            : 'count-object-$i',
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: !enabled || example
                                          ? null
                                          : () {
                                              work.toggleMark(i);
                                              onChanged();
                                            },
                                      child: ExcludeSemantics(
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Transform.translate(
                                              offset:
                                                  !frame &&
                                                      scene.arrangement ==
                                                          CountingArrangement
                                                              .scattered
                                                  ? Offset(
                                                      random.nextDouble() * 14 -
                                                          7,
                                                      random.nextDouble() * 14 -
                                                          7,
                                                    )
                                                  : Offset.zero,
                                              child: CountingPicture(
                                                object: scene.object,
                                              ),
                                            ),
                                            if (hint || example)
                                              Positioned(
                                                right: 1,
                                                bottom: 1,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.surface,
                                                  child: Text(
                                                    '${i + 1}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (!example &&
                                                work.marked.contains(i) &&
                                                !hint)
                                              const Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Icon(
                                                  Icons.check_circle,
                                                  size: 20,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (makeGroup) ...[
        Semantics(
          label: 'Make a group of ${scene.quantity} ${scene.object.label}s',
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${scene.quantity}',
                  key: const ValueKey('counting-target'),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 16),
                CountingPicture(object: scene.object, size: 48),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (makeGroup) _editableTray(context) else _collection(context),
      if (makeGroup) ...[
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          key: const ValueKey('add-count-object'),
          onPressed: enabled && work.items.length < maximum
              ? () {
                  work.add();
                  onChanged();
                }
              : null,
          icon: CountingPicture(object: scene.object, size: 30),
          label: Text('Add ${scene.object.label}'),
        ),
        const Text(
          'Tap an empty spot to add. Tap an object to remove.',
          textAlign: TextAlign.center,
        ),
        if (hint) ...[
          const SizedBox(height: 16),
          const Text(
            'Match this group',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          _collection(context, example: true),
        ],
      ],
    ],
  );
}

// Only pointer hit testing follows the picture. The full 56 dp semantics and
// keyboard action remain available independently of the picture spacing.
class _CounterHitRegion extends SingleChildRenderObjectWidget {
  const _CounterHitRegion({required this.object, required super.child});
  final CountingObject object;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCounterHitRegion(object);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCounterHitRegion renderObject,
  ) {
    renderObject.object = object;
  }
}

class _RenderCounterHitRegion extends RenderProxyBox {
  _RenderCounterHitRegion(this.object);
  CountingObject object;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // CountingPicture is centered at 38 dp, painted in a 40-unit coordinate space.
    final point =
        (position - Offset((size.width - 38) / 2, (size.height - 38) / 2)) *
        (40 / 38);
    final path = _counterOutline(object);
    var inside = path.contains(point);
    for (var i = 0; !inside && i < 8; i++) {
      final angle = i * math.pi / 4;
      inside = path.contains(
        point + Offset(math.cos(angle), math.sin(angle)) * .75,
      );
    }
    if (!inside) return false;
    return super.hitTest(result, position: position);
  }
}

Path _gemPath() => Path()
  ..moveTo(10, 5)
  ..lineTo(30, 5)
  ..lineTo(38, 16)
  ..lineTo(20, 37)
  ..lineTo(2, 16)
  ..close();

Path _counterOutline(CountingObject object) {
  final path = Path();
  switch (object) {
    case CountingObject.apple:
      path.addOval(const Rect.fromLTWH(5, 12, 30, 26));
      path.addOval(const Rect.fromLTWH(22, 4, 13, 7));
      // The visible 3-unit stem, including its slant.
      path.addPolygon(const [
        Offset(18.5, 16),
        Offset(19.5, 5),
        Offset(22.5, 5),
        Offset(21.5, 16),
      ], true);
    case CountingObject.flower:
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        path.addOval(
          Rect.fromCircle(
            center: Offset(20 + math.cos(a) * 10, 20 + math.sin(a) * 10),
            radius: 8,
          ),
        );
      }
      path.addOval(const Rect.fromLTWH(12, 12, 16, 16));
    case CountingObject.gem:
      return _gemPath();
  }
  return path;
}

class _ObjectPainter extends CustomPainter {
  const _ObjectPainter(this.object, this.dark);
  final CountingObject object;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 40);
    final p = Paint()..isAntiAlias = true;
    switch (object) {
      case CountingObject.apple:
        p.color = const Color(0xfff06582);
        canvas.drawOval(const Rect.fromLTWH(5, 12, 30, 26), p);
        if (!dark) {
          canvas.drawOval(
            const Rect.fromLTWH(5, 12, 30, 26),
            Paint()
              ..color = const Color(0xff563450)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
        p.color = const Color(0xff563450);
        p.strokeWidth = 3;
        canvas.drawLine(const Offset(20, 16), const Offset(21, 5), p);
        p.color = const Color(0xff75dcad);
        canvas.drawOval(const Rect.fromLTWH(22, 4, 13, 7), p);
        p.color = const Color(0xffffc3d0);
        canvas.drawOval(const Rect.fromLTWH(10, 17, 5, 10), p);
      case CountingObject.flower:
        p.color = const Color(0xffc3a1ff);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          final center = Offset(20 + math.cos(a) * 10, 20 + math.sin(a) * 10);
          canvas.drawCircle(center, 8, p);
          if (!dark) {
            canvas.drawCircle(
              center,
              8,
              Paint()
                ..color = const Color(0xff563450)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          }
        }
        p.color = const Color(0xfff6d66d);
        canvas.drawCircle(const Offset(20, 20), 8, p);
      case CountingObject.gem:
        final path = _gemPath();
        p.color = const Color(0xff75cfff);
        canvas.drawPath(path, p);
        p
          ..color = const Color(0xff35577d)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawPath(path, p);
        canvas.drawLine(const Offset(2, 16), const Offset(38, 16), p);
        canvas.drawLine(const Offset(12, 16), const Offset(20, 37), p);
        canvas.drawLine(const Offset(28, 16), const Offset(20, 37), p);
    }
  }

  @override
  bool shouldRepaint(_ObjectPainter oldDelegate) =>
      oldDelegate.object != object || oldDelegate.dark != dark;
}
