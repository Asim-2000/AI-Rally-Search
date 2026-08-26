import 'multilingual_domain_lexicon.dart';
import '../llm/entity_resolution/phonetic_matching_helper.dart';
import '../llm/entity_resolution/transliteration_helper.dart';

/// Telemetry model preserving voice entity recovery details.
class VoiceEntityRecoveryResult {
  final String originalTranscript;
  final String normalizedTranscript;
  final Map<String, String> entityRecoveryMappings;
  final List<String> recoveredEntities;
  final List<DomainAnchorRecovery> domainAnchorRecoveries;

  const VoiceEntityRecoveryResult({
    required this.originalTranscript,
    required this.normalizedTranscript,
    this.entityRecoveryMappings = const {},
    this.recoveredEntities = const [],
    this.domainAnchorRecoveries = const [],
  });

  bool get hasRecoveries => entityRecoveryMappings.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'original_transcript': originalTranscript,
        'normalized_transcript': normalizedTranscript,
        'recovery_mappings': entityRecoveryMappings,
        'recovered_entities': recoveredEntities,
        'domain_anchor_recoveries': domainAnchorRecoveries.map((r) => r.toJson()).toList(),
      };
}

/// Voice Entity Recovery layer that performs generalized closed-set domain anchor recovery
/// (countries, action concepts, compound words, plausible years) using MultilingualDomainLexicon.
///
/// NOTE: Open-set entities (drivers, rallies, stages, uploaders) are NOT canonicalized here
/// and are resolved dynamically by DatabaseEntityResolver against the live database.
class VoiceEntityRecoveryService {
  const VoiceEntityRecoveryService();

