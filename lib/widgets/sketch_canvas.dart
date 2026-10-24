import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_theme.dart';
import '../flood_fill.dart';
import '../sketch.dart';
import '../sketch_ink.dart';

sealed class SketchOp {}

class StrokeOp extends SketchOp {
  StrokeOp(this.stroke);
  final SketchStroke stroke;
}

class FillOp extends SketchOp {
  FillOp([this.image, this.left = 0, this.top = 0]);
  ui.Image? image;
  int left, top;
  bool discarded = false;
  List<SketchTwinkle> twinkles = const [];
  Uint8List? _coverage;
  int _coverageWidth = 0, _coverageHeight = 0;

  // One bit per pixel, captured once from the completed isolate result.
  void _setCoverage(FloodFillResult result) {
    _coverageWidth = result.width;
    _coverageHeight = result.height;
    final mask = _coverage = Uint8List((result.width * result.height + 7) ~/ 8);
    for (var i = 0; i < result.width * result.height; i++) {
      if (result.rgba[i * 4 + 3] > 0) mask[i >> 3] |= 1 << (i & 7);
    }
  }

  bool _covers(SketchTwinkle anchor) {
    final x = anchor.x.floor() - left, y = anchor.y.floor() - top;
    if (x < 0 || y < 0 || x >= _coverageWidth || y >= _coverageHeight) {
      return false;
    }
    final i = y * _coverageWidth + x;
    return _coverage != null && (_coverage![i >> 3] & (1 << (i & 7))) != 0;
  }
}

class ClearOp extends SketchOp {
  ClearOp(this.size);
  final Size size;
}

// Coverage follows the input polyline, including a dot's circular footprint.
// Reject the whole stroke bounds first, then segment bounds before distance.
void _removeStrokeTwinkles(List<SketchTwinkle> anchors, SketchStroke stroke) {
  final points = stroke.points;
  if (points.isEmpty || anchors.isEmpty) return;
  final radius =
      (stroke.special == SketchSpecial.neon
          ? stroke.width * .95
          : stroke.width / 2) +
      4;
  var bounds = Rect.fromPoints(points.first, points.first);
  for (final point in points.skip(1)) {
    bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
  }
  bounds = bounds.inflate(radius);
  final squared = radius * radius;
  bool within(Rect rect, Offset point) =>
      point.dx >= rect.left &&
      point.dx <= rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
  anchors.removeWhere((anchor) {
    final p = Offset(anchor.x, anchor.y);
    if (!within(bounds, p)) return false;
    if ((p - points.first).distanceSquared <= squared) return true;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (!within(Rect.fromPoints(a, b).inflate(radius), p)) continue;
      final delta = b - a;
      final length = delta.distanceSquared;
      final t = length == 0
          ? 0.0
          : (((p - a).dx * delta.dx + (p - a).dy * delta.dy) / length).clamp(
              0.0,
              1.0,
            );
      if ((p - (a + delta * t)).distanceSquared <= squared) return true;
    }
    return false;
  });
}

List<SketchTwinkle> _foldTwinkles(
  List<SketchTwinkle> baked,
  Iterable<SketchOp> ops,
) {
  final anchors = [...baked];
  for (final op in ops) {
    switch (op) {
      case ClearOp():
        anchors.clear();
      case StrokeOp():
        _removeStrokeTwinkles(anchors, op.stroke);
        anchors.addAll(glitterTwinkles(op.stroke));
      case FillOp():
        anchors.removeWhere(op._covers);
        anchors.addAll(op.twinkles);
    }
    if (anchors.length > 600) anchors.removeRange(0, anchors.length - 600);
  }
  return List.unmodifiable(anchors);
}

