import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';

class MockEntityLookupRepository implements IEntityLookupRepository {
  final Map<String, List<EntityCandidate>> rallies;
  final Map<String, List<EntityCandidate>> drivers;
  final Map<String, List<EntityCandidate>> stages;
  final Map<String, List<EntityCandidate>> cities;

  MockEntityLookupRepository({
    this.rallies = const {},
    this.drivers = const {},
    this.stages = const {},
    this.cities = const {},
  });

  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 10,
  }) async {
    final clean = phrase.toLowerCase().trim();
    for (final entry in rallies.entries) {
      if (entry.key.toLowerCase().contains(clean) ||
          clean.contains(entry.key.toLowerCase())) {
        var list = entry.value;
        if (year != null) {
          list = list.where((c) => c.metadata?['year'] == year).toList();
        }
        return list;
      }
    }
    return [];
  }

  @override
  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    PersonRole personRole = PersonRole.any,
    int limit = 10,
  }) async {
    final clean = phrase.toLowerCase().trim();
    for (final entry in drivers.entries) {
      if (entry.key.toLowerCase().contains(clean) ||
          clean.contains(entry.key.toLowerCase())) {
        var list = entry.value;
        // If event context matches, prioritize inContext matches
        if (eventId != null || eventName != null) {
          final inContext = list
              .where((c) {
                final ev = c.metadata?['eventId'] ?? c.metadata?['eventName'];
                return ev == eventId || ev == eventName;
              })
              .map(
                (c) => EntityCandidate(
                  id: c.id,
                  type: c.type,
                  canonicalName: c.canonicalName,
                  subtitle: c.subtitle,
                  metadata: {...?c.metadata, 'inContext': true},
                ),
              )
              .toList();

          if (inContext.isNotEmpty) return inContext;
        }
        return list;
      }
    }
    return [];
  }

  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 10,
  }) async {
    final clean = phrase.toLowerCase().trim();
    for (final entry in stages.entries) {
      if (entry.key.toLowerCase().contains(clean) ||
          clean.contains(entry.key.toLowerCase())) {
        var list = entry.value;
        if (eventId != null) {
          list = list.where((s) => s.metadata?['eventId'] == eventId).toList();
        }
        return list;
      }
    }
    return [];
  }

  @override
  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 10,
  }) async {
    final clean = phrase.toLowerCase().trim();
    for (final entry in cities.entries) {
      if (entry.key.toLowerCase().contains(clean) ||
          clean.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return [];
  }

  @override
  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 10,
  }) async => [];
}

