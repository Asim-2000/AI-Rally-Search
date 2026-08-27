import '../../../../models/entity_candidate.dart';
import 'entity_pronunciation_metadata.dart';

/// Provider interface for algorithmic pronunciation encoding and phonetic comparison.
///
/// Implementations may run offline in backend ingestion pipelines or on-device.
abstract class IPronunciationEncoder {
  /// Encodes a canonical entity into multilingual pronunciation metadata.
  Future<EntityPronunciationMetadata> encodeEntity({
    required String id,
    required String name,
    required EntityType type,
    List<String>? languageHints,
  });

  /// Generates phonetic search/retrieval keys for an arbitrary query string.
  Future<List<String>> generateRetrievalKeys(
    String text, {
    String? languageCode,
  });

  /// Computes phonetic similarity [0.0, 1.0] between a spoken query phonetic string
  /// and a candidate entity phonetic string.
  Future<double> comparePhonetic(
    String queryPhonetic,
    String candidatePhonetic,
  );
}

/// Fallback / Pass-through pronunciation encoder when G2P backend is not active.
class PassThroughPronunciationEncoder implements IPronunciationEncoder {
  const PassThroughPronunciationEncoder();

  @override
  Future<EntityPronunciationMetadata> encodeEntity({
    required String id,
    required String name,
    required EntityType type,
    List<String>? languageHints,
  }) async {
    final clean = name.toLowerCase().trim();
    return EntityPronunciationMetadata(
      canonicalId: id,
      canonicalName: name,
      entityType: type,
      languageHints: languageHints ?? const [],
      normalizedSpelling: clean,
      phoneticRepresentations: {
        'default': clean,
      },
      retrievalKeys: [clean],
    );
  }

  @override
  Future<List<String>> generateRetrievalKeys(
    String text, {
    String? languageCode,
  }) async {
    final clean = text.toLowerCase().trim();
    return clean.isNotEmpty ? [clean] : [];
  }

  @override
  Future<double> comparePhonetic(
    String queryPhonetic,
    String candidatePhonetic,
  ) async {
    if (queryPhonetic == candidatePhonetic) return 1.0;
    return 0.0;
  }
}
