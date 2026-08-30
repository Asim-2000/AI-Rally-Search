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
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'package:ai_rally_search/models/speech/speech_transcription_result.dart';
import 'package:ai_rally_search/services/search_repository.dart';

/// Configurable repository: empty results, a thrown error, or a gated (pending)
/// response for driving each search state.
class ConfigurableRepo implements ISearchRepository {
  final bool throwError;
  final Completer<void>? gate;

  ConfigurableRepo({this.throwError = false, this.gate});

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    if (gate != null) await gate!.future;
    if (throwError) throw Exception('boom');
    return SearchResponse<RallySearchResult>(
      intent: SearchIntent.searchRallies,
      results: const [],
      totalCount: 0,
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
  Future<List<EntityCandidate>> lookupRallies(String phrase,
          {int? year, String? country, String? city, int limit = 10}) async =>
      [];
  @override
  Future<List<EntityCandidate>> lookupDrivers(String phrase,
          {String? eventId,
          String? eventName,
          int? year,
          PersonRole personRole = PersonRole.any,
          int limit = 10}) async =>
      [];
  @override
  Future<List<EntityCandidate>> lookupStages(String phrase,
          {String? eventId, String? eventName, int? year, int limit = 10}) async =>
      [];
  @override
  Future<List<EntityCandidate>> lookupCities(String phrase,
          {String? country, int limit = 10}) async =>
      [];
  @override
  Future<List<EntityCandidate>> lookupUploaders(String phrase,
          {int limit = 10}) async =>
      [];
}

/// NL service whose typed search always reports an understanding failure.
class FailingNlService extends NaturalLanguageSearchService {
  FailingNlService(ISearchRepository repo)
      : super(
          parser: MockLlmQueryParser(),
          entityResolver: DatabaseEntityResolver(repository: NoopEntityLookupRepo()),
          repository: repo,
        );

  @override
  Future<NaturalLanguageSearchResult> search(String query,
          {SearchContext? context,
          SpeechTranscriptionResult? speechResult}) async =>
      NaturalLanguageSearchResult.failure(
        parseResult: const QueryParseResult(),
        error: 'unparseable',
        friendlyMessage: 'unparseable',
      );
}

Widget _wrap(GeneralSearchScreen s) => MaterialApp(home: s);

void main() {
  testWidgets('no-results renders as a valid outcome with removable filters, not a generic error', (tester) async {
    final repo = ConfigurableRepo();
    await tester.pumpWidget(_wrap(GeneralSearchScreen(
      repository: repo,
      initialQuery: const SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: ['Ireland'],
        years: [2026],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('No rallies found'), findsOneWidget);
    // Filters are echoed and removable; explicit next action present.
    expect(find.text('Ireland'), findsWidgets);
    expect(find.text('2026'), findsWidgets);
    expect(find.text('Start over'), findsOneWidget);
    // Not framed as a failure.
    expect(find.textContaining('Active search context'), findsNothing);
    expect(find.text('Search is temporarily unavailable'), findsNothing);
  });

  testWidgets('backend failure renders friendly service-unavailable copy', (tester) async {
    final repo = ConfigurableRepo(throwError: true);
    await tester.pumpWidget(_wrap(GeneralSearchScreen(
      repository: repo,
      initialQuery: const SearchQuery(intent: SearchIntent.searchRallies),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Search is temporarily unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // No raw exception / stack text.
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('query-understanding failure renders its own copy, distinct from service error', (tester) async {
    final repo = ConfigurableRepo();
    await tester.pumpWidget(_wrap(GeneralSearchScreen(
      repository: repo,
      nlSearchService: FailingNlService(repo),
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'asdfghjkl');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit_search_button')));
    await tester.pumpAndSettle();

    expect(find.text("We couldn't turn that into a search"), findsOneWidget);
    expect(find.text('Search is temporarily unavailable'), findsNothing);
  });

  testWidgets('loading shows contextual copy for the intent', (tester) async {
    final gate = Completer<void>();
    final repo = ConfigurableRepo(gate: gate);
    await tester.pumpWidget(_wrap(GeneralSearchScreen(
      repository: repo,
      initialQuery: const SearchQuery(intent: SearchIntent.searchRallies),
    )));
    // While the gated response is pending, contextual loading copy shows.
    await tester.pump();
    expect(find.text('Searching rallies…'), findsOneWidget);
    // Not a leaked internal step.
    expect(find.textContaining('OpenEntity'), findsNothing);
    expect(find.textContaining('MySQL'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('interpretation renders as removable context chips', (tester) async {
    final repo = ConfigurableRepo();
    await tester.pumpWidget(_wrap(GeneralSearchScreen(
      repository: repo,
      initialQuery: const SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: ['Ireland'],
      ),
    )));
    await tester.pumpAndSettle();

    // The resolved filter is shown as a chip with a remove affordance;
    // no schema/pipe string is present.
    expect(find.text('Ireland'), findsWidgets);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
    expect(find.textContaining('Driver:'), findsNothing);
    expect(find.textContaining('SEARCH_RALLIES'), findsNothing);
  });
}