void main() {
  group('DatabaseEntityResolver Deterministic Entity Resolution Tests', () {
    late DatabaseEntityResolver resolver;
    late MockEntityLookupRepository lookupRepo;

    setUp(() {
      lookupRepo = MockEntityLookupRepository(
        rallies: {
          'moonraker': [
            const EntityCandidate(
              id: 'moonraker-2025-uuid',
              type: EntityType.rally,
              canonicalName: 'Moonraker Forestry Rally 2025',
              subtitle: 'Ireland • Munster • 2025',
              metadata: {'year': 2025, 'country': 'Ireland', 'city': 'Munster'},
            ),
            const EntityCandidate(
              id: 'moonraker-2026-uuid',
              type: EntityType.rally,
              canonicalName: 'Moonraker Forestry Rally 2026',
              subtitle: 'Ireland • Dungarvan • 2026',
              metadata: {
                'year': 2026,
                'country': 'Ireland',
                'city': 'Dungarvan',
              },
            ),
          ],
          'get jerky': [
            const EntityCandidate(
              id: 'get-jerky-2026-uuid',
              type: EntityType.rally,
              canonicalName: 'Get Jerky Rally North Wales 2026',
              subtitle: 'United Kingdom • Welshpool • 2026',
              metadata: {'year': 2026, 'country': 'United Kingdom'},
            ),
          ],
          'trackrod': [
            const EntityCandidate(
              id: 'trackrod-2024-uuid',
              type: EntityType.rally,
              canonicalName: 'Trackrod Rally 2024',
              subtitle: 'United Kingdom • Filey • 2024',
              metadata: {'year': 2024, 'country': 'United Kingdom'},
            ),
          ],
          'donegal': [
            const EntityCandidate(
              id: 'donegal-forestry-2025-uuid',
              type: EntityType.rally,
              canonicalName: "McCafferty's Bars Donegal Forestry Rally 2025",
              subtitle: 'Ireland • Donegal Town • 2025',
              metadata: {'year': 2025},
            ),
            const EntityCandidate(
              id: 'donegal-intl-2025-uuid',
              type: EntityType.rally,
              canonicalName: 'Wilton Donegal International Rally 2025',
              subtitle: 'Ireland • Letterkenny • 2025',
              metadata: {'year': 2025},
            ),
          ],
        },
        drivers: {
          'josh moffett': [
            const EntityCandidate(
              id: 'josh-moffett-uuid',
              type: EntityType.driver,
              canonicalName: 'Josh Moffett',
              subtitle: 'IE',
            ),
          ],
          'moffett': [
            const EntityCandidate(
              id: 'josh-moffett-uuid',
              type: EntityType.driver,
              canonicalName: 'Josh Moffett',
              subtitle: 'IE',
              metadata: {
                'eventId': 'moonraker-2025-uuid',
                'eventName': 'Moonraker Forestry Rally 2025',
              },
            ),
            const EntityCandidate(
              id: 'sam-moffett-uuid',
              type: EntityType.driver,
              canonicalName: 'Sam Moffett',
              subtitle: 'IE',
            ),
            const EntityCandidate(
              id: 'richard-moffett-uuid',
              type: EntityType.driver,
              canonicalName: 'Richard Moffett',
              subtitle: 'IE',
            ),
            const EntityCandidate(
              id: 'david-moffett-uuid',
              type: EntityType.driver,
              canonicalName: 'David Moffett',
              subtitle: 'IE',
            ),
          ],
          'smith': [
            const EntityCandidate(
              id: 'gary-smith-uuid',
              type: EntityType.driver,
              canonicalName: 'Gary Smith',
              subtitle: 'GB',
            ),
            const EntityCandidate(
              id: 'mark-smith-uuid',
              type: EntityType.driver,
              canonicalName: 'Mark Smith',
              subtitle: 'IE',
            ),
          ],
        },
        stages: {
          'gale rigg': [
            const EntityCandidate(
              id: 'gale-rigg-trackrod-uuid',
              type: EntityType.stage,
              canonicalName: 'Gale Rigg',
              subtitle: 'Trackrod Rally 2024 • SS3',
              metadata: {'eventId': 'trackrod-2024-uuid', 'stageNumber': '3'},
            ),
          ],
        },
        cities: {
          'donegal': [
            const EntityCandidate(
              id: 'Donegal Town',
              type: EntityType.city,
              canonicalName: 'Donegal Town',
              subtitle: 'Ireland',
            ),
          ],
        },
      );

      resolver = DatabaseEntityResolver(repository: lookupRepo);
    });

    test('Rallies: "Moonraker" + year=2025 resolves deterministically to 2025 edition', () async {
      const parsedQuery = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyName: 'Moonraker',
        year: 2025,
      );

      final result = await resolver.resolve(parsedQuery);
      expect(result.isSuccess, isTrue);
      expect(result.requiresClarification, isFalse);
      expect(
        result.resolvedQuery?.targetRallyName,
        'Moonraker Forestry Rally 2025',
      );
      expect(result.parsedQuery?.targetRallyName, 'Moonraker');
    });

    test('Rallies: "Moonraker" without year requires clarification when multiple editions exist', () async {
      const parsedQuery = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyName: 'Moonraker',
      );

      final result = await resolver.resolve(parsedQuery);
      expect(result.requiresClarification, isTrue);
      expect(result.candidates.length, greaterThanOrEqualTo(2));
      expect(
        result.candidates.any((c) => c.canonicalName.contains('2025')),
        isTrue,
      );
      expect(
        result.candidates.any((c) => c.canonicalName.contains('2026')),
        isTrue,
      );
    });

    test(
      'Rallies: "Get Jerky" resolves to Get Jerky Rally North Wales',
      () async {
        const parsedQuery = SearchQuery(
          intent: SearchIntent.searchRallies,
          rallyName: 'Get Jerky',
        );

        final result = await resolver.resolve(parsedQuery);
        expect(result.isSuccess, isTrue);
        expect(
          result.resolvedQuery?.targetRallyName,
          'Get Jerky Rally North Wales 2026',
        );
      },
    );

    test(
      'Drivers: "Josh Moffett" exact name resolves auto-magically',
      () async {
        const parsedQuery = SearchQuery(
          intent: SearchIntent.searchDriverRallies,
          driverName: 'Josh Moffett',
        );

        final result = await resolver.resolve(parsedQuery);
        expect(result.isSuccess, isTrue);
        expect(result.resolvedQuery?.driverName, 'Josh Moffett');
        expect(result.resolvedQuery?.driverId, 'josh-moffett-uuid');
      },
    );

    test('Drivers: Ambiguous surname "Smith" without context requires clarification', () async {
      const parsedQuery = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverName: 'Smith',
      );

      final result = await resolver.resolve(parsedQuery);
      expect(result.requiresClarification, isTrue);
      expect(result.clarificationQuestion, contains('Smith'));
      expect(result.candidates.length, 2);
    });

    test('Drivers: Partial surname "Moffett" auto-resolves when event context isolates single participant', () async {
      // Query specifies Moonraker 2025 where Josh Moffett participated
      const parsedQuery = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Moffett',
        rallyName: 'Moonraker',
        year: 2025,
      );

      final result = await resolver.resolve(parsedQuery);
      expect(result.isSuccess, isTrue);
      expect(result.requiresClarification, isFalse);
      expect(result.resolvedQuery?.driverName, 'Josh Moffett');
      expect(result.resolvedQuery?.driverId, 'josh-moffett-uuid');
      expect(
        result.resolvedQuery?.targetRallyName,
        'Moonraker Forestry Rally 2025',
      );
    });

    test(
      'Stages: "Gale Rigg" resolves within Trackrod event context',
      () async {
        const parsedQuery = SearchQuery(
          intent: SearchIntent.searchVideoActions,
          stageName: 'Gale Rigg',
          rallyName: 'Trackrod',
          year: 2024,
        );

        final result = await resolver.resolve(parsedQuery);
        expect(result.isSuccess, isTrue);
        expect(result.resolvedQuery?.stageName, 'Gale Rigg');
        expect(result.resolvedQuery?.stageNumber, '3');
        expect(result.resolvedQuery?.targetRallyName, 'Trackrod Rally 2024');
      },
    );

    test('Compound Query: "jump highlights featuring Moffett from Moonraker in 2025"', () async {
      const parsedQuery = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionType: 'jump',
        driverName: 'Moffett',
        rallyName: 'Moonraker',
        year: 2025,
      );

      final result = await resolver.resolve(parsedQuery);
      expect(result.isSuccess, isTrue);
      expect(result.resolvedQuery?.actionType, 'jump');
      expect(result.resolvedQuery?.driverName, 'Josh Moffett');
      expect(result.resolvedQuery?.driverId, 'josh-moffett-uuid');
      expect(
        result.resolvedQuery?.targetRallyName,
        'Moonraker Forestry Rally 2025',
      );
    });

    test('Ambiguous Location: "Donegal" matches both city and rally without targetRallyName', () async {
      const parsedQuery = SearchQuery(
        intent: SearchIntent.searchRallies,
        city: 'Donegal',
      );

      final result = await resolver.resolve(parsedQuery);
      expect(result.requiresClarification, isTrue);
      expect(result.candidates.any((c) => c.type == EntityType.city), isTrue);
      expect(result.candidates.any((c) => c.type == EntityType.rally), isTrue);
    });

    test('Not Found: Fictional entity "Superman" does not invent ID and produces informative failure', () async {
      const parsedQuery = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverName: 'Superman',
      );

      final result = await resolver.resolve(parsedQuery);
      expect(result.isSuccess, isFalse);
      expect(
        result.error,
        contains('We couldn\'t confidently identify that driver'),
      );
      expect(result.resolvedQuery?.driverId, isNull);
    });
  });
}
