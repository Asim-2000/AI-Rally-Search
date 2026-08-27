// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  group('Relational Source-of-Truth Regression Tests', () {
    late DatabaseService db;
    late SearchRepository repo;
    late DatabaseEntityLookupRepository lookupRepo;
    late DatabaseEntityResolver resolver;

    setUp(() {
      db = DatabaseService();
      repo = SearchRepository(dbService: db);
      lookupRepo = DatabaseEntityLookupRepository(dbService: db);
      resolver = DatabaseEntityResolver(repository: lookupRepo);
    });

    tearDownAll(() async {
      await db.close();
    });

    test('1. Person existing only as Co-Driver (Max Freeman) - Entry List Participation', () async {
      // Max Freeman participated in 7 distinct rally events according to rally_entry_list
      final query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.any,
      );

      final resp = await repo.searchDriverRallies(query);
      print('\n[TEST 1] Max Freeman either-role participation: ${resp.results.length} events (totalCount: ${resp.totalCount})');
      for (final r in resp.results) {
        print('  Event: ${r.eventName} | Role: ${r.role} | Car: ${r.car} #${r.carNumber} | Year: ${r.year}');
      }

      expect(resp.results.isNotEmpty, isTrue);
      // In live DB, Max Freeman has entries in 7 distinct events:
      expect(resp.totalCount, greaterThanOrEqualTo(7));
      expect(resp.results.any((r) => r.eventName.contains("Terras d'Aboboreira")), isTrue);
      expect(resp.results.any((r) => r.eventName.contains("Circuit of Ireland")), isTrue);
      expect(resp.results.any((r) => r.eventName.contains("Galway International")), isTrue);
      expect(resp.results.any((r) => r.eventName.contains("Rally of the Lakes")), isTrue);
      expect(resp.results.any((r) => r.eventName.contains("West Cork")), isTrue);
      expect(resp.results.any((r) => r.eventName.contains("Down Rally")), isTrue);
      expect(resp.results.any((r) => r.eventName.contains("Donegal")), isTrue);

      // Verify that role is Co-Driver
      for (final r in resp.results) {
        expect(r.role, equals('Co-Driver'));
      }
    });

    test('2. Explicit Driver-only vs Co-Driver-only queries for Max Freeman', () async {
      // Driver-only -> 0 events
      final driverOnlyQuery = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.driver,
      );
      final driverResp = await repo.searchDriverRallies(driverOnlyQuery);
      expect(driverResp.results.isEmpty, isTrue);
      expect(driverResp.totalCount, equals(0));

      // Co-driver-only -> 7 events
      final codriverOnlyQuery = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.coDriver,
      );
      final codriverResp = await repo.searchDriverRallies(codriverOnlyQuery);
      expect(codriverResp.results.isNotEmpty, isTrue);
      expect(codriverResp.totalCount, greaterThanOrEqualTo(7));
    });

    test('3. Person existing only as Driver (Josh Moffett)', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Josh Moffett'],
        personRole: PersonRole.any,
      );
      final resp = await repo.searchDriverRallies(query);
      print('\n[TEST 3] Josh Moffett participation: ${resp.results.length} events (totalCount: ${resp.totalCount})');
      expect(resp.results.isNotEmpty, isTrue);
      expect(resp.totalCount, greaterThan(0));
      expect(resp.results.first.role, equals('Driver'));
    });

    test('4. searchRallies filters correctly for Co-Driver (Max Freeman)', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.any,
      );
      final resp = await repo.searchRallies(query);
      print('\n[TEST 4] searchRallies with Max Freeman: ${resp.results.length} events (totalCount: ${resp.totalCount})');
      expect(resp.results.isNotEmpty, isTrue);
      expect(resp.totalCount, greaterThanOrEqualTo(7));
      expect(resp.results.any((r) => r.eventName.contains('Galway')), isTrue);
    });

    test('5. Sub-event deduplication: person in multiple sub-events of same event returns 1 event card', () async {
      // In live DB, Donegal test rally & Wilton Donegal or similar sub-events map to events.
      // Every result returned in searchDriverRallies must have a unique rallyId / event_id.
      final query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.any,
        limit: 50,
      );
      final resp = await repo.searchDriverRallies(query);
      final eventIds = resp.results.map((r) => r.rallyId).toList();
      final uniqueEventIds = eventIds.toSet().toList();
      expect(eventIds.length, equals(uniqueEventIds.length), reason: 'Each rally event must appear at most once');
    });

    test('6. Top Uploaders resolution: Canonical fan_id / account_id join with human names and profile picture', () async {
      final query = SearchQuery(
        intent: SearchIntent.getTopUploaders,
        limit: 10,
      );
      final resp = await repo.getTopUploaders(query);
      print('\n[TEST 6] Top Uploaders: ${resp.results.length} items (totalCount: ${resp.totalCount})');
      for (final u in resp.results) {
        print('  Uploader: "${u.uploaderName}" | Count: ${u.uploadCount} | Pic: ${u.profilePicture} | ID: ${u.uploaderId}');
      }

      expect(resp.results.isNotEmpty, isTrue);
      expect(resp.totalCount, greaterThan(0));

      // Check that names are NOT falling back to "Anonymous" when user profile/account exists
      final namedUploaders = resp.results.where((u) => u.uploaderName != 'Anonymous' && u.uploaderName != 'Rally Contributor').toList();
      expect(namedUploaders.isNotEmpty, isTrue, reason: 'Should resolve real fan full_name or user_name');

      // Verify canonical IDs
      final uploaderIds = resp.results.map((u) => u.uploaderId).toList();
      expect(uploaderIds.toSet().length, equals(uploaderIds.length), reason: 'Each uploader must have a unique canonical identity');
    });

    test('7. lookupUploaders correctly uses user_fan_profile and user_account', () async {
      final matches = await lookupRepo.lookupUploaders('max');
      print('\n[TEST 7] lookupUploaders("max"): ${matches.length} candidates');
      for (final m in matches) {
        print('  $m | sub: ${m.subtitle} | meta: ${m.metadata}');
      }
      expect(matches.isNotEmpty, isTrue);
      expect(matches.any((m) => m.canonicalName.toLowerCase().contains('max') || (m.subtitle?.toLowerCase().contains('max') ?? false)), isTrue);
    });

    test('8. Entity Resolution for Person in both roles attaches role: both', () async {
      // Joshua Carr appears in live DB as both driver and codriver
      final matches = await lookupRepo.lookupDrivers('Joshua Carr');
      print('\n[TEST 8] lookupDrivers("Joshua Carr"): ${matches.length} candidates');
      for (final m in matches) {
        print('  $m | sub: ${m.subtitle} | meta: ${m.metadata}');
      }
      expect(matches.isNotEmpty, isTrue);
      final carr = matches.firstWhere((m) => m.canonicalName == 'Joshua Carr');
      expect(carr.metadata?['role'], equals('both'));
      expect(carr.subtitle, contains('DRIVER / CO-DRIVER'));
    });

    test('9. Full Entity Resolution flow for Max Freeman', () async {
      final inputQuery = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
      );
      final resResult = await resolver.resolve(inputQuery);
      print('\n[TEST 9] Resolved query for Max Freeman: ${resResult.resolvedQuery?.driverNames} | IDs: ${resResult.resolvedQuery?.driverIds}');
      expect(resResult.requiresClarification, isFalse);
      expect(resResult.resolvedQuery, isNotNull);
      expect(resResult.resolvedQuery!.driverNames, contains('Max Freeman'));
      expect(resResult.resolvedQuery!.driverIds.isNotEmpty, isTrue);
      expect(resResult.resolvedQuery!.driverIds.first, equals('7a633b52-950e-49ef-8cab-34cd43e99366'));
    });

    test('10. Uploader Name Fallback Order: user_name > full_name > email > Rally Contributor', () {
      // 1. Both user_name and full_name present -> user_name wins
      final dto1 = UploaderSearchResult.fromMap({
        'uploader_user_id': 'fan-1',
        'user_name': 'jerry_rally_fan',
        'full_name': 'Jerry Lynch',
        'email': 'jerry@example.com',
        'upload_count': 10,
      });
      expect(dto1.uploaderName, equals('jerry_rally_fan'));

      // 2. user_name is null/empty -> full_name wins
      final dto2 = UploaderSearchResult.fromMap({
        'uploader_user_id': 'fan-2',
        'user_name': '   ',
        'full_name': 'Jerry Lynch',
        'email': 'jerry@example.com',
        'upload_count': 10,
      });
      expect(dto2.uploaderName, equals('Jerry Lynch'));

      // 3. Both user_name and full_name absent -> email wins
      final dto3 = UploaderSearchResult.fromMap({
        'uploader_user_id': 'fan-3',
        'user_name': '',
        'full_name': null,
        'email': 'jerry@example.com',
        'upload_count': 10,
      });
      expect(dto3.uploaderName, equals('jerry@example.com'));

      // 4. All absent -> 'Rally Contributor' fallback
      final dto4 = UploaderSearchResult.fromMap({
        'uploader_user_id': 'fan-4',
        'user_name': '',
        'full_name': null,
        'email': '  ',
        'upload_count': 10,
      });
      expect(dto4.uploaderName, equals('Rally Contributor'));
    });

    test('11. Different fan IDs are not merged even if they share username or display name', () {
      final u1 = UploaderSearchResult.fromMap({
        'uploader_user_id': 'fan-uuid-1',
        'user_name': 'max_rally',
        'upload_count': 10,
      });
      final u2 = UploaderSearchResult.fromMap({
        'uploader_user_id': 'fan-uuid-2',
        'user_name': 'max_rally',
        'upload_count': 5,
      });
      expect(u1.uploaderId, isNot(equals(u2.uploaderId)));
      expect(u1.uploaderName, equals(u2.uploaderName));
    });

    test('12. Profile picture is preserved from user_fan_profile', () {
      final u = UploaderSearchResult.fromMap({
        'uploader_user_id': 'fan-pic-1',
        'user_name': 'Mad4TarRallying',
        'profile_picture': 'https://assets.prod.pineamite.com/profiles/fan/pic.jpg',
        'upload_count': 50,
      });
      expect(u.profilePicture, equals('https://assets.prod.pineamite.com/profiles/fan/pic.jpg'));
    });
  });
}
