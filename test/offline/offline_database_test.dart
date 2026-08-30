import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/offline/offline_search_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _snapshot({String dataVersion = 'v1'}) => {
      'schema_version': 1,
      'data_version': dataVersion,
      'snapshot_id': '1-$dataVersion-full',
      'segment': 'full',
      'generated_at': '2026-08-30T00:00:00Z',
      'rallies': <Map<String, Object?>>[
        {'event_id': 'ev1', 'event_name': 'Rally Alpha 2025', 'country': 'Ireland', 'city': 'Cork', 'year': 2025, 'start_date': '2025-05-01', 'end_date': '2025-05-02', 'status': 'completed', 'stages_count': 3},
        {'event_id': 'ev2', 'event_name': 'Rally Beta 2024', 'country': 'Portugal', 'city': 'Porto', 'year': 2024, 'start_date': '2024-04-01', 'end_date': '2024-04-02', 'status': 'completed', 'stages_count': 5},
      ],
      'people': [
        {'person_id': 'person:driver:d1', 'display_name': 'Ann Smith', 'searchable_names': ['Ann Smith'], 'role': 'driver', 'driver_id': 'd1', 'codriver_id': null, 'account_id': null, 'country': 'Ireland'},
      ],
      'stages': [
        {'stage_id': 's1', 'event_id': 'ev1', 'stage_name': 'Forest Stage', 'stage_number': '1'},
      ],
      'participation': [
        {'event_id': 'ev1', 'person_id': 'd1', 'driver_id': 'd1', 'codriver_id': null, 'driver_name': 'Ann Smith', 'role': 'Driver'},
      ],
      'final_results': [
        {'id': 1, 'event_id': 'ev1', 'driver_id': 'd1', 'driver_name': 'Ann Smith', 'pos_overall': 1},
        {'id': 2, 'event_id': 'ev1', 'driver_id': 'd2', 'driver_name': 'Ben Jones', 'pos_overall': 2},
      ],
      'driver_wins': <Map<String, Object?>>[
        {'person_id': 'd1', 'driver_id': 'd1', 'driver_name': 'Ann Smith', 'win_count': 1},
      ],
      'uploader_stats': [
        {'uploader_id': 'u1', 'account_id': 'a1', 'uploader_name': 'RallyFan', 'upload_count': 5},
      ],
      'video_meta': [
        {'video_id': 100, 'event_id': 'ev1', 'stage_id': 's1', 'person_id': 'd1', 'driver_id': 'd1', 'codriver_id': null, 'driver_name': 'Ann Smith', 'event_name': 'Rally Alpha 2025', 'stage_name': 'Forest Stage', 'stage_number': '1', 'thumbnail_url': 'http://t/1.jpg', 'on_demand_url': 'http://v/1.m3u8', 'length_seconds': 61.0, 'created_at': '2025-05-01T10:00:00Z'},
      ],
      'video_actions': [
        {'id': 500, 'video_id': 100, 'event_id': 'ev1', 'stage_id': 's1', 'person_id': 'd1', 'driver_id': 'd1', 'codriver_id': null, 'action_type': 'jump_segments', 'action_type_id': 3, 'driver_name': 'Ann Smith', 'event_name': 'Rally Alpha 2025', 'event_country': 'Ireland', 'stage_name': 'Forest Stage', 'stage_number': '1', 'start_action': 10.0, 'end_action': 12.0, 'points': 1.0, 'thumbnail_url': 'http://t/1.jpg', 'on_demand_url': 'http://v/1.m3u8'},
      ],
    };

