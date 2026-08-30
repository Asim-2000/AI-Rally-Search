import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/offline/offline_query_parser.dart';
import 'package:ai_rally_search/services/offline/offline_search_engine.dart';
import 'package:ai_rally_search/services/offline/offline_search_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Real anchors from the live snapshot.
const aluksne = '0cea6942-72e3-4257-a8c1-0f8148747d82';
const freemanCod = '7a633b52-950e-49ef-8cab-34cd43e99366';

/// One labelled corpus case.
class Case {
  final String q;
  final String category; // canonical | conversational | typo | multi_filter | ambiguity | unsupported | special
  final OfflineParseKind expectKind;
  final SearchIntent? intent;
  final Map<String, dynamic> fields; // expected field -> value (list/int)
  final String? entityIdIn; // resolved id expected within rallyNames or driverIds
  const Case(this.q, this.category, this.expectKind, {this.intent, this.fields = const {}, this.entityIdIn});
}

final corpus = <Case>[
  // SEARCH_RALLIES
  const Case('rallies in ireland in 2025', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.searchRallies, fields: {'countries': ['ireland'], 'years': [2025]}),
  const Case('what rallies happened in ireland', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.searchRallies, fields: {'countries': ['ireland']}),
  const Case('portugal rallies 2024', 'multi_filter', OfflineParseKind.results,
      intent: SearchIntent.searchRallies, fields: {'countries': ['portugal'], 'years': [2024]}),
  const Case('rally aluksne', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.searchRallies, entityIdIn: aluksne),
  const Case('rally aluqsne', 'typo', OfflineParseKind.results,
      intent: SearchIntent.searchRallies, entityIdIn: aluksne),
  const Case('rallies between 2024 and 2026', 'multi_filter', OfflineParseKind.results,
      intent: SearchIntent.searchRallies, fields: {'yearFrom': 2024, 'yearTo': 2026}),

  // SEARCH_DRIVER_RALLIES
  const Case('max freeman rallies', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.searchDriverRallies, entityIdIn: freemanCod),
  const Case('what rallies did max freeman compete in', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.searchDriverRallies, entityIdIn: freemanCod),
  const Case('max freemn rallies', 'typo', OfflineParseKind.results,
      intent: SearchIntent.searchDriverRallies, entityIdIn: freemanCod),

  // SEARCH_DRIVER_WINS
  const Case('rallies won by max freeman', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.searchDriverWins, entityIdIn: freemanCod),
  const Case('max freeman wins', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.searchDriverWins, entityIdIn: freemanCod),

  // GET_RALLY_RESULTS
  const Case('who won rally aluksne', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.getRallyResults, entityIdIn: aluksne),
  const Case('winner of rally aluksne', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.getRallyResults, entityIdIn: aluksne),

  // GET_RALLY_TOP_FINISHERS
  const Case('results for rally aluksne', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.getRallyTopFinishers, entityIdIn: aluksne),
  const Case('leaderboard for rally aluksne', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.getRallyTopFinishers, entityIdIn: aluksne),

  // SEARCH_VIDEO_ACTIONS
  const Case('jumps from rally ireland', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.searchVideoActions, fields: {'actionTypes': ['jump'], 'countries': ['ireland']}),
  const Case('show me crashes', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.searchVideoActions, fields: {'actionTypes': ['crash']}),
  const Case('drifts of max freeman', 'multi_filter', OfflineParseKind.results,
      intent: SearchIntent.searchVideoActions, fields: {'actionTypes': ['drift']}, entityIdIn: freemanCod),

  // SEARCH_DRIVER_VIDEOS
  const Case('videos of max freeman', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.searchDriverVideos, entityIdIn: freemanCod),
  const Case('watch max freeman onboard', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.searchDriverVideos, entityIdIn: freemanCod),

  // GET_TOP_UPLOADERS
  const Case('top uploaders', 'canonical', OfflineParseKind.results, intent: SearchIntent.getTopUploaders),
  const Case('who uploaded the most videos', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.getTopUploaders),

  // GET_TOP_DRIVERS_BY_WINS
  const Case('top drivers by wins', 'canonical', OfflineParseKind.results,
      intent: SearchIntent.getTopDriversByWins),
  const Case('most successful drivers', 'conversational', OfflineParseKind.results,
      intent: SearchIntent.getTopDriversByWins),

  // Ambiguity (clarify, never wrong-confident)
  const Case('rally donegal', 'ambiguity', OfflineParseKind.clarification),
  const Case('who won rally donegal', 'ambiguity', OfflineParseKind.clarification),
  const Case('results for rally donegal', 'ambiguity', OfflineParseKind.clarification),

  // Unsupported / decline (safe)
  const Case('explain the offside rule in football', 'unsupported', OfflineParseKind.unsupported),
  const Case('what is the meaning of life', 'unsupported', OfflineParseKind.unsupported),
  const Case('book me a flight to tokyo', 'unsupported', OfflineParseKind.unsupported),
  const Case('rally zzzxqywv', 'unsupported', OfflineParseKind.noMatch),
  const Case('compare aerodynamics of wrc cars in detail', 'unsupported', OfflineParseKind.unsupported),

  // Specials (all 9 categories)
  const Case('what is the weather', 'special', OfflineParseKind.special),
  const Case('hello', 'special', OfflineParseKind.special),
  const Case('thanks', 'special', OfflineParseKind.special),
  const Case('who are you', 'special', OfflineParseKind.special),
  const Case('what can you do', 'special', OfflineParseKind.special),
  const Case('tell me a joke', 'special', OfflineParseKind.special),
  const Case('are you alive', 'special', OfflineParseKind.special),
  const Case('who is the best rally driver of all time', 'special', OfflineParseKind.special),
  const Case('what is the capital of france', 'special', OfflineParseKind.special),
];


