// ignore_for_file: avoid_print
@Tags(['live-db', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_lookup_adapter.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'deterministic_corruption_generator.dart';
import 'held_out_entity_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frozen OLD vs NEW held-out baseline', () async {
    await dotenv.load(fileName: '.env');
    final database = DatabaseService();
    final source = MySqlEntitySearchDataSource(database: database);
    final rssBefore = ProcessInfo.currentRss;
    final all = await source.loadEntities();
    final service = InMemoryEntitySearchService.fromEntities(all);
    final buildWatch = Stopwatch()..start();
    await service.rebuild();
    buildWatch.stop();
    final rssAfter = ProcessInfo.currentRss;
    final old = DatabaseEntityLookupRepository(dbService: database);
    final generator = DeterministicCorruptionGenerator(heldOutSeed);
    final selected = <CanonicalSearchEntity>[];
    for (final entry in heldOutEntityIds.entries) {
      for (final id in entry.value) {
        final matches = all
            .where((e) => e.entityType == entry.key && e.canonicalId == id)
            .toList();
        if (matches.isNotEmpty) selected.add(matches.single);
      }
    }
    expect(
      selected.length,
      80,
      reason: 'The persisted live fixture must remain resolvable',
    );

    final metrics = <String, _Metrics>{};
    final corruptionCounts = <String, int>{};
    final personDiagnostics = <Map<String, Object?>>[];
    final pools = <int>[];
    final evaluated = <int>[];
    final returned = <int>[];
    final latencyByType = <String, List<int>>{};

    for (final target in selected) {
      final corruptions = generator.generate(
        target.canonicalName,
        target.canonicalId,
        person: target.entityType == SearchEntityType.person,
      );
      for (final corruption in corruptions) {
        corruptionCounts.update(
          '${corruption.kind}:${corruption.difficulty.name}',
          (v) => v + 1,
          ifAbsent: () => 1,
        );
        final newCandidates = await service.search(
          EntitySearchRequest(
            rawMention: corruption.value,
            entityType: target.entityType,
            limit: 10,
          ),
        );
        final stats = service.lastQueryStats!;
        pools.add(stats.survivingCandidates);
        evaluated.add(stats.rawCandidatesEvaluated);
        returned.add(stats.returnedCandidates);
        latencyByType
            .putIfAbsent(target.entityType.name, () => [])
            .add(stats.latency.inMicroseconds);
        final oldCandidates = await _oldSearch(
          old,
          target.entityType,
          corruption.value,
        );
        final newRank = _newRank(newCandidates, target.canonicalId);
        final oldRank = _oldRank(oldCandidates, target);
        for (final pair in [('NEW', newRank), ('OLD', oldRank)]) {
          _record(metrics, pair.$1, 'overall', pair.$2);
          _record(metrics, pair.$1, 'type:${target.entityType.name}', pair.$2);
          _record(
            metrics,
            pair.$1,
            'difficulty:${corruption.difficulty.name}',
            pair.$2,
          );
        }
        if (target.entityType == SearchEntityType.person) {
          final found = newCandidates
              .where((c) => c.canonicalId == target.canonicalId)
              .firstOrNull;
          personDiagnostics.add({
            'accountId': target.canonicalId,
            'canonicalName': target.canonicalName,
            'driverId': target.metadata['driverId'],
            'codriverId': target.metadata['codriverId'],
            'role': target.metadata['role'],
            'corruptionKind': corruption.kind,
            'difficulty': corruption.difficulty.name,
            'corruption': corruption.value,
            'rank': newRank,
            'tokenScore': found?.signals.tokenScore,
            'ngramScore': found?.signals.ngramScore,
            'lexicalScore': found?.signals.lexicalScore,
            'phoneticScore': found?.signals.phoneticScore,
            'finalScore': found?.score,
            'top5': newCandidates
                .take(5)
                .map(
                  (c) => {
                    'accountId': c.canonicalId,
                    'name': c.canonicalName,
                    'score': c.score,
                  },
                )
                .toList(),
          });
        }
      }
    }

    final adapter = EntitySearchLookupAdapter(
      searchService: service,
      cityFallback: old,
    );
    final resolver = DatabaseEntityResolver(
      repository: adapter,
      minConfidenceThreshold: 0.75,
      minScoreGap: 0.15,
    );
    final safety = await _runSafety(resolver, selected);
    final personAudit = await _personNameAudit(
      database,
      heldOutEntityIds[SearchEntityType.person]!,
    );
    pools.sort();
    evaluated.sort();
    returned.sort();

    final report = <String, Object?>{
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'frozenImplementation': true,
      'seed': heldOutSeed,
      'heldOutComposition': {
        for (final type in SearchEntityType.values)
          type.name: selected.where((e) => e.entityType == type).length,
      },
      'heldOutEntities': selected
          .map(
            (e) => {
              'id': e.canonicalId,
              'name': e.canonicalName,
              'type': e.entityType.name,
              'metadata': e.metadata,
            },
          )
          .toList(),
      'corruptionCounts': corruptionCounts,
      'retrievalMetrics': {
        for (final entry in metrics.entries) entry.key: entry.value.toJson(),
      },
      'personDiagnostics': personDiagnostics,
      'canonicalPersonNamePolicy': {
        'currentPolicy': 'driver profile name when present, otherwise co-driver profile name; normalized lexical tie-break within a role',
        'audit': personAudit,
      },
      'resolverSafety': safety,
      'candidatePools': _distribution(
        pools,
        extras: {
          'meanRawEvaluated': _mean(evaluated),
          'meanReturned': _mean(returned),
          'maxRawEvaluated': evaluated.last,
        },
      ),
      'memory': {
        'representationSizeEstimateBytes': service.indexStats?.estimatedBytes,
        'processRssBeforeBytes': rssBefore,
        'processRssAfterBytes': rssAfter,
        'processRssDeltaBytes': rssAfter - rssBefore,
        'limitation': 'RSS includes DB loading/runtime allocation and is not an isolated Dart heap measurement.',
      },
      'performance': {
        'entityCount': service.indexStats?.entityCount,
        'measuredRebuildMicroseconds': buildWatch.elapsedMicroseconds,
        'queryLatencyByTypeMicroseconds': {
          for (final e in latencyByType.entries)
            e.key: _distribution(e.value..sort()),
        },
      },
    };
    const path = 'test/eval/entity_search/held_out_baseline_report.json';
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    print('WROTE $path');
    print(
      const JsonEncoder.withIndent('  ').convert({
        'composition': report['heldOutComposition'],
        'corruptions': corruptionCounts.values.fold<int>(0, (a, b) => a + b),
        'metrics': report['retrievalMetrics'],
        'safety': safety,
        'pools': report['candidatePools'],
        'performance': report['performance'],
      }),
    );
    await database.close();
  }, timeout: const Timeout(Duration(minutes: 30)));
}

