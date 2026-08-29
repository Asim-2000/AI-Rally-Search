// ignore_for_file: avoid_print
@Tags(['live-db', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_lookup_adapter.dart';
import 'package:ai_rally_search/services/entity_search/entity_candidate_generator.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deterministic_corruption_generator.dart';

const _seed = 20260828;
const _excludedNames = {
  'pawel molgo',
  'shea breen',
  'max freeman',
  'chris melly',
  'melly',
};

void main() {
  test('full live PERSON universe benchmark and identity safety', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();
    final rssBefore = ProcessInfo.currentRss;
    final buildWatch = Stopwatch()..start();
    final entities = await MySqlEntitySearchDataSource(database: db)
        .loadEntities();
    final service = InMemoryEntitySearchService.fromEntities(entities);
    final fullScanService = InMemoryEntitySearchService.fromEntities(
      entities,
      candidateGenerator: FullScanCandidateGenerator(),
    );
    buildWatch.stop();
    final rssAfter = ProcessInfo.currentRss;
    final people = entities
        .where((entity) => entity.entityType == SearchEntityType.person)
        .toList();
    final groups = <String, List<CanonicalSearchEntity>>{
      'ACCOUNT_BACKED': people
          .where((e) => e.metadata['identityKind'] == 'account')
          .toList(),
      'NULL_DRIVER': people
          .where((e) => e.metadata['identityKind'] == 'driver')
          .toList(),
      'NULL_CODRIVER': people
          .where((e) => e.metadata['identityKind'] == 'codriver')
          .toList(),
    };
    final desired = {
      'ACCOUNT_BACKED': 20,
      'NULL_DRIVER': 40,
      'NULL_CODRIVER': 40,
    };
    final selected = <String, List<CanonicalSearchEntity>>{};
    for (final entry in groups.entries) {
      final eligible =
          entry.value.where((entity) {
            final normalized = PhoneticMatchingHelper.normalize(
              entity.canonicalName,
            );
            return !_excludedNames.any(
              (excluded) =>
                  normalized == excluded || normalized.contains(excluded),
            );
          }).toList()..shuffle(
            Random(
              _seed +
                  switch (entry.key) {
                    'ACCOUNT_BACKED' => 1,
                    'NULL_DRIVER' => 2,
                    _ => 3,
                  },
            ),
          );
      selected[entry.key] = eligible.take(desired[entry.key]!).toList();
    }

    final generator = DeterministicCorruptionGenerator(_seed);
    final metrics = <String, _Metrics>{
      for (final key in [...groups.keys, 'ALL_PERSON']) key: _Metrics(),
    };
    final fullScanMetrics = <String, _Metrics>{
      for (final key in [...groups.keys, 'ALL_PERSON']) key: _Metrics(),
    };
    final latencies = <int>[];
    final generationLatencies = <int>[];
    final scoringLatencies = <int>[];
    final generatedPools = <int>[];
    final candidateRecall = <String, int>{
      'pool': 0,
      'top25': 0,
      'top50': 0,
      'top100': 0,
      'top200': 0,
    };
    var fullScanEscapes = 0;
    final differences = <Map<String, Object?>>[];
    for (final entry in selected.entries) {
      for (final target in entry.value) {
        for (final corruption in generator.generate(
          target.canonicalName,
          target.canonicalId,
          person: true,
        )) {
          final request = EntitySearchRequest(
            rawMention: corruption.value,
            entityType: SearchEntityType.person,
            personRole: switch (entry.key) {
              'NULL_DRIVER' => PersonRole.driver,
              'NULL_CODRIVER' => PersonRole.coDriver,
              _ => PersonRole.any,
            },
            limit: 10,
          );
          final generated = service.candidateGenerator.generate(request);
          final candidates = await service.search(request);
          final fullCandidates = await fullScanService.search(request);
          final stats = service.lastQueryStats!;
          latencies.add(stats.latency.inMicroseconds);
          generationLatencies.add(
            stats.candidateGenerationLatency.inMicroseconds,
          );
          scoringLatencies.add(stats.scoringLatency.inMicroseconds);
          generatedPools.add(stats.generatedCandidatePool);
          if (stats.usedFullScanEscape) fullScanEscapes++;
          final generatedRank = generated.preRankedCanonicalIds.indexOf(
            target.canonicalId,
          );
          if (generatedRank >= 0) {
            candidateRecall['pool'] = candidateRecall['pool']! + 1;
            if (generatedRank < 25) {
              candidateRecall['top25'] = candidateRecall['top25']! + 1;
            }
            if (generatedRank < 50) {
              candidateRecall['top50'] = candidateRecall['top50']! + 1;
            }
            if (generatedRank < 100) {
              candidateRecall['top100'] = candidateRecall['top100']! + 1;
            }
            if (generatedRank < 200) {
              candidateRecall['top200'] = candidateRecall['top200']! + 1;
            }
          }
          final index = candidates.indexWhere(
            (candidate) => candidate.canonicalId == target.canonicalId,
          );
          final rank = index < 0 ? null : index + 1;
          final fullIndex = fullCandidates.indexWhere(
            (candidate) => candidate.canonicalId == target.canonicalId,
          );
          final fullRank = fullIndex < 0 ? null : fullIndex + 1;
          metrics[entry.key]!.add(rank);
          metrics['ALL_PERSON']!.add(rank);
          fullScanMetrics[entry.key]!.add(fullRank);
          fullScanMetrics['ALL_PERSON']!.add(fullRank);
          final indexedIds = candidates.map((c) => c.canonicalId).join('|');
          final fullIds = fullCandidates.map((c) => c.canonicalId).join('|');
          if (indexedIds != fullIds) {
            differences.add({
              'targetId': target.canonicalId,
              'input': corruption.value,
              'indexedRank': rank,
              'fullScanRank': fullRank,
            });
          }
        }
      }
    }

    final old = DatabaseEntityLookupRepository(dbService: db);
    final adapter = EntitySearchLookupAdapter(
      searchService: service,
      cityFallback: old,
    );
    final resolver = DatabaseEntityResolver(repository: adapter);
    final pawel = await _namedResult(
      service,
      resolver,
      'pawel malgo',
      PersonRole.driver,
    );
    final shea = {
      for (final role in PersonRole.values)
        role.name: await _namedResult(service, resolver, 'shea brain', role),
    };
    final collisions = await _collisionAudit(people, resolver);
    final parity = await _rawParity(db, resolver, people);
    latencies.sort();
    generationLatencies.sort();
    scoringLatencies.sort();
    generatedPools.sort();
    final queryCount = metrics['ALL_PERSON']!.count;
    final report = {
      'seed': _seed,
      'sample': {
        for (final entry in selected.entries) entry.key: entry.value.length,
      },
      'metrics': {
        for (final entry in metrics.entries) entry.key: entry.value.toMap(),
      },
      'fullScanMetrics': {
        for (final entry in fullScanMetrics.entries)
          entry.key: entry.value.toMap(),
      },
      'candidateGeneration': {
        'pool': _distribution(generatedPools),
        'candidateRecall': {
          for (final entry in candidateRecall.entries)
            entry.key: entry.value / queryCount,
        },
        'fullScanEscapeInvocations': fullScanEscapes,
        'indexedVsFullScanDifferenceCount': differences.length,
        'differences': differences,
      },
      'pawelMolgo': pawel,
      'sheaBreen': shea,
      'sameNameCollisions': collisions,
      'rawDbParity': parity,
      'performance': {
        'totalIndexedEntities': service.indexStats?.entityCount,
        'personEntities': people.length,
        'buildMicroseconds': buildWatch.elapsedMicroseconds,
        'representationSizeEstimateBytes': service.indexStats?.estimatedBytes,
        'canonicalRepresentationBytes':
            service.indexStats?.canonicalEstimatedBytes,
        'postingListBytes': service.indexStats?.postingListEstimatedBytes,
        'rssDeltaBytes': rssAfter - rssBefore,
        'personQueryMicroseconds': _distribution(latencies),
        'candidateGenerationMicroseconds': _distribution(generationLatencies),
        'scoringMicroseconds': _distribution(scoringLatencies),
      },
    };
    const path =
        'test/eval/entity_search/full_universe_person_benchmark_report.json';
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    print(const JsonEncoder.withIndent('  ').convert(report));
    expect(groups['ACCOUNT_BACKED']!.length, greaterThanOrEqualTo(20));
    expect(groups['NULL_DRIVER']!.length, greaterThanOrEqualTo(40));
    expect(groups['NULL_CODRIVER']!.length, greaterThanOrEqualTo(40));
    expect(
      parity.values.every((value) => value['matchesRawDb'] == true),
      isTrue,
    );
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 30)));
}

