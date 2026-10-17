import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'foal_assets.dart';
import 'foal_clip.dart';

/// A visible companion holds its current frame and at most one decoded lookahead.
/// All players reserve from the same image budget before decoding.
class FoalPlayback extends ChangeNotifier {
  FoalPlayback(this.assets);
  final FoalAssets assets;
  ui.Codec? _codec;
  FoalFrame? _current, _ahead;
  String? _context, _currentContext;
  int _currentIndex = -1, _aheadIndex = -1, _decodedIndex = -1;
  int _generation = 0;
  bool _busy = false, _disposed = false;
  _Request? _wanted;
  Object? error;
  Future<void>? _work;

  ui.Image? get image => _current?.image;
  ui.Image? imageFor(String outfit) =>
      _currentContext?.startsWith('$outfit-') == true ? image : null;
  Future<void> get pending async {
    // Cancellation can start a replacement pump in the old pump's finally.
    // Await that replacement too, rather than reporting a premature idle.
    Future<void>? work;
    do {
      work = _work;
      await work;
    } while (!identical(work, _work));
  }

  void request(String outfit, FoalClipSample sample, {int width = 512}) {
    // Keep a failed load latched until the explicit reload action calls
    // cancel(). Animation ticks must not retry a broken asset 60 times/sec.
    if (_disposed || error != null) return;
    assets.registerPlayback(this, _releaseAhead);
    final next = _Request(
      outfit,
      sample,
      width,
      assets.decodedFrame(outfit, sample),
    );
    _wanted = next;
    if (_currentContext == next.context && _currentIndex == next.decodedFrame) {
      return;
    }
    if (_context == next.context &&
        _aheadIndex == next.decodedFrame &&
        _ahead != null) {
      _current?.dispose();
      _current = _ahead;
      _ahead = null;
      _currentContext = next.context;
      _currentIndex = _aheadIndex;
    }
    if (!_busy) _work = _pump();
  }

  Future<void> _pump() async {
    _busy = true;
    final generation = _generation;
    bool live() => !_disposed && generation == _generation;
    try {
      while (live() && _wanted != null) {
        final request = _wanted!;
        if (_context != request.context ||
            (_decodedIndex >= request.decodedFrame &&
                !(_currentContext == request.context &&
                    _currentIndex == request.decodedFrame))) {
          _codec?.dispose();
          _codec = null;
          _ahead?.dispose();
          _ahead = null;
          _context = request.context;
          _decodedIndex = -1;
          final codec = await assets.codec(request.asset, request.width);
          if (!live() || _wanted?.context != request.context) {
            codec.dispose();
            if (!live()) return;
            _context = null;
            continue;
          }
          _codec = codec;
        }
        // A skipped lookahead must not prevent reserving the requested frame.
        if (_ahead != null && _aheadIndex != request.decodedFrame) {
          _ahead!.dispose();
          _ahead = null;
          _aheadIndex = -1;
        }
        final codec = _codec!;
        final count = assets.segmentFrameCount(request.outfit, request.sample);
        final goal = request.decodedFrame;
        // Decode only the requested frame plus one lookahead. Old frames are
        // released immediately, including skipped frames after a slow decode.
        final through = (goal + (assets.allowLookahead ? 1 : 0)).clamp(
          0,
          count - 1,
        );
        while (live() &&
            _wanted?.context == request.context &&
            _decodedIndex < through) {
          // This Flutter engine decodes animated WebP at source resolution,
          // even with a smaller targetWidth. Reserve the actual packed size.
          final bytes = assets.frameBytes;
          if (!assets.reserve(bytes)) {
            // Two visible players can each hold a large current frame. Release
            // this player's obsolete frame before decoding its replacement;
            // the shared static poster remains available in the meantime.
            if (_current == null || _decodedIndex >= goal) return;
            _current!.dispose();
            _current = null;
            _currentContext = null;
            _currentIndex = -1;
            if (!assets.reserve(bytes)) return;
          }
          ui.FrameInfo info;
          try {
            info = await codec.getNextFrame();
          } catch (_) {
            assets.release(bytes);
            rethrow;
          }
          final frame = FoalFrame(info.image, () => assets.release(bytes));
          if (!live() || _wanted?.context != request.context) {
            frame.dispose();
            break;
          }
          _decodedIndex++;
          final desired = _wanted!.decodedFrame;
          if (_decodedIndex <= desired) {
            _current?.dispose();
            _current = frame;
            _currentContext = request.context;
            _currentIndex = _decodedIndex;
            notifyListeners();
          } else if (assets.allowLookahead) {
            _ahead?.dispose();
            _ahead = frame;
            _aheadIndex = _decodedIndex;
          } else {
            frame.dispose();
          }
        }
        if (!live()) return;
        if (_wanted?.identity == request.identity) return;
      }
    } catch (failure) {
      if (live()) {
        // The retry UI replaces the sprite. Release both retained frames as
        // well as the codec, including a failure partway through a segment.
        cancel();
        error = failure;
        notifyListeners();
      }
    } finally {
      _busy = false;
      if (!_disposed && generation != _generation && _wanted != null) {
        _work = _pump();
      }
    }
  }

  void _releaseAhead() {
    _ahead?.dispose();
    _ahead = null;
    _aheadIndex = -1;
  }

  void cancel() {
    assets.unregisterPlayback(this);
    _generation++;
    _wanted = null;
    _codec?.dispose();
    _codec = null;
    _current?.dispose();
    _current = null;
    _ahead?.dispose();
    _ahead = null;
    _context = _currentContext = null;
    _currentIndex = _aheadIndex = _decodedIndex = -1;
    error = null;
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

class FoalFrame {
  FoalFrame(this.image, this._release);
  final ui.Image image;
  final VoidCallback _release;
  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    image.dispose();
    _release();
  }
}

class _Request {
  const _Request(this.outfit, this.sample, this.width, this.decodedFrame);
  final String outfit;
  final FoalClipSample sample;
  final int width;
  final int decodedFrame;
  String get asset =>
      '$outfit-${sample.clip}-${sample.segment.toString().padLeft(3, '0')}.webp';
  String get context => '$asset@$width';
  String get identity => '$context:$decodedFrame';
}
