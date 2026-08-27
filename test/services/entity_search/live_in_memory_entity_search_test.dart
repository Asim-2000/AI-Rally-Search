@Tags(['live-db'])
library;

import 'dart:math';

import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async => dotenv.load(fileName: '.env'));

  test('live index smoke benchmark', () async {
    final service = InMemoryEntitySearchService(
      dataSource: MySqlEntitySearchDataSource(),
    );
    final stats = await service.rebuild();
    expect(stats.entityCount, greaterThan(0));

    final inputs = <(String, SearchEntityType)>[
      ('aluksni', SearchEntityType.rally),
      ('aluksnay', SearchEntityType.rally),
      ('aluksney', SearchEntityType.rally),
      ('alux new', SearchEntityType.rally),
      ('a looks nay', SearchEntityType.rally),
      ('eluksne', SearchEntityType.rally),
      ('aluknse', SearchEntityType.rally),
      ('pawel malgo', SearchEntityType.person),
      ('shea brain', SearchEntityType.person),
      ('donny gall', SearchEntityType.rally),
      ('kemel berg', SearchEntityType.stage),
      ('dushniki', SearchEntityType.stage),
    ];
    final micros = <int>[];
    for (final input in inputs) {
      final watch = Stopwatch()..start();
      final results = await service.search(
        EntitySearchRequest(
          rawMention: input.$1,
          entityType: input.$2,
          limit: 5,
        ),
      );
      watch.stop();
      micros.add(watch.elapsedMicroseconds);
      // ignore: avoid_print
      print(
        '${input.$1}: ${results.map((r) => '${r.canonicalName}=${r.score.toStringAsFixed(3)} ${r.signals.toMap()}').join(' | ')}',
      );
    }
    micros.sort();
    final average = micros.reduce((a, b) => a + b) / micros.length;
    int percentile(double p) =>
        micros[min(micros.length - 1, (micros.length * p).floor())];
    // ignore: avoid_print
    print(
      'INDEX entities=${stats.entityCount} buildMs=${stats.buildTime.inMicroseconds / 1000} estimatedBytes=${stats.estimatedBytes} avgUs=$average p50Us=${percentile(.50)} p95Us=${percentile(.95)} maxUs=${micros.last}',
    );
  });
}
