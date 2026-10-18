import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'progress.dart';
import 'app_settings.dart';
import 'device_services.dart';
import 'game_2048.dart';
import 'profiles.dart';
import 'writing.dart';

/// Owns every write, including failures after the originating route closes.
/// A pending operation retries the exact same document; nothing else can mutate it.
class ProgressController extends ChangeNotifier {
  ProgressController(this.services, {Random? game2048Random})
    : _game2048Random = game2048Random ?? Random();
  final DeviceServices services;
  final Random _game2048Random;
  Game2048Move? last2048Move;
  // Controller-local idempotency is scoped to stable players; best alone is persisted.
  final _wordSprintResults = <String, Map<String, WordSprintResult>>{};
  PlayerProgress? progress;
  AppSettings settings = const AppSettings();
  AppSettings? _queuedSettings;
  String? _settingsPlayerId;
  Future<void>? _settingsSave;
  AppSettings get effectiveSettings =>
      _queuedSettings ?? _pending?.settings ?? settings;
  bool get savingSettings =>
      _pending?.key == 'settings' || _queuedSettings != null;
  bool get canEditSettings =>
      !loading &&
      _store != null &&
      !loadFailed &&
      (_pending == null || _pending!.key == 'settings');
  final blocked = ValueNotifier(false);
  bool loading = false, writing = false, loadFailed = false;
  String? failure;
  _Write? _pending;
  ProfileStore? _store;
  List<PlayerProfile> get profiles => _store?.players ?? const [];
  PlayerProfile? get activeProfile => _store?.active;
  bool get profileStoreUnavailable => _store == null;

  void _accept(ProfileStore store, {PlayerProgress? savedProgress}) {
    _store = store;
    settings = const AppSettings();
    progress = null;
    loadFailed = false;
    try {
      settings = store.active.settings;
      progress = savedProgress ?? store.active.progress;
    } catch (_) {
      loadFailed = true;
    }
  }

  void _requireProfiles() {
    if (blocked.value || _store == null) {
      throw StateError('Finish saving first');
    }
  }

  Future<void> selectProfile(String id) async {
    _requireProfiles();
    if (id == _store!.activeId) return;
    unawaited(services.stop().catchError((Object _) {}));
    await _commitStore('profile:select', _store!.select(id));
  }

  Future<void> addProfile(String name) async {
    _requireProfiles();
    final player = PlayerProfile.fresh(name);
    await _commitStore(
      'profile:add',
      ProfileStore(activeId: player.id, players: [..._store!.players, player]),
    );
  }

  Future<void> renameProfile(String name) async {
    _requireProfiles();
    await _commitStore(
      'profile:rename',
      _store!.replace(_store!.active.copyWith(name: name)),
    );
  }

  Future<void> deleteProfile() async {
    _requireProfiles();
    if (profiles.length == 1) throw StateError('Keep at least one player');
    final remaining = profiles.where((p) => p.id != _store!.activeId).toList();
    await _commitStore(
      'profile:delete',
      ProfileStore(activeId: remaining.first.id, players: remaining),
    );
  }

  bool get savingSound =>
      savingSettings && effectiveSettings.soundOn != settings.soundOn;
  bool get soundOn => effectiveSettings.soundOn;

  Future<void> setSound(bool enabled) async {
    _requireReady();
    await updateSettings((current) => current.withSound(enabled));
  }

  Future<void> setWordSprintTimer(bool enabled) async {
    _requireReady();
    await updateSettings((current) => current.withWordSprintTimer(enabled));
  }

  /// Settings edits are immediate; only one immutable document is written at a time.
  Future<void> updateSettings(AppSettings Function(AppSettings) update) async {
    if (!canEditSettings) throw StateError('Finish saving first');
    final next = update(effectiveSettings);
    final encoded = jsonEncode(next.toMap()); // Also validates activity caps.
    if (encoded == jsonEncode(effectiveSettings.toMap())) return;
    _settingsPlayerId ??= _store!.activeId;
    _queuedSettings = next;
    if (_pending == null) _prepareSettingsWrite();
    _publish();
    // A failed document must be explicitly retried, never replaced by another edit.
    if (failure != null) return;
    if (writing) {
      await _settingsSave;
      return;
    }
    await retry();
  }

  void _prepareSettingsWrite() {
    final next = _queuedSettings;
    if (next == null) return;
    if (_store?.activeId != _settingsPlayerId) {
      throw StateError('The pending settings belong to another player');
    }
    _queuedSettings = null;
    _pending = _Write(
      'settings',
      _settingsPlayerId,
      _store!.replace(_store!.active.copyWith(settings: next)),
      next,
      null,
      progress,
    );
  }

