import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
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

void main() {
  group('NaturalLanguageSearchService & Canonical Regression Dataset', () {
    late MockSearchRepository mockRepo;
    late MockLlmQueryParser mockParser;
    late NaturalLanguageSearchService service;

    setUp(() {
      mockRepo = MockSearchRepository();
      mockParser = MockLlmQueryParser();
      service = NaturalLanguageSearchService(
        parser: mockParser,
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

    test('1b. "show me rallies in poland" -> SEARCH_RALLIES, country=Poland', () async {
      final res = await service.search('show me rallies in poland');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchRallies);
      expect(res.query!.country, 'Poland');
      expect(mockRepo.lastReceivedQuery!.intent, SearchIntent.searchRallies);
      expect(mockRepo.lastReceivedQuery!.country, 'Poland');
    });

    test('2. "Show rallies in Ireland in 2025." -> SEARCH_RALLIES, country=Ireland, year=2025', () async {
      final res = await service.search('Show rallies in Ireland in 2025.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchRallies);
      expect(res.query!.country, 'Ireland');
      expect(res.query!.year, 2025);
    });

    test('3. "Show rallies in Ireland in 2025 where Josh Moffett participated." -> SEARCH_DRIVER_RALLIES, country=Ireland, year=2025, driverName=Josh Moffett', () async {
      final res = await service.search('Show rallies in Ireland in 2025 where Josh Moffett participated.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchDriverRallies);
      expect(res.query!.country, 'Ireland');
      expect(res.query!.year, 2025);
      expect(res.query!.driverName, 'Josh Moffett');
    });

    test('4. "Which rallies did Josh Moffett win?" -> SEARCH_DRIVER_WINS, driverName=Josh Moffett', () async {
      final res = await service.search('Which rallies did Josh Moffett win?');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchDriverWins);
      expect(res.query!.driverName, 'Josh Moffett');
    });

    test('5. "Which rallies did Josh Moffett win in 2025?" -> SEARCH_DRIVER_WINS, driverName=Josh Moffett, year=2025', () async {
      final res = await service.search('Which rallies did Josh Moffett win in 2025?');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchDriverWins);
      expect(res.query!.driverName, 'Josh Moffett');
      expect(res.query!.year, 2025);
    });

    test('6. "Who finished first in Moonraker?" -> GET_RALLY_RESULTS, rallyName=Moonraker', () async {
      final res = await service.search('Who finished first in Moonraker?');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.getRallyResults);
      expect(res.query!.targetRallyName, contains('Moonraker'));
    });

    test('7. "Show the top 10 finishers from Moonraker." -> GET_RALLY_TOP_FINISHERS, rallyName=Moonraker, limit=10', () async {
      final res = await service.search('Show the top 10 finishers from Moonraker.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.getRallyTopFinishers);
      expect(res.query!.targetRallyName, contains('Moonraker'));
      expect(res.query!.limit, 10);
    });

    test('8. "Show jump highlights from Moonraker." -> SEARCH_VIDEO_ACTIONS, actionType=jump, rallyName=Moonraker', () async {
      final res = await service.search('Show jump highlights from Moonraker.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchVideoActions);
      expect(res.query!.actionType, 'jump');
      expect(res.query!.targetRallyName, contains('Moonraker'));
    });

    test('9. "Show jump highlights featuring Josh Moffett from Moonraker." -> SEARCH_VIDEO_ACTIONS, actionType=jump, driverName=Josh Moffett, rallyName=Moonraker', () async {
      final res = await service.search('Show jump highlights featuring Josh Moffett from Moonraker.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchVideoActions);
      expect(res.query!.actionType, 'jump');
      expect(res.query!.driverName, 'Josh Moffett');
      expect(res.query!.targetRallyName, contains('Moonraker'));
    });

    test('10. "Show videos featuring Josh Moffett." -> SEARCH_DRIVER_VIDEOS, driverName=Josh Moffett', () async {
      final res = await service.search('Show videos featuring Josh Moffett.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchDriverVideos);
      expect(res.query!.driverName, 'Josh Moffett');
    });

    test('11. "Who are the top uploaders for Moonraker?" -> GET_TOP_UPLOADERS, rallyName=Moonraker', () async {
      final res = await service.search('Who are the top uploaders for Moonraker?');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.getTopUploaders);
      expect(res.query!.targetRallyName, contains('Moonraker'));
    });

    test('12. "Show the drivers with the most wins." -> GET_TOP_DRIVERS_BY_WINS', () async {
      final res = await service.search('Show the drivers with the most wins.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.getTopDriversByWins);
    });

    test('13. "Show drift highlights from Trackrod Rally on Gale Rigg." -> SEARCH_VIDEO_ACTIONS, actionType=drift, rallyName=Trackrod Rally, stageName=Gale Rigg', () async {
      final res = await service.search('Show drift highlights from Trackrod Rally on Gale Rigg.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchVideoActions);
      expect(res.query!.actionType, 'drift');
      expect(res.query!.targetRallyName, contains('Trackrod'));
      expect(res.query!.stageName, 'Gale Rigg');
    });

    test('14. "Show drift highlights featuring Philip Squires from Get Jerky." -> SEARCH_VIDEO_ACTIONS, actionType=drift, driverName=Philip Squires, rallyName=Get Jerky', () async {
      final res = await service.search('Show drift highlights featuring Philip Squires from Get Jerky.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchVideoActions);
      expect(res.query!.actionType, 'drift');
      expect(res.query!.driverName, 'Philip Squires');
      expect(res.query!.targetRallyName, contains('Get Jerky'));
    });

    test('15. "Show jumps in Ireland." -> SEARCH_VIDEO_ACTIONS, actionType=jump, country=Ireland', () async {
      final res = await service.search('Show jumps in Ireland.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchVideoActions);
      expect(res.query!.actionType, 'jump');
      expect(res.query!.country, 'Ireland');
    });

    test('16. "Find rallies from 2025." -> SEARCH_RALLIES, year=2025', () async {
      final res = await service.search('Find rallies from 2025.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchRallies);
      expect(res.query!.year, 2025);
    });

    test('17. "Show rallies in Donegal." -> SEARCH_RALLIES, rallyName=Donegal', () async {
      final res = await service.search('Show rallies in Donegal.');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchRallies);
      expect(res.query!.targetRallyName, contains('Donegal'));
    });

    test('Rejects empty query with clear failure without hitting repository', () async {
      final res = await service.search('   ');
      expect(res.isSuccess, isFalse);
      expect(res.error, 'Search query cannot be empty');
      expect(mockRepo.searchCallCount, 0);
    });

    test('Propagates clarification without hitting repository', () async {
      final clarifyParser = MockLlmQueryParser(
        simulateClarification: true,
        clarificationQuestion: 'Which rally year do you mean?',
      );
      final clarifyService = NaturalLanguageSearchService(
        parser: clarifyParser,
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
