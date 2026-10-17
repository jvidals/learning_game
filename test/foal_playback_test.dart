import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:rainbow_garden/companion/foal_assets.dart';
import 'package:rainbow_garden/companion/foal_clip.dart';
import 'package:rainbow_garden/companion/foal_playback.dart';

class TestFrames extends FoalAssets {
  TestFrames(super.manifest, super.posters, super.hair, this.source);
  final ui.Image source;
  Completer<void>? gate;
  bool fail = false;
  int? failAfter;
  int loads = 0;
  final codecs = <TestCodec>[];
  @override
  Future<ui.Codec> codec(String asset, int width) async {
    loads++;
    final codec = TestCodec(source, gate, fail, failAfter);
    codecs.add(codec);
    return codec;
  }

  @override
  int decodedFrame(String outfit, FoalClipSample sample) => sample.localFrame;
  @override
  int segmentFrameCount(String outfit, FoalClipSample sample) => 15;
}

class TestCodec implements ui.Codec {
  TestCodec(this.source, this.gate, this.fail, this.failAfter);
  final ui.Image source;
  final Completer<void>? gate;
  final bool fail;
  final int? failAfter;
  int decoded = 0;
  bool disposed = false;
  @override
  int get frameCount => 15;
  @override
  int get repetitionCount => 0;
  @override
  void dispose() => disposed = true;
  @override
  Future<ui.FrameInfo> getNextFrame() async {
    await gate?.future;
    if (fail || (failAfter != null && decoded >= failAfter!)) {
      throw StateError('fixture decode failure');
    }
    decoded++;
    return TestFrame(source.clone());
  }
}

