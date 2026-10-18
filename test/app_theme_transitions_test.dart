import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';

void main() {
  for (final entry in {
    'light': GardenTheme.light,
    'dark': GardenTheme.dark,
  }.entries) {
    test('${entry.key} theme uses predictive back transitions on Android', () {
      expect(
        entry.value.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
    });
  }
}
