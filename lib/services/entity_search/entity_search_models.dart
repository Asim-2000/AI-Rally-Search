import '../../models/search_query.dart';

enum SearchEntityType { rally, person, stage, uploader }

enum IndexedPersonRole { driver, coDriver, both }

class EntitySearchRequest {
  final String rawMention;
  final SearchEntityType entityType;
  final int limit;
  final int? year;
  final String? country;
  final PersonRole? personRole;
  final Map<String, Object?> context;

  const EntitySearchRequest({
    required this.rawMention,
    required this.entityType,
    this.limit = 10,
    this.year,
    this.country,
    this.personRole,
    this.context = const {},
  });
}

class EntitySearchSignals {
  final double exactScore;
  final double normalizedExactScore;
  final double tokenScore;
  final double ngramScore;
  final double lexicalScore;
  final double phoneticScore;
  final double contextScore;

  const EntitySearchSignals({
    this.exactScore = 0,
    this.normalizedExactScore = 0,
    this.tokenScore = 0,
    this.ngramScore = 0,
    this.lexicalScore = 0,
    this.phoneticScore = 0,
    this.contextScore = 0,
  });

  Map<String, double> toMap() => {
    'exact': exactScore,
    'normalizedExact': normalizedExactScore,
    'token': tokenScore,
    'ngram': ngramScore,
    'lexical': lexicalScore,
    'phonetic': phoneticScore,
    'context': contextScore,
  };
}

class EntitySearchCandidate {
  final String canonicalId;
  final String canonicalName;
  final SearchEntityType entityType;
  final double score;
  final EntitySearchSignals signals;
  final Set<String> matchedBy;
  final Map<String, Object?> metadata;

  const EntitySearchCandidate({
    required this.canonicalId,
    required this.canonicalName,
    required this.entityType,
    required this.score,
    required this.signals,
    required this.matchedBy,
    this.metadata = const {},
  });
}

/// Storage-neutral canonical row supplied by an index data source.
class CanonicalSearchEntity {
  final String canonicalId;
  final String canonicalName;
  final SearchEntityType entityType;
  final Map<String, Object?> metadata;

  const CanonicalSearchEntity({
    required this.canonicalId,
    required this.canonicalName,
    required this.entityType,
    this.metadata = const {},
  });
}

class EntitySearchIndexStats {
  final int entityCount;
  final Duration buildTime;
  final int estimatedBytes;
  final int canonicalEstimatedBytes;
  final int postingListEstimatedBytes;

  const EntitySearchIndexStats({
    required this.entityCount,
    required this.buildTime,
    required this.estimatedBytes,
    this.canonicalEstimatedBytes = 0,
    this.postingListEstimatedBytes = 0,
  });
}

class EntitySearchQueryStats {
  final SearchEntityType entityType;
  final int rawCandidatesEvaluated;
  final int survivingCandidates;
  final int returnedCandidates;
  final Duration latency;
  final Duration candidateGenerationLatency;
  final Duration scoringLatency;
  final int fullUniverseSize;
  final int generatedCandidatePool;
  final bool usedFullScanEscape;

  const EntitySearchQueryStats({
    required this.entityType,
    required this.rawCandidatesEvaluated,
    required this.survivingCandidates,
    required this.returnedCandidates,
    required this.latency,
    this.candidateGenerationLatency = Duration.zero,
    this.scoringLatency = Duration.zero,
    this.fullUniverseSize = 0,
    this.generatedCandidatePool = 0,
    this.usedFullScanEscape = false,
  });
}