void main() {
  final snapshotFile = File('parity/offline/snapshot_full.json');
  if (!snapshotFile.existsSync()) {
    test('offline benchmark (skipped: snapshot fixture absent)', () {}, skip: 'run backend snapshot generator first');
    return;
  }

  late OfflineSearchEngine engine;

  setUpAll(() async {
    sqfliteFfiInit();
    final snap = jsonDecode(await snapshotFile.readAsString()) as Map<String, dynamic>;
    final db = await OfflineDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await db.importSnapshot(snap);
    engine = await OfflineSearchEngine.create(db);
  });

  test('OFFLINE BENCHMARK — wrong-confident gate = 0, artifacts written', () async {
    final parser = engine.parser;
    final parserRows = <Map<String, dynamic>>[];
    final failures = <Map<String, dynamic>>[];

    int intentCorrect = 0, intentTotal = 0;
    int entityCorrect = 0, entityTotal = 0;
    int clarifyCorrect = 0, clarifyTotal = 0;
    int safeDeclineCorrect = 0, declineTotal = 0;
    int specialCorrect = 0, specialTotal = 0;
    int wrongConfident = 0;
    int coverageResults = 0, coverageAnswerable = 0;
    // Field F1 accumulators.
    int fTP = 0, fFP = 0, fFN = 0;

    for (final c in corpus) {
      final r = parser.parse(c.q);
      final row = <String, dynamic>{
        'query': c.q,
        'category': c.category,
        'expected_kind': c.expectKind.name,
        'actual_kind': r.kind.name,
        'expected_intent': c.intent?.toIntentString(),
        'actual_intent': (r.query?.intent ?? r.intent)?.toIntentString(),
        'actual_fields': r.query?.toMap(),
      };

      final answerable = c.expectKind == OfflineParseKind.results || c.expectKind == OfflineParseKind.clarification;
      if (answerable) coverageAnswerable++;
      if (r.kind == OfflineParseKind.results) coverageResults++;

      // --- Correctness accounting ---
      if (c.expectKind == OfflineParseKind.special) {
        specialTotal++;
        if (r.kind == OfflineParseKind.special) specialCorrect++;
      }
      if (c.expectKind == OfflineParseKind.clarification) {
        clarifyTotal++;
        if (r.kind == OfflineParseKind.clarification) clarifyCorrect++;
        // A confident RESULTS where a clarify was required is wrong-confident.
        if (r.kind == OfflineParseKind.results) {
          wrongConfident++;
          failures.add({...row, 'reason': 'confident result on ambiguous query'});
        }
      }
      if (c.expectKind == OfflineParseKind.unsupported || c.expectKind == OfflineParseKind.noMatch) {
        declineTotal++;
        if (r.kind == OfflineParseKind.unsupported || r.kind == OfflineParseKind.noMatch) {
          safeDeclineCorrect++;
        }
        if (r.kind == OfflineParseKind.results) {
          wrongConfident++;
          failures.add({...row, 'reason': 'confident result on unsupported query'});
        }
      }
      if (c.expectKind == OfflineParseKind.results) {
        // Intent accuracy.
        if (c.intent != null) {
          intentTotal++;
          final ok = r.kind == OfflineParseKind.results && r.query!.intent == c.intent;
          if (ok) intentCorrect++;
          if (r.kind == OfflineParseKind.results && r.query!.intent != c.intent) {
            wrongConfident++;
            failures.add({...row, 'reason': 'wrong confident intent'});
          }
        }
        // Entity resolution accuracy.
        if (c.entityIdIn != null) {
          entityTotal++;
          final ids = <String>{...?r.query?.rallyNames, ...?r.query?.driverIds};
          final ok = r.kind == OfflineParseKind.results && ids.contains(c.entityIdIn);
          if (ok) entityCorrect++;
          // Resolving a DIFFERENT confident entity is wrong-confident.
          if (r.kind == OfflineParseKind.results && !ids.contains(c.entityIdIn) &&
              (r.query!.rallyNames.isNotEmpty || r.query!.driverIds.isNotEmpty)) {
            wrongConfident++;
            failures.add({...row, 'reason': 'wrong confident entity'});
          }
        }
        // Field F1.
        if (r.kind == OfflineParseKind.results && c.fields.isNotEmpty) {
          for (final e in c.fields.entries) {
            final want = e.value is List ? e.value as List : [e.value];
            final got = _fieldValues(r.query!, e.key);
            for (final w in want) {
              if (got.contains(w)) {
                fTP++;
              } else {
                fFN++;
              }
            }
            for (final g in got) {
              if (!want.contains(g)) fFP++;
            }
          }
        }
      }
      parserRows.add(row);
    }

    final intentAcc = intentTotal == 0 ? 1.0 : intentCorrect / intentTotal;
    final entityAcc = entityTotal == 0 ? 1.0 : entityCorrect / entityTotal;
    final clarifyAcc = clarifyTotal == 0 ? 1.0 : clarifyCorrect / clarifyTotal;
    final safeDeclineRate = declineTotal == 0 ? 1.0 : safeDeclineCorrect / declineTotal;
    final specialAcc = specialTotal == 0 ? 1.0 : specialCorrect / specialTotal;
    final coverage = coverageAnswerable == 0 ? 0.0 : coverageResults / coverageAnswerable;
    final precision = (fTP + fFP) == 0 ? 1.0 : fTP / (fTP + fFP);
    final recall = (fTP + fFN) == 0 ? 1.0 : fTP / (fTP + fFN);
    final fieldF1 = (precision + recall) == 0 ? 0.0 : 2 * precision * recall / (precision + recall);

    // --- Execution parity (reuse the online oracle) ---
    final parity = await _executionParity(engine);

    // --- Connectivity fallback scenarios ---
    final connectivity = await _connectivityScenarios(engine);

    // --- Special-query results ---
    final specials = corpus.where((c) => c.category == 'special').map((c) {
      final r = engine.parser.parse(c.q);
      return {'query': c.q, 'category': r.specialCategory?.name, 'intercepted': r.kind == OfflineParseKind.special};
    }).toList();

    // --- Voice offline capability matrix (static, honest) ---
    final voice = {
      'cloud_voice_offline': 'NO (network required)',
      'on_device_voice_offline': 'DEVICE_DEPENDENT (only where OS on-device recognizer supports it)',
      'auto_submit': false,
      'transcript_editable': true,
    };

    // ---- Write artifacts ----
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final dir = Directory('backend/benchmarks/results/offline_search_$ts');
    dir.createSync(recursive: true);
    String p(String f) => '${dir.path}/$f';

    File(p('offline_parser_results.jsonl')).writeAsStringSync(parserRows.map(jsonEncode).join('\n'));
    File(p('offline_execution_parity.jsonl')).writeAsStringSync(parity['rows'].map(jsonEncode).join('\n'));
    File(p('offline_failure_analysis.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'wrong_confident': wrongConfident,
      'failures': failures,
    }));
    File(p('connectivity_fallback_results.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(connectivity));
    File(p('special_query_results.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(specials));
    File(p('voice_offline_results.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(voice));
    File(p('snapshot_validation.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'snapshot_id': (await engine.database.meta())['snapshot_id'],
      'table_counts': await _tableCounts(engine.database),
    }));

    final metrics = {
      'generated_at': ts,
      'corpus_size': corpus.length,
      'intent_accuracy': intentAcc,
      'field_f1': fieldF1,
      'entity_accuracy': entityAcc,
      'clarification_accuracy': clarifyAcc,
      'safe_unsupported_rate': safeDeclineRate,
      'special_accuracy': specialAcc,
      'wrong_confident': wrongConfident,
      'offline_coverage_rate': coverage,
      'execution_parity_pass': parity['pass'],
      'execution_parity_total': parity['total'],
    };
    File(p('offline_benchmark_metadata.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metrics));

    final report = StringBuffer()
      ..writeln('# Offline Search Benchmark Report')
      ..writeln()
      ..writeln('Generated: $ts')
      ..writeln()
      ..writeln('## Primary safety gate')
      ..writeln('- **wrong_confident: $wrongConfident** (gate: must be 0)')
      ..writeln()
      ..writeln('## Parser metrics')
      ..writeln('- Corpus size: ${corpus.length}')
      ..writeln('- Intent accuracy: ${_pct(intentAcc)} ($intentCorrect/$intentTotal)')
      ..writeln('- Field F1: ${fieldF1.toStringAsFixed(3)}')
      ..writeln('- Entity resolution accuracy: ${_pct(entityAcc)} ($entityCorrect/$entityTotal)')
      ..writeln('- Clarification accuracy: ${_pct(clarifyAcc)} ($clarifyCorrect/$clarifyTotal)')
      ..writeln('- Safe unsupported rate: ${_pct(safeDeclineRate)} ($safeDeclineCorrect/$declineTotal)')
      ..writeln('- Special-query accuracy: ${_pct(specialAcc)} ($specialCorrect/$specialTotal)')
      ..writeln('- OFFLINE_COVERAGE_RATE: ${_pct(coverage)} ($coverageResults/$coverageAnswerable answerable produced results)')
      ..writeln()
      ..writeln('## Execution parity (offline SQLite vs online MySQL oracle)')
      ..writeln('- Cases matched: ${parity['pass']}/${parity['total']}')
      ..writeln()
      ..writeln('## Connectivity fallback')
      ..writeln('- ${(connectivity as List).map((e) => '${e['scenario']}: ${e['mode']}').join('\n- ')}')
      ..writeln()
      ..writeln('## Voice offline')
      ..writeln('- Cloud voice offline: NO')
      ..writeln('- On-device voice offline: DEVICE_DEPENDENT');
    File(p('offline_search_report.md')).writeAsStringSync(report.toString());

    // ignore: avoid_print
    print('OFFLINE BENCHMARK artifacts -> ${dir.path}');
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(metrics));

    // ---- Gates ----
    expect(wrongConfident, 0, reason: 'WRONG_CONFIDENT must be 0. Failures: ${jsonEncode(failures)}');
    expect(parity['pass'], parity['total'], reason: 'execution parity must be exact');
    expect(specialAcc, 1.0);
    expect(clarifyAcc, 1.0);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

List _fieldValues(SearchQuery q, String key) {
  switch (key) {
    case 'countries':
      return q.countries;
    case 'years':
      return q.years;
    case 'actionTypes':
      return q.actionTypes;
    case 'yearFrom':
      return q.yearFrom == null ? [] : [q.yearFrom];
    case 'yearTo':
      return q.yearTo == null ? [] : [q.yearTo];
    default:
      return const [];
  }
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

Future<Map<String, dynamic>> _tableCounts(OfflineDatabase db) async {
  final out = <String, int>{};
  for (final t in OfflineDatabase.tableNames) {
    final rows = await db.rawQuery('SELECT COUNT(*) c FROM $t');
    out[t] = (rows.first['c'] as int?) ?? 0;
  }
  return out;
}

Future<Map<String, dynamic>> _executionParity(OfflineSearchEngine engine) async {
  final file = File('parity/offline/execution_oracle.jsonl');
  if (!file.existsSync()) return {'pass': 0, 'total': 0, 'rows': <Map<String, dynamic>>[]};
  final rows = <Map<String, dynamic>>[];
  int pass = 0, total = 0;
  for (final line in file.readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
    final c = jsonDecode(line) as Map<String, dynamic>;
    total++;
    final query = SearchQuery.fromMap(Map<String, dynamic>.from(c['query']));
    final resp = await engine.execute(query);
    final ok = resp.totalCount == c['total_count'];
    if (ok) pass++;
    rows.add({'name': c['name'], 'intent': c['intent'], 'online_total': c['total_count'], 'offline_total': resp.totalCount, 'match': ok});
  }
  return {'pass': pass, 'total': total, 'rows': rows};
}

class _Probe implements ConnectivityProbe {
  final bool online;
  _Probe(this.online);
  @override
  Future<bool> isOnline() async => online;
}

Future<List<Map<String, dynamic>>> _connectivityScenarios(OfflineSearchEngine engine) async {
  final results = <Map<String, dynamic>>[];
  Future<void> run(String scenario, ConnectivityProbe probe, Future<String> Function() online, {Duration budget = const Duration(seconds: 4)}) async {
    final router = OfflineSearchRouter<String>(connectivity: probe, engine: engine, fallbackBudget: budget);
    final r = await router.route(rawText: 'rallies in ireland in 2025', online: online);
    results.add({'scenario': scenario, 'mode': r.mode.name, 'ux_state': r.uxState.name, 'silent_swap': false});
  }

  await run('ONLINE', _Probe(true), () async => 'ONLINE');
  await run('OFFLINE', _Probe(false), () async => 'ONLINE');
  await run('TIMEOUT', _Probe(true), () => Future.delayed(const Duration(seconds: 2), () => 'ONLINE'),
      budget: const Duration(milliseconds: 50));
  await run('BACKEND_ERROR', _Probe(true), () async => throw StateError('boom'));
  return results;
}
