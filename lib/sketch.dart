import 'dart:convert';
import 'dart:ui' show Offset, Size;

import 'sketch_ink.dart';

const int sketchPageLongSide = 1920;
const double sketchMinPageRatio = 0.3;
const int sketchMaxImageSide = 2560;
const int sketchMinImageSide = 256;

/// Fits the drawable area's shape in page units, in the same orientation.
Size sketchPageSizeFor(Size area) {
  if (!area.width.isFinite || !area.height.isFinite || area.isEmpty) {
    return const Size(1080, 1920);
  }
  final portrait = area.height >= area.width;
  final ratio = portrait ? area.width / area.height : area.height / area.width;
  final shortSide = (sketchPageLongSide * ratio.clamp(sketchMinPageRatio, 1))
      .roundToDouble();
  return portrait
      ? Size(shortSide, sketchPageLongSide.toDouble())
      : Size(sketchPageLongSide.toDouble(), shortSide);
}

bool isValidSketchPageSize(int width, int height) =>
    width >= sketchMinImageSide &&
    width <= sketchMaxImageSide &&
    height >= sketchMinImageSide &&
    height <= sketchMaxImageSide;
const double sketchMinBrush = 12;
const double sketchMaxBrush = 110;
const double sketchDefaultBrush = 32;
const int sketchPaperColor = 0xFFFFFFFF;
const int sketchRecentLimit = 10;
const int sketchHistoryLimit = 30;

enum SketchTool { brush, eraser, fill }

/// Opaque crayon colors, in the order shown in the color picker.
const List<({int color, String name})> sketchPresetColors = [
  (color: 0xFF000000, name: 'Black'),
  (color: 0xFFFFFFFF, name: 'White'),
  (color: 0xFF757575, name: 'Grey'),
  (color: 0xFF79502E, name: 'Brown'),
  (color: 0xFFE53935, name: 'Red'),
  (color: 0xFFFF8A00, name: 'Orange'),
  (color: 0xFFFFD600, name: 'Yellow'),
  (color: 0xFF8BD43C, name: 'Light green'),
  (color: 0xFF16833D, name: 'Dark green'),
  (color: 0xFF29B6F6, name: 'Light blue'),
  (color: 0xFF2454CE, name: 'Dark blue'),
  (color: 0xFF8E36C9, name: 'Purple'),
  (color: 0xFFF052A0, name: 'Pink'),
];
const int sketchDefaultColor = 0xFF000000;

/// Returns a new, de-duplicated list with [color] first.
List<int> pushRecentColor(List<int> recent, int color) =>
    <int>{color, ...recent}.take(sketchRecentLimit).toList();

/// A finished stroke in page coordinates; erasers use [sketchPaperColor].
class SketchStroke {
  SketchStroke({
    required this.color,
    required this.width,
    required List<Offset> points,
    this.special,
  }) : points = List.unmodifiable(points);

  final int color;
  final double width;
  final List<Offset> points;
  final SketchSpecial? special;
}

/// Retains off-page direction; the renderer clips ink to the paper.
/// Distance filtering and the sample cap bound storage.
class StrokeBuilder {
  StrokeBuilder({
    required int color,
    required double width,
    required Size page,
    SketchSpecial? special,
    double minDistance = 1.5,
  }) : _color = color,
       _width = width,
       _special = special,
       _minDistanceSquared = minDistance * minDistance {
    if (!minDistance.isFinite || minDistance < 0) {
      throw ArgumentError.value(minDistance, 'minDistance');
    }
  }

  final int _color;
  final double _width;
  final SketchSpecial? _special;
  final double _minDistanceSquared;
  final List<Offset> _points = [];

  bool add(Offset point) {
    if (_points.length >= 4000 || !point.dx.isFinite || !point.dy.isFinite) {
      return false;
    }
    if (_points.isNotEmpty &&
        (point - _points.last).distanceSquared < _minDistanceSquared) {
      return false;
    }
    _points.add(point);
    return true;
  }

  List<Offset> get points => List.unmodifiable(_points);

