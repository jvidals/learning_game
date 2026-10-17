import 'dart:convert';
import 'dart:math';
import 'game_2048.dart';
import 'writing.dart';

const roundXp = 50;
int xpForLevel(int level) {
  if (level <= 1) return 0;
  if (level == 2) return 50;
  if (level <= 4) return 50 + (level - 2) * 100;
  if (level <= 7) return 250 + (level - 4) * 150;
  return 700 + (level - 7) * 200;
}

int levelForXp(int xp) {
  if (xp >= 700) return 7 + (xp - 700) ~/ 200;
  var level = 1;
  while (xp >= xpForLevel(level + 1)) {
    level++;
  }
  return level;
}

String newRoundId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

enum RewardCategory { mane, accessory, wings, polish, behavior }

class CompanionReward {
  const CompanionReward(
    this.id,
    this.label,
    this.category, {
    this.geometry,
    this.tint,
  });
  final String id, label;
  final RewardCategory category;
  final String? geometry, tint;
}

// Stable IDs and order remain the legacy migration boundary.
const legacyRewardIds = {
  'blue',
  'flower',
  'feather',
  'hop',
  'mint',
  'bow',
  'butterfly',
  'bowing',
  'gold',
  'star',
  'rainbow',
  'twirl',
};

// Interleave legacy order with polish / mane / headwear / wings additions.
const rewardCatalog = [
  CompanionReward('blue', 'Blue mane', RewardCategory.mane, tint: 'blue'),
  CompanionReward(
    'polish_pink',
    'Pink polish',
    RewardCategory.polish,
    tint: 'pink',
  ),
  CompanionReward(
    'flower',
    'Flower crown',
    RewardCategory.accessory,
    geometry: 'flower',
  ),
  CompanionReward(
    'lavender',
    'Lavender mane',
    RewardCategory.mane,
    tint: 'lavender',
  ),
  CompanionReward(
    'feather',
    'Feather wings',
    RewardCategory.wings,
    geometry: 'feather',
  ),
  CompanionReward(
    'heart',
    'Heart tiara',
    RewardCategory.accessory,
    geometry: 'heart',
  ),
  CompanionReward('hop', 'Happy hop', RewardCategory.behavior),
  CompanionReward(
    'fairy',
    'Fairy wings',
    RewardCategory.wings,
    geometry: 'fairy',
  ),
  CompanionReward('mint', 'Mint mane', RewardCategory.mane, tint: 'mint'),
  CompanionReward(
    'polish_blue',
    'Blue polish',
    RewardCategory.polish,
    tint: 'blue',
  ),
  CompanionReward(
    'bow',
    'Pretty bow',
    RewardCategory.accessory,
    geometry: 'bow',
  ),
  CompanionReward('coral', 'Coral mane', RewardCategory.mane, tint: 'coral'),
  CompanionReward(
    'butterfly',
    'Butterfly wings',
    RewardCategory.wings,
    geometry: 'butterfly',
  ),
  CompanionReward(
    'flower_lavender',
    'Lavender flower crown',
    RewardCategory.accessory,
    geometry: 'flower',
    tint: 'lavender',
  ),
  CompanionReward('bowing', 'Gentle bow', RewardCategory.behavior),
  CompanionReward(
    'feather_mint',
    'Mint feather wings',
    RewardCategory.wings,
    geometry: 'feather',
    tint: 'mint',
  ),
  CompanionReward('gold', 'Gold mane', RewardCategory.mane, tint: 'gold'),
  CompanionReward(
    'polish_mint',
    'Mint polish',
    RewardCategory.polish,
    tint: 'mint',
  ),
  CompanionReward(
    'star',
    'Star crown',
    RewardCategory.accessory,
    geometry: 'star',
  ),
  CompanionReward('teal', 'Teal mane', RewardCategory.mane, tint: 'teal'),
  CompanionReward(
    'rainbow',
    'Rainbow wings',
    RewardCategory.wings,
    geometry: 'rainbow',
  ),
  CompanionReward(
    'bow_coral',
    'Coral bow',
    RewardCategory.accessory,
    geometry: 'bow',
    tint: 'coral',
  ),
  CompanionReward('twirl', 'Rainbow twirl', RewardCategory.behavior),
  CompanionReward(
    'butterfly_lavender',
    'Lavender butterfly wings',
    RewardCategory.wings,
    geometry: 'butterfly',
    tint: 'lavender',
  ),
  CompanionReward(
    'polish_gold',
    'Gold polish',
    RewardCategory.polish,
    tint: 'gold',
  ),
  CompanionReward(
    'polish_lavender',
    'Lavender polish',
    RewardCategory.polish,
    tint: 'lavender',
  ),
  CompanionReward(
    'polish_coral',
    'Coral polish',
    RewardCategory.polish,
    tint: 'coral',
  ),
  CompanionReward(
    'polish_teal',
    'Teal polish',
    RewardCategory.polish,
    tint: 'teal',
  ),
];

