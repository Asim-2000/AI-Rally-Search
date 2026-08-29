import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/conversational_search_session.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/result_referent_context.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/search_repository.dart';

/// Fake repository with realistic deterministic responses for conversational tests.
class ConversationalTestSearchRepository implements ISearchRepository {
  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    switch (query.intent) {
      case SearchIntent.searchRallies:
        return SearchResponse<RallySearchResult>(
          intent: query.intent,
          results: [
            RallySearchResult(
              eventId: 'e-donegal-2025',
              eventName: 'Donegal International Rally 2025',
              country: 'Ireland',
              city: 'Letterkenny',
              stagesCount: 14,
              startDate: DateTime(2025, 6, 20),
            ),
          ],
          totalCount: 1,
          hasMore: false,
          limit: query.limit,
          offset: query.offset,
        );

      case SearchIntent.getRallyResults:
      case SearchIntent.getRallyTopFinishers:
        return SearchResponse<RallyResult>(
          intent: query.intent,
          results: [
            const RallyResult(
              id: 101,
              rallyId: 'e-donegal-2025',
              eventName: 'Donegal International Rally 2025',
              driverId: 'd-101',
              driverName: 'Josh Moffett',
              carNumber: '1',
              make: 'Hyundai i20 R5',
              posOverall: 1,
              totalTime: '3600.5',
            ),
            const RallyResult(
              id: 102,
              rallyId: 'e-donegal-2025',
              eventName: 'Donegal International Rally 2025',
              driverId: 'd-102',
              driverName: 'Sam Moffett',
              carNumber: '2',
              make: 'Ford Fiesta Rally2',
              posOverall: 2,
              totalTime: '3610.2',
            ),
          ],
          totalCount: 2,
          hasMore: false,
          limit: query.limit,
          offset: query.offset,
        );

      case SearchIntent.searchDriverVideos:
        return SearchResponse<VideoSearchResult>(
          intent: query.intent,
          results: [
            VideoSearchResult(
              videoId: 101,
              driverName: 'Josh Moffett',
              eventName: 'Donegal International Rally 2025',
              uploadTime: DateTime(2025, 6, 21),
            ),
          ],
          totalCount: 1,
          hasMore: false,
          limit: query.limit,
          offset: query.offset,
        );

      case SearchIntent.searchVideoActions:
        return SearchResponse<VideoAction>(
          intent: query.intent,
          results: [
            VideoAction(
              id: 501,
              videoId: 101,
              actionType: query.actionTypes.isNotEmpty ? query.actionTypes.first : 'jump',
              title: 'Huge Crest Jump - Josh Moffett',
              startTime: 42.0,
              endTime: 48.0,
              duration: 6.0,
              eventName: 'Donegal International Rally 2025',
              driverName: 'Josh Moffett',
            ),
          ],
          totalCount: 1,
          hasMore: false,
          limit: query.limit,
          offset: query.offset,
        );

      case SearchIntent.searchDriverRallies:
      case SearchIntent.searchDriverWins:
        return SearchResponse<RallyParticipationResult>(
          intent: query.intent,
          results: [
            RallyParticipationResult(
              rallyId: 'e-donegal-2025',
              eventName: 'Donegal International Rally 2025',
              driverName: query.driverName ?? 'Josh Moffett',
              crew: 'Moffett / Hayes',
              carNumber: '1',
              make: 'Hyundai i20 R5',
              posOverall: 1,
              totalTime: '3600.5',
            ),
          ],
          totalCount: 1,
          hasMore: false,
          limit: query.limit,
          offset: query.offset,
        );

      case SearchIntent.getTopUploaders:
      case SearchIntent.getTopDriversByWins:
        return SearchResponse<dynamic>(
          intent: query.intent,
          results: [],
          totalCount: 0,
          hasMore: false,
          limit: query.limit,
          offset: query.offset,
        );
    }
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) async =>
      (await search(query)) as SearchResponse<RallySearchResult>;
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(SearchQuery query) async =>
      (await search(query)) as SearchResponse<RallyParticipationResult>;
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(SearchQuery query) async =>
      (await search(query)) as SearchResponse<RallyParticipationResult>;
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery query) async =>
      (await search(query)) as SearchResponse<RallyResult>;
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery query) async =>
      (await search(query)) as SearchResponse<RallyResult>;
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery query) async =>
      (await search(query)) as SearchResponse<VideoAction>;
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(SearchQuery query) async =>
      (await search(query)) as SearchResponse<VideoSearchResult>;
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(SearchQuery query) async =>
      (await search(query)) as SearchResponse<UploaderSearchResult>;
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(SearchQuery query) async =>
      (await search(query)) as SearchResponse<DriverWinResult>;
}

