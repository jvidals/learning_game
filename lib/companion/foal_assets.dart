import 'dart:convert';
import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'foal_clip.dart';
import '../progress.dart';

/// Shared bundled posters and a bounded animation resource boundary.
class FoalAssets {
  FoalAssets(this.manifest, this.posters, this.hair);
  final Map<String, dynamic> manifest;
  final Map<String, ui.Image> posters;
  final ui.FragmentProgram hair;
  static const directory = 'assets/companion/foal_3d';
  static const memoryLimit = 64 * 1024 * 1024;
  static final cache = FoalAssetCache(_load);
  static FoalAssets? get ready => cache.ready;
  static Future<FoalAssets> load() => cache.load();
  int _frameBytes = 0;
  final _players = <Object, void Function()>{};
  bool get allowLookahead => _players.length <= 1;
  void registerPlayback(Object owner, void Function() releaseAhead) {
    if (_players.containsKey(owner)) return;
    _players[owner] = releaseAhead;
    if (_players.length > 1) {
      for (final release in _players.values) {
        release();
      }
    }
  }

  void unregisterPlayback(Object owner) => _players.remove(owner);

  final _details = LinkedHashMap<String, ui.Image>();
  final _posterLoads = <String, Future<void>>{};
  Future<void> _posterQueue = Future.value();
  int get packedPlanes => (manifest['packedPlanes'] as List?)?.length ?? 5;
  int get frameBytes =>
      (manifest['size'] as int) * (manifest['size'] as int) * packedPlanes * 4;
  ui.Color paletteColor(String id) => ui.Color(
    0xFF000000 |
        int.parse((manifest['palette'] as Map)[id] as String, radix: 16),
  );
  ui.Image poster(String outfit) {
    final detailed = _details.remove(outfit);
    if (detailed != null) _details[outfit] = detailed;
    return detailed ?? posters[outfit]!;
  }

