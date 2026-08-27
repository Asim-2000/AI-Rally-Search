import '../../../../models/entity_candidate.dart';

/// Storage-agnostic pronunciation metadata for a canonical database entity
/// (rally, driver, co-driver, stage, location).
///
/// Designed to support offline/backend G2P generation while being consumed
/// during entity resolution without storage-specific coupling.
class EntityPronunciationMetadata {
  /// Canonical database identifier (e.g. UUID, slug, int ID).
  final String canonicalId;

  /// Canonical orthographic display name (e.g. "Kalle Rovanperä", "Ott Tänak").
  final String canonicalName;

  /// Type of entity (driver, rally, stage, city, etc.).
  final EntityType entityType;

  /// ISO language hints for the entity (e.g. ['fi', 'en'], ['et']).
  final List<String> languageHints;

  /// ISO country hints for the entity (e.g. ['IE', 'PT', 'EE']).
  final List<String> countryHints;

  /// Normalized orthographic spelling (lowercase, diacritics stripped).
  final String normalizedSpelling;

  /// Map of algorithmically generated phonetic representations.
  /// Keys represent different phonological registers:
  /// - 'native': native-language phonetic transcription (e.g. Estonian /otː tæ.nɑk/)
  /// - 'international': English/international-oriented acoustic approximation (e.g. /ɒt tænæk/)
  /// - 'bmpm': Beider-Morse primary phonetic key
  final Map<String, String> phoneticRepresentations;

  /// Phonetic retrieval keys and n-grams for candidate lookup.
  final List<String> retrievalKeys;

  const EntityPronunciationMetadata({
    required this.canonicalId,
    required this.canonicalName,
    required this.entityType,
    this.languageHints = const [],
    this.countryHints = const [],
    required this.normalizedSpelling,
    this.phoneticRepresentations = const {},
    this.retrievalKeys = const [],
  });

  /// Primary native or default phonetic representation if available.
  String? get primaryPhonetic =>
      phoneticRepresentations['native'] ??
      phoneticRepresentations['international'] ??
      phoneticRepresentations['bmpm'] ??
      (phoneticRepresentations.isNotEmpty ? phoneticRepresentations.values.first : null);

  /// English / international acoustic approximation if available.
  String? get internationalPhonetic =>
      phoneticRepresentations['international'] ?? primaryPhonetic;

  Map<String, dynamic> toJson() => {
        'canonical_id': canonicalId,
        'canonical_name': canonicalName,
        'entity_type': entityType.name,
        'language_hints': languageHints,
        'country_hints': countryHints,
        'normalized_spelling': normalizedSpelling,
        'phonetic_representations': phoneticRepresentations,
        'retrieval_keys': retrievalKeys,
      };

  factory EntityPronunciationMetadata.fromJson(Map<String, dynamic> json) {
    return EntityPronunciationMetadata(
      canonicalId: json['canonical_id'] as String,
      canonicalName: json['canonical_name'] as String,
      entityType: EntityType.values.firstWhere(
        (e) => e.name == json['entity_type'],
        orElse: () => EntityType.driver,
      ),
      languageHints: (json['language_hints'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      countryHints: (json['country_hints'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      normalizedSpelling: json['normalized_spelling'] as String? ?? '',
      phoneticRepresentations: (json['phonetic_representations'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
      retrievalKeys: (json['retrieval_keys'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
