import '../../../models/entity_candidate.dart';
import '../../../models/search_intent.dart';
import '../../../models/search_query.dart';
import '../llm_query_parser.dart';
import 'entity_lookup_repository.dart';
import 'entity_resolver.dart';
import 'phonetic_matching_helper.dart';

/// Database-backed deterministic Entity Resolution Service.
///
/// Converts raw/corrupted LLM extracted entity phrases into canonical database UUIDs
/// using candidate retrieval and phonetic ranking.
class DatabaseEntityResolver implements EntityResolver {
  final IEntityLookupRepository _repository;
  final double minConfidenceThreshold;
  final double minScoreGap;

  // In-memory query-level resolution cache
  final Map<String, EntityResolution> _resolutionCache = {};

  DatabaseEntityResolver({
    required IEntityLookupRepository repository,
    this.minConfidenceThreshold = 0.75,
    this.minScoreGap = 0.15,
  }) : _repository = repository;

  /// Clears the resolution cache.
  void clearCache() {
    _resolutionCache.clear();
  }

  /// Resolves all open-set entity mentions inside [query] deterministically.
  @override
  Future<EntityResolutionResult> resolve(
    SearchQuery query, {
    SearchContext? context,
  }) async {
    SearchQuery workingQuery = query;
    final resolutions = <String, EntityResolution>{};

    EntityCandidate? resolvedRallyCandidate;

    // =========================================================================
    // STEP 1: RESOLVE RALLY / EVENT
    // =========================================================================
    final rawRally = query.targetRallyName;
    if (rawRally != null && rawRally.trim().isNotEmpty) {
      final isVideoSearch = query.intent == SearchIntent.searchVideoActions || query.intent == SearchIntent.searchDriverVideos;
      final rallyRes = await _resolveRally(
        rawRally.trim(),
        year: query.year,
        country: query.country,
        city: query.city,
        isVideoSearch: isVideoSearch,
      );

      resolutions['rally'] = rallyRes;

      if (rallyRes.isAmbiguous) {
        // Deterministic Policy: Distinguish REQUIRED vs OPTIONAL / low-confidence hallucinated entities
        // If intent is SEARCH_RALLIES (which searches rallies by country/year/city) and a strongly valid country exists,
        // and an unrecognized noisy rally phrase has low confidence (< 0.40), do NOT block the search with clarification.
        final hasStrongCountry = query.country != null && query.country!.trim().isNotEmpty && query.country!.toUpperCase() != 'ALL';
        final isBroadRalliesIntent = query.intent == SearchIntent.searchRallies;
        final isLowConfidenceNoise = rallyRes.confidence < 0.40;

        if (!(isBroadRalliesIntent && hasStrongCountry && isLowConfidenceNoise)) {
          return EntityResolutionResult.clarification(
            parsedQuery: query,
            clarificationQuestion: 'Which rally event do you mean?',
            candidates: rallyRes.candidateOptions,
            resolutions: resolutions,
          );
        }
      }

      if (rallyRes.resolvedCandidate != null) {
        resolvedRallyCandidate = rallyRes.resolvedCandidate;
        workingQuery = workingQuery.copyWith(
          rallyName: resolvedRallyCandidate!.canonicalName,
          eventName: resolvedRallyCandidate.canonicalName,
        );
      }
    }

    // =========================================================================
    // STEP 2: RESOLVE STAGE WITHIN EVENT
    // =========================================================================
    final rawStage = query.stageName;
    if (rawStage != null && rawStage.trim().isNotEmpty) {
      final stageRes = await _resolveStage(
        rawStage.trim(),
        eventId: resolvedRallyCandidate?.id,
        eventName: resolvedRallyCandidate?.canonicalName ?? query.targetRallyName,
      );

      resolutions['stage'] = stageRes;

      if (stageRes.isAmbiguous) {
        return EntityResolutionResult.clarification(
          parsedQuery: query,
          clarificationQuestion: 'Which stage do you mean?',
          candidates: stageRes.candidateOptions,
          resolutions: resolutions,
        );
      }

      if (stageRes.resolvedCandidate != null) {
        workingQuery = workingQuery.copyWith(
          stageName: stageRes.resolvedCandidate!.canonicalName,
          stageNumber: stageRes.resolvedCandidate!.metadata?['stageNumber']?.toString() ?? workingQuery.stageNumber,
        );
      }
    }

    // =========================================================================
    // STEP 3: RESOLVE DRIVER USING EVENT / YEAR CONTEXT
    // =========================================================================
    final rawDriver = query.driverName;
    if (rawDriver != null && rawDriver.trim().isNotEmpty) {
      final driverRes = await _resolveDriver(
        rawDriver.trim(),
        eventId: resolvedRallyCandidate?.id,
        eventName: resolvedRallyCandidate?.canonicalName ?? query.targetRallyName,
        year: query.year,
      );

      resolutions['driver'] = driverRes;

      if (driverRes.isAmbiguous) {
        return EntityResolutionResult.clarification(
          parsedQuery: query,
          clarificationQuestion: 'Which driver named "${rawDriver.trim()}" do you mean?',
          candidates: driverRes.candidateOptions,
          resolutions: resolutions,
        );
      }

      if (driverRes.resolvedCandidate != null) {
        workingQuery = workingQuery.copyWith(
          driverId: driverRes.resolvedCandidate!.id,
          driverName: driverRes.resolvedCandidate!.canonicalName,
        );
      }
    }

    // =========================================================================
    // STEP 4: RESOLVE CITY / LOCATION & CHECK FOR LOCATION AMBIGUITY
    // =========================================================================
    final rawCity = query.city;
    if (rawCity != null && rawCity.trim().isNotEmpty && rawCity.toUpperCase() != 'ALL') {
      final cityRes = await _resolveCity(
        rawCity.trim(),
        country: query.country,
        targetRallyName: resolvedRallyCandidate?.canonicalName ?? query.targetRallyName,
      );

      resolutions['city'] = cityRes;

      if (cityRes.isAmbiguous) {
        return EntityResolutionResult.clarification(
          parsedQuery: query,
          clarificationQuestion: 'Which location named "${rawCity.trim()}" do you mean?',
          candidates: cityRes.candidateOptions,
          resolutions: resolutions,
        );
      }

      if (cityRes.resolvedCandidate != null) {
        workingQuery = workingQuery.copyWith(
          city: cityRes.resolvedCandidate!.canonicalName,
        );
      }
    }

    return EntityResolutionResult(
      parsedQuery: query,
      resolvedQuery: workingQuery,
      requiresClarification: false,
      resolutions: resolutions,
    );
  }