Future<Map<String, Object?>> _namedResult(
  InMemoryEntitySearchService service,
  DatabaseEntityResolver resolver,
  String input,
  PersonRole role,
) async {
  final candidates = await service.search(
    EntitySearchRequest(
      rawMention: input,
      entityType: SearchEntityType.person,
      personRole: role,
      limit: 10,
    ),
  );
  final result = await resolver.resolve(_query(input, role));
  return {
    'role': role.name,
    'finalBehavior': result.requiresClarification
        ? 'clarification'
        : result.resolutions.values.any((r) => r.isResolved)
        ? 'resolved'
        : 'no_match',
    'resolvedIds': result.resolvedQuery?.driverIds ?? const <String>[],
    'candidates': candidates.take(5).map((candidate) {
      return {
        'rank': candidates.indexOf(candidate) + 1,
        'canonicalId': candidate.canonicalId,
        'canonicalName': candidate.canonicalName,
        'role': candidate.metadata['role'],
        'driverId': candidate.metadata['driverId'],
        'codriverId': candidate.metadata['codriverId'],
        'tokenScore': candidate.signals.tokenScore,
        'ngramScore': candidate.signals.ngramScore,
        'lexicalScore': candidate.signals.lexicalScore,
        'phoneticScore': candidate.signals.phoneticScore,
        'finalScore': candidate.score,
      };
    }).toList(),
  };
}