/// Shared page-unit renderer for the screen, history compaction and PNG saves.
void paintSketch(
  Canvas canvas, {
  required Size size,
  ui.Image? base,
  required List<SketchOp> ops,
  SketchStroke? live,
  bool background = true,
}) {
  final paper = Paint()..color = const Color(sketchPaperColor);
  final page = Offset.zero & size;
  void stroke(SketchStroke stroke) {
    final points = stroke.points;
    if (points.isEmpty) return;
    final pen = Paint()
      ..color = switch (stroke.special) {
        null ||
        SketchSpecial.glitter ||
        SketchSpecial.neon => Color(stroke.color),
        SketchSpecial.rainbow => Color(sketchRainbowBands.first),
      }
      ..isAntiAlias = true
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (points.length == 1) {
      if (stroke.special == SketchSpecial.glitter) {
        paintGlitterPath(
          canvas,
          Path(),
          stroke.width,
          stroke.color,
          start: points.first,
          isDot: true,
        );
        return;
      }
      if (stroke.special == SketchSpecial.neon) {
        paintNeonPath(
          canvas,
          Path(),
          stroke.width,
          stroke.color,
          dot: points.first,
        );
        return;
      }
      canvas.drawCircle(
        points.first,
        stroke.width / 2,
        pen..style = PaintingStyle.fill,
      );
      return;
    }
    final path = sketchStrokePath(stroke);
    switch (stroke.special) {
      case null:
        canvas.drawPath(path, pen);
      case SketchSpecial.rainbow:
        paintRainbowPath(canvas, path, stroke.width);
      case SketchSpecial.glitter:
        paintGlitterPath(
          canvas,
          path,
          stroke.width,
          stroke.color,
          start: points.first,
        );
      case SketchSpecial.neon:
        paintNeonPath(canvas, path, stroke.width, stroke.color);
    }
  }

  canvas.save();
  canvas.clipRect(page);
  if (background) canvas.drawRect(page, paper);
  if (base != null) canvas.drawImage(base, Offset.zero, Paint());
  for (final op in ops) {
    switch (op) {
      case StrokeOp():
        stroke(op.stroke);
      case FillOp():
        final image = op.image;
        if (image != null) {
          canvas.drawImage(
            image,
            Offset(op.left.toDouble(), op.top.toDouble()),
            Paint(),
          );
        }
      case ClearOp():
        canvas.drawRect(page, paper);
    }
  }
  if (live != null) stroke(live);
  canvas.restore();
}

void _disposeOp(SketchOp op) {
  if (op is FillOp) {
    op.discarded = true;
    op.image?.dispose();
    op.image = null;
    op._coverage = null;
    op.twinkles = const [];
  }
}

// Display caching and autosave often request the same completed edit together.
// Each caller gets its own native image handle; the shared original is released
// as soon as all waiting callers have taken their snapshot.
class _SketchRasterSnapshot {
  _SketchRasterSnapshot(this.revision, this.size, this.image, this.onReleased);
  final int revision;
  final Size size;
  final Future<ui.Image> image;
  final VoidCallback onReleased;
  int _waiting = 0;

  Future<ui.Image> take() async {
    _waiting++;
    ui.Image? original;
    try {
      original = await image;
      return original.clone();
    } finally {
      _waiting--;
      if (_waiting == 0) {
        original?.dispose();
        onReleased();
      }
    }
  }
}

class SketchCanvasController extends ChangeNotifier {
  final SketchHistory<SketchOp> _history = SketchHistory(onDiscard: _disposeOp);
  ui.Image? _base;
  List<SketchTwinkle> _bakedTwinkles = const [];
  List<SketchTwinkle> get bakedTwinkles => _bakedTwinkles;
  List<SketchTwinkle> _visibleTwinkles = const [];
  int _twinkleRevision = -1;

  List<SketchTwinkle> get visibleTwinkles {
    if (_twinkleRevision != revision) {
      _visibleTwinkles = _foldTwinkles(_bakedTwinkles, ops);
      _twinkleRevision = revision;
    }
    return _visibleTwinkles;
  }

  Size? _baseSize;

  /// Drawable area in natural orientation. Safe to assign during layout.
  Size viewport = Size.zero;
  double _viewScale = 0;
  double get viewScale => _viewScale;

