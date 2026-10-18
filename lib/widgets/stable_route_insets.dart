import 'package:flutter/material.dart';

/// Keeps covered routes from relaying out when another route changes system UI.
class StableRouteInsets extends StatefulWidget {
  const StableRouteInsets({super.key, required this.child});

  final Widget child;

  @override
  State<StableRouteInsets> createState() => _StableRouteInsetsState();
}

class _StableRouteInsetsState extends State<StableRouteInsets> {
  ModalRoute<dynamic>? _route;
  Animation<double>? _secondaryAnimation;
  MediaQueryData? _lastUncovered;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route = route;
      _lastUncovered = null;
    }
    final animation = route?.secondaryAnimation;
    if (animation != _secondaryAnimation) {
      _secondaryAnimation?.removeStatusListener(_statusChanged);
      _secondaryAnimation = animation;
      animation?.addStatusListener(_statusChanged);
    }
  }

  void _statusChanged(AnimationStatus status) => setState(() {});

  @override
  void dispose() {
    _secondaryAnimation?.removeStatusListener(_statusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_route == null) return widget.child;
    final data = MediaQuery.of(context);
    final covered =
        _secondaryAnimation != null &&
        _secondaryAnimation!.status != AnimationStatus.dismissed;
    if (!covered) {
      _lastUncovered = data;
    }
    final saved = _lastUncovered;
    return MediaQuery(
      data: covered && saved != null
          ? data.copyWith(
              padding: saved.padding,
              viewPadding: saved.viewPadding,
              viewInsets: saved.viewInsets,
            )
          : data,
      child: widget.child,
    );
  }
}