Future<Map<String, Object?>> _collisionAudit(
  List<CanonicalSearchEntity> people,
  DatabaseEntityResolver resolver,
) async {
  final byName = <String, List<CanonicalSearchEntity>>{};
  for (final person in people) {
    byName
        .putIfAbsent(
          PhoneticMatchingHelper.normalize(person.canonicalName),
          () => [],
        )
        .add(person);
  }
  final collisions =
      byName.entries.where((entry) => entry.value.length > 1).toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
  final details = <Map<String, Object?>>[];
  for (final collision in collisions.take(20)) {
    final behaviors = <String, String>{};
    for (final role in PersonRole.values) {
      final result = await resolver.resolve(
        _query(collision.value.first.canonicalName, role),
      );
      behaviors[role.name] = result.requiresClarification
          ? 'clarification'
          : result.resolutions.values.any((r) => r.isResolved)
          ? 'resolved'
          : 'no_match';
    }
    details.add({
      'name': collision.value.first.canonicalName,
      'identities': collision.value
          .map((e) => {'id': e.canonicalId, 'role': e.metadata['role']})
          .toList(),
      'behavior': behaviors,
    });
  }
  return {'collisionGroups': collisions.length, 'audited': details};
}

Future<Map<String, Map<String, Object?>>> _rawParity(
  DatabaseService db,
  DatabaseEntityResolver resolver,
  List<CanonicalSearchEntity> people,
) async {
  final linked = await db.query('''
    SELECT 'driver' AS role, dp.driver_id AS role_id
    FROM user_driver_profile dp
    WHERE dp.account_id IS NULL AND dp.full_name IS NOT NULL
      AND EXISTS (SELECT 1 FROM rally_entry_list el WHERE el.user_driver_id = dp.driver_id)
    UNION ALL
    SELECT 'co_driver' AS role, cdp.codriver_id AS role_id
    FROM user_codriver_profile cdp
    WHERE cdp.account_id IS NULL AND cdp.full_name IS NOT NULL
      AND EXISTS (SELECT 1 FROM rally_entry_list el WHERE el.user_co_driver_id = cdp.codriver_id);
  ''');
  final driverId = linked
      .firstWhere((row) => row['role'] == 'driver')['role_id']
      .toString();
  final codriverId = linked
      .firstWhere((row) => row['role'] == 'co_driver')['role_id']
      .toString();
  final driver = people.firstWhere(
    (e) => e.metadata['driverId']?.toString() == driverId,
  );
  final codriver = people.firstWhere(
    (e) => e.metadata['codriverId']?.toString() == codriverId,
  );
  final output = <String, Map<String, Object?>>{};
  for (final item in [
    (driver, PersonRole.driver),
    (codriver, PersonRole.coDriver),
  ]) {
    final result = await resolver.resolve(
      _query(item.$1.canonicalName, item.$2),
    );
    final expectedId = item.$2 == PersonRole.driver
        ? item.$1.metadata['driverId'].toString()
        : item.$1.metadata['codriverId'].toString();
    final resolvedIds = result.resolvedQuery?.driverIds ?? const <String>[];
    final column = item.$2 == PersonRole.driver
        ? 'user_driver_id'
        : 'user_co_driver_id';
    final rows = await db.query(
      'SELECT id, sub_event_id FROM rally_entry_list WHERE $column = :id ORDER BY id LIMIT 5;',
      {'id': expectedId},
    );
    output[item.$2.name] = {
      'canonicalId': item.$1.canonicalId,
      'expectedRoleId': expectedId,
      'resolvedQueryIds': resolvedIds,
      'rawEntryIds': rows.map((row) => row['id']?.toString()).toList(),
      'rawSubEventIds': rows
          .map((row) => row['sub_event_id']?.toString())
          .toList(),
      'matchesRawDb':
          resolvedIds.length == 1 &&
          resolvedIds.single == expectedId &&
          rows.isNotEmpty,
    };
  }
  return output;
}

SearchQuery _query(String name, PersonRole role) => SearchQuery(
  intent: SearchIntent.searchDriverRallies,
  driverNames: [name],
  personRole: role,
);

class _Metrics {
  int count = 0;
  int at1 = 0;
  int at5 = 0;
  int at10 = 0;
  double reciprocalRank = 0;
  void add(int? rank) {
    count++;
    if (rank == null) return;
    if (rank <= 1) at1++;
    if (rank <= 5) at5++;
    if (rank <= 10) at10++;
    reciprocalRank += 1 / rank;
  }

  Map<String, Object> toMap() => {
    'queries': count,
    'recallAt1': at1 / count,
    'recallAt5': at5 / count,
    'recallAt10': at10 / count,
    'mrr': reciprocalRank / count,
  };
}

Map<String, Object> _distribution(List<int> values) => {
  'count': values.length,
  'average': values.reduce((a, b) => a + b) / values.length,
  'p50': values[(values.length * .50).floor().clamp(0, values.length - 1)],
  'p95': values[(values.length * .95).floor().clamp(0, values.length - 1)],
  'max': values.last,
};