  bool get isFresh =>
      _base == null &&
      _pendingBaseOps.isEmpty &&
      !_history.canUndo &&
      !_history.canRedo &&
      _stroke == null;

  Size get pageSize => isFresh ? sketchPageSizeFor(viewport) : _sizeAfter(ops);

  Size _sizeAfter(List<SketchOp> operations) {
    for (final op in operations.reversed) {
      if (op is ClearOp) return op.size;
    }
    return _baseSize ?? sketchPageSizeFor(viewport);
  }

  void _fixFreshSize() {
    if (isFresh) _baseSize = sketchPageSizeFor(viewport);
  }

  final List<SketchOp> _pendingBaseOps = [];
  StrokeBuilder? _stroke;
  bool _merging = false, _disposed = false;
  int _pendingFills = 0;
  Future<void> _fillChain = Future<void>.value();
  int _revision = 0;
  int _contentRevision = 0;
  final _committedChanges = ChangeNotifier();
  Listenable get committedChanges => _committedChanges;
  bool get isDrawing => _stroke != null;
  SketchStroke? _liveSnapshot;

  ui.Image? _displayImage;
  int _displayRevision = -1;
  Size? _displaySize;
  bool _displayEnabled = false;
  Future<void>? _displayWork;
  _SketchRasterSnapshot? _pendingSnapshot;

  ui.Image? get displayImage =>
      _displayRevision == _contentRevision && _displaySize == pageSize
      ? _displayImage
      : null;

  /// One finished-page image, never one bitmap per Undo step. Recording a
  /// snapshot is synchronous; stale asynchronous results never replace edits.
  Future<void> prepareDisplay() {
    if (_disposed) return Future.value();
    _displayEnabled = true;
    return _displayWork ??= _cacheDisplay().whenComplete(
      () => _displayWork = null,
    );
  }

  Future<ui.Image> _committedSnapshot() {
    final size = pageSize;
    var pending = _pendingSnapshot;
    if (pending == null ||
        pending.revision != _contentRevision ||
        pending.size != size) {
      late final _SketchRasterSnapshot created;
      created = _SketchRasterSnapshot(
        _contentRevision,
        size,
        _render(size: size, base: _base, ops: ops),
        () {
          if (identical(_pendingSnapshot, created)) _pendingSnapshot = null;
        },
      );
      pending = _pendingSnapshot = created;
    }
    return pending.take();
  }

  Future<void> _cacheDisplay() async {
    try {
      while (!_disposed && _displayEnabled && displayImage == null) {
        final revision = _contentRevision;
        final size = pageSize;
        final image = await _committedSnapshot();
        if (_disposed || !_displayEnabled) {
          image.dispose();
          return;
        }
        if (revision != _contentRevision || size != pageSize) {
          image.dispose();
          continue;
        }
        _displayImage?.dispose();
        _displayImage = image;
        _displayRevision = revision;
        _displaySize = size;
        _committedChanges.notifyListeners();
      }
    } catch (error) {
      // Exact vector replay remains available if a display cache cannot allocate.
      debugPrint('Could not cache sketch display: $error');
    }
  }

  void releaseDisplay() {
    _displayEnabled = false;
    _displayImage?.dispose();
    _displayImage = null;
    _displayRevision = -1;
  }

  ui.Image? get base => _base;
  List<SketchOp> get pendingBaseOps => List.unmodifiable(_pendingBaseOps);
  List<SketchOp> get ops => [..._pendingBaseOps, ..._history.active];
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// Pending fills are informational; all drawing controls remain available.
  bool get busy => _pendingFills > 0;
  Future<void> get idle => _fillChain;
  int get revision => _revision;
  SketchStroke? get live => _liveSnapshot ??= _stroke?.build();

  bool get isBlank {
    if (_stroke != null) return false;
    var blank = _base == null;
    for (final op in ops) {
      blank = op is ClearOp;
    }
    return blank;
  }

