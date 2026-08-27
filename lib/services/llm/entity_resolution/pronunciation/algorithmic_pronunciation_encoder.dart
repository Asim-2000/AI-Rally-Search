import 'dart:math';
import '../../../../models/entity_candidate.dart';
import '../phonetic_matching_helper.dart';
import 'entity_pronunciation_metadata.dart';
import 'phonetic_distance.dart';
import 'pronunciation_encoder.dart';

/// Algorithmic multilingual pronunciation encoder and scorer for the POC.
///
/// Implements generalized, entity-independent multi-register phonetic representation
/// generation (native phonology mapping, international English acoustic projection,
/// space-collapsed phonetic tokens, and n-gram retrieval keys) without ANY entity-specific
/// or benchmark-specific hardcoded alias rules.
class AlgorithmicPronunciationEncoder implements IPronunciationEncoder {
  @override
  Future<EntityPronunciationMetadata> encodeEntity({
    required String id,
    required String name,
    required EntityType type,
    List<String>? languageHints,
    List<String>? countryHints,
  }) async {
    final normalized = PhoneticMatchingHelper.normalize(name);

    // 1. Native-oriented phonetic encoding (independent European phoneme mapping)
    final nativeRep = _encodeNativePhonetic(name);

    // 2. International / English-oriented acoustic projection (independent token acoustics)
    final internationalRep = _encodeInternationalPhonetic(name);

    // 3. Space-collapsed acoustic representation (for multi-word STT boundary splits)
    final collapsedRep = _encodeCollapsedPhonetic(name);

    // 4. Coarse phonetic key
    final coarseRep = PhoneticMatchingHelper.soundex(normalized);

    // 5. Phonetic retrieval keys (2-phone / 3-phone shingles for multi-modal candidate retrieval)
    final retrievalKeys = _generateRetrievalKeys([nativeRep, internationalRep, collapsedRep, coarseRep]);

    return EntityPronunciationMetadata(
      canonicalId: id,
      canonicalName: name,
      entityType: type,
      languageHints: languageHints ?? const [],
      countryHints: countryHints ?? const [],
      normalizedSpelling: normalized,
      phoneticRepresentations: {
        'native': nativeRep,
        'international': internationalRep,
        'collapsed': collapsedRep,
        'coarse': coarseRep,
      },
      retrievalKeys: retrievalKeys,
    );
  }

  @override
  Future<List<String>> generateRetrievalKeys(
    String text, {
    String? languageCode,
  }) async {
    final native = _encodeNativePhonetic(text);
    final international = _encodeInternationalPhonetic(text);
    final collapsed = _encodeCollapsedPhonetic(text);
    return _generateRetrievalKeys([native, international, collapsed]);
  }

  @override
  Future<double> comparePhonetic(
    String queryPhonetic,
    String candidatePhonetic,
  ) async {
    if (queryPhonetic.isEmpty || candidatePhonetic.isEmpty) return 0.0;
    return PhoneticDistance.similarity(queryPhonetic, candidatePhonetic);
  }

  /// Encodes a raw spoken query into its generalized international phonetic representation.
  String encodeQuery(String text) {
    return _encodeInternationalPhonetic(text);
  }

  /// Encodes a raw spoken query into its space-collapsed phonetic representation.
  String encodeCollapsedQuery(String text) {
    return _encodeCollapsedPhonetic(text);
  }

  /// Scores a spoken transcript against candidate metadata across all representations.
  Future<double> scorePhoneticMatch({
    required String spokenTranscriptPhonetic,
    String? spokenTranscriptCollapsed,
    required EntityPronunciationMetadata candidateMetadata,
  }) async {
    if (spokenTranscriptPhonetic.isEmpty && (spokenTranscriptCollapsed == null || spokenTranscriptCollapsed.isEmpty)) {
      return 0.0;
    }

    double maxSim = 0.0;

    for (final entry in candidateMetadata.phoneticRepresentations.entries) {
      final rep = entry.value;
      if (rep.isEmpty) continue;

      // Direct token-to-token similarity
      final sim1 = PhoneticDistance.similarity(spokenTranscriptPhonetic, rep);
      if (sim1 > maxSim) maxSim = sim1;

      // Space-collapsed boundary similarity (handles "a looks nay" -> "aluksne")
      if (spokenTranscriptCollapsed != null && spokenTranscriptCollapsed.isNotEmpty) {
        final collapsedCandidate = candidateMetadata.phoneticRepresentations['collapsed'] ?? rep.replaceAll(' ', '');
        final sim2 = PhoneticDistance.similarity(spokenTranscriptCollapsed, collapsedCandidate);
        if (sim2 > maxSim) maxSim = sim2;
      }
    }

    return maxSim;
  }

