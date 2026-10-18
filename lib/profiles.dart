import 'dart:convert';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'progress.dart';
import 'app_settings.dart';

String normalizePlayerName(String name) {
  final value = name.trim();
  if (value.isEmpty ||
      value.characters.length > 24 ||
      value.contains(RegExp(r'[\r\n]'))) {
    throw const FormatException('Use a name with 1–24 characters.');
  }
  return value;
}

/// Progress stays encoded so a damaged progress can be recovered independently.
class PlayerProfile {
  PlayerProfile({
    required String id,
    required String name,
    required AppSettings settings,
    required String progressDocument,
  }) : this._(
         id: id,
         name: name,
         settings: settings.toMap(),
         progress: progressDocument,
       );
  PlayerProfile._({
    required this.id,
    required String name,
    required Object? settings,
    required Object? progress,
  }) : name = normalizePlayerName(name),
       _settingsPayload = settings,
       _progressPayload = progress;
  final String id, name;
  final Object? _settingsPayload, _progressPayload;
  String get progressDocument {
    if (_progressPayload is! String)
      throw const FormatException('Invalid progress');
    return _progressPayload;
  }

  AppSettings get settings {
    if (_settingsPayload is! Map)
      throw const FormatException('Invalid settings');
    final map = Map<String, dynamic>.from(_settingsPayload);
    if (!map.containsKey('numberGameRanges') &&
        (!map.containsKey('min') || !map.containsKey('max'))) {
      throw const FormatException('Invalid number range');
    }
    // Retired settings are still validated before upgrade drops them.
    if (map.containsKey('relaxed') && map['relaxed'] is! bool) {
      throw const FormatException('Invalid legacy settings');
    }
    for (final key in [
      'tapNext',
      'haptics',
      'orderingLowercase',
      'soundOn',
      'sketchSaveToPhotos',
    ]) {
      if (map.containsKey(key) && map[key] is! bool) {
        throw const FormatException('Invalid setting');
      }
    }
    return AppSettings.fromMap(map);
  }

  bool get hasValidSettings {
    try {
      settings;
      return true;
    } catch (_) {
      return false;
    }
  }

  factory PlayerProfile.fresh(String name) => PlayerProfile(
    id: 'player-${newRoundId()}',
    name: name,
    settings: const AppSettings(),
    progressDocument: PlayerProgress().encode(),
  );

  PlayerProgress get progress => PlayerProgress.decode(progressDocument);
  CompanionConfiguration? get portrait {
    try {
      return progress.companion;
    } catch (_) {
      return null;
    }
  }

  PlayerProfile copyWith({
    String? name,
    AppSettings? settings,
    String? progressDocument,
  }) => PlayerProfile._(
    id: id,
    name: name ?? this.name,
    settings: settings?.toMap() ?? _settingsPayload,
    progress: progressDocument ?? _progressPayload,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'settings': _settingsPayload,
    'progress': _progressPayload,
  };

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Invalid player ID');
    }
    return PlayerProfile._(
      id: id,
      name: map['name'] as String,
      settings: map['settings'],
      progress: map['progress'],
    );
  }
}

class ProfileStore {
  ProfileStore({required this.activeId, required List<PlayerProfile> players})
    : players = List.unmodifiable(players) {
    if (players.isEmpty ||
        players.map((p) => p.id).toSet().length != players.length ||
        !players.any((p) => p.id == activeId)) {
      throw const FormatException('Invalid player collection');
    }
  }
  final String activeId;
  final List<PlayerProfile> players;
  PlayerProfile get active => players.firstWhere((p) => p.id == activeId);
  factory ProfileStore.initial() {
    final player = PlayerProfile.fresh('Player 1');
    return ProfileStore(activeId: player.id, players: [player]);
  }
  ProfileStore replace(PlayerProfile player) => ProfileStore(
    activeId: activeId,
    players: [
      for (final p in players)
        if (p.id == player.id) player else p,
    ],
  );
  ProfileStore select(String id) =>
      ProfileStore(activeId: id, players: players);

  /// Upgrade valid profiles together; never normalize a damaged payload.
  ProfileStore? migrateProgress() {
    var changed = false;
    final next = players.map((player) {
      try {
        final progress = player.progress;
        final settings = player.settings;
        final encoded = progress.encode();
        final oldSettings = player.toMap()['settings'] as Map;
        if (encoded == player.progressDocument &&
            !oldSettings.containsKey('relaxed') &&
            oldSettings.containsKey('numberGameRanges') &&
            !oldSettings.containsKey('min') &&
            !oldSettings.containsKey('max') &&
            !oldSettings.containsKey('countingMax')) {
          return player;
        }
        changed = true;
        return player.copyWith(progressDocument: encoded, settings: settings);
      } catch (_) {
        return player;
      }
    }).toList();
    return changed ? ProfileStore(activeId: activeId, players: next) : null;
  }

  String encode() => jsonEncode({
    'schemaVersion': 1,
    'activeId': activeId,
    'players': players.map((p) => p.toMap()).toList(),
  });
  factory ProfileStore.decode(String document) {
    final map = jsonDecode(document) as Map<String, dynamic>;
    if (map['schemaVersion'] != 1) {
      throw const FormatException('Unsupported profiles');
    }
    return ProfileStore(
      activeId: map['activeId'] as String,
      players: (map['players'] as List)
          .map(
            (p) => PlayerProfile.fromMap(Map<String, dynamic>.from(p as Map)),
          )
          .toList(),
    );
  }
}
