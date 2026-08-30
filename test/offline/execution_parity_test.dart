import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/offline/offline_search_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Execution parity: for a curated set of RESOLVED queries covering all 9
/// intents, the offline SQLite executor must match the authoritative online
/// pipeline (SearchPlanBuilder + SearchRepository over MySQL) captured in the
/// oracle. This isolates dimension A (data/execution) from dimension B (parser).
///
/// Requires the live-DB-generated fixtures (see backend/scripts). Skipped when
/// they are absent so CI without DB access still passes.
void main() {
  final snapshotFile = File('parity/offline/snapshot_full.json');
  final oracleFile = File('parity/offline/execution_oracle.jsonl');
  if (!snapshotFile.existsSync() || !oracleFile.existsSync()) {
    test('execution parity (skipped: fixtures absent)', () {
      // ignore: avoid_print
      print('SKIP: parity/offline/{snapshot_full.json,execution_oracle.jsonl} not found.');
    }, skip: 'offline parity fixtures not generated');
    return;
  }

  late OfflineDatabase db;
  late OfflineSearchExecutor exec;
  late List<Map<String, dynamic>> oracle;

  setUpAll(() async {
    sqfliteFfiInit();
    final snapshot = jsonDecode(await snapshotFile.readAsString()) as Map<String, dynamic>;
    db = await OfflineDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await db.importSnapshot(snapshot);
    exec = OfflineSearchExecutor(db);
    oracle = oracleFile
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .toList();
  });

  tearDownAll(() async => db.close());

  test('oracle covers all 9 intents', () {
    final intents = oracle.map((c) => c['intent']).toSet();
    expect(intents.length, greaterThanOrEqualTo(9));
  });

  test('offline execution matches online oracle for every case', () async {
    final failures = <String>[];
    for (final c in oracle) {
      final name = c['name'] as String;
      final query = SearchQuery.fromMap(Map<String, dynamic>.from(c['query']));
      final expectedTotal = c['total_count'] as int;
      final expectedRows = (c['rows'] as List).cast<Map<String, dynamic>>();
      final resp = await exec.execute(query);

      if (resp.totalCount != expectedTotal) {
        failures.add('$name: total_count ${resp.totalCount} != $expectedTotal');
        continue;
      }
      final mismatch = _compareRows(c['intent'] as String, resp, expectedRows);
      if (mismatch != null) failures.add('$name: $mismatch');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

String? _compareRows(String intent, dynamic resp, List<Map<String, dynamic>> expected) {
  final results = (resp.results as List);
  switch (intent) {
    case 'SEARCH_RALLIES':
      final got = results.map((e) => (e as RallySearchResult).eventId).toSet();
      final exp = expected.map((r) => r['event_id']).toSet();
      return got.difference(exp).isEmpty && exp.difference(got).isEmpty
          ? null
          : 'event_id set differs (got ${got.length}, exp ${exp.length})';
    case 'SEARCH_DRIVER_RALLIES':
    case 'SEARCH_DRIVER_WINS':
      final got = results.map((e) => '${(e as RallyParticipationResult).rallyId}|${e.driverId}').toSet();
      final exp = expected.map((r) => '${r['rally_id']}|${r['person_id']}').toSet();
      return _setEq(got, exp) ? null : '(rally_id|person_id) set differs';
    case 'GET_RALLY_RESULTS':
    case 'GET_RALLY_TOP_FINISHERS':
      final gotPos = results.map((e) => (e as RallyResult).posOverall).toList()..sort();
      final expPos = expected.map((r) => r['pos_overall'] as int).toList()..sort();
      final gotDrv = results.map((e) => (e as RallyResult).driverId).toSet();
      final expDrv = expected.map((r) => r['driver_id']).toSet();
      if (!_listEq(gotPos, expPos)) return 'pos_overall multiset differs';
      return _setEq(gotDrv, expDrv) ? null : 'driver_id set differs';
    case 'SEARCH_VIDEO_ACTIONS':
      final got = results.map((e) => (e as VideoAction).id).toSet();
      final exp = expected.map((r) => r['id']).toSet();
      return _setEq(got, exp) ? null : 'video_action id set differs';
    case 'SEARCH_DRIVER_VIDEOS':
      final got = results.map((e) => (e as VideoSearchResult).videoId).toSet();
      final exp = expected.map((r) => r['video_id']).toSet();
      return _setEq(got, exp) ? null : 'video_id set differs';
    case 'GET_TOP_UPLOADERS':
      final got = results.map((e) => '${(e as UploaderSearchResult).uploaderId}|${e.uploadCount}').toSet();
      final exp = expected.map((r) => '${r['uploader_id']}|${r['upload_count']}').toSet();
      return _setEq(got, exp) ? null : 'uploader set differs';
    case 'GET_TOP_DRIVERS_BY_WINS':
      final got = results.map((e) => '${(e as DriverWinResult).driverId}|${e.winCount}').toSet();
      final exp = expected.map((r) => '${r['person_id']}|${r['win_count']}').toSet();
      return _setEq(got, exp) ? null : 'top-drivers set differs';
    default:
      return 'unknown intent $intent';
  }
}

bool _setEq(Set a, Set b) => a.length == b.length && a.difference(b).isEmpty;
bool _listEq(List a, List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
