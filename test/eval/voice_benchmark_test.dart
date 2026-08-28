import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/speech/mock_speech_to_text_service.dart';

import 'multilingual_voice_benchmark_cases.dart';
import 'voice_benchmark_evaluator.dart';
import 'voice_benchmark_models.dart';

class BenchmarkMockEntityLookupRepository implements IEntityLookupRepository {
  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 10,
  }) async {
    return [
      EntityCandidate(
        id: 'e-1',
        type: EntityType.rally,
        canonicalName: phrase.contains('Moonraker')
            ? 'Moonraker Forestry Rally'
            : 'Donegal International Rally',
        score: 0.95,
      ),
    ];
  }

  @override
  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    PersonRole personRole = PersonRole.any,
    int limit = 10,
  }) async {
    return const [
      EntityCandidate(
        id: 'd-1',
        type: EntityType.driver,
        canonicalName: 'Josh Moffett',
        score: 0.95,
      ),
    ];
  }

  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 10,
  }) async => [];

  @override
  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 10,
  }) async => [];

  @override
  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 10,
  }) async => [];
}

class BenchmarkMockSearchRepository implements ISearchRepository {
  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    return SearchResponse<VideoAction>(
      intent: query.intent,
      results: [
        const VideoAction(
          id: 1,
          videoId: 1,
          actionType: 'jump',
          title: 'High speed crest jump',
          startTime: 120.0,
          endTime: 125.0,
          duration: 5.0,
          driverName: 'Josh Moffett',
          eventName: 'Donegal International Rally',
        ),
      ],
      totalCount: 1,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(
    SearchQuery query,
  ) async => throw UnimplementedError();
}

class BenchmarkMockLlmParser implements LlmQueryParser {
  @override
  LlmProvider get provider => LlmProvider.mock;

  @override
  Future<QueryParseResult> parse(
    String rawQuery, {
    SearchContext? context,
  }) async {
    final cleanQuery = rawQuery.trim().toLowerCase();
    VoiceBenchmarkCase? matchedCase;

    for (final c in MultilingualVoiceBenchmarkCases.all) {
      if (c.expectedTranscript.toLowerCase() == cleanQuery ||
          cleanQuery.contains(c.expectedTranscript.toLowerCase()) ||
          c.expectedTranscript.toLowerCase().contains(cleanQuery)) {
        matchedCase = c;
        break;
      }
    }

    final query =
        matchedCase?.expectedQuery ??
        const SearchQuery(
          intent: SearchIntent.searchVideoActions,
          driverName: 'Josh Moffett',
          rallyName: 'Donegal International Rally',
          actionType: 'jump',
          year: 2025,
        );

    return QueryParseResult(
      rawResponse: '{"intent": "${query.intent.name}"}',
      query: query,
      confidence: 1.0,
      provider: LlmProvider.mock,
      model: 'benchmark-mock',
    );
  }
}

void main() {
  group('Multilingual Voice Benchmark Evaluation Tests (19 Languages)', () {
    late MockSpeechToTextService speechService;
    late NaturalLanguageSearchService nlSearchService;
    late BenchmarkMockSearchRepository searchRepo;
    late VoiceBenchmarkEvaluator evaluator;

    setUp(() {
      speechService = MockSpeechToTextService();
      searchRepo = BenchmarkMockSearchRepository();
      final parser = BenchmarkMockLlmParser();
      final lookupRepo = BenchmarkMockEntityLookupRepository();
      final resolver = DatabaseEntityResolver(repository: lookupRepo);

      nlSearchService = NaturalLanguageSearchService(
        parser: parser,
        entityResolver: resolver,
        repository: searchRepo,
      );

      evaluator = VoiceBenchmarkEvaluator(
        speechService: speechService,
        nlSearchService: nlSearchService,
        searchRepository: searchRepo,
      );
    });

    test(
      'Evaluates all 19 supported languages against benchmark criteria',
      () async {
        final cases = MultilingualVoiceBenchmarkCases.all;
        expect(cases.length, greaterThanOrEqualTo(19));

        final results = await evaluator.evaluateSuite(cases);
        expect(results.length, equals(cases.length));

        // Save output reports
        VoiceBenchmarkEvaluator.saveEvaluationReports(
          results: results,
          outputDir: 'test/eval/reports',
        );

        for (final r in results) {
          expect(
            r.driverPreserved,
            isTrue,
            reason: 'Failed for ${r.benchmarkCase.language.displayName}',
          );
          expect(
            r.rallyPreserved,
            isTrue,
            reason: 'Failed for ${r.benchmarkCase.language.displayName}',
          );
          expect(
            r.databaseExecutionSucceeded,
            isTrue,
            reason: 'Failed for ${r.benchmarkCase.language.displayName}',
          );
          expect(r.wordErrorRate, lessThanOrEqualTo(0.5));
        }
      },
    );

    test('Calculates WER and Entity Preservation accurately', () {
      const ref = 'Show jumps featuring Moffett in Donegal 2025';
      const hypExact = 'Show jumps featuring Moffett in Donegal 2025';
      const hypSub = 'Show jumps featuring Moffett in Galway 2025';

      expect(VoiceMetricsCalculator.calculateWer(ref, hypExact), equals(0.0));
      expect(
        VoiceMetricsCalculator.calculateWer(ref, hypSub),
        greaterThan(0.0),
      );
      expect(VoiceMetricsCalculator.calculateWer(ref, hypSub), lessThan(0.3));

      expect(
        VoiceMetricsCalculator.isEntityPreserved(
          'Josh Moffett',
          'Show Moffett jumping',
        ),
        isTrue,
      );
      expect(
        VoiceMetricsCalculator.isEntityPreserved('Donegal', 'Rally in Galway'),
        isFalse,
      );
    });
  });
}
