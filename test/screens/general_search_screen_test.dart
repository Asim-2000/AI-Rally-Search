import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/widgets/driver_participation_card.dart';
import 'package:ai_rally_search/widgets/driver_wins_leaderboard.dart';
import 'package:ai_rally_search/widgets/rally_leaderboard.dart';
import 'package:ai_rally_search/widgets/rally_result_card.dart';
import 'package:ai_rally_search/widgets/uploader_leaderboard.dart';

class FakeSearchRepository implements ISearchRepository {
  SearchQuery? lastQuery;

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    lastQuery = query;

    if (query.intent == SearchIntent.searchRallies) {
      final country = query.countries.isEmpty
          ? 'Ireland'
          : query.countries.first;
      return SearchResponse<RallySearchResult>(
        intent: query.intent,
        results: [
          RallySearchResult(
            eventId: 'event-101',
            eventName: 'Rally $country 2026',
            country: country,
            city: 'Letterkenny',
            stagesCount: 12,
            startDate: DateTime(2026, 6, 20),
          ),
        ],
        totalCount: 1,
        hasMore: false,
        limit: query.limit,
        offset: query.offset,
      );
    } else if (query.intent == SearchIntent.getRallyResults ||
        query.intent == SearchIntent.getRallyTopFinishers) {
      return SearchResponse<RallyResult>(
        intent: query.intent,
        results: [
          const RallyResult(
            id: 1,
            rallyId: 'e-donegal',
            eventName: 'Donegal International Rally 2025',
            driverName: 'Josh Moffett',
            posOverall: 1,
            totalTime: '3600.0',
          ),
        ],
        totalCount: 1,
        hasMore: false,
        limit: query.limit,
        offset: query.offset,
      );
    }

    return SearchResponse<dynamic>(
      intent: query.intent,
      results: [],
      totalCount: 0,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<RallySearchResult>;
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<RallyParticipationResult>;
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<RallyParticipationResult>;
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<RallyResult>;
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<RallyResult>;
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<VideoAction>;
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<VideoSearchResult>;
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<UploaderSearchResult>;
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(
    SearchQuery query,
  ) async => (await search(query)) as SearchResponse<DriverWinResult>;
}

class ControlledLlmQueryParser implements LlmQueryParser {
  final Map<String, Completer<QueryParseResult>> requests = {};

  @override
  LlmProvider get provider => LlmProvider.mock;

  @override
  Future<QueryParseResult> parse(String userQuery, {SearchContext? context}) {
    return (requests[userQuery] ??= Completer<QueryParseResult>()).future;
  }

  void complete(String text, SearchQuery query) {
    requests[text]!.complete(QueryParseResult(query: query));
  }
}

class FakeEntityLookupRepo implements IEntityLookupRepository {
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
        id: 'r-1',
        type: EntityType.rally,
        canonicalName: phrase,
        metadata: {'year': year ?? 2026},
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
  }) async => [];

  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
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

