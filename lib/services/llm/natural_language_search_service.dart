import '../../models/search_query.dart';
import '../../models/search_results.dart';
import '../search_repository.dart';
import 'llm_query_parser.dart';
import 'query_parse_result.dart';

/// Encapsulates the complete result of a natural-language search operation,
/// including LLM query parse metadata, interpreted summary, and deterministic DB results.
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

  const NaturalLanguageSearchResult({
    required this.parseResult,
    this.query,
    this.searchResponse,
    this.requiresClarification = false,
    this.clarificationQuestion,
    this.error,
    this.interpretedSummary,
  });

  /// Success indicator: Both LLM parsing and SearchRepository execution succeeded.
  bool get isSuccess => searchResponse != null && error == null && !requiresClarification;

  /// Total count of results returned by the deterministic database layer.
  int get totalCount => searchResponse?.totalCount ?? 0;

  /// The list of items returned.
  List<dynamic> get results => searchResponse?.results ?? [];

  /// Factory for clarification response.
  factory NaturalLanguageSearchResult.clarification({
    required QueryParseResult parseResult,
    required String clarificationQuestion,
  }) {
    return NaturalLanguageSearchResult(
      parseResult: parseResult,
      requiresClarification: true,
      clarificationQuestion: clarificationQuestion,
    );
  }

  /// Factory for failure response.
  factory NaturalLanguageSearchResult.failure({
    required QueryParseResult parseResult,
    required String error,
  }) {
    return NaturalLanguageSearchResult(
      parseResult: parseResult,
      error: error,
      interpretedSummary: parseResult.interpretedSummary,
    );
  }
}

/// Orchestrates Natural Language Search:
/// 1. Takes user natural-language string.
/// 2. Passes it through an LlmQueryParser to produce a canonical SearchQuery.
/// 3. Validates against clarification or parsing errors.
/// 4. Executes deterministic search via existing ISearchRepository.
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
    final clean = naturalQuery.trim();
    if (clean.isEmpty) {
      final failureResult = QueryParseResult.failure(error: 'Search query cannot be empty');
      return NaturalLanguageSearchResult.failure(
        parseResult: failureResult,
        error: 'Search query cannot be empty',
      );
    }

    try {
      // Step 1: Parse natural language into structured SearchQuery
      final parseResult = await parser.parse(clean, context: context);

      // Step 2: Handle clarification
      if (parseResult.requiresClarification) {
        return NaturalLanguageSearchResult.clarification(
          parseResult: parseResult,
          clarificationQuestion: parseResult.clarificationQuestion ?? 'Please provide more details.',
        );
      }

      // Step 3: Handle parsing error
      if (!parseResult.isSuccess || parseResult.query == null) {
        return NaturalLanguageSearchResult.failure(
          parseResult: parseResult,
          error: parseResult.error ?? 'Unable to understand search query',
        );
      }

      final query = parseResult.query!;

      // Step 4: Execute deterministic search against existing SearchRepository
      final searchResponse = await repository.search(query);

      return NaturalLanguageSearchResult(
        parseResult: parseResult,
        query: query,
        searchResponse: searchResponse,
        interpretedSummary: parseResult.interpretedSummary,
      );
    } catch (e) {
      final failureResult = QueryParseResult.failure(error: 'Natural language search failed: $e');
      return NaturalLanguageSearchResult.failure(
        parseResult: failureResult,
        error: 'Search failed: $e',
      );
    }
  }
}