Future<OfflineDatabase> _openInMemory() =>
    OfflineDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('initial import populates tables and meta', () async {
    final db = await _openInMemory();
    await db.importSnapshot(_snapshot());
    expect(await db.hasSnapshot(), isTrue);
    final meta = await db.meta();
    expect(meta['snapshot_id'], '1-v1-full');
    expect(meta['last_sync_utc'], isNotEmpty);
    expect(await db.lastSyncUtc(), isNotNull);
    await db.close();
  });

  test('schema mismatch is rejected and leaves DB untouched', () async {
    final db = await _openInMemory();
    await db.importSnapshot(_snapshot());
    final bad = _snapshot(dataVersion: 'v2')..['schema_version'] = 99;
    expect(() => db.importSnapshot(bad), throwsA(isA<OfflineSnapshotImportException>()));
    // Previous valid snapshot still active.
    expect((await db.meta())['snapshot_id'], '1-v1-full');
    await db.close();
  });

  test('missing table is rejected', () async {
    final db = await _openInMemory();
    final bad = _snapshot()..remove('participation');
    expect(() => db.importSnapshot(bad), throwsA(isA<OfflineSnapshotImportException>()));
    await db.close();
  });

  test('failed import mid-transaction preserves the previous snapshot', () async {
    final db = await _openInMemory();
    await db.importSnapshot(_snapshot(dataVersion: 'v1'));
    // v2 passes validation but has an unsupported value type -> insert throws
    // inside the promotion transaction -> rollback.
    final corrupt = _snapshot(dataVersion: 'v2');
    (corrupt['driver_wins'] as List).add({
      'person_id': 'x', 'driver_id': 'x', 'driver_name': 'X',
      'win_count': {'not': 'a scalar'},
    });
    expect(() => db.importSnapshot(corrupt), throwsA(anything));
    // The live DB is unchanged: still v1, still queryable.
    expect((await db.meta())['snapshot_id'], '1-v1-full');
    final index = await db.buildEntityIndex();
    expect(index.rallies.length, 2);
    await db.close();
  });

  test('re-import promotes the new snapshot atomically', () async {
    final db = await _openInMemory();
    await db.importSnapshot(_snapshot(dataVersion: 'v1'));
    final v2 = _snapshot(dataVersion: 'v2');
    (v2['rallies'] as List).add({
      'event_id': 'ev3', 'event_name': 'Rally Gamma 2026', 'country': 'France',
      'city': null, 'year': 2026, 'start_date': '2026-03-01', 'end_date': null,
      'status': null, 'stages_count': 2,
    });
    await db.importSnapshot(v2);
    expect((await db.meta())['snapshot_id'], '1-v2-full');
    final index = await db.buildEntityIndex();
    expect(index.rallies.length, 3);
    await db.close();
  });

  group('executor over local snapshot', () {
    late OfflineDatabase db;
    late OfflineSearchExecutor exec;
    setUp(() async {
      db = await _openInMemory();
      await db.importSnapshot(_snapshot());
      exec = OfflineSearchExecutor(db);
    });
    tearDown(() => db.close());

    test('SEARCH_RALLIES filters by country', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.searchRallies, countries: ['ireland']));
      expect(r.totalCount, 1);
      expect((r.results.first as RallySearchResult).eventId, 'ev1');
    });

    test('SEARCH_RALLIES filters by year', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.searchRallies, years: [2024]));
      expect((r.results.single as RallySearchResult).eventId, 'ev2');
    });

    test('GET_RALLY_RESULTS returns the single winner', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.getRallyResults, rallyNames: ['ev1']));
      expect(r.totalCount, 1);
      final res = r.results.single as RallyResult;
      expect(res.driverId, 'd1');
      expect(res.posOverall, 1);
    });

    test('GET_RALLY_TOP_FINISHERS returns all positions ordered', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.getRallyTopFinishers, rallyNames: ['ev1']));
      expect(r.totalCount, 2);
      final positions = r.results.map((e) => (e as RallyResult).posOverall).toList();
      expect(positions, [1, 2]);
    });

    test('SEARCH_DRIVER_RALLIES by driver id', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.searchDriverRallies, driverIds: ['d1']));
      expect(r.totalCount, 1);
      expect((r.results.single as RallyParticipationResult).rallyId, 'ev1');
    });

    test('SEARCH_DRIVER_VIDEOS by driver id (metadata discovery)', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.searchDriverVideos, driverIds: ['d1']));
      expect(r.totalCount, 1);
      final v = r.results.single as VideoSearchResult;
      expect(v.videoId, 100);
      expect(v.videoUrl, 'http://v/1.m3u8'); // URL present; playback gated at UI
    });

    test('SEARCH_VIDEO_ACTIONS expands _segments and filters by action', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.searchVideoActions, actionTypes: ['jump']));
      expect(r.totalCount, 1);
    });

    test('GET_TOP_UPLOADERS', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.getTopUploaders));
      expect((r.results.single as UploaderSearchResult).uploaderId, 'u1');
    });

    test('GET_TOP_DRIVERS_BY_WINS', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.getTopDriversByWins));
      expect((r.results.single as DriverWinResult).winCount, 1);
    });

    test('SEARCH_DRIVER_WINS lists the win as a participation', () async {
      final r = await exec.execute(const SearchQuery(intent: SearchIntent.searchDriverWins, driverIds: ['d1']));
      expect(r.totalCount, 1);
      expect((r.results.single as RallyParticipationResult).posOverall, 1);
    });
  });
}
