import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_lookup_adapter.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('person role hard eligibility matrix', () {
    const driverOnly = {
      'accountId': 'a-driver',
      'driverId': 'd-1',
      'codriverId': null,
      'role': 'driver',
    };
    const codriverOnly = {
      'accountId': 'a-codriver',
      'driverId': null,
      'codriverId': 'c-1',
      'role': 'co_driver',
    };
    const both = {
      'accountId': 'a-both',
      'driverId': 'd-2',
      'codriverId': 'c-2',
      'role': 'both',
    };

    final cases = <(Map<String, dynamic>, PersonRole, bool)>[
      (driverOnly, PersonRole.driver, true),
      (driverOnly, PersonRole.coDriver, false),
      (driverOnly, PersonRole.any, true),
      (codriverOnly, PersonRole.driver, false),
      (codriverOnly, PersonRole.coDriver, true),
      (codriverOnly, PersonRole.any, true),
      (both, PersonRole.driver, true),
      (both, PersonRole.coDriver, true),
      (both, PersonRole.any, true),
    ];
    for (final item in cases) {
      test('${item.$1['role']} with ${item.$2.name} => ${item.$3}', () {
        expect(
          EntitySearchLookupAdapter.isPersonRoleEligible(item.$1, item.$2),
          item.$3,
        );
      });
    }
  });

  test(
    'equal-name distinct accounts clarify instead of using list order',
    () async {
      final resolver = DatabaseEntityResolver(
        repository: _DuplicatePersonRepository(),
      );
      final result = await resolver.resolve(
        const SearchQuery(
          intent: SearchIntent.searchDriverVideos,
          driverNames: ['Zubair Fawad'],
          personRole: PersonRole.any,
        ),
      );
      expect(result.requiresClarification, isTrue);
      expect(
        result.resolutions['driver']?.strategy,
        'duplicate_person_identity',
      );
      expect(result.candidates.map((c) => c.metadata?['accountId']).toSet(), {
        'account-1',
        'account-2',
      });
    },
  );
}

class _DuplicatePersonRepository implements IEntityLookupRepository {
  @override
  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    PersonRole personRole = PersonRole.any,
    int limit = 25,
  }) async => const [
    EntityCandidate(
      id: 'account-1',
      type: EntityType.driver,
      canonicalName: 'Zubair Fawad',
      metadata: {
        'accountId': 'account-1',
        'driverId': 'driver-1',
        'role': 'driver',
      },
    ),
    EntityCandidate(
      id: 'account-2',
      type: EntityType.driver,
      canonicalName: 'Zubair Fawad',
      metadata: {
        'accountId': 'account-2',
        'driverId': 'driver-2',
        'role': 'driver',
      },
    ),
  ];
  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 25,
  }) async => const [];
  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 25,
  }) async => const [];
  @override
  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 25,
  }) async => const [];
  @override
  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 25,
  }) async => const [];
}