  /// Takes ownership; an initial load starts a fresh visit-local history.
  void setBase(ui.Image? image, {List<SketchTwinkle> twinkles = const []}) {
    if (_disposed) {
      image?.dispose();
      return;
    }
    assert(!busy);
    _base?.dispose();
    _base = image;
    _bakedTwinkles = List.unmodifiable(
      twinkles.skip(math.max(0, twinkles.length - 600)),
    );
    _twinkleRevision = -1;
    _baseSize = image == null
        ? null
        : Size(image.width.toDouble(), image.height.toDouble());
    _history.clearAll();
    for (final op in _pendingBaseOps) {
      _disposeOp(op);
    }
    _pendingBaseOps.clear();
    _stroke = null;
    _revision = 0;
    _liveSnapshot = null;
    _contentRevision++;
    _committedChanges.notifyListeners();
    if (_displayEnabled) unawaited(prepareDisplay());
    notifyListeners();
  }

  void _changed({bool twinklesChanged = true}) {
    // Pointer movement does not alter committed ink or its coverage.
    if (!twinklesChanged && _twinkleRevision == _revision) _twinkleRevision++;
    _revision++;
    _liveSnapshot = null;
    if (twinklesChanged) {
      _contentRevision++;
      _committedChanges.notifyListeners();
      if (_displayEnabled) unawaited(prepareDisplay());
    }
    notifyListeners();
  }

  void beginStroke(
    Offset page, {
    required int color,
    required double width,
    SketchSpecial? special,
  }) {
    if (_disposed || _stroke != null) return;
    _fixFreshSize();
    _stroke = StrokeBuilder(
      color: color,
      width: width,
      page: pageSize,
      special: special,
    )..add(page);
    _changed(twinklesChanged: false);
  }

  void addPoint(Offset page) {
    if (_disposed) return;
    if (_stroke?.add(page) ?? false) _changed(twinklesChanged: false);
  }

  void endStroke() {
    if (_disposed || _stroke == null) return;
    final stroke = _stroke!.build();
    _stroke = null;
    if (stroke.points.isNotEmpty) _push(StrokeOp(stroke));
  }

  void cancelStroke() {
    if (_disposed || _stroke == null) return;
    _stroke = null;
    _changed(twinklesChanged: false);
  }

  void _push(SketchOp op) {
    _pendingBaseOps.addAll(_history.push(op));
    if (_pendingBaseOps.isNotEmpty && !_merging) {
      _merging = true;
      unawaited(_mergeBase());
    }
    _changed();
  }

  Future<void> _mergeBase() async {
    try {
      // Ops evicted while this merge rasterizes stay pending for the next one.
      while (_pendingBaseOps.isNotEmpty) {
        // A fill captures these operation objects. Keep their images alive
        // until every fill using them has recorded its source picture.
        await _waitForFills();
        if (_disposed || _pendingBaseOps.isEmpty) return;
        final merged = _pendingBaseOps.length;
        assert(!_pendingBaseOps.any((op) => op is FillOp && op.image == null));
        final size = _sizeAfter(_pendingBaseOps);
        final image = await _render(
          size: size,
          base: _base,
          ops: _pendingBaseOps,
        );
        // More fills may have arrived while this picture rasterized.
        await _waitForFills();
        if (_disposed) {
          image.dispose();
          return;
        }
        _bakedTwinkles = _foldTwinkles(
          _bakedTwinkles,
          _pendingBaseOps.take(merged),
        );
        final old = _base;
        _base = image;
        _baseSize = size;
        old?.dispose();
        for (final op in _pendingBaseOps.take(merged)) {
          _disposeOp(op);
        }
        _pendingBaseOps.removeRange(0, merged);
        notifyListeners();
      }
    } catch (error) {
      // Retain the pending ops if rasterization fails. They still paint in
      // order, and a later eviction can retry compaction without losing ink.
      debugPrint('Could not compact sketch history: $error');
    } finally {
      if (!_disposed) {
        _merging = false;
        notifyListeners();
      }
    }
  }

