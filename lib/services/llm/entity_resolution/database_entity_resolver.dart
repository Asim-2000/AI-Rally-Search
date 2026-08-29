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
/// Supports multi-entity list resolution independently per dimension while preserving partial resolutions.
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

    EntityCandidate? primaryResolvedRally;
    final resolvedRallies = <String>[];
    final resolvedDrivers = <String>[];
    final resolvedDriverIds = <String>[];
    final resolvedStages = <String>[];
    final resolvedStageNumbers = <String>[];
    final resolvedCities = <String>[];

    // =========================================================================
    // STEP 1: RESOLVE RALLIES / EVENTS
    // =========================================================================
    final rawRallies = query.targetRallyNames;
    if (rawRallies.isNotEmpty) {
      final isVideoSearch =
          query.intent == SearchIntent.searchVideoActions ||
          query.intent == SearchIntent.searchDriverVideos;
      for (final rawRally in rawRallies) {
        if (rawRally.trim().isEmpty) continue;
        final rallyRes = await _resolveRally(
          rawRally.trim(),
          year: query.years.length == 1 ? query.years.first : null,
          years: query.years,
          country: query.countries.length == 1 ? query.countries.first : null,
          countries: query.countries,
          city: query.cities.length == 1 ? query.cities.first : null,
          isVideoSearch: isVideoSearch,
        );

        resolutions['rally:$rawRally'] = rallyRes;
        if (rawRallies.length == 1) {
          resolutions['rally'] = rallyRes;
        }

        if (rallyRes.isAmbiguous) {
          // Deterministic Policy: Distinguish REQUIRED vs OPTIONAL / low-confidence hallucinated entities
          final hasStrongCountry = query.countries.isNotEmpty;
          final isBroadRalliesIntent =
              query.intent == SearchIntent.searchRallies;
          final isLowConfidenceNoise = rallyRes.confidence < 0.40;

          if (!(isBroadRalliesIntent &&
              hasStrongCountry &&
              isLowConfidenceNoise)) {
            final question =
                rallyRes.strategy == 'plausible_candidates' &&
                    rallyRes.candidateOptions.isNotEmpty
                ? 'Did you mean "${rallyRes.candidateOptions.first.canonicalName}"?'
                : (rawRallies.length > 1
                      ? 'Which rally event named "${rawRally.trim()}" do you mean?'
                      : (rallyRes.strategy == 'multi_year_ambiguity'
                            ? 'Which year or edition of "${rawRally.trim()}" are you looking for?'
                            : 'Which rally event named "${rawRally.trim()}" do you mean?'));

            return EntityResolutionResult.clarification(
              parsedQuery: query,
              clarificationQuestion: question,
              candidates: rallyRes.candidateOptions,
              resolutions: resolutions,
            );
          }
        }

        if (rallyRes.resolvedCandidate != null) {
          primaryResolvedRally ??= rallyRes.resolvedCandidate;
          resolvedRallies.add(rallyRes.resolvedCandidate!.canonicalName);
        } else {
          final isEntityRequiredIntent =
              query.intent == SearchIntent.searchVideoActions ||
              query.intent == SearchIntent.getRallyResults ||
              query.intent == SearchIntent.getRallyTopFinishers ||
              query.intent == SearchIntent.getTopUploaders;
          if (isEntityRequiredIntent) {
            return EntityResolutionResult.failure(
              'We couldn\'t confidently identify that rally ("${rawRally.trim()}").',
              parsedQuery: query,
            );
          }
          resolvedRallies.add(rawRally.trim());
        }
      }

      workingQuery = workingQuery.copyWith(
        rallyNames: resolvedRallies,
        eventNames: resolvedRallies,
      );
    }

    // =========================================================================
    // STEP 2: RESOLVE STAGES USING RALLY CONTEXT
    // =========================================================================
    final rawStages = query.stageNames;
    if (rawStages.isNotEmpty) {
      for (final rawStage in rawStages) {
        if (rawStage.trim().isEmpty) continue;
        final stageRes = await _resolveStage(
          rawStage.trim(),
          eventId: primaryResolvedRally?.id,
          eventName:
              primaryResolvedRally?.canonicalName ?? query.targetRallyName,
        );

        resolutions['stage:$rawStage'] = stageRes;
        if (rawStages.length == 1) {
          resolutions['stage'] = stageRes;
        }

        if (stageRes.isAmbiguous) {
          final question =
              stageRes.strategy == 'plausible_candidates' &&
                  stageRes.candidateOptions.isNotEmpty
              ? 'Did you mean "${stageRes.candidateOptions.first.canonicalName}"?'
              : 'Which stage named "${rawStage.trim()}" do you mean?';

          return EntityResolutionResult.clarification(
            parsedQuery: query,
            clarificationQuestion: question,
            candidates: stageRes.candidateOptions,
            resolutions: resolutions,
          );
        }

        if (stageRes.resolvedCandidate != null) {
          resolvedStages.add(stageRes.resolvedCandidate!.canonicalName);
          final stageNum = stageRes.resolvedCandidate!.metadata?['stageNumber']
              ?.toString();
          if (stageNum != null && stageNum.isNotEmpty) {
            resolvedStageNumbers.add(stageNum);
          }
        } else {
          final isStageRequiredIntent =
              query.intent == SearchIntent.searchVideoActions;
          if (isStageRequiredIntent && query.stageNames.length == 1) {
            return EntityResolutionResult.failure(
              'We couldn\'t confidently identify that stage ("${rawStage.trim()}").',
              parsedQuery: query,
            );
          }
          resolvedStages.add(rawStage.trim());
        }
      }

      workingQuery = workingQuery.copyWith(
        stageNames: resolvedStages,
        stageNumbers: resolvedStageNumbers.isNotEmpty
            ? resolvedStageNumbers
            : workingQuery.stageNumbers,
      );
    }

    // =========================================================================
    // STEP 3: RESOLVE DRIVERS USING EVENT / YEAR CONTEXT
    // =========================================================================
    final rawDrivers = query.driverNames;
    if (rawDrivers.isNotEmpty) {
      for (final rawDriver in rawDrivers) {
        if (rawDriver.trim().isEmpty) continue;
        final driverRes = await _resolveDriver(
          rawDriver.trim(),
          eventId: primaryResolvedRally?.id,
          eventName:
              primaryResolvedRally?.canonicalName ?? query.targetRallyName,
          year: query.years.length == 1 ? query.years.first : null,
          years: query.years,
          personRole: query.personRole,
        );

        resolutions['driver:$rawDriver'] = driverRes;
        if (rawDrivers.length == 1) {
          resolutions['driver'] = driverRes;
        }

        if (driverRes.isAmbiguous) {
          // Preserve already-resolved entities into workingQuery before prompting clarification
          final updatedWorkingQuery = workingQuery.copyWith(
            driverIds: resolvedDriverIds,
            driverNames: resolvedDrivers.isNotEmpty
                ? resolvedDrivers
                : workingQuery.driverNames,
          );

          final question =
              driverRes.strategy == 'plausible_candidates' &&
                  driverRes.candidateOptions.isNotEmpty
              ? 'Did you mean "${driverRes.candidateOptions.first.canonicalName}"?'
              : 'Which driver named "${rawDriver.trim()}" do you mean?';

          return EntityResolutionResult.clarification(
            parsedQuery: query,
            clarificationQuestion: question,
            candidates: driverRes.candidateOptions,
            resolutions: resolutions,
          );
        }

        if (driverRes.resolvedCandidate != null) {
          final cand = driverRes.resolvedCandidate!;
          final driverId = cand.metadata?['driverId']?.toString();
          final codriverId = cand.metadata?['codriverId']?.toString();

          switch (workingQuery.personRole) {
            case PersonRole.driver:
              if (driverId != null &&
                  driverId.isNotEmpty &&
                  driverId != 'null') {
                resolvedDriverIds.add(driverId);
              }
              break;
            case PersonRole.coDriver:
              if (codriverId != null &&
                  codriverId.isNotEmpty &&
                  codriverId != 'null') {
                resolvedDriverIds.add(codriverId);
              }
              break;
            case PersonRole.any:
              var addedCurrentCandidate = false;
              if (driverId != null &&
                  driverId.isNotEmpty &&
                  driverId != 'null') {
                resolvedDriverIds.add(driverId);
                addedCurrentCandidate = true;
              }
              if (codriverId != null &&
                  codriverId.isNotEmpty &&
                  codriverId != 'null') {
                resolvedDriverIds.add(codriverId);
                addedCurrentCandidate = true;
              }
              if (!addedCurrentCandidate) {
                resolvedDriverIds.add(cand.id);
              }
              break;
          }
          resolvedDrivers.add(cand.canonicalName);
        } else {
          final isDriverRequiredIntent =
              query.intent == SearchIntent.searchDriverVideos ||
              query.intent == SearchIntent.searchDriverRallies;
          if (isDriverRequiredIntent) {
            return EntityResolutionResult.failure(
              'We couldn\'t confidently identify that driver ("${rawDriver.trim()}").',
              parsedQuery: query,
            );
          }
          resolvedDrivers.add(rawDriver.trim());
        }
      }

      workingQuery = workingQuery.copyWith(
        driverIds: resolvedDriverIds,
        driverNames: resolvedDrivers,
      );
    }

    // =========================================================================
    // STEP 4: RESOLVE CITIES / LOCATIONS
    // =========================================================================
    final rawCities = query.cities;
    if (rawCities.isNotEmpty) {
      for (final rawCity in rawCities) {
        if (rawCity.trim().isEmpty || rawCity.toUpperCase() == 'ALL') continue;
        final cityRes = await _resolveCity(
          rawCity.trim(),
          country: query.countries.length == 1 ? query.countries.first : null,
          targetRallyName:
              primaryResolvedRally?.canonicalName ?? query.targetRallyName,
        );

        resolutions['city:$rawCity'] = cityRes;
        if (rawCities.length == 1) {
          resolutions['city'] = cityRes;
        }

        if (cityRes.isAmbiguous) {
          return EntityResolutionResult.clarification(
            parsedQuery: query,
            clarificationQuestion:
                'Which location named "${rawCity.trim()}" do you mean?',
            candidates: cityRes.candidateOptions,
            resolutions: resolutions,
          );
        }

        if (cityRes.resolvedCandidate != null) {
          resolvedCities.add(cityRes.resolvedCandidate!.canonicalName);
        } else {
          resolvedCities.add(rawCity.trim());
        }
      }

      workingQuery = workingQuery.copyWith(cities: resolvedCities);
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
    List<int>? years,
    String? country,
    List<String>? countries,
    String? city,
    bool isVideoSearch = false,
  }) async {
    final phraseYear = _extractYear(phrase);
    final effectiveYear =
        year ?? (years != null && years.length == 1 ? years.first : null);
    final lookupYear = phraseYear ?? effectiveYear;
    final effectiveCountry =
        country ??
        (countries != null && countries.length == 1 ? countries.first : null);
    final yearsKey = (years != null && years.isNotEmpty)
        ? years.join(',')
        : (lookupYear?.toString() ?? '');
    final countriesKey = (countries != null && countries.isNotEmpty)
        ? countries.join(',')
        : (effectiveCountry ?? '');
    final cacheKey =
        'rally:${phrase.toLowerCase()}:$yearsKey:$countriesKey:${city ?? ''}:$isVideoSearch';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    final candidates = await _repository.lookupRallies(
      phrase,
      year: lookupYear,
      country: effectiveCountry,
      city: city,
      limit: 35,
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
    final scored = _scoreCandidates(
      phrase,
      candidates,
      year: lookupYear,
      years: phraseYear == null ? years : [phraseYear],
    );

    // A normalized canonical-name match identifies a single, user-specified
    // edition. It must not be downgraded into fuzzy multi-edition handling.
    final normalizedPhrase = _normalizeName(phrase);
    final exactCanonical = scored.where(
      (candidate) =>
          _normalizeName(candidate.canonicalName) == normalizedPhrase,
    );
    if (exactCanonical.isNotEmpty) {
      final candidate = exactCanonical.first;
      final res = EntityResolution(
        type: EntityType.rally,
        rawPhrase: phrase,
        resolvedCandidate: candidate,
        confidence: candidate.score ?? 1.0,
        strategy: 'exact_canonical_match',
      );
      _putInCache(cacheKey, res);
      return res;
    }

    // Check for multi-edition ambiguity:
    // If user provided no year and multiple editions of the same rally exist (e.g. 2025, 2026),
    // trigger clarification for general rally queries, but allow video action highlights to resolve
    // to the most recent active edition.
    final hasExplicitYears =
        (lookupYear != null) || (years != null && years.isNotEmpty);
    if (!hasExplicitYears && scored.length > 1) {
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
            candidateOptions: scored.take(5).toList(),
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
    List<int>? years,
    PersonRole personRole = PersonRole.any,
  }) async {
    final effectiveYear =
        year ?? (years != null && years.length == 1 ? years.first : null);
    final yearsKey = (years != null && years.isNotEmpty)
        ? years.join(',')
        : (effectiveYear?.toString() ?? '');
    final cacheKey =
        'driver:${phrase.toLowerCase()}:${eventId ?? ''}:${eventName ?? ''}:$yearsKey:${personRole.name}';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    final candidates = await _repository.lookupDrivers(
      phrase,
      eventId: eventId,
      eventName: eventName,
      year: effectiveYear,
      personRole: personRole,
      limit: 50,
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
        candidateOptions: scored.take(5).toList(),
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
    final cacheKey =
        'stage:${phrase.toLowerCase()}:${eventId ?? ''}:${eventName ?? ''}';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    final candidates = await _repository.lookupStages(
      phrase,
      eventId: eventId,
      eventName: eventName,
      limit: 35,
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
    final cacheKey =
        'city:${phrase.toLowerCase()}:${country ?? ''}:${targetRallyName ?? ''}';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    // Check if phrase also matches a prominent rally name (e.g. "Donegal") when no rally name was specified
    if (targetRallyName == null) {
      final rallyMatches = await _repository.lookupRallies(phrase, limit: 5);
      final cityMatches = await _repository.lookupCities(
        phrase,
        country: country,
        limit: 5,
      );

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
          candidateOptions: combinedCandidates.take(5).toList(),
        );
        _putInCache(cacheKey, res);
        return res;
      }
    }

    final candidates = await _repository.lookupCities(
      phrase,
      country: country,
      limit: 25,
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
    List<int>? years,
  }) {
    final scored = <EntityCandidate>[];
    final effectiveYears = (years != null && years.isNotEmpty)
        ? years
        : (year != null ? [year] : const <int>[]);

    for (final c in candidates) {
      final candidateYear = c.metadata?['year'] as int?;
      final inContext = c.metadata?['inContext'] as bool? ?? false;
      final yearMatch =
          candidateYear != null && effectiveYears.contains(candidateYear);

      final isPerson = c.type == EntityType.driver;
      final scoringName = isPerson
          ? (c.metadata?['matchedSearchableName']?.toString() ??
                c.canonicalName)
          : c.canonicalName;

      final baseScore = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: phrase,
        candidateName: scoringName,
        isPerson: isPerson,
      );

      final score = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: phrase,
        candidateName: scoringName,
        queryYear: yearMatch
            ? candidateYear
            : (effectiveYears.isNotEmpty ? effectiveYears.first : year),
        candidateYear: candidateYear,
        inContext: inContext,
        isPerson: isPerson,
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

    // Distinct account identities with the same effective person name and
    // indistinguishable scores must never be resolved by database/list order.
    if (top.type == EntityType.driver && topScore >= minConfidenceThreshold) {
      final topIdentity = top.metadata?['accountId']?.toString() ?? top.id;
      final topMatchedName =
          top.metadata?['matchedSearchableName']?.toString() ??
          top.canonicalName;
      final duplicateIdentities = scoredCandidates.where((candidate) {
        if (candidate.type != EntityType.driver) return false;
        final identity =
            candidate.metadata?['accountId']?.toString() ?? candidate.id;
        return identity != topIdentity &&
            _normalizeName(
                  candidate.metadata?['matchedSearchableName']?.toString() ??
                      candidate.canonicalName,
                ) ==
                _normalizeName(topMatchedName) &&
            ((candidate.score ?? 0.0) - topScore).abs() <= 0.000001;
      }).toList();
      if (duplicateIdentities.isNotEmpty) {
        return EntityResolution(
          type: top.type,
          rawPhrase: phrase,
          confidence: topScore,
          strategy: 'duplicate_person_identity',
          isAmbiguous: true,
          candidateOptions: [top, ...duplicateIdentities].take(5).toList(),
        );
      }
    }

    // Check if top candidate meets confidence threshold
    if (topScore < minConfidenceThreshold) {
      final isPlausible = topScore >= 0.50;
      return EntityResolution(
        type: top.type,
        rawPhrase: phrase,
        confidence: topScore,
        strategy: isPlausible ? 'plausible_candidates' : 'below_threshold',
        isAmbiguous: isPlausible,
        candidateOptions: isPlausible
            ? scoredCandidates.take(5).toList()
            : const [],
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
    final baseRunnerUp =
        (runnerUp.metadata?['baseScore'] as double?) ?? runnerUpScore;
    final baseGap = baseTop - baseRunnerUp;

    if (gap >= minScoreGap ||
        (topScore >= minConfidenceThreshold && baseGap >= minScoreGap)) {
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
      candidateOptions: scoredCandidates
          .where((c) => (c.score ?? 0.0) >= minConfidenceThreshold - 0.10)
          .toList(),
    );
  }

  String _normalizeName(String input) =>
      PhoneticMatchingHelper.normalize(input);

  int? _extractYear(String input) {
    final match = RegExp(r'\\b(?:19|20)\\d{2}\\b').firstMatch(input);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  String _stripYear(String input) => PhoneticMatchingHelper.stripYear(input);

  EntityResolution? _getFromCache(String key) => _resolutionCache[key];

  void _putInCache(String key, EntityResolution value) {
    _resolutionCache[key] = value;
  }
}
