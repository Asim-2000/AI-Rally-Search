import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/widgets/driver_participation_card.dart';

class SingleRallyRepo implements ISearchRepository {
  final String eventName;
  SingleRallyRepo(this.eventName);

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    return SearchResponse<RallySearchResult>(
      intent: SearchIntent.searchRallies,
      results: [
        RallySearchResult(
          eventId: 'e-1',
          eventName: eventName,
          country: 'Ireland',
          city: 'Letterkenny',
          stagesCount: 14,
          status: 'active',
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

void main() {
  void setNarrow(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('participation card shows compact P1 · Winner copy', (tester) async {
    final part = RallyParticipationResult(
      rallyId: 'r-1',
      eventName: 'Donegal International Rally 2025',
      driverName: 'Josh Moffett',
      carNumber: '1',
      make: 'Hyundai i20 R5',
      posOverall: 1,
      totalTime: '3600.5',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DriverParticipationCard(participation: part)),
    ));

    expect(find.text('P1 · Winner'), findsOneWidget);
    expect(find.textContaining('1st Place (Winner)'), findsNothing);
  });

  testWidgets('search home renders without overflow at 320px, both voice modes visible', (tester) async {
    setNarrow(tester, 320);
    await tester.pumpWidget(MaterialApp(
      home: GeneralSearchScreen(repository: SingleRallyRepo('Rally X')),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cloud voice'), findsOneWidget);
    expect(find.text('On-device voice'), findsOneWidget);
  });

  testWidgets('long rally title renders without overflow at 320px', (tester) async {
    setNarrow(tester, 320);
    await tester.pumpWidget(MaterialApp(
      home: GeneralSearchScreen(
        repository: SingleRallyRepo(
          'Swift Signs & Shirts Yorkshire Dales International Rally Championship 2026',
        ),
        initialQuery: const SearchQuery(intent: SearchIntent.searchRallies),
      ),
    ));
    await tester.pumpAndSettle();

    // Results rendered and no layout overflow was thrown.
    expect(tester.takeException(), isNull);
    expect(find.byType(GeneralSearchScreen), findsOneWidget);
  });
}