class ConversationalTestEntityLookupRepository implements IEntityLookupRepository {
  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 10,
  }) async {
    final lower = phrase.toLowerCase().trim();
    if (lower.contains('donegal')) {
      final list = [
        const EntityCandidate(
          id: 'donegal-2025-uuid',
          type: EntityType.rally,
          canonicalName: 'Donegal International Rally 2025',
          metadata: {'year': 2025},
        ),
        const EntityCandidate(
          id: 'donegal-2024-uuid',
          type: EntityType.rally,
          canonicalName: 'Donegal International Rally 2024',
          metadata: {'year': 2024},
        ),
      ];
      if (lower.contains('2025') || year == 2025) {
        return [list[0]];
      }
      if (lower.contains('2024') || year == 2024) {
        return [list[1]];
      }
      if (year != null) {
        return list.where((c) => c.metadata?['year'] == year).toList();
      }
      return list;
    }
    if (lower.contains('moonraker')) {
      return [
        const EntityCandidate(
          id: 'moonraker-2025-uuid',
          type: EntityType.rally,
          canonicalName: 'Moonraker Forestry Rally 2025',
          metadata: {'year': 2025},
        ),
      ];
    }
    return [
      EntityCandidate(
        id: 'r-$lower',
        type: EntityType.rally,
        canonicalName: phrase,
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
    final lower = phrase.toLowerCase().trim();
    if (lower.contains('josh moffett') || lower == 'moffett' || lower == 'josh') {
      return [
        const EntityCandidate(
          id: 'd-101',
          type: EntityType.driver,
          canonicalName: 'Josh Moffett',
        ),
      ];
    }
    if (lower.contains('sam moffett')) {
      return [
        const EntityCandidate(
          id: 'd-102',
          type: EntityType.driver,
          canonicalName: 'Sam Moffett',
        ),
      ];
    }
    return [
      EntityCandidate(
        id: 'd-$lower',
        type: EntityType.driver,
        canonicalName: phrase,
      ),
    ];
  }

  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    int limit = 10,
  }) async => [];

  @override
  Future<List<EntityCandidate>> lookupCities(String phrase, {String? country, int limit = 10}) async => [];

  @override
  Future<List<EntityCandidate>> lookupUploaders(String phrase, {int limit = 10}) async => [];
}

