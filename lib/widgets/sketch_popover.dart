import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// An awaitable picker that stays attached to its strip button on rotation.
Future<T?> showSketchPopover<T>(
  BuildContext context, {
  required GlobalKey anchor,
  required WidgetBuilder builder,
  String? semanticLabel,
}) => Navigator.of(context).push<T>(
  _SketchPopoverRoute<T>(
    anchor: anchor,
    builder: builder,
    semanticLabel: semanticLabel,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
    themes: InheritedTheme.capture(
      from: context,
      to: Navigator.of(context).context,
    ),
  ),
);

enum _Edge { top, left, bottom, right }

Rect? _anchorRect(GlobalKey anchor) {
  final box = anchor.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Sketch pad strips sit on the screen's two short ends, so the anchor's edge
/// is top/bottom in portrait and left/right in landscape. Choosing by nearest
/// distance alone would pick the side edge for icons grouped in a corner.
_Edge _nearestEdge(Rect rect, Size size) => size.height >= size.width
    ? (rect.center.dy <= size.height / 2 ? _Edge.top : _Edge.bottom)
    : (rect.center.dx <= size.width / 2 ? _Edge.left : _Edge.right);

class _SketchPopoverRoute<T> extends PopupRoute<T> {
  _SketchPopoverRoute({
    required this.anchor,
    required this.builder,
    required this.semanticLabel,
    required this.barrierLabel,
    required this.reduceMotion,
    required this.themes,
  });

  final GlobalKey anchor;
  final WidgetBuilder builder;
  final String? semanticLabel;
  final bool reduceMotion;
  final CapturedThemes themes;

  @override
  final String barrierLabel;
  @override
  bool get barrierDismissible => true;
  @override
  Color get barrierColor => Colors.transparent;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 140);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Subscribe here as well as in the host: the page below must lay out before
    // the host's second pass reads the anchor's new global coordinates.
    MediaQuery.sizeOf(context);
    return themes.wrap(
      _PopoverHost(
        anchor: anchor,
        builder: builder,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

class _PopoverHost extends StatefulWidget {
  const _PopoverHost({
    required this.anchor,
    required this.builder,
    this.semanticLabel,
  });
  final GlobalKey anchor;
  final WidgetBuilder builder;
  final String? semanticLabel;

  @override
  State<_PopoverHost> createState() => _PopoverHostState();
}

class _PopoverHostState extends State<_PopoverHost> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (_lastSize != size) {
      _lastSize = size;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    final rect = _anchorRect(widget.anchor);
    final edge = rect == null ? null : _nearestEdge(rect, size);
    final alignment = switch (edge) {
      _Edge.top => Alignment.topCenter,
      _Edge.left => Alignment.centerLeft,
      _Edge.bottom => Alignment.bottomCenter,
      _Edge.right => Alignment.centerRight,
      null => Alignment.center,
    };
    final colors = GardenColors.of(context);
    final animation = ModalRoute.of(
      context,
    )!.animation!.drive(CurveTween(curve: Curves.easeOut));
    Widget card = Material(
      key: const ValueKey('sketch-popover'),
      color: colors.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: widget.semanticLabel,
        explicitChildNodes: true,
        child: SingleChildScrollView(child: widget.builder(context)),
      ),
    );
    // Animate the card itself so it grows from the side touching the icon.
    if (!MediaQuery.disableAnimationsOf(context)) {
      card = FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .94, end: 1).animate(animation),
          alignment: alignment,
          child: card,
        ),
      );
    }
    return LayoutBuilder(
      // Global transforms can read ancestor sizes (page transitions do this).
      // Read them in the layout callback, where Flutter permits those reads.
      builder: (context, constraints) => CustomSingleChildLayout(
        delegate: _PopoverPosition(widget.anchor),
        child: card,
      ),
    );
  }
}

class _PopoverPosition extends SingleChildLayoutDelegate {
  _PopoverPosition(GlobalKey anchor) : _rect = _anchorRect(anchor);
  final Rect? _rect;
  static const margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final rect = _rect;
    var width = math.max(0.0, size.width - margin * 2);
    var height = math.max(0.0, size.height - margin * 2);
    if (rect != null) {
      switch (_nearestEdge(rect, size)) {
        case _Edge.top:
          height = math.max(0, size.height - rect.bottom - margin);
        case _Edge.left:
          width = math.max(0, size.width - rect.right - margin);
        case _Edge.bottom:
          height = math.max(0, rect.top - margin);
        case _Edge.right:
          width = math.max(0, rect.left - margin);
      }
    }
    return BoxConstraints(maxWidth: width, maxHeight: height);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rect = _rect;
    if (rect == null) {
      return Offset(
        (size.width - childSize.width) / 2,
        (size.height - childSize.height) / 2,
      );
    }
    final x = (rect.center.dx - childSize.width / 2)
        .clamp(margin, math.max(margin, size.width - childSize.width - margin))
        .toDouble();
    final y = (rect.center.dy - childSize.height / 2)
        .clamp(
          margin,
          math.max(margin, size.height - childSize.height - margin),
        )
        .toDouble();
    return switch (_nearestEdge(rect, size)) {
      _Edge.top => Offset(x, rect.bottom),
      _Edge.left => Offset(rect.right, y),
      _Edge.bottom => Offset(x, rect.top - childSize.height),
      _Edge.right => Offset(rect.left - childSize.width, y),
    };
  }

  @override
  bool shouldRelayout(_PopoverPosition oldDelegate) => true;
}
