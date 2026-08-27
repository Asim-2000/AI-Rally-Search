// ignore_for_file: avoid_print
@Tags(['live-db', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known real-device top five', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();
    final service = InMemoryEntitySearchService(
      dataSource: MySqlEntitySearchDataSource(database: db),
    );
    await service.rebuild();
    const cases = <(String, SearchEntityType)>[
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
    final results = <Map<String, Object?>>[];
    for (final item in cases) {
      final candidates = await service.search(
        EntitySearchRequest(rawMention: item.$1, entityType: item.$2, limit: 5),
      );
      results.add({
        'input': item.$1,
        'type': item.$2.name,
        'top5': candidates
            .map(
              (c) => {
                'id': c.canonicalId,
                'name': c.canonicalName,
                'score': c.score,
                'matchedSearchableName': c.metadata['matchedSearchableName'],
                'signals': c.signals.toMap(),
              },
            )
            .toList(),
      });
    }
    const path = 'test/eval/entity_search/known_real_device_report.json';
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    print(const JsonEncoder.withIndent('  ').convert(results));
    await db.close();
  });
}
