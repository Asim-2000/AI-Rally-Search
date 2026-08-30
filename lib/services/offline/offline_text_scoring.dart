import 'dart:math';

/// Deterministic, model-free text normalization and similarity scoring for the
/// offline entity resolver.
///
/// This is a fresh, self-contained port of the deterministic entity-scoring
/// maths used by the authoritative online pipeline
/// (`backend/app/entity_search/{normalization,scorer}.py`). It intentionally does
/// NOT import any of the forbidden legacy in-app AI/LLM files
/// (`lib/services/llm/*`) — it revives none of that runtime; it only re-expresses
/// the same deterministic algorithm so the offline path matches online scoring.
///
/// Cross-script (Arabic/Urdu) transliteration is out of scope offline: queries
/// arriving offline are Latin-script typed/on-device transcripts. The
/// transliteration branch is therefore inert here (documented limitation).
class OfflineTextScoring {
  const OfflineTextScoring._();

  static const Map<String, String> _diacriticsMap = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ą': 'a', 'ă': 'a', 'æ': 'ae',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e', 'ĕ': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ĭ': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o', 'ŏ': 'o', 'œ': 'oe',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ų': 'u', 'ů': 'u', 'ű': 'u', 'ŭ': 'u',
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
    'ď': 'd', 'đ': 'd', 'ð': 'd',
    'ģ': 'g', 'ğ': 'g', 'ġ': 'g', 'ĝ': 'g',
    'ĥ': 'h', 'ħ': 'h',
    'ĵ': 'j',
    'ķ': 'k',
    'ł': 'l', 'ľ': 'l', 'ĺ': 'l', 'ļ': 'l', 'ŀ': 'l',
    'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ņ': 'n', 'ŉ': 'n', 'ŋ': 'n',
    'ŕ': 'r', 'ř': 'r', 'ŗ': 'r',
    'ś': 's', 'š': 's', 'ș': 's', 'ş': 's', 'ŝ': 's', 'ß': 'ss',
    'ť': 't', 'ț': 't', 'ţ': 't', 'ŧ': 't', 'þ': 'th',
    'ŵ': 'w',
    'ź': 'z', 'ž': 'z', 'ż': 'z', 'ẑ': 'z',
  };

  static final RegExp _descriptorRe =
      RegExp(r'\b(rally|rallies|rallye|rali|rajd|rallijsprints|stages|stage|forestry|championship)\b');
  static final RegExp _yearRe = RegExp(r'\b(19|20)\d{2}\b');

  static String normalize(String input) {
    if (input.isEmpty) return '';
    String text = input.toLowerCase();
    _diacriticsMap.forEach((key, val) {
      if (text.contains(key)) text = text.replaceAll(key, val);
    });
    text = text.replaceAll(RegExp(r"['‘’`´]"), "'");
    text = text.replaceAll(RegExp(r'[-–—]'), ' ');
    text = text.replaceAllMapped(RegExp(r'(\d+)([a-zA-Z]+)'), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAllMapped(RegExp(r'([a-zA-Z]+)(\d+)'), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static String collapseSpaces(String input) => normalize(input).replaceAll(RegExp(r'\s+'), '');

  static String acousticFold(String input) {
    String text = normalize(input);
    if (text.isEmpty) return '';
    text = text.replaceAll('x', 'ks');
    text = text.replaceAll('ph', 'f');
    text = text.replaceAll('ck', 'k');
    text = text.replaceAllMapped(RegExp(r'([b-df-hj-np-tv-z])\1+', caseSensitive: false), (m) => m[1]!);
    return text;
  }

  static String stripYear(String input) => normalize(input)
      .replaceAll(_yearRe, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String stripDescriptors(String input) => stripYear(input)
      .replaceAll(_descriptorRe, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _hasMotorsportDescriptor(String input) => _descriptorRe.hasMatch(normalize(input));

  static int? extractYear(String text) {
    final match = _yearRe.firstMatch(text);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  static double diceBigram(String s1, String s2) {
    final n1 = normalize(s1), n2 = normalize(s2);
    if (n1 == n2) return 1.0;
    if (n1.length < 2 || n2.length < 2) return n1 == n2 ? 1.0 : 0.0;
    final b1 = <String, int>{};
    for (int i = 0; i < n1.length - 1; i++) {
      final bg = n1.substring(i, i + 2);
      b1[bg] = (b1[bg] ?? 0) + 1;
    }
    final b2 = <String, int>{};
    for (int i = 0; i < n2.length - 1; i++) {
      final bg = n2.substring(i, i + 2);
      b2[bg] = (b2[bg] ?? 0) + 1;
    }
    int matches = 0;
    b1.forEach((bg, c1) => matches += min(c1, b2[bg] ?? 0));
    return (2.0 * matches) / ((n1.length - 1) + (n2.length - 1));
  }

  static double diceTrigram(String s1, String s2) {
    final n1 = normalize(s1), n2 = normalize(s2);
    if (n1 == n2) return 1.0;
    if (n1.length < 3 || n2.length < 3) return diceBigram(s1, s2);
    final t1 = <String, int>{};
    for (int i = 0; i < n1.length - 2; i++) {
      final tg = n1.substring(i, i + 3);
      t1[tg] = (t1[tg] ?? 0) + 1;
    }
    final t2 = <String, int>{};
    for (int i = 0; i < n2.length - 2; i++) {
      final tg = n2.substring(i, i + 3);
      t2[tg] = (t2[tg] ?? 0) + 1;
    }
    int matches = 0;
    t1.forEach((tg, c1) => matches += min(c1, t2[tg] ?? 0));
    return (2.0 * matches) / ((n1.length - 2) + (n2.length - 2));
  }

  static double jaroWinkler(String s1, String s2) {
    final n1 = normalize(s1), n2 = normalize(s2);
    if (n1.isEmpty && n2.isEmpty) return 1.0;
    if (n1.isEmpty || n2.isEmpty) return 0.0;
    if (n1 == n2) return 1.0;
    final jaroSim = _jaro(n1, n2);
    if (jaroSim < 0.70) return jaroSim;
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
    final len1 = s1.length, len2 = s2.length;
    final matchDistance = (max(len1, len2) ~/ 2) - 1;
    final s1M = List<bool>.filled(len1, false);
    final s2M = List<bool>.filled(len2, false);
    int matches = 0;
    for (int i = 0; i < len1; i++) {
      final start = max(0, i - matchDistance);
      final end = min(i + matchDistance + 1, len2);
      for (int j = start; j < end; j++) {
        if (s2M[j]) continue;
        if (s1[i] != s2[j]) continue;
        s1M[i] = true;
        s2M[j] = true;
        matches++;
        break;
      }
    }
    if (matches == 0) return 0.0;
    int transpositions = 0, k = 0;
    for (int i = 0; i < len1; i++) {
      if (!s1M[i]) continue;
      while (!s2M[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }
    final m = matches.toDouble();
    return (m / len1 + m / len2 + (m - (transpositions / 2.0)) / m) / 3.0;
  }

  static double normalizedLevenshtein(String s1, String s2) {
    final n1 = normalize(s1), n2 = normalize(s2);
    if (n1 == n2) return 1.0;
    if (n1.isEmpty || n2.isEmpty) return 0.0;
    final maxLen = max(n1.length, n2.length);
    return (1.0 - (_levenshtein(n1, n2) / maxLen)).clamp(0.0, 1.0);
  }

  static int _levenshtein(String s1, String s2) {
    final m = s1.length, n = s2.length;
    List<int> prev = List<int>.generate(n + 1, (i) => i);
    List<int> curr = List<int>.filled(n + 1, 0);
    for (int i = 0; i < m; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < n; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = min(curr[j] + 1, min(prev[j + 1] + 1, prev[j] + cost));
      }
      prev = List<int>.from(curr);
    }
    return prev[n];
  }

  static double tokenSetSimilarity(String s1, String s2) {
    final set1 = normalize(s1).split(' ').where((w) => w.isNotEmpty).toSet();
    final set2 = normalize(s2).split(' ').where((w) => w.isNotEmpty).toSet();
    if (set1.isEmpty || set2.isEmpty) return 0.0;
    return set1.intersection(set2).length / set1.union(set2).length;
  }

  static String soundex(String s) {
    final clean = normalize(s).replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.isEmpty) return '';
    final first = clean[0].toUpperCase();
    const codeMap = {
      'b': '1', 'f': '1', 'p': '1', 'v': '1',
      'c': '2', 'g': '2', 'j': '2', 'k': '2', 'q': '2', 's': '2', 'x': '2', 'z': '2',
      'd': '3', 't': '3', 'l': '4', 'm': '5', 'n': '5', 'r': '6',
    };
    final out = StringBuffer()..write(first);
    String lastCode = codeMap[clean[0]] ?? '0';
    for (int i = 1; i < clean.length && out.length < 4; i++) {
      final code = codeMap[clean[i]] ?? '0';
      if (code != '0' && code != lastCode) out.write(code);
      lastCode = code;
    }
    while (out.length < 4) {
      out.write('0');
    }
    return out.toString();
  }

  static double _applyContextBoosts(double baseScore, {int? queryYear, int? candidateYear, bool inContext = false}) {
    double score = baseScore;
    if (queryYear != null && candidateYear != null) {
      if (queryYear == candidateYear) {
        score += 0.20;
      } else {
        score = min(score * 0.40, 0.35);
      }
    }
    if (inContext) score += 0.15;
    return double.parse(score.clamp(0.0, 1.0).toStringAsFixed(3));
  }

  /// Composite deterministic similarity between a query phrase and a candidate
  /// name. Faithful reproduction of the online `compute_composite_score`.
  static double computeCompositeScore({
    required String queryPhrase,
    required String candidateName,
    int? queryYear,
    int? candidateYear,
    bool inContext = false,
    bool isPerson = false,
  }) {
    final pNorm = normalize(queryPhrase);
    final cNorm = normalize(candidateName);
    if (pNorm.isEmpty || cNorm.isEmpty) return 0.0;

    final qYear = queryYear ?? extractYear(queryPhrase);
    final cYear = candidateYear ?? extractYear(candidateName);
    if (qYear != null && cYear != null && qYear != cYear) return 0.25;

    if (pNorm == cNorm) {
      return _applyContextBoosts(1.0, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }
    final pBase = stripYear(pNorm), cBase = stripYear(cNorm);
    if (pBase == cBase && pBase.isNotEmpty) {
      return _applyContextBoosts(0.96, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }
    final pCollapsed = collapseSpaces(pNorm), cCollapsed = collapseSpaces(cNorm);
    if (pCollapsed == cCollapsed && pCollapsed.isNotEmpty) {
      return _applyContextBoosts(0.95, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }
    final pCore = collapseSpaces(stripDescriptors(pNorm)), cCore = collapseSpaces(stripDescriptors(cNorm));
    if (pCore == cCore && pCore.isNotEmpty) {
      return _applyContextBoosts(0.94, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }
    final pAcoustic = acousticFold(pCollapsed), cAcoustic = acousticFold(cCollapsed);
    final pAcCore = acousticFold(pCore), cAcCore = acousticFold(cCore);
    if ((pAcCore == cAcCore && pAcCore.isNotEmpty) || (pAcoustic == cAcoustic && pAcoustic.isNotEmpty)) {
      return _applyContextBoosts(0.93, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }

    final pTokens = pNorm.split(' ').where((w) => w.isNotEmpty).toList();
    final cTokens = cNorm.split(' ').where((w) => w.isNotEmpty).toList();
    final hasMotorsportWords = _hasMotorsportDescriptor(queryPhrase) || _hasMotorsportDescriptor(candidateName);
    double lexicalScore = 0.0;

    double tokenWindowScore = 0.0;
    if (pTokens.isNotEmpty && cTokens.isNotEmpty) {
      final pTokensCore = pTokens.where((t) => !_hasMotorsportDescriptor(t)).toList();
      final cTokensCore = cTokens.where((t) => !_hasMotorsportDescriptor(t)).toList();
      final queryTokens = pTokensCore.isNotEmpty ? pTokensCore : pTokens;
      final candTokens = cTokensCore.isNotEmpty ? cTokensCore : cTokens;
      if (queryTokens.length == 1) {
        final q = queryTokens.first;
        for (final ct in candTokens) {
          if (ct.length >= 3 && q.length >= 3) {
            final sim = (0.55 * jaroWinkler(q, ct)) + (0.30 * normalizedLevenshtein(q, ct)) + (0.15 * diceBigram(q, ct));
            tokenWindowScore = max(tokenWindowScore, sim);
          }
        }
      } else if (queryTokens.length <= candTokens.length) {
        final windowSize = queryTokens.length;
        for (int i = 0; i <= candTokens.length - windowSize; i++) {
          final window = candTokens.sublist(i, i + windowSize).join(' ');
          final qStr = queryTokens.join(' ');
          final sim = (0.55 * jaroWinkler(qStr, window)) + (0.30 * normalizedLevenshtein(qStr, window)) + (0.15 * diceBigram(qStr, window));
          tokenWindowScore = max(tokenWindowScore, sim);
        }
      }
      if (queryTokens.length >= 2) {
        final qAcoustic = acousticFold(collapseSpaces(queryTokens.join(' ')));
        for (final ct in candTokens) {
          if (ct.length >= 4) {
            final ctAcoustic = acousticFold(ct);
            final acSim = (0.50 * jaroWinkler(qAcoustic, ctAcoustic)) + (0.30 * normalizedLevenshtein(qAcoustic, ctAcoustic)) + (0.20 * diceBigram(qAcoustic, ctAcoustic));
            tokenWindowScore = max(tokenWindowScore, acSim * 0.95);
          }
        }
      }
    }

    const genSuffixes = {'jnr', 'snr', 'jr', 'sr', 'ii', 'iii', 'iv'};
    final cleanPTokens = pTokens.where((t) => !genSuffixes.contains(t)).toList();
    final cleanCTokens = cTokens.where((t) => !genSuffixes.contains(t)).toList();

    if (isPerson && !hasMotorsportWords && cleanPTokens.length >= 2 && cleanCTokens.length >= 2) {
      final firstCombined = (0.50 * jaroWinkler(cleanPTokens.first, cleanCTokens.first)) +
          (0.30 * normalizedLevenshtein(cleanPTokens.first, cleanCTokens.first)) +
          (0.20 * diceBigram(cleanPTokens.first, cleanCTokens.first));
      final pSur = cleanPTokens.last, cSur = cleanCTokens.last;
      double surCombined;
      if (cSur == pSur) {
        surCombined = 1.0;
      } else if (cSur.contains(pSur) || pSur.contains(cSur)) {
        surCombined = 0.95;
      } else {
        final standardSur = (0.50 * jaroWinkler(pSur, cSur)) + (0.30 * normalizedLevenshtein(pSur, cSur)) + (0.20 * diceBigram(pSur, cSur));
        final acousticSur = (0.50 * jaroWinkler(acousticFold(pSur), acousticFold(cSur))) + (0.50 * normalizedLevenshtein(acousticFold(pSur), acousticFold(cSur)));
        surCombined = max(standardSur, acousticSur * 0.95);
      }
      if (surCombined < 0.78) {
        lexicalScore = min(0.55, firstCombined * surCombined);
      } else if (firstCombined < 0.75) {
        lexicalScore = min(0.60, (0.60 * surCombined) + (0.40 * firstCombined));
      } else {
        lexicalScore = (0.65 * surCombined) + (0.35 * firstCombined);
      }
    } else if (isPerson && !hasMotorsportWords && cleanPTokens.length == 1 && cleanCTokens.length >= 2) {
      final qToken = cleanPTokens.first, surToken = cleanCTokens.last;
      final surCombined = (0.50 * jaroWinkler(qToken, surToken)) + (0.30 * normalizedLevenshtein(qToken, surToken)) + (0.20 * diceBigram(qToken, surToken));
      if (surCombined >= 0.80 || surToken == qToken) {
        lexicalScore = max(lexicalScore, surCombined * 0.90);
      }
    } else {
      final jw = jaroWinkler(pNorm, cNorm);
      final lev = normalizedLevenshtein(pNorm, cNorm);
      final dice = diceBigram(pNorm, cNorm);
      final triDice = diceTrigram(pNorm, cNorm);
      final tokenSim = tokenSetSimilarity(pNorm, cNorm);
      final jwBase = jaroWinkler(pBase, cBase);
      final levBase = normalizedLevenshtein(pBase, cBase);
      final diceBase = diceBigram(pBase, cBase);
      final jwCore = (pCore.isNotEmpty && cCore.isNotEmpty) ? jaroWinkler(pCore, cCore) : 0.0;
      final levCore = (pCore.isNotEmpty && cCore.isNotEmpty) ? normalizedLevenshtein(pCore, cCore) : 0.0;
      final diceCore = (pCore.isNotEmpty && cCore.isNotEmpty) ? diceBigram(pCore, cCore) : 0.0;
      final jwCollapsed = jaroWinkler(pCollapsed, cCollapsed);
      final diceCollapsed = diceBigram(pCollapsed, cCollapsed);
      final acousticScore = (0.50 * jaroWinkler(pAcoustic, cAcoustic)) + (0.30 * normalizedLevenshtein(pAcoustic, cAcoustic)) + (0.20 * diceBigram(pAcoustic, cAcoustic));
      final acCoreScore = (pAcCore.isNotEmpty && cAcCore.isNotEmpty)
          ? (0.50 * jaroWinkler(pAcCore, cAcCore)) + (0.30 * normalizedLevenshtein(pAcCore, cAcCore)) + (0.20 * diceBigram(pAcCore, cAcCore))
          : 0.0;
      final soundexBonus = (soundex(pNorm) == soundex(cNorm) && soundex(pNorm).isNotEmpty) ? 0.03 : 0.0;
      double containmentBonus = 0.0;
      if (pTokens.length == 1 || cTokens.length == 1) {
        if (cNorm.startsWith(pNorm) || pNorm.startsWith(cNorm) || cBase.startsWith(pBase) || pBase.startsWith(cBase)) {
          containmentBonus = 0.12;
        } else if (cNorm.contains(pNorm) || cBase.contains(pBase)) {
          containmentBonus = 0.08 * (pNorm.length / cNorm.length.clamp(1, 100));
        }
      }
      final fullScore = (0.35 * jw) + (0.25 * lev) + (0.20 * dice) + (0.10 * triDice) + (0.10 * tokenSim) + soundexBonus + containmentBonus;
      final baseScore = (0.45 * jwBase) + (0.30 * levBase) + (0.25 * diceBase);
      final coreScore = (0.45 * jwCore) + (0.30 * levCore) + (0.25 * diceCore);
      final collapsedScore = (0.60 * jwCollapsed) + (0.40 * diceCollapsed);
      lexicalScore = max(fullScore,
          max(baseScore, max(coreScore, max(collapsedScore * 0.90, max(tokenWindowScore * 0.98, max(acousticScore * 0.92, acCoreScore * 0.94))))));
    }

    lexicalScore = lexicalScore.clamp(0.0, 1.0);
    if (lexicalScore >= 0.45) {
      return _applyContextBoosts(lexicalScore, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }
    return double.parse(lexicalScore.toStringAsFixed(3));
  }
}
