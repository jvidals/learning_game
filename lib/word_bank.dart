import 'letter_sounds.dart';

/// Curated short-vowel CVC content for the reading games. Plain data only.
///
/// Spellings are lowercase, three letters, one short vowel. c and k share
/// /k/; x is two sounds (/k/ + /s/), so its hint plays both. q is excluded.
class DecodableWord {
  const DecodableWord(this.spelling, {this.picture, this.label});

  final String spelling;

  /// Noto emoji used to render `assets/words/<spelling>.png` (real words only).
  final String? picture;

  /// Accessible picture description (real words only).
  final String? label;

  bool get real => picture != null;

  /// Bundled whole-word recording.
  String get clip => real ? 'cvc_$spelling' : 'nonsense_$spelling';

  String? get pictureAsset => real ? 'assets/words/$spelling.png' : null;

  /// One entry per letter, in order; each entry lists the isolated phoneme
  /// clips to play for that letter (x plays two).
  List<List<String>> get letterSounds => [
    for (final letter in spelling.split(''))
      letter == 'x'
          ? [soundFor('k').audio, soundFor('s').audio]
          : [soundFor(letter).audio],
  ];

  String get vowel => spelling[1];
}

/// Real CVC words with unambiguous pictures, grouped by short vowel.
const realWords = <DecodableWord>[
  DecodableWord('cat', picture: '🐈', label: 'a cat'),
  DecodableWord('bat', picture: '🦇', label: 'a bat'),
  DecodableWord('hat', picture: '🎩', label: 'a hat'),
  DecodableWord('rat', picture: '🐀', label: 'a rat'),
  DecodableWord('can', picture: '🥫', label: 'a can'),
  DecodableWord('map', picture: '🗺️', label: 'a map'),
  DecodableWord('man', picture: '👨', label: 'a man'),
  DecodableWord('van', picture: '🚐', label: 'a van'),
  DecodableWord('fan', picture: '🪭', label: 'a fan'),
  DecodableWord('sad', picture: '😢', label: 'a sad face'),
  DecodableWord('mad', picture: '😠', label: 'a mad face'),
  DecodableWord('bed', picture: '🛏️', label: 'a bed'),
  DecodableWord('pen', picture: '🖊️', label: 'a pen'),
  DecodableWord('net', picture: '🥅', label: 'a net'),
  DecodableWord('web', picture: '🕸️', label: 'a web'),
  DecodableWord('leg', picture: '🦵', label: 'a leg'),
  DecodableWord('ten', picture: '🔟', label: 'the number ten'),
  DecodableWord('hen', picture: '🐔', label: 'a hen'),
  DecodableWord('pig', picture: '🐖', label: 'a pig'),
  DecodableWord('pin', picture: '📌', label: 'a pin'),
  DecodableWord('lip', picture: '👄', label: 'lips'),
  DecodableWord('six', picture: '6️⃣', label: 'the number six'),
  DecodableWord('dog', picture: '🐕', label: 'a dog'),
  DecodableWord('log', picture: '🪵', label: 'a log'),
  DecodableWord('hot', picture: '🥵', label: 'a hot face'),
  DecodableWord('fox', picture: '🦊', label: 'a fox'),
  DecodableWord('box', picture: '📦', label: 'a box'),
  DecodableWord('sun', picture: '☀️', label: 'the sun'),
  DecodableWord('bus', picture: '🚌', label: 'a bus'),
  DecodableWord('bug', picture: '🐛', label: 'a bug'),
  DecodableWord('nut', picture: '🥜', label: 'nuts'),
  DecodableWord('hut', picture: '🛖', label: 'a hut'),
  DecodableWord('tub', picture: '🛁', label: 'a tub'),
  DecodableWord('cup', picture: '🥤', label: 'a cup'),
];

/// A printed make-believe word and two spoken foils, each one sound different.
class MakeBelieveItem {
  const MakeBelieveItem(this.target, this.foils);
  final String target;
  final List<String> foils;
}

