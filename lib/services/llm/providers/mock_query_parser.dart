import '../../../models/search_intent.dart';
import '../../../models/search_query.dart';
import '../llm_provider_config.dart';
import '../llm_query_parser.dart';
import '../query_output_validator.dart';
import '../query_parse_result.dart';

/// Offline deterministic query parser implementing LlmQueryParser.
/// Maps canonical patterns, compound filters, and supports failure/clarification simulation for tests.
///
/// In Phase 3.5+, extracts verbatim entity mentions (e.g. "Moonraker", "Moffett", "Get Jerky")
/// without inventing canonical database titles or driver IDs.
class MockLlmQueryParser implements LlmQueryParser {
  @override
  LlmProvider get provider => LlmProvider.mock;

  /// Optional simulated delay for testing async / cancellation flows.
  final Duration simulatedDelay;

  /// If true, parse() will throw or return a failure result.
  final bool simulateFailure;
  final String? failureMessage;

  /// If true, parse() will return a clarification-needed result.
  final bool simulateClarification;
  final String? clarificationQuestion;

  /// Custom query -> SearchQuery overrides for tests.
  final Map<String, SearchQuery> customMappings;

  MockLlmQueryParser({
    this.simulatedDelay = Duration.zero,
    this.simulateFailure = false,
    this.failureMessage,
    this.simulateClarification = false,
    this.clarificationQuestion,
    this.customMappings = const {},
  });

  @override
  Future<QueryParseResult> parse(String userQuery, {SearchContext? context}) async {
    final stopwatch = Stopwatch()..start();

    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }

