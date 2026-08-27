import 'dart:convert';
import '../../models/search_intent.dart';
import '../../models/search_query.dart';
import 'llm_provider_config.dart';
import 'query_parse_result.dart';
import 'query_understanding_spec.dart';

/// Validates, sanitizes, and normalizes structured output from LLM providers
/// into canonical SearchQuery objects without making any database calls.
class QueryOutputValidator {
  QueryOutputValidator._();

  /// Extracts JSON and validates structured query output.
  static QueryParseResult validateAndParse({
    required String rawContent,
    LlmProvider? provider,
    String? model,
    int? latencyMs,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    Map<String, dynamic>? metadata,
  }) {
    final cleanContent = rawContent.trim();
    if (cleanContent.isEmpty) {
      return QueryParseResult.failure(
        error: 'Empty response received from LLM provider',
        provider: provider,
        model: model,
        latencyMs: latencyMs,
        rawResponse: rawContent,
        metadata: metadata,
      );
    }

    Map<String, dynamic> jsonMap;
    try {
      jsonMap = _extractJsonMap(cleanContent);
    } catch (e) {
      return QueryParseResult.failure(
        error: 'Failed to extract valid JSON from LLM response: $e',
        provider: provider,
        model: model,
        latencyMs: latencyMs,
        rawResponse: rawContent,
        metadata: metadata,
      );
    }

    return validateMap(
      jsonMap: jsonMap,
      provider: provider,
      model: model,
      latencyMs: latencyMs,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      rawResponse: rawContent,
      metadata: metadata,
    );
  }

