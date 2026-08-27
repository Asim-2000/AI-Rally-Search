import 'dart:math';

enum CorruptionDifficulty { easy, medium, hard }

class CorruptionCase {
  final String kind;
  final String value;
  final CorruptionDifficulty difficulty;
  const CorruptionCase(this.kind, this.value, this.difficulty);
}

class DeterministicCorruptionGenerator {
  final int seed;
  const DeterministicCorruptionGenerator(this.seed);

  List<CorruptionCase> generate(
    String canonical,
    String stableId, {
    required bool person,
  }) {
    final random = Random(
      seed ^ stableId.codeUnits.fold(0, (a, b) => 31 * a + b),
    );
    final cases = <CorruptionCase>[];
    void add(String kind, String value, CorruptionDifficulty difficulty) {
      value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value.isNotEmpty &&
          value != canonical &&
          !cases.any((c) => c.value == value)) {
        cases.add(CorruptionCase(kind, value, difficulty));
      }
    }

    final editable = _letterPositions(canonical);
    if (editable.isNotEmpty) {
      final i = editable[random.nextInt(editable.length)];
      add(
        'character_deletion',
        canonical.substring(0, i) + canonical.substring(i + 1),
        CorruptionDifficulty.easy,
      );
      add(
        'character_insertion',
        canonical.substring(0, i) + 'x' + canonical.substring(i),
        CorruptionDifficulty.easy,
      );
      add(
        'character_substitution',
        canonical.substring(0, i) +
            _different(canonical[i], 'abcdefghijklmnopqrstuvwxyz', random) +
            canonical.substring(i + 1),
        CorruptionDifficulty.easy,
      );
    }
    final adjacent = <int>[
      for (var i = 0; i < canonical.length - 1; i++)
        if (_isLetter(canonical[i]) &&
            _isLetter(canonical[i + 1]) &&
            canonical[i] != canonical[i + 1])
          i,
    ];
    if (adjacent.isNotEmpty) {
      final i = adjacent[random.nextInt(adjacent.length)];
      add(
        'adjacent_transposition',
        canonical.substring(0, i) +
            canonical[i + 1] +
            canonical[i] +
            canonical.substring(i + 2),
        CorruptionDifficulty.easy,
      );
    }
    add(
      'diacritic_removal',
      _removeDiacritics(canonical),
      CorruptionDifficulty.easy,
    );
    add(
      'hyphen_removal',
      canonical.replaceAll(RegExp(r'[-–—]'), ''),
      CorruptionDifficulty.easy,
    );
    add(
      'apostrophe_removal',
      canonical.replaceAll(RegExp(r"['‘’`]"), ''),
      CorruptionDifficulty.easy,
    );
    add(
      'whitespace_collapse',
      canonical.replaceAll(' ', ''),
      CorruptionDifficulty.medium,
    );
    if (editable.length > 5) {
      final i = editable[editable.length ~/ 2];
      add(
        'whitespace_split',
        canonical.substring(0, i) + ' ' + canonical.substring(i),
        CorruptionDifficulty.medium,
      );
    }
    add(
      'repeated_consonant_reduction',
      canonical.replaceAllMapped(
        RegExp(r'([b-df-hj-np-tv-z])\1+', caseSensitive: false),
        (m) => m[1]!,
      ),
      CorruptionDifficulty.easy,
    );
    add(
      'final_vowel_change',
      _replaceLastMatching(
        canonical,
        RegExp('[aeiouy]', caseSensitive: false),
        (c) => _different(c, 'aeiou', random),
      ),
      CorruptionDifficulty.medium,
    );
    add(
      'vowel_confusion',
      _replaceOne(
        canonical,
        RegExp('[aeiouy]', caseSensitive: false),
        random,
        (c) => _different(c, 'aeiou', random),
      ),
      CorruptionDifficulty.medium,
    );
    add(
      'consonant_confusion',
      _replaceOne(
        canonical,
        RegExp('[b-df-hj-np-tv-z]', caseSensitive: false),
        random,
        (c) => _confuseConsonant(c),
      ),
      CorruptionDifficulty.medium,
    );
    if (person && canonical.trim().split(RegExp(r'\s+')).length > 1) {
      add(
        'token_order_reversal',
        canonical.trim().split(RegExp(r'\s+')).reversed.join(' '),
        CorruptionDifficulty.medium,
      );
    }
    final collapsed = canonical.replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '',
    );
    if (collapsed.length > 6) {
      final split1 = max(1, collapsed.length ~/ 3);
      final split2 = min(collapsed.length - 1, split1 * 2 + 1);
      var stt =
          '${collapsed.substring(0, split1)} ${collapsed.substring(split1, split2)} ${collapsed.substring(split2)}';
      stt = _replaceOne(
        stt,
        RegExp('[aeiouy]', caseSensitive: false),
        random,
        (c) => _different(c, 'aeiou', random),
      );
      add('stt_style_segmentation', stt, CorruptionDifficulty.hard);
    }
    return cases;
  }
}

List<int> _letterPositions(String s) => [
  for (var i = 0; i < s.length; i++)
    if (_isLetter(s[i])) i,
];
bool _isLetter(String c) => RegExp(r'^\p{L}$', unicode: true).hasMatch(c);
String _different(String original, String choices, Random random) {
  var next = choices[random.nextInt(choices.length)];
  while (next.toLowerCase() == original.toLowerCase())
    next = choices[random.nextInt(choices.length)];
  return original == original.toUpperCase() ? next.toUpperCase() : next;
}

String _replaceOne(
  String s,
  RegExp pattern,
  Random random,
  String Function(String) replacement,
) {
  final matches = pattern.allMatches(s).toList();
  if (matches.isEmpty) return s;
  final m = matches[random.nextInt(matches.length)];
  return s.substring(0, m.start) +
      replacement(m.group(0)!) +
      s.substring(m.end);
}

String _replaceLastMatching(
  String s,
  RegExp pattern,
  String Function(String) replacement,
) {
  final matches = pattern.allMatches(s).toList();
  if (matches.isEmpty) return s;
  final m = matches.last;
  return s.substring(0, m.start) +
      replacement(m.group(0)!) +
      s.substring(m.end);
}

String _confuseConsonant(String c) {
  const groups = ['bp', 'dt', 'gkq', 'fv', 'sz', 'cj', 'mn', 'lr'];
  final lower = c.toLowerCase();
  final group = groups.firstWhere((g) => g.contains(lower), orElse: () => 'dt');
  final next = group[(group.indexOf(lower) + 1) % group.length];
  return c == c.toUpperCase() ? next.toUpperCase() : next;
}

String _removeDiacritics(String s) {
  const from =
      'áàâäãåāąăéèêëēėęěíìîïīįóòôöõøōőúùûüūųůűýÿçćčďđģğķłľĺļñńňņŕřśšşťțžźż';
  const to =
      'aaaaaaaaaeeeeeeeeiiiiiiiooooooooouuuuuuuuuyyccccddggkllllnnnnrrsssttzzz';
  var result = s;
  for (var i = 0; i < from.length; i++)
    result = result
        .replaceAll(from[i], to[i])
        .replaceAll(from[i].toUpperCase(), to[i].toUpperCase());
  return result;
}