  /// Small posters remain available; at most four full-detail posters are cached.
  Future<void> ensurePoster(String outfit) {
    if (_details.containsKey(outfit)) {
      poster(outfit);
      return Future.value();
    }
    return _posterLoads.putIfAbsent(outfit, () {
      final result = _posterQueue.then((_) async {
        if (_details.containsKey(outfit)) return;
        while (_details.length >= 4) {
          _details.remove(_details.keys.first)!.dispose();
        }
        final bytes = 256 * 256 * packedPlanes * 4;
        if (!reserve(bytes)) return;
        ui.Codec? codec;
        try {
          codec = await _decode('$outfit-poster.webp', 256);
          final image = (await codec.getNextFrame()).image;
          _details[outfit] = image;
        } finally {
          codec?.dispose();
          release(bytes);
        }
      });
      _posterQueue = result.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      );
      return result.whenComplete(() {
        _posterLoads.remove(outfit);
      });
    });
  }

  int get posterBytes => [
    ...posters.values,
    ..._details.values,
  ].fold(0, (n, image) => n + image.width * image.height * 4);
  int get decodedBytes => posterBytes + _frameBytes;
  bool reserve(int bytes) {
    // Animation has priority over optional detailed posters.
    while (decodedBytes + bytes > memoryLimit && _details.isNotEmpty) {
      _details.remove(_details.keys.first)!.dispose();
    }
    if (decodedBytes + bytes > memoryLimit) return false;
    _frameBytes += bytes;
    return true;
  }

  void release(int bytes) {
    _frameBytes -= bytes;
    assert(_frameBytes >= 0);
  }

  static Future<FoalAssets> _load() async {
    final posters = <String, ui.Image>{};
    try {
      final manifest =
          jsonDecode(await rootBundle.loadString('$directory/manifest.json'))
              as Map<String, dynamic>;
      validateManifest(manifest);
      final hair = await ui.FragmentProgram.fromAsset(
        'shaders/companion_hair.frag',
      );
      for (final outfit in (manifest['outfits'] as Map).keys.cast<String>()) {
        final codec = await _decode('$outfit-poster.webp', 128);
        try {
          posters[outfit] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
      final items = await _decode('items.png', 768);
      try {
        posters['__items'] = (await items.getNextFrame()).image;
      } finally {
        items.dispose();
      }
      final assets = FoalAssets(manifest, Map.unmodifiable(posters), hair);
      if (assets.posterBytes + assets.frameBytes * 2 > memoryLimit) {
        throw const FormatException('Foal posters leave no playback memory');
      }
      await assets.ensurePoster('none-none');
      return assets;
    } catch (_) {
      for (final image in posters.values) {
        image.dispose();
      }
      rethrow;
    }
  }

  static void validateManifest(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 2 ||
        data['fps'] != 60 ||
        data['size'] != 1024 ||
        data['segmentFrames'] != 15) {
      throw const FormatException('Unsupported foal asset contract');
    }
    if (jsonEncode(data['packedPlanes']) !=
        jsonEncode(['color', 'hair', 'hooves', 'headwear', 'wings'])) {
      throw const FormatException('Incomplete foal masks');
    }
    final palette = data['palette'] as Map;
    for (final id in {
      'pink',
      for (final reward in rewardCatalog)
        if (reward.tint != null) reward.tint!,
    }) {
      if (palette[id] is! String ||
          !RegExp(r'^[0-9A-F]{6}$').hasMatch(palette[id])) {
        throw const FormatException('Invalid companion palette');
      }
    }
    final items = (data['itemIds'] as List).cast<String>();
    final expectedItems = {
      'simple',
      'polish_none',
      for (final reward in rewardCatalog)
        if (reward.category != RewardCategory.mane) reward.id,
    };
    if (items.length != expectedItems.length ||
        !items.toSet().containsAll(expectedItems)) {
      throw const FormatException('Invalid reward pictures');
    }
    final outfits = data['outfits'] as Map;
    final heads = {
      'none',
      for (final reward in rewardCatalog)
        if (reward.category == RewardCategory.accessory) reward.geometry!,
    };
    final wings = {
      'none',
      for (final reward in rewardCatalog)
        if (reward.category == RewardCategory.wings) reward.geometry!,
    };
    if (outfits.length != heads.length * wings.length) {
      throw const FormatException('Incomplete foal outfits');
    }
    for (final head in heads) {
      for (final wing in wings) {
        final outfit = outfits['$head-$wing'] as Map;
        for (final entry in foalDurations.entries) {
          final definition = (data['clips'] as Map)[entry.key] as Map;
          final clip = outfit[entry.key] as Map;
          final count = (entry.value * 60 / 1000).round();
          if (definition['durationMs'] != entry.value ||
              definition['loop'] != (entry.key == 'idle') ||
              clip['frameCount'] != count) {
            throw const FormatException('Foal timing mismatch');
          }
          var next = 0;
          for (final segment in clip['segments'] as List) {
            final length = segment['frameCount'] as int;
            final asset = segment['asset'] as String;
            final decoded = segment['decodedFrameCount'] as int;
            final samples = (segment['sampleFrames'] as List).cast<int>();
            if (segment['firstFrame'] != next ||
                length != (count - next).clamp(1, 15) ||
                decoded < 1 ||
                decoded > length ||
                samples.length != length ||
                samples.first != 0 ||
                samples.last != decoded - 1 ||
                asset !=
                    '$head-$wing-${entry.key}-${(next ~/ 15).toString().padLeft(3, '0')}.webp') {
              throw const FormatException('Invalid foal segment');
            }
            for (var i = 1; i < samples.length; i++) {
              if (samples[i] < samples[i - 1] ||
                  samples[i] > samples[i - 1] + 1) {
                throw const FormatException('Invalid foal frame mapping');
              }
            }
            next += length;
          }
          if (next != count) {
            throw const FormatException('Incomplete foal clip');
          }
        }
      }
    }
  }

  static Future<ui.Codec> _decode(String asset, int width) async {
    final data = await rootBundle.load('$directory/$asset');
    return ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      targetWidth: width,
      allowUpscaling: false,
    );
  }

  Future<ui.Codec> codec(String asset, int width) => _decode(asset, width);

  int segmentFrameCount(String outfit, FoalClipSample sample) =>
      (((manifest['outfits'] as Map)[outfit] as Map)[sample.clip]['segments']
              as List)[sample.segment]['decodedFrameCount']
          as int;

  int decodedFrame(String outfit, FoalClipSample sample) =>
      (((manifest['outfits'] as Map)[outfit] as Map)[sample.clip]['segments']
              as List)[sample.segment]['sampleFrames'][sample.localFrame]
          as int;

  ui.Rect framing(String name) {
    final values = (manifest['framing'][name] as List).cast<num>();
    return ui.Rect.fromLTWH(
      values[0].toDouble(),
      values[1].toDouble(),
      values[2].toDouble(),
      values[3].toDouble(),
    );
  }
}

/// Coalesces concurrent consumers and releases failed requests for retry.
class FoalAssetCache {
  FoalAssetCache(this.loader);
  final Future<FoalAssets> Function() loader;
  Future<FoalAssets>? _pending;
  FoalAssets? ready;
  Future<FoalAssets> load() =>
      _pending ??= Future<FoalAssets>.sync(loader).then(
        (value) => ready = value,
        onError: (Object error, StackTrace stack) {
          _pending = null;
          Error.throwWithStackTrace(error, stack);
        },
      );
}