  // ===========================================================================
  // RALLY RESOLUTION
  // ===========================================================================
  Future<EntityResolution> _resolveRally(
    String phrase, {
    int? year,
    String? country,
    String? city,
    bool isVideoSearch = false,
  }) async {
    final cacheKey = 'rally:${phrase.toLowerCase()}:${year ?? ''}:${country ?? ''}:${city ?? ''}:$isVideoSearch';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    final candidates = await _repository.lookupRallies(
      phrase,
      year: year,
      country: country,
      city: city,
      limit: 10,
    );

    if (candidates.isEmpty) {
      final res = EntityResolution(
        type: EntityType.rally,
        rawPhrase: phrase,
        confidence: 0.0,
        strategy: 'none',
      );
      _putInCache(cacheKey, res);
      return res;
    }

    // Score and rank candidates
    final scored = _scoreCandidates(phrase, candidates, year: year);

    // Check for multi-edition ambiguity:
    // If user provided no year and multiple editions of the same rally exist (e.g. 2025, 2026),
    // trigger clarification for general rally queries, but allow video action highlights to resolve
    // to the most recent active edition.
    if (year == null && scored.length > 1) {
      final topName = _normalizeName(scored[0].canonicalName);
      final secondName = _normalizeName(scored[1].canonicalName);

      // Check if they share the same base championship/event name across different years
      final baseTop = _stripYear(topName);
      final baseSecond = _stripYear(secondName);

      if (baseTop.isNotEmpty && baseTop == baseSecond) {
        if (!isVideoSearch) {
          final res = EntityResolution(
            type: EntityType.rally,
            rawPhrase: phrase,
            confidence: 0.5,
            strategy: 'multi_year_ambiguity',
            isAmbiguous: true,
            candidateOptions: scored,
          );
          _putInCache(cacheKey, res);
          return res;
        }
      }
    }

    // Policy check: confidence and gap analysis
    final policy = _evaluateCandidateSelection(phrase, scored);
    _putInCache(cacheKey, policy);
    return policy;
  }

