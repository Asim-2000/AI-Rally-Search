import '../../../models/entity_candidate.dart';
import '../../../models/search_query.dart';
import '../llm_query_parser.dart';
import 'entity_lookup_repository.dart';
import 'entity_resolver.dart';

/// Database-backed deterministic entity resolution engine.
///
/// Implements staged matching, confidence thresholds, score gap analysis,
/// context-aware sequential resolution, and ambiguity protection.
class DatabaseEntityResolver implements EntityResolver {
  final IEntityLookupRepository _repository;

  /// Minimum confidence score required to auto-resolve an entity (0.0 to 1.0)
  final double minConfidenceThreshold;

  /// Minimum score difference required between top match and runner-up
  final double minScoreGap;

  /// In-memory resolution cache
  final Map<String, _CachedResolution> _cache = {};
  static const int _maxCacheEntries = 200;

  DatabaseEntityResolver({
    required IEntityLookupRepository repository,
    this.minConfidenceThreshold = 0.75,
    this.minScoreGap = 0.15,
  }) : _repository = repository;

  @override
  Future<EntityResolutionResult> resolve(
    SearchQuery query, {
    SearchContext? context,
  }) async {
    final resolutions = <String, EntityResolution>{};
    SearchQuery workingQuery = query;

    // Track if any entity required clarification
    EntityCandidate? resolvedRallyCandidate;

    // =========================================================================
    // STEP 1: RESOLVE RALLY / EVENT NAME
    // =========================================================================
    final rawRally = query.targetRallyName;
    if (rawRally != null && rawRally.trim().isNotEmpty) {
      final rallyRes = await _resolveRally(
        rawRally.trim(),
        year: query.year,
        country: query.country,
        city: query.city,
      );

      resolutions['rally'] = rallyRes;

      if (rallyRes.isAmbiguous) {
        return EntityResolutionResult.clarification(
          parsedQuery: query,
          clarificationQuestion: 'Which rally event do you mean?',
          candidates: rallyRes.candidateOptions,
          resolutions: resolutions,
        );
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
        targetRallyName: rawRally,
      );

      resolutions['city'] = cityRes;

      if (cityRes.isAmbiguous) {
        return EntityResolutionResult.clarification(
          parsedQuery: query,
          clarificationQuestion: 'Do you mean rallies located in ${rawCity.trim()}, or a specific rally event?',
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

    return EntityResolutionResult.success(
      parsedQuery: query,
      resolvedQuery: workingQuery,
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
  }) async {
    final cacheKey = 'rally:${phrase.toLowerCase()}:${year ?? ''}:${country ?? ''}:${city ?? ''}';
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
    // trigger clarification rather than guessing.
    if (year == null && scored.length > 1) {
      final topName = _normalizeName(scored[0].canonicalName);
      final secondName = _normalizeName(scored[1].canonicalName);

      // Check if they share the same base championship/event name across different years
      final baseTop = _stripYear(topName);
      final baseSecond = _stripYear(secondName);

      if (baseTop.isNotEmpty && baseTop == baseSecond) {
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

    // Score and rank candidates
    final scored = _scoreCandidates(phrase, candidates);

    // Rule: Surnames ("Moffett", "Smith") or first names ("Josh") must never resolve globally if > 1 match
    final cleanLower = phrase.trim().toLowerCase();
    final isPartialName = !cleanLower.contains(' ');

    if (isPartialName && scored.length > 1) {
      // Check if context reduced candidate set to exactly 1 inContext match
      final inContextMatches = scored.where((c) => c.metadata?['inContext'] == true).toList();
      if (inContextMatches.length == 1) {
        final single = inContextMatches.first;
        final res = EntityResolution(
          type: EntityType.driver,
          rawPhrase: phrase,
          resolvedCandidate: single,
          confidence: 0.95,
          strategy: 'context_disambiguated',
        );
        _putInCache(cacheKey, res);
        return res;
      }

      // Ambiguous partial name across multiple drivers
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
  // CITY / LOCATION RESOLUTION
  // ===========================================================================
  Future<EntityResolution> _resolveCity(
    String phrase, {
    String? country,
    String? targetRallyName,
  }) async {
    final cacheKey = 'city:${phrase.toLowerCase()}:${country ?? ''}';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    // Check if phrase also matches a prominent rally name (e.g. "Donegal")
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

    final candidates = await _repository.lookupCities(phrase, country: country, limit: 5);
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
  // SCORING & POLICY ENGINE
  // ===========================================================================

  /// Scores each candidate deterministically from 0.0 to 1.0
  List<EntityCandidate> _scoreCandidates(
    String phrase,
    List<EntityCandidate> candidates, {
    int? year,
  }) {
    final pNorm = _normalizeName(phrase);

    final scored = <EntityCandidate>[];
    for (final c in candidates) {
      final cNorm = _normalizeName(c.canonicalName);
      double score = 0.0;

      // 1. Exact match
      if (cNorm == pNorm || c.canonicalName.toLowerCase() == phrase.toLowerCase()) {
        score = 1.0;
      }
      // 2. Exact match on base name ignoring year (e.g. "Moonraker Forestry Rally" == "Moonraker Forestry Rally 2025")
      else if (_stripYear(cNorm) == _stripYear(pNorm)) {
        score = 0.95;
      }
      // 3. Prefix match
      else if (cNorm.startsWith(pNorm) || pNorm.startsWith(cNorm)) {
        score = 0.88;
      }
      // 4. Substring / contains
      else if (cNorm.contains(pNorm)) {
        // Boost shorter canonical names that tightly enclose the query
        final lengthRatio = pNorm.length / cNorm.length.clamp(1, 100);
        score = 0.70 + (0.15 * lengthRatio);
      }
      // 5. Word boundary match
      else {
        final pWords = pNorm.split(' ').where((w) => w.isNotEmpty).toSet();
        final cWords = cNorm.split(' ').where((w) => w.isNotEmpty).toSet();
        final intersection = pWords.intersection(cWords);
        if (intersection.isNotEmpty) {
          score = 0.50 + (0.30 * (intersection.length / pWords.length));
        } else {
          score = 0.30;
        }
      }

      // Contextual year boost
      if (year != null && c.metadata?['year'] == year) {
        score = (score + 0.10).clamp(0.0, 1.0);
      }

      // Contextual participation boost
      if (c.metadata?['inContext'] == true) {
        score = (score + 0.15).clamp(0.0, 1.0);
      }

      scored.add(EntityCandidate(
        id: c.id,
        type: c.type,
        canonicalName: c.canonicalName,
        subtitle: c.subtitle,
        score: double.parse(score.toStringAsFixed(3)),
        metadata: c.metadata,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// Evaluates scored candidates against confidence threshold and score gap policy
  EntityResolution _evaluateCandidateSelection(
    String phrase,
    List<EntityCandidate> scored,
  ) {
    if (scored.isEmpty) {
      return EntityResolution(
        type: EntityType.rally,
        rawPhrase: phrase,
        confidence: 0.0,
        strategy: 'none',
      );
    }

    final top = scored.first;

    // Single candidate
    if (scored.length == 1) {
      if (top.score >= minConfidenceThreshold) {
        return EntityResolution(
          type: top.type,
          rawPhrase: phrase,
          resolvedCandidate: top,
          confidence: top.score,
          strategy: 'unique_match',
        );
      } else {
        return EntityResolution(
          type: top.type,
          rawPhrase: phrase,
          confidence: top.score,
          strategy: 'low_confidence',
          isAmbiguous: true,
          candidateOptions: scored,
        );
      }
    }

    final runnerUp = scored[1];
    final scoreGap = top.score - runnerUp.score;

    // Check if top candidate clearly exceeds threshold AND satisfies minimum score gap
    if (top.score >= minConfidenceThreshold && scoreGap >= minScoreGap) {
      return EntityResolution(
        type: top.type,
        rawPhrase: phrase,
        resolvedCandidate: top,
        confidence: top.score,
        strategy: 'high_confidence_gap',
      );
    }

    // Ambiguous: top candidates are too close in score or confidence is insufficient
    return EntityResolution(
      type: top.type,
      rawPhrase: phrase,
      confidence: top.score,
      strategy: 'insufficient_gap',
      isAmbiguous: true,
      candidateOptions: scored,
    );
  }

  // ===========================================================================
  // HELPERS & CACHE
  // ===========================================================================
  static String _normalizeName(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s]"), '') // strip punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // collapse whitespace
        .trim();
  }

  static String _stripYear(String s) {
    return s.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  EntityResolution? _getFromCache(String key) {
    final entry = _cache[key];
    if (entry != null) {
      return entry.resolution;
    }
    return null;
  }

  void _putInCache(String key, EntityResolution res) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CachedResolution(res);
  }
}

class _CachedResolution {
  final EntityResolution resolution;
  final DateTime timestamp;

  _CachedResolution(this.resolution) : timestamp = DateTime.now();
}
