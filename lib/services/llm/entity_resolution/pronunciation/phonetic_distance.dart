import 'dart:math';

/// Articulatory phonetic feature distance calculator.
///
/// Implements feature-weighted phoneme edit distance rather than raw character
/// Levenshtein, reflecting acoustic confusions in Speech-to-Text models.
class PhoneticDistance {
  // Acoustic / Phonetic character classes
  static const _plosives = {'P', 'B', 'T', 'D', 'K', 'G', 'C', 'Q'};
  static const _fricatives = {'F', 'V', 'S', 'Z', 'X', 'H', 'J'};
  static const _nasals = {'M', 'N'};
  static const _liquids = {'L', 'R', 'W', 'Y'};
  static const _vowels = {'A', 'E', 'I', 'O', 'U'};

  /// Computes feature-weighted edit distance between two phonetic representation strings.
  ///
  /// Returns a cost value $\ge 0.0$.
  static double distance(String a, String b) {
    if (a == b) return 0.0;
    if (a.isEmpty) return b.length.toDouble();
    if (b.isEmpty) return a.length.toDouble();

    final s1 = a.toUpperCase();
    final s2 = b.toUpperCase();
    final n = s1.length;
    final m = s2.length;

    // DP matrix
    final dp = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0.0));

    for (var i = 0; i <= n; i++) {
      dp[i][0] = i * 1.0;
    }
    for (var j = 0; j <= m; j++) {
      dp[0][j] = j * 1.0;
    }

    for (var i = 1; i <= n; i++) {
      final c1 = s1[i - 1];
      for (var j = 1; j <= m; j++) {
        final c2 = s2[j - 1];

        final subCost = _substitutionCost(c1, c2);
        final deleteCost = _deletionCost(c1);
        final insertCost = _insertionCost(c2);

        dp[i][j] = min(
          dp[i - 1][j] + deleteCost,
          min(
            dp[i][j - 1] + insertCost,
            dp[i - 1][j - 1] + subCost,
          ),
        );
      }
    }

    return dp[n][m];
  }

  /// Computes normalized phonetic similarity in [0.0, 1.0].
  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

    final dist = distance(a, b);
    final maxLen = max(a.length, b.length).toDouble();
    if (maxLen == 0) return 1.0;

    final score = 1.0 - (dist / maxLen);
    return score.clamp(0.0, 1.0);
  }

  /// Calculates substitution cost based on acoustic & articulatory features.
  static double _substitutionCost(String c1, String c2) {
    if (c1 == c2) return 0.0;

    // Both vowels: slight acoustic timbre shift
    if (_vowels.contains(c1) && _vowels.contains(c2)) {
      // Near-homophone vowels (e.g. E <-> I, A <-> O, U <-> O)
      if ((c1 == 'E' && c2 == 'I') || (c1 == 'I' && c2 == 'E')) return 0.15;
      if ((c1 == 'A' && c2 == 'O') || (c1 == 'O' && c2 == 'A')) return 0.20;
      if ((c1 == 'A' && c2 == 'E') || (c1 == 'E' && c2 == 'A')) return 0.20;
      if ((c1 == 'U' && c2 == 'O') || (c1 == 'O' && c2 == 'U')) return 0.20;
      return 0.30;
    }

    // Both plosives (voicing or place shift, e.g. T <-> D, K <-> G, P <-> B)
    if (_plosives.contains(c1) && _plosives.contains(c2)) {
      if ((c1 == 'T' && c2 == 'D') || (c1 == 'D' && c2 == 'T')) return 0.15;
      if ((c1 == 'K' && c2 == 'G') || (c1 == 'G' && c2 == 'K')) return 0.20;
      if ((c1 == 'P' && c2 == 'B') || (c1 == 'B' && c2 == 'P')) return 0.20;
      if ((c1 == 'K' && c2 == 'C') || (c1 == 'C' && c2 == 'K')) return 0.05;
      return 0.40;
    }

    // Both fricatives/sibilants (e.g. S <-> Z, S <-> X, F <-> V)
    if (_fricatives.contains(c1) && _fricatives.contains(c2)) {
      if ((c1 == 'S' && c2 == 'Z') || (c1 == 'Z' && c2 == 'S')) return 0.10;
      if ((c1 == 'F' && c2 == 'V') || (c1 == 'V' && c2 == 'F')) return 0.15;
      if ((c1 == 'S' && c2 == 'X') || (c1 == 'X' && c2 == 'S')) return 0.20;
      if ((c1 == 'Z' && c2 == 'J') || (c1 == 'J' && c2 == 'Z')) return 0.25;
      return 0.35;
    }

    // Both nasals (M <-> N)
    if (_nasals.contains(c1) && _nasals.contains(c2)) {
      return 0.20;
    }

    // Both liquids / glides (L <-> R, W <-> Y)
    if (_liquids.contains(c1) && _liquids.contains(c2)) {
      if ((c1 == 'L' && c2 == 'R') || (c1 == 'R' && c2 == 'L')) return 0.30;
      if ((c1 == 'W' && c2 == 'V') || (c1 == 'V' && c2 == 'W')) return 0.20;
      return 0.40;
    }

    // Acoustic cross-class confusions (e.g. X <-> K S, C <-> S)
    if ((c1 == 'C' && c2 == 'S') || (c1 == 'S' && c2 == 'C')) return 0.15;
    if ((c1 == 'X' && c2 == 'K') || (c1 == 'K' && c2 == 'X')) return 0.25;

    // Vowel vs Consonant: high acoustic distance
    if ((_vowels.contains(c1) && !_vowels.contains(c2)) || (!_vowels.contains(c1) && _vowels.contains(c2))) {
      return 1.0;
    }

    return 0.70;
  }

  static double _deletionCost(String c) {
    if (_vowels.contains(c)) return 0.6; // unstressed vowels frequently dropped
    if (c == 'H' || c == 'W' || c == 'Y') return 0.5; // weak glides
    return 0.85;
  }

  static double _insertionCost(String c) {
    if (_vowels.contains(c)) return 0.6;
    if (c == 'H' || c == 'W' || c == 'Y') return 0.5;
    return 0.85;
  }
}
