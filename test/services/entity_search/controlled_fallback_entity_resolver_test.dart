import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/entity_search/controlled_fallback_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_resolver.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = SearchQuery(
    intent: SearchIntent.searchVideoActions,
    rallyNames: ['aluksni'],
  );

  test('OFF returns legacy and never invokes Entity Search', () async {
    final legacy = _CountingResolver(_noMatch(query));
    final recovered = _CountingResolver(_resolved(query, _rally));
    final resolver = ControlledFallbackEntityResolver(
      legacyResolver: legacy,
      entitySearchResolver: recovered,
    );
    expect((await resolver.resolve(query)).error, isNotNull);
    expect(recovered.calls, 0);
  });

  test('SHADOW invokes Entity Search but preserves legacy result and records diagnostics', () async {
    final legacy = _CountingResolver(_noMatch(query));
    final recovered = _CountingResolver(_resolved(query, _rally));
    final telemetry = _Telemetry();
    final resolver = ControlledFallbackEntityResolver(
      legacyResolver: legacy,
      entitySearchResolver: recovered,
      config: const EntitySearchFallbackConfig(
        mode: EntitySearchFallbackMode.shadow,
      ),
      telemetry: telemetry,
    );
    expect((await resolver.resolve(query)).error, isNotNull);
    expect(recovered.calls, 1);
    expect(telemetry.values.single.rawMention, 'aluksni');
    expect(telemetry.values.single.entitySearchCandidateIds, ['event-1']);
    expect(
      telemetry.values.single.candidateOrigins['event-1'],
      CandidateOrigin.entitySearch,
    );
  });

  test(
    'FALLBACK returns safety-checked recovered result after legacy no-match',
    () async {
      final recovered = _CountingResolver(_resolved(query, _rally));
      final resolver = ControlledFallbackEntityResolver(
        legacyResolver: _CountingResolver(_noMatch(query)),
        entitySearchResolver: recovered,
        config: const EntitySearchFallbackConfig(
          mode: EntitySearchFallbackMode.fallback,
        ),
      );
      final result = await resolver.resolve(query);
      expect(result.resolutions['rally']?.resolvedCandidate?.id, 'event-1');
      expect(recovered.calls, 1);
    },
  );

  test('clear legacy winner bypasses Entity Search in FALLBACK mode', () async {
    final recovered = _CountingResolver(_resolved(query, _rally));
    final resolver = ControlledFallbackEntityResolver(
      legacyResolver: _CountingResolver(_resolved(query, _rally)),
      entitySearchResolver: recovered,
      config: const EntitySearchFallbackConfig(
        mode: EntitySearchFallbackMode.fallback,
      ),
    );
    await resolver.resolve(query);
    expect(recovered.calls, 0);
  });

  test('fallback no-match cannot erase a useful SQL clarification', () async {
    final legacy = EntityResolutionResult.clarification(
      parsedQuery: query,
      clarificationQuestion: 'Which rally?',
      candidates: const [_rally],
    );
    final resolver = ControlledFallbackEntityResolver(
      legacyResolver: _CountingResolver(legacy),
      entitySearchResolver: _CountingResolver(_noMatch(query)),
      config: const EntitySearchFallbackConfig(
        mode: EntitySearchFallbackMode.fallback,
      ),
    );
    final result = await resolver.resolve(query);
    expect(result.requiresClarification, isTrue);
    expect(result.clarificationQuestion, 'Which rally?');
  });

  test(
    'voice phonetic recovery becomes confirmation with canonical ID',
    () async {
      final resolver = ControlledFallbackEntityResolver(
        legacyResolver: _CountingResolver(_noMatch(query)),
        entitySearchResolver: _CountingResolver(_resolved(query, _rally)),
        config: const EntitySearchFallbackConfig(
          mode: EntitySearchFallbackMode.fallback,
        ),
      );
      final result = await resolver.resolveControlled(query, voice: true);
      expect(result.requiresClarification, isTrue);
      expect(
        result.clarificationQuestion,
        'Did you mean "Rally Alūksne 2026"?',
      );
      expect(result.candidates.single.id, 'event-1');
    },
  );

  test(
    'strong normalized recovery may retain resolver auto-resolution for voice',
    () async {
      final exact = _rally.copyWith(
        metadata: {
          ...?_rally.metadata,
          'retrievalSignals': {'exact': 0.0, 'normalizedExact': 1.0},
        },
      );
      final resolver = ControlledFallbackEntityResolver(
        legacyResolver: _CountingResolver(_noMatch(query)),
        entitySearchResolver: _CountingResolver(_resolved(query, exact)),
        config: const EntitySearchFallbackConfig(
          mode: EntitySearchFallbackMode.fallback,
        ),
      );
      expect(
        (await resolver.resolveControlled(
          query,
          voice: true,
        )).requiresClarification,
        isFalse,
      );
    },
  );

  test('multi-entity partial ambiguity is preserved independently', () async {
    const multi = SearchQuery(
      intent: SearchIntent.searchDriverRallies,
      driverNames: ['Max Freeman', 'Josh Mofet'],
      driverMatchMode: MatchMode.any,
    );
    final partial = EntityResolutionResult.clarification(
      parsedQuery: multi,
      clarificationQuestion: 'Which person?',
      candidates: const [_person2],
      resolutions: {
        'driver:Max Freeman': const EntityResolution(
          type: EntityType.driver,
          rawPhrase: 'Max Freeman',
          resolvedCandidate: _person1,
          confidence: .95,
          strategy: 'unique_match',
        ),
        'driver:Josh Mofet': const EntityResolution(
          type: EntityType.driver,
          rawPhrase: 'Josh Mofet',
          confidence: .8,
          strategy: 'insufficient_gap',
          isAmbiguous: true,
          candidateOptions: [_person2],
        ),
      },
    );
    final resolver = ControlledFallbackEntityResolver(
      legacyResolver: _CountingResolver(_noMatch(multi)),
      entitySearchResolver: _CountingResolver(partial),
      config: const EntitySearchFallbackConfig(
        mode: EntitySearchFallbackMode.fallback,
      ),
    );
    final result = await resolver.resolve(multi);
    expect(result.requiresClarification, isTrue);
    expect(
      result
          .resolutions['driver:Max Freeman']
          ?.resolvedCandidate
          ?.metadata?['accountId'],
      'account-max',
    );
    expect(result.resolutions['driver:Josh Mofet']?.isAmbiguous, isTrue);
    expect(multi.driverMatchMode, MatchMode.any);
  });

  test('feature flag values are configurable', () {
    expect(
      EntitySearchFallbackConfig.fromValue(null).mode,
      EntitySearchFallbackMode.off,
    );
    expect(
      EntitySearchFallbackConfig.fromValue('SHADOW').mode,
      EntitySearchFallbackMode.shadow,
    );
    expect(
      EntitySearchFallbackConfig.fromValue('fallback').mode,
      EntitySearchFallbackMode.fallback,
    );
  });
}

