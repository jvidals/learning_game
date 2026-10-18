import 'package:flutter/material.dart';

/// A compact outline with a padded touch target for writing demonstrations.
class WatchButton extends StatelessWidget {
  const WatchButton({
    super.key,
    this.buttonKey,
    required this.semanticsLabel,
    required this.onPressed,
  });

  /// Placed on the tappable button so finders and taps reach it directly.
  final Key? buttonKey;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    button: true,
    child: OutlinedButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        iconSize: 20,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: const Icon(Icons.play_arrow_rounded),
      label: const ExcludeSemantics(child: Text('Watch')),
    ),
  );
}