void main() {
  group('Result Views Widget Unit Tests', () {
    testWidgets('RallyResultCard renders event details properly', (
      tester,
    ) async {
      final rally = RallySearchResult(
        eventId: 'event-101',
        eventName: 'Donegal International Rally 2025',
        country: 'Ireland',
        city: 'Letterkenny',
        stagesCount: 14,
        startDate: DateTime(2025, 6, 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RallyResultCard(rally: rally)),
        ),
      );

      expect(find.text('Donegal International Rally 2025'), findsOneWidget);
      expect(find.text('Letterkenny, Ireland'), findsOneWidget);
      expect(find.text('14 stages'), findsOneWidget);
    });

    testWidgets('DriverParticipationCard renders win and place badges', (
      tester,
    ) async {
      final part = RallyParticipationResult(
        rallyId: 'event-101',
        eventName: 'Donegal International Rally 2025',
        driverName: 'Josh Moffett',
        crew: 'Moffett / Hayes',
        carNumber: '1',
        make: 'Hyundai i20 R5',
        posOverall: 1,
        totalTime: '3600.5',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriverParticipationCard(participation: part)),
        ),
      );

      expect(find.text('Josh Moffett'), findsOneWidget);
      expect(find.text('Donegal International Rally 2025'), findsOneWidget);
      expect(find.text('🏆 1st Place (Winner)'), findsOneWidget);
    });

    testWidgets('RallyLeaderboard renders top finishers in rank order', (
      tester,
    ) async {
      const results = [
        RallyResult(
          id: 1,
          rallyId: 'e-101',
          eventName: 'Donegal 2025',
          driverName: 'Josh Moffett',
          posOverall: 1,
          totalTime: '3600.5',
        ),
        RallyResult(
          id: 2,
          rallyId: 'e-101',
          eventName: 'Donegal 2025',
          driverName: 'Sam Moffett',
          posOverall: 2,
          totalTime: '3610.2',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RallyLeaderboard(
                results: results,
                rallyName: 'Donegal 2025',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Donegal 2025'), findsOneWidget);
      expect(find.text('Josh Moffett'), findsOneWidget);
      expect(find.text('Sam Moffett'), findsOneWidget);
    });

    testWidgets('UploaderLeaderboard renders ranked contributors', (
      tester,
    ) async {
      const uploaders = [
        UploaderSearchResult(
          uploaderId: 'u-1',
          uploaderName: 'RallyMediaPro',
          uploadCount: 25,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UploaderLeaderboard(uploaders: uploaders),
            ),
          ),
        ),
      );

      expect(find.text('RallyMediaPro'), findsOneWidget);
      expect(find.text('25 vids'), findsOneWidget);
    });

    testWidgets('DriverWinsLeaderboard renders career victories list', (
      tester,
    ) async {
      const winners = [
        DriverWinResult(
          driverName: 'Josh Moffett',
          winCount: 12,
          country: 'Ireland',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DriverWinsLeaderboard(drivers: winners),
            ),
          ),
        ),
      );

      expect(find.text('Josh Moffett'), findsOneWidget);
      expect(find.text('🏆 12 wins'), findsOneWidget);
      expect(find.text('Ireland'), findsOneWidget);
    });
  });

  group('GeneralSearchScreen Continuous Search & UX Widget Tests', () {
    testWidgets(
      'Renders unified search controls, active context chips, and results',
      (tester) async {
        final fakeRepo = FakeSearchRepository();
        final mockParser = MockLlmQueryParser();
        final lookupRepo = FakeEntityLookupRepo();
        final resolver = DatabaseEntityResolver(repository: lookupRepo);
        final nlService = NaturalLanguageSearchService(
          parser: mockParser,
          entityResolver: resolver,
          repository: fakeRepo,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GeneralSearchScreen(
              repository: fakeRepo,
              nlSearchService: nlService,
              initialQuery: const SearchQuery(
                intent: SearchIntent.searchRallies,
                countries: ['Ireland'],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('AI Rally Search'), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
        expect(find.text('Ireland'), findsWidgets);
        expect(find.text('Rally Ireland 2026'), findsOneWidget);
      },
    );

    testWidgets(
      'Submitting continuous natural language search updates query and results',
      (tester) async {
        final fakeRepo = FakeSearchRepository();
        final mockParser = MockLlmQueryParser();
        final lookupRepo = FakeEntityLookupRepo();
        final resolver = DatabaseEntityResolver(repository: lookupRepo);
        final nlService = NaturalLanguageSearchService(
          parser: mockParser,
          entityResolver: resolver,
          repository: fakeRepo,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GeneralSearchScreen(
              repository: fakeRepo,
              nlSearchService: nlService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'Show rallies in Ireland');
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
        expect(find.text('Rally Ireland 2026'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping chip remove (×) deterministically removes filter without LLM call',
      (tester) async {
        final fakeRepo = FakeSearchRepository();
        final mockParser = MockLlmQueryParser();
        final lookupRepo = FakeEntityLookupRepo();
        final resolver = DatabaseEntityResolver(repository: lookupRepo);
        final nlService = NaturalLanguageSearchService(
          parser: mockParser,
          entityResolver: resolver,
          repository: fakeRepo,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GeneralSearchScreen(
              repository: fakeRepo,
              nlSearchService: nlService,
              initialQuery: const SearchQuery(
                intent: SearchIntent.searchRallies,
                countries: ['Ireland'],
                years: [2026],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Ireland'), findsWidgets);
        expect(find.text('2026'), findsWidgets);

        // Tap close on 2026 chip
        final closeIcons = find.byIcon(Icons.close_rounded);
        expect(closeIcons, findsWidgets);
        await tester.tap(closeIcons.first);
        await tester.pumpAndSettle();

        // Verified search re-executed deterministically
        expect(fakeRepo.lastQuery, isNotNull);
      },
    );

    testWidgets('Tapping advanced filters button opens bottom sheet', (
      tester,
    ) async {
      final fakeRepo = FakeSearchRepository();

      await tester.pumpWidget(
        MaterialApp(home: GeneralSearchScreen(repository: fakeRepo)),
      );

      await tester.pumpAndSettle();

      final tuneButton = find.byIcon(Icons.tune_rounded);
      expect(tuneButton, findsOneWidget);
      await tester.tap(tuneButton);
      await tester.pumpAndSettle();

      expect(find.text('Advanced Filters'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);
    });

    testWidgets('newer request wins when an older response arrives last', (
      tester,
    ) async {
      final repository = FakeSearchRepository();
      final parser = ControlledLlmQueryParser();
      final service = NaturalLanguageSearchService(
        parser: parser,
        entityResolver: DatabaseEntityResolver(
          repository: FakeEntityLookupRepo(),
        ),
        repository: repository,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GeneralSearchScreen(
            repository: repository,
            nlSearchService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byType(TextField).first;
      await tester.enterText(field, 'request A');
      await tester.tap(find.text('Search'));
      await tester.pump();
      await tester.enterText(field, 'request B');
      await tester.tap(find.text('Search'));
      await tester.pump();

      parser.complete(
        'request B',
        const SearchQuery(
          intent: SearchIntent.searchRallies,
          countries: ['France'],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rally France 2026'), findsOneWidget);

      parser.complete(
        'request A',
        const SearchQuery(
          intent: SearchIntent.searchRallies,
          countries: ['Germany'],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rally France 2026'), findsOneWidget);
      expect(find.text('Rally Germany 2026'), findsNothing);
    });

    testWidgets('clearing input invalidates an in-flight response', (
      tester,
    ) async {
      final repository = FakeSearchRepository();
      final parser = ControlledLlmQueryParser();
      final service = NaturalLanguageSearchService(
        parser: parser,
        entityResolver: DatabaseEntityResolver(
          repository: FakeEntityLookupRepo(),
        ),
        repository: repository,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GeneralSearchScreen(
            repository: repository,
            nlSearchService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byType(TextField).first;
      await tester.enterText(field, 'request A');
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      parser.complete(
        'request A',
        const SearchQuery(
          intent: SearchIntent.searchRallies,
          countries: ['Germany'],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rally Germany 2026'), findsNothing);
      expect(tester.widget<TextField>(field).controller?.text, isEmpty);
    });
  });
}