    if (simulateFailure) {
      stopwatch.stop();
      return QueryParseResult.failure(
        error: failureMessage ?? 'Simulated mock parser failure',
        provider: LlmProvider.mock,
        model: 'mock-parser-v1',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }

    if (simulateClarification) {
      stopwatch.stop();
      return QueryParseResult.clarification(
        clarificationQuestion: clarificationQuestion ?? 'Please clarify your search query.',
        provider: LlmProvider.mock,
        model: 'mock-parser-v1',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }

    final normalized = userQuery.trim().toLowerCase();

    // Check custom mappings first
    if (customMappings.containsKey(normalized)) {
      final q = customMappings[normalized]!;
      stopwatch.stop();
      return QueryParseResult(
        query: q,
        requiresClarification: false,
        interpretedSummary: QueryOutputValidator.generateInterpretedSummary(q),
        provider: LlmProvider.mock,
        model: 'mock-parser-v1',
        latencyMs: stopwatch.elapsedMilliseconds,
        promptTokens: 10,
        completionTokens: 20,
        totalTokens: 30,
      );
    }

    // Check for conversational pronoun / missing referent clarification conditions
    if (normalized.contains('who won it') || normalized.contains('who won that') || normalized == 'who won?') {
      final activeRally = context?.activeRally ?? context?.referents.activeRally;
      if (activeRally == null || activeRally.isEmpty) {
        stopwatch.stop();
        return QueryParseResult.clarification(
          clarificationQuestion: 'Which rally do you want to see the winner for?',
          provider: LlmProvider.mock,
          model: 'mock-parser-v1',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    }

    if (normalized.contains('videos of him') || normalized.contains('show videos of him') || normalized.contains('clips of him') || normalized.contains('his videos')) {
      if (context != null && context.referents.lastWinner == null && context.referents.activeDrivers.length > 1) {
        stopwatch.stop();
        return QueryParseResult.clarification(
          clarificationQuestion: 'Which driver do you mean?',
          provider: LlmProvider.mock,
          model: 'mock-parser-v1',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
      final driver = context?.referents.lastWinner ?? context?.referents.activeDriver ?? context?.activeDriver;
      if (driver == null || driver.isEmpty) {
        stopwatch.stop();
        return QueryParseResult.clarification(
          clarificationQuestion: 'Which driver do you want to see videos of?',
          provider: LlmProvider.mock,
          model: 'mock-parser-v1',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    }

    // Deterministic pattern matching covering canonical queries and compound filters
    final parsedQuery = _parseRuleBased(normalized, userQuery, context);

    stopwatch.stop();
    return QueryParseResult(
      query: parsedQuery,
      requiresClarification: false,
      interpretedSummary: QueryOutputValidator.generateInterpretedSummary(parsedQuery),
      provider: LlmProvider.mock,
      model: 'mock-parser-v1',
      latencyMs: stopwatch.elapsedMilliseconds,
      promptTokens: 15,
      completionTokens: 25,
      totalTokens: 40,
    );
  }

  SearchQuery _parseRuleBased(String lower, String original, SearchContext? context) {
    // 1. Extract Year (e.g. 2026, 2025, 2024, 2023)
    int? year;
    final yearRegex = RegExp(r'\b(202[0-9]|19[89][0-9])\b');
    final yearMatch = yearRegex.firstMatch(lower);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(1)!);
    }

    // 2. Extract Driver Name (verbatim phrase extraction)
    String? driverName;
    if (lower.contains('max freeman')) {
      driverName = 'Max Freeman';
    } else if (lower.contains('josh moffett')) {
      driverName = 'Josh Moffett';
    } else if (lower.contains('philip squires')) {
      driverName = 'Philip Squires';
    } else if (lower.contains('kris meeke')) {
      driverName = 'Kris Meeke';
    } else if (lower.contains('craig breen')) {
      driverName = 'Craig Breen';
    } else if (lower.contains('moffett')) {
      driverName = 'Moffett';
    } else if (lower.contains('squires')) {
      driverName = 'Squires';
    } else if (lower.contains('smith')) {
      driverName = 'Smith';
    } else if (lower.contains('josh')) {
      driverName = 'Josh';
    }
    final driverNames = <String>[];
    if (lower.contains('josh moffett')) driverNames.add('Josh Moffett');
    if (lower.contains('sam moffett')) driverNames.add('Sam Moffett');

    // 3. Extract Country
    String? country;
    if (lower.contains('ireland') || lower.contains('irish') || lower.contains(' irl ') || lower.contains(' ie ')) {
      country = 'Ireland';
    } else if (lower.contains('united kingdom') || lower.contains(' uk ') || lower.contains(' gb ') || lower.contains('great britain') || lower.contains('britain') || lower.contains('england') || lower.contains('scotland') || lower.contains('wales')) {
      country = 'United Kingdom';
    } else if (lower.contains('portugal') || lower.contains('portuguese') || lower.contains(' pt ')) {
      country = 'Portugal';
    } else if (lower.contains('france') || lower.contains('french') || lower.contains(' fr ')) {
      country = 'France';
    } else if (lower.contains('austria') || lower.contains('austrian') || lower.contains(' at ')) {
      country = 'Austria';
    } else if (lower.contains('norway') || lower.contains('norwegian') || lower.contains(' no ')) {
      country = 'Norway';
    } else if (lower.contains('poland') || lower.contains('polish') || lower.contains(' pl ')) {
      country = 'Poland';
    } else if (lower.contains('belgium') || lower.contains('belgian') || lower.contains(' be ')) {
      country = 'Belgium';
    } else if (lower.contains('spain') || lower.contains('spanish') || lower.contains(' es ')) {
      country = 'Spain';
    } else if (lower.contains('italy') || lower.contains('italian') || lower.contains(' it ')) {
      country = 'Italy';
    } else if (lower.contains('latvia') || lower.contains('latvian') || lower.contains(' lv ')) {
      country = 'Latvia';
    } else if (lower.contains('czech') || lower.contains('czechia') || lower.contains(' cz ')) {
      country = 'Czech Republic';
    } else if (lower.contains('germany') || lower.contains('german') || lower.contains(' de ')) {
      country = 'Germany';
    } else if (lower.contains('kenya') || lower.contains('kenyan') || lower.contains(' ke ')) {
      country = 'Kenya';
    } else if (lower.contains('croatia') || lower.contains('croatian') || lower.contains(' hr ')) {
      country = 'Croatia';
    } else if (lower.contains('netherlands') || lower.contains('dutch') || lower.contains('holland') || lower.contains(' nl ')) {
      country = 'Netherlands';
    } else if (lower.contains('new zealand') || lower.contains('kiwi') || lower.contains(' nz ')) {
      country = 'New Zealand';
    } else if (lower.contains('lithuania') || lower.contains('lithuanian') || lower.contains(' lt ')) {
      country = 'Lithuania';
    } else if (lower.contains('slovakia') || lower.contains('slovak') || lower.contains(' sk ')) {
      country = 'Slovakia';
    } else if (lower.contains('qatar') || lower.contains('qatari') || lower.contains(' qa ')) {
      country = 'Qatar';
    } else if (lower.contains('pakistan') || lower.contains('pakistani') || lower.contains(' pk ')) {
      country = 'Pakistan';
    } else if (lower.contains('barbados') || lower.contains('bajan') || lower.contains(' bb ')) {
      country = 'Barbados';
    } else if (lower.contains('sweden') || lower.contains('swedish') || lower.contains(' se ')) {
      country = 'Sweden';
    } else if (lower.contains('finland') || lower.contains('finnish') || lower.contains(' fi ')) {
      country = 'Finland';
    } else if (lower.contains('estonia') || lower.contains('estonian') || lower.contains(' ee ')) {
      country = 'Estonia';
    }

    // 4. Extract Rally / Event Name (verbatim phrase extraction)
    String? rallyName;
    if (lower.contains('moonraker forestry rally')) {
      rallyName = 'Moonraker Forestry Rally';
    } else if (lower.contains('moonraker')) {
      rallyName = 'Moonraker';
    } else if (lower.contains('donegal international rally')) {
      rallyName = 'Donegal International Rally';
    } else if (lower.contains('donegal')) {
      rallyName = lower.contains('rally') ? 'Donegal Rally' : 'Donegal';
    } else if (lower.contains('trackrod rally')) {
      rallyName = 'Trackrod Rally';
    } else if (lower.contains('trackrod')) {
      rallyName = 'Trackrod';
    } else if (lower.contains('get jerky rally north wales')) {
      rallyName = 'Get Jerky Rally North Wales';
    } else if (lower.contains('get jerky')) {
      rallyName = 'Get Jerky';
    } else if (lower.contains('woodpecker')) {
      rallyName = 'Woodpecker';
    } else if (lower.contains('plains')) {
      rallyName = 'Plains';
    } else {
      final rallyRegex = RegExp(r'\brally\s+([a-z0-9\s\-]+?)(?:\s+(?:videos|highlights|results|stages|clips|jump|drift)|$)');
      final match = rallyRegex.firstMatch(lower);
      if (match != null) {
        rallyName = match.group(1)?.trim();
      }
    }

    // 5. Extract City
    String? city;
    if (lower.contains('in letterkenny') || lower.contains('letterkenny')) {
      city = 'Letterkenny';
    } else if (lower.contains('in fafe') || lower.contains('fafe')) {
      city = 'Fafe';
    } else if (lower.contains('in newtown') || lower.contains('newtown')) {
      city = 'Newtown';
    }

    // 6. Extract Stage Name
    String? stageName;
    if (lower.contains('gale rigg')) {
      stageName = 'Gale Rigg';
    } else if (lower.contains('alwen north')) {
      stageName = 'Alwen North';
    } else if (lower.contains('dyfnant')) {
      stageName = 'Dyfnant South';
    } else if (lower.contains('aberhirnant')) {
      stageName = 'Aberhirnant';
    }

    // 7. Extract Action Type
    String? actionType;
    if (lower.contains('jump') || lower.contains('air')) {
      actionType = 'jump';
    } else if (lower.contains('drift') || lower.contains('slide')) {
      actionType = 'drift';
    } else if (lower.contains('crash') || lower.contains('accident') || lower.contains('roll')) {
      actionType = 'crash';
    } else if (lower.contains('spin')) {
      actionType = 'spin';
    } else if (lower.contains('start line') || lower.contains('launch')) {
      actionType = 'start line';
    } else if (lower.contains('near miss') || lower.contains('close call')) {
      actionType = 'near miss';
    } else if (lower.contains('mechanical') || lower.contains('puncture') || lower.contains('breakdown')) {
      actionType = 'mechanical failure';
    }

    // 8. Extract Limit (e.g. "top 10", "top 5")
    int limit = 20;
    final topLimitRegex = RegExp(r'\btop\s+(\d+)\b');
    final topLimitMatch = topLimitRegex.firstMatch(lower);
    if (topLimitMatch != null) {
      limit = int.tryParse(topLimitMatch.group(1)!) ?? 20;
    }

    // 9. Determine Role & Intent
    PersonRole personRole = PersonRole.any;
    if (lower.contains('co-drove') || lower.contains('co-driven') || lower.contains('co-driver') || lower.contains('codriver') || lower.contains('co driver') || lower.contains('navigator')) {
      personRole = PersonRole.coDriver;
    } else if (lower.contains('driven by') || lower.contains('drove in') || lower.contains('drive in') || lower.contains('as driver') || lower.contains('where he drove')) {
      personRole = PersonRole.driver;
    }

    SearchIntent intent;

    if (lower.contains('uploader') || lower.contains('contributor')) {
      intent = SearchIntent.getTopUploaders;
    } else if (lower.contains('most win') || lower.contains('top driver') || lower.contains('driver leaderboard')) {
      intent = SearchIntent.getTopDriversByWins;
    } else if (lower.contains('first') || lower.contains('who won') || lower.contains('winner of')) {
      intent = SearchIntent.getRallyResults;
    } else if (lower.contains('top finisher') || lower.contains('leaderboard') || (lower.contains('top 10') && !lower.contains('uploader'))) {
      intent = SearchIntent.getRallyTopFinishers;
    } else if (actionType != null || lower.contains('highlight') || lower.contains('moment') || lower.contains('action') || lower.contains('video') || lower.contains('clip')) {
      intent = SearchIntent.searchVideoActions;
    } else if (lower.contains('video') && driverName != null) {
      intent = SearchIntent.searchDriverVideos;
    } else if ((lower.contains('win') || lower.contains('won') || lower.contains('victor')) && driverName != null) {
      intent = SearchIntent.searchDriverWins;
    } else if (driverName != null && (lower.contains('participat') || lower.contains('compet') || lower.contains('drove') || lower.contains('drive') || lower.contains('co-drove') || lower.contains('co-driver') || lower.contains('codriver') || lower.contains('entries'))) {
      intent = SearchIntent.searchDriverRallies;
    } else {
      intent = SearchIntent.searchRallies;
    }

    // Context-aware referent resolution and pronoun mapping
    if (context != null) {
      if (lower.contains('who won') || lower.contains('winner of it') || lower.contains('who won it') || lower.contains('who won that')) {
        rallyName ??= context.activeRally ?? context.referents.activeRally ?? context.previousQuery?.rallyName;
        year ??= context.previousQuery?.year;
        intent = SearchIntent.getRallyResults;
      } else if (lower.contains('videos of him') || lower.contains('show videos of him') || lower.contains('clips of him') || lower.contains('his videos')) {
        driverName ??= context.referents.lastWinner ?? context.referents.activeDriver ?? context.activeDriver;
        intent = SearchIntent.searchDriverVideos;
      }

      if (lower.contains('only show jumps') || lower.contains('only jumps') || lower.contains('just jumps')) {
        actionType = 'jump';
        rallyName ??= context.referents.activeRally ?? context.previousQuery?.rallyName;
        driverName ??= context.referents.activeDriver ?? context.referents.lastWinner ?? context.previousQuery?.driverName;
        year ??= context.previousQuery?.year;
        country ??= context.previousQuery?.country;
        intent = SearchIntent.searchVideoActions;
      } else if (lower.contains('only drifts') || lower.contains('only show drifts')) {
        actionType = 'drift';
        rallyName ??= context.referents.activeRally ?? context.previousQuery?.rallyName;
        driverName ??= context.referents.activeDriver ?? context.referents.lastWinner ?? context.previousQuery?.driverName;
        year ??= context.previousQuery?.year;
        intent = SearchIntent.searchVideoActions;
      }

      if (lower.contains('forget the driver') || lower.contains('remove driver')) {
        driverName = null;
        rallyName ??= context.referents.activeRally ?? context.previousQuery?.rallyName;
        year ??= context.previousQuery?.year;
        intent = context.previousQuery?.intent ?? intent;
      }

      if (lower.contains('what about 2024') || lower.contains('in 2024') && rallyName == null) {
        rallyName ??= context.referents.activeRally ?? context.previousQuery?.rallyName;
        driverName ??= context.referents.activeDriver ?? context.previousQuery?.driverName;
        intent = context.previousQuery?.intent ?? intent;
      }
    }

    // Handle additive action filter
    List<String> actionTypes = actionType != null ? [actionType] : [];
    if (context != null && (lower.contains('also drift') || lower.contains('add drift') || lower.contains('and drift'))) {
      actionTypes = List<String>.from(context.previousQuery?.actionTypes ?? []);
      if (!actionTypes.contains('drift')) actionTypes.add('drift');
      rallyName ??= context.referents.activeRally ?? context.previousQuery?.rallyName;
      driverName ??= context.referents.activeDriver ?? context.referents.lastWinner ?? context.previousQuery?.driverName;
      year ??= context.previousQuery?.year;
      intent = SearchIntent.searchVideoActions;
    }
    if (actionTypes.isEmpty &&
        context != null &&
        (lower.contains('forget the driver') || lower.contains('what about 2024'))) {
      actionTypes = List<String>.from(context.previousQuery?.actionTypes ?? const []);
    }

    return SearchQuery(
      intent: intent,
      rallyName: rallyName,
      eventName: rallyName,
      country: country,
      city: city,
      stageName: stageName,
      driverNames: driverNames.length > 1 ? driverNames : const [],
      driverName: driverNames.length > 1 ? null : driverName,
      actionTypes: actionTypes,
      year: year,
      personRole: personRole,
      driverMatchMode: lower.contains('both') ? MatchMode.all : MatchMode.any,
      limit: limit,
    );
  }
}