  Future<ui.Image> _render({
    required Size size,
    ui.Image? base,
    required List<SketchOp> ops,
    SketchStroke? live,
  }) async {
    final recorder = ui.PictureRecorder();
    paintSketch(Canvas(recorder), size: size, base: base, ops: ops, live: live);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(size.width.toInt(), size.height.toInt());
    } finally {
      picture.dispose();
    }
  }

  /// Returns a new image owned by the caller; recording is synchronous so
  /// later edits and disposal cannot change this snapshot.
  Future<ui.Image> flatten() {
    final cached = displayImage;
    if (!isDrawing) {
      if (cached != null) return Future.value(cached.clone());
      return _committedSnapshot();
    }
    return _render(size: pageSize, base: _base, ops: ops, live: live);
  }

  /// Rotates a synchronous snapshot clockwise. Caller owns the result.
  Future<ui.Image> flattenRotated(int quarterTurns) async {
    final image = await flatten();
    final turns = quarterTurns % 4;
    if (turns == 0) return image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = turns.isOdd ? image.height : image.width;
    final height = turns.isOdd ? image.width : image.height;
    switch (turns) {
      case 1:
        canvas.translate(width.toDouble(), 0);
      case 2:
        canvas.translate(width.toDouble(), height.toDouble());
      case 3:
        canvas.translate(0, height.toDouble());
    }
    canvas.rotate(turns * math.pi / 2);
    canvas.drawImage(image, Offset.zero, Paint());
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
      image.dispose();
    }
  }

  Future<void> _waitForFills() async {
    while (busy) {
      await _fillChain;
    }
  }

  /// Reserve the history position now; queued work never blocks later input.
  Future<bool> fill(
    Offset page,
    SketchInk ink, {
    int color = sketchDefaultColor,
  }) {
    if (_disposed) return Future<bool>.value(false);
    endStroke();
    _fixFreshSize();
    final size = pageSize;
    final preceding = ops;
    // Compaction can replace the base while this fill waits in the queue.
    final base = _base?.clone();
    final op = FillOp();
    _pendingFills++;
    final result = _fillChain.then(
      (_) => _computeFill(op, base, preceding, size, page, ink, color),
    );
    // Errors still reach the caller, but cannot break subsequent queued fills.
    _fillChain = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _push(op);
    return result;
  }

  void _removeFill(FillOp op) {
    if (!_history.remove(op) && _pendingBaseOps.remove(op)) _disposeOp(op);
  }

  Future<bool> _computeFill(
    FillOp op,
    ui.Image? base,
    List<SketchOp> preceding,
    Size size,
    Offset page,
    SketchInk ink,
    int color,
  ) async {
    ui.Image? snapshot;
    ui.Image? mask;
    try {
      if (_disposed || op.discarded) return false;
      snapshot = await _render(size: size, base: base, ops: preceding);
      if (_disposed || op.discarded) return false;
      final bytes = await snapshot.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (bytes == null) throw StateError('Could not read drawing pixels');
      final rgba = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      final width = size.width.toInt();
      final height = size.height.toInt();
      final x = page.dx.floor().clamp(0, width - 1);
      final y = page.dy.floor().clamp(0, height - 1);
      final result = await switch (ink) {
        SolidInk(:final argb) => floodFillInBackground(
          rgba,
          width,
          height,
          x,
          y,
          argb,
        ),
        SpecialInk(:final kind) => switch (kind) {
          SketchSpecial.rainbow => rainbowFloodFillInBackground(
            rgba,
            width,
            height,
            x,
            y,
          ),
          SketchSpecial.glitter => glitterFloodFillInBackground(
            rgba,
            width,
            height,
            x,
            y,
            color,
          ),
          SketchSpecial.neon => neonFloodFillInBackground(
            rgba,
            width,
            height,
            x,
            y,
            color,
          ),
        },
      };
      if (_disposed || op.discarded) return false;
      if (result == null) {
        _removeFill(op);
        return false;
      }
      final decoded = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        result.rgba,
        result.width,
        result.height,
        ui.PixelFormat.rgba8888,
        decoded.complete,
      );
      mask = await decoded.future;
      if (_disposed || op.discarded) return false;
      op._setCoverage(result);
      op.twinkles = result.twinkles;
      op.image = mask;
      op.left = result.left;
      op.top = result.top;
      mask = null;
      return true;
    } catch (_) {
      if (!_disposed) _removeFill(op);
      rethrow;
    } finally {
      base?.dispose();
      snapshot?.dispose();
      mask?.dispose();
      _pendingFills--;
      if (!_disposed) _changed();
    }
  }

  void undo() {
    if (_disposed || _stroke != null || !_history.canUndo) return;
    _history.undo();
    _changed();
  }

  void redo() {
    if (_disposed || _stroke != null || !_history.canRedo) return;
    _history.redo();
    _changed();
  }

  void clear() {
    if (_disposed || _stroke != null) return;
    _fixFreshSize();
    _push(ClearOp(sketchPageSizeFor(viewport)));
  }

  @override
  void dispose() {
    _disposed = true;
    releaseDisplay();
    _committedChanges.dispose();
    _base?.dispose();
    _history.clearAll();
    for (final op in _pendingBaseOps) {
      _disposeOp(op);
    }
    _pendingBaseOps.clear();
    super.dispose();
  }
}