  bool _disposed = false;
  void _publish() {
    if (!_disposed) {
      blocked.value =
          writing || _pending != null || _queuedSettings != null || loading;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    blocked.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (loading || writing || _pending != null) return;
    loading = true;
    _store = null;
    progress = null;
    last2048Move = null;
    loadFailed = false;
    _publish();
    try {
      _accept(ProfileStore.decode(await services.loadProfiles()));
    } catch (_) {
      loadFailed = true;
    }
    loading = false;
    if (_store != null) {
      final migrated = _store!.migrateProgress();
      if (migrated != null) {
        try {
          await _commitStore('migration:progress-v3', migrated);
        } catch (_) {
          // The shared pending write remains available through SaveStatus.
        }
      }
    }
    _publish();
  }

  Future<void> _commit(
    String key,
    PlayerProgress? next, [
    AppSettings? nextSettings,
    Game2048Move? gameMove,
  ]) async {
    final store = _store;
    if (store == null) throw StateError('Open your players first');
    await _commitStore(
      key,
      store.replace(
        store.active.copyWith(
          settings: nextSettings,
          progressDocument: next?.encode(),
        ),
      ),
      settings: nextSettings,
      gameMove: gameMove,
      savedProgress: next ?? progress,
    );
  }

  Future<void> _commitStore(
    String key,
    ProfileStore next, {
    AppSettings? settings,
    Game2048Move? gameMove,
    PlayerProgress? savedProgress,
  }) async {
    if (writing || loading) throw StateError('A save is still running');
    if (_pending != null && _pending!.key != key) {
      throw StateError('Retry the pending save first');
    }
    _pending ??= _Write(
      key,
      _store?.activeId,
      next,
      settings,
      gameMove,
      savedProgress,
    );
    await retry();
  }

  Future<void> retry() {
    if (writing)
      return Future<void>.error(StateError('A save is still running'));
    final completion = Completer<void>();
    _settingsSave = completion.future;
    _retryWrite().then(completion.complete, onError: completion.completeError);
    return completion.future;
  }

  Future<void> _retryWrite() async {
    if (writing) throw StateError('A save is still running');
    if (_pending == null) return;
    writing = true;
    failure = null;
    _publish();
    try {
      while (_pending != null) {
        final pending = _pending!;
        if (_store?.activeId != pending.profileId) {
          throw StateError('The pending save belongs to another player');
        }
        await services.saveProfiles(pending.store.encode());
        final retainedIds = pending.store.players.map((p) => p.id).toSet();
        final removedIds = profiles
            .map((p) => p.id)
            .where((id) => !retainedIds.contains(id))
            .toList();
        _accept(pending.store, savedProgress: pending.progress);
        for (final id in removedIds) {
          // Profile deletion is already durable; optional art cleanup must not
          // turn it into a failed profile write or block the remaining players.
          unawaited(
            Future<void>.sync(
              () => services.deleteSketch(id),
            ).catchError((Object _) {}),
          );
        }
        last2048Move = pending.gameMove;
        _pending = null;
        if (pending.key == 'reset') {
          _wordSprintResults.remove(pending.profileId);
        }
        if (pending.key.startsWith('choose:') ||
            pending.key.startsWith('equip:')) {
          unawaited(
            requestFeedback(
              services,
              DeviceFeedback.light,
              enabled: settings.haptics,
            ),
          );
        }
        // Drain without publishing an unblocked gap or an older visual preference.
        _prepareSettingsWrite();
      }
      _settingsPlayerId = null;
    } catch (_) {
      failure = 'Your changes could not be saved yet. Try saving again.';
      rethrow;
    } finally {
      writing = false;
      _publish();
    }
  }

  Future<RoundRewardResult> completeRound(String id) async {
    final p = progress!;
    if (_pending?.key == 'round:$id') {
      await retry();
    } else if (p.lastRewardedRound != id) {
      await _commit(
        'round:$id',
        p.awardXp(roundXp).copyWith(lastRewardedRound: id),
      );
    }
    return RoundRewardResult(progress!, levelForXp(progress!.xp - roundXp));
  }

  Future<void> choose(String id) async {
    final p = progress!;
    if (!p.choices.any((r) => r.id == id))
      throw StateError('Reward unavailable');
    final r = rewardCatalog.firstWhere((r) => r.id == id);
    await _commit(
      'choose:$id',
      p.copyWith(
        owned: {...p.owned, id},
        companion: CompanionConfiguration({
          ...p.companion.equipped,
          r.category: id,
        }),
      ),
    );
  }

  Future<void> equip(RewardCategory category, String? id) async {
    final p = progress!;
    if (id != null &&
        (!p.owned.contains(id) ||
            !rewardCatalog.any((r) => r.id == id && r.category == category)))
      throw StateError('Reward unavailable');
    final equipped = {...p.companion.equipped}..remove(category);
    if (id != null) equipped[category] = id;
    await _commit(
      'equip:${category.name}:$id',
      p.copyWith(companion: CompanionConfiguration(equipped)),
    );
  }

  Future<TapChallengeResult> completeTapChallengeRound(
    String id,
    int score,
  ) async {
    if (id.isEmpty || score < 0) throw ArgumentError('Invalid round result');
    final key = 'tap:$id';
    if (_pending?.key == key) {
      await retry();
      return TapChallengeResult(score, progress!.tapChallengeHighScore, 50);
    }
    _requireReady();
    final p = progress!;
    if (score <= p.tapChallengeHighScore || p.lastRewardedRound == key) {
      return TapChallengeResult(score, p.tapChallengeHighScore, 0);
    }
    await _commit(
      key,
      p
          .awardXp(50)
          .copyWith(tapChallengeHighScore: score, lastRewardedRound: key),
    );
    return TapChallengeResult(score, progress!.tapChallengeHighScore, 50);
  }

  Future<WordSprintResult> recordWordSprint(String id, int words) async {
    if (id.isEmpty || words < 0) throw ArgumentError('Invalid sprint result');
    final key = 'sprint:$id';
    final playerId = _store?.activeId;
    if (_pending?.key == key) {
      await retry();
      return _wordSprintResults[playerId]![id]!;
    }
    _requireReady();
    final results = _wordSprintResults.putIfAbsent(playerId!, () => {});
    final previous = results[id];
    if (previous != null) return previous;
    final p = progress!;
    final newBest = words > p.wordSprintBest;
    final result = WordSprintResult(
      words,
      newBest ? words : p.wordSprintBest,
      newBest,
    );
    results[id] = result;
    if (newBest) {
      await _commit(key, p.copyWith(wordSprintBest: words));
    }
    return result;
  }

  Future<void> saveSettings(AppSettings value) => updateSettings((_) => value);
  Future<void> reset() async {
    if (blocked.value) throw StateError('Finish saving first');
    return _store == null
        ? _commitStore('reset-all', ProfileStore.initial())
        : _commit(
            'reset',
            PlayerProgress(),
            activeProfile!.hasValidSettings ? null : const AppSettings(),
          );
  }

  void _requireReady() {
    if (blocked.value || progress == null) {
      throw StateError('Finish saving progress first');
    }
  }

  Future<void> startWriting({bool restart = false, Random? random}) async {
    _requireReady();
    final p = progress!, previous = progress!.writing;
    if (previous != null && (!restart || !previous.finished)) return;
    final next = WritingProgress.start(
      newRoundId(),
      random ?? Random(),
      previous: previous?.order.last,
    );
    await _commit('writing:start:${next.id}', p.copyWith(writing: next));
  }

  /// Tokens reject stale UI callbacks after advancing or starting a new cycle.
  Future<void> completeWritingForm(String id, int index, bool lowercase) async {
    _requireReady();
    final p = progress!, current = progress!.writing;
    if (current == null ||
        current.id != id ||
        current.index != index ||
        current.finished)
      return;
    final next = current.complete(lowercase);
    if (identical(next, current)) return;
    final earned = next.pairComplete ? writingPairXp : 0;
    await _commit(
      'writing:form:$id:$index:$lowercase',
      p
          .awardXp(earned)
          .copyWith(
            writing: next,
            lastRewardedRound: earned > 0 ? 'writing:$id:$index' : null,
          ),
    );
  }

  Future<void> advanceWriting(String id, int index) async {
    _requireReady();
    final current = progress!.writing;
    if (current == null ||
        current.id != id ||
        current.index != index ||
        current.finished)
      return;
    await _commit(
      'writing:next:$id:$index',
      progress!.copyWith(writing: current.advance()),
    );
  }

  Future<void> start2048({bool restart = false}) async {
    _requireReady();
    final p = progress!;
    if (!restart && p.game2048.session != null) return;
    final session = Game2048State.start(newRoundId(), _game2048Random);
    await _commit(
      '2048:start:' + session.id,
      p.copyWith(
        game2048: Game2048Progress(
          highScore: p.game2048.highScore,
          session: session,
        ),
      ),
    );
  }

  Future<void> move2048(Move2048Direction direction) async {
    _requireReady();
    final p = progress!, session = p.game2048.session;
    if (session == null) return;
    final move = session.move(direction, _game2048Random);
    if (move == null) return;
    await _commit(
      '2048:move:${session.id}:${session.moves}',
      p
          .awardXp(move.firstWin ? game2048WinXp : 0)
          .copyWith(
            game2048: Game2048Progress(
              highScore: max(p.game2048.highScore, move.after.score),
              session: move.after,
            ),
            lastRewardedRound: move.firstWin ? '2048:${session.id}' : null,
          ),
      null,
      move,
    );
  }

  Future<void> continue2048() async {
    _requireReady();
    final p = progress!, session = p.game2048.session;
    if (session == null || !session.awaitingContinue) return;
    await _commit(
      '2048:continue:' + session.id,
      p.copyWith(
        game2048: Game2048Progress(
          highScore: p.game2048.highScore,
          session: session.acknowledgeWin(),
        ),
      ),
    );
  }
}

class _Write {
  const _Write(
    this.key,
    this.profileId,
    this.store,
    this.settings,
    this.gameMove,
    this.progress,
  );
  final String key;
  final String? profileId;
  final ProfileStore store;
  final PlayerProgress? progress;
  final AppSettings? settings;
  final Game2048Move? gameMove;
}

class TapChallengeResult {
  const TapChallengeResult(this.score, this.highScore, this.xpAwarded);
  final int score, highScore, xpAwarded;
}

class WordSprintResult {
  const WordSprintResult(this.words, this.best, this.newBest);
  final int words, best;
  final bool newBest;
}
