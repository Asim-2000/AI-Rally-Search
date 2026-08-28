import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../test/eval/entity_search/deterministic_corruption_generator.dart';
import '../test/eval/entity_search/held_out_entity_fixture.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  final database = DatabaseService();
  final source = MySqlEntitySearchDataSource(database: database);
  final all = await source.loadEntities();
  await database.disconnect();

  // 1. Export 803 cases
  final selected80 = <CanonicalSearchEntity>[];
  final fixtureSeedIdByCanonicalId = <String, String>{};
  for (final entry in heldOutEntityIds.entries) {
    for (final id in entry.value) {
      final matches = all
          .where(
            (e) =>
                e.entityType == entry.key &&
                (e.canonicalId == id ||
                    (entry.key == SearchEntityType.person &&
                        e.metadata['accountId']?.toString() == id)),
          )
          .toList();
      if (matches.isNotEmpty) {
        selected80.add(matches.single);
        fixtureSeedIdByCanonicalId[matches.single.canonicalId] = id;
      }
    }
  }

  final generator803 = DeterministicCorruptionGenerator(heldOutSeed);
  final cases803 = <Map<String, dynamic>>[];
  for (final target in selected80) {
    final corruptions = generator803.generate(
      target.canonicalName,
      fixtureSeedIdByCanonicalId[target.canonicalId] ?? target.canonicalId,
      person: target.entityType == SearchEntityType.person,
    );
    for (final c in corruptions) {
      cases803.add({
        'targetCanonicalId': target.canonicalId,
        'targetCanonicalName': target.canonicalName,
        'entityType': target.entityType.name,
        'corruptionKind': c.kind,
        'difficulty': c.difficulty.name,
        'input': c.value,
      });
    }
  }
  File('test/eval/entity_search/frozen_803_cases.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(cases803),
  );
  print('Exported ${cases803.length} frozen 803 cases');

  // 2. Export 1108 person cases
  final people = all.where((e) => e.entityType == SearchEntityType.person).toList();
  final groups = <String, List<CanonicalSearchEntity>>{
    'ACCOUNT_BACKED': people.where((e) => e.metadata['identityKind'] == 'account').toList(),
    'NULL_DRIVER': people.where((e) => e.metadata['identityKind'] == 'driver').toList(),
    'NULL_CODRIVER': people.where((e) => e.metadata['identityKind'] == 'codriver').toList(),
  };
  final desired = {'ACCOUNT_BACKED': 20, 'NULL_DRIVER': 40, 'NULL_CODRIVER': 40};
  final selectedPerson = <String, List<CanonicalSearchEntity>>{};
  const excludedNames = {'pawel molgo', 'shea breen', 'max freeman', 'chris melly', 'melly'};
  const personSeed = 20260828;

  for (final entry in groups.entries) {
    final eligible = entry.value.where((entity) {
      final normalized = PhoneticMatchingHelper.normalize(entity.canonicalName);
      return !excludedNames.any((ex) => normalized == ex || normalized.contains(ex));
    }).toList()..shuffle(
      Random(personSeed + switch (entry.key) { 'ACCOUNT_BACKED' => 1, 'NULL_DRIVER' => 2, _ => 3 }),
    );
    selectedPerson[entry.key] = eligible.take(desired[entry.key]!).toList();
  }

  final generatorPerson = DeterministicCorruptionGenerator(personSeed);
  final cases1108 = <Map<String, dynamic>>[];
  for (final entry in selectedPerson.entries) {
    for (final target in entry.value) {
      final corruptions = generatorPerson.generate(
        target.canonicalName,
        target.canonicalId,
        person: true,
      );
      for (final c in corruptions) {
        cases1108.add({
          'group': entry.key,
          'targetCanonicalId': target.canonicalId,
          'targetCanonicalName': target.canonicalName,
          'entityType': 'person',
          'corruptionKind': c.kind,
          'difficulty': c.difficulty.name,
          'input': c.value,
        });
      }
    }
  }
  File('test/eval/entity_search/frozen_1108_cases.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(cases1108),
  );
  print('Exported ${cases1108.length} frozen 1108 cases');
}