bool sketchSegmentEntersPage(Offset from, Offset to, Rect rect) {
  var enter = 0.0, leave = 1.0;
  final delta = to - from;
  bool clip(double direction, double distance) {
    if (direction == 0) return distance >= 0;
    final t = distance / direction;
    if (direction < 0) {
      if (t > leave) return false;
      enter = math.max(enter, t);
    } else {
      if (t < enter) return false;
      leave = math.min(leave, t);
    }
    return true;
  }

  return clip(-delta.dx, from.dx - rect.left) &&
      clip(delta.dx, rect.right - from.dx) &&
      clip(-delta.dy, from.dy - rect.top) &&
      clip(delta.dy, rect.bottom - from.dy);
}

class SketchCanvas extends StatefulWidget {
  const SketchCanvas({
    super.key = const ValueKey('sketch-canvas'),
    required this.controller,
    required this.color,
    required this.width,
    required this.tool,
    required this.enabled,
    this.onFill,
    this.special,
    this.quarterTurns = 0,
    this.padding = EdgeInsets.zero,
  });
  final SketchCanvasController controller;
  final int color;
  final SketchSpecial? special;
  final double width;
  final SketchTool tool;
  final bool enabled;
  final ValueChanged<Offset>? onFill;
  final int quarterTurns;
  final EdgeInsets padding;

  static Rect pageRect(Size area, Size page) {
    final scale = math.max(
      0.0,
      math.min(area.width / page.width, area.height / page.height),
    );
    return Rect.fromCenter(
      center: area.center(Offset.zero),
      width: page.width * scale,
      height: page.height * scale,
    );
  }

  @override
  State<SketchCanvas> createState() => _SketchCanvasState();
}

