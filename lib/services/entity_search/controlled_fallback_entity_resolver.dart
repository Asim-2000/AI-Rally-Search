import '../../models/entity_candidate.dart';
import '../../models/search_query.dart';
import '../llm/entity_resolution/entity_resolver.dart';
import '../llm/llm_query_parser.dart';

enum EntitySearchFallbackMode { off, shadow, fallback }

enum CandidateOrigin { sql, entitySearch, both }

class EntitySearchFallbackConfig {
  final EntitySearchFallbackMode mode;
  const EntitySearchFallbackConfig({this.mode = EntitySearchFallbackMode.off});

  factory EntitySearchFallbackConfig.fromValue(String? value) {
    return EntitySearchFallbackConfig(
      mode: switch (value?.trim().toLowerCase()) {
        'shadow' => EntitySearchFallbackMode.shadow,
        'fallback' => EntitySearchFallbackMode.fallback,
        _ => EntitySearchFallbackMode.off,
      },
    );
  }
}

/// In-memory, query-text-free operational counters for controlled rollout.
class EntitySearchFallbackMetrics {
  int legacyResolved = 0;
  int legacyClarified = 0;
  int legacyNoMatch = 0;
  int entitySearchInvoked = 0;
  int entitySearchResolved = 0;
  int entitySearchClarified = 0;
  int entitySearchNoMatch = 0;
  int entitySearchRecoveredLegacyFailure = 0;
  int roleConstraintRejected = 0;
  int yearConstraintRejected = 0;
  int duplicateIdentityClarification = 0;
  int legacyLatencyMicroseconds = 0;
  int entitySearchLatencyMicroseconds = 0;
  int totalResolutionLatencyMicroseconds = 0;

  Map<String, Object> toMap() => {
    'legacyResolved': legacyResolved,
    'legacyClarified': legacyClarified,
    'legacyNoMatch': legacyNoMatch,
    'entitySearchInvoked': entitySearchInvoked,
    'entitySearchResolved': entitySearchResolved,
    'entitySearchClarified': entitySearchClarified,
    'entitySearchNoMatch': entitySearchNoMatch,
    'entitySearchRecoveredLegacyFailure': entitySearchRecoveredLegacyFailure,
    'roleConstraintRejected': roleConstraintRejected,
    'yearConstraintRejected': yearConstraintRejected,
    'duplicateIdentityClarification': duplicateIdentityClarification,
    'legacyLatencyMicroseconds': legacyLatencyMicroseconds,
    'entitySearchLatencyMicroseconds': entitySearchLatencyMicroseconds,
    'totalResolutionLatencyMicroseconds': totalResolutionLatencyMicroseconds,
  };
}

class EntitySearchShadowDiagnostic {
  final String rawMention;
  final EntityType entityType;
  final String legacyOutcome;
  final List<String> legacyCandidateIds;
  final List<String> entitySearchCandidateIds;
  final List<int> entitySearchRanks;
  final Map<String, CandidateOrigin> candidateOrigins;
  final String? legacyResolvedId;
  final bool legacyResolvedIdAppearsInEntitySearch;
  final Duration latency;

  const EntitySearchShadowDiagnostic({
    required this.rawMention,
    required this.entityType,
    required this.legacyOutcome,
    required this.legacyCandidateIds,
    required this.entitySearchCandidateIds,
    required this.entitySearchRanks,
    required this.candidateOrigins,
    required this.legacyResolvedId,
    required this.legacyResolvedIdAppearsInEntitySearch,
    required this.latency,
  });
}

abstract class IEntitySearchFallbackTelemetry {
  void record(EntitySearchShadowDiagnostic diagnostic);
}

class NoOpEntitySearchFallbackTelemetry
    implements IEntitySearchFallbackTelemetry {
  const NoOpEntitySearchFallbackTelemetry();
  @override
  void record(EntitySearchShadowDiagnostic diagnostic) {}
}

/// Controlled ES-2 integration. Legacy resolution always runs first and is
/// authoritative whenever it produces a clear, safe winner.
class ControlledFallbackEntityResolver implements EntityResolver {
  final EntityResolver legacyResolver;
  final EntityResolver entitySearchResolver;
  final EntitySearchFallbackConfig config;
  final IEntitySearchFallbackTelemetry telemetry;
  final EntitySearchFallbackMetrics metrics;

  ControlledFallbackEntityResolver({
    required this.legacyResolver,
    required this.entitySearchResolver,
    this.config = const EntitySearchFallbackConfig(),
    this.telemetry = const NoOpEntitySearchFallbackTelemetry(),
    EntitySearchFallbackMetrics? metrics,
  }) : metrics = metrics ?? EntitySearchFallbackMetrics();

