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
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/search_repository.dart';

/// Phase 1 UI/UX: search-first home, no auto-search, hero + examples, both
/// voice modes retained, no telemetry/provenance leakage.
class CountingSearchRepository implements ISearchRepository {
  int searchCallCount = 0;
  SearchQuery? lastQuery;

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    searchCallCount++;
    lastQuery = query;
    return SearchResponse<RallySearchResult>(
      intent: SearchIntent.searchRallies,
      results: [
        RallySearchResult(
          eventId: 'e-1',
          eventName: 'Rally Ireland 2026',
          country: 'Ireland',
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
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery q) async =>
      (await search(q)) as SearchResponse<RallySearchResult>;
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(
    SearchQuery q,
  ) async => (await search(q)) as SearchResponse<RallyParticipationResult>;
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(
    SearchQuery q,
  ) async => (await search(q)) as SearchResponse<RallyParticipationResult>;
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery q) async =>
      (await search(q)) as SearchResponse<RallyResult>;
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery q) async =>
      (await search(q)) as SearchResponse<RallyResult>;
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery q) async =>
      (await search(q)) as SearchResponse<VideoAction>;
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(
    SearchQuery q,
  ) async => (await search(q)) as SearchResponse<VideoSearchResult>;
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(
    SearchQuery q,
  ) async => (await search(q)) as SearchResponse<UploaderSearchResult>;
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(
    SearchQuery q,
  ) async => (await search(q)) as SearchResponse<DriverWinResult>;
}

class NoopEntityLookupRepo implements IEntityLookupRepository {
  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 10,
  }) async => [];
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

Widget _wrap(GeneralSearchScreen screen) => MaterialApp(home: screen);

void main() {
  NaturalLanguageSearchService buildNlService(CountingSearchRepository repo) {
    return NaturalLanguageSearchService(
      parser: MockLlmQueryParser(),
      entityResolver: DatabaseEntityResolver(repository: NoopEntityLookupRepo()),
      repository: repo,
    );
  }

  group('Phase 1 — search-first home', () {
    testWidgets('does NOT auto-search on first launch and shows the hero', (
      tester,
    ) async {
      final repo = CountingSearchRepository();
      await tester.pumpWidget(
        _wrap(
          GeneralSearchScreen(
            repository: repo,
            nlSearchService: buildNlService(repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No backend search runs automatically.
      expect(repo.searchCallCount, 0);

      // Hero content is present.
      expect(find.text('Rally Search'), findsWidgets);
      expect(find.text('Try'), findsOneWidget);

      // Exactly one hero search field is visible.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('example queries are visible on first launch', (tester) async {
      final repo = CountingSearchRepository();
      await tester.pumpWidget(
        _wrap(
          GeneralSearchScreen(
            repository: repo,
            nlSearchService: buildNlService(repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rallies in Ireland in 2025'), findsOneWidget);
      expect(find.text("Show Max Freeman's rallies"), findsOneWidget);
      expect(find.text('Who won Rally Donegal?'), findsOneWidget);
    });

    testWidgets('both voice modes are visible and independent', (tester) async {
      final repo = CountingSearchRepository();
      await tester.pumpWidget(
        _wrap(
          GeneralSearchScreen(
            repository: repo,
            nlSearchService: buildNlService(repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both retained (product decision).
      expect(find.byKey(const Key('cloud_voice_button')), findsOneWidget);
      expect(find.byKey(const Key('native_voice_button')), findsOneWidget);
      // Product-facing labels, no provider terminology.
      expect(find.text('Cloud voice'), findsOneWidget);
      expect(find.text('On-device voice'), findsOneWidget);
      expect(find.textContaining('Whisper'), findsNothing);
    });

    testWidgets('tapping an example query runs a search and shows results', (
      tester,
    ) async {
      final repo = CountingSearchRepository();
      await tester.pumpWidget(
        _wrap(
          GeneralSearchScreen(
            repository: repo,
            nlSearchService: buildNlService(repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rallies in Ireland in 2025'));
      await tester.pumpAndSettle();

      expect(repo.searchCallCount, greaterThan(0));
      expect(find.text('Rally Ireland 2026'), findsOneWidget);
    });

    testWidgets('no telemetry or STT provenance surfaces in normal UI', (
      tester,
    ) async {
      final repo = CountingSearchRepository();
      await tester.pumpWidget(
        _wrap(
          GeneralSearchScreen(
            repository: repo,
            nlSearchService: buildNlService(repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Run a search so the interpreted-summary bar is shown.
      await tester.enterText(find.byType(TextField), 'rallies in Ireland');
      await tester.pump(); // inline submit appears once the field has text
      await tester.tap(find.byKey(const Key('submit_search_button')));
      await tester.pumpAndSettle();

      // No telemetry chip / dialog affordance.
      expect(find.byIcon(Icons.analytics_outlined), findsNothing);
      expect(find.textContaining('Tokens'), findsNothing);
      expect(find.textContaining('Provider'), findsNothing);
      // No STT provenance line.
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('browse/streams affordance remains reachable from search', (
      tester,
    ) async {
      final repo = CountingSearchRepository();
      await tester.pumpWidget(
        _wrap(
          GeneralSearchScreen(
            repository: repo,
            nlSearchService: buildNlService(repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Browse entry point exists in the app bar (navigation target is the
      // RallyStreamsPage, which is retained, not deleted).
      expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
    });
  });
}
