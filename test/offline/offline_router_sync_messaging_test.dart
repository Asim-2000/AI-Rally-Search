
import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/offline/offline_messaging.dart';
import 'package:ai_rally_search/services/offline/offline_search_engine.dart';
import 'package:ai_rally_search/services/offline/offline_search_router.dart';
import 'package:ai_rally_search/services/offline/offline_snapshot_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _snapshot({String v = 'v1'}) => {
      'schema_version': 1,
      'data_version': v,
      'snapshot_id': '1-$v-core',
      'segment': 'core',
      'generated_at': '2026-08-30T00:00:00Z',
      'rallies': <Map<String, Object?>>[
        {'event_id': 'ev1', 'event_name': 'Rally Alpha 2025', 'country': 'Ireland', 'city': 'Cork', 'year': 2025, 'start_date': '2025-05-01', 'end_date': null, 'status': null, 'stages_count': 3},
      ],
      'people': const [],
      'stages': const [],
      'participation': const [],
      'final_results': const [],
      'driver_wins': const [],
      'uploader_stats': const [],
      'video_meta': const [],
      'video_actions': const [],
    };

class _FakeProbe implements ConnectivityProbe {
  bool online;
  _FakeProbe(this.online);
  @override
  Future<bool> isOnline() async => online;
}

void main() {
  setUpAll(sqfliteFfiInit);

  Future<OfflineSearchEngine> engine() async {
    final db = await OfflineDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    await db.importSnapshot(_snapshot());
    return OfflineSearchEngine.create(db);
  }

  group('messaging matrix', () {
    const svc = OfflineMessagingService();
    test('every offline state has a headline, explanation and action', () {
      for (final s in OfflineUxState.values) {
        if (s == OfflineUxState.online) continue;
        final m = svc.messageFor(s);
        expect(m.headline, isNotEmpty, reason: '$s headline');
        expect(m.explanation, isNotEmpty, reason: '$s explanation');
        expect(m.action, isNotEmpty, reason: '$s action');
      }
    });

    test('weather-independent copy is verbatim from the matrix', () {
      expect(svc.messageFor(OfflineUxState.noLocalSnapshot).headline, "We haven't packed the service notes yet");
      expect(svc.messageFor(OfflineUxState.videoPlaybackUnavailable).headline, "Found the clip — but the stream's off-stage");
      expect(svc.messageFor(OfflineUxState.cloudVoiceOffline).explanation, 'On-device voice is still available.');
    });

    test('stale age is rendered into the explanation', () {
      final m = svc.messageFor(OfflineUxState.offlineStaleResults, age: const Duration(hours: 2));
      expect(m.explanation, 'Updated 2 hours ago.');
    });
  });

  group('NETWORK_FIRST_WITH_LOCAL_FALLBACK router', () {
    test('ONLINE -> authoritative online result is used', () async {
      final router = OfflineSearchRouter<String>(connectivity: _FakeProbe(true), engine: await engine());
      final r = await router.route(rawText: 'rallies in ireland', online: () async => 'ONLINE');
      expect(r.mode, RouteMode.onlineAuthoritative);
      expect(r.online, 'ONLINE');
    });

    test('OFFLINE -> local search used immediately (online skipped)', () async {
      var onlineCalled = false;
      final router = OfflineSearchRouter<String>(connectivity: _FakeProbe(false), engine: await engine());
      final r = await router.route(rawText: 'rallies in ireland', online: () async {
        onlineCalled = true;
        return 'ONLINE';
      });
      expect(onlineCalled, isFalse);
      expect(r.mode, RouteMode.offlineLocal);
      expect(r.offline!.hasResults, isTrue);
    });

    test('TIMEOUT -> local fallback surfaced, online kept for explicit promotion (no silent swap)', () async {
      final router = OfflineSearchRouter<String>(
        connectivity: _FakeProbe(true),
        engine: await engine(),
        fallbackBudget: const Duration(milliseconds: 50),
      );
      final r = await router.route(
        rawText: 'rallies in ireland',
        online: () => Future.delayed(const Duration(seconds: 2), () => 'ONLINE'),
      );
      expect(r.mode, RouteMode.lowBandwidthLocal);
      expect(r.offline, isNotNull);
      expect(r.pendingOnline, isNotNull); // caller decides when/if to promote
      expect(r.uxState, OfflineUxState.lowBandwidthLocalFallback);
    });

    test('BACKEND ERROR -> deterministic local fallback', () async {
      final router = OfflineSearchRouter<String>(connectivity: _FakeProbe(true), engine: await engine());
      final r = await router.route(
        rawText: 'rallies in ireland',
        online: () async => throw StateError('boom'),
      );
      expect(r.mode, RouteMode.backendUnreachableLocal);
      expect(r.offline!.hasResults, isTrue);
    });
  });

  group('snapshot sync', () {
    test('initial sync imports the snapshot', () async {
      final db = await OfflineDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      final sync = OfflineSnapshotSync(database: db, fetcher: (_) async => _snapshot());
      final r = await sync.sync();
      expect(r.status, SyncStatus.complete);
      expect(await db.hasSnapshot(), isTrue);
    });

    test('failed fetch reports failure and preserves the previous snapshot', () async {
      final db = await OfflineDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      await db.importSnapshot(_snapshot(v: 'v1'));
      final sync = OfflineSnapshotSync(database: db, fetcher: (_) async => throw StateError('network down'));
      final r = await sync.sync();
      expect(r.status, SyncStatus.failed);
      expect((await db.meta())['snapshot_id'], '1-v1-core'); // old data intact
    });

    test('maybeSync skips when a fresh snapshot already exists', () async {
      final db = await OfflineDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      await db.importSnapshot(_snapshot());
      var fetched = false;
      final sync = OfflineSnapshotSync(
        database: db,
        fetcher: (_) async {
          fetched = true;
          return _snapshot();
        },
        stalenessThreshold: const Duration(days: 1),
      );
      final r = await sync.maybeSync();
      expect(fetched, isFalse);
      expect(r.status, SyncStatus.idle);
    });
  });
}