  // ===========================================================================
  // DRIVER RESOLUTION
  // ===========================================================================
  Future<EntityResolution> _resolveDriver(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
  }) async {
    final cacheKey = 'driver:${phrase.toLowerCase()}:${eventId ?? ''}:${eventName ?? ''}:${year ?? ''}';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    final candidates = await _repository.lookupDrivers(
      phrase,
      eventId: eventId,
      eventName: eventName,
      year: year,
      limit: 10,
    );

    if (candidates.isEmpty) {
      final res = EntityResolution(
        type: EntityType.driver,
        rawPhrase: phrase,
        confidence: 0.0,
        strategy: 'none',
      );
      _putInCache(cacheKey, res);
      return res;
    }

    // Score and rank candidates with context awareness
    final scored = _scoreCandidates(phrase, candidates, year: year);

    // Check for Ambiguous Driver Names (e.g., single surname or single first name)
    final cleanLower = phrase.trim().toLowerCase();
    final isPartialName = !cleanLower.contains(' ');

    if (isPartialName && scored.length > 1) {
      final res = EntityResolution(
        type: EntityType.driver,
        rawPhrase: phrase,
        confidence: 0.5,
        strategy: 'partial_name_ambiguity',
        isAmbiguous: true,
        candidateOptions: scored,
      );
      _putInCache(cacheKey, res);
      return res;
    }

    final policy = _evaluateCandidateSelection(phrase, scored);
    _putInCache(cacheKey, policy);
    return policy;
  }

  // ===========================================================================
  // STAGE RESOLUTION
  // ===========================================================================
  Future<EntityResolution> _resolveStage(
    String phrase, {
    String? eventId,
    String? eventName,
  }) async {
    final cacheKey = 'stage:${phrase.toLowerCase()}:${eventId ?? ''}:${eventName ?? ''}';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    final candidates = await _repository.lookupStages(
      phrase,
      eventId: eventId,
      eventName: eventName,
      limit: 10,
    );

    if (candidates.isEmpty) {
      final res = EntityResolution(
        type: EntityType.stage,
        rawPhrase: phrase,
        confidence: 0.0,
        strategy: 'none',
      );
      _putInCache(cacheKey, res);
      return res;
    }

    final scored = _scoreCandidates(phrase, candidates);
    final policy = _evaluateCandidateSelection(phrase, scored);
    _putInCache(cacheKey, policy);
    return policy;
  }

  // ===========================================================================
  // CITY RESOLUTION
  // ===========================================================================
  Future<EntityResolution> _resolveCity(
    String phrase, {
    String? country,
    String? targetRallyName,
  }) async {
    final cacheKey = 'city:${phrase.toLowerCase()}:${country ?? ''}:${targetRallyName ?? ''}';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    // Check if phrase also matches a prominent rally name (e.g. "Donegal") when no rally name was specified
    if (targetRallyName == null) {
      final rallyMatches = await _repository.lookupRallies(phrase, limit: 5);
      final cityMatches = await _repository.lookupCities(phrase, country: country, limit: 5);

      if (rallyMatches.isNotEmpty && cityMatches.isNotEmpty) {
        // Both city and rally interpretations exist
        final combinedCandidates = <EntityCandidate>[
          ...cityMatches,
          ...rallyMatches,
        ];
        final res = EntityResolution(
          type: EntityType.city,
          rawPhrase: phrase,
          confidence: 0.5,
          strategy: 'location_vs_event_ambiguity',
          isAmbiguous: true,
          candidateOptions: combinedCandidates,
        );
        _putInCache(cacheKey, res);
        return res;
      }
    }

    final candidates = await _repository.lookupCities(
      phrase,
      country: country,
      limit: 10,
    );

    if (candidates.isEmpty) {
      final res = EntityResolution(
        type: EntityType.city,
        rawPhrase: phrase,
        confidence: 0.0,
        strategy: 'none',
      );
      _putInCache(cacheKey, res);
      return res;
    }

    final scored = _scoreCandidates(phrase, candidates);
    final policy = _evaluateCandidateSelection(phrase, scored);
    _putInCache(cacheKey, policy);
    return policy;
  }

  // ===========================================================================
  // CANDIDATE SCORING & AMBIGUITY POLICY EVALUATION
  // ===========================================================================
  List<EntityCandidate> _scoreCandidates(
    String phrase,
    List<EntityCandidate> candidates, {
    int? year,
  }) {
    final scored = <EntityCandidate>[];

    for (final c in candidates) {
      final candidateYear = c.metadata?['year'] as int?;
      final inContext = c.metadata?['inContext'] as bool? ?? false;

      final baseScore = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: phrase,
        candidateName: c.canonicalName,
      );

      final score = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: phrase,
        candidateName: c.canonicalName,
        queryYear: year,
        candidateYear: candidateYear,
        inContext: inContext,
      );

      final updatedMetadata = Map<String, dynamic>.from(c.metadata ?? {});
      updatedMetadata['baseScore'] = baseScore;

      scored.add(c.copyWith(score: score, metadata: updatedMetadata));
    }

    // Sort descending by similarity score
    scored.sort((a, b) => (b.score ?? 0.0).compareTo(a.score ?? 0.0));
    return scored;
  }

  EntityResolution _evaluateCandidateSelection(
    String phrase,
    List<EntityCandidate> scoredCandidates,
  ) {
    if (scoredCandidates.isEmpty) {
      return EntityResolution(
        type: EntityType.rally,
        rawPhrase: phrase,
        confidence: 0.0,
        strategy: 'none',
      );
    }

    final top = scoredCandidates.first;
    final topScore = top.score ?? 0.0;

    // Check if top candidate meets confidence threshold
    if (topScore < minConfidenceThreshold) {
      return EntityResolution(
        type: top.type,
        rawPhrase: phrase,
        confidence: topScore,
        strategy: 'below_threshold',
        candidateOptions: scoredCandidates,
      );
    }

    // If only one candidate meets threshold, unique resolution
    if (scoredCandidates.length == 1) {
      return EntityResolution(
        type: top.type,
        rawPhrase: phrase,
        resolvedCandidate: top,
        confidence: topScore,
        strategy: 'unique_match',
      );
    }

    // Multi-candidate evaluation: Check Score Gap
    final runnerUp = scoredCandidates[1];
    final runnerUpScore = runnerUp.score ?? 0.0;
    final gap = topScore - runnerUpScore;

    // Check base similarity gap if both received context boosts
    final baseTop = (top.metadata?['baseScore'] as double?) ?? topScore;
    final baseRunnerUp = (runnerUp.metadata?['baseScore'] as double?) ?? runnerUpScore;
    final baseGap = baseTop - baseRunnerUp;

    if (gap >= minScoreGap || (topScore >= minConfidenceThreshold && baseGap >= minScoreGap)) {
      return EntityResolution(
        type: top.type,
        rawPhrase: phrase,
        resolvedCandidate: top,
        confidence: topScore,
        strategy: 'clear_winner',
      );
    }

    // Gap is insufficient -> Mark ambiguous and require clarification
    return EntityResolution(
      type: top.type,
      rawPhrase: phrase,
      confidence: topScore,
      strategy: 'insufficient_gap',
      isAmbiguous: true,
      candidateOptions: scoredCandidates.where((c) => (c.score ?? 0.0) >= minConfidenceThreshold - 0.10).toList(),
    );
  }

  String _normalizeName(String input) => PhoneticMatchingHelper.normalize(input);

  String _stripYear(String input) => PhoneticMatchingHelper.stripYear(input);

  EntityResolution? _getFromCache(String key) => _resolutionCache[key];

  void _putInCache(String key, EntityResolution value) {
    _resolutionCache[key] = value;
  }
}