class _SketchCanvasState extends State<SketchCanvas>
    with SingleTickerProviderStateMixin {
  final _twinkleClock = _TwinkleClock();
  late final Ticker _ticker;
  bool _motionAllowed = false;
  int? _pointer;
  Offset? _down;
  Offset? _previous;
  bool _moved = false;
  Size? _size;
  Size? _page;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_twinkleClock.tick);
    widget.controller.addListener(_controllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed =
        !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
    _syncTwinkles();
  }

  void _syncTwinkles() {
    final active =
        _motionAllowed && widget.controller.visibleTwinkles.isNotEmpty;
    _twinkleClock.setActive(active);
    final running = active && !widget.controller.isDrawing;
    if (running && !_ticker.isActive) {
      _twinkleClock.resume();
      _ticker.start();
    }
    if (!running && _ticker.isActive) _ticker.stop();
  }

  // Pointer moves only repaint; rebuild the layout when the page reshapes
  // (a resizing Clear, or undoing one).
  void _controllerChanged() {
    _syncTwinkles();
    if (_page != null && widget.controller.pageSize != _page) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    widget.controller.releaseDisplay();
    _ticker.dispose();
    _twinkleClock.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SketchCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerChanged);
      oldWidget.controller.releaseDisplay();
      widget.controller.addListener(_controllerChanged);
    }
    if (!widget.enabled ||
        oldWidget.tool != widget.tool ||
        oldWidget.quarterTurns != widget.quarterTurns ||
        oldWidget.padding != widget.padding ||
        oldWidget.controller != widget.controller) {
      _pointer = null;
      oldWidget.controller.cancelStroke();
    }
    _syncTwinkles();
  }

  void _begin(Offset point) {
    widget.controller.beginStroke(
      point,
      color: widget.tool == SketchTool.eraser ? sketchPaperColor : widget.color,
      width: widget.width,
      special: widget.tool == SketchTool.brush ? widget.special : null,
    );
  }

  void _move(Offset point, Rect rect, Offset Function(Offset) toPage) {
    final previous = _previous!;
    if (!widget.controller.isDrawing &&
        sketchSegmentEntersPage(previous, point, rect)) {
      _begin(toPage(previous));
    }
    if (widget.controller.isDrawing) widget.controller.addPoint(toPage(point));
    _previous = point;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Drawing page',
    image: true,
    child: SizedBox.expand(
      child: RotatedBox(
        quarterTurns: widget.quarterTurns,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (_size != null && size != _size) {
              _pointer = null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) widget.controller.cancelStroke();
              });
            }
            _size = size;
            // Padding is supplied in upright screen coordinates; rotate it
            // with the input surface into the paper's natural orientation.
            var padding = widget.padding;
            for (var i = 0; i < widget.quarterTurns % 4; i++) {
              padding = EdgeInsets.fromLTRB(
                padding.top,
                padding.right,
                padding.bottom,
                padding.left,
              );
            }
            final area = Size(
              size.width - padding.horizontal,
              size.height - padding.vertical,
            );
            widget.controller.viewport = area;
            final pageSize = _page = widget.controller.pageSize;
            final rect = SketchCanvas.pageRect(
              area,
              pageSize,
            ).shift(Offset(padding.left, padding.top));
            unawaited(widget.controller.prepareDisplay());
            final scale = rect.width / pageSize.width;
            widget.controller._viewScale = scale;
            Offset page(Offset point) => (point - rect.topLeft) / scale;
            return RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: widget.enabled
                  ? {
                      EagerGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            EagerGestureRecognizer
                          >(EagerGestureRecognizer.new, (_) {}),
                    }
                  : const {},
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (!widget.enabled || _pointer != null) return;
                  if (widget.tool == SketchTool.fill &&
                      !rect.contains(event.localPosition)) {
                    return;
                  }
                  _pointer = event.pointer;
                  _down = _previous = event.localPosition;
                  _moved = false;
                  if (widget.tool != SketchTool.fill &&
                      rect.contains(event.localPosition)) {
                    _begin(page(event.localPosition));
                  }
                },
                onPointerMove: (event) {
                  if (!widget.enabled || event.pointer != _pointer) return;
                  if ((event.localPosition - _down!).distance > kTouchSlop) {
                    _moved = true;
                  }
                  if (widget.tool != SketchTool.fill) {
                    _move(event.localPosition, rect, page);
                  }
                },
                onPointerUp: (event) {
                  if (event.pointer != _pointer) return;
                  _pointer = null;
                  if (!widget.enabled) return;
                  if (widget.tool == SketchTool.fill) {
                    if (!_moved &&
                        (event.localPosition - _down!).distance <= kTouchSlop &&
                        rect.contains(event.localPosition)) {
                      widget.onFill?.call(page(event.localPosition));
                    }
                  } else {
                    _move(event.localPosition, rect, page);
                    widget.controller.endStroke();
                  }
                },
                onPointerCancel: (event) {
                  if (event.pointer != _pointer) return;
                  _pointer = null;
                  widget.controller.cancelStroke();
                },
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: rect,
                      child: RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CustomPaint(
                            painter: _SketchPainter(widget.controller),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          key: const ValueKey('sketch-live'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: CustomPaint(
                              painter: _LiveSketchPainter(widget.controller),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          key: const ValueKey('sketch-twinkles'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: CustomPaint(
                              painter: _TwinklePainter(
                                widget.controller,
                                _twinkleClock,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: GardenColors.of(context).outline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.controller) : super(repaint: controller.committedChanges);
  final SketchCanvasController controller;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final pageSize = controller.pageSize;
    canvas.scale(size.width / pageSize.width);
    final cached = controller.displayImage;
    if (cached != null) {
      canvas.drawImage(cached, Offset.zero, Paint());
    } else {
      paintSketch(
        canvas,
        size: pageSize,
        base: controller.base,
        ops: controller.ops,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SketchPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

class _LiveSketchPainter extends CustomPainter {
  _LiveSketchPainter(this.controller) : super(repaint: controller);
  final SketchCanvasController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final live = controller.live;
    if (live == null) return;
    final page = controller.pageSize;
    canvas.save();
    canvas.scale(size.width / page.width);
    paintSketch(
      canvas,
      size: page,
      ops: const [],
      live: live,
      background: false,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiveSketchPainter old) => old.controller != controller;
}

/// Only this clock listens to frame ticks. The raster page listens exclusively
/// to drawing changes and is isolated in its own repaint boundary.
class _TwinkleClock extends ChangeNotifier {
  double seconds = 0;
  bool active = false;
  double _startedAt = 0;
  void resume() => _startedAt = seconds;
  void tick(Duration elapsed) {
    seconds =
        _startedAt + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    notifyListeners();
  }

  void setActive(bool value) {
    if (active == value) return;
    active = value;
    notifyListeners();
  }
}

class _TwinklePainter extends CustomPainter {
  _TwinklePainter(this.controller, this.clock)
    : super(repaint: Listenable.merge([controller.committedChanges, clock]));
  final SketchCanvasController controller;
  final _TwinkleClock clock;

  @override
  void paint(Canvas canvas, Size size) {
    if (!clock.active) return;
    canvas.save();
    final pageSize = controller.pageSize;
    canvas.scale(size.width / pageSize.width);
    canvas.clipRect(Offset.zero & pageSize);
    final white = Paint();
    final glow = Paint();
    for (final anchor in controller.visibleTwinkles) {
      final phase = anchor.phase & 0xFFFFFFFF;
      final period = 2.4 + (phase % 1601) / 1000;
      final local = (clock.seconds + ((phase >>> 11) % 4000) / 1000) % period;
      if (local >= .6) continue;
      final alpha = math.pow(math.sin(math.pi * local / .6), 2).toDouble();
      // Full anchor size: half-size stars were barely visible on a phone.
      final extent = anchor.size * (.75 + alpha * .25);
      final center = Offset(anchor.x, anchor.y);
      canvas.drawCircle(
        center,
        extent * .9,
        glow
          ..color = const Color(0xFFFFD54F).withValues(alpha: alpha * .8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, extent * .65),
      );
      final star = Path()
        ..moveTo(center.dx, center.dy - extent)
        ..lineTo(center.dx + extent * .22, center.dy - extent * .22)
        ..lineTo(center.dx + extent, center.dy)
        ..lineTo(center.dx + extent * .22, center.dy + extent * .22)
        ..lineTo(center.dx, center.dy + extent)
        ..lineTo(center.dx - extent * .22, center.dy + extent * .22)
        ..lineTo(center.dx - extent, center.dy)
        ..lineTo(center.dx - extent * .22, center.dy - extent * .22)
        ..close();
      canvas.drawPath(
        star,
        white..color = Colors.white.withValues(alpha: alpha),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TwinklePainter oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.clock != clock;
}
