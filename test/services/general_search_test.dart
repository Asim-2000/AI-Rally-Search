// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late SearchRepository repository;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    dbService = DatabaseService();
    repository = SearchRepository(dbService: dbService);
    await dbService.connect();
  });

  tearDownAll(() async {
    await dbService.close();
  });

  group('General Search Integration Tests across all 9 Search Intents', () {
    // 1. Search rallies by country
    test('1. SEARCH_RALLIES: "Rallies in Ireland" returns valid RallySearchResult list', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchRallies,
        country: 'Ireland',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchRallies));
      expect(response.results, isA<List<RallySearchResult>>());
      expect(response.totalCount, greaterThan(0));

      final rallies = response.results.cast<RallySearchResult>();
      print('\nRallies in Ireland count: ${rallies.length}');
      for (final r in rallies.take(3)) {
        print('  • ${r.eventName} (${r.formattedLocation}), ${r.stagesCount} stages');
        expect(r.eventName, isNotEmpty);
        expect(r.eventId, isNotEmpty);
      }
    });

    // 2. Search rallies by city
    test('2. SEARCH_RALLIES: "Rallies in Donegal / Letterkenny" matches specific city', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchRallies,
        city: 'Letterkenny',
      );

      final response = await repository.searchRallies(query);
      expect(response.results, isNotEmpty);
      for (final r in response.results) {
        expect(r.city?.toLowerCase(), contains('letterkenny'));
      }
    });

    // 3. Search rallies by year
    test('3. SEARCH_RALLIES: "Rallies from 2025" filters events by year', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchRallies,
        year: 2025,
      );

      final response = await repository.searchRallies(query);
      expect(response.results, isNotEmpty);
      for (final r in response.results) {
        print('  Event: ${r.eventName}, start: ${r.startDate}, end: ${r.endDate}, parsedYear: ${r.year}');
        expect(
          r.year == 2025 || (r.startDate != null && r.startDate!.year == 2025) || (r.endDate != null && r.endDate!.year == 2025),
          isTrue,
        );
      }
    });


    // 4. Search driver rallies (participation)
    test('4. SEARCH_DRIVER_RALLIES: "Rallies Driver X participated in" returns participation records', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverName: 'Josh Moffett',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchDriverRallies));
      expect(response.results, isA<List<RallyParticipationResult>>());
      expect(response.totalCount, greaterThan(0));

      final participations = response.results.cast<RallyParticipationResult>();
      print('\nJosh Moffett participations count: ${participations.length}');
      for (final p in participations) {
        print('  • ${p.eventName}: ${p.driverName} - ${p.finishPositionDisplay}');
        expect(p.driverName.toLowerCase(), contains('moffett'));
        expect(p.eventName, isNotEmpty);
      }
    });

    // 5. Search driver wins
    test('5. SEARCH_DRIVER_WINS: "Rallies Driver X won" returns only 1st place finishes on final stage', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchDriverWins,
        driverName: 'Josh Moffett',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchDriverWins));
      expect(response.results, isA<List<RallyParticipationResult>>());

      final wins = response.results.cast<RallyParticipationResult>();
      print('\nJosh Moffett won events: ${wins.length}');
      for (final w in wins) {
        print('  • 🏆 ${w.eventName}: ${w.driverName} (Pos: ${w.posOverall}, Time: ${w.totalTime}s)');
        expect(w.posOverall, equals(1));
      }
    });

    // 6. Get first-place finisher / winner of a rally
    test('6. GET_RALLY_RESULTS: "Winner of Rally X" returns first-place result on final classification', () async {
      const query = SearchQuery(
        intent: SearchIntent.getRallyResults,
        rallyName: 'Moonraker Forestry Rally',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.getRallyResults));
      expect(response.results, isA<List<RallyResult>>());
      expect(response.results.length, equals(1));

      final winner = response.results.cast<RallyResult>().first;
      print('\nWinner of Moonraker Rally: ${winner.positionBadge} ${winner.driverName} (Time: ${winner.totalTime}s)');
      expect(winner.posOverall, equals(1));
      expect(winner.driverName, isNotEmpty);
    });

    // 7. Get top 10 finishers of a rally (Leaderboard)
    test('7. GET_RALLY_TOP_FINISHERS: "Top 10 finishers of Rally X" returns ranked classification table', () async {
      const query = SearchQuery(
        intent: SearchIntent.getRallyTopFinishers,
        rallyName: 'Moonraker Forestry Rally',
        limit: 10,
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.getRallyTopFinishers));
      expect(response.results, isA<List<RallyResult>>());

      final finishers = response.results.cast<RallyResult>();
      expect(finishers.length, greaterThanOrEqualTo(3));
      print('\nMoonraker Rally Top Finishers:');
      for (int i = 0; i < finishers.length; i++) {
        final f = finishers[i];
        print('  ${f.posOverall}. ${f.driverName} #${f.carNumber ?? ""} (${f.make ?? ""}) - ${f.totalTime}s');
        expect(f.posOverall, equals(i + 1));
      }
    });

    // 8. Search video action highlights for a rally
    test('8. SEARCH_VIDEO_ACTIONS: "Jump highlights from Rally X" returns playable VideoAction moments', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'drift',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchVideoActions));
      expect(response.results, isA<List<VideoAction>>());
      expect(response.totalCount, greaterThan(0));

      final actions = response.results.cast<VideoAction>();
      final first = actions.first;
      print('\nAction Moment: ${first.title} (${first.formattedDuration}), Stream URL: ${first.videoUrl}');
      expect(first.videoUrl, isNotNull);
      expect(first.duration, greaterThan(0));
    });

    // 9. Search videos featuring a driver
    test('9. SEARCH_DRIVER_VIDEOS: "Videos featuring Driver X" uses explicit database links', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverName: 'Philip Squires',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchDriverVideos));
      expect(response.results, isA<List<VideoSearchResult>>());
      expect(response.totalCount, greaterThan(0));

      final vids = response.results.cast<VideoSearchResult>();
      for (final v in vids) {
        print('  • Video #${v.videoId} featuring ${v.driverName} in ${v.eventName} (${v.stageName})');
        expect(v.driverName?.toLowerCase(), contains('squires'));
        expect(v.videoUrl, isNotNull);
      }
    });

    // 10. Get top uploaders
    test('10. GET_TOP_UPLOADERS: "Top uploaders" returns ranked contributors by upload count', () async {
      const query = SearchQuery(
        intent: SearchIntent.getTopUploaders,
        limit: 5,
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.getTopUploaders));
      expect(response.results, isA<List<UploaderSearchResult>>());
      expect(response.totalCount, greaterThan(0));

      final uploaders = response.results.cast<UploaderSearchResult>();
      print('\nTop Uploaders:');
      for (int i = 0; i < uploaders.length; i++) {
        final u = uploaders[i];
        print('  #${i + 1} ${u.uploaderName}: ${u.uploadCount} uploads');
        expect(u.uploadCount, greaterThan(0));
      }
    });

    // 11. Get drivers with most career wins
    test('11. GET_TOP_DRIVERS_BY_WINS: "Drivers with most wins" returns career winners leaderboard (1 win per event)', () async {
      const query = SearchQuery(
        intent: SearchIntent.getTopDriversByWins,
        limit: 5,
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.getTopDriversByWins));
      expect(response.results, isA<List<DriverWinResult>>());
      expect(response.totalCount, greaterThan(0));

      final winners = response.results.cast<DriverWinResult>();
      print('\nDrivers with Most Wins:');
      for (int i = 0; i < winners.length; i++) {
        final w = winners[i];
        print('  #${i + 1} ${w.driverName}: ${w.winCount} wins (Latest: ${w.latestRallyWon})');
        expect(w.winCount, greaterThanOrEqualTo(1));
      }
    });

    // 12. Empty results handling
    test('12. Empty results for non-matching criteria returns empty list without error', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchRallies,
        country: 'NonExistentCountryXYZ999',
      );

      final response = await repository.search(query);
      expect(response.results, isEmpty);
      expect(response.totalCount, equals(0));
      expect(response.hasMore, isFalse);
    });

    // 13. Pagination works deterministically
    test('13. Pagination: limit & offset work deterministically', () async {
      const page1Query = SearchQuery(
        intent: SearchIntent.searchRallies,
        limit: 3,
        offset: 0,
      );
      const page2Query = SearchQuery(
        intent: SearchIntent.searchRallies,
        limit: 3,
        offset: 3,
      );

      final p1 = await repository.searchRallies(page1Query);
      final p2 = await repository.searchRallies(page2Query);

      expect(p1.results.length, equals(3));
      expect(p2.results.length, equals(3));
      expect(p1.results.first.eventId, isNot(equals(p2.results.first.eventId)));
    });
  });

  group('Compound / Multi-Constraint Search Integration Tests', () {
    // 1. Country + Year: "Show rallies in Ireland in 2025"
    test('1. Compound: Country + Year (Ireland + 2025)', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchRallies,
        country: 'Ireland',
        year: 2025,
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchRallies));
      expect(response.results, isA<List<RallySearchResult>>());
      expect(response.results, isNotEmpty);

      final rallies = response.results.cast<RallySearchResult>();
      print('\nRallies in Ireland in 2025: ${rallies.length}');
      for (final r in rallies) {
        expect(r.country?.toLowerCase(), contains('ireland'));
        expect(
          r.year == 2025 || (r.startDate != null && r.startDate!.year == 2025) || (r.endDate != null && r.endDate!.year == 2025),
          isTrue,
        );
      }
    });

    // 2. Country + Driver: "Show rallies in Ireland where Josh Moffett participated"
    test('2. Compound: Country + Driver (Ireland + Josh Moffett)', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        country: 'Ireland',
        driverName: 'Josh Moffett',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchDriverRallies));
      expect(response.results, isA<List<RallyParticipationResult>>());
      expect(response.results, isNotEmpty);

      final participations = response.results.cast<RallyParticipationResult>();
      print('\nJosh Moffett participations in Ireland: ${participations.length}');
      for (final p in participations) {
        expect(p.country?.toLowerCase(), contains('ireland'));
        expect(p.driverName.toLowerCase(), contains('moffett'));
      }
    });

    // 3. Country + Year + Driver: "Show rallies in Ireland in 2026 where Josh Moffett participated"
    test('3. Compound: Country + Year + Driver (Ireland + 2026 + Josh Moffett)', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        country: 'Ireland',
        year: 2026,
        driverName: 'Josh Moffett',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchDriverRallies));
      expect(response.results, isA<List<RallyParticipationResult>>());
      expect(response.results, isNotEmpty);

      final participations = response.results.cast<RallyParticipationResult>();
      print('\nJosh Moffett participations in Ireland in 2026: ${participations.length}');
      for (final p in participations) {
        expect(p.country?.toLowerCase(), contains('ireland'));
        expect(p.driverName.toLowerCase(), contains('moffett'));
        expect(p.startDate?.year, equals(2026));
      }
    });

    // 4. Event + Action: "Show drift highlights from Get Jerky Rally North Wales"
    test('4. Compound: Event + Action (Get Jerky + drift)', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        eventName: 'Get Jerky',
        actionType: 'drift',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchVideoActions));
      expect(response.results, isA<List<VideoAction>>());
      expect(response.results, isNotEmpty);

      final actions = response.results.cast<VideoAction>();
      print('\nDrift highlights in Get Jerky: ${actions.length}');
      for (final a in actions) {
        expect(a.actionType.toLowerCase(), contains('drift'));
        expect(a.eventName?.toLowerCase(), contains('get jerky'));
      }
    });

    // 5. Event + Action + Driver: "Show drift highlights featuring Philip Squires from Get Jerky Rally North Wales"
    test('5. Compound: Event + Action + Driver (Get Jerky + drift + Philip Squires)', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        eventName: 'Get Jerky',
        actionType: 'drift',
        driverName: 'Philip Squires',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchVideoActions));
      expect(response.results, isA<List<VideoAction>>());

      final actions = response.results.cast<VideoAction>();
      print('\nPhilip Squires drift highlights in Get Jerky: ${actions.length}');
      for (final a in actions) {
        expect(a.actionType.toLowerCase(), contains('drift'));
        expect(a.eventName?.toLowerCase(), contains('get jerky'));
        expect(a.driverName?.toLowerCase(), contains('squires'));
      }
    });

    // 6. Event + Stage + Action: "Show drift highlights from Trackrod Rally 2024 Stage Gale Rigg"
    test('6. Compound: Event + Stage + Action (Trackrod + Gale Rigg + drift)', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        eventName: 'Trackrod Rally',
        stageName: 'Gale Rigg',
        actionType: 'drift',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchVideoActions));
      expect(response.results, isA<List<VideoAction>>());
      expect(response.results, isNotEmpty);

      final actions = response.results.cast<VideoAction>();
      print('\nTrackrod Gale Rigg drift highlights: ${actions.length}');
      for (final a in actions) {
        expect(a.actionType.toLowerCase(), contains('drift'));
        expect(a.eventName?.toLowerCase(), contains('trackrod'));
        expect(a.stageName?.toLowerCase(), contains('gale rigg'));
      }
    });


    // 7. Driver + Year: "Show rallies won by Josh Moffett in 2026"
    test('7. Compound: Driver + Year (Josh Moffett + 2026 Wins)', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchDriverWins,
        driverName: 'Josh Moffett',
        year: 2026,
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchDriverWins));
      expect(response.results, isA<List<RallyParticipationResult>>());
      expect(response.results, isNotEmpty);

      final wins = response.results.cast<RallyParticipationResult>();
      print('\nJosh Moffett 2026 wins: ${wins.length}');
      for (final w in wins) {
        expect(w.driverName.toLowerCase(), contains('moffett'));
        expect(w.posOverall, equals(1));
        expect(w.startDate?.year, equals(2026));
      }
    });

    // 8. Empty compound results
    test('8. Compound: Empty results for contradictory criteria returns gracefully', () async {
      const query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        country: 'Ireland',
        year: 1950,
        driverName: 'Josh Moffett',
      );

      final response = await repository.search(query);
      expect(response.intent, equals(SearchIntent.searchDriverRallies));
      expect(response.results, isEmpty);
      expect(response.totalCount, equals(0));
      expect(response.hasMore, isFalse);
    });
  });
}

