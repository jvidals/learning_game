import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/device_services.dart';
import 'package:rainbow_garden/progress_controller.dart';
import 'package:rainbow_garden/sketch_store.dart';
import 'package:rainbow_garden/sketch.dart';
import 'package:rainbow_garden/sketch_ink.dart';

import 'widget_test.dart' show MemoryDevice;

class HeldSketchDevice extends MemoryDevice {
  Completer<void>? hold;
  int active = 0, maxActive = 0;
  final attempts = <({String id, Uint8List png, String settings})>[];

  @override
  Future<void> saveSketch(
    String playerId, {
    required Uint8List png,
    required String settings,
  }) async {
    attempts.add((
      id: playerId,
      png: Uint8List.fromList(png),
      settings: settings,
    ));
    active++;
    if (active > maxActive) maxActive = active;
    try {
      await hold?.future;
      await super.saveSketch(playerId, png: png, settings: settings);
    } finally {
      active--;
    }
  }
}

class CleanupDevice extends MemoryDevice {
  Completer<void>? hold;
  bool failCleanup = false;

  @override
  Future<void> saveProfiles(String document) async {
    await hold?.future;
    await super.saveProfiles(document);
  }

  @override
  Future<void> deleteSketch(String playerId) {
    if (failCleanup) throw StateError('Unavailable');
    return super.deleteSketch(playerId);
  }
}

Future<ui.Image> tinyPage(int color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawPaint(ui.Paint()..color = ui.Color(color));
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(2, 2);
  } finally {
    picture.dispose();
  }
}

