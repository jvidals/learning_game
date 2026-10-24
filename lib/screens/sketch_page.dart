import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../device_services.dart';
import '../progress_controller.dart';
import '../sketch.dart';
import '../sketch_ink.dart';
import '../sketch_store.dart';
import '../widgets/brush_size_sheet.dart';
import '../widgets/color_wheel.dart';
import '../widgets/special_swatch.dart';
import '../widgets/sketch_canvas.dart';
import '../widgets/sketch_popover.dart';

/// Hardware cutout clearance in the view's current logical coordinates.
///
/// Assigns each cutout to its nearest edge (all tied edges at a corner), using
/// its far side as the clearance so inset punch holes are covered too.
EdgeInsets sketchCutoutInsets(Size size, List<ui.DisplayFeature> features) {
  var left = 0.0, top = 0.0, right = 0.0, bottom = 0.0;
  final screen = Offset.zero & size;
  for (final feature in features) {
    if (feature.type != ui.DisplayFeatureType.cutout) continue;
    final rect = feature.bounds.intersect(screen);
    if (rect.isEmpty) continue;
    final fromRight = size.width - rect.right;
    final fromBottom = size.height - rect.bottom;
    final nearest = math.min(
      math.min(rect.left, rect.top),
      math.min(fromRight, fromBottom),
    );
    if (rect.left == nearest) left = math.max(left, rect.right);
    if (rect.top == nearest) top = math.max(top, rect.bottom);
    if (fromRight == nearest) right = math.max(right, size.width - rect.left);
    if (fromBottom == nearest) {
      bottom = math.max(bottom, size.height - rect.top);
    }
  }
  return EdgeInsets.fromLTRB(left, top, right, bottom);
}

class SketchPage extends StatefulWidget {
  const SketchPage({
    super.key,
    required this.controller,
    required this.services,
    this.store,
  });
  final ProgressController controller;
  final DeviceServices services;
  final SketchStore? store;

  @override
  State<SketchPage> createState() => _SketchPageState();
}

enum _LoadState { loading, ready, failed, unreadable }

