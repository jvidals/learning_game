import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'progress_controller.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'device_services.dart';
import 'screens/home_page.dart';

void main() => runApp(RainbowGardenApp(services: AndroidServices()));

class RainbowGardenApp extends StatefulWidget {
  const RainbowGardenApp({super.key, required this.services});
  final DeviceServices services;
  @override
  State<RainbowGardenApp> createState() => _RainbowGardenAppState();
}

class _RainbowGardenAppState extends State<RainbowGardenApp> {
  late final ProgressController _controller = ProgressController(
    widget.services,
  );
  AppAppearance _appearance = AppAppearance.system;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_settingsChanged);
    _controller.load();
  }

  void _settingsChanged() {
    final next = _controller.effectiveSettings.appearance;
    if (next != _appearance) setState(() => _appearance = next);
  }

  @override
  void dispose() {
    _controller.removeListener(_settingsChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Learning Corner',
    debugShowCheckedModeBanner: false,
    theme: GardenTheme.light,
    darkTheme: GardenTheme.dark,
    themeMode: switch (_appearance) {
      AppAppearance.system => ThemeMode.system,
      AppAppearance.light => ThemeMode.light,
      AppAppearance.dark => ThemeMode.dark,
    },
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: GardenTheme.systemBars(Theme.of(context).brightness),
      child: child!,
    ),
    home: HomePage(services: widget.services, controller: _controller),
  );
}
