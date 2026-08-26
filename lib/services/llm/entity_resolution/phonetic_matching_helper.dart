import 'dart:math';
import 'transliteration_helper.dart';

/// Deterministic phonetic, lexical, and string similarity calculator for entity resolution.
class PhoneticMatchingHelper {
  const PhoneticMatchingHelper._();

  /// Comprehensive diacritics mapping for Unicode Latin normalization.
  static const Map<String, String> _diacriticsMap = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ų': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ç': 'c', 'ć': 'c', 'č': 'c',
    'ñ': 'n', 'ń': 'n', 'ň': 'n',
    'š': 's', 'ś': 's', 'ș': 's',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
    'ř': 'r', 'ŕ': 'r',
    'ł': 'l', 'ľ': 'l',
    'ď': 'd', 'đ': 'd',
    'ť': 't', 'ț': 't',
  };

  /// Normalizes Unicode string: removes diacritics, strips punctuation, folds case across all scripts.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    String text = input.toLowerCase();

    // Map common Latin diacritics
    _diacriticsMap.forEach((key, val) {
      if (text.contains(key)) {
        text = text.replaceAll(key, val);
      }
    });

    // Remove punctuation & symbols across all Unicode scripts
    text = text.replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), ' ');
    // Collapse multiple whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Removes all whitespace for word-boundary collapsed comparisons.
  static String collapseSpaces(String input) {
    return normalize(input).replaceAll(RegExp(r'\s+'), '');
  }

  /// Strips 4-digit years from entity names.
  static String stripYear(String input) {
    return normalize(input)
        .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Strips generic motorsport descriptors (rally, stages, etc.) and country names to extract core entity stem.
  static String stripDescriptors(String input) {
    return stripYear(input)
        .replaceAll(RegExp(r'\b(rally|rallies|stages|stage|forestry|championship|forest|winter|summer|international|national|ireland|portugal|france|spain|germany|austria|italy|norway|sweden|finland|uk|britain)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _hasMotorsportDescriptor(String input) {
    return RegExp(r'\b(rally|rallies|stages|stage|forestry|championship|forest|winter|summer|international|national)\b')
        .hasMatch(normalize(input));
  }

  /// Calculates Jaro-Winkler similarity between two strings (0.0 to 1.0).
  static double jaroWinkler(String s1, String s2) {
    final n1 = normalize(s1);
    final n2 = normalize(s2);

    if (n1.isEmpty && n2.isEmpty) return 1.0;
    if (n1.isEmpty || n2.isEmpty) return 0.0;
    if (n1 == n2) return 1.0;

    final jaroSim = _jaro(n1, n2);
    if (jaroSim < 0.70) return jaroSim;

    // Winkler prefix bonus (up to 4 matching prefix chars, scale factor p=0.1)
    int prefixLen = 0;
    final maxPrefix = min(4, min(n1.length, n2.length));
    for (int i = 0; i < maxPrefix; i++) {
      if (n1[i] == n2[i]) {
        prefixLen++;
      } else {
        break;
      }
    }

    return jaroSim + (prefixLen * 0.1 * (1.0 - jaroSim));
  }

  static double _jaro(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    final matchDistance = (max(len1, len2) ~/ 2) - 1;

    final s1Matches = List<bool>.filled(len1, false);
    final s2Matches = List<bool>.filled(len2, false);

    int matches = 0;
    for (int i = 0; i < len1; i++) {
      final start = max(0, i - matchDistance);
      final end = min(i + matchDistance + 1, len2);

      for (int j = start; j < end; j++) {
        if (s2Matches[j]) continue;
        if (s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    int transpositions = 0;
    int k = 0;
    for (int i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) {
        transpositions++;
      }
      k++;
    }

    final m = matches.toDouble();
    return (m / len1 + m / len2 + (m - (transpositions / 2.0)) / m) / 3.0;
  }

  /// Calculates Normalized Levenshtein similarity (0.0 to 1.0).
  static double normalizedLevenshtein(String s1, String s2) {
    final n1 = normalize(s1);
    final n2 = normalize(s2);

    if (n1 == n2) return 1.0;
    if (n1.isEmpty || n2.isEmpty) return 0.0;

    final maxLen = max(n1.length, n2.length);
    final dist = _levenshteinDistance(n1, n2);
    return (1.0 - (dist / maxLen)).clamp(0.0, 1.0);
  }

  static int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;

    List<int> prev = List<int>.generate(n + 1, (i) => i);
    List<int> curr = List<int>.filled(n + 1, 0);

    for (int i = 0; i < m; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < n; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1,
          min(
            prev[j + 1] + 1,
            prev[j] + cost,
          ),
        );
      }
      prev = List<int>.from(curr);
    }

    return prev[n];
  }

  /// Token Set Jaccard similarity.
  static double tokenSetSimilarity(String s1, String s2) {
    final n1 = normalize(s1);
    final n2 = normalize(s2);

    final set1 = n1.split(' ').where((w) => w.isNotEmpty).toSet();
    final set2 = n2.split(' ').where((w) => w.isNotEmpty).toSet();

    if (set1.isEmpty || set2.isEmpty) return 0.0;
    final intersection = set1.intersection(set2);
    final union = set1.union(set2);

    return intersection.length / union.length;
  }

  /// Simple Soundex encoder for weak tiebreaking.
  static String soundex(String s) {
    final clean = normalize(s).replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.isEmpty) return '';

    final first = clean[0].toUpperCase();
    final codeMap = {
      'b': '1', 'f': '1', 'p': '1', 'v': '1',
      'c': '2', 'g': '2', 'j': '2', 'k': '2', 'q': '2', 's': '2', 'x': '2', 'z': '2',
      'd': '3', 't': '3',
      'l': '4',
      'm': '5', 'n': '5',
      'r': '6',
    };

    final out = StringBuffer()..write(first);
    String lastCode = codeMap[clean[0]] ?? '0';

    for (int i = 1; i < clean.length && out.length < 4; i++) {
      final code = codeMap[clean[i]] ?? '0';
      if (code != '0' && code != lastCode) {
        out.write(code);
      }
      lastCode = code;
    }

    while (out.length < 4) {
      out.write('0');
    }

    return out.toString();
  }

  /// Computes composite deterministic similarity score between query phrase and canonical candidate.
  static double computeCompositeScore({
    required String queryPhrase,
    required String candidateName,
    int? queryYear,
    int? candidateYear,
    bool inContext = false,
  }) {
    final pNorm = normalize(queryPhrase);
    final cNorm = normalize(candidateName);

    if (pNorm.isEmpty || cNorm.isEmpty) return 0.0;

    // 1. Exact string match
    if (pNorm == cNorm) {
      return _applyContextBoosts(1.0, queryYear: queryYear, candidateYear: candidateYear, inContext: inContext);
    }

    // 2. Base name exact match (ignoring years)
    final pBase = stripYear(pNorm);
    final cBase = stripYear(cNorm);
    if (pBase == cBase && pBase.isNotEmpty) {
      return _applyContextBoosts(0.95, queryYear: queryYear, candidateYear: candidateYear, inContext: inContext);
    }

    // 3. Core descriptor stripped match (e.g. "West Cork Rally" == "West Cork", "Mid Ulster Stages" == "Mid Ulster")
    final pCore = collapseSpaces(stripDescriptors(pNorm));
    final cCore = collapseSpaces(stripDescriptors(cNorm));
    if (pCore == cCore && pCore.isNotEmpty) {
      return _applyContextBoosts(0.94, queryYear: queryYear, candidateYear: candidateYear, inContext: inContext);
    }

    // 4. Collapsed-space exact match or exact containment of collapsed stem (e.g. "Westcork" inside "Clonakilty Park Hotel West Cork Rally 2025")
    final pCollapsed = collapseSpaces(pNorm);
    final cCollapsed = collapseSpaces(cNorm);
    if (pCollapsed == cCollapsed && pCollapsed.isNotEmpty) {
      return _applyContextBoosts(0.94, queryYear: queryYear, candidateYear: candidateYear, inContext: inContext);
    }
    if (pCollapsed.length >= 6 && (cCollapsed.contains(pCollapsed) || (cCore.isNotEmpty && cCore.contains(pCore)))) {
      return _applyContextBoosts(0.94, queryYear: queryYear, candidateYear: candidateYear, inContext: inContext);
    }

    // 5. Cross-script transliteration match (Arabic/Urdu -> Latin)
    double transliterationScore = 0.0;
    if (TransliterationHelper.isArabicOrUrdu(queryPhrase)) {
      final latinVariants = TransliterationHelper.transliterateToLatin(queryPhrase);
      for (final variant in latinVariants) {
        final vNorm = normalize(variant);
        final vBaseNorm = stripYear(vNorm);
        final vCore = collapseSpaces(stripDescriptors(vNorm));
        final vCollapsed = collapseSpaces(variant);

        if (vNorm == cNorm || vBaseNorm == cBase || (vCore == cCore && vCore.isNotEmpty)) {
          transliterationScore = max(transliterationScore, 0.94);
        } else if (vCollapsed == cCollapsed || (vCollapsed.length >= 6 && cCollapsed.contains(vCollapsed))) {
          transliterationScore = max(transliterationScore, 0.93);
        } else {
          final jw = jaroWinkler(vNorm, cNorm);
          final lev = normalizedLevenshtein(vNorm, cNorm);
          final jwBase = jaroWinkler(vBaseNorm, cBase);
          final jwCore = (vCore.isNotEmpty && cCore.isNotEmpty) ? jaroWinkler(vCore, cCore) : 0.0;
          final jwCollapsed = jaroWinkler(vCollapsed, cCollapsed);

          final sim = max(
            max(jw * 0.5 + lev * 0.5, jwBase * 0.9),
            max(jwCore * 0.9, jwCollapsed * 0.85),
          );
          transliterationScore = max(transliterationScore, sim);
        }
      }
    }

    final pTokens = pNorm.split(' ').where((w) => w.isNotEmpty).toList();
    final cTokens = cNorm.split(' ').where((w) => w.isNotEmpty).toList();
    final hasMotorsportWords = _hasMotorsportDescriptor(queryPhrase) || _hasMotorsportDescriptor(candidateName);

    double lexicalScore = 0.0;

    // 6. Multi-token person name alignment scoring (First name + Surname separation for drivers without descriptors)
    if (!hasMotorsportWords && pTokens.length >= 2 && cTokens.length >= 2) {
      final firstJw = jaroWinkler(pTokens.first, cTokens.first);
      final firstLev = normalizedLevenshtein(pTokens.first, cTokens.first);
      final firstCombined = (0.60 * firstJw) + (0.40 * firstLev);

      final surJw = jaroWinkler(pTokens.last, cTokens.last);
      final surLev = normalizedLevenshtein(pTokens.last, cTokens.last);
      final surCombined = (0.60 * surJw) + (0.40 * surLev);

      if (firstCombined < 0.70 || surCombined < 0.70) {
        lexicalScore = firstCombined * surCombined;
      } else {
        lexicalScore = (0.50 * surCombined) + (0.50 * firstCombined);
      }
    } else {
      // 7. General Lexical & Phonetic composite calculation for rallies, stages, locations
      final jw = jaroWinkler(pNorm, cNorm);
      final lev = normalizedLevenshtein(pNorm, cNorm);
      final tokenSim = tokenSetSimilarity(pNorm, cNorm);
      final jwBase = jaroWinkler(pBase, cBase);
      final levBase = normalizedLevenshtein(pBase, cBase);
      final jwCore = (pCore.isNotEmpty && cCore.isNotEmpty) ? jaroWinkler(pCore, cCore) : 0.0;
      final levCore = (pCore.isNotEmpty && cCore.isNotEmpty) ? normalizedLevenshtein(pCore, cCore) : 0.0;
      final jwCollapsed = jaroWinkler(pCollapsed, cCollapsed);

      final soundexBonus = (soundex(pNorm) == soundex(cNorm) && soundex(pNorm).isNotEmpty) ? 0.03 : 0.0;

      double containmentBonus = 0.0;
      if (pTokens.length == 1 || cTokens.length == 1) {
        if (cNorm.startsWith(pNorm) || pNorm.startsWith(cNorm) || cBase.startsWith(pBase) || pBase.startsWith(cBase)) {
          containmentBonus = 0.15;
        } else if (cNorm.contains(pNorm) || cBase.contains(pBase)) {
          containmentBonus = 0.10 * (pNorm.length / cNorm.length.clamp(1, 100));
        }
      }

      lexicalScore = max(
        (0.40 * jw) + (0.30 * lev) + (0.15 * tokenSim) + (0.10 * jwCollapsed) + soundexBonus + containmentBonus,
        max(
          (0.60 * jwBase) + (0.40 * levBase),
          (0.60 * jwCore) + (0.40 * levCore),
        ),
      );
    }

    if (transliterationScore > lexicalScore) {
      lexicalScore = transliterationScore;
    }

    lexicalScore = lexicalScore.clamp(0.0, 1.0);

    // 8. Contextual Boosts (Year match, Participation in event)
    if (lexicalScore >= 0.50) {
      return _applyContextBoosts(lexicalScore, queryYear: queryYear, candidateYear: candidateYear, inContext: inContext);
    }

    return double.parse(lexicalScore.toStringAsFixed(3));
  }

  static double _applyContextBoosts(
    double baseScore, {
    int? queryYear,
    int? candidateYear,
    bool inContext = false,
  }) {
    double score = baseScore;

    // Contextual year alignment boost / penalty
    if (queryYear != null && candidateYear != null) {
      if (queryYear == candidateYear) {
        score += 0.20;
      } else {
        score -= 0.25;
      }
    }

    // Contextual event participation boost (+0.15)
    if (inContext) {
      score += 0.15;
    }

    return double.parse(score.clamp(0.0, 1.0).toStringAsFixed(3));
  }
}
