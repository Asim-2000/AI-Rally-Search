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

  EntityCandidate copyWith({
    String? id,
    EntityType? type,
    String? canonicalName,
    String? subtitle,
    double? score,
    Map<String, dynamic>? metadata,
  }) {
    return EntityCandidate(
      id: id ?? this.id,
      type: type ?? this.type,
      canonicalName: canonicalName ?? this.canonicalName,
      subtitle: subtitle ?? this.subtitle,
      score: score ?? this.score,
      metadata: metadata ?? this.metadata,
    );
  }

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

/// Strategy and status of a resolved entity phrase.
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
    required this.confidence,
    required this.strategy,
    this.isAmbiguous = false,
    this.candidateOptions = const [],
  });

  bool get isResolved => resolvedCandidate != null && !isAmbiguous;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'rawPhrase': rawPhrase,
        'resolvedCandidate': resolvedCandidate?.canonicalName,
        'resolvedId': resolvedCandidate?.id,
        'confidence': confidence,
        'strategy': strategy,
        'isAmbiguous': isAmbiguous,
        'candidateOptionsCount': candidateOptions.length,
      };
}

/// Comprehensive outcome of the multi-stage entity resolution pipeline.
class EntityResolutionResult {
  final SearchQuery? resolvedQuery;
  final bool requiresClarification;
  final String? clarificationQuestion;
  final List<EntityCandidate> candidates;
  final Map<String, EntityResolution> resolutions;
  final String? error;

  const EntityResolutionResult({
    this.resolvedQuery,
    this.requiresClarification = false,
    this.clarificationQuestion,
    this.candidates = const [],
    this.resolutions = const {},
    this.error,
  });

  factory EntityResolutionResult.clarification({
    required SearchQuery parsedQuery,
    required String clarificationQuestion,
    required List<EntityCandidate> candidates,
    Map<String, EntityResolution> resolutions = const {},
  }) {
    return EntityResolutionResult(
      resolvedQuery: parsedQuery,
      requiresClarification: true,
      clarificationQuestion: clarificationQuestion,
      candidates: candidates,
      resolutions: resolutions,
    );
  }

  factory EntityResolutionResult.failure(String error) {
    return EntityResolutionResult(
      error: error,
    );
  }
}
