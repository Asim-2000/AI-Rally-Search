import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/search_repository.dart';

class MockSearchRepository implements ISearchRepository {
  SearchQuery? lastReceivedQuery;
  int searchCallCount = 0;

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    lastReceivedQuery = query;
    searchCallCount++;

    return SearchResponse<dynamic>(
      intent: query.intent,
      results: ['result_item_1', 'result_item_2'],
      totalCount: 2,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(SearchQuery query) async => throw UnimplementedError();
}

class TestEntityLookupRepository implements IEntityLookupRepository {
  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 10,
  }) async {
    final lower = phrase.toLowerCase().trim();
    if (lower.contains('moonraker')) {
      final list = [
        const EntityCandidate(
          id: 'moonraker-2025-uuid',
          type: EntityType.rally,
          canonicalName: 'Moonraker Forestry Rally 2025',
          metadata: {'year': 2025},
        ),
        const EntityCandidate(
          id: 'moonraker-2026-uuid',
          type: EntityType.rally,
          canonicalName: 'Moonraker Forestry Rally 2026',
          metadata: {'year': 2026},
        ),
      ];
      if (year != null) {
        return list.where((c) => c.metadata?['year'] == year).toList();
      }
      return list;
    }
    if (lower.contains('get jerky')) {
      return [
        const EntityCandidate(
          id: 'get-jerky-2026-uuid',
          type: EntityType.rally,
          canonicalName: 'Get Jerky Rally North Wales 2026',
          metadata: {'year': 2026},
        ),
      ];
    }
    if (lower.contains('trackrod')) {
      return [
        const EntityCandidate(
          id: 'trackrod-2024-uuid',
          type: EntityType.rally,
          canonicalName: 'Trackrod Rally 2024',
          metadata: {'year': 2024},
        ),
      ];
    }
    return [];
  }

  @override
  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    int limit = 10,
  }) async {
    final lower = phrase.toLowerCase().trim();
    if (lower.contains('josh moffett')) {
      return [
        const EntityCandidate(
          id: 'josh-moffett-uuid',
          type: EntityType.driver,
          canonicalName: 'Josh Moffett',
        ),
      ];
    }
    if (lower.contains('moffett')) {
      final list = [
        const EntityCandidate(
          id: 'josh-moffett-uuid',
          type: EntityType.driver,
          canonicalName: 'Josh Moffett',
          metadata: {'eventId': 'moonraker-2025-uuid'},
        ),
        const EntityCandidate(
          id: 'sam-moffett-uuid',
          type: EntityType.driver,
          canonicalName: 'Sam Moffett',
        ),
      ];
      if (eventId == 'moonraker-2025-uuid') {
        return [
          const EntityCandidate(
            id: 'josh-moffett-uuid',
            type: EntityType.driver,
            canonicalName: 'Josh Moffett',
            metadata: {'inContext': true},
          ),
        ];
      }
      return list;
    }
    if (lower.contains('philip squires') || lower.contains('squires')) {
      return [
        const EntityCandidate(
          id: 'philip-squires-uuid',
          type: EntityType.driver,
          canonicalName: 'Philip Squires',
        ),
      ];
    }
    return [];
  }

  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 10,
  }) async {
    final lower = phrase.toLowerCase().trim();
    if (lower.contains('gale rigg')) {
      return [
        const EntityCandidate(
          id: 'gale-rigg-uuid',
          type: EntityType.stage,
          canonicalName: 'Gale Rigg',
          metadata: {'stageNumber': '3'},
        ),
      ];
    }
    return [];
  }

  @override
  Future<List<EntityCandidate>> lookupCities(String phrase, {String? country, int limit = 10}) async => [];
  @override
  Future<List<EntityCandidate>> lookupUploaders(String phrase, {int limit = 10}) async => [];
}

