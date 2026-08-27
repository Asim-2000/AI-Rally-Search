import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'database_entity_resolver_test.dart';

void main() {
  group('DatabaseEntityResolver Multi-Entity Resolution Tests', () {
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
              subtitle: 'Ireland • 2025',
              metadata: {'year': 2025},
            ),
          ],
          'trackrod': [
            const EntityCandidate(
              id: 'trackrod-2024-uuid',
              type: EntityType.rally,
              canonicalName: 'Trackrod Rally 2024',
              subtitle: 'United Kingdom • 2024',
              metadata: {'year': 2024},
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
          'sam moffett': [
            const EntityCandidate(
              id: 'sam-moffett-uuid',
              type: EntityType.driver,
              canonicalName: 'Sam Moffett',
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
              id: 'gale-rigg-uuid',
              type: EntityType.stage,
              canonicalName: 'Gale Rigg',
              metadata: {'stageNumber': '3'},
            ),
          ],
          'alwen north': [
            const EntityCandidate(
              id: 'alwen-north-uuid',
              type: EntityType.stage,
              canonicalName: 'Alwen North',
              metadata: {'stageNumber': '1'},
            ),
          ],
        },
      );

      resolver = DatabaseEntityResolver(repository: lookupRepo);
    });

    test('Resolves multiple drivers independently into canonical IDs', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: const ['Josh Moffett', 'Sam Moffett'],
      );

      final result = await resolver.resolve(query);
      expect(result.isSuccess, isTrue);
      expect(result.requiresClarification, isFalse);
      expect(result.resolvedQuery?.driverIds, equals(['josh-moffett-uuid', 'sam-moffett-uuid']));
      expect(result.resolvedQuery?.driverNames, equals(['Josh Moffett', 'Sam Moffett']));
    });

    test('Resolves multiple rallies independently', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        rallyNames: const ['Moonraker', 'Trackrod'],
        actionTypes: const ['jump'],
      );

      final result = await resolver.resolve(query);
      expect(result.isSuccess, isTrue);
      expect(result.requiresClarification, isFalse);
      expect(result.resolvedQuery?.rallyNames, contains('Moonraker Forestry Rally 2025'));
      expect(result.resolvedQuery?.rallyNames, contains('Trackrod Rally 2024'));
    });

    test('Partial resolution preserves resolved driver when second driver is ambiguous', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: const ['Josh Moffett', 'Smith'],
      );

      final result = await resolver.resolve(query);
      expect(result.requiresClarification, isTrue);
      expect(result.clarificationQuestion, contains('Smith'));
      expect(result.candidates.length, equals(2));
      expect(result.candidates.any((c) => c.canonicalName == 'Gary Smith'), isTrue);
      expect(result.candidates.any((c) => c.canonicalName == 'Mark Smith'), isTrue);

      // Verify that Josh Moffett is preserved in the resolutions
      expect(result.resolutions['driver:Josh Moffett']?.isResolved, isTrue);
      expect(result.resolutions['driver:Josh Moffett']?.resolvedCandidate?.id, equals('josh-moffett-uuid'));
    });

    test('Resolves multiple stages independently into stage names and stage numbers', () async {
      final query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        stageNames: const ['Gale Rigg', 'Alwen North'],
      );

      final result = await resolver.resolve(query);
      expect(result.isSuccess, isTrue);
      expect(result.requiresClarification, isFalse);
      expect(result.resolvedQuery?.stageNames, equals(['Gale Rigg', 'Alwen North']));
      expect(result.resolvedQuery?.stageNumbers, equals(['3', '1']));
    });
  });
}
