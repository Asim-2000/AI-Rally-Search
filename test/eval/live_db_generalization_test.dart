import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_intent.dart';

void main() {
  group('Phase 5B.2 — Live Database Generalization Integration Test Suite', () {
    late DatabaseService dbService;
    late DatabaseEntityLookupRepository lookupRepo;
    late DatabaseEntityResolver resolver;

    setUpAll(() async {
      await dotenv.load(fileName: '.env');
      dbService = DatabaseService();
      lookupRepo = DatabaseEntityLookupRepository(dbService: dbService);
      resolver = DatabaseEntityResolver(repository: lookupRepo);
    });

    test('Live DB Entity 1: "Keith Cronan" resolves to Keith Cronin (49d7ab8d-6d05-4015-9af1-5195f33b647f)', () async {
      final query = const SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverName: 'Keith Cronan',
      );

      final result = await resolver.resolve(query);

      expect(result.requiresClarification, isFalse);
      expect(result.resolutions['driver']?.resolvedCandidate?.id, equals('49d7ab8d-6d05-4015-9af1-5195f33b647f'));
      expect(result.resolutions['driver']?.resolvedCandidate?.canonicalName, equals('Keith Cronin'));
      expect(result.resolvedQuery?.driverId, equals('49d7ab8d-6d05-4015-9af1-5195f33b647f'));
    });

    test('Live DB Entity 2: "Calum Devine" resolves to Callum Devine (16de0f32-5979-4bd7-8ce5-bf06dfc84bff)', () async {
      final query = const SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverName: 'Calum Devine',
      );

      final result = await resolver.resolve(query);

      expect(result.requiresClarification, isFalse);
      expect(result.resolutions['driver']?.resolvedCandidate?.id, equals('16de0f32-5979-4bd7-8ce5-bf06dfc84bff'));
      expect(result.resolutions['driver']?.resolvedCandidate?.canonicalName, equals('Callum Devine'));
      expect(result.resolvedQuery?.driverId, equals('16de0f32-5979-4bd7-8ce5-bf06dfc84bff'));
    });

    test('Live DB Entity 3: "Westcork" + 2025 resolves to West Cork Rally (7123b272-88a9-4604-b1d5-68d2ce4d0635)', () async {
      final query = const SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyName: 'Westcork',
        year: 2025,
      );

      final result = await resolver.resolve(query);

      expect(result.requiresClarification, isFalse);
      expect(result.resolutions['rally']?.resolvedCandidate?.id, equals('7123b272-88a9-4604-b1d5-68d2ce4d0635'));
      expect(result.resolutions['rally']?.resolvedCandidate?.canonicalName, contains('West Cork Rally 2025'));
    });

    test('Live DB Property-Style Dynamic Perturbation Generalization Test', () async {
      // 1. Fetch a live sample of distinct drivers with two full names (length >= 4 per token)
      final driverRows = await dbService.query('''
        SELECT driver_id, full_name 
        FROM user_driver_profile 
        WHERE full_name IS NOT NULL 
          AND full_name NOT LIKE '%.%'
          AND full_name NOT LIKE '% Jr%'
          AND LENGTH(full_name) > 10
        LIMIT 12;
      ''');

      int testedDrivers = 0;
      int recoveredDrivers = 0;

      for (final r in driverRows) {
        final realId = r['driver_id']?.toString();
        final realName = r['full_name']?.toString();

        if (realId == null || realName == null) continue;
        final parts = realName.split(' ');
        if (parts.length < 2 || parts[0].length < 3 || parts[1].length < 3) continue;

        // Controlled perturbation: substitute a vowel in first name
        String pFirst = parts[0];
        if (pFirst.contains('e')) {
          pFirst = pFirst.replaceFirst('e', 'a');
        } else if (pFirst.contains('a')) {
          pFirst = pFirst.replaceFirst('a', 'e');
        } else if (pFirst.contains('o')) {
          pFirst = pFirst.replaceFirst('o', 'u');
        } else if (pFirst.contains('i')) {
          pFirst = pFirst.replaceFirst('i', 'e');
        }

        final perturbed = '$pFirst ${parts.sublist(1).join(' ')}';

        testedDrivers++;
        final q = SearchQuery(
          intent: SearchIntent.searchDriverVideos,
          driverName: perturbed,
        );

        final res = await resolver.resolve(q);
        final resolvedId = res.resolutions['driver']?.resolvedCandidate?.id;

        if (resolvedId == realId) {
          recoveredDrivers++;
        }
      }

      final driverAccuracy = recoveredDrivers / testedDrivers;
      print('Live DB Driver Dynamic Perturbation Recovery: ${(driverAccuracy * 100).toStringAsFixed(1)}% ($recoveredDrivers/$testedDrivers)');
      expect(driverAccuracy >= 0.80, isTrue);

      // 2. Fetch a live sample of distinct rallies from MySQL
      final rallyRows = await dbService.query('''
        SELECT event_id, event_name, YEAR(start_date) AS event_year 
        FROM rally_events 
        WHERE event_name IS NOT NULL 
          AND start_date IS NOT NULL
        LIMIT 12;
      ''');

      int testedRallies = 0;
      int recoveredRallies = 0;

      for (final r in rallyRows) {
        final realId = r['event_id']?.toString();
        final realName = r['event_name']?.toString();
        final year = int.tryParse(r['event_year']?.toString() ?? '');

        if (realId == null || realName == null) continue;

        // Perturbation: Collapse spaces in name (e.g. "Donegal Forestry Rally" -> "DonegalForestry")
        final cleanStem = realName.replaceAll(RegExp(r'\b(202\d)\b'), '').trim();
        final words = cleanStem.split(' ').where((w) => w.length >= 4).toList();
        if (words.length < 2) continue;

        final collapsedPerturbation = '${words[0]}${words[1]}'.toLowerCase();

        testedRallies++;
        final q = SearchQuery(
          intent: SearchIntent.searchRallies,
          rallyName: collapsedPerturbation,
          year: year,
        );

        final res = await resolver.resolve(q);
        final resolvedId = res.resolutions['rally']?.resolvedCandidate?.id;

        if (resolvedId == realId) {
          recoveredRallies++;
        }
      }

      final rallyAccuracy = recoveredRallies / testedRallies;
      print('Live DB Rally Dynamic Perturbation Recovery: ${(rallyAccuracy * 100).toStringAsFixed(1)}% ($recoveredRallies/$testedRallies)');
      expect(rallyAccuracy >= 0.80, isTrue);
    });
  });
}
