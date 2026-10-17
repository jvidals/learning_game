import 'dart:math' as math;
import '../app_theme.dart';
import 'package:flutter/material.dart';

/// A separately accessible action that fits beside the game's title.
class SelectionCardAction extends StatelessWidget {
  const SelectionCardAction({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });
  final String label, semanticsLabel;
  final VoidCallback? onPressed;

  TextStyle _style(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!;

  Size size(BuildContext context, {double maxWidth = double.infinity}) {
    final natural = _measure(context, label, _style(context));
    final width = math.min(
      maxWidth,
      math.max(56.0, natural.width.ceilToDouble() + 16),
    );
    final text = _measure(
      context,
      label,
      _style(context),
      maxWidth: width - 16,
    );
    return Size(width, math.max(48, text.height.ceilToDouble() + 40));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bounds = size(context, maxWidth: constraints.maxWidth);
      return SizedBox(
        width: bounds.width,
        height: bounds.height,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            textStyle: _style(context),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.all(8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(child: Icon(Icons.tune_rounded, size: 20)),
              const SizedBox(height: 4),
              Text(label, semanticsLabel: semanticsLabel),
            ],
          ),
        ),
      );
    },
  );
}

Size _measure(
  BuildContext context,
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout(maxWidth: maxWidth);
  final size = painter.size;
  painter.dispose();
  return size;
}

class SelectionCard extends StatelessWidget {
  const SelectionCard({
    super.key,
    required this.title,
    required this.example,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.illustration,
    this.trailingAction,
    this.showPlayArrow = true,
  });
  final String title, example, subtitle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? illustration;
  final SelectionCardAction? trailingAction;
  final bool showPlayArrow;

  bool _stackArt(BuildContext context, double width) =>
      !showPlayArrow &&
      width < 400 &&
      MediaQuery.textScalerOf(context).scale(20) > 30;
  double _artWidth(BuildContext context, double width) =>
      _stackArt(context, width) ? 48 : 70;
  double _actionMaxWidth(double width) => math.max(56, width * .3);
  TextStyle _titleStyle(BuildContext context) => DefaultTextStyle.of(
    context,
  ).style.merge(const TextStyle(fontSize: 20, fontWeight: FontWeight.w800));
  TextStyle _subtitleStyle(BuildContext context) =>
      DefaultTextStyle.of(context).style.merge(
        TextStyle(fontSize: 14, color: GardenColors.of(context).secondary),
      );

  double preferredHeight(BuildContext context, double width) {
    final action = trailingAction?.size(
      context,
      maxWidth: _actionMaxWidth(width),
    );
    final stacked = _stackArt(context, width);
    final textWidth = math.max(
      1.0,
      width -
          (stacked ? 0 : _artWidth(context, width) + 14) -
          (action == null ? 36 : 38 + action.width) -
          (showPlayArrow ? 28 : 0),
    );
    var textHeight = _measure(
      context,
      title,
      _titleStyle(context),
      maxWidth: textWidth,
    ).height;
    if (subtitle.isNotEmpty) {
      textHeight +=
          4 +
          _measure(
            context,
            subtitle,
            _subtitleStyle(context),
            maxWidth: textWidth,
          ).height;
    }
    final primaryHeight = stacked
        ? 66 + 8 + textHeight
        : math.max(66, textHeight);
    return math
        .max(102, math.max(primaryHeight, action?.height ?? 0) + 36)
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final artWidth = _artWidth(context, constraints.maxWidth);
      final stacked = _stackArt(context, constraints.maxWidth);
      final art = Container(
        width: artWidth,
        height: 66,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GardenColors.of(context).resolve(
            Colors.white.withValues(alpha: .8),
            GardenColors.of(context).surface,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child:
            (artWidth < 70 && illustration != null
                ? FittedBox(child: illustration!)
                : illustration) ??
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                example,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: artWidth < 70 ? 24 : 29,
                  fontWeight: FontWeight.w800,
                  color: GardenColors.of(context).foreground,
                ),
              ),
            ),
      );
      final titleBlock = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle(context)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: _subtitleStyle(context)),
          ],
        ],
      );
      final primary = Semantics(
        button: true,
        onTap: onTap,
        enabled: onTap != null,
        label: subtitle.isEmpty ? title : '$title. $subtitle',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                trailingAction == null ? 18 : 8,
                18,
              ),
              child: stacked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [art, const SizedBox(height: 8), titleBlock],
                    )
                  : Row(
                      children: [
                        art,
                        const SizedBox(width: 14),
                        Expanded(child: titleBlock),
                        if (showPlayArrow) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.play_arrow_rounded),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      );
      return Material(
        color: GardenColors.of(context).card(color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: GardenColors.of(context).isDark
              ? BorderSide(color: GardenColors.of(context).accent(color))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: trailingAction == null
            ? primary
            : Row(
                crossAxisAlignment: constraints.hasBoundedHeight
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                children: [
                  Expanded(child: primary),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      widthFactor: 1,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _actionMaxWidth(constraints.maxWidth),
                        ),
                        child: trailingAction!,
                      ),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

/// A shared one-column phone / two-column tablet arrangement.
class SelectionGrid extends StatelessWidget {
  const SelectionGrid({
    super.key,
    required this.children,
    this.uniformHeight = false,
  });
  final List<SelectionCard> children;
  final bool uniformHeight;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 500 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      final height = uniformHeight
          ? children.fold<double>(
              102,
              (height, card) =>
                  math.max(height, card.preferredHeight(context, width)),
            )
          : null;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(width: width, height: height, child: child),
        ],
      );
    },
  );
}