  @override
  Future<EntityResolutionResult> resolve(
    SearchQuery query, {
    SearchContext? context,
  }) => resolveControlled(query, context: context);

  Future<EntityResolutionResult> resolveControlled(
    SearchQuery query, {
    SearchContext? context,
    bool voice = false,
  }) async {
    final totalWatch = Stopwatch()..start();
    final legacyWatch = Stopwatch()..start();
    final legacy = await legacyResolver.resolve(query, context: context);
    legacyWatch.stop();
    metrics.legacyLatencyMicroseconds += legacyWatch.elapsedMicroseconds;
    _incrementOutcome(legacy, legacy: true);
    final unsafeLegacyPerson = _hasUnbridgedLegacyPerson(query, legacy);
    if (config.mode == EntitySearchFallbackMode.off ||
        (_isClearLegacyWinner(query, legacy) && !unsafeLegacyPerson)) {
      totalWatch.stop();
      metrics.totalResolutionLatencyMicroseconds +=
          totalWatch.elapsedMicroseconds;
      return legacy;
    }

    metrics.entitySearchInvoked++;
    final watch = Stopwatch()..start();
    final recovered = await entitySearchResolver.resolve(
      query,
      context: context,
    );
    watch.stop();
    metrics.entitySearchLatencyMicroseconds += watch.elapsedMicroseconds;
    _incrementOutcome(recovered, legacy: false);
    _recordDiagnostics(query, legacy, recovered, watch.elapsed);

    if (config.mode == EntitySearchFallbackMode.shadow) {
      totalWatch.stop();
      metrics.totalResolutionLatencyMicroseconds +=
          totalWatch.elapsedMicroseconds;
      return legacy;
    }
    if (!_hasUsefulOutcome(legacy) && _hasUsefulOutcome(recovered)) {
      metrics.entitySearchRecoveredLegacyFailure++;
    }
    if (_isDuplicateIdentityClarification(recovered)) {
      metrics.duplicateIdentityClarification++;
    }
    EntityResolutionResult result;
    if (voice && _isRecoveredAutoResolution(recovered)) {
      result = _voiceClarification(query, recovered);
    } else {
      result = _hasUsefulOutcome(recovered) || unsafeLegacyPerson
          ? recovered
          : legacy;
    }
    totalWatch.stop();
    metrics.totalResolutionLatencyMicroseconds +=
        totalWatch.elapsedMicroseconds;
    return result;
  }

  void _incrementOutcome(
    EntityResolutionResult result, {
    required bool legacy,
  }) {
    final outcome = _outcome(result);
    if (legacy) {
      if (outcome == 'resolved') metrics.legacyResolved++;
      if (outcome == 'clarification') metrics.legacyClarified++;
      if (outcome == 'no_match') metrics.legacyNoMatch++;
    } else {
      if (outcome == 'resolved') metrics.entitySearchResolved++;
      if (outcome == 'clarification') metrics.entitySearchClarified++;
      if (outcome == 'no_match') metrics.entitySearchNoMatch++;
    }
  }

