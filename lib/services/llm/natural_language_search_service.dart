import '../../models/search_query.dart';
import '../../models/search_results.dart';
import '../search_repository.dart';
import 'llm_query_parser.dart';
import 'query_parse_result.dart';

/// Encapsulates the complete result of a natural-language search operation,
/// including LLM query parse metadata, interpreted summary, deterministic DB results,
/// and full latency/cost telemetry.
class NaturalLanguageSearchResult {
  /// The outcome of the LLM parsing phase.
  final QueryParseResult parseResult;

  /// The parsed SearchQuery executed against the database (if parsing succeeded).
  final SearchQuery? query;

  /// The typed search response returned by SearchRepository (if query was executed).
  final SearchResponse<dynamic>? searchResponse;

  /// True if the user needs to provide more information before the query can run.
  final bool requiresClarification;

  /// Clarification question from LLM if requiresClarification is true.
  final String? clarificationQuestion;

  /// Any error message encountered during parsing or DB execution.
  final String? error;

  /// Deterministic human-readable explanation of what was understood.
  final String? interpretedSummary;

  /// Time taken to execute the database query in milliseconds.
  final int dbLatencyMs;

  /// Total end-to-end latency in milliseconds (Parse + DB).
  final int totalLatencyMs;

  const NaturalLanguageSearchResult({
    required this.parseResult,
    this.query,
    this.searchResponse,
    this.requiresClarification = false,
    this.clarificationQuestion,
    this.error,
    this.interpretedSummary,
    this.dbLatencyMs = 0,
    this.totalLatencyMs = 0,
  });

  /// Success indicator: Both LLM parsing and SearchRepository execution succeeded.
  bool get isSuccess => searchResponse != null && error == null && !requiresClarification;

  /// Total count of results returned by the deterministic database layer.
  int get totalCount => searchResponse?.totalCount ?? 0;

  /// The list of items returned.
  List<dynamic> get results => searchResponse?.results ?? [];

  /// LLM Parsing latency in milliseconds.
  int get parseLatencyMs => parseResult.latencyMs ?? 0;

  /// Estimated USD cost formatted string.
  String get formattedCost => parseResult.formattedCost;

  /// Factory for clarification response.
  factory NaturalLanguageSearchResult.clarification({
    required QueryParseResult parseResult,
    required String clarificationQuestion,
    int totalLatencyMs = 0,
  }) {
    return NaturalLanguageSearchResult(
      parseResult: parseResult,
      requiresClarification: true,
      clarificationQuestion: clarificationQuestion,
      totalLatencyMs: totalLatencyMs,
    );
  }

  /// Factory for failure response.
  factory NaturalLanguageSearchResult.failure({
    required QueryParseResult parseResult,
    required String error,
    int totalLatencyMs = 0,
  }) {
    return NaturalLanguageSearchResult(
      parseResult: parseResult,
      error: error,
      interpretedSummary: parseResult.interpretedSummary,
      totalLatencyMs: totalLatencyMs,
    );
  }
}

/// Orchestrates Natural Language Search:
/// 1. Takes user natural-language string.
/// 2. Passes it through an LlmQueryParser to produce a canonical SearchQuery.
/// 3. Validates against clarification or parsing errors.
/// 4. Executes deterministic search via existing ISearchRepository.
/// 5. Captures granular latency (parse & DB) and estimated token costs.
class NaturalLanguageSearchService {
  final LlmQueryParser parser;
  final ISearchRepository repository;

  NaturalLanguageSearchService({
    required this.parser,
    ISearchRepository? repository,
  }) : repository = repository ?? SearchRepository();

  /// Executes natural language search end-to-end.
  Future<NaturalLanguageSearchResult> search(
    String naturalQuery, {
    SearchContext? context,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    final clean = naturalQuery.trim();
    if (clean.isEmpty) {
      final failureResult = QueryParseResult.failure(error: 'Search query cannot be empty');
      overallStopwatch.stop();
      return NaturalLanguageSearchResult.failure(
        parseResult: failureResult,
        error: 'Search query cannot be empty',
        totalLatencyMs: overallStopwatch.elapsedMilliseconds,
      );
    }

    try {
      // Step 1: Parse natural language into structured SearchQuery
      final parseResult = await parser.parse(clean, context: context);

      // Step 2: Handle clarification
      if (parseResult.requiresClarification) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.clarification(
          parseResult: parseResult,
          clarificationQuestion: parseResult.clarificationQuestion ?? 'Please provide more details.',
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      // Step 3: Handle parsing error
      if (!parseResult.isSuccess || parseResult.query == null) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.failure(
          parseResult: parseResult,
          error: parseResult.error ?? 'Unable to understand search query',
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      final query = parseResult.query!;

      // Step 4: Execute deterministic search against existing SearchRepository
      final dbStopwatch = Stopwatch()..start();
      final searchResponse = await repository.search(query);
      dbStopwatch.stop();
      overallStopwatch.stop();

      return NaturalLanguageSearchResult(
        parseResult: parseResult,
        query: query,
        searchResponse: searchResponse,
        interpretedSummary: parseResult.interpretedSummary,
        dbLatencyMs: dbStopwatch.elapsedMilliseconds,
        totalLatencyMs: overallStopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      overallStopwatch.stop();
      final failureResult = QueryParseResult.failure(error: 'Natural language search failed: $e');
      return NaturalLanguageSearchResult.failure(
        parseResult: failureResult,
        error: 'Search failed: $e',
        totalLatencyMs: overallStopwatch.elapsedMilliseconds,
      );
    }
  }
}
