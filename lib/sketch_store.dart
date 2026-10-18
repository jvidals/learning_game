import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'device_services.dart';

/// Serial, latest-wins autosave for one player's sketch at a time. Separate
/// from ProgressController's save guard so drawing never blocks XP/settings.
class SketchStore {
  SketchStore(this.services, {this.delay = const Duration(seconds: 1)});

  final DeviceServices services;
  final Duration delay;
  final _failed = ValueNotifier(false);
  final _pngByPlayer = <String, Uint8List>{};
  final _queued = <_SketchWrite>[];
  _SketchWrite? _pending;
  String? _lastUpdatedPlayer;
  Timer? _timer;
  Future<void>? _draining, _closing;
  bool _closed = false, _released = false;

  ValueListenable<bool> get failed => _failed;
  bool get hasPending => _pending != null || _queued.isNotEmpty;

  /// A failed read propagates so the caller cannot mistake it for a blank page.
  Future<SketchSnapshot> load(String playerId) async {
    if (_closed) throw StateError('Sketch store is closed');
    final snapshot = await services.loadSketch(playerId);
    final png = snapshot.png;
    if (png == null) {
      _pngByPlayer.remove(playerId);
    } else {
      _pngByPlayer[playerId] = png;
    }
    return snapshot;
  }

  /// Takes ownership of [page], including when the store has already closed.
  void update(String playerId, {ui.Image? page, required String settings}) {
    if (_closed) {
      page?.dispose();
      return;
    }
    if (_lastUpdatedPlayer != null && _lastUpdatedPlayer != playerId) {
      // Freeze the previous player's work before accepting another player's edit.
      unawaited(flush());
    }
    _lastUpdatedPlayer = playerId;
    if (_queued.isNotEmpty && _queued.last.playerId == playerId) {
      final latest = _queued.last;
      latest.settings = settings;
      if (page != null) {
        latest.page?.dispose();
        latest.page = page;
      }
    } else {
      _queued.add(_SketchWrite(playerId, page, settings));
    }
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  /// Cancels debounce and drains serially; concurrent flushes share completion.
  Future<void> flush() {
    if (_released) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    final draining = _draining;
    if (draining != null) return draining;
    final completion = Completer<void>();
    _draining = completion.future;
    _drain().then((_) => completion.complete());
    return completion.future;
  }

  Future<void> _drain() async {
    try {
      while (true) {
        if (_pending == null) {
          // A settings-only edit for a never-drawn player stays held. It must
          // not prevent another player's drawing from reaching disk.
          final index = _queued.indexWhere(
            (edit) =>
                edit.page != null || _pngByPlayer.containsKey(edit.playerId),
          );
          if (index < 0) return;
          _pending = _queued.removeAt(index);
        }
        final pending = _pending!;
        if (pending.png == null) {
          final page = pending.page;
          if (page != null) {
            final bytes = await page.toByteData(format: ui.ImageByteFormat.png);
            if (bytes == null) throw StateError('Could not encode sketch PNG');
            pending.png = bytes.buffer.asUint8List(
              bytes.offsetInBytes,
              bytes.lengthInBytes,
            );
            page.dispose();
            pending.page = null;
          } else {
            pending.png = _pngByPlayer[pending.playerId]!;
          }
          _pngByPlayer[pending.playerId] = pending.png!;
        }
        await services.saveSketch(
          pending.playerId,
          png: pending.png!,
          settings: pending.settings,
        );
        _pending = null;
        _failed.value = false;
      }
    } catch (error) {
      // Keep this exact payload ahead of newer edits until a retry succeeds.
      _failed.value = true;
      debugPrint('Could not save sketch: $error');
    } finally {
      // Release synchronously even when there was nothing eligible to save.
      // An edit followed by flush in the same turn must start a fresh drain.
      _draining = null;
    }
  }

  Future<void> retry() => flush();

  /// Flushes before releasing owned images, including after a failed encode.
  Future<void> close() {
    final closing = _closing;
    if (closing != null) return closing;
    _closed = true;
    return _closing = _close();
  }

  Future<void> _close() async {
    await flush();
    _timer?.cancel();
    _pending?.page?.dispose();
    _pending?.page = null;
    for (final edit in _queued) {
      edit.page?.dispose();
      edit.page = null;
    }
    _released = true;
    _failed.dispose();
  }
}

class _SketchWrite {
  _SketchWrite(this.playerId, this.page, this.settings);
  final String playerId;
  ui.Image? page;
  Uint8List? png;
  String settings;
}