  /// Validates an already parsed JSON map against SearchQuery schema constraints.
  static QueryParseResult validateMap({
    required Map<String, dynamic> jsonMap,
    LlmProvider? provider,
    String? model,
    int? latencyMs,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    String? rawResponse,
    Map<String, dynamic>? metadata,
  }) {
    // 1. Check for explicit clarification request from LLM
    final bool requiresClarification = jsonMap['requiresClarification'] == true ||
        jsonMap['requires_clarification'] == true;
    final String? clarificationQuestion =
        jsonMap['clarificationQuestion']?.toString() ?? jsonMap['clarification_question']?.toString();

    // 2. Multi-value string list extraction and item-by-item normalization
    final rawActions = _extractRawList(jsonMap['actionTypes'] ?? jsonMap['action_types'] ?? jsonMap['actionType'] ?? jsonMap['action_type']);
    final validatedActions = <String>{};
    for (final act in rawActions) {
      final normalized = normalizeActionType(act);
      if (normalized != null) validatedActions.add(normalized);
    }

    final rawCountries = _extractRawList(jsonMap['countries'] ?? jsonMap['country']);
    final validatedCountries = <String>{};
    for (final c in rawCountries) {
      final normalized = normalizeCountry(c);
      if (normalized != null) validatedCountries.add(normalized);
    }

    final rawCities = _extractRawList(jsonMap['cities'] ?? jsonMap['city']);
    final validatedCities = <String>{};
    for (final city in rawCities) {
      final s = _sanitizeString(city);
      if (s != null && s.toUpperCase() != 'ALL') validatedCities.add(s);
    }

    final rawRallies = _extractRawList(jsonMap['rallyNames'] ?? jsonMap['rally_names'] ?? jsonMap['rallyName'] ?? jsonMap['rally_name']);
    final validatedRallies = <String>{};
    for (final r in rawRallies) {
      final s = _sanitizeString(r);
      if (s != null) validatedRallies.add(s);
    }

    final rawEvents = _extractRawList(jsonMap['eventNames'] ?? jsonMap['event_names'] ?? jsonMap['eventName'] ?? jsonMap['event_name']);
    final validatedEvents = <String>{};
    for (final ev in rawEvents) {
      final s = _sanitizeString(ev);
      if (s != null) validatedEvents.add(s);
    }

    final rawStages = _extractRawList(jsonMap['stageNames'] ?? jsonMap['stage_names'] ?? jsonMap['stageName'] ?? jsonMap['stage_name']);
    final validatedStages = <String>{};
    for (final st in rawStages) {
      final s = _sanitizeString(st);
      if (s != null) validatedStages.add(s);
    }

    final rawStageNumbers = _extractRawList(jsonMap['stageNumbers'] ?? jsonMap['stage_numbers'] ?? jsonMap['stageNumber'] ?? jsonMap['stage_number']);
    final validatedStageNumbers = <String>{};
    for (final sn in rawStageNumbers) {
      final s = _sanitizeString(sn);
      if (s != null) validatedStageNumbers.add(s);
    }

    final rawDrivers = _extractRawList(jsonMap['driverNames'] ?? jsonMap['driver_names'] ?? jsonMap['driverName'] ?? jsonMap['driver_name']);
    final validatedDrivers = <String>{};
    for (final d in rawDrivers) {
      final s = _sanitizeString(d);
      if (s != null) validatedDrivers.add(s);
    }

    final rawDriverIds = _extractRawList(jsonMap['driverIds'] ?? jsonMap['driver_ids'] ?? jsonMap['driverId'] ?? jsonMap['driver_id']);
    final validatedDriverIds = <String>{};
    for (final id in rawDriverIds) {
      final s = _sanitizeString(id);
      if (s != null) validatedDriverIds.add(s);
    }

    // 3. Year and Year-range validation
    final rawYears = _extractRawList(jsonMap['years'] ?? jsonMap['year']);
    final validatedYears = <int>{};
    for (final yr in rawYears) {
      final val = _validateYear(yr);
      if (val != null) validatedYears.add(val);
    }

    final int? validatedYearFrom = _validateYear(jsonMap['yearFrom'] ?? jsonMap['year_from']);
    final int? validatedYearTo = _validateYear(jsonMap['yearTo'] ?? jsonMap['year_to']);

    // 4. Match Mode & Person Role
    final matchMode = MatchMode.fromString(jsonMap['driverMatchMode']?.toString() ?? jsonMap['driver_match_mode']?.toString());
    final personRole = PersonRole.fromString(jsonMap['personRole']?.toString() ?? jsonMap['person_role']?.toString() ?? jsonMap['role']?.toString());

    // 5. Limit and Offset validation
    final rawLimit = jsonMap['limit'];
    final int validatedLimit = _validateLimit(rawLimit);

    final rawOffset = jsonMap['offset'];
    final int validatedOffset = _validateOffset(rawOffset);

    // Guard against unnecessary clarification when explicit filters exist
    final hasSpecificFilters = validatedActions.isNotEmpty ||
        validatedDrivers.isNotEmpty ||
        validatedDriverIds.isNotEmpty ||
        validatedRallies.isNotEmpty ||
        validatedEvents.isNotEmpty ||
        validatedCountries.isNotEmpty ||
        validatedCities.isNotEmpty ||
        validatedStages.isNotEmpty ||
        validatedStageNumbers.isNotEmpty ||
        validatedYears.isNotEmpty ||
        validatedYearFrom != null ||
        validatedYearTo != null;

    if (requiresClarification && clarificationQuestion != null && clarificationQuestion.trim().isNotEmpty && !hasSpecificFilters) {
      return QueryParseResult.clarification(
        clarificationQuestion: clarificationQuestion.trim(),
        provider: provider,
        model: model,
        latencyMs: latencyMs,
        rawResponse: rawResponse,
        metadata: metadata,
      );
    }

    // 6. Intent validation and normalization
    final rawIntent = jsonMap['intent']?.toString();
    if (rawIntent == null || rawIntent.trim().isEmpty) {
      return QueryParseResult.failure(
        error: 'Missing required field "intent" in structured output',
        provider: provider,
        model: model,
        latencyMs: latencyMs,
        rawResponse: rawResponse,
        metadata: metadata,
      );
    }

    final SearchIntent parsedIntent = _parseAndValidateIntent(rawIntent);

    // Build canonical SearchQuery
    final searchQuery = SearchQuery(
      intent: parsedIntent,
      rallyNames: validatedRallies.toList(),
      eventNames: validatedEvents.toList(),
      countries: validatedCountries.toList(),
      cities: validatedCities.toList(),
      stageNames: validatedStages.toList(),
      stageNumbers: validatedStageNumbers.toList(),
      driverNames: validatedDrivers.toList(),
      driverIds: validatedDriverIds.toList(),
      actionTypes: validatedActions.toList(),
      years: validatedYears.toList(),
      yearFrom: validatedYearFrom,
      yearTo: validatedYearTo,
      driverMatchMode: matchMode,
      personRole: personRole,
      limit: validatedLimit,
      offset: validatedOffset,
    );

    // Deterministically generate interpreted summary from structured query
    final summary = generateInterpretedSummary(searchQuery);

    return QueryParseResult(
      query: searchQuery,
      requiresClarification: false,
      interpretedSummary: summary,
      provider: provider,
      model: model,
      latencyMs: latencyMs,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      rawResponse: rawResponse,
      metadata: metadata ?? {},
    );
  }

