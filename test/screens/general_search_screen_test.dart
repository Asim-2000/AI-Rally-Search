import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/widgets/driver_participation_card.dart';
import 'package:ai_rally_search/widgets/driver_wins_leaderboard.dart';
import 'package:ai_rally_search/widgets/rally_leaderboard.dart';
import 'package:ai_rally_search/widgets/rally_result_card.dart';
import 'package:ai_rally_search/widgets/uploader_leaderboard.dart';

class FakeSearchRepository implements ISearchRepository {
  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    return SearchResponse<RallySearchResult>(
      intent: SearchIntent.searchRallies,
      results: [
        RallySearchResult(
          eventId: 'e-1',
          eventName: 'Rally Ireland 2026',
          country: 'Ireland',
          city: 'Letterkenny',
          stagesCount: 8,
          startDate: DateTime(2026, 9, 12),
        ),
      ],
      totalCount: 1,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) async {
    return (await search(query)) as SearchResponse<RallySearchResult>;
  }

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Result Views Widget Unit Tests', () {
    testWidgets('RallyResultCard renders event details properly', (tester) async {
      final rally = RallySearchResult(
        eventId: 'e-1',
        eventName: 'Rally Ireland 2026',
        country: 'Ireland',
        city: 'Letterkenny',
        stagesCount: 8,
        startDate: DateTime(2026, 9, 12),
        endDate: DateTime(2026, 9, 14),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RallyResultCard(rally: rally),
          ),
        ),
      );

      expect(find.text('Rally Ireland 2026'), findsOneWidget);
      expect(find.text('Letterkenny, Ireland'), findsOneWidget);
      expect(find.text('8 stages'), findsOneWidget);
    });

    testWidgets('DriverParticipationCard renders win and place badges', (tester) async {
      final participation = RallyParticipationResult(
        rallyId: 'r-1',
        eventName: 'Moonraker Forestry Rally 2026',
        driverName: 'Josh Moffett',
        crew: 'Moffett Josh / Hayes Andy',
        carNumber: '5',
        make: 'Hyundai i20 R5',
        posOverall: 1,
        totalTime: '2325.8',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverParticipationCard(participation: participation),
          ),
        ),
      );

      expect(find.text('Moonraker Forestry Rally 2026'), findsOneWidget);
      expect(find.text('Josh Moffett'), findsOneWidget);
      expect(find.text('🏆 1st Place (Winner)'), findsOneWidget);
      expect(find.text('2325.8s'), findsOneWidget);
    });

    testWidgets('RallyLeaderboard renders top finishers in rank order', (tester) async {
      final results = [
        const RallyResult(
          id: 1,
          rallyId: 'r-1',
          eventName: 'Moonraker Rally',
          driverName: 'Josh Moffett',
          carNumber: '5',
          make: 'Hyundai i20 R5',
          posOverall: 1,
          totalTime: '2325.8',
        ),
        const RallyResult(
          id: 2,
          rallyId: 'r-1',
          eventName: 'Moonraker Rally',
          driverName: 'Jordan Hone',
          carNumber: '3',
          make: 'Škoda Fabia Rally2',
          posOverall: 2,
          totalTime: '2328.9',
          diffLeader: '3.1',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RallyLeaderboard(results: results),
            ),
          ),
        ),
      );

      expect(find.text('Moonraker Rally'), findsOneWidget);
      expect(find.text('Josh Moffett'), findsOneWidget);
      expect(find.text('Jordan Hone'), findsOneWidget);
      expect(find.text('+3.1'), findsOneWidget);
      expect(find.text('2 finishers'), findsOneWidget);
    });

    testWidgets('UploaderLeaderboard renders ranked contributors', (tester) async {
      final uploaders = [
        const UploaderSearchResult(
          uploaderId: 'u-1',
          uploaderName: 'SuperFan2026',
          uploadCount: 42,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UploaderLeaderboard(uploaders: uploaders),
            ),
          ),
        ),
      );

      expect(find.text('SuperFan2026'), findsOneWidget);
      expect(find.text('42 vids'), findsOneWidget);
    });

    testWidgets('DriverWinsLeaderboard renders career victories list', (tester) async {
      final winners = [
        const DriverWinResult(
          driverName: 'Josh Moffett',
          winCount: 12,
          country: 'Ireland',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
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

  group('GeneralSearchScreen Widget Smoke Tests', () {
    testWidgets('Renders search controls and filters and results', (tester) async {
      final fakeRepo = FakeSearchRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: GeneralSearchScreen(
            repository: fakeRepo,
            initialQuery: const SearchQuery(
              intent: SearchIntent.searchRallies,
              country: 'Ireland',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Rally Search'), findsOneWidget);
      expect(find.text('Search Query Intent'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Rally Ireland 2026'), findsOneWidget);
    });
  });
}