CompanionReward? companionReward(String? id) {
  if (id == null) return null;
  for (final reward in rewardCatalog) {
    if (reward.id == id) return reward;
  }
  return null;
}

class CompanionConfiguration {
  CompanionConfiguration([Map<RewardCategory, String> equipped = const {}])
    : equipped = Map.unmodifiable(equipped);
  final Map<RewardCategory, String> equipped;
  String? operator [](RewardCategory category) => equipped[category];
}

class RoundRewardResult {
  const RoundRewardResult(this.progress, this.previousLevel);
  final PlayerProgress progress;
  final int previousLevel;
  int get levelsEarned => progress.level - previousLevel;
}

class PlayerProgress {
  PlayerProgress({
    this.xp = 0,
    this.tapChallengeHighScore = 0,
    int? earnedRewardChoices,
    Set<String> owned = const {},
    CompanionConfiguration? companion,
    this.lastRewardedRound,
    this.game2048 = const Game2048Progress(),
    this.writing,
  }) : earnedRewardChoices =
           earnedRewardChoices ??
           min(levelForXp(xp) - 1, legacyRewardIds.length),
       owned = Set.unmodifiable(owned),
       companion = companion ?? CompanionConfiguration();
  final int xp, tapChallengeHighScore, earnedRewardChoices;
  final Set<String> owned;
  final CompanionConfiguration companion;
  final String? lastRewardedRound;
  final Game2048Progress game2048;
  final WritingProgress? writing;
  int get level => levelForXp(xp);
  int get availableChoices => earnedRewardChoices - owned.length;

