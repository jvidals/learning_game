import 'dart:convert';
import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/sketch.dart';
import 'package:rainbow_garden/sketch_ink.dart';

void main() {
  test('page size follows orientation, rounds, and clamps extreme shapes', () {
    expect(sketchPageSizeFor(const Size(400, 800)), const Size(960, 1920));
    expect(sketchPageSizeFor(const Size(800, 500)), const Size(1920, 1200));
    expect(sketchPageSizeFor(const Size(500, 500)), const Size(1920, 1920));
    expect(sketchPageSizeFor(const Size(393, 852)), const Size(886, 1920));
    expect(sketchPageSizeFor(const Size(1, 10000)), const Size(576, 1920));
    expect(sketchPageSizeFor(const Size(10000, 1)), const Size(1920, 576));
    for (final area in [
      Size.zero,
      const Size(0, 100),
      const Size(100, -1),
      const Size(double.infinity, 100),
      const Size(100, double.nan),
    ]) {
      expect(sketchPageSizeFor(area), const Size(1080, 1920));
    }
  });

  test('PNG dimensions accept legacy pages and inclusive image bounds', () {
    expect(isValidSketchPageSize(1080, 1920), isTrue);
    expect(isValidSketchPageSize(256, 2560), isTrue);
    expect(isValidSketchPageSize(2560, 256), isTrue);
    for (final side in [-1, 0, 255, 2561]) {
      expect(isValidSketchPageSize(side, 1080), isFalse);
      expect(isValidSketchPageSize(1920, side), isFalse);
    }
  });

  test(
    'stroke points preserve outside coordinates before distance filtering',
    () {
      final builder = StrokeBuilder(
        color: sketchDefaultColor,
        width: 32,
        page: const Size(1920, 1200),
      );
      expect(builder.add(const Offset(-10, -1)), isTrue);
      expect(builder.add(const Offset(-20, -30)), isTrue);
      expect(builder.add(const Offset(3000, 3000)), isTrue);
      expect(builder.points, [
        const Offset(-10, -1),
        const Offset(-20, -30),
        const Offset(3000, 3000),
      ]);
      expect(builder.add(const Offset(double.nan, 10)), isFalse);
    },
  );

  test('recent colors insert, move, cap, and preserve the input', () {
    final recent = List.generate(10, (i) => 0xFF000000 + i);
    final original = [...recent];
    expect(pushRecentColor(recent, 0xFF123456), [
      0xFF123456,
      ...recent.take(9),
    ]);
    expect(pushRecentColor(recent, recent[4]), [
      recent[4],
      ...recent.where((color) => color != recent[4]),
    ]);
    expect(pushRecentColor([1, 1, 2, 2], 3), [3, 1, 2]);
    expect(recent, original);
    expect(identical(pushRecentColor(recent, recent.first), recent), isFalse);
  });

  group('strokes', () {
    test('builder forwards special ink to every stroke snapshot', () {
      final builder = StrokeBuilder(
        page: const Size(1080, 1920),
        color: sketchDefaultColor,
        width: 32,
        special: SketchSpecial.rainbow,
      )..add(const Offset(10, 10));
      expect(builder.build().special, SketchSpecial.rainbow);
      builder.add(const Offset(100, 100));
      expect(builder.build().special, SketchSpecial.rainbow);
      expect(
        SketchStroke(color: 0xFF000000, width: 12, points: []).special,
        isNull,
      );
    });

    test('distance filtering and a single point stroke', () {
      final builder = StrokeBuilder(
        page: const Size(1080, 1920),
        color: sketchDefaultColor,
        width: 32,
      );
      expect(builder.add(const Offset(10, 10)), isTrue);
      expect(builder.add(const Offset(11, 10)), isFalse);
      expect(builder.build().points, [const Offset(10, 10)]);
      expect(builder.add(const Offset(11.5, 10)), isTrue);
      expect(builder.build().color, sketchDefaultColor);
      expect(builder.build().width, 32);
      final wider = StrokeBuilder(
        page: const Size(1080, 1920),
        color: sketchPaperColor,
        width: 50,
        minDistance: 5,
      );
      wider.add(Offset.zero);
      expect(wider.add(const Offset(3, 3)), isFalse);
      expect(wider.add(const Offset(3, 4)), isTrue);
    });

    test('retains outside samples and caps at 4000 points', () {
      final builder = StrokeBuilder(
        page: const Size(1080, 1920),
        color: sketchDefaultColor,
        width: 32,
      );
      builder.add(const Offset(-10, -10));
      expect(builder.points.first, const Offset(-10, -10));
      expect(builder.add(const Offset(-20, -20)), isTrue);
      builder.add(const Offset(2000, 3000));
      expect(builder.points.last, const Offset(2000, 3000));
      for (var i = 0; i < 5000; i++) {
        builder.add(i.isEven ? Offset.zero : const Offset(1080, 1920));
      }
      expect(builder.points.length, 4000);
      expect(builder.add(const Offset(300, 300)), isFalse);
    });

    test('finished strokes are independent and unmodifiable', () {
      final points = [Offset.zero];
      final stroke = SketchStroke(
        color: sketchPaperColor,
        width: 12,
        points: points,
      );
      points.add(const Offset(1, 1));
      expect(stroke.points, [Offset.zero]);
      expect(() => stroke.points.add(Offset.zero), throwsUnsupportedError);
      final builder = StrokeBuilder(
        page: const Size(1080, 1920),
        color: sketchDefaultColor,
        width: 32,
      );
      builder.add(Offset.zero);
      final finished = builder.build();
      builder.add(const Offset(10, 10));
      expect(finished.points, [Offset.zero]);
      expect(() => builder.points.add(Offset.zero), throwsUnsupportedError);
    });
  });

  group('history', () {
    test('cursor, active snapshots, and redo-tail disposal', () {
      final discarded = <String>[];
      final history = SketchHistory<String>(onDiscard: discarded.add);
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      expect(history.undo(), isNull);
      expect(history.redo(), isNull);
      expect(history.push('a'), isEmpty);
      history.push('b');
      history.push('c');
      final snapshot = history.active;
      expect(history.undo(), 'c');
      expect(history.active, ['a', 'b']);
      expect(history.canRedo, isTrue);
      expect(history.redo(), 'c');
      history.undo();
      history.undo();
      history.push('d');
      expect(discarded, ['b', 'c']);
      expect(history.active, ['a', 'd']);
      expect(snapshot, ['a', 'b', 'c']);
      expect(history.canRedo, isFalse);
      history.undo();
      history.undo();
      expect(history.canUndo, isFalse);
      expect(history.redo(), 'a');
    });

    test('remove adjusts the cursor for active ops and the redo tail', () {
      final discarded = <String>[];
      final history = SketchHistory<String>(onDiscard: discarded.add);
      for (final op in ['a', 'b', 'c', 'd']) {
        history.push(op);
      }
      history.undo();
      history.undo();
      expect(history.remove('a'), isTrue);
      expect(history.active, ['b']);
      expect(history.remove('d'), isTrue);
      expect(history.active, ['b']);
      expect(history.redo(), 'c');
      expect(history.canRedo, isFalse);
      expect(history.remove('absent'), isFalse);
      expect(history.remove('c'), isTrue);
      expect(history.undo(), 'b');
      expect(history.canUndo, isFalse);
      expect(history.remove('b'), isTrue);
      expect(history.canRedo, isFalse);
      expect(discarded, ['a', 'd', 'c', 'b']);
    });

    test(
      'eviction transfers ownership in order and clear disposes all ops',
      () {
        final discarded = <int>[];
        final history = SketchHistory<int>(limit: 2, onDiscard: discarded.add);
        history.push(1);
        history.push(2);
        expect(history.push(3), [1]);
        expect(history.push(4), [2]);
        expect(history.active, [3, 4]);
        expect(discarded, isEmpty);
        history.undo();
        history.clearAll();
        expect(discarded, [3, 4]);
        expect(history.active, isEmpty);
        expect(history.canUndo, isFalse);
        expect(history.canRedo, isFalse);
        history.clearAll();
        expect(discarded, [3, 4]);
      },
    );

    test(
      'zero capacity immediately evicts and negative limits are rejected',
      () {
        final history = SketchHistory<int>(limit: 0);
        expect(history.push(1), [1]);
        expect(history.active, isEmpty);
        expect(history.undo(), isNull);
        expect(() => SketchHistory<int>(limit: -1), throwsArgumentError);
      },
    );
  });

  group('settings', () {
    test('v4 twinkles round-trip and survive all settings edits', () {
      const anchors = [SketchTwinkle(12.5, 34, 817, 10)];
      const settings = SketchSettings(twinkles: anchors);
      final decoded = SketchSettings.decode(settings.encode());
      expect(decoded, settings);
      expect(decoded.hashCode, settings.hashCode);
      expect(jsonDecode(settings.encode())['twinkles'], [
        [12.5, 34, 817, 10],
      ]);
      expect(settings.copyWith(size: 40).twinkles, anchors);
      expect(settings.applyColor(0xFF123456).twinkles, anchors);
      expect(settings.clearSpecial().twinkles, anchors);
      expect(settings.copyWith(twinkles: []), const SketchSettings());
      expect(settings, isNot(const SketchSettings()));
    });

    test('malformed v4 twinkles are dropped without losing other settings', () {
      const settings = SketchSettings(size: 50, photoUri: 'content://media/42');
      final valid = jsonDecode(settings.encode()) as Map<String, dynamic>;
      for (final invalid in [
        null,
        true,
        {},
        'stars',
        [1],
        [
          [1, 2, 3],
        ],
        [
          ['x', 2, 3, 10],
        ],
        [
          [1, 2, 3.5, 10],
        ],
        [
          [1, 2, true, 10],
        ],
        [
          [1, 2, 3, 0],
        ],
        [
          [1, 2, 3, 19],
        ],
        List.filled(601, [1, 2, 3, 10]),
      ]) {
        expect(
          SketchSettings.decode(jsonEncode({...valid, 'twinkles': invalid})),
          settings,
        );
      }
      final max = settings.copyWith(
        twinkles: List.generate(
          600,
          (i) => SketchTwinkle(i.toDouble(), 10, i, 10),
        ),
      );
      expect(SketchSettings.decode(max.encode()), max);
    });

    const defaults = SketchSettings();
    test('v1 documents retain every saved setting without special ink', () {
      const document =
          '{"version":1,"color":4279383126,"size":42.5,'
          '"tool":"fill","recentColors":[4279383126,4294967295]}';
      final settings = SketchSettings.decode(document);
      expect(settings.special, isNull);
      expect(settings.color, 0xFF123456);
      expect(settings.size, 42.5);
      expect(settings.tool, SketchTool.fill);
      expect(settings.recentColors, [0xFF123456, 0xFFFFFFFF]);
      expect(settings.ink, const SolidInk(0xFF123456));
    });

    for (final special in SketchSpecial.values) {
      test('color selection preserves only effects: ${special.name}', () {
        final original = SketchSettings(
          special: special,
          color: 0xFF123456,
          recentColors: const [0xFF123456, 0xFFABCDEF],
          photoUri: 'content://photos/1',
          size: 42,
          tool: SketchTool.fill,
        );
        final changed = original.applyColor(0xFFABCDEF);
        expect(special.isEffect, special != SketchSpecial.rainbow);
        expect(changed.special, special.isEffect ? special : null);
        expect(changed.recentColors, [0xFFABCDEF, 0xFF123456]);
        expect(changed.photoUri, original.photoUri);
        expect(
          original.clearSpecial(),
          const SketchSettings(
            color: 0xFF123456,
            recentColors: [0xFF123456, 0xFFABCDEF],
            photoUri: 'content://photos/1',
            size: 42,
            tool: SketchTool.fill,
          ),
        );
      });
    }

    test('special ink round trips and color selection restores solid ink', () {
      final solid = defaults.applyColor(0xFF123456).applyColor(0xFFABCDEF);
      final rainbow = solid.applySpecial(SketchSpecial.rainbow);
      expect(rainbow.special, SketchSpecial.rainbow);
      expect(rainbow.ink, const SpecialInk(SketchSpecial.rainbow));
      expect(rainbow.color, solid.color);
      expect(rainbow.recentColors, solid.recentColors);
      expect(rainbow, isNot(solid));
      expect(rainbow.copyWith(size: 50).special, SketchSpecial.rainbow);
      final decoded = SketchSettings.decode(rainbow.encode());
      expect(decoded, rainbow);
      expect(decoded.hashCode, rainbow.hashCode);
      expect(jsonDecode(rainbow.encode())['special'], 'rainbow');
      final selected = rainbow.applyColor(0xFF123456);
      expect(selected.special, isNull);
      expect(selected.ink, const SolidInk(0xFF123456));
      expect(selected.recentColors, [0xFF123456, 0xFFABCDEF]);
      expect(
        () => selected.recentColors.add(0xFFFFFFFF),
        throwsUnsupportedError,
      );
      expect(SketchSettings.decode(selected.encode()), selected);
    });

    test('each settings version requires its exact document shape', () {
      final v4 = jsonDecode(defaults.encode()) as Map<String, dynamic>;
      final v3 = {...v4, 'version': 3}..remove('twinkles');
      expect(SketchSettings.decode(jsonEncode(v3)), defaults);
      final v2 = {...v3, 'version': 2}..remove('photoUri');
      final v1 = {...v2, 'version': 1}..remove('special');
      expect(SketchSettings.decode(jsonEncode(v1)), defaults);
      expect(SketchSettings.decode(jsonEncode(v2)), defaults);
      expect(SketchSettings.decode(jsonEncode(v2)).photoUri, isNull);
      for (final invalid in [
        {...v2}..remove('special'),
        {...v1, 'special': null},
        {...v2}
          ..remove('special')
          ..['extra'] = null,
      ]) {
        expect(
          () => SketchSettings.decode(jsonEncode(invalid)),
          throwsFormatException,
        );
      }
    });

    test('v3 photo URI round trips, survives tool changes, and clears', () {
      const uri = 'content://media/external/images/media/42';
      final saved = defaults.copyWith(photoUri: uri);
      expect(jsonDecode(saved.encode())['version'], 4);
      expect(SketchSettings.decode(saved.encode()), saved);
      expect(SketchSettings.decode(saved.encode()).hashCode, saved.hashCode);
      expect(SketchSettings.decode(defaults.encode()).photoUri, isNull);
      expect(saved, isNot(defaults));
      expect(saved.copyWith(size: 50).photoUri, uri);
      expect(saved.applyColor(0xFF123456).photoUri, uri);
      expect(saved.applySpecial(SketchSpecial.rainbow).photoUri, uri);
      expect(saved.copyWith(clearPhotoUri: true), defaults);
    });

    test('invalid photo URI is dropped without losing drawing settings', () {
      final valid = defaults.copyWith(size: 50);
      final map = jsonDecode(valid.encode()) as Map<String, dynamic>;
      for (final uri in [
        null,
        1,
        true,
        [],
        {},
        '',
        'file:///photo.png',
        'content://other/photo',
        'content://media/${'x' * 497}',
      ]) {
        expect(
          SketchSettings.decode(jsonEncode({...map, 'photoUri': uri})),
          valid,
        );
      }
      final boundary = 'content://media/${'x' * 496}';
      expect(boundary.length, 512);
      expect(
        SketchSettings.decode(
          jsonEncode({...map, 'photoUri': boundary}),
        ).photoUri,
        boundary,
      );
    });

    test('defaults and applyColor', () {
      expect(defaults.color, sketchPresetColors.first.color);
      expect(defaults.size, sketchDefaultBrush);
      expect(defaults.tool, SketchTool.brush);
      expect(defaults.recentColors, isEmpty);
      final settings = defaults
          .copyWith(size: 50, tool: SketchTool.fill)
          .applyColor(0xFFFF0000)
          .applyColor(0xFF0000FF)
          .applyColor(0xFFFF0000);
      expect(settings.color, 0xFFFF0000);
      expect(settings.recentColors, [0xFFFF0000, 0xFF0000FF]);
      expect(settings.size, 50);
      expect(settings.tool, SketchTool.fill);
      expect(defaults.recentColors, isEmpty);
    });

    test('JSON round trip and equality by value', () {
      for (final tool in SketchTool.values) {
        final settings = defaults.copyWith(
          color: 0xFF123456,
          size: 42.5,
          tool: tool,
          recentColors: [0xFF123456, 0xFFFFFFFF],
        );
        expect(SketchSettings.decode(settings.encode()), settings);
        expect(
          SketchSettings.decode(settings.encode()).hashCode,
          settings.hashCode,
        );
      }
      expect(jsonDecode(defaults.encode()), {
        'version': 4,
        'twinkles': [],
        'special': null,
        'photoUri': null,
        'color': sketchDefaultColor,
        'size': sketchDefaultBrush,
        'tool': 'brush',
        'recentColors': [],
      });
      expect(defaults.copyWith(), defaults);
      expect(defaults.copyWith(color: 0xFFFF0000), isNot(defaults));
      expect(defaults.copyWith(size: 40), isNot(defaults));
      expect(defaults.copyWith(tool: SketchTool.eraser), isNot(defaults));
      expect(
        defaults.copyWith(recentColors: [sketchDefaultColor]),
        isNot(defaults),
      );
      expect(
        SketchSettings.decode(
          defaults.copyWith(size: sketchMinBrush).encode(),
        ).size,
        sketchMinBrush,
      );
      expect(
        SketchSettings.decode(
          defaults.copyWith(size: sketchMaxBrush).encode(),
        ).size,
        sketchMaxBrush,
      );
    });

    test('all malformed documents use the agreed FormatException', () {
      final valid = jsonDecode(defaults.encode()) as Map<String, dynamic>;
      final invalid = <String>['', '{', 'null', '[]', '1', '"settings"'];
      for (final key in valid.keys) {
        invalid.add(jsonEncode({...valid}..remove(key)));
        if (key != 'special' && key != 'photoUri' && key != 'twinkles') {
          invalid.add(jsonEncode({...valid, key: null}));
        }
      }
      final changes = <Map<String, Object?>>[
        {'version': 1},
        {'version': 5},
        {'special': 'unknown'},
        {'special': 1},
        {'special': true},
        {'version': 1.0},
        {'version': '1'},
        {'extra': true},
        for (final value in [
          -1,
          0x100000000,
          0xFEFFFFFF,
          0,
          1.5,
          'black',
          true,
        ])
          {'color': value},
        for (final value in [11.9, 110.1, '32', true]) {'size': value},
        for (final value in ['pen', 'Brush', 0, []]) {'tool': value},
        {'recentColors': 'red'},
        {'recentColors': List.filled(11, sketchDefaultColor)},
        {
          'recentColors': [sketchDefaultColor, sketchDefaultColor],
        },
        for (final value in [-1, 0x100000000, 0xFEFFFFFF, 0, 1.5, 'red', null])
          {
            'recentColors': [value],
          },
      ];
      invalid.addAll(
        changes.map((change) => jsonEncode({...valid, ...change})),
      );
      invalid.add(defaults.encode().replaceFirst('32.0', '1e999'));
      for (final document in invalid) {
        expect(
          () => SketchSettings.decode(document),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Sketch settings could not be read.',
            ),
          ),
          reason: document,
        );
      }
    });
  });

  test('presets retain the original crayons and include opaque White', () {
    expect(sketchPresetColors.length, 13);
    expect(sketchPresetColors.map((preset) => preset.color).toSet().length, 13);
    expect(sketchPresetColors.map((preset) => preset.name).toSet().length, 13);
    expect(sketchPresetColors.map((preset) => preset.name), [
      'Black',
      'White',
      'Grey',
      'Brown',
      'Red',
      'Orange',
      'Yellow',
      'Light green',
      'Dark green',
      'Light blue',
      'Dark blue',
      'Purple',
      'Pink',
    ]);
    expect(
      sketchPresetColors.singleWhere((preset) => preset.name == 'White').color,
      sketchPaperColor,
    );
    for (final preset in sketchPresetColors) {
      expect(preset.color >> 24, 255);
      expect(preset.name.trim(), isNotEmpty);
    }
  });
}