/// Targets adapted from the school's practice sheet (x, c, real and
/// word-like items removed). Foils change one vowel or one consonant.
const makeBelieveItems = <MakeBelieveItem>[
  MakeBelieveItem('pib', ['pab', 'bip']),
  MakeBelieveItem('teg', ['tog', 'deg']),
  MakeBelieveItem('nef', ['nuf', 'mef']),
  MakeBelieveItem('sog', ['sug', 'zog']),
  MakeBelieveItem('buf', ['bif', 'duf']),
  MakeBelieveItem('wop', ['wep', 'wob']),
  MakeBelieveItem('nad', ['nud', 'nam']),
  MakeBelieveItem('yed', ['yod', 'yeb']),
  MakeBelieveItem('bim', ['bem', 'bik']),
  MakeBelieveItem('rof', ['ruf', 'lof']),
  MakeBelieveItem('dub', ['dib', 'dup']),
  MakeBelieveItem('jav', ['jev', 'jad']),
  MakeBelieveItem('fum', ['fam', 'fup']),
  MakeBelieveItem('duv', ['dav', 'guv']),
  MakeBelieveItem('mef', ['muf', 'nef']),
  MakeBelieveItem('tik', ['tak', 'tib']),
  MakeBelieveItem('puj', ['paj', 'buj']),
  MakeBelieveItem('niv', ['nov', 'miv']),
  MakeBelieveItem('pok', ['pek', 'pog']),
  MakeBelieveItem('koz', ['kez', 'kov']),
  MakeBelieveItem('mig', ['mog', 'mib']),
  MakeBelieveItem('zod', ['zad', 'zob']),
  MakeBelieveItem('vut', ['vit', 'vup']),
  MakeBelieveItem('tes', ['tos', 'tep']),
];

/// Word Sprint only: from the school's Activity 2 and Activity 4 sheets.
/// Hints use letter sounds only; no whole-word recording is required.
const sprintOnlyPretendWords = <DecodableWord>[
  DecodableWord('fod'),
  DecodableWord('hif'),
  DecodableWord('wum'),
  DecodableWord('lif'),
  DecodableWord('nen'),
  DecodableWord('pem'),
  DecodableWord('vab'),
  DecodableWord('nuv'),
  DecodableWord('yez'),
  DecodableWord('pob'),
  DecodableWord('bem'),
  DecodableWord('yuc'),
  DecodableWord('sut'),
  DecodableWord('tef'),
  DecodableWord('jub'),
  DecodableWord('rez'),
  DecodableWord('juf'),
  DecodableWord('bik'),
  DecodableWord('nem'),
  DecodableWord('lix'),
  DecodableWord('wob'),
  DecodableWord('vup'),
  DecodableWord('tuz'),
  DecodableWord('rup'),
  DecodableWord('hos'),
  DecodableWord('fec'),
  DecodableWord('gob'),
  DecodableWord('sis'),
  DecodableWord('bap'),
  DecodableWord('yek'),
  DecodableWord('fon'),
  DecodableWord('nop'),
  DecodableWord('hap'),
  DecodableWord('bef'),
  DecodableWord('din'),
  DecodableWord('lod'),
  DecodableWord('tep'),
  DecodableWord('paz'),
  DecodableWord('gik'),
  DecodableWord('pev'),
  DecodableWord('fab'),
  DecodableWord('neb'),
  DecodableWord('lim'),
  DecodableWord('yik'),
  DecodableWord('min'),
  DecodableWord('pag'),
  DecodableWord('yun'),
  DecodableWord('sid'),
  DecodableWord('tix'),
  DecodableWord('piz'),
  DecodableWord('dax'),
  DecodableWord('roz'),
  DecodableWord('yon'),
  DecodableWord('kim'),
  DecodableWord('tiv'),
  DecodableWord('fez'),
  DecodableWord('ris'),
  DecodableWord('dap'),
  DecodableWord('dod'),
];

/// Every make-believe spelling that needs a recording (targets and foils).
final List<DecodableWord> makeBelieveWords = List.unmodifiable(
  {
    for (final item in makeBelieveItems) ...[item.target, ...item.foils],
  }.map(DecodableWord.new),
);

DecodableWord makeBelieveWord(String spelling) =>
    makeBelieveWords.firstWhere((word) => word.spelling == spelling);

DecodableWord realWord(String spelling) =>
    realWords.firstWhere((word) => word.spelling == spelling);