  SketchStroke build() => SketchStroke(
    color: _color,
    width: _width,
    points: _points,
    special: _special,
  );
}

/// Linear history. Evicted ops transfer to the caller for base-image flattening;
/// discarded redo ops transfer to [onDiscard] for disposal.
class SketchHistory<T> {
  SketchHistory({this.limit = sketchHistoryLimit, this.onDiscard}) {
    if (limit < 0) throw ArgumentError.value(limit, 'limit');
  }

  final int limit;
  final void Function(T op)? onDiscard;
  final List<T> _ops = [];
  int _cursor = 0;

  List<T> push(T op) {
    final discarded = _ops.sublist(_cursor);
    _ops.removeRange(_cursor, _ops.length);
    for (final old in discarded) {
      onDiscard?.call(old);
    }
    _ops.add(op);
    final excess = _ops.length - limit;
    final evicted = excess > 0 ? _ops.sublist(0, excess) : <T>[];
    if (excess > 0) _ops.removeRange(0, excess);
    _cursor = _ops.length;
    return evicted;
  }

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _ops.length;
  T? undo() => canUndo ? _ops[--_cursor] : null;
  T? redo() => canRedo ? _ops[_cursor++] : null;
  List<T> get active => List.unmodifiable(_ops.take(_cursor));

  /// Removes an operation without leaving an undo step, disposing its payload.
  bool remove(T op) {
    final index = _ops.indexOf(op);
    if (index < 0) return false;
    _ops.removeAt(index);
    if (index < _cursor) _cursor--;
    onDiscard?.call(op);
    return true;
  }

  void clearAll() {
    final discarded = List<T>.of(_ops);
    _ops.clear();
    _cursor = 0;
    for (final op in discarded) {
      onDiscard?.call(op);
    }
  }
}

/// Settings belong to a player, independently of their learning progress.
class SketchSettings {
  const SketchSettings({
    this.color = sketchDefaultColor,
    this.size = sketchDefaultBrush,
    this.tool = SketchTool.brush,
    this.recentColors = const [],
    this.special,
    this.photoUri,
    this.twinkles = const [],
  });

  final int color;
  final double size;
  final SketchTool tool;
  final List<int> recentColors;
  final SketchSpecial? special;
  final String? photoUri;
  final List<SketchTwinkle> twinkles;

  SketchInk get ink => special == null ? SolidInk(color) : SpecialInk(special!);

  SketchSettings copyWith({
    int? color,
    double? size,
    SketchTool? tool,
    List<int>? recentColors,
    SketchSpecial? special,
    String? photoUri,
    bool clearPhotoUri = false,
    List<SketchTwinkle>? twinkles,
  }) => SketchSettings(
    color: color ?? this.color,
    twinkles: List.unmodifiable(twinkles ?? this.twinkles),
    special: special ?? this.special,
    photoUri: clearPhotoUri ? null : photoUri ?? this.photoUri,
    size: size ?? this.size,
    tool: tool ?? this.tool,
    recentColors: List.unmodifiable(recentColors ?? this.recentColors),
  );

  SketchSettings applyColor(int color) => SketchSettings(
    color: color,
    special: special?.isEffect == true ? special : null,
    photoUri: photoUri,
    twinkles: twinkles,
    size: size,
    tool: tool,
    recentColors: List.unmodifiable(pushRecentColor(recentColors, color)),
  );

  SketchSettings clearSpecial() => SketchSettings(
    color: color,
    size: size,
    tool: tool,
    recentColors: recentColors,
    photoUri: photoUri,
    twinkles: twinkles,
  );

  SketchSettings applySpecial(SketchSpecial special) =>
      copyWith(special: special);

  String encode() => jsonEncode({
    'version': 4,
    'twinkles': [
      for (final t in twinkles) [t.x, t.y, t.phase, t.size],
    ],
    'photoUri': photoUri,
    'color': color,
    'size': size,
    'tool': tool.name,
    'recentColors': recentColors,
    'special': special?.name,
  });

