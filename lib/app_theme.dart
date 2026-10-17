import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The shared UI palette. Asset/reward colors are deliberately independent.
/// See docs/dark_mode.md before introducing another surface or painted color.
@immutable
class GardenColors extends ThemeExtension<GardenColors> {
  const GardenColors._(this.darkness);
  static const light = GardenColors._(0);
  static const dark = GardenColors._(1);
  final double darkness;
  bool get isDark => darkness >= .5;

  static GardenColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GardenColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  Color resolve(Color light, Color dark) => darkness == 0
      ? light
      : darkness == 1
      ? dark
      : Color.lerp(light, dark, darkness)!;
  Color get background => resolve(const Color(0xFFFFFBF5), Colors.black);
  Color get surface => resolve(Colors.white, const Color(0xFF111115));
  Color get panel => resolve(const Color(0xFFF3EDF8), const Color(0xFF1C1B23));
  Color get foreground =>
      resolve(const Color(0xFF39234F), const Color(0xFFF3EEF8));
  Color get secondary =>
      resolve(const Color(0xFF705A7D), const Color(0xFFC6BDCF));
  Color get outline =>
      resolve(const Color(0xFFCFBDE6), const Color(0xFF8B8295));
  Color get primary =>
      resolve(const Color(0xFF79519D), const Color(0xFFC3A1FF));
  Color get selectedSurface =>
      resolve(const Color(0xFFEFE4FA), const Color(0xFF332344));
  Color get successSurface =>
      resolve(const Color(0xFFCCE8D6), const Color(0xFF143327));
  Color get successText =>
      resolve(const Color(0xFF28613B), const Color(0xFF75DCAD));
  Color get successBorder =>
      resolve(const Color(0xFF34734A), const Color(0xFF75DCAD));
  Color get mutedSurface =>
      resolve(const Color(0xFFF0EAF2), const Color(0xFF26212E));
  Color get retrySurface =>
      resolve(const Color(0xFFFFF2EF), const Color(0xFF3D2025));
  Color get retryInk =>
      resolve(const Color(0xFFC95149), const Color(0xFFFFA49B));
  Color get star => resolve(const Color(0xFF9A6500), const Color(0xFFF6D66D));
  Color get emptyStar =>
      resolve(const Color(0xFFB8A8C4), const Color(0xFF8B8295));
  Color get portrait =>
      resolve(const Color(0xFFF0E7F8), const Color(0xFF241C30));
  Color get writingRule =>
      resolve(const Color(0xFF7B7292), const Color(0xFF8B8295));
  Color get writingGuide =>
      resolve(const Color(0xFFCFBDE6), const Color(0xFF7955A3));
  Color get writingInk =>
      resolve(const Color(0xFF267B87), const Color(0xFF75DCAD));
  Color get writingDirection =>
      resolve(const Color(0xFF654089), const Color(0xFFF3EEF8));
  Color get onDirection => resolve(Colors.white, const Color(0xFF21152E));
  Color get shadow => resolve(const Color(0x2639234F), Colors.black);
  Color get boardSlot =>
      resolve(const Color(0x0B39234F), const Color(0xFF111115));
  Color get tileBorder => resolve(Colors.white, outline);
  Color get goldBorder =>
      resolve(const Color(0xFFC29127), const Color(0xFFF6D66D));
  static const lightRainbow = <Color>[
    Color(0xFFF27E98),
    Color(0xFFF3AA6D),
    Color(0xFFF5D477),
    Color(0xFF89CBAA),
    Color(0xFF80BBDD),
    Color(0xFFB6A0DC),
  ];
  static const darkRainbow = <Color>[
    Color(0xFFFF82AC),
    Color(0xFFFFB26B),
    Color(0xFFF6D66D),
    Color(0xFF75DCAD),
    Color(0xFF75CFFF),
    Color(0xFFC3A1FF),
  ];
  List<Color> get rainbow => darkness == 0
      ? lightRainbow
      : darkness == 1
      ? darkRainbow
      : [for (var i = 0; i < 6; i++) resolve(lightRainbow[i], darkRainbow[i])];
  Color accent(Color color) {
    final index = lightRainbow.indexOf(color);
    return index < 0 ? color : resolve(color, darkRainbow[index]);
  }

  Color card(Color color, {double white = .76}) => resolve(
    Color.lerp(color, Colors.white, white)!,
    Color.lerp(const Color(0xFF111115), accent(color), .18)!,
  );

  static final lightTiles = <Color>[
    for (final color in lightRainbow) Color.lerp(color, Colors.white, .76)!,
    const Color(0xFFF29A87),
    const Color(0xFFE8AD62),
    const Color(0xFFB5CE72),
    const Color(0xFF67C7BE),
    const Color(0xFFF0CF58),
    const Color(0xFF8FA7DE),
    const Color(0xFFBD96DA),
    const Color(0xFFDB8AB6),
  ];
  // Individually tuned jewel tones keep all 14 values distinct and text light.
  static const darkTiles = <Color>[
    Color(0xFF54263D),
    Color(0xFF543820),
    Color(0xFF4A421D),
    Color(0xFF204C38),
    Color(0xFF1C425A),
    Color(0xFF40305D),
    Color(0xFF71362D),
    Color(0xFF684719),
    Color(0xFF405B24),
    Color(0xFF145951),
    Color(0xFF62501A),
    Color(0xFF304C78),
    Color(0xFF633B77),
    Color(0xFF75375E),
  ];
  Color tile(int value) {
    if (value == 0) return boardSlot;
    final index = (value.bitLength - 2).clamp(0, lightTiles.length - 1);
    return resolve(lightTiles[index], darkTiles[index]);
  }

  @override
  GardenColors copyWith({double? darkness}) =>
      GardenColors._(darkness ?? this.darkness);
  @override
  GardenColors lerp(covariant GardenColors? other, double t) => other == null
      ? this
      : GardenColors._(darkness + (other.darkness - darkness) * t);
}

class GardenTheme {
  static final light = _build(GardenColors.light);
  static final dark = _build(GardenColors.dark);

  static SystemUiOverlayStyle systemBars(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: dark ? Colors.black : const Color(0xFFFFFBF5),
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static ThemeData _build(GardenColors colors) {
    final brightness = colors.isDark ? Brightness.dark : Brightness.light;
    var scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF79519D),
      brightness: brightness,
    ).copyWith(onSurface: colors.foreground, surface: colors.background);
    if (colors.isDark) {
      scheme = scheme.copyWith(
        primary: colors.primary,
        onPrimary: const Color(0xFF21152E),
        primaryContainer: colors.selectedSurface,
        onPrimaryContainer: colors.foreground,
        secondary: const Color(0xFF75DCAD),
        onSecondary: const Color(0xFF10291D),
        secondaryContainer: colors.successSurface,
        onSecondaryContainer: colors.foreground,
        tertiary: const Color(0xFFFF82AC),
        onTertiary: const Color(0xFF351322),
        onSurfaceVariant: colors.secondary,
        surfaceContainerLowest: colors.background,
        surfaceContainerLow: colors.surface,
        surfaceContainer: colors.panel,
        surfaceContainerHigh: colors.panel,
        surfaceContainerHighest: const Color(0xFF282333),
        outline: colors.outline,
        outlineVariant: const Color(0xFF51465E),
        error: colors.retryInk,
        onError: const Color(0xFF3D2025),
        errorContainer: colors.retrySurface,
        onErrorContainer: colors.foreground,
      );
    }
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [colors],
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemBars(brightness),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 56),
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 56),
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 17, fontFamily: 'Roboto'),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
      ),
    );
  }
}