const _rally = EntityCandidate(
  id: 'event-1',
  type: EntityType.rally,
  canonicalName: 'Rally Alūksne 2026',
  metadata: {
    'candidateOrigin': 'entitySearch',
    'retrievalSignals': {'exact': 0.0, 'normalizedExact': 0.0},
  },
);
const _person1 = EntityCandidate(
  id: 'account-max',
  type: EntityType.driver,
  canonicalName: 'Max Freeman',
  metadata: {'accountId': 'account-max', 'driverId': 'driver-max'},
);
const _person2 = EntityCandidate(
  id: 'account-josh',
  type: EntityType.driver,
  canonicalName: 'Josh Moffett',
  metadata: {'accountId': 'account-josh', 'driverId': 'driver-josh'},
);

EntityResolutionResult _resolved(
  SearchQuery query,
  EntityCandidate candidate,
) => EntityResolutionResult(
  parsedQuery: query,
  resolvedQuery: query.copyWith(
    rallyNames: candidate.type == EntityType.rally
        ? [candidate.canonicalName]
        : null,
    driverNames: candidate.type == EntityType.driver
        ? [candidate.canonicalName]
        : null,
    driverIds: candidate.type == EntityType.driver ? [candidate.id] : null,
  ),
  resolutions: {
    candidate.type == EntityType.rally ? 'rally' : 'driver': EntityResolution(
      type: candidate.type,
      rawPhrase: query.targetRallyName ?? query.driverName ?? '',
      resolvedCandidate: candidate,
      confidence: .95,
      strategy: 'unique_match',
    ),
  },
);
EntityResolutionResult _noMatch(SearchQuery query) =>
    EntityResolutionResult.failure('not found', parsedQuery: query);

class _CountingResolver implements EntityResolver {
  final EntityResolutionResult result;
  int calls = 0;
  _CountingResolver(this.result);
  @override
  Future<EntityResolutionResult> resolve(
    SearchQuery query, {
    SearchContext? context,
  }) async {
    calls++;
    return result;
  }
}

class _Telemetry implements IEntitySearchFallbackTelemetry {
  final values = <EntitySearchShadowDiagnostic>[];
  @override
  void record(EntitySearchShadowDiagnostic diagnostic) =>
      values.add(diagnostic);
}
