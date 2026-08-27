import 'dart:math';
import 'transliteration_helper.dart';

/// Deterministic phonetic, lexical, and string similarity calculator for entity resolution.
class PhoneticMatchingHelper {
  const PhoneticMatchingHelper._();

  /// Comprehensive diacritics mapping for all European Unicode Latin scripts
  /// (Baltic, Slavic, Nordic, Germanic, Romance, Hungarian, Celtic).
  static const Map<String, String> _diacriticsMap = {
    // Vowels
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ą': 'a', 'ă': 'a', 'æ': 'ae',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e', 'ĕ': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ĭ': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o', 'ŏ': 'o', 'œ': 'oe',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ų': 'u', 'ů': 'u', 'ű': 'u', 'ŭ': 'u',
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    // Consonants
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

  /// Normalizes Unicode string: removes diacritics, standardizes apostrophes/hyphens,
  /// strips punctuation, folds case across all scripts.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    String text = input.toLowerCase();

    // Map all European Latin diacritics
    _diacriticsMap.forEach((key, val) {
      if (text.contains(key)) {
        text = text.replaceAll(key, val);
      }
    });

    // Standardize apostrophes & hyphens
    text = text.replaceAll(RegExp(r"['‘’`´]"), "'");
    text = text.replaceAll(RegExp(r'[-–—]'), ' ');

    // Separate digits and letters (e.g. 2powerstage -> 2 powerstage, ss2 -> ss 2)
    text = text.replaceAllMapped(RegExp(r'(\d+)([a-zA-Z]+)'), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAllMapped(RegExp(r'([a-zA-Z]+)(\d+)'), (m) => '${m[1]} ${m[2]}');

    // Remove remaining punctuation & symbols across all Unicode scripts except apostrophe
    text = text.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    // Collapse multiple whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Removes all whitespace for word-boundary collapsed comparisons.
  static String collapseSpaces(String input) {
    return normalize(input).replaceAll(RegExp(r'\s+'), '');
  }

  /// Conservative acoustic and phonetic comparison form.
  /// Standardizes safe, language-general acoustic patterns:
  /// - x -> ks
  /// - ph -> f
  /// - ck -> k
  /// - collapses doubled consonants (e.g. ll -> l, tt -> t, mm -> m, rr -> r, ss -> s, ff -> f, bb -> b, gg -> g, dd -> d)
  /// - strips diacritics and collapses whitespace.
  static String acousticFold(String input) {
    String text = normalize(input);
    if (text.isEmpty) return '';

    // Standardize conservative consonant equivalences
    text = text.replaceAll('x', 'ks');
    text = text.replaceAll('ph', 'f');
    text = text.replaceAll('ck', 'k');

    // Collapse doubled consonants
    text = text.replaceAllMapped(RegExp(r'([b-df-hj-np-tv-z])\1+', caseSensitive: false), (m) => m[1]!);

    return text;
  }

  /// Generates bounded internal character n-grams from distinctive words (length >= n).
  static List<String> generateNgramAnchors(String input, {int n = 3, int maxAnchors = 6}) {
    final clean = collapseSpaces(input);
    if (clean.length < n) return clean.isNotEmpty ? [clean] : [];

    final anchors = <String>{};
    // Include start anchor
    anchors.add(clean.substring(0, n));

    // Internal sliding windows
    for (int i = 1; i <= clean.length - n && anchors.length < maxAnchors - 1; i++) {
      anchors.add(clean.substring(i, i + n));
    }

    // Include end anchor if room
    if (clean.length >= n && anchors.length < maxAnchors) {
      anchors.add(clean.substring(clean.length - n));
    }

    return anchors.take(maxAnchors).toList();
  }

  /// Strips 4-digit years from entity names.
  static String stripYear(String input) {
    return normalize(input)
        .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// CONSERVATIVE descriptor stripping:
  /// Strips ONLY genuinely generic motorsport descriptors (rally, stages, etc.)
  /// and NEVER language words (de, van, of), location names, or descriptors (international, series).
  static String stripDescriptors(String input) {
    return stripYear(input)
        .replaceAll(RegExp(r'\b(rally|rallies|rallye|rali|rajd|rallijsprints|stages|stage|forestry|championship)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _hasMotorsportDescriptor(String input) {
    return RegExp(r'\b(rally|rallies|rallye|rali|rajd|rallijsprints|stages|stage|forestry|championship)\b')
        .hasMatch(normalize(input));
  }

  /// Character Bigram Dice similarity (0.0 to 1.0).
  static double diceBigram(String s1, String s2) {
    final n1 = normalize(s1);
    final n2 = normalize(s2);

    if (n1 == n2) return 1.0;
    if (n1.length < 2 || n2.length < 2) {
      return n1 == n2 ? 1.0 : 0.0;
    }

    final bigrams1 = <String, int>{};
    for (int i = 0; i < n1.length - 1; i++) {
      final bg = n1.substring(i, i + 2);
      bigrams1[bg] = (bigrams1[bg] ?? 0) + 1;
    }

    int matches = 0;
    final bigrams2 = <String, int>{};
    for (int i = 0; i < n2.length - 1; i++) {
      final bg = n2.substring(i, i + 2);
      bigrams2[bg] = (bigrams2[bg] ?? 0) + 1;
    }

    bigrams1.forEach((bg, count1) {
      final count2 = bigrams2[bg] ?? 0;
      matches += min(count1, count2);
    });

    final total = (n1.length - 1) + (n2.length - 1);
    return (2.0 * matches) / total;
  }

  /// Character Trigram Dice similarity (0.0 to 1.0).
  static double diceTrigram(String s1, String s2) {
    final n1 = normalize(s1);
    final n2 = normalize(s2);

    if (n1 == n2) return 1.0;
    if (n1.length < 3 || n2.length < 3) {
      return diceBigram(s1, s2);
    }

    final trigrams1 = <String, int>{};
    for (int i = 0; i < n1.length - 2; i++) {
      final tg = n1.substring(i, i + 3);
      trigrams1[tg] = (trigrams1[tg] ?? 0) + 1;
    }

    int matches = 0;
    final trigrams2 = <String, int>{};
    for (int i = 0; i < n2.length - 2; i++) {
      final tg = n2.substring(i, i + 3);
      trigrams2[tg] = (trigrams2[tg] ?? 0) + 1;
    }

    trigrams1.forEach((tg, count1) {
      final count2 = trigrams2[tg] ?? 0;
      matches += min(count1, count2);
    });

    final total = (n1.length - 2) + (n2.length - 2);
    return (2.0 * matches) / total;
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
    bool isPerson = false,
  }) {
    final pNorm = normalize(queryPhrase);
    final cNorm = normalize(candidateName);

    if (pNorm.isEmpty || cNorm.isEmpty) return 0.0;

    // Extract explicit 4-digit years from phrase / candidate name if not provided
    final qYear = queryYear ?? extractYear(queryPhrase);
    final cYear = candidateYear ?? extractYear(candidateName);

    // Hard Constraint on Explicit Year Mismatch:
    // If the user explicitly provided a year (e.g. 1999) that mismatches candidate's year (e.g. 2026),
    // fuzzy name similarity MUST NEVER overcome the year mismatch to auto-resolve.
    if (qYear != null && cYear != null && qYear != cYear) {
      return 0.25;
    }

    // 1. Exact string match
    if (pNorm == cNorm) {
      return _applyContextBoosts(1.0, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }

    // 2. Base name exact match (ignoring years)
    final pBase = stripYear(pNorm);
    final cBase = stripYear(cNorm);
    if (pBase == cBase && pBase.isNotEmpty) {
      return _applyContextBoosts(0.96, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }

    // 3. Collapsed-space exact match (e.g. "Westcork" == "West Cork", "Midulster" == "Mid Ulster")
    final pCollapsed = collapseSpaces(pNorm);
    final cCollapsed = collapseSpaces(cNorm);
    if (pCollapsed == cCollapsed && pCollapsed.isNotEmpty) {
      return _applyContextBoosts(0.95, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }

    // 4. Core descriptor stripped match (e.g. "West Cork Rally" == "West Cork", "Mid Ulster Stages" == "Mid Ulster")
    final pCore = collapseSpaces(stripDescriptors(pNorm));
    final cCore = collapseSpaces(stripDescriptors(cNorm));
    if (pCore == cCore && pCore.isNotEmpty) {
      return _applyContextBoosts(0.94, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }

    // 4b. Conservative acoustic folded exact match (e.g. "aluxne" == "aluksne", "kemelberg" == "kemmelberg")
    final pAcoustic = acousticFold(pCollapsed);
    final cAcoustic = acousticFold(cCollapsed);
    final pAcCore = acousticFold(pCore);
    final cAcCore = acousticFold(cCore);
    if ((pAcCore == cAcCore && pAcCore.isNotEmpty) || (pAcoustic == cAcoustic && pAcoustic.isNotEmpty)) {
      return _applyContextBoosts(0.93, queryYear: qYear, candidateYear: cYear, inContext: inContext);
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
          final dice = diceBigram(vNorm, cNorm);
          final jwBase = jaroWinkler(vBaseNorm, cBase);
          final jwCore = (vCore.isNotEmpty && cCore.isNotEmpty) ? jaroWinkler(vCore, cCore) : 0.0;
          final jwCollapsed = jaroWinkler(vCollapsed, cCollapsed);

          final sim = max(
            max((jw * 0.40) + (lev * 0.30) + (dice * 0.30), jwBase * 0.90),
            max(jwCore * 0.90, jwCollapsed * 0.85),
          );
          transliterationScore = max(transliterationScore, sim);
        }
      }
    }

    final pTokens = pNorm.split(' ').where((w) => w.isNotEmpty).toList();
    final cTokens = cNorm.split(' ').where((w) => w.isNotEmpty).toList();
    final hasMotorsportWords = _hasMotorsportDescriptor(queryPhrase) || _hasMotorsportDescriptor(candidateName);

    double lexicalScore = 0.0;

    // 6. Token-window sub-sequence alignment & space-collapsed cross-token alignment
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
            final jw = jaroWinkler(q, ct);
            final lev = normalizedLevenshtein(q, ct);
            final dice = diceBigram(q, ct);
            final sim = (0.55 * jw) + (0.30 * lev) + (0.15 * dice);
            tokenWindowScore = max(tokenWindowScore, sim);
          }
        }
      } else if (queryTokens.length <= candTokens.length) {
        final windowSize = queryTokens.length;
        for (int i = 0; i <= candTokens.length - windowSize; i++) {
          final window = candTokens.sublist(i, i + windowSize).join(' ');
          final qStr = queryTokens.join(' ');
          final jw = jaroWinkler(qStr, window);
          final lev = normalizedLevenshtein(qStr, window);
          final dice = diceBigram(qStr, window);
          final sim = (0.55 * jw) + (0.30 * lev) + (0.15 * dice);
          tokenWindowScore = max(tokenWindowScore, sim);
        }
      }

      // Space-collapsed query vs single candidate tokens (e.g. "alux new" -> "aluxnew" vs "aluksne")
      if (queryTokens.length >= 2) {
        final qCollapsed = collapseSpaces(queryTokens.join(' '));
        final qAcoustic = acousticFold(qCollapsed);
        for (final ct in candTokens) {
          if (ct.length >= 4) {
            final ctAcoustic = acousticFold(ct);
            final jwAc = jaroWinkler(qAcoustic, ctAcoustic);
            final levAc = normalizedLevenshtein(qAcoustic, ctAcoustic);
            final diceAc = diceBigram(qAcoustic, ctAcoustic);
            final acSim = (0.50 * jwAc) + (0.30 * levAc) + (0.20 * diceAc);
            tokenWindowScore = max(tokenWindowScore, acSim * 0.95);
          }
        }
      }
    }

    // 7. Multi-token person name alignment scoring (First name + Surname separation for drivers)
    const genSuffixes = {'jnr', 'snr', 'jr', 'sr', 'ii', 'iii', 'iv'};
    final cleanPTokens = pTokens.where((t) => !genSuffixes.contains(t)).toList();
    final cleanCTokens = cTokens.where((t) => !genSuffixes.contains(t)).toList();

    if (isPerson && !hasMotorsportWords && cleanPTokens.length >= 2 && cleanCTokens.length >= 2) {
      final firstJw = jaroWinkler(cleanPTokens.first, cleanCTokens.first);
      final firstLev = normalizedLevenshtein(cleanPTokens.first, cleanCTokens.first);
      final firstDice = diceBigram(cleanPTokens.first, cleanCTokens.first);
      final firstCombined = (0.50 * firstJw) + (0.30 * firstLev) + (0.20 * firstDice);

      final pSur = cleanPTokens.last;
      final cSur = cleanCTokens.last;

      double surCombined = 0.0;
      if (cSur == pSur) {
        surCombined = 1.0;
      } else if (cSur.contains(pSur) || pSur.contains(cSur)) {
        surCombined = 0.95;
      } else {
        final surJw = jaroWinkler(pSur, cSur);
        final surLev = normalizedLevenshtein(pSur, cSur);
        final surDice = diceBigram(pSur, cSur);
        final surAcJw = jaroWinkler(acousticFold(pSur), acousticFold(cSur));
        final surAcLev = normalizedLevenshtein(acousticFold(pSur), acousticFold(cSur));
        final standardSur = (0.50 * surJw) + (0.30 * surLev) + (0.20 * surDice);
        final acousticSur = (0.50 * surAcJw) + (0.50 * surAcLev);
        surCombined = max(standardSur, acousticSur * 0.95);
      }

      // Strict person surname and first name safety:
      // Both tokens must agree strongly for confident auto-resolution.
      // Surnames are primary; a different first name (e.g. "Josh" vs "Sam" Moffett or "Sam" vs "Sameisha")
      // must NEVER trigger unconfirmed auto-resolution.
      if (surCombined < 0.78) {
        // Differing surname: suppress auto-resolution (cap score at 0.55 max)
        lexicalScore = min(0.55, firstCombined * surCombined);
      } else if (firstCombined < 0.75) {
        // Differing or partial first name with matching surname: suppress auto-resolve (cap score at 0.60)
        lexicalScore = min(0.60, (0.60 * surCombined) + (0.40 * firstCombined));
      } else {
        // Strong agreement on both surname and first name
        lexicalScore = (0.65 * surCombined) + (0.35 * firstCombined);
      }
    } else if (isPerson && !hasMotorsportWords && cleanPTokens.length == 1 && cleanCTokens.length >= 2) {
      final qToken = cleanPTokens.first;
      final surToken = cleanCTokens.last;
      final surJw = jaroWinkler(qToken, surToken);
      final surLev = normalizedLevenshtein(qToken, surToken);
      final surDice = diceBigram(qToken, surToken);
      final surCombined = (0.50 * surJw) + (0.30 * surLev) + (0.20 * surDice);
      if (surCombined >= 0.80 || surToken == qToken) {
        lexicalScore = max(lexicalScore, surCombined * 0.90);
      }
    } else {
      // 8. General Lexical & Phonetic composite calculation for rallies, stages, locations
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

      final jwAcoustic = jaroWinkler(pAcoustic, cAcoustic);
      final levAcoustic = normalizedLevenshtein(pAcoustic, cAcoustic);
      final diceAcoustic = diceBigram(pAcoustic, cAcoustic);
      final acousticScore = (0.50 * jwAcoustic) + (0.30 * levAcoustic) + (0.20 * diceAcoustic);

      final jwAcCore = (pAcCore.isNotEmpty && cAcCore.isNotEmpty) ? jaroWinkler(pAcCore, cAcCore) : 0.0;
      final levAcCore = (pAcCore.isNotEmpty && cAcCore.isNotEmpty) ? normalizedLevenshtein(pAcCore, cAcCore) : 0.0;
      final diceAcCore = (pAcCore.isNotEmpty && cAcCore.isNotEmpty) ? diceBigram(pAcCore, cAcCore) : 0.0;
      final acCoreScore = (0.50 * jwAcCore) + (0.30 * levAcCore) + (0.20 * diceAcCore);

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

      lexicalScore = max(
        fullScore,
        max(
          baseScore,
          max(
            coreScore,
            max(
              collapsedScore * 0.90,
              max(tokenWindowScore * 0.98, max(acousticScore * 0.92, acCoreScore * 0.94)),
            ),
          ),
        ),
      );
    }

    if (transliterationScore > lexicalScore) {
      lexicalScore = transliterationScore;
    }

    lexicalScore = lexicalScore.clamp(0.0, 1.0);

    // 8. Contextual Boosts (Year match, Participation in event)
    // Guard: Base lexical score must be >= 0.45 to prevent boosting unrelated entities
    if (lexicalScore >= 0.45) {
      return _applyContextBoosts(lexicalScore, queryYear: qYear, candidateYear: cYear, inContext: inContext);
    }

    return double.parse(lexicalScore.toStringAsFixed(3));
  }

  /// Extracts a 4-digit year (1900-2099) from text, if present.
  static int? extractYear(String text) {
    final match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
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
        // Year mismatch hard penalty
        score = min(score * 0.40, 0.35);
      }
    }

    // Contextual event participation boost (+0.15)
    if (inContext) {
      score += 0.15;
    }

    return double.parse(score.clamp(0.0, 1.0).toStringAsFixed(3));
  }
}