  static SketchSettings decode(String document) {
    const error = FormatException('Sketch settings could not be read.');
    dynamic decoded;
    try {
      decoded = jsonDecode(document);
    } on FormatException {
      throw error;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] is! int ||
        !switch (decoded['version']) {
          1 =>
            decoded.length == 5 &&
                !decoded.containsKey('special') &&
                !decoded.containsKey('photoUri') &&
                !decoded.containsKey('twinkles'),
          2 =>
            decoded.length == 6 &&
                decoded.containsKey('special') &&
                !decoded.containsKey('photoUri') &&
                !decoded.containsKey('twinkles'),
          3 =>
            decoded.length == 7 &&
                decoded.containsKey('special') &&
                decoded.containsKey('photoUri') &&
                !decoded.containsKey('twinkles'),
          4 =>
            decoded.length == 8 &&
                decoded.containsKey('special') &&
                decoded.containsKey('photoUri') &&
                decoded.containsKey('twinkles'),
          _ => false,
        } ||
        (decoded['special'] != null &&
            (decoded['special'] is! String ||
                !SketchSpecial.values.any(
                  (special) => special.name == decoded['special'],
                ))) ||
        !_opaqueColor(decoded['color']) ||
        decoded['size'] is! num ||
        !(decoded['size'] as num).isFinite ||
        decoded['size'] < sketchMinBrush ||
        decoded['size'] > sketchMaxBrush ||
        decoded['tool'] is! String ||
        !SketchTool.values.any((tool) => tool.name == decoded['tool']) ||
        decoded['recentColors'] is! List) {
      throw error;
    }
    final recent = decoded['recentColors'] as List;
    if (recent.length > sketchRecentLimit ||
        !recent.every(_opaqueColor) ||
        recent.toSet().length != recent.length) {
      throw error;
    }
    final photoUri = decoded['photoUri'];
    return SketchSettings(
      twinkles: decoded['version'] == 4
          ? _decodeTwinkles(decoded['twinkles'])
          : const [],
      photoUri:
          photoUri is String &&
              photoUri.startsWith('content://media/') &&
              photoUri.length <= 512
          ? photoUri
          : null,
      color: decoded['color'] as int,
      special: decoded['special'] == null
          ? null
          : SketchSpecial.values.firstWhere(
              (special) => special.name == decoded['special'],
            ),
      size: (decoded['size'] as num).toDouble(),
      tool: SketchTool.values.firstWhere(
        (tool) => tool.name == decoded['tool'],
      ),
      recentColors: List<int>.unmodifiable(recent),
    );
  }

  // Animation metadata is optional recovery data: a corrupt list must never
  // prevent loading the player's drawing and brush settings.
  static List<SketchTwinkle> _decodeTwinkles(Object? value) {
    if (value is! List || value.length > 600) return const [];
    final anchors = <SketchTwinkle>[];
    for (final entry in value) {
      if (entry is! List ||
          entry.length != 4 ||
          !entry.every((n) => n is num && n.isFinite) ||
          entry[2] is! int ||
          entry[3] < 6 ||
          entry[3] > 18) {
        return const [];
      }
      anchors.add(
        SketchTwinkle(
          (entry[0] as num).toDouble(),
          (entry[1] as num).toDouble(),
          entry[2] as int,
          (entry[3] as num).toDouble(),
        ),
      );
    }
    return List.unmodifiable(anchors);
  }

  static bool _opaqueColor(Object? value) =>
      value is int && value >= 0xFF000000 && value <= 0xFFFFFFFF;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SketchSettings ||
        color != other.color ||
        special != other.special ||
        photoUri != other.photoUri ||
        twinkles.length != other.twinkles.length ||
        size != other.size ||
        tool != other.tool ||
        recentColors.length != other.recentColors.length) {
      return false;
    }
    for (var i = 0; i < recentColors.length; i++) {
      if (recentColors[i] != other.recentColors[i]) return false;
    }
    for (var i = 0; i < twinkles.length; i++) {
      if (twinkles[i] != other.twinkles[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    color,
    size,
    tool,
    special,
    photoUri,
    Object.hashAll(recentColors),
    Object.hashAll(twinkles),
  );
}
