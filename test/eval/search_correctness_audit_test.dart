// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive Search Result Correctness Audit', () {
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

    test('2. Max Freeman Golden Case Raw DB Truth vs Repository', () async {
      print('\n================================================================');
      print('SECTION 2: MAX FREEMAN GOLDEN CASE RAW DB TRUTH AUDIT');
      print('================================================================');

      // Check existence in driver and codriver tables
      final driverRows = await db.query(
        "SELECT * FROM user_driver_profile WHERE full_name LIKE '%Max Freeman%'",
      );
      final codriverRows = await db.query(
        "SELECT * FROM user_codriver_profile WHERE full_name LIKE '%Max Freeman%'",
      );

      print('Driver Profiles for Max Freeman: ${driverRows.length}');
      for (final r in driverRows) {
        print('  Driver ID: ${r['driver_id']}, Account: ${r['account_id']}, Name: "${r['full_name']}"');
      }

      print('Co-Driver Profiles for Max Freeman: ${codriverRows.length}');
      for (final r in codriverRows) {
        print('  Co-Driver ID: ${r['codriver_id']}, Account: ${r['account_id']}, Name: "${r['full_name']}"');
      }

      final driverId = driverRows.isNotEmpty ? driverRows.first['driver_id'] : null;
      final codriverId = codriverRows.isNotEmpty ? codriverRows.first['codriver_id'] : null;

      // Raw Truth Query for Driver participation
      final rawDriverParticipation = driverId != null
          ? await db.query('''
              SELECT DISTINCT 
                re.event_id, 
                re.event_name, 
                re.country, 
                YEAR(re.start_date) AS year,
                'driver' AS role
              FROM rally_entry_list el
              JOIN rally_sub_events rse ON el.sub_event_id = rse.sub_event_id
              JOIN rally_events re ON rse.event_id = re.event_id
              WHERE el.user_driver_id = '$driverId'
              ORDER BY re.start_date DESC
            ''')
          : <Map<String, dynamic>>[];

      // Raw Truth Query for Co-Driver participation
      final rawCodriverParticipation = codriverId != null
          ? await db.query('''
              SELECT DISTINCT 
                re.event_id, 
                re.event_name, 
                re.country, 
                YEAR(re.start_date) AS year,
                'codriver' AS role
              FROM rally_entry_list el
              JOIN rally_sub_events rse ON el.sub_event_id = rse.sub_event_id
              JOIN rally_events re ON rse.event_id = re.event_id
              WHERE el.user_co_driver_id = '$codriverId'
              ORDER BY re.start_date DESC
            ''')
          : <Map<String, dynamic>>[];

      // Combined Raw Truth (Distinct Events)
      final allRawEvents = <String, Map<String, dynamic>>{};
      for (final r in rawDriverParticipation) {
        allRawEvents[r['event_id'].toString()] = r;
      }
      for (final r in rawCodriverParticipation) {
        allRawEvents[r['event_id'].toString()] = r;
      }

      print('\nRAW DB TRUTH - Driver Events (${rawDriverParticipation.length}):');
      for (final r in rawDriverParticipation) {
        print('  [Driver] ${r['event_id']} | ${r['event_name']} (${r['year']}, ${r['country']})');
      }

      print('\nRAW DB TRUTH - Co-Driver Events (${rawCodriverParticipation.length}):');
      for (final r in rawCodriverParticipation) {
        print('  [Co-Driver] ${r['event_id']} | ${r['event_name']} (${r['year']}, ${r['country']})');
      }

      print('\nRAW DB TRUTH - Total Distinct Participation Events: ${allRawEvents.length}');

      // Compare against SearchRepository.searchDriverRallies for PersonRole.any, driver, coDriver
      print('\n--- TESTING REPOSITORY EXECUTION ---');

      // 1. PersonRole.any
      final repoAnyRes = await repo.searchDriverRallies(
        SearchQuery(
          intent: SearchIntent.searchDriverRallies,
          driverName: 'Max Freeman',
          personRole: PersonRole.any,
        ),
      );
      print('\nRepository searchDriverRallies(role: PersonRole.any):');
      print('  Found: ${repoAnyRes.results.length} rallies (Total Count: ${repoAnyRes.totalCount})');
      final repoAnyIds = repoAnyRes.results.map((r) => r.rallyId).toSet();
      for (final r in repoAnyRes.results) {
        print('  - ${r.rallyId} | ${r.eventName} (${r.year}, ${r.country}) [Role: ${r.role}]');
      }

      // 2. PersonRole.driver
      final repoDriverRes = await repo.searchDriverRallies(
        SearchQuery(
          intent: SearchIntent.searchDriverRallies,
          driverName: 'Max Freeman',
          personRole: PersonRole.driver,
        ),
      );
      print('\nRepository searchDriverRallies(role: PersonRole.driver):');
      print('  Found: ${repoDriverRes.results.length} rallies (Total Count: ${repoDriverRes.totalCount})');
      final repoDriverIds = repoDriverRes.results.map((r) => r.rallyId).toSet();
      for (final r in repoDriverRes.results) {
        print('  - ${r.rallyId} | ${r.eventName} (${r.year}, ${r.country}) [Role: ${r.role}]');
      }

      // 3. PersonRole.coDriver
      final repoCodriverRes = await repo.searchDriverRallies(
        SearchQuery(
          intent: SearchIntent.searchDriverRallies,
          driverName: 'Max Freeman',
          personRole: PersonRole.coDriver,
        ),
      );
      print('\nRepository searchDriverRallies(role: PersonRole.coDriver):');
      print('  Found: ${repoCodriverRes.results.length} rallies (Total Count: ${repoCodriverRes.totalCount})');
      final repoCodriverIds = repoCodriverRes.results.map((r) => r.rallyId).toSet();
      for (final r in repoCodriverRes.results) {
        print('  - ${r.rallyId} | ${r.eventName} (${r.year}, ${r.country}) [Role: ${r.role}]');
      }

      // Compute exact diffs
      final expectedDriverIds = rawDriverParticipation.map((r) => r['event_id'].toString()).toSet();
      final expectedCodriverIds = rawCodriverParticipation.map((r) => r['event_id'].toString()).toSet();
      final expectedAnyIds = allRawEvents.keys.toSet();

      print('\n--- EXACT DIFF REPORT FOR MAX FREEMAN ---');
      print('ANY Role:');
      print('  Expected (${expectedAnyIds.length}): $expectedAnyIds');
      print('  Actual (${repoAnyIds.length}): $repoAnyIds');
      print('  Missing in Repo: ${expectedAnyIds.difference(repoAnyIds)}');
      print('  Extra in Repo:   ${repoAnyIds.difference(expectedAnyIds)}');

      print('DRIVER Role:');
      print('  Expected (${expectedDriverIds.length}): $expectedDriverIds');
      print('  Actual (${repoDriverIds.length}): $repoDriverIds');
      print('  Missing in Repo: ${expectedDriverIds.difference(repoDriverIds)}');
      print('  Extra in Repo:   ${repoDriverIds.difference(expectedDriverIds)}');

      print('CO-DRIVER Role:');
      print('  Expected (${expectedCodriverIds.length}): $expectedCodriverIds');
      print('  Actual (${repoCodriverIds.length}): $repoCodriverIds');
      print('  Missing in Repo: ${expectedCodriverIds.difference(repoCodriverIds)}');
      print('  Extra in Repo:   ${repoCodriverIds.difference(expectedCodriverIds)}');
    });

    test('3. Driver-Only / Co-Driver-Only / Dual-Role Representative Entities', () async {
      print('\n================================================================');
      print('SECTION 3: REPRESENTATIVE ROLE ENTITIES AUDIT');
      print('================================================================');

      // Find person who is Driver ONLY
      final driverOnlyQuery = await db.query('''
        SELECT d.driver_id, d.full_name, COUNT(DISTINCT el.sub_event_id) as event_count
        FROM user_driver_profile d
        JOIN rally_entry_list el ON d.driver_id = el.user_driver_id
        LEFT JOIN user_codriver_profile cd ON d.account_id = cd.account_id
        WHERE cd.codriver_id IS NULL OR cd.codriver_id NOT IN (SELECT user_co_driver_id FROM rally_entry_list WHERE user_co_driver_id IS NOT NULL)
        GROUP BY d.driver_id, d.full_name
        HAVING event_count >= 3
        LIMIT 3;
      ''');
      print('\nRepresentative Driver-Only Persons:');
      for (final r in driverOnlyQuery) {
        print('  ${r['full_name']} (Driver ID: ${r['driver_id']}, Events: ${r['event_count']})');
      }

      // Find person who is Co-Driver ONLY
      final codriverOnlyQuery = await db.query('''
        SELECT cd.codriver_id, cd.full_name, COUNT(DISTINCT el.sub_event_id) as event_count
        FROM user_codriver_profile cd
        JOIN rally_entry_list el ON cd.codriver_id = el.user_co_driver_id
        LEFT JOIN user_driver_profile d ON cd.account_id = d.account_id
        WHERE d.driver_id IS NULL OR d.driver_id NOT IN (SELECT user_driver_id FROM rally_entry_list WHERE user_driver_id IS NOT NULL)
        GROUP BY cd.codriver_id, cd.full_name
        HAVING event_count >= 3
        LIMIT 3;
      ''');
      print('\nRepresentative Co-Driver-Only Persons:');
      for (final r in codriverOnlyQuery) {
        print('  ${r['full_name']} (Co-Driver ID: ${r['codriver_id']}, Events: ${r['event_count']})');
      }

      // Find person who is in BOTH roles with entries in both
      final dualRoleQuery = await db.query('''
        SELECT 
          d.full_name,
          d.driver_id, cd.codriver_id,
          (SELECT COUNT(DISTINCT sub_event_id) FROM rally_entry_list WHERE user_driver_id = d.driver_id) AS driver_events,
          (SELECT COUNT(DISTINCT sub_event_id) FROM rally_entry_list WHERE user_co_driver_id = cd.codriver_id) AS codriver_events
        FROM user_driver_profile d
        JOIN user_codriver_profile cd ON d.account_id = cd.account_id
        WHERE d.driver_id IN (SELECT user_driver_id FROM rally_entry_list)
          AND cd.codriver_id IN (SELECT user_co_driver_id FROM rally_entry_list)
        LIMIT 5;
      ''');
      print('\nRepresentative Dual-Role Persons:');
      for (final r in dualRoleQuery) {
        print('  ${r['full_name']} (Driver Events: ${r['driver_events']}, Co-Driver Events: ${r['codriver_events']})');
      }

      // Test Driver-Only Case
      if (driverOnlyQuery.isNotEmpty) {
        final dName = driverOnlyQuery.first['full_name']?.toString() ?? '';
        final dId = driverOnlyQuery.first['driver_id'];
        final rawTruth = await db.query('''
          SELECT DISTINCT re.event_id, re.event_name FROM rally_entry_list el
          JOIN rally_sub_events rse ON el.sub_event_id = rse.sub_event_id
          JOIN rally_events re ON rse.event_id = re.event_id
          WHERE el.user_driver_id = '$dId'
        ''');
        final rawIds = rawTruth.map((r) => r['event_id'].toString()).toSet();
        final repoRes = await repo.searchDriverRallies(
          SearchQuery(
            intent: SearchIntent.searchDriverRallies,
            driverName: dName,
            personRole: PersonRole.any,
          ),
        );
        final repoIds = repoRes.results.map((r) => r.rallyId).toSet();

        print('\nDriver-Only Audit for "$dName":');
        print('  Raw Truth Events: ${rawIds.length}, Repo Events: ${repoIds.length}');
        print('  Missing: ${rawIds.difference(repoIds)}, Extra: ${repoIds.difference(rawIds)}');
      }

      // Test Co-Driver-Only Case
      if (codriverOnlyQuery.isNotEmpty) {
        final cdName = codriverOnlyQuery.first['full_name']?.toString() ?? '';
        final cdId = codriverOnlyQuery.first['codriver_id'];
        final rawTruth = await db.query('''
          SELECT DISTINCT re.event_id, re.event_name FROM rally_entry_list el
          JOIN rally_sub_events rse ON el.sub_event_id = rse.sub_event_id
          JOIN rally_events re ON rse.event_id = re.event_id
          WHERE el.user_co_driver_id = '$cdId'
        ''');
        final rawIds = rawTruth.map((r) => r['event_id'].toString()).toSet();
        final repoRes = await repo.searchDriverRallies(
          SearchQuery(
            intent: SearchIntent.searchDriverRallies,
            driverName: cdName,
            personRole: PersonRole.any,
          ),
        );
        final repoIds = repoRes.results.map((r) => r.rallyId).toSet();

        print('\nCo-Driver-Only Audit for "$cdName":');
        print('  Raw Truth Events: ${rawIds.length}, Repo Events: ${repoIds.length}');
        print('  Missing: ${rawIds.difference(repoIds)}, Extra: ${repoIds.difference(rawIds)}');
      }
    });

    test('4. Uploader / Fan Username Mapping Audit', () async {
      print('\n================================================================');
      print('SECTION 4: UPLOADER / FAN USERNAME MAPPING AUDIT');
      print('================================================================');

      // Query raw relation between rally_videos, user_fan_profile, user_account
      final uploaderQuery = await db.query('''
        SELECT 
          v.uploader_user_id,
          f.fan_id,
          f.account_id,
          f.full_name AS fan_full_name,
          f.profile_picture,
          a.id AS account_id_from_acc,
          a.user_name,
          a.email,
          COUNT(v.id) AS video_count
        FROM rally_videos v
        LEFT JOIN user_fan_profile f ON v.uploader_user_id = f.fan_id
        LEFT JOIN user_account a ON f.account_id = a.id
        GROUP BY v.uploader_user_id, f.fan_id, f.account_id, f.full_name, f.profile_picture, a.id, a.user_name, a.email
        ORDER BY video_count DESC
        LIMIT 10;
      ''');

      print('\nTop 10 Video Uploaders in DB:');
      for (final r in uploaderQuery) {
        print('  Uploader ID: ${r['uploader_user_id']} | Videos: ${r['video_count']} | user_name: "${r['user_name']}" | fan_full_name: "${r['fan_full_name']}" | email: "${r['email']}"');
      }

      // Check SearchRepository.getTopUploaders
      final repoTopUploaders = await repo.getTopUploaders(
        SearchQuery(intent: SearchIntent.getTopUploaders),
      );
      print('\nRepository getTopUploaders (${repoTopUploaders.results.length} uploaders):');
      for (final u in repoTopUploaders.results.take(5)) {
        print('  Name: "${u.uploaderName}", Videos: ${u.uploadCount}, ID: ${u.uploaderId}, Avatar: ${u.profilePicture}');
      }
    });
  });
}
