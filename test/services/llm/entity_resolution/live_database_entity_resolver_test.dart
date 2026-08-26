import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live AWS RDS MySQL Entity Resolution Integration Tests', () {
    late DatabaseService db;
    late DatabaseEntityLookupRepository lookupRepo;
    late DatabaseEntityResolver resolver;

    setUpAll(() async {
      await dotenv.load(fileName: '.env');
      db = DatabaseService();
      await db.connect();
      lookupRepo = DatabaseEntityLookupRepository(dbService: db);
      resolver = DatabaseEntityResolver(repository: lookupRepo);
    });

    tearDownAll(() async {
      await db.close();
    });

    test('Live DB: "Moonraker" + year=2025 resolves Moonraker Forestry Rally 2025', () async {
      const q = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyName: 'Moonraker',
        year: 2025,
      );

      final res = await resolver.resolve(q);
      expect(res.isSuccess, isTrue);
      expect(res.requiresClarification, isFalse);
      expect(res.resolvedQuery?.targetRallyName, contains('Moonraker Forestry Rally 2025'));
    });

    test('Live DB: "Moonraker" without year requires clarification for 2025 vs 2026 editions', () async {
      const q = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyName: 'Moonraker',
      );

      final res = await resolver.resolve(q);
      expect(res.requiresClarification, isTrue);
      expect(res.candidates.length, greaterThanOrEqualTo(2));
      expect(res.candidates.any((c) => c.canonicalName.contains('2025')), isTrue);
      expect(res.candidates.any((c) => c.canonicalName.contains('2026')), isTrue);
    });

    test('Live DB: "Get Jerky" resolves to Get Jerky Rally North Wales 2026', () async {
      const q = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyName: 'Get Jerky',
      );

      final res = await resolver.resolve(q);
      expect(res.isSuccess, isTrue);
      expect(res.resolvedQuery?.targetRallyName, contains('Get Jerky Rally North Wales'));
    });

    test('Live DB: "Trackrod" resolves to Trackrod Rally 2024', () async {
      const q = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyName: 'Trackrod',
      );

      final res = await resolver.resolve(q);
      expect(res.isSuccess, isTrue);
      expect(res.resolvedQuery?.targetRallyName, contains('Trackrod Rally'));
    });

    test('Live DB: "Josh Moffett" resolves to exact driver with UUID', () async {
      const q = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverName: 'Josh Moffett',
      );

      final res = await resolver.resolve(q);
      expect(res.isSuccess, isTrue);
      expect(res.resolvedQuery?.driverName, 'Josh Moffett');
      expect(res.resolvedQuery?.driverId, isNotNull);
      expect(res.resolvedQuery?.driverId!.isNotEmpty, isTrue);
    });

    test('Live DB: "Moffett" surname alone requires clarification across 6 drivers', () async {
      const q = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverName: 'Moffett',
      );

      final res = await resolver.resolve(q);
      expect(res.requiresClarification, isTrue);
      expect(res.candidates.length, greaterThanOrEqualTo(4));
    });

    test('Live DB: "Gale Rigg" stage resolves within Trackrod event context', () async {
      const q = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        rallyName: 'Trackrod',
        stageName: 'Gale Rigg',
      );

      final res = await resolver.resolve(q);
      expect(res.isSuccess, isTrue);
      expect(res.resolvedQuery?.stageName, 'Gale Rigg');
      expect(res.resolvedQuery?.stageNumber, '3');
    });

    test('Live DB: Unknown entity "Superman" does not invent IDs', () async {
      const q = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverName: 'Superman',
      );

      final res = await resolver.resolve(q);
      expect(res.resolvedQuery?.driverId, isNull);
      expect(res.resolvedQuery?.driverName, 'Superman');
    });
  });
}
