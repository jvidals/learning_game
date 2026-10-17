import 'package:flutter/services.dart';
import 'profiles.dart';

enum DeviceFeedback { light, confirm, retry, placement }

/// The only boundary to Android: bundled audio and player storage.
abstract class DeviceServices {
  Future<String> loadProfiles();
  Future<void> saveProfiles(String document);
  Future<void> play(String clip);
  Future<void> stop();
  Future<void> feedback(DeviceFeedback kind);
}

class AndroidServices implements DeviceServices {
  static const _channel = MethodChannel('rainbow_garden/device');

  @override
  Future<String> loadProfiles() async => (await _channel.invokeMethod<String>(
    'loadProfiles',
    ProfileStore.initial().encode(),
  ))!;
  @override
  Future<void> saveProfiles(String document) =>
      _channel.invokeMethod<void>('saveProfiles', document);

  @override
  Future<void> play(String clip) => _channel
      .invokeMethod<void>('play', clip)
      .timeout(const Duration(seconds: 5));

  @override
  Future<void> feedback(DeviceFeedback kind) async {
    try {
      await _channel.invokeMethod<void>('feedback', kind.name);
    } catch (_) {
      // Optional feedback must never interrupt play.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Leaving a screen must still work if Android has already released audio.
    }
  }
}

Future<void> requestFeedback(
  DeviceServices services,
  DeviceFeedback kind, {
  required bool enabled,
}) async {
  if (!enabled) return;
  try {
    await services.feedback(kind);
  } catch (_) {}
}