class _SketchPageState extends State<SketchPage> with WidgetsBindingObserver {
  final _canvas = SketchCanvasController();
  final _inputAreaKey = GlobalKey();
  Rect? _gestureBounds;
  bool _foreground = true;
  bool _gestureUpdateScheduled = false;
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_routeStatusChanged);
      _routeAnimation = animation;
      animation?.addStatusListener(_routeStatusChanged);
    }
    _updateGestureBounds();
  }

  void _routeStatusChanged(AnimationStatus status) => _updateGestureBounds();

  void _updateGestureBounds() {
    if (_gestureUpdateScheduled) return;
    _gestureUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gestureUpdateScheduled = false;
      if (!mounted) return;
      Rect? bounds;
      final box = _inputAreaKey.currentContext?.findRenderObject();
      if (_enabled &&
          _foreground &&
          (_routeAnimation == null ||
              _routeAnimation!.status == AnimationStatus.completed) &&
          box is RenderBox &&
          box.hasSize) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final origin = box.localToGlobal(Offset.zero);
        bounds = Rect.fromLTWH(
          origin.dx * ratio,
          origin.dy * ratio,
          box.size.width * ratio,
          box.size.height * ratio,
        );
      }
      if (bounds == _gestureBounds) return;
      _gestureBounds = bounds;
      unawaited(
        widget.services
            .setSketchGestureExclusion(bounds)
            .catchError((Object _) {}),
      );
    });
  }

  void _clearGestureBounds() {
    _gestureBounds = null;
    unawaited(
      widget.services.setSketchGestureExclusion(null).catchError((Object _) {}),
    );
  }

  final _toolAnchor = GlobalKey();
  final _colorAnchor = GlobalKey();
  final _sizeAnchor = GlobalKey();
  SolidInk? _previewInk;
  SketchColorTab? _colorTab;

  SketchTool get _drawingTool =>
      _previewInk != null && _settings.tool == SketchTool.eraser
      ? SketchTool.brush
      : _settings.tool;
  int get _drawingColor => _previewInk?.argb ?? _settings.color;
  SketchSpecial? get _drawingSpecial =>
      _previewInk == null || _settings.special?.isEffect == true
      ? _settings.special
      : null;
  late final SketchStore _store;
  late final String? _playerId;
  SketchSettings _settings = const SketchSettings();
  _LoadState _loadState = _LoadState.loading;
  bool _gallerySupported = false, _saving = false, _sheet = false;
  bool _renderFailed = false;
  int _seenRevision = 0;
  int? _galleryRevision;
  bool _galleryFailed = false, _alreadySaved = false;
  int _rotation = 0;
  StreamSubscription<int>? _rotationSubscription;
  Future<void>? _autosave;
  bool _dirty = false;
  (bool, bool)? _controls;

  bool get _ready => _loadState == _LoadState.ready;
  bool get _enabled => _ready && !_saving && !_sheet;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SketchStore(widget.services);
    _playerId = widget.controller.activeProfile?.id;
    WidgetsBinding.instance.addObserver(this);
    _canvas.addListener(_canvasChanged);
    _store.failed.addListener(_saveStateChanged);
    _setWindow(true);
    unawaited(_queryRotation());
    _rotationSubscription = widget.services.displayRotationChanges.listen(
      _rotationChanged,
      onError: (Object _) {},
    );
    unawaited(_checkGallery());
    unawaited(_load());
  }

  void _setWindow(bool active) {
    if (!active) _clearGestureBounds();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        active ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ).catchError((Object _) {}),
    );
    unawaited(
      widget.services.setSketchWindow(active).catchError((Object _) {}),
    );
  }

  void _rotationChanged(int rotation) {
    if (mounted && rotation >= 0 && rotation <= 3 && rotation != _rotation) {
      setState(() => _rotation = rotation);
    }
  }

  Future<void> _queryRotation() async {
    try {
      _rotationChanged(await widget.services.displayRotation());
    } catch (_) {
      // Keep the last known rotation if the platform is temporarily unavailable.
    }
  }

  @override
  void didChangeMetrics() => unawaited(_queryRotation());

  Future<void> _checkGallery() async {
    try {
      final supported = await widget.services.canSaveToGallery();
      if (mounted) setState(() => _gallerySupported = supported);
    } catch (_) {
      // An unavailable platform capability simply omits this action.
    }
  }

  Future<void> _load() async {
    setState(() => _loadState = _LoadState.loading);
    final id = _playerId;
    if (id == null) {
      setState(() => _loadState = _LoadState.failed);
      return;
    }
    try {
      final snapshot = await _store.load(id);
      if (!mounted) return;
      try {
        _settings = snapshot.settings == null
            ? const SketchSettings()
            : SketchSettings.decode(snapshot.settings!);
      } on FormatException {
        _settings = const SketchSettings();
      }
      _settings = _settings.copyWith(tool: SketchTool.brush);
      ui.Image? image;
      if (snapshot.png != null) {
        ui.Codec? codec;
        try {
          codec = await ui.instantiateImageCodec(snapshot.png!);
          image = (await codec.getNextFrame()).image;
          if (!isValidSketchPageSize(image.width, image.height)) {
            image.dispose();
            image = null;
            throw const FormatException('Unexpected drawing dimensions');
          }
          final rgba = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (rgba == null) throw const FormatException('Unreadable drawing');
          // At most 2560² pixels: scan once, without allocating per-pixel objects.
          final bytes = rgba.buffer.asUint8List(
            rgba.offsetInBytes,
            rgba.lengthInBytes,
          );
          if (bytes.every((byte) => byte == 255)) {
            image.dispose();
            image = null;
          }
        } catch (_) {
          image?.dispose();
          if (mounted) setState(() => _loadState = _LoadState.unreadable);
          return;
        } finally {
          codec?.dispose();
        }
      }
      if (!mounted) {
        image?.dispose();
        return;
      }
      _canvas.setBase(image, twinkles: _settings.twinkles);
      _seenRevision = _canvas.revision;
      setState(() => _loadState = _LoadState.ready);
    } catch (_) {
      if (mounted) setState(() => _loadState = _LoadState.failed);
    }
  }

  void _saveStateChanged() {
    if (mounted) setState(() {});
  }

  void _canvasChanged() {
    if (!_ready) return;
    if (_canvas.revision != _seenRevision) {
      _seenRevision = _canvas.revision;
      if (mounted && (_galleryRevision != null || _galleryFailed)) {
        setState(() {
          _galleryRevision = null;
          _galleryFailed = false;
          _alreadySaved = false;
        });
      }
      _queueSave();
    }
    // Pointer moves change only the painter; rebuild for button state changes.
    final controls = (_canvas.canUndo, _canvas.canRedo);
    if (controls != _controls && mounted) setState(() => _controls = controls);
  }

  void _queueSave() {
    _dirty = true;
    _autosave ??= _saveDrawing().whenComplete(() => _autosave = null);
  }

  Future<void> _saveDrawing() async {
    final id = _playerId;
    if (!_ready || id == null) return;
    try {
      // flatten() records synchronously, so each image is an exact snapshot.
      // An unfinished stroke waits: ending or cancelling it queues a save.
      while (_dirty && !_canvas.isDrawing) {
        _dirty = false;
        final snapshot = _canvas.flatten();
        final twinkles = _canvas.visibleTwinkles;
        final image = await snapshot;
        _settings = _settings.copyWith(twinkles: twinkles);
        _store.update(id, page: image, settings: _settings.encode());
        if (mounted && _renderFailed) setState(() => _renderFailed = false);
      }
    } catch (_) {
      if (mounted) setState(() => _renderFailed = true);
    }
  }

  void _settingsChanged(SketchSettings settings) {
    if (!_ready) return;
    setState(() => _settings = settings);
    _store.update(_playerId!, settings: settings.encode());
    // The store holds a settings-only edit until it has a PNG. On a brand-new
    // page, persist white paper too so the very first tool/color choice saves.
    if (_canvas.isBlank) _queueSave();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _setWindow(true);
      _updateGestureBounds();
    } else {
      _clearGestureBounds();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _canvas.cancelStroke();
      unawaited(_flush());
    }
  }

  Future<void> _flush() async {
    await _canvas.idle;
    await _autosave;
    await _store.flush();
  }

  Future<void> _closeStore() async {
    try {
      await _canvas.idle;
      // The listener is removed on navigation; capture completed pending fills.
      if (_ready && _canvas.revision != _seenRevision) _queueSave();
      await _autosave;
      await _store.close();
    } finally {
      _canvas.dispose();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_routeStatusChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_rotationSubscription?.cancel());
    _setWindow(false);
    _canvas.removeListener(_canvasChanged);
    _store.failed.removeListener(_saveStateChanged);
    _canvas.cancelStroke();
    if (_ready && _canvas.revision != _seenRevision) _queueSave();
    unawaited(_closeStore());
    super.dispose();
  }

  String _toolName(SketchTool tool) => switch (tool) {
    SketchTool.brush => 'Brush',
    SketchTool.eraser => 'Eraser',
    SketchTool.fill => 'Fill',
  };

  IconData _toolIcon(SketchTool tool) => switch (tool) {
    SketchTool.brush => Icons.brush_rounded,
    SketchTool.eraser => Icons.auto_fix_normal_rounded,
    SketchTool.fill => Icons.format_color_fill_rounded,
  };

  ButtonStyle _selectionStyle(bool selected) => OutlinedButton.styleFrom(
    backgroundColor: selected ? GardenColors.of(context).selectedSurface : null,
    side: selected
        ? BorderSide(color: GardenColors.of(context).primary, width: 2)
        : null,
  );

  void _beginSheet() {
    _canvas.cancelStroke();
    setState(() => _sheet = true);
  }

  Future<void> _pickTool() async {
    _beginSheet();
    final selected = await showSketchPopover<SketchTool>(
      context,
      anchor: _toolAnchor,
      semanticLabel: 'Choose a tool',
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final vertical = size.width > size.height;
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tool in SketchTool.values)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: MergeSemantics(
                    child: Semantics(
                      selected: _settings.tool == tool,
                      child: Tooltip(
                        message: _toolName(tool),
                        child: SizedBox.square(
                          dimension: 64,
                          child: OutlinedButton(
                            key: ValueKey('sketch-tool-${tool.name}'),
                            style: _selectionStyle(_settings.tool == tool)
                                .copyWith(
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.zero,
                                  ),
                                ),
                            onPressed: () => Navigator.pop(context, tool),
                            child: Icon(_toolIcon(tool), size: 32),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() => _sheet = false);
    if (selected != null) _settingsChanged(_settings.copyWith(tool: selected));
  }

  Future<void> _pickColor() async {
    _beginSheet();
    final selected = await showSketchInkPopover(
      context,
      anchor: _colorAnchor,
      onPreview: (ink) {
        if (mounted) setState(() => _previewInk = ink);
      },
      current: _settings.ink,
      base: Color(_settings.color),
      initialTab: _colorTab ??= _settings.special == null
          ? SketchColorTab.crayons
          : SketchColorTab.special,
      onTabChanged: (tab) => _colorTab = tab,
      presets: [
        for (final preset in sketchPresetColors)
          (color: Color(preset.color), name: preset.name),
      ],
      recent: _settings.recentColors.map(Color.new).toList(),
    );
    if (!mounted) return;
    setState(() {
      _sheet = false;
      _previewInk = null;
    });
    if (selected != null) {
      _settingsChanged(
        (switch (selected) {
          PickSolid(:final argb) => _settings.applyColor(argb),
          PickSpecial(:final kind) =>
            kind.isEffect && _settings.special == kind
                ? _settings.clearSpecial()
                : _settings.applySpecial(kind),
          PickPlain() => _settings.clearSpecial(),
        }).copyWith(
          tool: _settings.tool == SketchTool.eraser
              ? SketchTool.brush
              : _settings.tool,
        ),
      );
    }
  }

  Future<void> _pickSize() async {
    _beginSheet();
    await showBrushSizePopover(
      context,
      anchor: _sizeAnchor,
      size: _settings.size,
      min: sketchMinBrush,
      max: sketchMaxBrush,
      previewScale: _canvas.viewScale,
      color: Color(
        _settings.tool == SketchTool.eraser
            ? sketchPaperColor
            : _settings.color,
      ),
      special: _settings.tool == SketchTool.eraser ? null : _settings.special,
      onChanged: (value) {
        if (mounted) _settingsChanged(_settings.copyWith(size: value));
      },
    );
    if (mounted) setState(() => _sheet = false);
  }

  Future<void> _clear() async {
    _beginSheet();
    final unsaved = !_canvas.isBlank && _galleryRevision != _canvas.revision;
    final clear =
        !unsaved ||
        (await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Icon(
                  Icons.delete_outline_rounded,
                  size: 48,
                  semanticLabel: 'Clear the whole page?',
                ),
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actions: [
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    tooltip: 'Keep drawing',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, size: 32),
                  ),
                  IconButton.filled(
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    tooltip: 'Clear page',
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete_rounded, size: 32),
                  ),
                ],
              ),
            ) ??
            false);
    if (!mounted) return;
    setState(() => _sheet = false);
    if (clear) {
      _canvas.clear();
      if (_settings.photoUri != null) {
        _settingsChanged(_settings.copyWith(clearPhotoUri: true));
      }
    }
  }

  Future<void> _startNew() async {
    final start =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Icon(
              Icons.note_add_rounded,
              size: 48,
              semanticLabel: 'Start a new page?',
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              IconButton(
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                tooltip: 'Keep it',
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded, size: 32),
              ),
              IconButton.filled(
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                tooltip: 'Start new',
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.note_add_rounded, size: 32),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !start) return;
    _canvas.setBase(null);
    _seenRevision = _canvas.revision;
    setState(() => _loadState = _LoadState.ready);
    if (_settings.photoUri != null) {
      _settingsChanged(_settings.copyWith(clearPhotoUri: true));
    }
    _queueSave();
  }

  Future<void> _fill(Offset point) async {
    try {
      final changed = await _canvas.fill(
        point,
        _settings.ink,
        color: _drawingColor,
      );
      if (changed && mounted) {
        await requestFeedback(
          widget.services,
          DeviceFeedback.light,
          enabled: widget.controller.settings.haptics,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _renderFailed = true);
    }
  }

  Future<void> _saveGallery() async {
    if (!_enabled) return;
    _canvas.cancelStroke();
    if (_galleryRevision == _canvas.revision) {
      setState(() => _alreadySaved = true);
      return;
    }
    setState(() => _saving = true);
    ui.Image? image;
    try {
      await _canvas.idle;
      final revision = _canvas.revision;
      image = await _canvas.flattenRotated((4 - _rotation) % 4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode drawing');
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final stamp =
          '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
      final uri = await widget.services.saveToGallery(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        'Learning Corner sketch $stamp.png',
        replaceUri: _settings.photoUri,
      );
      if (mounted) {
        if (uri != _settings.photoUri) {
          _settingsChanged(_settings.copyWith(photoUri: uri));
        }
        setState(() {
          _galleryRevision = revision;
          _galleryFailed = false;
          _alreadySaved = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _galleryFailed = true);
    } finally {
      image?.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _setWindow(false);
    },
    child: Semantics(
      label: 'Sketch Pad',
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: GardenColors.of(context).background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            _updateGestureBounds();
            final portrait = constraints.maxHeight >= constraints.maxWidth;
            // System/caption bars overlay this immersive page; only hardware
            // cutouts should change its geometry when the device turns.
            final cutouts = sketchCutoutInsets(
              constraints.biggest,
              MediaQuery.displayFeaturesOf(context),
            );
            final shortInset = portrait
                ? math.max(cutouts.top, cutouts.bottom)
                : math.max(cutouts.left, cutouts.right);
            final longInset =
                8.0 +
                (portrait
                    ? math.max(cutouts.left, cutouts.right)
                    : math.max(cutouts.top, cutouts.bottom));
            Widget strip(Widget child, {required bool first}) => SizedBox(
              key: ValueKey(first ? 'sketch-strip-a' : 'sketch-strip-b'),
              height: portrait ? 72 + shortInset : null,
              width: portrait ? null : 72 + shortInset,
              child: Padding(
                padding: portrait
                    ? EdgeInsets.only(
                        top: first ? shortInset : 0,
                        bottom: first ? 0 : shortInset,
                        left: longInset,
                        right: longInset,
                      )
                    : EdgeInsets.only(
                        left: first ? shortInset : 0,
                        right: first ? 0 : shortInset,
                        top: longInset,
                        bottom: longInset,
                      ),
                child: child,
              ),
            );
            // Add a short run-in through blank strip space without changing
            // the paper's viewport. Strips paint/hit-test above this surface,
            // so buttons keep their full touch targets and own their gestures.
            const runIn = 16.0;
            final stripExtent = 72 + shortInset;
            final padding = portrait
                ? EdgeInsets.symmetric(
                    horizontal: longInset,
                    vertical: 8 + runIn,
                  )
                : EdgeInsets.symmetric(
                    horizontal: 8 + runIn,
                    vertical: longInset,
                  );
            final page = SizedBox.expand(
              key: _inputAreaKey,
              child: _ready
                  ? SketchCanvas(
                      controller: _canvas,
                      padding: padding,
                      quarterTurns: (4 - _rotation) % 4,
                      color: _drawingColor,
                      special: _drawingSpecial,
                      width: _settings.size,
                      tool: _drawingTool,
                      enabled: _enabled,
                      onFill: (point) => unawaited(_fill(point)),
                    )
                  : Padding(padding: padding, child: _loadBody()),
            );
            return Stack(
              children: [
                Positioned(
                  left: portrait ? 0 : stripExtent - runIn,
                  right: portrait ? 0 : stripExtent - runIn,
                  top: portrait ? stripExtent - runIn : 0,
                  bottom: portrait ? stripExtent - runIn : 0,
                  child: page,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  right: portrait ? 0 : null,
                  bottom: portrait ? null : 0,
                  child: strip(_pickers(vertical: !portrait), first: true),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  left: portrait ? 0 : null,
                  top: portrait ? null : 0,
                  child: strip(_actions(vertical: !portrait), first: false),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  // Like the AppBar it replaces: Back at the start, pickers grouped at the end.
  Widget _pickers({required bool vertical}) => Flex(
    direction: vertical ? Axis.vertical : Axis.horizontal,
    children: [
      IconButton(
        color: GardenColors.of(context).foreground,
        key: const ValueKey('sketch-back'),
        tooltip: 'Back to Art Hub',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      const Spacer(),
      MergeSemantics(
        child: Semantics(
          label: 'Choose a tool',
          value: _toolName(_drawingTool),
          child: KeyedSubtree(
            key: _toolAnchor,
            child: IconButton(
              color: GardenColors.of(context).foreground,
              key: const ValueKey('sketch-tool'),
              tooltip: 'Choose a tool',
              icon: Icon(_toolIcon(_drawingTool)),
              onPressed: _enabled ? _pickTool : null,
            ),
          ),
        ),
      ),
      SizedBox(width: vertical ? 0 : 8, height: vertical ? 8 : 0),
      KeyedSubtree(
        key: _colorAnchor,
        child: IconButton(
          color: GardenColors.of(context).foreground,
          key: const ValueKey('sketch-color'),
          tooltip: 'Choose a color',
          icon: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _drawingSpecial == null ? Color(_drawingColor) : null,
              border: Border.all(
                color: GardenColors.of(context).outline,
                width: 2,
              ),
            ),
            child: _drawingSpecial == null
                ? null
                : SpecialSwatch(
                    special: _drawingSpecial!,
                    base: Color(_drawingColor),
                    shape: BoxShape.circle,
                  ),
          ),
          onPressed: _enabled ? _pickColor : null,
        ),
      ),
      SizedBox(width: vertical ? 0 : 8, height: vertical ? 8 : 0),
      KeyedSubtree(
        key: _sizeAnchor,
        child: IconButton(
          color: GardenColors.of(context).foreground,
          key: const ValueKey('sketch-size'),
          tooltip: 'Brush size',
          icon: Container(
            width:
                6 +
                18 *
                    (_settings.size - sketchMinBrush) /
                    (sketchMaxBrush - sketchMinBrush),
            height:
                6 +
                18 *
                    (_settings.size - sketchMinBrush) /
                    (sketchMaxBrush - sketchMinBrush),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GardenColors.of(context).foreground,
            ),
          ),
          onPressed: _enabled ? _pickSize : null,
        ),
      ),
    ],
  );

  Widget _loadBody() => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(switch (_loadState) {
              _LoadState.loading => 'Opening your drawing…',
              _LoadState.unreadable => "This drawing couldn't be opened.",
              _ => "We couldn't open your drawing.",
            }, textAlign: TextAlign.center),
            if (_loadState != _LoadState.loading) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Try again')),
              if (_loadState == _LoadState.unreadable)
                OutlinedButton(
                  onPressed: _startNew,
                  child: const Text('Start a new page'),
                ),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _retrySave() async {
    if (_renderFailed) {
      _queueSave();
      await _autosave;
    }
    await _store.retry();
  }

  Widget _saveButton() {
    final failed = _store.failed.value || _renderFailed;
    final saved = _galleryRevision == _canvas.revision;
    final label = failed
        ? "Couldn't save your drawing. Try again"
        : _saving
        ? 'Saving…'
        : _galleryFailed
        ? "Couldn't save to photos. Try again"
        : saved
        ? (_alreadySaved ? 'Already saved to photos' : 'Saved to photos')
        : 'Save to photos';
    final error = failed || _galleryFailed;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final icon = _saving
        ? Icons.hourglass_top_rounded
        : error
        ? Icons.refresh_rounded
        : saved
        ? Icons.check_rounded
        : Icons.save_alt_rounded;
    return _actionButton(
      key: const ValueKey('sketch-save'),
      label: label,
      liveRegion: true,
      error: error,
      onPressed: _enabled ? (failed ? _retrySave : _saveGallery) : null,
      icon: _saving && !reducedMotion
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
    );
  }

  Widget _actionButton({
    required Key key,
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
    bool liveRegion = false,
    bool error = false,
  }) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: MergeSemantics(
      child: Semantics(
        label: label,
        liveRegion: liveRegion,
        child: OutlinedButton(
          key: key,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(56, 56),
            maximumSize: const Size(56, 56),
            padding: EdgeInsets.zero,
            side: error
                ? BorderSide(color: Theme.of(context).colorScheme.error)
                : null,
          ),
          onPressed: onPressed,
          child: icon,
        ),
      ),
    ),
  );

  Widget _actions({required bool vertical}) {
    Widget button(String name, IconData icon, VoidCallback? onPressed) =>
        _actionButton(
          key: ValueKey('sketch-${name.toLowerCase()}'),
          label: name,
          icon: Icon(icon),
          onPressed: onPressed,
        );
    final showSave =
        (_gallerySupported && widget.controller.settings.sketchSaveToPhotos) ||
        _store.failed.value ||
        _renderFailed;
    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      children: [
        button(
          'Undo',
          Icons.undo_rounded,
          _enabled && _canvas.canUndo ? _canvas.undo : null,
        ),
        SizedBox(width: vertical ? 0 : 8, height: vertical ? 8 : 0),
        button(
          'Redo',
          Icons.redo_rounded,
          _enabled && _canvas.canRedo ? _canvas.redo : null,
        ),
        const Spacer(),
        button('Clear', Icons.delete_outline_rounded, _enabled ? _clear : null),
        if (showSave) ...[
          SizedBox(width: vertical ? 0 : 8, height: vertical ? 8 : 0),
          _saveButton(),
        ],
      ],
    );
  }
}