Future<List<EntityCandidate>> _oldSearch(
  DatabaseEntityLookupRepository old,
  SearchEntityType type,
  String value,
) => switch (type) {
  SearchEntityType.rally => old.lookupRallies(value, limit: 10),
  SearchEntityType.person => old.lookupDrivers(value, limit: 10),
  SearchEntityType.stage => old.lookupStages(value, limit: 10),
  SearchEntityType.uploader => old.lookupUploaders(value, limit: 10),
};

int? _newRank(List<EntitySearchCandidate> values, String id) {
  final index = values.indexWhere((c) => c.canonicalId == id);
  return index < 0 ? null : index + 1;
}

int? _oldRank(List<EntityCandidate> values, CanonicalSearchEntity target) {
  final index = values.indexWhere((c) {
    if (target.entityType == SearchEntityType.person) {
      return c.metadata?['accountId']?.toString() == target.canonicalId ||
          c.metadata?['driverId']?.toString() ==
              target.metadata['driverId']?.toString() ||
          c.metadata?['codriverId']?.toString() ==
              target.metadata['codriverId']?.toString();
    }
    return c.id == target.canonicalId;
  });
  return index < 0 ? null : index + 1;
}

void _record(
  Map<String, _Metrics> metrics,
  String engine,
  String slice,
  int? rank,
) => metrics.putIfAbsent('$engine:$slice', _Metrics.new).add(rank);

class _Metrics {
  int total = 0, r1 = 0, r5 = 0, r10 = 0;
  double reciprocalRank = 0;
  void add(int? rank) {
    total++;
    if (rank != null) {
      if (rank <= 1) r1++;
      if (rank <= 5) r5++;
      if (rank <= 10) r10++;
      reciprocalRank += 1 / rank;
    }
  }

  Map<String, Object> toJson() => {
    'cases': total,
    'recallAt1': r1 / total,
    'recallAt5': r5 / total,
    'recallAt10': r10 / total,
    'mrr': reciprocalRank / total,
  };
}

Map<String, Object> _distribution(
  List<int> sorted, {
  Map<String, Object> extras = const {},
}) => {
  'count': sorted.length,
  'mean': _mean(sorted),
  'p50': _percentile(sorted, .50),
  'p95': _percentile(sorted, .95),
  'max': sorted.last,
  ...extras,
};
double _mean(List<int> values) =>
    values.fold<int>(0, (a, b) => a + b) / values.length;
int _percentile(List<int> values, double p) =>
    values[min(values.length - 1, (values.length * p).floor())];

