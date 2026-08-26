import 'dart:convert';
import '../../models/search_intent.dart';
import '../../models/search_query.dart';
import 'eval/llm_cost_calculator.dart';
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

    if (requiresClarification && clarificationQuestion != null && clarificationQuestion.trim().isNotEmpty) {
      return QueryParseResult.clarification(
        clarificationQuestion: clarificationQuestion.trim(),
        provider: provider,
        model: model,
        latencyMs: latencyMs,
        rawResponse: rawResponse,
        metadata: metadata,
      );
    }

    // 2. Intent validation and normalization
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

    // 3. Action type validation (must be in canonical list or null)
    final rawAction = jsonMap['actionType']?.toString() ?? jsonMap['action_type']?.toString();
    final String? validatedAction = _validateActionType(rawAction);

    // 4. Year validation (must be a realistic rally motorsport year, e.g. 1950 - 2050)
    final rawYear = jsonMap['year'];
    final int? validatedYear = _validateYear(rawYear);

    // 5. Limit and Offset validation
    final rawLimit = jsonMap['limit'];
    final int validatedLimit = _validateLimit(rawLimit);

    final rawOffset = jsonMap['offset'];
    final int validatedOffset = _validateOffset(rawOffset);

    // 6. Text string sanitization (empty strings converted to null)
    final rallyName = _sanitizeString(jsonMap['rallyName'] ?? jsonMap['rally_name']);
    final eventName = _sanitizeString(jsonMap['eventName'] ?? jsonMap['event_name']);
    final rawCountry = _sanitizeString(jsonMap['country']);
    final country = _normalizeCountry(rawCountry);
    final city = _sanitizeString(jsonMap['city']);
    final stageName = _sanitizeString(jsonMap['stageName'] ?? jsonMap['stage_name']);
    final stageNumber = _sanitizeString(jsonMap['stageNumber'] ?? jsonMap['stage_number']);
    final driverName = _sanitizeString(jsonMap['driverName'] ?? jsonMap['driver_name']);

    // Build canonical SearchQuery
    final searchQuery = SearchQuery(
      intent: parsedIntent,
      rallyName: rallyName,
      eventName: eventName,
      country: country,
      city: city,
      stageName: stageName,
      stageNumber: stageNumber,
      driverName: driverName,
      actionType: validatedAction,
      year: validatedYear,
      limit: validatedLimit,
      offset: validatedOffset,
    );

    // Deterministically generate interpreted summary from structured query
    final summary = generateInterpretedSummary(searchQuery);

    // Compute estimated USD cost
    double? costUsd;
    if (promptTokens != null && completionTokens != null) {
      costUsd = LlmCostCalculator.calculateCost(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        model: model,
        provider: provider,
      );
    }

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
      estimatedCostUsd: costUsd,
      rawResponse: rawResponse,
      metadata: metadata ?? {},
    );
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
  static String? _validateActionType(String? raw) {
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
      'donut': 'spin',
      'donuts': 'spin',
      'doughnut': 'spin',
      'doughnuts': 'spin',
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

    // Unknown or invalid action type -> reject safely to null
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
  static String? _normalizeCountry(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty || clean == 'all' || clean == 'null' || clean == 'none') return null;

    const Map<String, String> countryLookup = {
      'ireland': 'Ireland',
      'ie': 'Ireland',
      'irl': 'Ireland',
      'republic of ireland': 'Ireland',
      'united kingdom': 'United Kingdom',
      'uk': 'United Kingdom',
      'gb': 'United Kingdom',
      'gbr': 'United Kingdom',
      'great britain': 'United Kingdom',
      'england': 'United Kingdom',
      'scotland': 'United Kingdom',
      'wales': 'United Kingdom',
      'portugal': 'Portugal',
      'pt': 'Portugal',
      'prt': 'Portugal',
      'france': 'France',
      'fr': 'France',
      'fra': 'France',
      'austria': 'Austria',
      'at': 'Austria',
      'aut': 'Austria',
      'norway': 'Norway',
      'no': 'Norway',
      'nor': 'Norway',
      'poland': 'Poland',
      'pl': 'Poland',
      'pol': 'Poland',
      'polish': 'Poland',
      'belgium': 'Belgium',
      'be': 'Belgium',
      'bel': 'Belgium',
      'spain': 'Spain',
      'es': 'Spain',
      'esp': 'Spain',
      'italy': 'Italy',
      'it': 'Italy',
      'ita': 'Italy',
      'latvia': 'Latvia',
      'lv': 'Latvia',
      'lva': 'Latvia',
      'czech republic': 'Czech Republic',
      'czechia': 'Czech Republic',
      'cz': 'Czech Republic',
      'cze': 'Czech Republic',
      'germany': 'Germany',
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
      'se': 'Sweden',
      'finland': 'Finland',
      'fi': 'Finland',
      'estonia': 'Estonia',
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
        if (query.actionType != null) {
          parts.add('Showing ${query.actionType} highlights');
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
    if (query.driverName != null) filters.add('Driver: ${query.driverName}');
    if (query.targetRallyName != null) filters.add('Rally: ${query.targetRallyName}');
    if (query.country != null) filters.add('Country: ${query.country}');
    if (query.city != null) filters.add('City: ${query.city}');
    if (query.stageName != null) filters.add('Stage: ${query.stageName}');
    if (query.year != null) filters.add('Year: ${query.year}');

    if (filters.isEmpty) {
      return parts.join();
    }
    return '${parts.join()} | ${filters.join(' | ')}';
  }
}
