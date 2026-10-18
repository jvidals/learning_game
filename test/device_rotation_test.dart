import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/device_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final binding = TestDefaultBinaryMessengerBinding.instance;
  const channel = MethodChannel('rainbow_garden/device');
  const codec = StandardMethodCodec();
  late AndroidServices device;

  setUp(() {
    device = AndroidServices();
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('takeShortcut accepts only the two supported ids', () async {
    for (final value in <Object?>[
      'sketchPad',
      'game2048',
      'settings',
      '',
      42,
      null,
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'takeShortcut');
        expect(call.arguments, isNull);
        return value;
      });
      expect(
        await device.takeShortcut(),
        value == 'sketchPad' || value == 'game2048' ? value : isNull,
      );
    }
  });

  test('takeShortcut tolerates unavailable native services', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    expect(await device.takeShortcut(), isNull);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    expect(await device.takeShortcut(), isNull);
  });

  testWidgets('shortcut requests broadcast alongside display rotations', (
    tester,
  ) async {
    var first = 0, second = 0;
    final rotations = <int>[];
    final a = device.shortcutRequests.listen((_) => first++);
    final b = device.shortcutRequests.listen((_) => second++);
    final c = device.displayRotationChanges.listen(rotations.add);
    addTearDown(a.cancel);
    addTearDown(b.cancel);
    addTearDown(c.cancel);
    for (final call in [
      const MethodCall('shortcutRequested'),
      const MethodCall('displayRotationChanged', 2),
      const MethodCall('shortcutRequested'),
    ]) {
      final reply = Completer<void>();
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(call),
        (data) {
          expect(codec.decodeEnvelope(data!), isNull);
          reply.complete();
        },
      );
      await reply.future;
      await tester.pump();
    }
    expect(first, 2);
    expect(second, 2);
    expect(rotations, [2]);
  });

  test('displayRotation returns each native rotation', () async {
    for (var rotation = 0; rotation < 4; rotation++) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'displayRotation');
        expect(call.arguments, isNull);
        return rotation;
      });
      expect(await device.displayRotation(), rotation);
    }
  });

  test('displayRotation falls back when native is unavailable', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    expect(await device.displayRotation(), 0);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    expect(await device.displayRotation(), 0);
  });

  test('displayRotation falls back for out-of-range or null values', () async {
    for (final value in <int?>[-1, 4, null]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => value,
      );
      expect(await device.displayRotation(), 0);
    }
  });

  test('setSketchWindow sends its bool and tolerates native errors', () async {
    final values = <Object?>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'setSketchWindow');
      values.add(call.arguments);
      return null;
    });
    await device.setSketchWindow(true);
    await device.setSketchWindow(false);
    expect(values, [true, false]);

    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    await device.setSketchWindow(true);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await device.setSketchWindow(false);
  });

  testWidgets('native rotations broadcast and invalid values are ignored', (
    tester,
  ) async {
    final first = <int>[];
    final second = <int>[];
    final firstSubscription = device.displayRotationChanges.listen(first.add);
    final secondSubscription = device.displayRotationChanges.listen(second.add);
    addTearDown(firstSubscription.cancel);
    addTearDown(secondSubscription.cancel);

    for (final value in <Object?>[0, 2, 1, 3, -1, 4, '2', 1.0, null]) {
      final reply = Completer<void>();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(MethodCall('displayRotationChanged', value)),
        (data) {
          expect(codec.decodeEnvelope(data!), isNull);
          reply.complete();
        },
      );
      await reply.future;
      await tester.pump();
    }
    expect(first, [0, 2, 1, 3]);
    expect(second, first);
  });

  testWidgets('unknown incoming methods are not implemented', (tester) async {
    // Access installs the incoming handler even without a stream subscriber.
    device.displayRotationChanges;
    final reply = Completer<void>();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(const MethodCall('unknownDeviceMethod')),
      (data) {
        expect(data, isNull);
        reply.complete();
      },
    );
    await reply.future;
  });
}
