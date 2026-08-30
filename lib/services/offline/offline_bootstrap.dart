import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'offline_database.dart';
import 'offline_search_engine.dart';
import 'offline_search_router.dart';
import 'offline_snapshot_sync.dart';

/// Reachability signal backed by `connectivity_plus`. A best-effort hint only —
/// "has a network interface", not a guaranteed reachable backend.
class ConnectivityPlusProbe implements ConnectivityProbe {
  final Connectivity _connectivity;
  ConnectivityPlusProbe([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // If the probe fails, assume online so the authoritative path is tried.
      return true;
    }
  }
}

/// The initialised offline search stack handed to the UI.
class OfflineStack {
  final OfflineDatabase database;
  final OfflineSearchEngine engine;
  final OfflineSnapshotSync sync;
  final ConnectivityProbe connectivity;
  OfflineStack({required this.database, required this.engine, required this.sync, required this.connectivity});
}

/// Opens the local snapshot DB, performs a first/opportunistic sync when online,
/// then builds the deterministic offline engine. Fully guarded: any failure
/// returns null and the app runs online-only exactly as before.
class OfflineBootstrap {
  static Future<OfflineStack?> initialize({required Uri? backendBaseUrl}) async {
    if (backendBaseUrl == null) return null;
    try {
      final path = '${await getDatabasesPath()}/offline_rally.db';
      final db = await OfflineDatabase.open(factory: databaseFactory, path: path);
      final sync = OfflineSnapshotSync(
        database: db,
        fetcher: OfflineSnapshotSync.httpFetcher(backendBaseUrl),
      );
      final probe = ConnectivityPlusProbe();

      // First online launch / staleness: fetch the snapshot before building the
      // entity index so the index reflects the freshest data available.
      if (await probe.isOnline()) {
        await sync.maybeSync();
      }

      final engine = await OfflineSearchEngine.create(db);
      return OfflineStack(database: db, engine: engine, sync: sync, connectivity: probe);
    } catch (_) {
      return null;
    }
  }
}
