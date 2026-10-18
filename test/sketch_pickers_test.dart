import 'dart:ui' as ui;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/app_theme.dart';
import 'package:rainbow_garden/sketch_ink.dart';
import 'package:rainbow_garden/widgets/brush_size_sheet.dart';
import 'package:rainbow_garden/widgets/color_wheel.dart';
import 'package:rainbow_garden/widgets/special_swatch.dart';

final pickerAnchor = GlobalKey();

const presets = [
  (color: Colors.red, name: 'Red'),
  (color: Colors.orange, name: 'Orange'),
  (color: Colors.yellow, name: 'Yellow'),
  (color: Colors.green, name: 'Green'),
  (color: Colors.teal, name: 'Teal'),
  (color: Colors.blue, name: 'Blue'),
  (color: Colors.indigo, name: 'Indigo'),
  (color: Colors.purple, name: 'Purple'),
  (color: Colors.pink, name: 'Pink'),
  (color: Colors.brown, name: 'Brown'),
  (color: Colors.black, name: 'Black'),
  (color: Colors.white, name: 'White'),
];

Future<void> host(
  WidgetTester tester,
  Future<void> Function(BuildContext) open, {
  bool dark = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? GardenTheme.dark : GardenTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: pickerAnchor,
            onPressed: () => open(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> selectTab(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('sketch-color-tab-$name')));
  await tester.pumpAndSettle();
}

Color preview(WidgetTester tester) =>
    (tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.bySemanticsLabel('New color preview'),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration)
        .color!;

void main() {
  for (final special in [null, ...SketchSpecial.values]) {
    testWidgets('base and special selection: $special', (tester) async {
      final semantics = tester.ensureSemantics();
      SketchPick? result;
      await host(tester, (context) async {
        result = await showSketchInkPopover(
          context,
          anchor: pickerAnchor,
          base: Colors.red,
          onPreview: (_) {},
          current: special == null
              ? SolidInk(Colors.red.toARGB32())
              : SpecialInk(special),
          presets: presets,
          recent: [Colors.red],
        );
      });
      for (final key in ['sketch-preset-0', 'sketch-recent-0']) {
        expect(
          tester
              .getSemantics(find.byKey(ValueKey(key)))
              .flagsCollection
              .isSelected,
          special == SketchSpecial.rainbow ? Tristate.isFalse : Tristate.isTrue,
        );
      }
      await selectTab(tester, 'special');
      final plain = find.byKey(const ValueKey('sketch-special-plain'));
      expect(tester.getSemantics(plain).label, 'Plain');
      expect(find.byTooltip('Plain'), findsOneWidget);
      expect(
        tester.getSemantics(plain).flagsCollection.isSelected,
        special == null ? Tristate.isTrue : Tristate.isFalse,
      );
      if (special != null) {
        expect(
          tester
              .getSemantics(
                find.byKey(ValueKey('sketch-special-${special.name}')),
              )
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
      }
      await tester.tap(plain);
      await tester.pumpAndSettle();
      expect(result, isA<PickPlain>());
      semantics.dispose();
    });
  }

  for (final dark in [false, true]) {
    testWidgets('special ink selection and order, dark $dark', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      SketchPick? result;
      await host(
        tester,
        (context) async {
          result = await showSketchInkPopover(
            context,
            anchor: pickerAnchor,
            base: Colors.red,
            onPreview: (_) {},
            current: const SpecialInk(SketchSpecial.rainbow),
            initialTab: SketchColorTab.special,
            presets: presets,
            recent: [Colors.cyan],
          );
        },
        dark: dark,
        scale: 2,
      );
      final swatch = find.byKey(const ValueKey('sketch-special-rainbow'));
      expect(tester.getSemantics(swatch).label, 'Rainbow');
      expect(
        tester.getSemantics(swatch).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('sketch-color-tab-special')),
            )
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      for (final special in SketchSpecial.values) {
        final tile = find.byKey(ValueKey('sketch-special-${special.name}'));
        final paint = tester.widget<SpecialSwatch>(
          find.descendant(of: tile, matching: find.byType(SpecialSwatch)),
        );
        expect(paint.special, special);
        expect(paint.base.toARGB32(), Colors.red.toARGB32());
      }
      expect(find.byKey(const ValueKey('sketch-use-color')), findsNothing);
      expect(tester.takeException(), isNull);
      await reveal(tester, swatch);
      await tester.tap(swatch);
      await tester.pumpAndSettle();
      expect(
        result,
        isA<PickSpecial>().having(
          (pick) => pick.kind,
          'kind',
          SketchSpecial.rainbow,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final source in ['crayon', 'mix']) {
    testWidgets('ink popover returns solid from $source', (tester) async {
      SketchPick? result;
      await host(tester, (context) async {
        result = await showSketchInkPopover(
          context,
          anchor: pickerAnchor,
          base: Colors.red,
          onPreview: (_) {},
          current: const SolidInk(0xFF123456),
          presets: presets,
          recent: [],
        );
      });
      if (source == 'crayon') {
        await tester.tap(find.byKey(const ValueKey('sketch-preset-0')));
      } else {
        await selectTab(tester, 'mix');
        final wheel = find.byKey(const ValueKey('sketch-color-wheel'));
        await reveal(tester, wheel);
        await tester.tapAt(
          tester.getRect(wheel).centerRight - const Offset(1, 0),
        );
        await tester.pump();
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(result, isA<PickSolid>());
    });
  }

  testWidgets('size preview uses optional special swatch', (tester) async {
    await host(tester, (context) async {
      await showBrushSizePopover(
        context,
        anchor: pickerAnchor,
        size: 20,
        min: 2,
        max: 80,
        previewScale: .5,
        color: Colors.white,
        special: SketchSpecial.neon,
        onChanged: (_) {},
      );
    });
    final swatch = tester.widget<SpecialSwatch>(find.byType(SpecialSwatch));
    expect(swatch.special, SketchSpecial.neon);
    expect(swatch.base, Colors.white);
    expect(swatch.shape, BoxShape.circle);
  });

  testWidgets('color popover shows controls and selected preset semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await host(tester, (context) async {
      await showSketchInkPopover(
        context,
        anchor: pickerAnchor,
        base: Colors.red,
        onPreview: (_) {},
        current: SolidInk(Colors.red.toARGB32()),
        specials: const [],
        presets: presets,
        recent: [Colors.cyan],
      );
    });
    for (var i = 0; i < 12; i++) {
      expect(find.byKey(ValueKey('sketch-preset-$i')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(ValueKey('sketch-preset-$i'))).shortestSide,
        greaterThanOrEqualTo(48),
      );
    }
    expect(
      tester.getTopLeft(find.byTooltip('Recent colors')).dy,
      lessThan(tester.getTopLeft(find.byTooltip('Crayons')).dy),
    );
    expect(find.byTooltip('Special colors'), findsOneWidget);
    expect(find.byKey(const ValueKey('sketch-recent-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('sketch-color-wheel')), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const ValueKey('sketch-use-color')), findsNothing);
    expect(find.text('Choose a color'), findsNothing);
    expect(find.text('Brightness'), findsNothing);
    expect(find.byTooltip('Close color picker'), findsNothing);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('sketch-preset-0')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  for (final recent in [false, true]) {
    testWidgets('${recent ? 'recent' : 'preset'} returns exact color', (
      tester,
    ) async {
      SketchPick? result;
      await host(tester, (context) async {
        result = await showSketchInkPopover(
          context,
          anchor: pickerAnchor,
          base: Colors.red,
          onPreview: (_) {},
          current: SolidInk(Colors.red.toARGB32()),
          specials: const [],
          presets: presets,
          recent: [Colors.cyan],
        );
      });
      final swatch = find.byKey(
        ValueKey(recent ? 'sketch-recent-0' : 'sketch-preset-5'),
      );
      await reveal(tester, swatch);
      await tester.tap(swatch);
      await tester.pumpAndSettle();
      expect(
        result,
        isA<PickSolid>().having(
          (pick) => pick.argb,
          'argb',
          (recent ? Colors.cyan : Colors.blue).toARGB32(),
        ),
      );
      expect(find.text('Choose a color'), findsNothing);
    });
  }

  testWidgets('empty recent section is hidden and Back returns null', (
    tester,
  ) async {
    SketchPick? result = PickSolid(Colors.red.toARGB32());
    await host(tester, (context) async {
      result = await showSketchInkPopover(
        context,
        anchor: pickerAnchor,
        base: Colors.red,
        onPreview: (_) {},
        current: SolidInk(Colors.green.toARGB32()),
        specials: const [],
        presets: presets,
        recent: [],
      );
    });
    expect(find.byTooltip('Recent colors'), findsNothing);
    await selectTab(tester, 'mix');
    expect(preview(tester).toARGB32(), Colors.green.toARGB32());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets(
    'wheel geometry, drag clamping and brightness update applied preview',
    (tester) async {
      SketchPick? result;
      final previews = <SolidInk>[];
      await host(tester, (context) async {
        result = await showSketchInkPopover(
          context,
          anchor: pickerAnchor,
          base: Colors.red,
          onPreview: previews.add,
          initialTab: SketchColorTab.mix,
          current: SolidInk(Colors.white.toARGB32()),
          specials: const [],
          presets: presets,
          recent: [],
        );
      });
      final wheel = find.byKey(const ValueKey('sketch-color-wheel'));
      await reveal(tester, wheel);
      final rect = tester.getRect(wheel);
      await tester.tapAt(rect.centerRight - const Offset(1, 0));
      await tester.pump();
      var hsv = HSVColor.fromColor(preview(tester));
      expect(hsv.hue, closeTo(0, 2));
      expect(hsv.saturation, greaterThan(.97));
      final drag = await tester.startGesture(rect.center);
      await drag.moveTo(rect.topCenter - const Offset(0, 30));
      await drag.up();
      await tester.pump();
      hsv = HSVColor.fromColor(preview(tester));
      expect(hsv.hue, closeTo(270, 2));
      expect(hsv.saturation, closeTo(1, .01));
      final slider = find.byType(Slider);
      await reveal(tester, slider);
      await tester.drag(slider, const Offset(-600, 0));
      await tester.pumpAndSettle();
      final applied = preview(tester);
      expect(previews.last, SolidInk(applied.toARGB32()));
      expect(HSVColor.fromColor(applied).value, lessThan(.02));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        result,
        isA<PickSolid>().having(
          (pick) => pick.argb,
          'argb',
          applied.toARGB32(),
        ),
      );
    },
  );

  testWidgets('black keeps a colorful disc and wheel touch brightens the mix', (
    tester,
  ) async {
    await host(tester, (context) async {
      await showSketchInkPopover(
        context,
        anchor: pickerAnchor,
        base: Colors.red,
        onPreview: (_) {},
        initialTab: SketchColorTab.mix,
        current: SolidInk(Colors.black.toARGB32()),
        specials: const [],
        presets: presets,
        recent: [],
      );
    });
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(preview(tester).toARGB32(), Colors.black.toARGB32());
    final wheel = find.byKey(const ValueKey('sketch-color-wheel'));
    await reveal(tester, wheel);
    final paint = tester.widget<CustomPaint>(
      find.descendant(of: wheel, matching: find.byType(CustomPaint)).first,
    );
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      paint.painter!.paint(Canvas(recorder), const Size.square(200));
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      final pixels = (await image.toByteData())!;
      // Sample the red edge, away from the black thumb at the centre.
      final offset = (100 * 200 + 185) * 4;
      expect(pixels.getUint8(offset), greaterThan(240));
      expect(pixels.getUint8(offset + 1), lessThan(60));
      image.dispose();
      picture.dispose();
    });
    await tester.tapAt(tester.getRect(wheel).centerRight - const Offset(1, 0));
    await tester.pump();
    final selected = HSVColor.fromColor(preview(tester));
    expect(selected.value, 1);
    expect(selected.hue, closeTo(0, 2));
    expect(selected.saturation, greaterThan(.97));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
  });

  for (final brightness in [.1, .25]) {
    testWidgets('initial mix preserves HSV at brightness $brightness', (
      tester,
    ) async {
      final current = HSVColor.fromAHSV(1, 210, .7, brightness).toColor();
      final initial = HSVColor.fromColor(current);
      await host(tester, (context) async {
        await showSketchInkPopover(
          context,
          anchor: pickerAnchor,
          base: Colors.red,
          onPreview: (_) {},
          initialTab: SketchColorTab.mix,
          current: SolidInk(current.toARGB32()),
          specials: const [],
          presets: presets,
          recent: [],
        );
      });
      final wheel = find.byKey(const ValueKey('sketch-color-wheel'));
      final mix = tester.widget<ColorWheel>(wheel).value;
      expect(mix.hue, initial.hue);
      expect(mix.saturation, initial.saturation);
      expect(tester.widget<Slider>(find.byType(Slider)).value, initial.value);
      await reveal(tester, wheel);
      await tester.tapAt(
        tester.getRect(wheel).centerRight - const Offset(1, 0),
      );
      await tester.pump();
      expect(
        HSVColor.fromColor(preview(tester)).value,
        initial.value < .25 ? 1 : initial.value,
      );
    });
  }

  testWidgets('phone Mix section fits together with ten recent colors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await host(tester, (context) async {
      await showSketchInkPopover(
        context,
        anchor: pickerAnchor,
        base: Colors.red,
        onPreview: (_) {},
        initialTab: SketchColorTab.mix,
        current: SolidInk(Colors.black.toARGB32()),
        specials: const [],
        presets: presets,
        recent: List.filled(10, Colors.cyan),
      );
    });
    await reveal(tester, find.byTooltip('Mix a color'));
    final viewport = tester.getRect(
      find.byKey(const ValueKey('sketch-color-content')),
    );
    for (final control in [
      find.byKey(const ValueKey('sketch-color-wheel')),
      find.byType(Slider),
      find.bySemanticsLabel('New color preview'),
    ]) {
      final rect = tester.getRect(control);
      expect(rect.top, greaterThanOrEqualTo(viewport.top));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent colors stay in one row and tabs never move the pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final tabs = <SketchColorTab>[];
    await host(tester, (context) async {
      await showSketchInkPopover(
        context,
        anchor: pickerAnchor,
        base: Colors.blue,
        onPreview: (_) {},
        current: const SolidInk(0xFF000000),
        presets: presets,
        recent: List.filled(10, Colors.cyan),
        onTabChanged: tabs.add,
      );
    });
    final pane = tester.getRect(find.byKey(const ValueKey('sketch-popover')));
    final positions = [
      for (final name in ['crayons', 'special', 'mix'])
        tester.getRect(find.byKey(ValueKey('sketch-color-tab-$name'))),
    ];
    expect(pane.width, lessThanOrEqualTo(304));
    expect(
      tester.getSize(find.byKey(const ValueKey('sketch-color-content'))).height,
      150,
    );
    for (final (name, label, icon) in [
      ('crayons', 'Crayons', Icons.palette_rounded),
      ('special', 'Special colors', Icons.auto_awesome_rounded),
      ('mix', 'Mix a color', Icons.colorize_rounded),
    ]) {
      final button = find.byKey(ValueKey('sketch-color-tab-$name'));
      expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(button).label, label);
      expect(
        find.descendant(of: button, matching: find.byIcon(icon)),
        findsOneWidget,
      );
      expect(find.byTooltip(label), findsOneWidget);
    }
    final rows = <double, int>{};
    for (var i = 0; i < 12; i++) {
      final y = tester.getTopLeft(find.byKey(ValueKey('sketch-preset-$i'))).dy;
      rows[y] = (rows[y] ?? 0) + 1;
    }
    expect(rows.values, [6, 6]);
    final recents = [
      for (var i = 0; i < 10; i++) find.byKey(ValueKey('sketch-recent-$i')),
    ].where((finder) => finder.evaluate().isNotEmpty).toList();
    expect(recents, hasLength(5));
    expect(
      recents.map((finder) => tester.getTopLeft(finder).dy).toSet(),
      hasLength(1),
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('sketch-color-tab-crayons')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    for (final name in ['special', 'mix', 'crayons']) {
      await selectTab(tester, name);
      expect(
        tester.getRect(find.byKey(const ValueKey('sketch-popover'))),
        pane,
      );
      expect([
        for (final tab in ['crayons', 'special', 'mix'])
          tester.getRect(find.byKey(ValueKey('sketch-color-tab-$tab'))),
      ], positions);
      expect(
        tester
            .getSemantics(find.byKey(ValueKey('sketch-color-tab-$name')))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    }
    expect(tabs, [
      SketchColorTab.special,
      SketchColorTab.mix,
      SketchColorTab.crayons,
    ]);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final special in [SketchSpecial.glitter, SketchSpecial.neon]) {
    testWidgets('${special.label} tile returns its special ink', (
      tester,
    ) async {
      SketchPick? result;
      await host(tester, (context) async {
        result = await showSketchInkPopover(
          context,
          anchor: pickerAnchor,
          base: Colors.blue,
          onPreview: (_) {},
          current: const SolidInk(0xFF000000),
          initialTab: SketchColorTab.special,
          presets: presets,
          recent: [],
        );
      });
      await tester.tap(find.byKey(ValueKey('sketch-special-${special.name}')));
      await tester.pumpAndSettle();
      expect(
        result,
        isA<PickSpecial>().having((pick) => pick.kind, 'kind', special),
      );
    });
  }

  testWidgets('size updates live with scaled preview and dismissal completes', (
    tester,
  ) async {
    final values = <double>[];
    var completed = false;
    await host(tester, (context) async {
      await showBrushSizePopover(
        context,
        anchor: pickerAnchor,
        size: 20,
        min: 2,
        max: 80,
        previewScale: .5,
        color: Colors.white,
        onChanged: values.add,
      );
      completed = true;
    });
    expect(
      tester.getSize(find.byKey(const ValueKey('sketch-size-preview'))),
      const Size.square(10),
    );
    expect(find.text('Brush size'), findsNothing);
    expect(find.byTooltip('Close brush size'), findsNothing);
    final slider = find.byKey(const ValueKey('sketch-size-slider'));
    await tester.drag(slider, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(values, isNotEmpty);
    expect(values.every((v) => v >= 2 && v <= 80), isTrue);
    expect(
      tester.getSize(find.byKey(const ValueKey('sketch-size-preview'))).width,
      closeTo(values.last * .5, .01),
    );
    expect(find.byKey(const ValueKey('sketch-size-done')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  for (final dismissal in ['outside', 'back']) {
    testWidgets('size $dismissal keeps live edits and completes', (
      tester,
    ) async {
      final values = <double>[];
      var completed = false;
      await host(tester, (context) async {
        await showBrushSizePopover(
          context,
          anchor: pickerAnchor,
          size: 20,
          min: 2,
          max: 80,
          previewScale: .5,
          color: Colors.white,
          onChanged: values.add,
        );
        completed = true;
      });
      await tester.drag(
        find.byKey(const ValueKey('sketch-size-slider')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      final last = values.last;
      if (dismissal == 'outside') {
        await tester.tapAt(const Offset(790, 590));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(values.last, last);
      expect(find.byKey(const ValueKey('sketch-size-slider')), findsNothing);
    });
  }

  for (final dark in [false, true]) {
    for (final sizeSheet in [false, true]) {
      testWidgets(
        'small 2x ${dark ? 'dark' : 'light'} ${sizeSheet ? 'size' : 'color'} popover fits',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await host(
            tester,
            (context) async {
              if (sizeSheet) {
                await showBrushSizePopover(
                  context,
                  anchor: pickerAnchor,
                  size: 20,
                  min: 2,
                  max: 80,
                  previewScale: .5,
                  color: Colors.white,
                  onChanged: (_) {},
                );
              } else {
                await showSketchInkPopover(
                  context,
                  anchor: pickerAnchor,
                  base: Colors.red,
                  onPreview: (_) {},
                  current: SolidInk(Colors.red.toARGB32()),
                  specials: const [],
                  presets: presets,
                  recent: List.filled(10, Colors.white),
                );
              }
            },
            dark: dark,
            scale: 2,
          );
          if (!sizeSheet) await selectTab(tester, 'mix');
          await reveal(
            tester,
            find.byKey(
              ValueKey(sizeSheet ? 'sketch-size-slider' : 'sketch-color-wheel'),
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