  /// Extracts dynamic list of items from list or single value
  static List<dynamic> _extractRawList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw;
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty || s.toLowerCase() == 'null' || s.toLowerCase() == 'none') return [];
      return [s];
    }
    return [raw];
  }

  /// Extracts JSON from raw text, supporting markdown code fence wrapping (```json ... ```)
  static Map<String, dynamic> _extractJsonMap(String text) {
    String cleaned = text.trim();

    // Check for markdown code fences
    if (cleaned.contains('```')) {
      final jsonBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
      final match = jsonBlockRegex.firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        cleaned = match.group(1)!.trim();
      }
    }

    // Attempt direct decode
    final dynamic decoded = jsonDecode(cleaned);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    } else if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Decoded JSON is not a JSON object map');
  }

  /// Validates SearchIntent or resolves to safe fallback
  static SearchIntent _parseAndValidateIntent(String raw) {
    try {
      return SearchIntent.fromString(raw);
    } catch (_) {
      return SearchIntent.searchRallies;
    }
  }

  /// Validates and normalizes action type
  static String? normalizeActionType(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'all' || trimmed == 'none') {
      return null;
    }

    // Strip trailing '_segments' if present
    final clean = trimmed.endsWith('_segments')
        ? trimmed.substring(0, trimmed.length - '_segments'.length)
        : trimmed;

    // Check against canonical supported action types
    for (final supported in QueryUnderstandingSpec.supportedActionTypes) {
      if (clean == supported || clean == supported.replaceAll(' ', '_')) {
        return supported;
      }
    }

    // Exact alias matching
    const Map<String, String> aliasMap = {
      'jumps': 'jump',
      'jumping': 'jump',
      'air': 'jump',
      'airborne': 'jump',
      'big air': 'jump',
      'jumsp': 'jump',
      'drifts': 'drift',
      'drifting': 'drift',
      'slide': 'drift',
      'slides': 'drift',
      'sliding': 'drift',
      'crashes': 'crash',
      'crashed': 'crash',
      'crashing': 'crash',
      'accident': 'crash',
      'accidents': 'crash',
      'roll': 'crash',
      'rolled': 'crash',
      'rollover': 'crash',
      'spins': 'spin',
      'spinning': 'spin',
      'donut': 'donut',
      'donuts': 'donut',
      'doughnut': 'donut',
      'doughnuts': 'donut',
      'hairpin': 'hairpin',
      'hairpins': 'hairpin',
      'handbrake turn': 'hairpin',
      'handbrake turns': 'hairpin',
      'handbrake': 'hairpin',
      'water splash': 'water splash',
      'water splashes': 'water splash',
      'water crossing': 'water splash',
      'water crossings': 'water splash',
      'splash': 'water splash',
      'splashes': 'water splash',
      'watr splash': 'water splash',
      'watr splashes': 'water splash',
      'watr crossing': 'water splash',
      'launch': 'start line',
      'start': 'start line',
      'starts': 'start line',
      'start_line': 'start line',
      'near_miss': 'near miss',
      'near misses': 'near miss',
      'close call': 'near miss',
      'save': 'near miss',
      'saves': 'near miss',
      'mechanical': 'mechanical failure',
      'mechanical_failure': 'mechanical failure',
      'mech': 'mechanical failure',
      'puncture': 'mechanical failure',
      'punctures': 'mechanical failure',
      'breakdown': 'mechanical failure',
      'broken': 'mechanical failure',
      'off_road': 'offroad',
      'off road': 'offroad',
      'ditch': 'offroad',
      'ditched': 'offroad',
      'bogged': 'stuck',
    };

    if (aliasMap.containsKey(clean)) {
      return aliasMap[clean];
    }

    return null;
  }

  /// Validates that year is a reasonable 4-digit calendar year (1950 - 2050)
  static int? _validateYear(dynamic raw) {
    if (raw == null) return null;
    int? yr;
    if (raw is int) {
      yr = raw;
    } else if (raw is num) {
      yr = raw.toInt();
    } else if (raw is String) {
      yr = int.tryParse(raw.trim());
    }

    if (yr != null && yr >= 1950 && yr <= 2050) {
      return yr;
    }
    return null;
  }

  /// Validates limit with sensible bounds (1 to 200)
  static int _validateLimit(dynamic raw) {
    if (raw == null) return 20;
    int? lim;
    if (raw is int) {
      lim = raw;
    } else if (raw is num) {
      lim = raw.toInt();
    } else if (raw is String) {
      lim = int.tryParse(raw.trim());
    }

    if (lim != null && lim > 0) {
      return lim.clamp(1, 200);
    }
    return 20;
  }

  /// Validates offset (>= 0)
  static int _validateOffset(dynamic raw) {
    if (raw == null) return 0;
    int? off;
    if (raw is int) {
      off = raw;
    } else if (raw is num) {
      off = raw.toInt();
    } else if (raw is String) {
      off = int.tryParse(raw.trim());
    }

    if (off != null && off >= 0) {
      return off;
    }
    return 0;
  }

  /// Sanitizes text strings
  static String? _sanitizeString(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null' || s.toLowerCase() == 'none') {
      return null;
    }
    return s;
  }

  /// Normalizes country name or code into canonical title case matching DB values
  static String? normalizeCountry(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty || clean == 'all' || clean == 'null' || clean == 'none') return null;

    const Map<String, String> countryLookup = {
      'ireland': 'Ireland',
      'irelnd': 'Ireland',
      'ie': 'Ireland',
      'irl': 'Ireland',
      'roi': 'Ireland',
      'republic of ireland': 'Ireland',
      'united kingdom': 'United Kingdom',
      'uk': 'United Kingdom',
      'gb': 'United Kingdom',
      'gbr': 'United Kingdom',
      'great britain': 'United Kingdom',
      'great britan': 'United Kingdom',
      'britain': 'United Kingdom',
      'britan': 'United Kingdom',
      'england': 'United Kingdom',
      'scotland': 'Scotland',
      'wales': 'Wales',
      'portugal': 'Portugal',
      'portugl': 'Portugal',
      'pt': 'Portugal',
      'prt': 'Portugal',
      'france': 'France',
      'fr': 'France',
      'fra': 'France',
      'austria': 'Austria',
      'austra': 'Austria',
      'at': 'Austria',
      'aut': 'Austria',
      'norway': 'Norway',
      'no': 'Norway',
      'nor': 'Norway',
      'poland': 'Poland',
      'polnd': 'Poland',
      'pl': 'Poland',
      'pol': 'Poland',
      'polish': 'Poland',
      'belgium': 'Belgium',
      'belgm': 'Belgium',
      'be': 'Belgium',
      'bel': 'Belgium',
      'spain': 'Spain',
      'spn': 'Spain',
      'espana': 'Spain',
      'españa': 'Spain',
      'es': 'Spain',
      'esp': 'Spain',
      'italy': 'Italy',
      'itly': 'Italy',
      'it': 'Italy',
      'ita': 'Italy',
      'latvia': 'Latvia',
      'latva': 'Latvia',
      'lv': 'Latvia',
      'lva': 'Latvia',
      'czech republic': 'Czech Republic',
      'czechia': 'Czech Republic',
      'cz': 'Czech Republic',
      'cze': 'Czech Republic',
      'germany': 'Germany',
      'germny': 'Germany',
      'de': 'Germany',
      'deu': 'Germany',
      'kenya': 'Kenya',
      'ke': 'Kenya',
      'ken': 'Kenya',
      'croatia': 'Croatia',
      'hr': 'Croatia',
      'hrv': 'Croatia',
      'netherlands': 'Netherlands',
      'nl': 'Netherlands',
      'nld': 'Netherlands',
      'holland': 'Netherlands',
      'new zealand': 'New Zealand',
      'nz': 'New Zealand',
      'nzl': 'New Zealand',
      'lithuania': 'Lithuania',
      'lt': 'Lithuania',
      'ltu': 'Lithuania',
      'slovakia': 'Slovakia',
      'sk': 'Slovakia',
      'svk': 'Slovakia',
      'qatar': 'Qatar',
      'qa': 'Qatar',
      'qat': 'Qatar',
      'pakistan': 'Pakistan',
      'pk': 'Pakistan',
      'pak': 'Pakistan',
      'barbados': 'Barbados',
      'bb': 'Barbados',
      'brb': 'Barbados',
      'sweden': 'Sweden',
      'swedn': 'Sweden',
      'se': 'Sweden',
      'finland': 'Finland',
      'finlnd': 'Finland',
      'fi': 'Finland',
      'estonia': 'Estonia',
      'estona': 'Estonia',
      'ee': 'Estonia',
    };

    if (countryLookup.containsKey(clean)) {
      return countryLookup[clean];
    }

    // Capitalize words if not directly in map
    return raw.split(' ').map((w) => w.isNotEmpty ? (w[0].toUpperCase() + w.substring(1).toLowerCase()) : '').join(' ');
  }

  /// Generates a clean, user-facing interpreted summary from the structured SearchQuery
  /// without making an additional LLM call.
  static String generateInterpretedSummary(SearchQuery query) {
    final parts = <String>[];

    // Intent headline
    switch (query.intent) {
      case SearchIntent.searchRallies:
        parts.add('Searching rally events');
        break;
      case SearchIntent.searchDriverRallies:
        parts.add('Searching driver participations');
        break;
      case SearchIntent.searchDriverWins:
        parts.add('Searching driver victories');
        break;
      case SearchIntent.getRallyResults:
        parts.add('Getting 1st place rally winner');
        break;
      case SearchIntent.getRallyTopFinishers:
        parts.add('Getting rally leaderboard');
        break;
      case SearchIntent.searchVideoActions:
        if (query.actionTypes.isNotEmpty) {
          parts.add('Showing ${query.actionTypes.join(', ')} highlights');
        } else {
          parts.add('Showing action highlights');
        }
        break;
      case SearchIntent.searchDriverVideos:
        parts.add('Searching driver videos');
        break;
      case SearchIntent.getTopUploaders:
        parts.add('Getting top uploaders');
        break;
      case SearchIntent.getTopDriversByWins:
        parts.add('Getting career wins leaderboard');
        break;
    }

    final filters = <String>[];
    if (query.driverNames.isNotEmpty) {
      if (query.driverMatchMode == MatchMode.all) {
        filters.add('Drivers: ${query.driverNames.join(' AND ')}');
      } else {
        filters.add('Drivers: ${query.driverNames.join(', ')}');
      }
    }
    if (query.targetRallyNames.isNotEmpty) filters.add('Rallies: ${query.targetRallyNames.join(', ')}');
    if (query.countries.isNotEmpty) filters.add('Countries: ${query.countries.join(', ')}');
    if (query.cities.isNotEmpty) filters.add('Cities: ${query.cities.join(', ')}');
    if (query.stageNames.isNotEmpty) filters.add('Stages: ${query.stageNames.join(', ')}');
    if (query.stageNumbers.isNotEmpty) filters.add('Stage Numbers: ${query.stageNumbers.join(', ')}');

    if (query.years.isNotEmpty) {
      filters.add('Years: ${query.years.join(', ')}');
    } else if (query.yearFrom != null && query.yearTo != null) {
      filters.add('Years: ${query.yearFrom}–${query.yearTo}');
    } else if (query.yearFrom != null) {
      filters.add('Years: >= ${query.yearFrom}');
    } else if (query.yearTo != null) {
      filters.add('Years: <= ${query.yearTo}');
    }

    if (filters.isEmpty) {
      return parts.join();
    }
    return '${parts.join()} | ${filters.join(' | ')}';
  }
}
