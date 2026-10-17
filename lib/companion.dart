import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'progress.dart';
import 'garden_art.dart';
import 'companion/foal_assets.dart';
import 'companion/foal_clip.dart';
import 'companion/foal_playback.dart';
import 'companion/foal_renderer.dart';

enum CompanionReaction { happy, celebration }

enum CompanionFraming { full, head, wings }

Color maneColor(String? id) =>
    FoalAssets.ready?.paletteColor(id ?? 'pink') ??
    switch (id) {
      'blue' => rainbow[4],
      'mint' => rainbow[3],
      'gold' => rainbow[2],
      _ => rainbow[0],
    };

class CompanionView extends StatefulWidget {
  const CompanionView({
    super.key,
    required this.configuration,
    this.height = 180,
    this.reactionTrigger = 0,
    this.animate = true,
    this.framing = CompanionFraming.full,
    this.clipToFraming = true,
    this.boundedCelebration = false,
    this.reaction = CompanionReaction.celebration,
    this.onPet,
  });
  final CompanionConfiguration configuration;
  final double height;
  final int reactionTrigger;
  final CompanionReaction reaction;
  final VoidCallback? onPet;
  final bool animate;
  final CompanionFraming framing;

  /// Keep the focus rectangle's crop, or reveal art up to the viewport edges.
  final bool clipToFraming;