Future<List<Map<String, Object?>>> _personNameAudit(
  DatabaseService db,
  List<String> ids,
) async {
  final quoted = ids.map((id) => "'${id.replaceAll("'", "''")}'").join(',');
  final rows = await db.query('''
    SELECT account_id, 'driver' AS role, driver_id AS profile_id, full_name FROM user_driver_profile WHERE account_id IN ($quoted)
    UNION ALL
    SELECT account_id, 'co_driver' AS role, codriver_id AS profile_id, full_name FROM user_codriver_profile WHERE account_id IN ($quoted);
  ''');
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in rows)
    grouped.putIfAbsent(row['account_id'].toString(), () => []).add(row);
  return grouped.entries.map((e) {
    final names = e.value
        .map((r) => r['full_name']?.toString())
        .whereType<String>()
        .toSet();
    return <String, Object?>{
      'accountId': e.key,
      'profiles': e.value,
      'distinctNames': names.toList(),
      'nameDivergence': names.length > 1,
    };
  }).toList();
}

Future<Map<String, Object>> _runSafety(
  DatabaseEntityResolver resolver,
  List<CanonicalSearchEntity> entities,
) async {
  final cases = <({String id, SearchQuery query, String? expected})>[
    (
      id: 'positive_aluksne',
      query: const SearchQuery(
        intent: SearchIntent.searchVideoActions,
        rallyNames: ['alux new'],
      ),
      expected: 'Alūksne',
    ),
    (
      id: 'wrong_year',
      query: const SearchQuery(
        intent: SearchIntent.searchVideoActions,
        rallyNames: ['Aluksne'],
        years: [1999],
      ),
      expected: null,
    ),
    (
      id: 'wrong_person',
      query: const SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Craig Nonexistentperson'],
      ),
      expected: null,
    ),
    (
      id: 'nonsense_person',
      query: const SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Zzzz Qqqq Xxxx'],
      ),
      expected: null,
    ),
    (
      id: 'random_tourist_person',
      query: const SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Random Tourist 12345'],
      ),
      expected: null,
    ),
    (
      id: 'fake_rally',
      query: const SearchQuery(
        intent: SearchIntent.searchVideoActions,
        rallyNames: ['Rally Fakeplacenamexyz'],
      ),
      expected: null,
    ),
    (
      id: 'random_city_rally',
      query: const SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyNames: ['Random City Nonexistent Stages Rally'],
      ),
      expected: null,
    ),
    (
      id: 'spaceship_rally',
      query: const SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyNames: ['Pineapple Spaceship Championship 2099'],
      ),
      expected: null,
    ),
    (
      id: 'moon_base_stage',
      query: const SearchQuery(
        intent: SearchIntent.searchVideoActions,
        stageNames: ['Moon Base Alpha Stage 99'],
      ),
      expected: null,
    ),
    (
      id: 'coral_reef_stage',
      query: const SearchQuery(
        intent: SearchIntent.searchVideoActions,
        stageNames: ['Underwater Coral Reef SS99'],
      ),
      expected: null,
    ),
    (
      id: 'unrelated_noise',
      query: const SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Completely Unrelated Noise'],
      ),
      expected: null,
    ),
    (
      id: 'common_first_wrong_surname',
      query: const SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['James Xylophone'],
      ),
      expected: null,
    ),
  ];
  final onlyCoDriver = entities
      .where(
        (e) =>
            e.entityType == SearchEntityType.person &&
            e.metadata['role'] == 'co_driver',
      )
      .firstOrNull;
  if (onlyCoDriver != null) {
    cases.add((
      id: 'driver_role_mismatch',
      query: SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: [onlyCoDriver.canonicalName],
        personRole: PersonRole.driver,
      ),
      expected: null,
    ));
  }
  var falseConfident = 0, correct = 0, clarification = 0, noMatch = 0;
  final details = <Map<String, Object?>>[];
  for (final item in cases) {
    final result = await resolver.resolve(item.query);
    final resolution = result.resolutions.values.firstOrNull;
    final resolvedName = resolution?.resolvedCandidate?.canonicalName;
    final auto = resolution?.isResolved ?? false;
    final isCorrect =
        item.expected != null &&
        auto &&
        (resolvedName?.contains(item.expected!) ?? false);
    final isFalse = auto && !isCorrect;
    if (isFalse) falseConfident++;
    if (isCorrect) correct++;
    if (result.requiresClarification) clarification++;
    if (!auto && !result.requiresClarification) noMatch++;
    details.add({
      'id': item.id,
      'expected': item.expected,
      'resolved': resolvedName,
      'autoResolved': auto,
      'clarification': result.requiresClarification,
      'error': result.error,
      'falseConfident': isFalse,
    });
  }
  return {
    'cases': cases.length,
    'falseConfidentAutoResolution': falseConfident,
    'correctAutoResolution': correct,
    'clarification': clarification,
    'noMatch': noMatch,
    'details': details,
  };
}