  /// Credit only newly crossed levels; exhausted catalogs never bank future gifts.
  PlayerProgress awardXp(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, "amount");
    final nextXp = xp + amount;
    return copyWith(
      xp: nextXp,
      earnedRewardChoices: min(
        rewardCatalog.length,
        earnedRewardChoices + levelForXp(nextXp) - level,
      ),
    );
  }

  int get levelXp => xp - xpForLevel(level);
  int get nextLevelXp => xpForLevel(level + 1) - xpForLevel(level);
  List<CompanionReward> get choices => availableChoices <= 0
      ? []
      : rewardCatalog.where((r) => !owned.contains(r.id)).take(3).toList();
  PlayerProgress copyWith({
    int? xp,
    int? tapChallengeHighScore,
    int? earnedRewardChoices,
    Set<String>? owned,
    CompanionConfiguration? companion,
    String? lastRewardedRound,
    Game2048Progress? game2048,
    WritingProgress? writing,
  }) => PlayerProgress(
    xp: xp ?? this.xp,
    tapChallengeHighScore: tapChallengeHighScore ?? this.tapChallengeHighScore,
    earnedRewardChoices: earnedRewardChoices ?? this.earnedRewardChoices,
    owned: owned ?? this.owned,
    companion: companion ?? this.companion,
    lastRewardedRound: lastRewardedRound ?? this.lastRewardedRound,
    game2048: game2048 ?? this.game2048,
    writing: writing ?? this.writing,
  );
  String encode() => jsonEncode({
    'version': 3,
    'earnedRewardChoices': earnedRewardChoices,
    'xp': xp,
    'tapChallengeHighScore': tapChallengeHighScore,
    'owned': owned.toList(),
    'equipped': companion.equipped.map((k, v) => MapEntry(k.name, v)),
    'lastRewardedRound': lastRewardedRound,
    'game2048': game2048.toJson(),
    if (writing != null) 'writing': writing!.toJson(),
  });
  factory PlayerProgress.decode(String document) {
    try {
      final m = jsonDecode(document) as Map<String, dynamic>;
      final version = m['version'];
      if (version != 1 && version != 2 && version != 3)
        throw const FormatException();
      final xp = m['xp'] as int;
      final highScore = version == 3 ? m['tapChallengeHighScore'] as int : 0;
      if (version != 3) _validateLegacyAdventure(m, xp);
      final earned = version == 1
          ? min(levelForXp(xp) - 1, legacyRewardIds.length)
          : m['earnedRewardChoices'] as int;
      final rawOwned = (m['owned'] as List).cast<String>();
      final owned = rawOwned.toSet();
      final equipped = (m['equipped'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(RewardCategory.values.byName(k), v as String),
      );
      final last = m['lastRewardedRound'] as String?;
      final game2048 = m.containsKey('game2048')
          ? Game2048Progress.fromJson(m['game2048'] as Map<String, dynamic>)
          : const Game2048Progress();
      final writing = m.containsKey('writing')
          ? WritingProgress.fromJson(m['writing'] as Map<String, dynamic>)
          : null;
      if (writing != null && xp < writing.completedPairs * writingPairXp) {
        throw const FormatException();
      }
      if (game2048.session?.won == true && xp < game2048WinXp) {
        throw const FormatException();
      }
      if (xp < 0 ||
          xp % 10 != 0 ||
          highScore < 0 ||
          (highScore > 0 && xp < 50) ||
          owned.length != rawOwned.length ||
          earned < 0 ||
          earned > min(levelForXp(xp) - 1, rewardCatalog.length) ||
          owned.length > earned ||
          (version == 1 && owned.any((id) => !legacyRewardIds.contains(id))) ||
          owned.any((id) => !rewardCatalog.any((r) => r.id == id)) ||
          equipped.entries.any(
            (e) =>
                !owned.contains(e.value) ||
                !rewardCatalog.any(
                  (r) => r.id == e.value && r.category == e.key,
                ),
          ) ||
          (xp > 0 && (last == null || last.isEmpty)))
        throw const FormatException();
      return PlayerProgress(
        xp: xp,
        tapChallengeHighScore: highScore,
        earnedRewardChoices: earned,
        owned: owned,
        companion: CompanionConfiguration(equipped),
        lastRewardedRound: last,
        game2048: game2048,
        writing: writing,
      );
    } catch (_) {
      throw const FormatException('Player progress could not be read.');
    }
  }
}

// Only the upgrade reader knows the retired board format. Validate before
// dropping it so a damaged legacy document still requires explicit recovery.
void _validateLegacyAdventure(Map<String, dynamic> m, int xp) {
  final moves = m['movesTaken'] as int;
  final visits = (m['pendingPlays'] as List).cast<int>();
  final bests = (m['bests'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(int.parse(k), v as int),
  );
  if (moves < 0 ||
      moves > levelForXp(xp) - 1 ||
      visits.toSet().length != visits.length ||
      visits.any((v) => v < 1 || v > moves) ||
      bests.entries.any((e) => e.key < 0 || e.key >= 8 || e.value < 0)) {
    throw const FormatException('Invalid legacy adventure');
  }
  for (var i = 1; i < visits.length; i++) {
    if (visits[i] <= visits[i - 1]) throw const FormatException();
  }
}
