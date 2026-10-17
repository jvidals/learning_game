import 'number_range.dart';
import 'sight_words.dart';
import 'letter_sounds.dart';
import 'counting.dart';
import 'game.dart';

enum AppAppearance {
  system,
  light,
  dark;

  static AppAppearance fromValue(Object? value) {
    for (final appearance in values) {
      if (value == appearance.name) return appearance;
    }
    throw const FormatException('Invalid appearance');
  }
}

/// Independent inclusive practice ranges for one player.
class NumberGameRanges {
  const NumberGameRanges({
    this.numberHunt = NumberRange.defaults,
    this.numberOrder = NumberRange.defaults,
    this.howMany = NumberRange.defaults,
    this.makeGroup = NumberRange.defaults,
  });
  final NumberRange numberHunt, numberOrder, howMany, makeGroup;

  static bool appliesTo(Activity activity) =>
      activity == Activity.numbers ||
      activity == Activity.numberOrder ||
      activity.isCounting;
  static int capFor(Activity activity) {
    if (!appliesTo(activity))
      throw ArgumentError('This game has no number range');
    return activity.isCounting ? NumberRange.countingMaximum : 100;
  }

  static NumberRange validate(Activity activity, NumberRange range) {
    if (range.max > capFor(activity)) {
      throw ArgumentError('Choose numbers from 0 to ${capFor(activity)}.');
    }
    return range;
  }

  NumberRange forActivity(Activity activity) => switch (activity) {
    Activity.numbers => numberHunt,
    Activity.numberOrder => numberOrder,
    Activity.howMany => howMany,
    Activity.makeGroup => makeGroup,
    _ => throw ArgumentError('This game has no number range'),
  };
  NumberGameRanges withRange(Activity activity, NumberRange range) {
    validate(activity, range);
    return NumberGameRanges(
      numberHunt: activity == Activity.numbers ? range : numberHunt,
      numberOrder: activity == Activity.numberOrder ? range : numberOrder,
      howMany: activity == Activity.howMany ? range : howMany,
      makeGroup: activity == Activity.makeGroup ? range : makeGroup,
    );
  }

  Map<String, Object> toMap() => {
    for (final entry in _keys.entries)
      entry.key: validate(entry.value, forActivity(entry.value)).toMap(),
  };
  static const _keys = {
    'numberHunt': Activity.numbers,
    'numberOrder': Activity.numberOrder,
    'howMany': Activity.howMany,
    'makeGroup': Activity.makeGroup,
  };
  factory NumberGameRanges.fromValue(Object? value) {
    if (value is! Map) throw const FormatException('Invalid game ranges');
    var ranges = const NumberGameRanges();
    for (final entry in _keys.entries) {
      final raw = value[entry.key];
      if (raw is! Map || raw['min'] is! int || raw['max'] is! int) {
        throw const FormatException('Invalid game range');
      }
      try {
        ranges = ranges.withRange(
          entry.value,
          NumberRange(raw['min'] as int, raw['max'] as int),
        );
      } on ArgumentError {
        throw const FormatException('Invalid game range');
      }
    }
    return ranges;
  }
  factory NumberGameRanges.fromLegacy(NumberRange range, int maximum) =>
      NumberGameRanges(
        numberHunt: range,
        numberOrder: range,
        howMany: NumberRange(0, maximum),
        makeGroup: NumberRange(0, maximum),
      );
}

class AppSettings {
  const AppSettings({
    this.numberGameRanges = const NumberGameRanges(),
    this.enabledLetterSounds = SoundSelection.defaults,
    this.tapNext = true,
    this.haptics = true,
    this.orderingLowercase = false,
    this.soundOn = true,
    this.wordSprintTimer = true,
    this.appearance = AppAppearance.system,
    this.enabledSightWordPacks = SightWordPacks.defaults,
  });
  final NumberGameRanges numberGameRanges;
  final SoundSelection enabledLetterSounds;
  final bool tapNext, haptics, orderingLowercase, soundOn;
  final bool wordSprintTimer;
  final AppAppearance appearance;
  final SightWordPacks enabledSightWordPacks;

  AppSettings copyWith({
    NumberGameRanges? numberGameRanges,
    SoundSelection? enabledLetterSounds,
    bool? tapNext,
    bool? haptics,
    bool? orderingLowercase,
    bool? soundOn,
    bool? wordSprintTimer,
    AppAppearance? appearance,
    SightWordPacks? enabledSightWordPacks,
  }) => AppSettings(
    numberGameRanges: numberGameRanges ?? this.numberGameRanges,
    enabledLetterSounds: enabledLetterSounds ?? this.enabledLetterSounds,
    tapNext: tapNext ?? this.tapNext,
    haptics: haptics ?? this.haptics,
    orderingLowercase: orderingLowercase ?? this.orderingLowercase,
    soundOn: soundOn ?? this.soundOn,
    wordSprintTimer: wordSprintTimer ?? this.wordSprintTimer,
    appearance: appearance ?? this.appearance,
    enabledSightWordPacks: enabledSightWordPacks ?? this.enabledSightWordPacks,
  );
  AppSettings withOrderingCase(bool lowercase) =>
      copyWith(orderingLowercase: lowercase);
  AppSettings withWordSprintTimer(bool enabled) =>
      copyWith(wordSprintTimer: enabled);
  AppSettings withSound(bool enabled) => copyWith(soundOn: enabled);
  AppSettings withNumberRange(Activity activity, NumberRange range) =>
      copyWith(numberGameRanges: numberGameRanges.withRange(activity, range));

  Map<String, Object> toMap() => {
    'numberGameRanges': numberGameRanges.toMap(),
    'enabledLetterSounds': enabledLetterSounds.letters,
    'tapNext': tapNext,
    'haptics': haptics,
    'orderingLowercase': orderingLowercase,
    'soundOn': soundOn,
    'wordSprintTimer': wordSprintTimer,
    'appearance': appearance.name,
    'enabledSightWordPacks': enabledSightWordPacks.toList(),
  };
  factory AppSettings.fromMap(Map<String, dynamic>? map) {
    // Validate legacy fields before migrating, even alongside new fields.
    var legacyRange = NumberRange.defaults;
    if (map != null && (map.containsKey('min') || map.containsKey('max'))) {
      final min = map['min'], max = map['max'];
      if (min is! int || max is! int)
        throw const FormatException('Invalid number range');
      try {
        legacyRange = NumberRange(min, max);
      } on ArgumentError {
        throw const FormatException('Invalid number range');
      }
    }
    final legacyMaximum = map != null && map.containsKey('countingMax')
        ? readCountingMax(map['countingMax'])
        : 10;
    return AppSettings(
      numberGameRanges: map != null && map.containsKey('numberGameRanges')
          ? NumberGameRanges.fromValue(map['numberGameRanges'])
          : NumberGameRanges.fromLegacy(legacyRange, legacyMaximum),
      enabledLetterSounds: map != null && map.containsKey('enabledLetterSounds')
          ? SoundSelection.fromValue(map['enabledLetterSounds'])
          : SoundSelection.defaults,
      tapNext: map?['tapNext'] != false,
      haptics: map?['haptics'] != false,
      orderingLowercase: map?['orderingLowercase'] == true,
      soundOn: map?['soundOn'] != false,
      wordSprintTimer: map?['wordSprintTimer'] != false,
      appearance: map != null && map.containsKey('appearance')
          ? AppAppearance.fromValue(map['appearance'])
          : AppAppearance.system,
      enabledSightWordPacks: SightWordPacks.fromValue(
        map?['enabledSightWordPacks'],
      ),
    );
  }
}
