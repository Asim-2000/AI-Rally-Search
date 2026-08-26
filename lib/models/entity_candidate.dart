import 'search_query.dart';

/// Supported motorsport entity types for deterministic resolution.
enum EntityType {
  rally,
  driver,
  stage,
  uploader,
  city,
}

/// Provider-independent candidate entity returned from database lookup.
class EntityCandidate {
  final String id;
  final EntityType type;
  final String canonicalName;
  final String? subtitle;
  final double score;
  final Map<String, dynamic>? metadata;

  const EntityCandidate({
    required this.id,
    required this.type,
    required this.canonicalName,
    this.subtitle,
    this.score = 1.0,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'canonicalName': canonicalName,
      if (subtitle != null) 'subtitle': subtitle,
      'score': score,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory EntityCandidate.fromMap(Map<String, dynamic> map) {
    return EntityCandidate(
      id: map['id']?.toString() ?? '',
      type: EntityType.values.firstWhere(
        (e) => e.name == map['type']?.toString(),
        orElse: () => EntityType.rally,
      ),
      canonicalName: map['canonicalName']?.toString() ?? '',
      subtitle: map['subtitle']?.toString(),
      score: (map['score'] as num?)?.toDouble() ?? 1.0,
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata']) : null,
    );
  }

  @override
  String toString() => 'EntityCandidate($canonicalName [$id], type: ${type.name}, score: $score)';
}

/// Metadata and resolution trail for a single entity phrase in a query.
class EntityResolution {
  final EntityType type;
  final String rawPhrase;
  final EntityCandidate? resolvedCandidate;
  final double confidence;
  final String strategy;
  final bool isAmbiguous;
  final List<EntityCandidate> candidateOptions;

  const EntityResolution({
    required this.type,
    required this.rawPhrase,
    this.resolvedCandidate,
    this.confidence = 1.0,
    this.strategy = 'exact',
    this.isAmbiguous = false,
    this.candidateOptions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'rawPhrase': rawPhrase,
      'resolvedCandidate': resolvedCandidate?.toMap(),
      'confidence': confidence,
      'strategy': strategy,
      'isAmbiguous': isAmbiguous,
      'candidateOptions': candidateOptions.map((c) => c.toMap()).toList(),
    };
  }
}

/// Encapsulates the overall result of deterministic entity resolution on a SearchQuery.
class EntityResolutionResult {
  /// The original unmodified SearchQuery parsed by LLM/validator.
  final SearchQuery? parsedQuery;

  /// The normalized and resolved SearchQuery ready for SearchRepository.
  final SearchQuery? resolvedQuery;

  /// True if multiple candidates exist or confidence is below required threshold.
  final bool requiresClarification;

  /// User-facing clarification question.
  final String? clarificationQuestion;

  /// Disambiguation candidate options if clarification is required.
  final List<EntityCandidate> candidates;

  /// Error message if lookup failed.
  final String? error;

  /// Detailed per-entity resolution mapping (e.g. 'driver' -> EntityResolution).
  final Map<String, EntityResolution> resolutions;

  const EntityResolutionResult({
    this.parsedQuery,
    this.resolvedQuery,
    this.requiresClarification = false,
    this.clarificationQuestion,
    this.candidates = const [],
    this.error,
    this.resolutions = const {},
  });

  bool get isSuccess => resolvedQuery != null && !requiresClarification && error == null;

  factory EntityResolutionResult.success({
    required SearchQuery parsedQuery,
    required SearchQuery resolvedQuery,
    Map<String, EntityResolution> resolutions = const {},
  }) {
    return EntityResolutionResult(
      parsedQuery: parsedQuery,
      resolvedQuery: resolvedQuery,
      requiresClarification: false,
      resolutions: resolutions,
    );
  }

  factory EntityResolutionResult.clarification({
    required SearchQuery parsedQuery,
    required String clarificationQuestion,
    required List<EntityCandidate> candidates,
    Map<String, EntityResolution> resolutions = const {},
  }) {
    return EntityResolutionResult(
      parsedQuery: parsedQuery,
      requiresClarification: true,
      clarificationQuestion: clarificationQuestion,
      candidates: candidates,
      resolutions: resolutions,
    );
  }

  factory EntityResolutionResult.failure({
    SearchQuery? parsedQuery,
    required String error,
  }) {
    return EntityResolutionResult(
      parsedQuery: parsedQuery,
      error: error,
    );
  }
}
