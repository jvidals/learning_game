/// Bundled content; stable IDs are also used in saved settings.
enum SightWordPack {
  pack1(['the', 'a', 'see', 'I', 'to', 'by', 'my', 'go']),
  pack2([
    'is',
    'no',
    'you',
    'has',
    'he',
    'she',
    'put',
    'me',
    'with',
    'good',
    'his',
    'very',
    'her',
  ]),
  pack3([
    'here',
    'of',
    'are',
    'was',
    'be',
    'do',
    'look',
    'want',
    'for',
    'they',
    'too',
    'have',
    'some',
    'we',
    'more',
    'or',
    'where',
    'come',
    'from',
    'as',
    'that',
    'our',
  ]);

  const SightWordPack(this.words);
  final List<String> words;
  String get title => 'Pack ${index + 1}';
}

/// Immutable, nonempty selection. UI drafts may be empty until validated.
class SightWordPacks {
  factory SightWordPacks(Iterable<SightWordPack> packs) {
    final selection = Set<SightWordPack>.unmodifiable(packs);
    if (selection.isEmpty) {
      throw ArgumentError('Choose at least one pack.');
    }
    return SightWordPacks._(selection);
  }

  const SightWordPacks._(this.enabled);
  static const defaults = SightWordPacks._({SightWordPack.pack1});
  final Set<SightWordPack> enabled;

  List<String> get words => List.unmodifiable([
    for (final pack in SightWordPack.values)
      if (enabled.contains(pack)) ...pack.words,
  ]);

  List<String> toList() => [
    for (final pack in SightWordPack.values)
      if (enabled.contains(pack)) pack.name,
  ];

  factory SightWordPacks.fromValue(Object? value) {
    if (value == null) return defaults;
    if (value is! List ||
        value.isEmpty ||
        value.any(
          (id) => !SightWordPack.values.any((pack) => pack.name == id),
        )) {
      throw const FormatException('Invalid sight word packs');
    }
    return SightWordPacks(
      value.map(
        (id) => SightWordPack.values.firstWhere((pack) => pack.name == id),
      ),
    );
  }
}
