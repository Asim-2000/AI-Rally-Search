import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entities = [
    const CanonicalSearchEntity(
      canonicalId: 'r1',
      canonicalName: 'Rally Alūksne 2026',
      entityType: SearchEntityType.rally,
      metadata: {'year': 2026, 'country': 'Latvia'},
    ),
    const CanonicalSearchEntity(
      canonicalId: 'r2',
      canonicalName: 'Rally Estonia 2026',
      entityType: SearchEntityType.rally,
      metadata: {'year': 2026, 'country': 'Estonia'},
    ),
    const CanonicalSearchEntity(
      canonicalId: 'a1',
      canonicalName: 'Paweł Molgo',
      entityType: SearchEntityType.person,
      metadata: {
        'accountId': 'a1',
        'driverId': 'd1',
        'codriverId': 'c1',
        'role': 'both',
      },
    ),
    const CanonicalSearchEntity(
      canonicalId: 's1',
      canonicalName: 'Kemmelberg',
      entityType: SearchEntityType.stage,
      metadata: {'eventId': 'r1'},
    ),
  ];

  test('ranks generalized spelling and segmentation damage', () async {
    final service = InMemoryEntitySearchService.fromEntities(entities);
    for (final mention in [
      'aluksni',
      'aluksnay',
      'alux new',
      'a looks nay',
      'aluknse',
    ]) {
      final result = await service.search(
        EntitySearchRequest(
          rawMention: mention,
          entityType: SearchEntityType.rally,
        ),
      );
      expect(result.first.canonicalId, 'r1', reason: mention);
      expect(result.first.signals.toMap().length, 7);
      expect(result.first.matchedBy, isNotEmpty);
    }
  });

  test('person role filters preserve one account-centric identity', () async {
    final service = InMemoryEntitySearchService.fromEntities(entities);
    final result = await service.search(
      const EntitySearchRequest(
        rawMention: 'pawel malgo',
        entityType: SearchEntityType.person,
        personRole: PersonRole.coDriver,
      ),
    );
    expect(result.single.canonicalId, 'a1');
    expect(result.single.metadata['driverId'], 'd1');
    expect(result.single.metadata['codriverId'], 'c1');
  });

  test('context boosts ranking but does not hard-filter wrong year', () async {
    final service = InMemoryEntitySearchService.fromEntities(entities);
    final result = await service.search(
      const EntitySearchRequest(
        rawMention: 'Aluksne',
        entityType: SearchEntityType.rally,
        year: 1999,
      ),
    );
    expect(result.first.canonicalId, 'r1');
    expect(result.first.signals.contextScore, 0);
  });

  test(
    'scores every legitimate person name but returns one account identity',
    () async {
      final service = InMemoryEntitySearchService.fromEntities(const [
        CanonicalSearchEntity(
          canonicalId: 'account-1',
          canonicalName: 'Melly Chris',
          entityType: SearchEntityType.person,
          metadata: {
            'accountId': 'account-1',
            'driverId': 'driver-1',
            'codriverId': 'codriver-1',
            'role': 'both',
            'searchableNames': ['Melly Chris', 'Chris Melly'],
          },
        ),
      ]);
      final result = await service.search(
        const EntitySearchRequest(
          rawMention: 'Chris Melly',
          entityType: SearchEntityType.person,
        ),
      );
      expect(result, hasLength(1));
      expect(result.single.canonicalId, 'account-1');
      expect(result.single.canonicalName, 'Melly Chris');
      expect(result.single.metadata['matchedSearchableName'], 'Chris Melly');
    expect(result.single.score, 0.95);
    },
  );
}