class TestFrame implements ui.FrameInfo {
  TestFrame(this.image);
  @override
  final ui.Image image;
  @override
  Duration get duration => const Duration(milliseconds: 17);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestFrames assets;
  setUp(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xffff00ff), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final source = await picture.toImage(32, 64);
    picture.dispose();
    assets = TestFrames(
      {'size': 1024},
      {},
      await ui.FragmentProgram.fromAsset('shaders/companion_hair.frag'),
      source,
    );
  });
  tearDown(() {
    expect(assets.decodedBytes, 0);
    assets.source.dispose();
  });

  test('a decode failure stays latched until explicit retry', () async {
    final player = FoalPlayback(assets);
    assets.fail = true;
    player.request('none-none', const FoalClipSample('idle', 0));
    await player.pending;
    expect(player.error, isStateError);
    expect(assets.decodedBytes, 0);
    player.request('none-none', const FoalClipSample('idle', 5));
    await player.pending;
    expect(assets.loads, 1);
    assets.fail = false;
    player.cancel();
    player.request('none-none', const FoalClipSample('idle', 5));
    await player.pending;
    expect(player.error, isNull);
    expect(player.image, isNotNull);
    player.dispose();
    expect(assets.codecs.every((c) => c.disposed), isTrue);
  });

  test(
    'late decoding after cancellation cannot publish an old outfit',
    () async {
      final player = FoalPlayback(assets);
      final old = assets.gate = Completer<void>();
      player.request('star-feather', const FoalClipSample('twirl', 0));
      await Future<void>.delayed(Duration.zero);
      expect(assets.decodedBytes, 20 * 1024 * 1024);
      player.cancel();
      assets.gate = null;
      player.request('bow-butterfly', const FoalClipSample('idle', 1));
      old.complete();
      await player.pending;
      expect(player.imageFor('star-feather'), isNull);
      expect(player.imageFor('bow-butterfly'), isNotNull);
      expect(assets.decodedBytes, 40 * 1024 * 1024);
      player.dispose();
    },
  );

  test(
    'failure after visible frames releases current and lookahead images',
    () async {
      assets.failAfter = 2;
      final player = FoalPlayback(assets);
      player.request('none-none', const FoalClipSample('idle', 0));
      await player.pending;
      expect(player.image, isNotNull);
      expect(assets.decodedBytes, 40 * 1024 * 1024);
      player.request('none-none', const FoalClipSample('idle', 3));
      await player.pending;
      expect(player.error, isStateError);
      expect(player.image, isNull);
      expect(assets.decodedBytes, 0);
      player.dispose();
    },
  );

  test(
    'repeated outfit and reaction changes keep only the current outfit',
    () async {
      final player = FoalPlayback(assets);
      const outfits = [
        'none-none',
        'star-feather',
        'bow-butterfly',
        'flower-rainbow',
      ];
      for (var i = 0; i < 64; i++) {
        final outfit = outfits[i % outfits.length];
        player.request(
          outfit,
          FoalClipSample(i.isEven ? 'idle' : 'happy', i % 30),
        );
        await player.pending;
        expect(player.error, isNull);
        expect(player.imageFor(outfit), isNotNull);
        expect(player.imageFor(outfits[(i + 3) % outfits.length]), isNull);
        expect(assets.decodedBytes, lessThanOrEqualTo(40 * 1024 * 1024));
      }
      player.cancel();
      expect(assets.decodedBytes, 0);
      player.dispose();
      expect(assets.codecs.every((codec) => codec.disposed), isTrue);
    },
  );

  test('late decoding after disposal releases its reservation', () async {
    final player = FoalPlayback(assets);
    final gate = assets.gate = Completer<void>();
    player.request('none-none', const FoalClipSample('idle', 0));
    await Future<void>.delayed(Duration.zero);
    player.dispose();
    gate.complete();
    await player.pending;
    expect(player.image, isNull);
  });

  test(
    'shared budget defers decoding until other players release frames',
    () async {
      final players = List.generate(5, (_) => FoalPlayback(assets));
      for (final player in players) {
        player.request('none-none', const FoalClipSample('idle', 0));
        await player.pending;
        expect(assets.decodedBytes, lessThanOrEqualTo(FoalAssets.memoryLimit));
      }
      expect(players.last.image, isNull);
      players.first.dispose();
      players.last.request('none-none', const FoalClipSample('idle', 0));
      await players.last.pending;
      expect(players.last.image, isNotNull);
      for (final player in players.skip(1)) {
        player.dispose();
      }
    },
  );
  test('two current frames keep advancing when no extra frame fits', () async {
    const mib = 1024 * 1024;
    // Hold 19 MiB for shared posters and temporarily hold another frame.
    expect(assets.reserve(39 * mib), isTrue);
    final first = FoalPlayback(assets), second = FoalPlayback(assets);
    first.request('none-none', const FoalClipSample('idle', 0));
    await first.pending;
    assets.release(20 * mib);
    try {
      second.request('none-none', const FoalClipSample('idle', 0));
      await second.pending;
      expect(first.image, isNotNull);
      expect(second.image, isNotNull);
      for (final frame in [2, 5, 9]) {
        first.request('none-none', FoalClipSample('idle', frame));
        await first.pending;
        second.request('none-none', FoalClipSample('idle', frame));
        await second.pending;
        expect(first.error, isNull);
        expect(second.error, isNull);
        expect(first.image, isNotNull);
        expect(second.image, isNotNull);
        expect(assets.codecs.take(2).every((c) => c.decoded > frame), isTrue);
        expect(assets.decodedBytes, lessThanOrEqualTo(FoalAssets.memoryLimit));
      }
    } finally {
      first.dispose();
      second.dispose();
      assets.release(19 * mib);
    }
  });
  test(
    'shared detail loads finish and optional posters yield their memory',
    () async {
      final first = assets.ensurePoster('none-none');
      final second = assets.ensurePoster('none-none');
      expect(identical(first, second), isTrue);
      await first.timeout(const Duration(seconds: 5));
      final poster = assets.poster('none-none');
      expect(poster.width, 256);
      expect(assets.decodedBytes, poster.width * poster.height * 4);
      // An animation reservation can evict all optional detailed posters.
      expect(assets.reserve(FoalAssets.memoryLimit), isTrue);
      expect(assets.posterBytes, 0);
      assets.release(FoalAssets.memoryLimit);
    },
  );
  test(
    'a second player releases lookahead and the first can revisit that frame',
    () async {
      const mib = 1024 * 1024;
      final first = FoalPlayback(assets), second = FoalPlayback(assets);
      try {
        first.request('none-none', const FoalClipSample('idle', 0));
        await first.pending;
        expect(assets.decodedBytes, 40 * mib);
        second.request('none-none', const FoalClipSample('idle', 0));
        expect(assets.decodedBytes, 20 * mib);
        await second.pending;
        expect(assets.decodedBytes, 40 * mib);
        first.request('none-none', const FoalClipSample('idle', 1));
        await first.pending;
        expect(first.image, isNotNull);
        expect(first.error, isNull);
        expect(assets.codecs.last.decoded, 2);
        expect(assets.decodedBytes, 40 * mib);
        second.cancel();
        first.request('none-none', const FoalClipSample('idle', 2));
        await first.pending;
        expect(assets.decodedBytes, 40 * mib);
      } finally {
        first.dispose();
        second.dispose();
      }
    },
  );
}
