import '../../models/entity_candidate.dart';
import '../../models/result_referent_context.dart';
import '../../models/search_query.dart';
import '../../models/search_results.dart';
import '../../models/speech/speech_transcription_result.dart';
import '../search_repository.dart';
import '../speech/voice_entity_recovery_service.dart';
import 'entity_resolution/entity_resolver.dart';
import 'entity_resolution/spoken_entity_resolver.dart';
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

  /// Voice entity recovery details (if voice search or normalization applied).
  final VoiceEntityRecoveryResult? voiceRecovery;

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

  /// Derived result referents established by this search execution.
  final ResultReferentContext referents;

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
    this.voiceRecovery,
    this.searchResponse,
    this.requiresClarification = false,
    this.clarificationQuestion,
    this.candidates = const [],
    this.resolutions = const {},
    this.error,
    this.interpretedSummary,
    this.referents = ResultReferentContext.empty,
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
    VoiceEntityRecoveryResult? voiceRecovery,
    required String clarificationQuestion,
    List<EntityCandidate> candidates = const [],
    Map<String, EntityResolution> resolutions = const {},
    ResultReferentContext referents = ResultReferentContext.empty,
    int entityResolutionLatencyMs = 0,
    int totalLatencyMs = 0,
  }) {
    return NaturalLanguageSearchResult(
      parseResult: parseResult,
      parsedQuery: parsedQuery,
      voiceRecovery: voiceRecovery,
      requiresClarification: true,
      clarificationQuestion: clarificationQuestion,
      candidates: candidates,
      resolutions: resolutions,
      referents: referents,
      entityResolutionLatencyMs: entityResolutionLatencyMs,
      totalLatencyMs: totalLatencyMs,
    );
  }

  /// Factory for failure response.
  factory NaturalLanguageSearchResult.failure({
    required QueryParseResult parseResult,
    SearchQuery? parsedQuery,
    VoiceEntityRecoveryResult? voiceRecovery,
    required String error,
    ResultReferentContext referents = ResultReferentContext.empty,
    int entityResolutionLatencyMs = 0,
    int totalLatencyMs = 0,
  }) {
    return NaturalLanguageSearchResult(
      parseResult: parseResult,
      parsedQuery: parsedQuery,
      voiceRecovery: voiceRecovery,
      error: error,
      interpretedSummary: parseResult.interpretedSummary,
      referents: referents,
      entityResolutionLatencyMs: entityResolutionLatencyMs,
      totalLatencyMs: totalLatencyMs,
    );
  }
}

/// Orchestrates Natural Language Search:
/// 1. Takes user natural-language string or rich spoken transcription result.
/// 2. Performs Voice Entity Recovery / Normalization if applicable.
/// 3. Passes it through an [LlmQueryParser] to produce an extracted [SearchQuery].
/// 4. Validates against clarification or parsing errors.
/// 5. Resolves entity phrases deterministically via injected [EntityResolver] / [SpokenEntityResolver].
/// 6. If ambiguous or clarification required, returns candidates to UI.
/// 7. Executes deterministic search via existing [ISearchRepository].
/// 8. Captures granular latency (parse, entity resolution, DB) and cost telemetry.
/// 9. Deterministically disposes audio context when search completes.
class NaturalLanguageSearchService {
  final LlmQueryParser parser;
  final EntityResolver entityResolver;
  final ISearchRepository repository;
  final VoiceEntityRecoveryService voiceRecoveryService;

  NaturalLanguageSearchService({
    required this.parser,
    required this.entityResolver,
    ISearchRepository? repository,
    VoiceEntityRecoveryService? voiceRecoveryService,
  })  : repository = repository ?? SearchRepository(),
        voiceRecoveryService = voiceRecoveryService ?? const VoiceEntityRecoveryService();

  /// Executes natural language search from a rich [SpeechTranscriptionResult] end-to-end,
  /// guaranteeing deterministic disposal of retained audio context in a finally block.
  Future<NaturalLanguageSearchResult> searchSpoken(
    SpeechTranscriptionResult speechResult, {
    SearchContext? context,
  }) async {
    try {
      return await search(
        speechResult.text,
        context: context,
        speechResult: speechResult,
      );
    } finally {
      speechResult.disposeAudio();
    }
  }

