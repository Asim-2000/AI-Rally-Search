import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'offline_database.dart';

/// Fetches a raw snapshot payload for the given segment ('core' | 'full').
typedef SnapshotFetcher = Future<Map<String, dynamic>> Function(String segment);

enum SyncStatus { idle, inProgress, complete, failed }

class SyncResult {
  final SyncStatus status;
  final String? snapshotId;
  final Object? error;
  const SyncResult(this.status, {this.snapshotId, this.error});
}

/// Coordinates downloading the backend snapshot into local SQLite.
///
/// Triggers (see [maybeSync]): first online launch when no snapshot exists,
/// app foreground after a staleness threshold, manual refresh, and an
/// opportunistic refresh after a successful online search. It never polls.
class OfflineSnapshotSync {
  final OfflineDatabase database;
  final SnapshotFetcher fetcher;

  /// Staleness threshold before a foreground/opportunistic refresh is allowed.
  final Duration stalenessThreshold;

  /// Default segment for the mandatory bootstrap. 'core' is ~5 MB (no video
  /// metadata); 'full' adds video discovery (~37 MB on current data).
  final String defaultSegment;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  final _controller = StreamController<SyncResult>.broadcast();
  Stream<SyncResult> get updates => _controller.stream;

  OfflineSnapshotSync({
    required this.database,
    required this.fetcher,
    this.stalenessThreshold = const Duration(hours: 12),
    this.defaultSegment = 'core',
  });

  /// Builds a [SnapshotFetcher] that GETs `<base>/v1/offline/snapshot`.
  static SnapshotFetcher httpFetcher(
    Uri base, {
    http.Client? client,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 60),
  }) {
    final http.Client c = client ?? http.Client();
    return (segment) async {
      final uri = base.resolve('/v1/offline/snapshot').replace(queryParameters: {'segment': segment});
      final resp = await c.get(uri, headers: headers).timeout(timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw http.ClientException('snapshot HTTP ${resp.statusCode}', uri);
      }
      return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
    };
  }

  /// Runs a sync only if a trigger condition is met.
  Future<SyncResult> maybeSync({bool force = false, String? segment}) async {
    if (_status == SyncStatus.inProgress) {
      return const SyncResult(SyncStatus.inProgress);
    }
    if (!force) {
      final has = await database.hasSnapshot();
      if (has) {
        final last = await database.lastSyncUtc();
        final stale = last == null || DateTime.now().toUtc().difference(last) >= stalenessThreshold;
        if (!stale) return const SyncResult(SyncStatus.idle);
      }
    }
    return sync(segment: segment);
  }

  /// Forces a sync now. On failure the previous valid snapshot is preserved
  /// (import is atomic), and status transitions to [SyncStatus.failed].
  Future<SyncResult> sync({String? segment}) async {
    _emit(SyncStatus.inProgress);
    try {
      final payload = await fetcher(segment ?? defaultSegment);
      await database.importSnapshot(payload);
      final id = '${payload['snapshot_id'] ?? ''}';
      final result = SyncResult(SyncStatus.complete, snapshotId: id);
      _status = SyncStatus.complete;
      _controller.add(result);
      return result;
    } catch (e) {
      final result = SyncResult(SyncStatus.failed, error: e);
      _status = SyncStatus.failed;
      _controller.add(result);
      return result;
    }
  }

  void _emit(SyncStatus s) {
    _status = s;
    _controller.add(SyncResult(s));
  }

  void dispose() => _controller.close();
}
