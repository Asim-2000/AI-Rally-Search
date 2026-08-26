import '../../models/entity_candidate.dart';
import '../../models/search_query.dart';
import '../../models/search_results.dart';
import '../search_repository.dart';
import 'entity_resolution/entity_resolver.dart';
import 'llm_query_parser.dart';
import 'query_output_validator.dart';
import 'query_parse_result.dart';

/// Encapsulates the complete result of a natural-language search operation,
/// including LLM query parse metadata, entity resolution results, interpreted summary,
/// deterministic DB search response, and granular latency/cost telemetry.
class NaturalLanguageSearchResult {
  /// The outcome of the LLM parsing phase.
  final QueryParseResult parseResult;

  /// The raw parsed query directly extracted by the LLM (before entity resolution).
  final SearchQuery? parsedQuery;

  /// The canonical resolved query produced by the EntityResolver.
  final SearchQuery? resolvedQuery;

  /// The executable query (resolvedQuery if available, otherwise parsedQuery).
  SearchQuery? get query => resolvedQuery ?? parsedQuery;

  /// The typed search response returned by SearchRepository (if query was executed).
  final SearchResponse<dynamic>? searchResponse;

  /// True if the user needs to provide more information or select a candidate.
  final bool requiresClarification;

  /// Clarification question to display to the user.
  final String? clarificationQuestion;

  /// Candidate entity options if clarification / disambiguation is required.
  final List<EntityCandidate> candidates;

  /// Detailed per-entity resolution metadata.
  final Map<String, EntityResolution> resolutions;

  /// Any error message encountered during parsing, resolution, or DB execution.
  final String? error;

  /// Deterministic human-readable explanation of what was understood.
  final String? interpretedSummary;

  /// Time taken by EntityResolver in milliseconds.
  final int entityResolutionLatencyMs;

  /// Time taken to execute the database query in milliseconds.
  final int dbLatencyMs;

  /// Total end-to-end latency in milliseconds (Parse + Entity Resolution + DB).
  final int totalLatencyMs;

  const NaturalLanguageSearchResult({
    required this.parseResult,
    this.parsedQuery,
    this.resolvedQuery,
    this.searchResponse,
    this.requiresClarification = false,
    this.clarificationQuestion,
    this.candidates = const [],
    this.resolutions = const {},
    this.error,
    this.interpretedSummary,
    this.entityResolutionLatencyMs = 0,
    this.dbLatencyMs = 0,
    this.totalLatencyMs = 0,
  });

  /// Success indicator: LLM parsing, entity resolution, and SearchRepository execution all succeeded.
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
    SearchQuery? parsedQuery,
    required String clarificationQuestion,
    List<EntityCandidate> candidates = const [],
    Map<String, EntityResolution> resolutions = const {},
    int entityResolutionLatencyMs = 0,
    int totalLatencyMs = 0,
  }) {
    return NaturalLanguageSearchResult(
      parseResult: parseResult,
      parsedQuery: parsedQuery,
      requiresClarification: true,
      clarificationQuestion: clarificationQuestion,
      candidates: candidates,
      resolutions: resolutions,
      entityResolutionLatencyMs: entityResolutionLatencyMs,
      totalLatencyMs: totalLatencyMs,
    );
  }

  /// Factory for failure response.
  factory NaturalLanguageSearchResult.failure({
    required QueryParseResult parseResult,
    SearchQuery? parsedQuery,
    required String error,
    int entityResolutionLatencyMs = 0,
    int totalLatencyMs = 0,
  }) {
    return NaturalLanguageSearchResult(
      parseResult: parseResult,
      parsedQuery: parsedQuery,
      error: error,
      interpretedSummary: parseResult.interpretedSummary,
      entityResolutionLatencyMs: entityResolutionLatencyMs,
      totalLatencyMs: totalLatencyMs,
    );
  }
}

/// Orchestrates Natural Language Search:
/// 1. Takes user natural-language string.
/// 2. Passes it through an [LlmQueryParser] to produce an extracted [SearchQuery].
/// 3. Validates against clarification or parsing errors.
/// 4. Resolves entity phrases deterministically via injected [EntityResolver].
/// 5. If ambiguous or clarification required, returns candidates to UI.
/// 6. Executes deterministic search via existing [ISearchRepository].
/// 7. Captures granular latency (parse, entity resolution, DB) and cost telemetry.
class NaturalLanguageSearchService {
  final LlmQueryParser parser;
  final EntityResolver entityResolver;
  final ISearchRepository repository;

  NaturalLanguageSearchService({
    required this.parser,
    required this.entityResolver,
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
      // Step 1: Parse natural language into structured SearchQuery (entity extraction)
      final parseResult = await parser.parse(clean, context: context);

      // Step 2: Handle parser-level clarification
      if (parseResult.requiresClarification) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.clarification(
          parseResult: parseResult,
          clarificationQuestion: parseResult.clarificationQuestion ?? 'Please provide more details.',
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      // Step 3: Handle parser-level error
      if (!parseResult.isSuccess || parseResult.query == null) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.failure(
          parseResult: parseResult,
          error: parseResult.error ?? 'Unable to understand search query',
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      final parsedQuery = parseResult.query!;

      // Step 4: Deterministic Entity Resolution
      final erStopwatch = Stopwatch()..start();
      final resolutionResult = await entityResolver.resolve(parsedQuery, context: context);
      erStopwatch.stop();

      if (resolutionResult.requiresClarification) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.clarification(
          parseResult: parseResult,
          parsedQuery: parsedQuery,
          clarificationQuestion: resolutionResult.clarificationQuestion ?? 'Please clarify the entity.',
          candidates: resolutionResult.candidates,
          resolutions: resolutionResult.resolutions,
          entityResolutionLatencyMs: erStopwatch.elapsedMilliseconds,
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      if (resolutionResult.error != null) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.failure(
          parseResult: parseResult,
          parsedQuery: parsedQuery,
          error: resolutionResult.error!,
          entityResolutionLatencyMs: erStopwatch.elapsedMilliseconds,
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      final resolvedQuery = resolutionResult.resolvedQuery ?? parsedQuery;

      // Step 5: Execute deterministic search against existing SearchRepository
      final dbStopwatch = Stopwatch()..start();
      final searchResponse = await repository.search(resolvedQuery);
      dbStopwatch.stop();
      overallStopwatch.stop();

      // Deterministically generate summary from the resolved query
      final summary = QueryOutputValidator.generateInterpretedSummary(resolvedQuery);

      return NaturalLanguageSearchResult(
        parseResult: parseResult,
        parsedQuery: parsedQuery,
        resolvedQuery: resolvedQuery,
        searchResponse: searchResponse,
        resolutions: resolutionResult.resolutions,
        interpretedSummary: summary,
        entityResolutionLatencyMs: erStopwatch.elapsedMilliseconds,
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
