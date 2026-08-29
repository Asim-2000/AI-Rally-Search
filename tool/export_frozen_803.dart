import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import '../test/eval/entity_search/deterministic_corruption_generator.dart';
import '../test/eval/entity_search/held_out_entity_fixture.dart';

void main() {
  final baselineFile = File('test/eval/entity_search/held_out_baseline_report.json');
  final baselineJson = jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
  final heldOutEntities = baselineJson['heldOutEntities'] as List<dynamic>;

  final generator = DeterministicCorruptionGenerator(heldOutSeed);
  final cases = <Map<String, dynamic>>[];

  for (final entityMap in heldOutEntities) {
    final id = entityMap['id'] as String;
    final name = entityMap['name'] as String;
    final typeStr = entityMap['type'] as String;
    final isPerson = typeStr == 'person';

    final corruptions = generator.generate(name, id, person: isPerson);
    for (final c in corruptions) {
      cases.add({
        'targetId': id,
        'targetName': name,
        'entityType': typeStr,
        'corruptionKind': c.kind,
        'difficulty': c.difficulty.name,
        'input': c.value,
      });
    }
  }

  File('test/eval/entity_search/frozen_803_cases.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(cases),
  );
  print('Exported ${cases.length} frozen 803 cases');
}