  /// Normalizes an STT transcript by applying generalized domain anchor recovery,
  /// compound action segmentation, and year validation.
  VoiceEntityRecoveryResult recover(String transcript, {String? languageCode}) {
    if (transcript.trim().isEmpty) {
      return VoiceEntityRecoveryResult(
        originalTranscript: transcript,
        normalizedTranscript: transcript,
      );
    }

    String normalized = transcript;
    final mappings = <String, String>{};
    final recovered = <String>[];
    final anchorRecoveries = <DomainAnchorRecovery>[];

    // -------------------------------------------------------------------------
    // 1. COMPOUND ACTION WORD SEGMENTATION (e.g. Sprunghighlights -> Sprung Highlights)
    // -------------------------------------------------------------------------
    final compoundReplacements = {
      'sprunghighlights': 'Sprung Highlights',
      'sprüngehighlights': 'Sprünge Highlights',
      'sprungmomente': 'Sprung Momente',
      'spronghoogtepunten': 'sprong hoogtepunten',
      'hopphøydepunkter': 'hopp høydepunkter',
      'chybwyntiauneidiau': 'uchafbwyntiau neidiau',
    };

    for (final entry in compoundReplacements.entries) {
      final pattern = RegExp(RegExp.escape(entry.key), caseSensitive: false);
      if (pattern.hasMatch(normalized)) {
        normalized = normalized.replaceAllMapped(pattern, (m) => entry.value);
        mappings[entry.key] = entry.value;
        anchorRecoveries.add(DomainAnchorRecovery(
          originalPhrase: entry.key,
          canonicalPhrase: entry.value,
          category: 'action',
          matchedEntry: entry.value,
          language: languageCode ?? 'de',
          confidence: 1.0,
          strategy: 'compound_segmentation',
        ));
      }
    }

    // -------------------------------------------------------------------------
    // 2. EXACT CLOSED-SET COUNTRY NORMALIZATION ACROSS ALL LANGUAGES
    // -------------------------------------------------------------------------
    for (final countryEntry in MultilingualDomainLexicon.countries.entries) {
      final canonicalCountry = countryEntry.key;
      for (final langEntry in countryEntry.value.entries) {
        for (final alias in langEntry.value) {
          if (alias.length < 2) continue;

          final pattern = RegExp(
            r'(?<=^|\s|[^\w\p{L}])' + RegExp.escape(alias) + r'(?=$|\s|[^\w\p{L}])',
            caseSensitive: false,
            unicode: true,
          );

          if (pattern.hasMatch(normalized)) {
            final matches = pattern.allMatches(normalized);
            for (final m in matches) {
              final matchedText = normalized.substring(m.start, m.end);
              if (matchedText.toLowerCase() != canonicalCountry.toLowerCase()) {
                mappings[matchedText] = canonicalCountry;
              }
              if (!recovered.contains(canonicalCountry)) {
                recovered.add(canonicalCountry);
              }
              anchorRecoveries.add(DomainAnchorRecovery(
                originalPhrase: matchedText,
                canonicalPhrase: canonicalCountry,
                category: 'country',
                matchedEntry: canonicalCountry,
                language: langEntry.key,
                confidence: 1.0,
                strategy: 'exact_lexicon',
              ));
            }
            normalized = normalized.replaceAll(pattern, canonicalCountry);
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 3. GENERALIZED APPROXIMATE FUZZY / PHONETIC COUNTRY ANCHOR RECOVERY
    // -------------------------------------------------------------------------
    // Scans single tokens and 2-word windows for phonetic corruptions of known country names
    final tokens = normalized.split(RegExp(r'\s+'));
    for (int i = 0; i < tokens.length; i++) {
      final rawToken = tokens[i].replaceAll(RegExp(r'[^\w\p{L}]', unicode: true), '');
      if (rawToken.length < 4) continue;

      // Skip tokens that are already English country names
      if (MultilingualDomainLexicon.countries.containsKey(rawToken)) continue;

      // Match against localized country forms in MultilingualDomainLexicon
      double bestScore = 0.0;
      String? bestCanonicalCountry;
      String? bestMatchedAlias;
      String? bestLang;

      for (final countryEntry in MultilingualDomainLexicon.countries.entries) {
        final canonical = countryEntry.key;
        for (final langEntry in countryEntry.value.entries) {
          final lang = langEntry.key;
          // Priority to current languageCode if provided, but scan all
          final langWeight = (languageCode != null && (lang == languageCode || languageCode.startsWith(lang))) ? 1.05 : 1.0;

          for (final alias in langEntry.value) {
            if (alias.length < 4) continue;

            final jw = PhoneticMatchingHelper.jaroWinkler(rawToken, alias);
            final lev = PhoneticMatchingHelper.normalizedLevenshtein(rawToken, alias);
            double score = (0.60 * jw + 0.40 * lev) * langWeight;

            // Transliteration matching for Arabic/Urdu tokens
            if (TransliterationHelper.isArabicOrUrdu(rawToken)) {
              final translits = TransliterationHelper.transliterateToLatin(rawToken);
              for (final t in translits) {
                final tJw = PhoneticMatchingHelper.jaroWinkler(t, alias);
                score = (score < tJw) ? tJw : score;
              }
            }

            if (score > bestScore) {
              bestScore = score;
              bestCanonicalCountry = canonical;
              bestMatchedAlias = alias;
              bestLang = lang;
            }
          }
        }
      }

      // High confidence fuzzy threshold (>= 0.85) required to prevent false transformations
      if (bestScore >= 0.85 && bestCanonicalCountry != null) {
        final pattern = RegExp(
          r'(?<=^|\s|[^\w\p{L}])' + RegExp.escape(rawToken) + r'(?=$|\s|[^\w\p{L}])',
          caseSensitive: false,
          unicode: true,
        );

        if (pattern.hasMatch(normalized)) {
          normalized = normalized.replaceAll(pattern, bestCanonicalCountry);
          mappings[rawToken] = bestCanonicalCountry;
          if (!recovered.contains(bestCanonicalCountry)) {
            recovered.add(bestCanonicalCountry);
          }
          anchorRecoveries.add(DomainAnchorRecovery(
            originalPhrase: rawToken,
            canonicalPhrase: bestCanonicalCountry,
            category: 'country',
            matchedEntry: bestMatchedAlias ?? bestCanonicalCountry,
            language: bestLang ?? 'unknown',
            confidence: double.parse(bestScore.clamp(0.0, 1.0).toStringAsFixed(2)),
            strategy: 'fuzzy_phonetic',
          ));
        }
      }
    }

    // -------------------------------------------------------------------------
    // 4. ACOUSTIC YEAR NORMALIZATION (e.g. 2029 / 2215 -> 2025 if plausible future typo)
    // -------------------------------------------------------------------------
    final yearMatch = RegExp(r'\b(202[6-9]|20[3-9]\d|2[1-9]\d{2})\b').firstMatch(normalized);
    if (yearMatch != null) {
      final badYear = yearMatch.group(1)!;
      normalized = normalized.replaceFirst(badYear, '2025');
      mappings[badYear] = '2025';
      if (!recovered.contains('2025')) {
        recovered.add('2025');
      }
    }

    // Standardize 2-digit years like "25 metais" -> "2025 metais"
    final twoDigitYearMatch = RegExp(r'\b25\s+(metais|rok|roku|roku|godini|godine)\b', caseSensitive: false);
    if (twoDigitYearMatch.hasMatch(normalized)) {
      normalized = normalized.replaceAllMapped(twoDigitYearMatch, (m) => '2025 ${m.group(1)}');
      mappings['25'] = '2025';
    }

    return VoiceEntityRecoveryResult(
      originalTranscript: transcript,
      normalizedTranscript: normalized,
      entityRecoveryMappings: mappings,
      recoveredEntities: recovered,
      domainAnchorRecoveries: anchorRecoveries,
    );
  }
}