void main() {
  late ISearchRepository repository;
  late MockLlmQueryParser parser;
  late NaturalLanguageSearchService nlService;

  setUp(() {
    repository = ConversationalTestSearchRepository();
    parser = MockLlmQueryParser();
    final lookupRepo = ConversationalTestEntityLookupRepository();
    final resolver = DatabaseEntityResolver(repository: lookupRepo);
    nlService = NaturalLanguageSearchService(
      parser: parser,
      entityResolver: resolver,
      repository: repository,
    );
  });

  group('Mandatory 4-Turn Conversational Integration Pipeline', () {
    test('Executes Donegal 2025 -> Who won it? -> Videos of him -> Only jumps seamlessly', () async {
      var session = SearchConversationSession.initial;

      // TURN 1: "Show Donegal Rally 2025"
      final turn1Result = await nlService.search(
        'Show Donegal Rally 2025',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(turn1Result.isSuccess, isTrue);
      expect(turn1Result.query?.intent, equals(SearchIntent.searchRallies));
      expect(turn1Result.referents.activeRally, contains('Donegal'));

      session = session.recordTurn(
        query: turn1Result.query!,
        referents: turn1Result.referents,
        title: 'Show Donegal Rally 2025',
        response: turn1Result.searchResponse,
        interpretedSummary: turn1Result.interpretedSummary,
      );

      // TURN 2: "Who won it?"
      final turn2Result = await nlService.search(
        'Who won it?',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(turn2Result.isSuccess, isTrue);
      expect(turn2Result.query?.intent, equals(SearchIntent.getRallyResults));
      expect(turn2Result.query?.targetRallyName, contains('Donegal'));
      // Database result returned winner Josh Moffett
      expect(turn2Result.referents.lastWinner, equals('Josh Moffett'));
      expect(turn2Result.referents.activeDriver, equals('Josh Moffett'));

      session = session.recordTurn(
        query: turn2Result.query!,
        referents: turn2Result.referents,
        title: 'Who won it?',
        response: turn2Result.searchResponse,
        interpretedSummary: turn2Result.interpretedSummary,
      );

      // TURN 3: "Show videos of him."
      final turn3Result = await nlService.search(
        'Show videos of him',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(turn3Result.isSuccess, isTrue);
      expect(turn3Result.query?.intent, equals(SearchIntent.searchDriverVideos));
      expect(turn3Result.query?.driverNames, contains('Josh Moffett'));

      session = session.recordTurn(
        query: turn3Result.query!,
        referents: turn3Result.referents,
        title: 'Show videos of him',
        response: turn3Result.searchResponse,
        interpretedSummary: turn3Result.interpretedSummary,
      );

      // TURN 4: "Only show jumps."
      final turn4Result = await nlService.search(
        'Only show jumps',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(turn4Result.isSuccess, isTrue);
      expect(turn4Result.query?.intent, equals(SearchIntent.searchVideoActions));
      expect(turn4Result.query?.actionTypes, equals(['jump']));
      expect(turn4Result.query?.driverNames, contains('Josh Moffett'));
      expect(turn4Result.query?.targetRallyName, contains('Donegal'));
    });
  });

  group('Conversational State & Context Operation Tests', () {
    test('A. Ambiguous pronoun requires clarification when multiple active drivers exist', () async {
      final session = SearchConversationSession(
        referents: const ResultReferentContext(
          activeDrivers: ['Josh Moffett', 'Sam Moffett'],
        ),
      );

      final result = await nlService.search(
        'Show videos of him',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(result.requiresClarification, isTrue);
      expect(result.clarificationQuestion, contains('Which driver do you mean?'));
    });

    test('B. "Who won it?" when no active rally exists requires clarification', () async {
      final session = SearchConversationSession.initial;

      final result = await nlService.search(
        'Who won it?',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(result.requiresClarification, isTrue);
      expect(result.clarificationQuestion, contains('Which rally'));
    });

    test('C. "What about 2024?" replaces year and preserves rally', () async {
      final session = SearchConversationSession(
        activeQuery: const SearchQuery(
          intent: SearchIntent.searchRallies,
          rallyNames: ['Donegal International Rally'],
          years: [2025],
        ),
        referents: const ResultReferentContext(
          activeRally: 'Donegal International Rally',
        ),
      );

      final result = await nlService.search(
        'What about 2024?',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.query?.year, equals(2024));
      expect(result.query?.targetRallyName, contains('Donegal'));
    });

    test('D. "also drifts" adds drift without replacing jump', () async {
      final session = SearchConversationSession(
        activeQuery: const SearchQuery(
          intent: SearchIntent.searchVideoActions,
          actionTypes: ['jump'],
          driverNames: ['Josh Moffett'],
          rallyNames: ['Donegal International Rally'],
          years: [2025],
        ),
        referents: const ResultReferentContext(
          activeRally: 'Donegal International Rally',
          activeDriver: 'Josh Moffett',
        ),
      );

      final result = await nlService.search(
        'also drifts',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.query?.actionTypes, containsAll(['jump', 'drift']));
      expect(result.query?.driverNames, contains('Josh Moffett'));
    });

    test('E. "Only drifts" replaces existing actions with drift', () async {
      final session = SearchConversationSession(
        activeQuery: const SearchQuery(
          intent: SearchIntent.searchVideoActions,
          actionTypes: ['jump', 'crash'],
          driverNames: ['Josh Moffett'],
        ),
        referents: const ResultReferentContext(
          activeDriver: 'Josh Moffett',
        ),
      );

      final result = await nlService.search(
        'Only drifts',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.query?.actionTypes, equals(['drift']));
    });

    test('F. "Forget the driver" removes driver context', () async {
      final session = SearchConversationSession(
        activeQuery: const SearchQuery(
          intent: SearchIntent.searchRallies,
          driverNames: ['Josh Moffett'],
          rallyNames: ['Donegal International Rally'],
          years: [2025],
        ),
        referents: const ResultReferentContext(
          activeRally: 'Donegal International Rally',
          activeDriver: 'Josh Moffett',
        ),
      );

      final result = await nlService.search(
        'forget the driver',
        context: SearchContext(
          currentYear: 2026,
          referents: session.referents,
          previousQuery: session.activeQuery,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.query?.driverNames, isEmpty);
      expect(result.query?.targetRallyName, contains('Donegal'));
    });

    test('G. "Start over" clears query and referents', () {
      final session = SearchConversationSession(
        activeQuery: const SearchQuery(
          intent: SearchIntent.searchVideoActions,
          driverNames: ['Josh Moffett'],
          actionTypes: ['jump'],
        ),
        referents: const ResultReferentContext(
          activeDriver: 'Josh Moffett',
          lastWinner: 'Josh Moffett',
        ),
      );

      final cleared = session.clearAll();

      expect(cleared.activeQuery.driverNames, isEmpty);
      expect(cleared.activeQuery.actionTypes, isEmpty);
      expect(cleared.referents.activeDriver, isNull);
      expect(cleared.referents.lastWinner, isNull);
      expect(cleared.history, isEmpty);
    });

    test('H. Deterministic removeFilter updates multi-value state without LLM call', () {
      final session = SearchConversationSession(
        activeQuery: const SearchQuery(
          intent: SearchIntent.searchRallies,
          countries: ['Ireland', 'Scotland'],
          years: [2024, 2025],
        ),
      );

      final updated = session.removeFilter(field: 'country', value: 'Scotland');

      expect(updated.activeQuery.countries, equals(['Ireland']));
      expect(updated.activeQuery.years, equals([2024, 2025]));
    });

    test('I. History rollback restores both SearchQuery and ResultReferentContext snapshots', () {
      final session = SearchConversationSession.initial
          .recordTurn(
            query: const SearchQuery(intent: SearchIntent.searchRallies, rallyNames: ['Moonraker']),
            referents: const ResultReferentContext(activeRally: 'Moonraker'),
            title: 'Moonraker',
          )
          .recordTurn(
            query: const SearchQuery(intent: SearchIntent.getRallyResults, rallyNames: ['Moonraker']),
            referents: const ResultReferentContext(activeRally: 'Moonraker', lastWinner: 'Jordan Hone'),
            title: 'Winner',
          );

      expect(session.history.length, equals(2));
      expect(session.referents.lastWinner, equals('Jordan Hone'));

      // Rollback to turn 0 (Moonraker)
      final rolledBack = session.rollbackTo(0);

      expect(rolledBack.activeQuery.intent, equals(SearchIntent.searchRallies));
      expect(rolledBack.activeQuery.targetRallyName, equals('Moonraker'));
      expect(rolledBack.referents.lastWinner, isNull);
      expect(rolledBack.history.length, equals(1));
    });

    test('J. Stale async response protection with activeRequestId', () {
      var session = SearchConversationSession.initial;
      final req1 = session.activeRequestId + 1;
      session = session.copyWith(activeRequestId: req1);

      // A newer search is launched
      final req2 = session.activeRequestId + 1;
      session = session.copyWith(activeRequestId: req2);

      // Simulating late arrival of req1 response -> ignored
      final isReq1Valid = req1 == session.activeRequestId;
      final isReq2Valid = req2 == session.activeRequestId;

      expect(isReq1Valid, isFalse);
      expect(isReq2Valid, isTrue);
    });
  });
}
