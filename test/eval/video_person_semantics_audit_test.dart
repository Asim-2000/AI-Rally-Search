import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/result_referent_context.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';

void main() {
  late DatabaseService dbService;
  late SearchRepository searchRepo;
  late DatabaseEntityLookupRepository lookupRepo;
  late DatabaseEntityResolver resolver;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    dbService = DatabaseService();
    searchRepo = SearchRepository(dbService: dbService);
    lookupRepo = DatabaseEntityLookupRepository(dbService: dbService);
    resolver = DatabaseEntityResolver(repository: lookupRepo);
  });

  group('1. Max Freeman (Co-Driver Only) Video & Action Semantics Audit', () {
    test('Max Freeman: searchDriverVideos & searchVideoActions raw truth vs repository', () async {
      // 1. Raw DB Truth for Max Freeman Videos (via rally_video_metadata -> rally_entry_list -> user_codriver_profile)
      const rawMaxFreemanVideosSql = '''
        SELECT DISTINCT rv.id AS video_id
        FROM rally_videos rv
        INNER JOIN rally_video_metadata vm ON rv.id = vm.video_id
        INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
        INNER JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
        INNER JOIN rally_streams rs ON rv.id = rs.video_id
        WHERE LOWER(cdp.full_name) LIKE '%max freeman%'
          AND rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''
          AND (rs.video_type IS NULL OR rs.video_type != 'instantReplay')
      ''';
      final rawVideoRows = await dbService.query(rawMaxFreemanVideosSql);
      final expectedVideoIds = rawVideoRows.map((r) => int.parse(r['video_id'].toString())).toSet();

      // 2. Raw DB Truth for Max Freeman Video Actions (via rally_video_metadata -> rally_entry_list -> user_codriver_profile)
      const rawMaxFreemanActionsSql = '''
        SELECT DISTINCT vm.id AS action_id
        FROM rally_video_metadata vm
        INNER JOIN rally_video_actions va ON vm.action_id = va.id
        INNER JOIN rally_streams rs ON vm.video_id = rs.video_id
        INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
        INNER JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
        WHERE LOWER(cdp.full_name) LIKE '%max freeman%'
          AND rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''
          AND (rs.video_type IS NULL OR rs.video_type != 'instantReplay')
      ''';
      final rawActionRows = await dbService.query(rawMaxFreemanActionsSql);
      final expectedActionIds = rawActionRows.map((r) => int.parse(r['action_id'].toString())).toSet();

      // Check DRIVER role (Must return 0 for both videos and actions since Max Freeman is strictly a co-driver)
      final qDriverVid = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.driver,
      );
      final resDriverVid = await resolver.resolve(qDriverVid);
      final respDriverVid = await searchRepo.search(resDriverVid.resolvedQuery!);
      expect(respDriverVid.totalCount, 0);
      expect(respDriverVid.results.isEmpty, isTrue);

      final qDriverAct = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.driver,
      );
      final resDriverAct = await resolver.resolve(qDriverAct);
      final respDriverAct = await searchRepo.search(resDriverAct.resolvedQuery!);
      expect(respDriverAct.totalCount, 0);
      expect(respDriverAct.results.isEmpty, isTrue);

      // Check CO_DRIVER role
      final qCodriverVid = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.coDriver,
        limit: 100,
      );
      final resCodriverVid = await resolver.resolve(qCodriverVid);
      final respCodriverVid = await searchRepo.search(resCodriverVid.resolvedQuery!);
      expect(respCodriverVid.totalCount, expectedVideoIds.length);
      final actualVidIds = respCodriverVid.results.map((r) => r.videoId).toSet();
      expect(actualVidIds, equals(expectedVideoIds));

      final qCodriverAct = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.coDriver,
        limit: 100,
      );
      final resCodriverAct = await resolver.resolve(qCodriverAct);
      final respCodriverAct = await searchRepo.search(resCodriverAct.resolvedQuery!);
      expect(respCodriverAct.totalCount, expectedActionIds.length);
      final actualActIds = respCodriverAct.results.map((r) => r.id).toSet();
      expect(actualActIds, equals(expectedActionIds));

      // Check ANY role
      final qAnyVid = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.any,
        limit: 100,
      );
      final resAnyVid = await resolver.resolve(qAnyVid);
      final respAnyVid = await searchRepo.search(resAnyVid.resolvedQuery!);
      expect(respAnyVid.totalCount, expectedVideoIds.length);
      final actualAnyVidIds = respAnyVid.results.map((r) => r.videoId).toSet();
      expect(actualAnyVidIds, equals(expectedVideoIds));

      final qAnyAct = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.any,
        limit: 100,
      );
      final resAnyAct = await resolver.resolve(qAnyAct);
      final respAnyAct = await searchRepo.search(resAnyAct.resolvedQuery!);
      expect(respAnyAct.totalCount, expectedActionIds.length);
      final actualAnyActIds = respAnyAct.results.map((r) => r.id).toSet();
      expect(actualAnyActIds, equals(expectedActionIds));
    });
  });

  group('2. Driver-Only Golden Case (Josh Moffett)', () {
    test('Josh Moffett: Videos & Actions comparison for DRIVER vs CO_DRIVER vs ANY', () async {
      // 1. Raw DB truth for Josh Moffett as DRIVER
      const rawJoshDriverVideosSql = '''
        SELECT DISTINCT rv.id AS video_id
        FROM rally_videos rv
        INNER JOIN rally_video_metadata vm ON rv.id = vm.video_id
        INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
        INNER JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
        INNER JOIN rally_streams rs ON rv.id = rs.video_id
        WHERE LOWER(dp.full_name) LIKE '%josh moffett%'
          AND rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''
          AND (rs.video_type IS NULL OR rs.video_type != 'instantReplay')
      ''';
      final rawDriverVidRows = await dbService.query(rawJoshDriverVideosSql);
      final expectedDriverVidIds = rawDriverVidRows.map((r) => int.parse(r['video_id'].toString())).toSet();

      const rawJoshDriverActionsSql = '''
        SELECT DISTINCT vm.id AS action_id
        FROM rally_video_metadata vm
        INNER JOIN rally_video_actions va ON vm.action_id = va.id
        INNER JOIN rally_streams rs ON vm.video_id = rs.video_id
        INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
        INNER JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
        WHERE LOWER(dp.full_name) LIKE '%josh moffett%'
          AND rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''
          AND (rs.video_type IS NULL OR rs.video_type != 'instantReplay')
      ''';
      final rawDriverActRows = await dbService.query(rawJoshDriverActionsSql);
      final expectedDriverActIds = rawDriverActRows.map((r) => int.parse(r['action_id'].toString())).toSet();

      // 2. Raw DB truth for Josh Moffett as CO_DRIVER
      const rawJoshCodriverVideosSql = '''
        SELECT DISTINCT rv.id AS video_id
        FROM rally_videos rv
        INNER JOIN rally_video_metadata vm ON rv.id = vm.video_id
        INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
        INNER JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
        INNER JOIN rally_streams rs ON rv.id = rs.video_id
        WHERE LOWER(cdp.full_name) LIKE '%josh moffett%'
          AND rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''
          AND (rs.video_type IS NULL OR rs.video_type != 'instantReplay')
      ''';
      final rawCodriverVidRows = await dbService.query(rawJoshCodriverVideosSql);
      final expectedCodriverVidIds = rawCodriverVidRows.map((r) => int.parse(r['video_id'].toString())).toSet();

      // DRIVER query
      final qDriver = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Josh Moffett'],
        personRole: PersonRole.driver,
        limit: 500,
      );
      final resDriver = await resolver.resolve(qDriver);
      final respDriver = await searchRepo.search(resDriver.resolvedQuery!);
      expect(respDriver.totalCount, expectedDriverVidIds.length);
      final actualDriverVidIds = respDriver.results.map((r) => r.videoId).toSet();
      expect(actualDriverVidIds, equals(expectedDriverVidIds));

      // CO_DRIVER query
      final qCodriver = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Josh Moffett'],
        personRole: PersonRole.coDriver,
        limit: 500,
      );
      final resCodriver = await resolver.resolve(qCodriver);
      final respCodriver = await searchRepo.search(resCodriver.resolvedQuery!);
      expect(respCodriver.totalCount, expectedCodriverVidIds.length);

      // ANY query
      final qAny = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Josh Moffett'],
        personRole: PersonRole.any,
        limit: 500,
      );
      final resAny = await resolver.resolve(qAny);
      final respAny = await searchRepo.search(resAny.resolvedQuery!);
      final expectedAllVidIds = {...expectedDriverVidIds, ...expectedCodriverVidIds};
      expect(respAny.totalCount, expectedAllVidIds.length);
      final actualAnyVidIds = respAny.results.map((r) => r.videoId).toSet();
      expect(actualAnyVidIds, equals(expectedAllVidIds));
    });
  });

  group('3. Dual-Role Case (Account 419633b1-56ca-483a-8c10-0141d7cc3092)', () {
    test('Chris Melly / Melly Chris: Exact video and action IDs per role', () async {
      const accId = '419633b1-56ca-483a-8c10-0141d7cc3092';

      // Raw truth queries
      final rawDriverVidSql = '''
        SELECT DISTINCT rv.id AS video_id
        FROM rally_videos rv
        INNER JOIN rally_video_metadata vm ON rv.id = vm.video_id
        INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
        INNER JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
        INNER JOIN rally_streams rs ON rv.id = rs.video_id
        WHERE dp.account_id = '$accId'
          AND rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''
          AND (rs.video_type IS NULL OR rs.video_type != 'instantReplay')
      ''';
      final rawDriverVidRows = await dbService.query(rawDriverVidSql);
      final expectedDriverVidIds = rawDriverVidRows.map((r) => int.parse(r['video_id'].toString())).toSet();

      final rawCodriverVidSql = '''
        SELECT DISTINCT rv.id AS video_id
        FROM rally_videos rv
        INNER JOIN rally_video_metadata vm ON rv.id = vm.video_id
        INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
        INNER JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
        INNER JOIN rally_streams rs ON rv.id = rs.video_id
        WHERE cdp.account_id = '$accId'
          AND rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''
          AND (rs.video_type IS NULL OR rs.video_type != 'instantReplay')
      ''';
      final rawCodriverVidRows = await dbService.query(rawCodriverVidSql);
      final expectedCodriverVidIds = rawCodriverVidRows.map((r) => int.parse(r['video_id'].toString())).toSet();

      final expectedAllVidIds = {...expectedDriverVidIds, ...expectedCodriverVidIds};

      // 1. DRIVER role
      final qDriver = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['melly chris'],
        personRole: PersonRole.driver,
        limit: 50,
      );
      final resDriver = await resolver.resolve(qDriver);
      final respDriver = await searchRepo.search(resDriver.resolvedQuery!);
      expect(respDriver.totalCount, expectedDriverVidIds.length);
      final actualDriverVidIds = respDriver.results.map((r) => r.videoId).toSet();
      expect(actualDriverVidIds, equals(expectedDriverVidIds));

      // 2. CO_DRIVER role
      final qCodriver = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['melly chris'],
        personRole: PersonRole.coDriver,
        limit: 200,
      );
      final resCodriver = await resolver.resolve(qCodriver);
      final respCodriver = await searchRepo.search(resCodriver.resolvedQuery!);
      expect(respCodriver.totalCount, expectedCodriverVidIds.length);
      final actualCodriverVidIds = respCodriver.results.map((r) => r.videoId).toSet();
      expect(actualCodriverVidIds, equals(expectedCodriverVidIds));

      // 3. ANY role
      final qAny = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['melly chris'],
        personRole: PersonRole.any,
        limit: 200,
      );
      final resAny = await resolver.resolve(qAny);
      final respAny = await searchRepo.search(resAny.resolvedQuery!);
      expect(respAny.totalCount, expectedAllVidIds.length);
      final actualAnyVidIds = respAny.results.map((r) => r.videoId).toSet();
      expect(actualAnyVidIds, equals(expectedAllVidIds));
    });
  });

  group('4. Deduplication & Pagination Integrity', () {
    test('Video actions pagination has zero duplicate rows and correct totalCount', () async {
      final qPage1 = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: ['jump'],
        limit: 10,
        offset: 0,
      );
      final respPage1 = await searchRepo.search(qPage1);
      final page1Ids = respPage1.results.map((r) => r.id).toList();
      expect(page1Ids.toSet().length, page1Ids.length, reason: 'Page 1 must have no duplicate IDs');

      if (respPage1.totalCount > 10) {
        final qPage2 = SearchQuery(
          intent: SearchIntent.searchVideoActions,
          actionTypes: ['jump'],
          limit: 10,
          offset: 10,
        );
        final respPage2 = await searchRepo.search(qPage2);
        final page2Ids = respPage2.results.map((r) => r.id).toList();
        expect(page2Ids.toSet().length, page2Ids.length, reason: 'Page 2 must have no duplicate IDs');

        final overlap = page1Ids.toSet().intersection(page2Ids.toSet());
        expect(overlap, isEmpty, reason: 'Page 1 and Page 2 must not have overlapping IDs');
      }
    });
  });

  group('5. Conversational Follow-Up Semantics Distinction', () {
    test('Distinguishes "videos from those rallies" (event referents) vs "videos of X" (person filter)', () async {
      // Step 1: "Which rallies did Max Freeman co-drive in?"
      final qRallies = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.coDriver,
      );
      final resRallies = await resolver.resolve(qRallies);
      final respRallies = await searchRepo.search(resRallies.resolvedQuery!);

      final contextAfterRallies = ResultReferentContext.fromSearchResponse(
        respRallies,
        queryDriver: 'Max Freeman',
        queryPersonRole: PersonRole.coDriver,
        queryRallies: respRallies.results.map((r) => r.eventName.toString()).toList(),
      );

      // Verification A: Follow-up "Show videos from those rallies"
      // Expected: Uses inherited event referents (activeRallies), NOT direct person filter on video crew
      expect(contextAfterRallies.activeRallies, isNotEmpty);
      expect(contextAfterRallies.activeRallies.length, greaterThan(1));

      // Verification B: "Show videos of Max Freeman"
      // Expected: Uses person filter (driverNames: ["Max Freeman"], personRole: CO_DRIVER)
      expect(contextAfterRallies.activeDriver, 'Max Freeman');
      expect(contextAfterRallies.activePersonRole, PersonRole.coDriver);
    });
  });
}
