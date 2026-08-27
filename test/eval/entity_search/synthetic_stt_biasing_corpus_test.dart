import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_stt_biasing_corpus.dart';

void main() {
  test('builds deterministic held-out 30/50/30/30 corpus', () {
    final entities = <CanonicalSearchEntity>[];
    for (final type in SearchEntityType.values) {
      final count = type == SearchEntityType.person ? 70 : 40;
      for (var i = 0; i < count; i++) {
        entities.add(
          CanonicalSearchEntity(
            canonicalId: '${type.name}:$i',
            canonicalName: '${type.name} Name ${i % 35} $i',
            entityType: type,
            metadata: {
              'searchableNames': ['${type.name} Alternate $i'],
              if (type == SearchEntityType.person) 'driverId': 'd$i',
            },
          ),
        );
      }
    }
    final first = SyntheticSttCorpusBuilder().build(entities);
    final second = SyntheticSttCorpusBuilder().build(entities);
    expect(first.entities.length, 140);
    expect(first.utterances.length, 280);
    expect(
      first.entities.where((e) => e.entityType == SearchEntityType.rally),
      hasLength(30),
    );
    expect(
      first.entities.where((e) => e.entityType == SearchEntityType.person),
      hasLength(50),
    );
    expect(
      first.entities.where((e) => e.entityType == SearchEntityType.stage),
      hasLength(30),
    );
    expect(
      first.entities.where((e) => e.entityType == SearchEntityType.uploader),
      hasLength(30),
    );
    expect(
      first.utterances.map((e) => e.id),
      orderedEquals(second.utterances.map((e) => e.id)),
    );
  });
}
