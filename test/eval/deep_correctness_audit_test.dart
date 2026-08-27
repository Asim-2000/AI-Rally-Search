// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Search Result Correctness & LLM Spec Audit', () {
    late DatabaseService db;
    late SearchRepository repo;

    setUpAll(() async {
      await dotenv.load(fileName: '.env');
      db = DatabaseService();
      repo = SearchRepository(dbService: db);
    });

    tearDownAll(() async {
      await db.close();
    });

    test('3B. Dual-Role Deep Audit', () async {
      print('\n================================================================');
      print('SECTION 3B: DUAL-ROLE PERSON AUDIT');
      print('================================================================');

      final dualRows = await db.query('''
        SELECT 
          d.full_name,
          d.driver_id, cd.codriver_id,
          (SELECT COUNT(DISTINCT sub_event_id) FROM rally_entry_list WHERE user_driver_id = d.driver_id) AS driver_events,
          (SELECT COUNT(DISTINCT sub_event_id) FROM rally_entry_list WHERE user_co_driver_id = cd.codriver_id) AS codriver_events
        FROM user_driver_profile d
        JOIN user_codriver_profile cd ON d.account_id = cd.account_id
        WHERE d.driver_id IN (SELECT user_driver_id FROM rally_entry_list)
          AND cd.codriver_id IN (SELECT user_co_driver_id FROM rally_entry_list)
        LIMIT 2;
      ''');

      for (final person in dualRows) {
        final name = person['full_name']?.toString() ?? '';
        final driverId = person['driver_id'];
        final codriverId = person['codriver_id'];

        print('\nAuditing Dual-Role Person: "$name"');
        print('  Driver ID: $driverId (Events: ${person['driver_events']})');
        print('  Co-Driver ID: $codriverId (Events: ${person['codriver_events']})');

        final rawDriverEvents = await db.query('''
          SELECT DISTINCT re.event_id, re.event_name, YEAR(re.start_date) as yr, 'driver' as role
          FROM rally_entry_list el
          JOIN rally_sub_events rse ON el.sub_event_id = rse.sub_event_id
          JOIN rally_events re ON rse.event_id = re.event_id
          WHERE el.user_driver_id = '$driverId'
        ''');

        final rawCodriverEvents = await db.query('''
          SELECT DISTINCT re.event_id, re.event_name, YEAR(re.start_date) as yr, 'codriver' as role
          FROM rally_entry_list el
          JOIN rally_sub_events rse ON el.sub_event_id = rse.sub_event_id
          JOIN rally_events re ON rse.event_id = re.event_id
          WHERE el.user_co_driver_id = '$codriverId'
        ''');

        final allEventMap = <String, Map<String, dynamic>>{};
        for (final r in rawDriverEvents) {
          allEventMap[r['event_id'].toString()] = r;
        }
        for (final r in rawCodriverEvents) {
          allEventMap[r['event_id'].toString()] = r;
        }

        print('  Raw Driver Distinct Events: ${rawDriverEvents.length}');
        print('  Raw Co-Driver Distinct Events: ${rawCodriverEvents.length}');
        print('  Raw Total Distinct Events: ${allEventMap.length}');

        // Repository check
        final repoAny = await repo.searchDriverRallies(SearchQuery(
          intent: SearchIntent.searchDriverRallies,
          driverName: name,
          personRole: PersonRole.any,
        ));
        final repoDriver = await repo.searchDriverRallies(SearchQuery(
          intent: SearchIntent.searchDriverRallies,
          driverName: name,
          personRole: PersonRole.driver,
        ));
        final repoCodriver = await repo.searchDriverRallies(SearchQuery(
          intent: SearchIntent.searchDriverRallies,
          driverName: name,
          personRole: PersonRole.coDriver,
        ));

        print('  Repo ANY Count: ${repoAny.totalCount}, Results: ${repoAny.results.length}');
        print('  Repo DRIVER Count: ${repoDriver.totalCount}, Results: ${repoDriver.results.length}');
        print('  Repo CODRIVER Count: ${repoCodriver.totalCount}, Results: ${repoCodriver.results.length}');

        final expectedAnyIds = allEventMap.keys.toSet();
        final expectedDriverIds = rawDriverEvents.map((r) => r['event_id'].toString()).toSet();
        final expectedCodriverIds = rawCodriverEvents.map((r) => r['event_id'].toString()).toSet();

        final actualAnyIds = repoAny.results.map((r) => r.rallyId).toSet();
        final actualDriverIds = repoDriver.results.map((r) => r.rallyId).toSet();
        final actualCodriverIds = repoCodriver.results.map((r) => r.rallyId).toSet();

        print('  ANY Diff - Missing: ${expectedAnyIds.difference(actualAnyIds)}, Extra: ${actualAnyIds.difference(expectedAnyIds)}');
        print('  DRIVER Diff - Missing: ${expectedDriverIds.difference(actualDriverIds)}, Extra: ${actualDriverIds.difference(expectedDriverIds)}');
        print('  CODRIVER Diff - Missing: ${expectedCodriverIds.difference(actualCodriverIds)}, Extra: ${actualCodriverIds.difference(expectedCodriverIds)}');
      }
    });

    test('6. Counts, Pagination & Sub-Event Deduplication Audit', () async {
      print('\n================================================================');
      print('SECTION 6: COUNTS, PAGINATION & SUB-EVENT DEDUPLICATION AUDIT');
      print('================================================================');

      // Test event with multiple sub-events
      final multiSubEvents = await db.query('''
        SELECT event_id, COUNT(sub_event_id) as sub_count
        FROM rally_sub_events
        GROUP BY event_id
        HAVING sub_count > 1
        LIMIT 5;
      ''');
      print('Events with multiple sub-events:');
      for (final r in multiSubEvents) {
        print('  Event ID: ${r['event_id']} (Sub-events: ${r['sub_count']})');
      }

      // Check count query vs results count for general rally search
      final qRallies = SearchQuery(intent: SearchIntent.searchRallies, limit: 10, offset: 0);
      final repoRallies = await repo.searchRallies(qRallies);
      print('\nsearchRallies pagination:');
      print('  totalCount: ${repoRallies.totalCount}, returned: ${repoRallies.results.length}, hasMore: ${repoRallies.hasMore}');

      // Check pagination page 2
      final qRalliesP2 = SearchQuery(intent: SearchIntent.searchRallies, limit: 10, offset: 10);
      final repoRalliesP2 = await repo.searchRallies(qRalliesP2);
      final page1Ids = repoRallies.results.map((r) => r.eventId).toSet();
      final page2Ids = repoRalliesP2.results.map((r) => r.eventId).toSet();
      final overlap = page1Ids.intersection(page2Ids);
      print('  Page 1 & 2 overlap: $overlap (Should be empty)');
    });

    test('7. Multi-Value Query Semantics Audit', () async {
      print('\n================================================================');
      print('SECTION 7: MULTI-VALUE QUERY SEMANTICS AUDIT');
      print('================================================================');

      // OR within dimension: driverNames
      final multiDriverQ = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman', 'Josh Moffett'],
        driverMatchMode: MatchMode.any,
      );
      final multiDriverRes = await repo.searchDriverRallies(multiDriverQ);
      print('OR Drivers ("Max Freeman" OR "Josh Moffett"): Found ${multiDriverRes.totalCount} rallies');

      // Multi-year within dimension
      final multiYearQ = SearchQuery(
        intent: SearchIntent.searchRallies,
        years: [2025, 2026],
      );
      final multiYearRes = await repo.searchRallies(multiYearQ);
      print('OR Years (2025 OR 2026): Found ${multiYearRes.totalCount} rallies');

      // Cross-dimension: Country + Year
      final crossQ = SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: ['Ireland'],
        years: [2025],
      );
      final crossRes = await repo.searchRallies(crossQ);
      print('AND Cross-dimension (Ireland AND 2025): Found ${crossRes.totalCount} rallies');
    });
  });
}