void seed(MemoryDevice device, String id, [int byte = 1]) {
  device.sketches[id] = SketchSnapshot(
    png: Uint8List.fromList([byte]),
    settings: 'saved',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1 settings load and v2 inks stay attached to their player', () async {
    final d = MemoryDevice();
    const v1 =
        '{"version":1,"color":4278190080,"size":32,"tool":"brush","recentColors":[]}';
    d.sketches['one'] = SketchSnapshot(
      png: Uint8List.fromList([1]),
      settings: v1,
    );
    seed(d, 'two', 2);
    final store = SketchStore(d);
    final loaded = await store.load('one');
    final legacy = SketchSettings.decode(loaded.settings!);
    expect(legacy.special, isNull);
    final rainbow = legacy.applySpecial(SketchSpecial.rainbow);
    await store.load('two');
    store.update('one', settings: rainbow.encode());
    store.update('two', settings: legacy.applyColor(0xFF123456).encode());
    await store.flush();
    expect(SketchSettings.decode(d.sketches['one']!.settings!), rainbow);
    expect(
      SketchSettings.decode(d.sketches['two']!.settings!).ink,
      const SolidInk(0xFF123456),
    );
    expect(d.sketches['one']!.png, [1]);
    expect(d.sketches['two']!.png, [2]);
    await store.close();
  });

  test('load returns the saved snapshot and rethrows read failures', () async {
    final d = MemoryDevice();
    seed(d, 'one');
    final store = SketchStore(d);
    final saved = await store.load('one');
    expect(saved.png, [1]);
    expect(saved.settings, 'saved');
    d.failSketchLoad = true;
    await expectLater(store.load('two'), throwsStateError);
    expect(d.sketchWrites, 0);
    await store.close();
  });

  testWidgets('updates debounce to the latest settings', (tester) async {
    final d = MemoryDevice();
    seed(d, 'one');
    final store = SketchStore(d);
    await store.load('one');
    store.update('one', settings: 'first');
    await tester.pump(const Duration(milliseconds: 800));
    store.update('one', settings: 'second');
    await tester.pump(const Duration(milliseconds: 800));
    expect(d.sketchWrites, 0);
    store.update('one', settings: 'latest');
    await tester.pump(const Duration(seconds: 1));
    expect(d.sketchWrites, 1);
    expect(d.sketches['one']!.settings, 'latest');
    expect(store.hasPending, isFalse);
    await store.close();
  });

  test(
    'flush is immediate and serializes newer data behind a held write',
    () async {
      final d = HeldSketchDevice();
      seed(d, 'one');
      final store = SketchStore(d);
      await store.load('one');
      d.hold = Completer<void>();
      store.update('one', settings: 'first');
      final first = store.flush();
      final concurrent = store.flush();
      await Future<void>.delayed(Duration.zero);
      expect(d.attempts.length, 1);
      store.update('one', settings: 'latest');
      final next = store.flush();
      expect(store.hasPending, isTrue);
      d.hold!.complete();
      await Future.wait([first, concurrent, next]);
      expect(d.attempts.map((a) => a.settings), ['first', 'latest']);
      expect(d.maxActive, 1);
      expect(store.hasPending, isFalse);
      await store.close();
    },
  );

  test(
    'a flush immediately after an idle flush still saves the new edit',
    () async {
      final d = MemoryDevice();
      seed(d, 'one');
      final store = SketchStore(d);
      await store.load('one');
      final idle = store.flush();
      store.update('one', settings: 'new edit');
      final saving = store.flush();
      await Future.wait([idle, saving]);
      expect(d.sketchWrites, 1);
      expect(d.sketches['one']!.settings, 'new edit');
      await store.close();
    },
  );

  test('settings-only updates reuse the loaded PNG', () async {
    final d = MemoryDevice();
    seed(d, 'one', 7);
    final store = SketchStore(d);
    await store.load('one');
    store.update('one', settings: 'new settings');
    await store.flush();
    expect(d.sketches['one']!.png, [7]);
    expect(d.sketches['one']!.settings, 'new settings');
    await store.close();
  });

  testWidgets('settings without a PNG wait until a page arrives', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final d = MemoryDevice(), store = SketchStore(d);
      await store.load('one');
      store.update('one', settings: 'held');
      await store.flush();
      expect(d.sketchWrites, 0);
      expect(store.hasPending, isTrue);
      store.update('one', page: await tinyPage(0xffffffff), settings: 'page');
      await store.flush();
      expect(d.sketchWrites, 1);
      expect(d.sketches['one']!.png!.take(8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      expect(d.sketches['one']!.settings, 'page');
      await store.close();
    });
  });

  test('switching players saves each payload to its originating id', () async {
    final d = HeldSketchDevice();
    seed(d, 'one', 1);
    seed(d, 'two', 2);
    final store = SketchStore(d);
    await store.load('one');
    await store.load('two');
    store.update('one', settings: 'first player');
    store.update('two', settings: 'second player');
    await Future<void>.delayed(Duration.zero);
    expect(d.sketches['one']!.settings, 'first player');
    await store.flush();
    expect(d.attempts.map((a) => a.id), ['one', 'two']);
    expect(d.sketches['one']!.png, [1]);
    expect(d.sketches['two']!.png, [2]);
    await store.close();
  });

  test(
    'failure keeps the exact payload ahead of newer edits for retry',
    () async {
      final d = HeldSketchDevice();
      seed(d, 'one');
      final store = SketchStore(d);
      await store.load('one');
      store.update('one', settings: 'failed payload');
      d.failSketchSave = true;
      await store.flush();
      expect(store.failed.value, isTrue);
      expect(store.hasPending, isTrue);
      store.update('one', settings: 'newer settings');
      d.failSketchSave = false;
      await store.retry();
      expect(d.attempts.map((a) => a.settings), [
        'failed payload',
        'failed payload',
        'newer settings',
      ]);
      expect(d.attempts[1].png, d.attempts[0].png);
      expect(store.failed.value, isFalse);
      expect(store.hasPending, isFalse);
      await store.close();
    },
  );

  testWidgets('superseded and encoded images are disposed; close flushes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final d = MemoryDevice(), store = SketchStore(d);
      final first = await tinyPage(0xffff0000);
      final second = await tinyPage(0xff0000ff);
      final expected = (await second.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      store.update('one', page: first, settings: 'first');
      store.update('one', page: second, settings: 'second');
      expect(first.debugDisposed, isTrue);
      await store.close();
      expect(second.debugDisposed, isTrue);
      expect(d.sketchWrites, 1);
      expect(d.sketches['one']!.png, expected.buffer.asUint8List());
      final ignored = await tinyPage(0xff00ff00);
      store.update('one', page: ignored, settings: 'ignored');
      expect(ignored.debugDisposed, isTrue);
      await store.flush();
      expect(d.sketchWrites, 1);
      await store.close();
    });
  });

  testWidgets('close releases queued images even when the pending save fails', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final d = MemoryDevice(), store = SketchStore(d);
      final first = await tinyPage(0xffff0000);
      store.update('one', page: first, settings: 'first');
      d.failSketchSave = true;
      await store.flush();
      final newer = await tinyPage(0xff0000ff);
      store.update('one', page: newer, settings: 'newer');
      await store.close();
      expect(first.debugDisposed, isTrue);
      expect(newer.debugDisposed, isTrue);
      expect(d.sketchWrites, 0);
    });
  });

  test(
    'Android rejects invalid player IDs before invoking the channel',
    () async {
      final services = AndroidServices();
      for (final id in ['../x', '', 'a/b', 'a' * 101, 'a\n']) {
        expect(isValidSketchPlayerId(id), isFalse);
        await expectLater(services.loadSketch(id), throwsArgumentError);
        await expectLater(
          services.saveSketch(id, png: Uint8List(0), settings: '{}'),
          throwsArgumentError,
        );
        await expectLater(services.deleteSketch(id), throwsArgumentError);
      }
      for (final id in ['player-1', 'A_09', 'a' * 100]) {
        expect(isValidSketchPlayerId(id), isTrue);
      }
    },
  );

  test(
    'Android sketch channel forwards the required argument and return shapes',
    () async {
      const channel = MethodChannel('rainbow_garden/device');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'loadSketch') {
          return {
            'png': Uint8List.fromList([5]),
            'settings': '{}',
          };
        }
        if (call.method == 'saveToGallery') {
          return 'content://media/external/images/media/1';
        }
        if (call.method == 'canSaveToGallery') {
          return true;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final services = AndroidServices(), png = Uint8List.fromList([5]);
      final loaded = await services.loadSketch('one');
      expect(loaded.png, png);
      expect(loaded.settings, '{}');
      await services.saveSketch('one', png: png, settings: '{}');
      await services.deleteSketch('one');
      expect(await services.canSaveToGallery(), isTrue);
      await services.saveToGallery(png, 'Drawing.png');
      expect(calls.map((c) => c.method), [
        'loadSketch',
        'saveSketch',
        'deleteSketch',
        'canSaveToGallery',
        'saveToGallery',
      ]);
      expect(calls[0].arguments, {'playerId': 'one'});
      expect(calls[1].arguments, {
        'playerId': 'one',
        'png': png,
        'settings': '{}',
      });
      expect(calls[2].arguments, {'playerId': 'one'});
      expect(calls[4].arguments, {'png': png, 'name': 'Drawing.png'});
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect(await services.canSaveToGallery(), isFalse);
    },
  );

  test(
    'player deletion cleans up once, only after durable success; reset keeps art',
    () async {
      final d = MemoryDevice(), c = ProgressController(d);
      addTearDown(c.dispose);
      await c.load();
      final first = c.activeProfile!.id;
      await c.addProfile('Second');
      final second = c.activeProfile!.id;
      seed(d, second);
      await c.reset();
      expect(d.deletedSketches, isEmpty);
      expect(d.sketches, contains(second));
      d.failSave = true;
      await expectLater(c.deleteProfile(), throwsStateError);
      expect(d.deletedSketches, isEmpty);
      d.failSave = false;
      await c.retry();
      expect(c.activeProfile!.id, first);
      expect(d.deletedSketches, [second]);
      expect(d.sketches, isNot(contains(second)));
      await c.retry();
      expect(d.deletedSketches, [second]);
    },
  );

  test(
    'cleanup waits for an in-flight profile write and cleanup errors stay optional',
    () async {
      final d = CleanupDevice(), c = ProgressController(d);
      addTearDown(c.dispose);
      await c.load();
      final first = c.activeProfile!.id;
      await c.addProfile('Second');
      final second = c.activeProfile!.id;
      d.hold = Completer<void>();
      final deletion = c.deleteProfile();
      expect(d.deletedSketches, isEmpty);
      expect(c.activeProfile!.id, second);
      d.hold!.complete();
      await deletion;
      expect(d.deletedSketches, [second]);
      expect(c.activeProfile!.id, first);
      d.hold = null;
      await c.addProfile('Third');
      d.failCleanup = true;
      await c.deleteProfile();
      expect(c.activeProfile!.id, first);
      expect(c.failure, isNull);
      expect(c.blocked.value, isFalse);
    },
  );
}