void main() {
  group('NaturalLanguageSearchService & Phase 3.5 Entity Resolution', () {
    late MockSearchRepository mockRepo;
    late MockLlmQueryParser mockParser;
    late DatabaseEntityResolver resolver;
    late NaturalLanguageSearchService service;

    setUp(() {
      mockRepo = MockSearchRepository();
      mockParser = MockLlmQueryParser();
      resolver = DatabaseEntityResolver(repository: TestEntityLookupRepository());
      service = NaturalLanguageSearchService(
        parser: mockParser,
        entityResolver: resolver,
        repository: mockRepo,
      );
    });

    test('1. "Show all rallies in Ireland." -> SEARCH_RALLIES, country=Ireland', () async {
      final res = await service.search('Show all rallies in Ireland.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchRallies);
      expect(res.query!.country, 'Ireland');
      expect(mockRepo.lastReceivedQuery!.intent, SearchIntent.searchRallies);
      expect(mockRepo.lastReceivedQuery!.country, 'Ireland');
    });

    test('2. "Show rallies in Ireland in 2025." -> SEARCH_RALLIES, country=Ireland, year=2025', () async {
      final res = await service.search('Show rallies in Ireland in 2025.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchRallies);
      expect(res.query!.country, 'Ireland');
      expect(res.query!.year, 2025);
    });

    test('3. "Show rallies in Ireland in 2025 where Josh Moffett participated." -> preserves parsed & resolved queries', () async {
      final res = await service.search('Show rallies in Ireland in 2025 where Josh Moffett participated.');
      expect(res.isSuccess, isTrue);
      expect(res.parsedQuery?.driverName, 'Josh Moffett');
      expect(res.resolvedQuery?.driverName, 'Josh Moffett');
      expect(res.resolvedQuery?.driverId, 'josh-moffett-uuid');
      expect(mockRepo.lastReceivedQuery!.driverId, 'josh-moffett-uuid');
    });

    test('4. "Show jump highlights featuring Moffett from Moonraker in 2025" -> contextual resolution', () async {
      final res = await service.search('Show jump highlights featuring Moffett from Moonraker in 2025');
      expect(res.isSuccess, isTrue);
      expect(res.parsedQuery?.driverName, 'Moffett');
      expect(res.parsedQuery?.targetRallyName, 'Moonraker');
      expect(res.resolvedQuery?.driverName, 'Josh Moffett');
      expect(res.resolvedQuery?.driverId, 'josh-moffett-uuid');
      expect(res.resolvedQuery?.targetRallyName, 'Moonraker Forestry Rally 2025');
      expect(res.query!.actionType, 'jump');
    });

    test('5. "Who won Moonraker?" without year triggers rally edition clarification', () async {
      final res = await service.search('Who won Moonraker?');
      expect(res.isSuccess, isFalse);
      expect(res.requiresClarification, isTrue);
      expect(res.candidates.length, greaterThanOrEqualTo(2));
      expect(mockRepo.searchCallCount, 0); // Did not execute DB query prematurely
    });

    test('6. "Show drift highlights featuring Philip Squires from Get Jerky." -> resolves Get Jerky', () async {
      final res = await service.search('Show drift highlights featuring Philip Squires from Get Jerky.');
      expect(res.isSuccess, isTrue);
      expect(res.resolvedQuery?.targetRallyName, 'Get Jerky Rally North Wales 2026');
      expect(res.resolvedQuery?.driverName, 'Philip Squires');
      expect(res.resolvedQuery?.driverId, 'philip-squires-uuid');
    });

    test('7. "Show drift highlights from Trackrod Rally on Gale Rigg." -> resolves stage in event context', () async {
      final res = await service.search('Show drift highlights from Trackrod Rally on Gale Rigg.');
      expect(res.isSuccess, isTrue);
      expect(res.resolvedQuery?.targetRallyName, 'Trackrod Rally 2024');
      expect(res.resolvedQuery?.stageName, 'Gale Rigg');
      expect(res.resolvedQuery?.stageNumber, '3');
    });

    test('Rejects empty query with clear failure without hitting entity resolver or repository', () async {
      final res = await service.search('   ');
      expect(res.isSuccess, isFalse);
      expect(res.error, 'Search query cannot be empty');
      expect(mockRepo.searchCallCount, 0);
    });

    test('Propagates parser clarification without hitting entity resolver or repository', () async {
      final clarifyParser = MockLlmQueryParser(
        simulateClarification: true,
        clarificationQuestion: 'Which rally year do you mean?',
      );
      final clarifyService = NaturalLanguageSearchService(
        parser: clarifyParser,
        entityResolver: resolver,
        repository: mockRepo,
      );

      final res = await clarifyService.search('Show results');
      expect(res.isSuccess, isFalse);
      expect(res.requiresClarification, isTrue);
      expect(res.clarificationQuestion, 'Which rally year do you mean?');
      expect(mockRepo.searchCallCount, 0);
    });
  });
}