  static bool _isDuplicateIdentityClarification(EntityResolutionResult result) {
    if (!result.requiresClarification) return false;
    final people = result.candidates
        .where((candidate) => candidate.type == EntityType.driver)
        .toList();
    for (var i = 0; i < people.length; i++) {
      for (var j = i + 1; j < people.length; j++) {
        if (people[i].canonicalName.toLowerCase() ==
                people[j].canonicalName.toLowerCase() &&
            _canonicalIdentity(people[i]) != _canonicalIdentity(people[j])) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _hasUsefulOutcome(EntityResolutionResult result) =>
      result.requiresClarification ||
      result.resolutions.values.any((resolution) => resolution.isResolved);

  static bool _isClearLegacyWinner(
    SearchQuery query,
    EntityResolutionResult result,
  ) {
    if (!result.isSuccess ||
        result.requiresClarification ||
        result.error != null) {
      return false;
    }
    final expected =
        query.rallyNames.length +
        query.driverNames.length +
        query.stageNames.length;
    if (expected == 0) return true;
    return result.resolutions.values.where((r) => r.isResolved).length >=
        expected;
  }

  /// A NULL-account SQL person row is not globally unique: another driver or
  /// co-driver profile may have the same name without an account bridge.
  /// The complete index must validate identity and role before execution.
  static bool _hasUnbridgedLegacyPerson(
    SearchQuery query,
    EntityResolutionResult result,
  ) {
    if (query.driverNames.isEmpty) return false;
    return result.resolutions.values.any((resolution) {
      if (resolution.type != EntityType.driver || !resolution.isResolved) {
        return false;
      }
      final candidate = resolution.resolvedCandidate;
      final accountId = candidate?.metadata?['accountId']?.toString();
      return accountId == null || accountId.isEmpty || accountId == 'null';
    });
  }

  static bool _isRecoveredAutoResolution(EntityResolutionResult result) =>
      result.resolutions.values.any((resolution) {
        final candidate = resolution.resolvedCandidate;
        if (candidate == null) return false;
        final signals = candidate.metadata?['retrievalSignals'];
        if (signals is! Map) return true;
        return (signals['exact'] as num? ?? 0) < 1 &&
            (signals['normalizedExact'] as num? ?? 0) < 1;
      });

  static EntityResolutionResult _voiceClarification(
    SearchQuery query,
    EntityResolutionResult recovered,
  ) {
    final candidates = recovered.resolutions.values
        .map((r) => r.resolvedCandidate)
        .whereType<EntityCandidate>()
        .toList(growable: false);
    if (candidates.isEmpty) return recovered;
    return EntityResolutionResult.clarification(
      parsedQuery: query,
      clarificationQuestion:
          'Did you mean "${candidates.first.canonicalName}"?',
      candidates: candidates,
      resolutions: recovered.resolutions,
    );
  }

  void _recordDiagnostics(
    SearchQuery query,
    EntityResolutionResult legacy,
    EntityResolutionResult recovered,
    Duration latency,
  ) {
    final legacyByType = _candidatesByType(legacy);
    final recoveredByType = _candidatesByType(recovered);
    final mentions = <(String, EntityType)>[
      for (final mention in query.rallyNames) (mention, EntityType.rally),
      for (final mention in query.driverNames) (mention, EntityType.driver),
      for (final mention in query.stageNames) (mention, EntityType.stage),
    ];
    for (final mention in mentions) {
      final legacyCandidates = legacyByType[mention.$2] ?? const [];
      final newCandidates = recoveredByType[mention.$2] ?? const [];
      final legacyResolved = legacy.resolutions.values
          .where((r) => r.type == mention.$2 && r.isResolved)
          .map((r) => r.resolvedCandidate?.id)
          .whereType<String>()
          .firstOrNull;
      telemetry.record(
        EntitySearchShadowDiagnostic(
          rawMention: mention.$1,
          entityType: mention.$2,
          legacyOutcome: _outcome(legacy),
          legacyCandidateIds: legacyCandidates
              .map(_canonicalIdentity)
              .toSet()
              .toList(),
          entitySearchCandidateIds: newCandidates
              .map(_canonicalIdentity)
              .toSet()
              .toList(),
          entitySearchRanks: List<int>.generate(
            newCandidates.length,
            (i) => i + 1,
          ),
          candidateOrigins: _candidateOrigins(legacyCandidates, newCandidates),
          legacyResolvedId: legacyResolved,
          legacyResolvedIdAppearsInEntitySearch:
              legacyResolved != null &&
              newCandidates.any((c) => _canonicalIdentity(c) == legacyResolved),
          latency: latency,
        ),
      );
    }
  }

  static Map<String, CandidateOrigin> _candidateOrigins(
    List<EntityCandidate> legacy,
    List<EntityCandidate> entitySearch,
  ) {
    final legacyIds = legacy.map(_canonicalIdentity).toSet();
    final entitySearchIds = entitySearch.map(_canonicalIdentity).toSet();
    return {
      for (final id in {...legacyIds, ...entitySearchIds})
        id: legacyIds.contains(id) && entitySearchIds.contains(id)
            ? CandidateOrigin.both
            : legacyIds.contains(id)
            ? CandidateOrigin.sql
            : CandidateOrigin.entitySearch,
    };
  }

  static Map<EntityType, List<EntityCandidate>> _candidatesByType(
    EntityResolutionResult result,
  ) {
    final candidates = <EntityCandidate>[
      ...result.candidates,
      for (final resolution in result.resolutions.values)
        ...resolution.candidateOptions,
      for (final resolution in result.resolutions.values)
        if (resolution.resolvedCandidate != null) resolution.resolvedCandidate!,
    ];
    final grouped = <EntityType, List<EntityCandidate>>{};
    for (final candidate in candidates) {
      final identity = _canonicalIdentity(candidate);
      final bucket = grouped.putIfAbsent(candidate.type, () => []);
      if (!bucket.any((existing) => _canonicalIdentity(existing) == identity)) {
        bucket.add(candidate);
      }
    }
    return grouped;
  }

  static String _canonicalIdentity(EntityCandidate candidate) =>
      candidate.type == EntityType.driver
      ? (candidate.metadata?['accountId']?.toString() ?? candidate.id)
      : candidate.id;

  static String _outcome(EntityResolutionResult result) {
    if (result.requiresClarification) return 'clarification';
    if (result.error != null) return 'no_match';
    if (result.resolutions.values.any((r) => r.isResolved)) {
      return 'resolved';
    }
    return 'no_match';
  }
}
