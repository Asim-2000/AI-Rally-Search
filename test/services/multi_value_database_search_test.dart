import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
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
  });

  tearDownAll(() async {
    await dbService.close();
  });

  group('Multi-Value Database Search & SQL Semantics Tests', () {
    // 1. Multi-Action: jump OR drift
    test('1. Multi-Action: actionTypes = ["jump", "drift"] returns union of actions', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        limit: 20,
      );

      final response = await repository.searchVideoActions(query);
      expect(response.results, isNotEmpty);
      final actionTypesFound = response.results.map((a) => a.actionType.toLowerCase()).toSet();
      expect(actionTypesFound.every((a) => a.contains('jump') || a.contains('drift')), isTrue);
    });

    // 2. Multi-Country: Ireland OR United Kingdom
    test('2. Multi-Country: countries = ["Ireland", "United Kingdom"] in rally search', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: const ['Ireland', 'United Kingdom'],
        limit: 20,
      );

      final response = await repository.searchRallies(query);
      expect(response.results, isNotEmpty);
      for (final r in response.results) {
        final c = r.country?.toLowerCase() ?? '';
        expect(
          c.contains('ireland') || c.contains('ie') || c.contains('united kingdom') || c.contains('gb') || c.contains('scotland') || c.contains('wales'),
          isTrue,
        );
      }
    });

    // 3. Multi-Year: 2024 OR 2025
    test('3. Multi-Year: years = [2024, 2025]', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        years: const [2024, 2025],
        limit: 20,
      );

      final response = await repository.searchRallies(query);
      expect(response.results, isNotEmpty);
      for (final r in response.results) {
        expect(r.year == 2024 || r.year == 2025, isTrue, reason: 'Failed for ${r.eventName} with year ${r.year}');
      }
    });

    // 4. Year Range: yearFrom = 2023, yearTo = 2025
    test('4. Year Range: yearFrom = 2023, yearTo = 2025', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        yearFrom: 2023,
        yearTo: 2025,
        limit: 20,
      );

      final response = await repository.searchRallies(query);
      expect(response.results, isNotEmpty);
      for (final r in response.results) {
        expect(r.year, isNotNull);
        expect(r.year!, inInclusiveRange(2023, 2025));
      }
    });

    // 5. Multi-Rally: Moonraker OR Trackrod
    test('5. Multi-Rally: rallyNames = ["Moonraker", "Trackrod"]', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyNames: const ['Moonraker', 'Trackrod'],
        limit: 20,
      );

      final response = await repository.searchRallies(query);
      expect(response.results, isNotEmpty);
      for (final r in response.results) {
        final name = r.eventName.toLowerCase();
        expect(name.contains('moonraker') || name.contains('trackrod'), isTrue);
      }
    });

    // 6. Multi-Driver ANY: Josh Moffett OR Sam Moffett participations
    test('6. Multi-Driver ANY: driverNames = ["Josh Moffett", "Sam Moffett"] with MatchMode.any', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: const ['Josh Moffett', 'Sam Moffett'],
        driverMatchMode: MatchMode.any,
        limit: 20,
      );

      final response = await repository.searchDriverRallies(query);
      expect(response.results, isNotEmpty);
      for (final r in response.results) {
        final d = r.driverName?.toLowerCase() ?? '';
        expect(d.contains('josh') || d.contains('sam') || d.contains('moffett'), isTrue);
      }
    });

    // 7. Multi-Driver ALL vs ANY: Prove live DB difference between ANY and ALL semantics
    test('7. Multi-Driver ALL vs ANY: Explicitly proves MatchMode.any vs MatchMode.all difference on live DB', () async {
      final queryAny = SearchQuery(
        intent: SearchIntent.searchRallies,
        driverNames: const ['Josh Moffett', 'Philip Squires'],
        driverMatchMode: MatchMode.any,
        limit: 50,
      );

      final queryAll = SearchQuery(
        intent: SearchIntent.searchRallies,
        driverNames: const ['Josh Moffett', 'Philip Squires'],
        driverMatchMode: MatchMode.all,
        limit: 50,
      );

      final responseAny = await repository.searchRallies(queryAny);
      final responseAll = await repository.searchRallies(queryAll);

      // ANY returns the union of rallies where either Josh or Philip participated (e.g. Ireland + UK rallies)
      expect(responseAny.results, isNotEmpty);
      expect(responseAny.totalCount, greaterThan(0));

      // ALL requires events where BOTH drivers competed simultaneously
      expect(responseAny.totalCount, greaterThan(responseAll.totalCount));
      print('Live DB ANY vs ALL comparison: ANY count = ${responseAny.totalCount}, ALL count = ${responseAll.totalCount}');
    });

    // 8. 3+ Dimensions Simultaneously: (jump OR drift) AND (Ireland OR United Kingdom) AND (2024 OR 2025)
    test('8. 3+ Dimensions: actionTypes + countries + years combined', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        countries: const ['Ireland', 'United Kingdom'],
        years: const [2024, 2025],
        limit: 20,
      );

      final response = await repository.searchVideoActions(query);
      expect(response.results, isNotEmpty);
      for (final a in response.results) {
        expect(a.actionType.toLowerCase().contains('jump') || a.actionType.toLowerCase().contains('drift'), isTrue);
      }
    });

    // 9. Pagination & Deduplication Stability: Distinct results across pages
    test('9. Pagination & Deduplication: No duplicate records returned on multi-value joins', () async {
      final queryP1 = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        countries: const ['Ireland', 'United Kingdom'],
        limit: 5,
        offset: 0,
      );

      final queryP2 = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        countries: const ['Ireland', 'United Kingdom'],
        limit: 5,
        offset: 5,
      );

      final p1 = await repository.searchVideoActions(queryP1);
      final p2 = await repository.searchVideoActions(queryP2);

      final p1Ids = p1.results.map((a) => a.id).toSet();
      final p2Ids = p2.results.map((a) => a.id).toSet();

      // Ensure no duplicates within page 1 or page 2
      expect(p1Ids.length, equals(p1.results.length));
      expect(p2Ids.length, equals(p2.results.length));
      // Ensure zero overlap between page 1 and page 2
      expect(p1Ids.intersection(p2Ids), isEmpty);
    });

    // 10. Zero results handled cleanly without error
    test('10. Zero results for impossible multi-value filter returns empty list and count 0', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: const ['NonexistentCountry123'],
        years: const [1901],
      );

      final response = await repository.searchRallies(query);
      expect(response.results, isEmpty);
      expect(response.totalCount, equals(0));
    });

    // 11. Pagination Determinism: 3-page pagination and count consistency
    test('11. Pagination Determinism: Page 1, 2, 3 have disjoint canonical IDs and count matches total unique IDs', () async {
      const pageSize = 5;
      final qPage1 = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        limit: pageSize,
        offset: 0,
      );
      final qPage2 = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        limit: pageSize,
        offset: pageSize,
      );
      final qPage3 = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        limit: pageSize,
        offset: pageSize * 2,
      );
      final qTotal = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        limit: 100,
        offset: 0,
      );

      final res1 = await repository.searchVideoActions(qPage1);
      final res2 = await repository.searchVideoActions(qPage2);
      final res3 = await repository.searchVideoActions(qPage3);
      final resTotal = await repository.searchVideoActions(qTotal);

      final ids1 = res1.results.map((a) => a.id).toList();
      final ids2 = res2.results.map((a) => a.id).toList();
      final ids3 = res3.results.map((a) => a.id).toList();

      // Ensure each page has distinct IDs
      expect(ids1.toSet().length, equals(ids1.length));
      expect(ids2.toSet().length, equals(ids2.length));
      expect(ids3.toSet().length, equals(ids3.length));

      // Ensure no overlap across pages
      expect(ids1.toSet().intersection(ids2.toSet()), isEmpty);
      expect(ids2.toSet().intersection(ids3.toSet()), isEmpty);
      expect(ids1.toSet().intersection(ids3.toSet()), isEmpty);

      // Verify totalCount query equals the count returned by all queries
      expect(res1.totalCount, equals(res2.totalCount));
      expect(res2.totalCount, equals(res3.totalCount));
      expect(res3.totalCount, equals(resTotal.totalCount));

      // Verify ordering consistency with large limit
      final combinedPaginatedIds = [...ids1, ...ids2, ...ids3];
      final totalSliceIds = resTotal.results.take(combinedPaginatedIds.length).map((a) => a.id).toList();
      expect(combinedPaginatedIds, equals(totalSliceIds));
    });
  });
}
