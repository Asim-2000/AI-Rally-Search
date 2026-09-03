
import 'dart:io';

import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/offline/offline_messaging.dart';
import 'package:ai_rally_search/services/offline/offline_search_engine.dart';
import 'package:ai_rally_search/services/latency/latency_policy.dart';
import 'package:ai_rally_search/services/latency/search_latency_coordinator.dart';
import 'package:ai_rally_search/services/latency/search_telemetry.dart';
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

  group('latency coordinator (single fallback policy)', () {
    SearchLatencyCoordinator<String> coordinator(
      OfflineSearchEngine e, {
      bool online = true,
      Duration budget = const Duration(milliseconds: 50),
      Duration overall = const Duration(seconds: 5),
    }) =>
        SearchLatencyCoordinator<String>(
          connectivity: _FakeProbe(online),
          engine: e,
          policy: LatencyPolicy(
            onlineResultBudget: budget,
            overallOnlineTimeout: overall,
          ),
        );

    Future<List<SearchEvent<String>>> collect(Stream<SearchEvent<String>> s) =>
        s.toList();

    test('online within budget -> authoritative online result', () async {
      final events = await collect(coordinator(await engine()).run(
        generation: 1,
        rawText: 'rallies in ireland',
        online: () async => 'ONLINE',
      ));
      expect(events.single.stage, SearchStage.online);
      expect(events.single.online, 'ONLINE');
      expect(events.single.source, SearchResultSource.online);
    });

    test('known offline -> local immediately, online never attempted', () async {
      var onlineCalled = false;
      final events = await collect(
        coordinator(await engine(), online: false).run(
          generation: 1,
          rawText: 'rallies in ireland',
          online: () async {
            onlineCalled = true;
            return 'ONLINE';
          },
        ),
      );
      expect(onlineCalled, isFalse);
      expect(events.single.stage, SearchStage.offlineImmediate);
      expect(events.single.offline!.hasResults, isTrue);
    });

    test('budget exceeded -> local shown, then late online is offered not applied',
        () async {
      final events = await collect(coordinator(await engine()).run(
        generation: 7,
        rawText: 'rallies in ireland',
        online: () =>
            Future.delayed(const Duration(milliseconds: 300), () => 'ONLINE'),
      ));
      expect(events.map((e) => e.stage), [
        SearchStage.offlineFallback,
        SearchStage.lateOnlineAvailable,
      ]);
      expect(events.first.source, SearchResultSource.offlineFallback);
      // The late result is explicitly not a render: it must be offered.
      expect(events.last.isTerminalRender, isFalse);
      expect(events.last.online, 'ONLINE');
      expect(events.every((e) => e.generation == 7), isTrue);
    });

    test('online fails after fallback -> local stays, no error render', () async {
      final events = await collect(coordinator(await engine()).run(
        generation: 1,
        rawText: 'rallies in ireland',
        online: () => Future.delayed(
            const Duration(milliseconds: 300), () => throw StateError('boom')),
      ));
      expect(events.map((e) => e.stage), [
        SearchStage.offlineFallback,
        SearchStage.lateOnlineFailed,
      ]);
      expect(events.last.isTerminalRender, isFalse);
    });

    test('online fails before budget -> deterministic local fallback', () async {
      final events = await collect(coordinator(await engine()).run(
        generation: 1,
        rawText: 'rallies in ireland',
        online: () async => throw StateError('boom'),
      ));
      expect(events.single.stage, SearchStage.offlineAfterOnlineFailure);
      expect(events.single.offline!.hasResults, isTrue);
    });

    test('no safe local answer -> waits for online rather than fabricating one',
        () async {
      final events = await collect(coordinator(await engine()).run(
        generation: 1,
        // Nothing in the snapshot matches, so the local parser cannot answer.
        rawText: 'rallies in absolutelynowhere',
        online: () =>
            Future.delayed(const Duration(milliseconds: 300), () => 'ONLINE'),
      ));
      expect(events.single.stage, SearchStage.online);
      expect(events.single.online, 'ONLINE');
    });

    test('no safe local answer and online fails -> surfaces the failure',
        () async {
      final events = await collect(coordinator(await engine()).run(
        generation: 1,
        rawText: 'rallies in absolutelynowhere',
        online: () => Future.delayed(
            const Duration(milliseconds: 200), () => throw StateError('boom')),
      ));
      expect(events.single.stage, SearchStage.onlineFailed);
    });

    test('online just inside the budget wins; just outside it falls back',
        () async {
      final inside = await collect(coordinator(
        await engine(),
        budget: const Duration(milliseconds: 300),
      ).run(
        generation: 1,
        rawText: 'rallies in ireland',
        online: () =>
            Future.delayed(const Duration(milliseconds: 60), () => 'ONLINE'),
      ));
      expect(inside.single.stage, SearchStage.online);

      final outside = await collect(coordinator(
        await engine(),
        budget: const Duration(milliseconds: 60),
      ).run(
        generation: 1,
        rawText: 'rallies in ireland',
        online: () =>
            Future.delayed(const Duration(milliseconds: 400), () => 'ONLINE'),
      ));
      expect(outside.first.stage, SearchStage.offlineFallback);
      expect(outside.last.stage, SearchStage.lateOnlineAvailable);
    });

    test('local and online completing together resolves to online', () async {
      // Both are ready effectively at once; the rule is that an online answer
      // inside the budget always wins, so the outcome is never a coin flip.
      for (var i = 0; i < 12; i++) {
        final events = await collect(coordinator(
          await engine(),
          budget: const Duration(milliseconds: 200),
        ).run(
          generation: 1,
          rawText: 'rallies in ireland',
          online: () async => 'ONLINE',
        ));
        expect(events.single.stage, SearchStage.online, reason: 'iteration $i');
      }
    });

    // `inMemoryDatabasePath` is shared within an isolate, so an "empty" local
    // store needs its own file to genuinely have no snapshot.
    Future<OfflineSearchEngine> emptyEngine() async {
      final dir = await Directory.systemTemp.createTemp('rally_empty_snapshot');
      final db = await OfflineDatabase.open(
        factory: databaseFactoryFfi,
        path: '${dir.path}/empty.db',
      );
      addTearDown(() async => dir.delete(recursive: true));
      return OfflineSearchEngine.create(db);
    }

    test('a stale/missing snapshot never fabricates a local answer', () async {
      final empty = await emptyEngine();
      expect(await empty.database.hasSnapshot(), isFalse);
      final events = await collect(
        SearchLatencyCoordinator<String>(
          connectivity: _FakeProbe(true),
          engine: empty,
          policy: const LatencyPolicy(
            onlineResultBudget: Duration(milliseconds: 40),
            overallOnlineTimeout: Duration(seconds: 5),
          ),
        ).run(
          generation: 1,
          rawText: 'rallies in ireland',
          online: () =>
              Future.delayed(const Duration(milliseconds: 200), () => 'ONLINE'),
        ),
      );
      expect(events.single.stage, SearchStage.online);
    });

    test('offline device with no snapshot reports failure, not a fake result',
        () async {
      final events = await collect(
        SearchLatencyCoordinator<String>(
          connectivity: _FakeProbe(false),
          engine: await emptyEngine(),
          policy: const LatencyPolicy(),
        ).run(
          generation: 1,
          rawText: 'rallies in ireland',
          online: () async => 'ONLINE',
        ),
      );
      expect(events.single.stage, SearchStage.onlineFailed);
    });

    test('no offline stack at all falls through to the online path', () async {
      final events = await collect(
        SearchLatencyCoordinator<String>(
          connectivity: null,
          engine: null,
          policy: const LatencyPolicy(
            onlineResultBudget: Duration(milliseconds: 30),
            overallOnlineTimeout: Duration(seconds: 5),
          ),
        ).run(
          generation: 1,
          rawText: 'rallies in ireland',
          online: () =>
              Future.delayed(const Duration(milliseconds: 150), () => 'ONLINE'),
        ),
      );
      expect(events.single.stage, SearchStage.online);
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