  /// Generalized, language-independent European diacritic and phoneme mapping.
  /// Applies universally to any input text.
  String _encodeNativePhonetic(String text) {
    var s = text.toLowerCase().trim();

    // Universal European character acoustic mappings
    s = s
        .replaceAll('ł', 'w')
        .replaceAll('ū', 'u')
        .replaceAll('ø', 'o')
        .replaceAll('å', 'o')
        .replaceAll('ä', 'e')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'an')
        .replaceAll('â', 'a')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 's')
        .replaceAll('č', 'ch')
        .replaceAll('š', 'sh')
        .replaceAll('ž', 'zh')
        .replaceAll('ć', 'ch')
        .replaceAll('ź', 'z')
        .replaceAll('ż', 'z')
        .replaceAll('ß', 'ss');

    // Strip non-letters
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

    return tokens.map((t) => _phoneticToken(t)).join(' ');
  }

  /// Generalized International / English STT acoustic projection.
  /// Strictly entity-independent.
  String _encodeInternationalPhonetic(String text) {
    var s = text.toLowerCase().trim();
    // Normalize diacritics using standard normalization
    s = PhoneticMatchingHelper.normalize(s);

    final tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return tokens.map((t) => _phoneticToken(t)).join(' ');
  }

  /// Space-collapsed phonetic representation for multi-token STT artifacts.
  String _encodeCollapsedPhonetic(String text) {
    var s = text.toLowerCase().trim();
    s = PhoneticMatchingHelper.normalize(s);
    final tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final phoneticTokens = tokens.map((t) => _phoneticToken(t)).join('');
    return phoneticTokens;
  }

  /// Transforms a single word token to its generalized acoustic phonetic representation.
  /// (Diphthong collapsing, voicing standardizations, consonant cluster reductions).
  String _phoneticToken(String token) {
    if (token.isEmpty) return '';

    var t = token.toLowerCase();

    // Universal acoustic digraph and diphthong standardizations
    t = t
        .replaceAll('ph', 'f')
        .replaceAll('gh', 'g')
        .replaceAll('ck', 'k')
        .replaceAll('qu', 'kw')
        .replaceAll('x', 'ks')
        .replaceAll('c', 'k')
        .replaceAll('z', 's')
        .replaceAll('v', 'f')
        .replaceAll('oo', 'u')
        .replaceAll('ee', 'i')
        .replaceAll('ea', 'i')
        .replaceAll('ay', 'e')
        .replaceAll('ey', 'e')
        .replaceAll('ai', 'e')
        .replaceAll('ei', 'e')
        .replaceAll('ou', 'u')
        .replaceAll('ow', 'o')
        .replaceAll('aw', 'o');

    // Deduplicate consecutive identical characters
    final buffer = StringBuffer();
    String? prev;
    for (var i = 0; i < t.length; i++) {
      final c = t[i];
      if (c != prev) {
        buffer.write(c);
      }
      prev = c;
    }

    return buffer.toString().toUpperCase();
  }

  List<String> _generateRetrievalKeys(List<String> representations) {
    final keys = <String>{};
    for (final rep in representations) {
      if (rep.isEmpty) continue;
      final clean = rep.replaceAll(' ', '');
      if (clean.length >= 3) {
        for (var i = 0; i <= clean.length - 3; i++) {
          keys.add(clean.substring(i, i + 3));
        }
      } else if (clean.isNotEmpty) {
        keys.add(clean);
      }
    }
    return keys.toList();
  }
}