  /// Executes natural language search end-to-end.
  Future<NaturalLanguageSearchResult> search(
    String naturalQuery, {
    SearchContext? context,
    SpeechTranscriptionResult? speechResult,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    final clean = naturalQuery.trim();
    if (clean.isEmpty) {
      final failureResult = QueryParseResult.failure(error: 'Search query cannot be empty');
      overallStopwatch.stop();
      return NaturalLanguageSearchResult.failure(
        parseResult: failureResult,
        error: 'Search query cannot be empty',
        referents: context?.referents ?? ResultReferentContext.empty,
        totalLatencyMs: overallStopwatch.elapsedMilliseconds,
      );
    }

    try {
      // Step 0: Voice Entity Recovery / Text Normalization
      final recovery = voiceRecoveryService.recover(
        clean,
        languageCode: context?.languageCode ?? context?.locale,
      );
      final queryToParse = recovery.normalizedTranscript;

      // Step 1: Parse natural language into structured SearchQuery (entity extraction)
      final parseResult = await parser.parse(queryToParse, context: context);

      // Step 2: Handle parser-level clarification
      if (parseResult.requiresClarification) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.clarification(
          parseResult: parseResult,
          voiceRecovery: recovery,
          clarificationQuestion: parseResult.clarificationQuestion ?? 'Please provide more details.',
          referents: context?.referents ?? ResultReferentContext.empty,
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      // Step 3: Handle parser-level error
      if (!parseResult.isSuccess || parseResult.query == null) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.failure(
          parseResult: parseResult,
          voiceRecovery: recovery,
          error: parseResult.error ?? 'Unable to understand search query',
          referents: context?.referents ?? ResultReferentContext.empty,
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      final parsedQuery = parseResult.query!;

      // Step 4: Deterministic Entity Resolution
      final erStopwatch = Stopwatch()..start();
      final EntityResolutionResult resolutionResult;
      if (speechResult != null && entityResolver is SpokenEntityResolver) {
        resolutionResult = await (entityResolver as SpokenEntityResolver).resolveSpoken(
          parsedQuery: parsedQuery,
          speechResult: speechResult,
          context: context,
        );
      } else {
        resolutionResult = await entityResolver.resolve(parsedQuery, context: context);
      }
      erStopwatch.stop();

      if (resolutionResult.requiresClarification) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.clarification(
          parseResult: parseResult,
          parsedQuery: parsedQuery,
          voiceRecovery: recovery,
          clarificationQuestion: resolutionResult.clarificationQuestion ?? 'Please clarify the entity.',
          candidates: resolutionResult.candidates,
          resolutions: resolutionResult.resolutions,
          referents: context?.referents ?? ResultReferentContext.empty,
          entityResolutionLatencyMs: erStopwatch.elapsedMilliseconds,
          totalLatencyMs: overallStopwatch.elapsedMilliseconds,
        );
      }

      if (resolutionResult.error != null) {
        overallStopwatch.stop();
        return NaturalLanguageSearchResult.failure(
          parseResult: parseResult,
          parsedQuery: parsedQuery,
          voiceRecovery: recovery,
          error: resolutionResult.error!,
          referents: context?.referents ?? ResultReferentContext.empty,
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

      // Deterministically derive referents from SearchResponse
      final derivedReferents = ResultReferentContext.fromSearchResponse(
        searchResponse,
        previous: context?.referents ?? ResultReferentContext.empty,
        queryRally: resolvedQuery.targetRallyName,
        queryDriver: resolvedQuery.driverName,
        queryRallies: resolvedQuery.targetRallyNames,
        queryDrivers: resolvedQuery.driverNames,
        queryPersonRole: resolvedQuery.personRole,
      );

      return NaturalLanguageSearchResult(
        parseResult: parseResult,
        parsedQuery: parsedQuery,
        resolvedQuery: resolvedQuery,
        voiceRecovery: recovery,
        searchResponse: searchResponse,
        resolutions: resolutionResult.resolutions,
        interpretedSummary: summary,
        referents: derivedReferents,
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
        referents: context?.referents ?? ResultReferentContext.empty,
        totalLatencyMs: overallStopwatch.elapsedMilliseconds,
      );
    }
  }
}
