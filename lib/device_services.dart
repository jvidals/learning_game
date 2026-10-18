import 'dart:async';

import 'package:flutter/services.dart';
import 'profiles.dart';

enum DeviceFeedback { light, confirm, retry, placement }

class SketchSnapshot {
  const SketchSnapshot({this.png, this.settings});
  final Uint8List? png;
  final String? settings;
}

bool isValidSketchPlayerId(String playerId) =>
    RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(playerId);

void _validateSketchPlayerId(String playerId) {
  if (!isValidSketchPlayerId(playerId)) {
    throw ArgumentError.value(playerId, 'playerId', 'Invalid sketch player ID');
  }
}

/// The only boundary to Android: bundled audio and player storage.
abstract class DeviceServices {
  Future<String> loadProfiles();
  Future<void> saveProfiles(String document);
  Future<SketchSnapshot> loadSketch(String playerId);
  Future<void> saveSketch(
    String playerId, {
    required Uint8List png,
    required String settings,
  });
  Future<void> deleteSketch(String playerId);
  Future<bool> canSaveToGallery();
  Future<String> saveToGallery(
    Uint8List png,
    String displayName, {
    String? replaceUri,
  });
  Future<int> displayRotation();
  Stream<int> get displayRotationChanges;
  Stream<void> get shortcutRequests;
  Future<String?> takeShortcut();
  Future<void> setSketchWindow(bool active);

  /// Completes when the clip finishes, is stopped, or is replaced by another clip.
  Future<void> play(String clip);
  Future<void> stop();
  Future<void> feedback(DeviceFeedback kind);
}

class AndroidServices implements DeviceServices {
  static const _channel = MethodChannel('rainbow_garden/device');
  static final _rotations = StreamController<int>.broadcast();
  static final _shortcuts = StreamController<void>.broadcast();
  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'displayRotationChanged':
          final value = call.arguments;
          if (value is int && value >= 0 && value <= 3) {
            _rotations.add(value);
          }
        case 'shortcutRequested':
          _shortcuts.add(null);
        default:
          throw MissingPluginException('Unknown device method: ${call.method}');
      }
    });
    _handlerInstalled = true;
  }

  @override
  Stream<void> get shortcutRequests {
    _ensureHandler();
    return _shortcuts.stream;
  }

  @override
  Future<String?> takeShortcut() async {
    try {
      final value = await _channel.invokeMethod<Object?>('takeShortcut');
      return value == 'sketchPad' || value == 'game2048'
          ? value as String
          : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<int> displayRotation() async {
    try {
      final value = await _channel.invokeMethod<int>('displayRotation');
      return value != null && value >= 0 && value <= 3 ? value : 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  @override
  Stream<int> get displayRotationChanges {
    _ensureHandler();
    return _rotations.stream;
  }

  @override
  Future<void> setSketchWindow(bool active) async {
    _ensureHandler();
    try {
      await _channel.invokeMethod<void>('setSketchWindow', active);
    } on PlatformException {
      // Window effects are best effort.
    } on MissingPluginException {
      // Other platforms do not provide Sketch window effects.
    }
  }

  @override
  Future<String> loadProfiles() async => (await _channel.invokeMethod<String>(
    'loadProfiles',
    ProfileStore.initial().encode(),
  ))!;
  @override
  Future<void> saveProfiles(String document) =>
      _channel.invokeMethod<void>('saveProfiles', document);

  @override
  Future<SketchSnapshot> loadSketch(String playerId) async {
    _validateSketchPlayerId(playerId);
    final result = await _channel.invokeMapMethod<String, Object?>(
      'loadSketch',
      {'playerId': playerId},
    );
    if (result == null) throw StateError('Missing sketch snapshot');
    return SketchSnapshot(
      png: result['png'] as Uint8List?,
      settings: result['settings'] as String?,
    );
  }

  @override
  Future<void> saveSketch(
    String playerId, {
    required Uint8List png,
    required String settings,
  }) async {
    _validateSketchPlayerId(playerId);
    await _channel.invokeMethod<void>('saveSketch', {
      'playerId': playerId,
      'png': png,
      'settings': settings,
    });
  }

  @override
  Future<void> deleteSketch(String playerId) async {
    _validateSketchPlayerId(playerId);
    await _channel.invokeMethod<void>('deleteSketch', {'playerId': playerId});
  }

  @override
  Future<bool> canSaveToGallery() async {
    try {
      return await _channel.invokeMethod<bool>('canSaveToGallery') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> saveToGallery(
    Uint8List png,
    String displayName, {
    String? replaceUri,
  }) async {
    final uri = await _channel.invokeMethod<String>('saveToGallery', {
      'png': png,
      'name': displayName,
      'replaceUri': ?replaceUri,
    });
    if (uri == null) throw StateError('Gallery export returned no photo URI');
    return uri;
  }

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