  /// Retained for callers; all one-shot reactions are now bounded.
  final bool boundedCelebration;
  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  late final AnimationController _response = AnimationController(vsync: this);
  bool _foreground = true, _celebrating = false, _failed = false;
  CompanionReaction _reaction = CompanionReaction.celebration;
  Timer? _end;
  FoalPlayback? _playback;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    if (widget.reactionTrigger > 0) _start(widget.reaction);
  }

  Future<void> _load() async {
    try {
      final assets = await FoalAssets.load();
      await assets.ensurePoster(FoalRenderer.outfit(widget.configuration));
      if (mounted) {
        setState(() {
          _playback ??= FoalPlayback(assets);
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CompanionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.framing != oldWidget.framing ||
        widget.configuration[RewardCategory.behavior] !=
            oldWidget.configuration[RewardCategory.behavior]) {
      _stop();
    }
    if (FoalRenderer.outfit(widget.configuration) !=
        FoalRenderer.outfit(oldWidget.configuration)) {
      _playback?.cancel();
      unawaited(_load());
    }
    if (widget.reactionTrigger != oldWidget.reactionTrigger) {
      if (widget.reactionTrigger > 0) {
        _start(widget.reaction);
      } else {
        _stop();
      }
    }
    _sync();
  }

  void _start(CompanionReaction reaction) {
    _end?.cancel();
    _reaction = reaction;
    _celebrating = true;
    final duration = foalReactionDuration(
      happy: reaction == CompanionReaction.happy,
      behavior: widget.configuration[RewardCategory.behavior],
    );
    _response.duration = duration;
    _response.value = 0;
    _end = Timer(duration, () {
      if (mounted) {
        setState(() {
          _stop();
          _sync();
        });
      }
    });
  }

  void _stop() {
    _end?.cancel();
    _celebrating = false;
    _response.stop();
  }

  bool get _visible =>
      _foreground &&
      TickerMode.of(context) &&
      (ModalRoute.isCurrentOf(context) ?? true);
  void _pet() {
    if (_celebrating || !_visible) return;
    setState(() {
      _start(CompanionReaction.happy);
      _sync();
    });
    widget.onPet?.call();
  }

  void _sync() {
    if (!_visible) {
      _stop();
      _playback?.cancel();
    }
    final moving = _visible && !MediaQuery.disableAnimationsOf(context);
    if (moving && widget.animate) {
      if (!_idle.isAnimating) _idle.repeat();
    } else {
      _idle.stop();
    }
    if (moving && _celebrating) {
      if (!_response.isAnimating) _response.forward();
    } else {
      _response.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _end?.cancel();
    _idle.dispose();
    _response.dispose();
    _playback?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.onPet == null ? 'Your unicorn' : 'Pet your unicorn',
    image: widget.onPet == null,
    button: widget.onPet != null,
    onTap: widget.onPet == null ? null : _pet,
    child: GestureDetector(
      excludeFromSemantics: true,
      onTap: widget.onPet == null ? null : _pet,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _failed
            ? Center(
                child: IconButton(
                  tooltip: 'Reload unicorn art',
                  onPressed: () {
                    setState(() => _failed = false);
                    unawaited(_load());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              )
            : RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_idle, _response, ?_playback]),
                  builder: (context, _) {
                    final happy =
                        _celebrating && _reaction == CompanionReaction.happy;
                    final celebrating =
                        _celebrating &&
                        _reaction == CompanionReaction.celebration;
                    final reduced = MediaQuery.disableAnimationsOf(context);
                    final art = FoalAssets.ready;
                    if (art != null && _visible) {
                      final sample = FoalClipSample.evaluate(
                        idle: widget.animate ? _idle.value : 0,
                        reaction: _response.value,
                        happy: happy,
                        celebrating: celebrating,
                        behavior: widget.configuration[RewardCategory.behavior],
                        reduced: reduced,
                      );
                      _playback?.request(
                        FoalRenderer.outfit(widget.configuration),
                        sample,
                        width:
                            widget.height *
                                        MediaQuery.devicePixelRatioOf(context) >
                                    400 ||
                                widget.framing != CompanionFraming.full
                            ? 1024
                            : 512,
                      );
                    }
                    if (_playback?.error != null) {
                      return Center(
                        child: IconButton(
                          tooltip: 'Reload unicorn art',
                          onPressed: () => setState(() => _playback?.cancel()),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      );
                    }
                    return CustomPaint(
                      painter: CompanionPainter(
                        widget.configuration,
                        assets: FoalAssets.ready,
                        frame: _playback?.imageFor(
                          FoalRenderer.outfit(widget.configuration),
                        ),
                        phase: widget.animate ? _idle.value : 0,
                        response: _response.value,
                        reduced: MediaQuery.disableAnimationsOf(context),
                        celebrating:
                            _celebrating &&
                            _reaction == CompanionReaction.celebration,
                        happy:
                            _celebrating &&
                            _reaction == CompanionReaction.happy,
                        framing: widget.framing,
                        clipToFraming: widget.clipToFraming,
                      ),
                    );
                  },
                ),
              ),
      ),
    ),
  );
}

class CompanionPainter extends CustomPainter {
  CompanionPainter(
    this.configuration, {
    this.assets,
    this.frame,
    this.phase = 0,
    this.response = 0,
    this.celebrating = false,
    this.happy = false,
    this.reduced = false,
    this.framing = CompanionFraming.full,
    this.clipToFraming = true,
  });
  final CompanionConfiguration configuration;
  final FoalAssets? assets;
  final ui.Image? frame;
  final double phase, response;
  final bool celebrating, happy, reduced;
  final CompanionFraming framing;
  final bool clipToFraming;
  @override
  void paint(Canvas c, Size size) {
    final art = assets ?? FoalAssets.ready;
    if (art == null) return;
    final bounds = art.framing(framing.name);
    final scale = min(size.width / bounds.width, size.height / bounds.height);
    c.save();
    c.clipRect(Offset.zero & size);
    c.translate(
      (size.width - bounds.width * scale) / 2,
      (size.height - bounds.height * scale) / 2,
    );
    c.scale(scale);
    c.translate(-bounds.left, -bounds.top);
    if (clipToFraming) {
      c.clipRect(bounds);
    }
    if (framing != CompanionFraming.head) {
      // The fixed camera projects the rear hooves above the front pair.
      // Span their shared ground plane rather than drawing a flat baseline.
      c.save();
      c.translate(502, 872);
      c.rotate(-14.5 * pi / 180);
      c.drawOval(
        const Rect.fromLTWH(-200, -50, 400, 100),
        Paint()
          ..color = const Color(0x1839234F)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      c.restore();
    }
    FoalRenderer(
      art,
      configuration,
      maneColor(configuration[RewardCategory.mane]),
    ).draw(c, frame: frame);
    c.restore();
  }

  @override
  bool shouldRepaint(CompanionPainter old) =>
      old.configuration != configuration ||
      old.assets != assets ||
      old.frame != frame ||
      old.phase != phase ||
      old.response != response ||
      old.celebrating != celebrating ||
      old.happy != happy ||
      old.reduced != reduced ||
      old.framing != framing ||
      old.clipToFraming != clipToFraming;
}

class CompanionItemArt extends StatefulWidget {
  const CompanionItemArt({super.key, required this.category, this.id});
  final RewardCategory category;
  final String? id;
  @override
  State<CompanionItemArt> createState() => _CompanionItemArtState();
}

class _CompanionItemArtState extends State<CompanionItemArt> {
  Future<FoalAssets> _load() async {
    final art = await FoalAssets.load();
    await art.ensurePoster('none-none');
    return art;
  }

  late Future<FoalAssets> _art = _load();
  @override
  Widget build(BuildContext context) => FutureBuilder<FoalAssets>(
    future: _art,
    builder: (context, snapshot) => snapshot.hasError
        ? IconButton(
            tooltip: 'Reload reward art',
            onPressed: () => setState(() => _art = _load()),
            icon: const Icon(Icons.refresh_rounded),
          )
        : CustomPaint(
            painter: CompanionItemPainter(
              widget.category,
              widget.id,
              assets: snapshot.data,
            ),
          ),
  );
}

class CompanionItemPainter extends CustomPainter {
  CompanionItemPainter(this.category, this.id, {this.assets});
  final RewardCategory category;
  final String? id;
  final FoalAssets? assets;
  @override
  void paint(Canvas canvas, Size size) {
    final art = assets ?? FoalAssets.ready;
    if (art == null) return;
    final configuration = CompanionConfiguration({category: ?id});
    if (category == RewardCategory.behavior ||
        category == RewardCategory.polish ||
        (id != null &&
            (category == RewardCategory.accessory ||
                category == RewardCategory.wings))) {
      final itemId =
          id ?? (category == RewardCategory.polish ? 'polish_none' : 'simple');
      final index = (art.manifest['itemIds'] as List).indexOf(itemId);
      if (index < 0) return;
      final side = min(size.width, size.height);
      canvas.drawImageRect(
        art.posters['__items']!,
        Rect.fromLTWH(index % 3 * 256.0, index ~/ 3 * 256.0, 256, 256),
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: side,
          height: side,
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    CompanionPainter(
      configuration,
      assets: art,
      framing:
          category == RewardCategory.mane ||
              category == RewardCategory.accessory
          ? CompanionFraming.head
          : category == RewardCategory.wings
          ? CompanionFraming.wings
          : CompanionFraming.full,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(CompanionItemPainter old) =>
      old.category != category || old.id != id || old.assets != assets;
}
