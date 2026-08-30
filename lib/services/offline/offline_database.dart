import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'offline_entity_index.dart';
import 'offline_text_scoring.dart';

/// Raised when a snapshot payload cannot be imported (schema mismatch, missing
/// tables, count verification failure). The live DB is always left intact.
class OfflineSnapshotImportException implements Exception {
  final String message;
  const OfflineSnapshotImportException(this.message);
  @override
  String toString() => 'OfflineSnapshotImportException: $message';
}

/// Local read-only rally snapshot stored in SQLite (`sqflite`).
///
/// The device never touches MySQL and holds no secrets — this is a cache of the
/// public snapshot served by `GET /v1/offline/snapshot`. Imports are atomic: a
/// half-written snapshot never becomes the live database.
class OfflineDatabase {
  static const int schemaVersion = 1;

  final Database db;
  OfflineDatabase(this.db);

  /// Column definitions per snapshot table (SQLite DDL body).
  static const Map<String, String> _tableDdl = {
    'meta': 'key TEXT PRIMARY KEY, value TEXT',
    'rallies': 'event_id TEXT PRIMARY KEY, event_name TEXT, name_norm TEXT, country TEXT, '
        'city TEXT, year INTEGER, start_date TEXT, end_date TEXT, status TEXT, stages_count INTEGER',
    'people': 'person_id TEXT PRIMARY KEY, display_name TEXT, name_norm TEXT, searchable_names TEXT, '
        'role TEXT, driver_id TEXT, codriver_id TEXT, account_id TEXT, country TEXT',
    'stages': 'stage_id TEXT PRIMARY KEY, event_id TEXT, stage_name TEXT, name_norm TEXT, stage_number TEXT',
    'participation': 'event_id TEXT, person_id TEXT, driver_id TEXT, codriver_id TEXT, '
        'driver_name TEXT, role TEXT, PRIMARY KEY(event_id, person_id, role)',
    'final_results': 'id INTEGER PRIMARY KEY, event_id TEXT, driver_id TEXT, driver_name TEXT, pos_overall INTEGER',
    'driver_wins': 'person_id TEXT PRIMARY KEY, driver_id TEXT, driver_name TEXT, win_count INTEGER',
    'uploader_stats': 'uploader_id TEXT PRIMARY KEY, account_id TEXT, uploader_name TEXT, upload_count INTEGER',
    'video_meta': 'video_id INTEGER PRIMARY KEY, event_id TEXT, stage_id TEXT, person_id TEXT, '
        'driver_id TEXT, codriver_id TEXT, driver_name TEXT, event_name TEXT, stage_name TEXT, '
        'stage_number TEXT, thumbnail_url TEXT, on_demand_url TEXT, length_seconds REAL, created_at TEXT',
    'video_actions': 'id INTEGER PRIMARY KEY, video_id INTEGER, event_id TEXT, stage_id TEXT, person_id TEXT, '
        'driver_id TEXT, codriver_id TEXT, action_type TEXT, action_type_id INTEGER, driver_name TEXT, '
        'event_name TEXT, event_country TEXT, stage_name TEXT, stage_number TEXT, start_action REAL, '
        'end_action REAL, points REAL, thumbnail_url TEXT, on_demand_url TEXT',
  };

  static const List<String> _indexes = [
    'CREATE INDEX IF NOT EXISTS ix_rallies_country ON rallies(country)',
    'CREATE INDEX IF NOT EXISTS ix_rallies_year ON rallies(year)',
    'CREATE INDEX IF NOT EXISTS ix_part_person ON participation(person_id)',
    'CREATE INDEX IF NOT EXISTS ix_part_driver ON participation(driver_id)',
    'CREATE INDEX IF NOT EXISTS ix_part_codriver ON participation(codriver_id)',
    'CREATE INDEX IF NOT EXISTS ix_part_event ON participation(event_id)',
    'CREATE INDEX IF NOT EXISTS ix_final_event ON final_results(event_id)',
    'CREATE INDEX IF NOT EXISTS ix_final_driver ON final_results(driver_id)',
    'CREATE INDEX IF NOT EXISTS ix_vmeta_person ON video_meta(person_id)',
    'CREATE INDEX IF NOT EXISTS ix_vmeta_driver ON video_meta(driver_id)',
    'CREATE INDEX IF NOT EXISTS ix_vmeta_codriver ON video_meta(codriver_id)',
    'CREATE INDEX IF NOT EXISTS ix_vmeta_event ON video_meta(event_id)',
    'CREATE INDEX IF NOT EXISTS ix_vact_action ON video_actions(action_type)',
    'CREATE INDEX IF NOT EXISTS ix_vact_person ON video_actions(person_id)',
    'CREATE INDEX IF NOT EXISTS ix_vact_event ON video_actions(event_id)',
  ];

  static const List<String> tableNames = [
    'rallies', 'people', 'stages', 'participation', 'final_results',
    'driver_wins', 'uploader_stats', 'video_meta', 'video_actions',
  ];

  /// Opens (creating schema if needed) an OfflineDatabase at [path] using the
  /// supplied [factory] (sqflite on device, sqflite_common_ffi in tests).
  static Future<OfflineDatabase> open({
    required DatabaseFactory factory,
    required String path,
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (d) async => d.execute('PRAGMA foreign_keys = OFF'),
        onCreate: (d, version) async => _createSchema(d),
        onUpgrade: (d, oldVersion, newVersion) async => _createSchema(d),
      ),
    );
    await _createSchema(db); // idempotent — guarantees tables exist
    return OfflineDatabase(db);
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    for (final entry in _tableDdl.entries) {
      await db.execute('CREATE TABLE IF NOT EXISTS ${entry.key} (${entry.value})');
    }
    for (final ix in _indexes) {
      await db.execute(ix);
    }
  }

  Future<void> close() => db.close();

  // ---------------------------------------------------------------------------
  // Import (staging + verify + atomic promotion)
  // ---------------------------------------------------------------------------

  /// Validates and atomically imports a snapshot payload. Rows are written into
  /// per-table staging tables, verified against the payload counts, then promoted
  /// in a single transaction. Any failure rolls back and preserves the previous
  /// valid snapshot.
  Future<void> importSnapshot(Map<String, dynamic> snapshot) async {
    final schema = snapshot['schema_version'];
    if (schema is! int || schema != schemaVersion) {
      throw OfflineSnapshotImportException(
        'schema_version mismatch: got $schema, expected $schemaVersion',
      );
    }
    for (final t in tableNames) {
      if (snapshot[t] is! List) {
        throw OfflineSnapshotImportException('missing or invalid table "$t"');
      }
    }

    await db.transaction((txn) async {
      // 1) Build fresh staging tables.
      for (final t in tableNames) {
        await txn.execute('DROP TABLE IF EXISTS stg_$t');
        await txn.execute('CREATE TABLE stg_$t (${_tableDdl[t]})');
      }

      // 2) Populate staging.
      for (final t in tableNames) {
        final rows = (snapshot[t] as List).cast<Map>();
        final batch = txn.batch();
        for (final raw in rows) {
          batch.insert('stg_$t', _rowFor(t, Map<String, dynamic>.from(raw)),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }

      // 3) Verify staging counts vs payload.
      for (final t in tableNames) {
        final expected = (snapshot[t] as List).length;
        final got = Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM stg_$t'),
            ) ??
            -1;
        // Distinct primary keys may collapse duplicate rows; allow got <= expected.
        if (got > expected) {
          throw OfflineSnapshotImportException(
            'verification failed for "$t": staged $got > payload $expected',
          );
        }
      }

      // 4) Promote atomically: replace live tables from staging.
      for (final t in tableNames) {
        await txn.delete(t);
        await txn.execute('INSERT INTO $t SELECT * FROM stg_$t');
        await txn.execute('DROP TABLE stg_$t');
      }

      // 5) Persist snapshot bookkeeping.
      final meta = {
        'schema_version': '${snapshot['schema_version']}',
        'data_version': '${snapshot['data_version'] ?? ''}',
        'snapshot_id': '${snapshot['snapshot_id'] ?? ''}',
        'segment': '${snapshot['segment'] ?? 'full'}',
        'generated_at': '${snapshot['generated_at'] ?? ''}',
        'last_sync_utc': DateTime.now().toUtc().toIso8601String(),
      };
      for (final e in meta.entries) {
        await txn.insert('meta', {'key': e.key, 'value': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Map<String, Object?> _rowFor(String table, Map<String, dynamic> raw) {
    switch (table) {
      case 'rallies':
        return {
          'event_id': raw['event_id'],
          'event_name': raw['event_name'],
          'name_norm': OfflineTextScoring.normalize('${raw['event_name'] ?? ''}'),
          'country': raw['country'],
          'city': raw['city'],
          'year': raw['year'],
          'start_date': raw['start_date'],
          'end_date': raw['end_date'],
          'status': raw['status'],
          'stages_count': raw['stages_count'] ?? 0,
        };
      case 'people':
        final sn = raw['searchable_names'];
        return {
          'person_id': raw['person_id'],
          'display_name': raw['display_name'],
          'name_norm': OfflineTextScoring.normalize('${raw['display_name'] ?? ''}'),
          'searchable_names': sn is String ? sn : jsonEncode(sn ?? const []),
          'role': raw['role'],
          'driver_id': raw['driver_id'],
          'codriver_id': raw['codriver_id'],
          'account_id': raw['account_id'],
          'country': raw['country'],
        };
      case 'stages':
        return {
          'stage_id': raw['stage_id'],
          'event_id': raw['event_id'],
          'stage_name': raw['stage_name'],
          'name_norm': OfflineTextScoring.normalize('${raw['stage_name'] ?? ''}'),
          'stage_number': raw['stage_number'],
        };
      case 'participation':
        return {
          'event_id': raw['event_id'],
          'person_id': raw['person_id'],
          'driver_id': raw['driver_id'],
          'codriver_id': raw['codriver_id'],
          'driver_name': raw['driver_name'],
          'role': raw['role'],
        };
      case 'final_results':
        return {
          'id': raw['id'],
          'event_id': raw['event_id'],
          'driver_id': raw['driver_id'],
          'driver_name': raw['driver_name'],
          'pos_overall': raw['pos_overall'],
        };
      case 'driver_wins':
        return {
          'person_id': raw['person_id'],
          'driver_id': raw['driver_id'],
          'driver_name': raw['driver_name'],
          'win_count': raw['win_count'],
        };
      case 'uploader_stats':
        return {
          'uploader_id': raw['uploader_id'],
          'account_id': raw['account_id'],
          'uploader_name': raw['uploader_name'],
          'upload_count': raw['upload_count'],
        };
      case 'video_meta':
        return {
          'video_id': raw['video_id'],
          'event_id': raw['event_id'],
          'stage_id': raw['stage_id'],
          'person_id': raw['person_id'],
          'driver_id': raw['driver_id'],
          'codriver_id': raw['codriver_id'],
          'driver_name': raw['driver_name'],
          'event_name': raw['event_name'],
          'stage_name': raw['stage_name'],
          'stage_number': raw['stage_number'],
          'thumbnail_url': raw['thumbnail_url'],
          'on_demand_url': raw['on_demand_url'],
          'length_seconds': raw['length_seconds'],
          'created_at': raw['created_at'],
        };
      case 'video_actions':
        return {
          'id': raw['id'],
          'video_id': raw['video_id'],
          'event_id': raw['event_id'],
          'stage_id': raw['stage_id'],
          'person_id': raw['person_id'],
          'driver_id': raw['driver_id'],
          'codriver_id': raw['codriver_id'],
          'action_type': raw['action_type'],
          'action_type_id': raw['action_type_id'],
          'driver_name': raw['driver_name'],
          'event_name': raw['event_name'],
          'event_country': raw['event_country'],
          'stage_name': raw['stage_name'],
          'stage_number': raw['stage_number'],
          'start_action': raw['start_action'],
          'end_action': raw['end_action'],
          'points': raw['points'],
          'thumbnail_url': raw['thumbnail_url'],
          'on_demand_url': raw['on_demand_url'],
        };
      default:
        return raw;
    }
  }

  // ---------------------------------------------------------------------------
  // Metadata / status
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> meta() async {
    final rows = await db.query('meta');
    return {for (final r in rows) '${r['key']}': '${r['value']}'};
  }

  Future<bool> hasSnapshot() async {
    final m = await meta();
    if (m['snapshot_id'] == null || m['snapshot_id']!.isEmpty) return false;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM rallies')) ?? 0;
    return count > 0;
  }

  Future<DateTime?> lastSyncUtc() async {
    final v = (await meta())['last_sync_utc'];
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  // ---------------------------------------------------------------------------
  // Entity index construction
  // ---------------------------------------------------------------------------

  Future<OfflineEntityIndex> buildEntityIndex() async {
    final rallyRows = await db.query('rallies');
    final peopleRows = await db.query('people');
    final stageRows = await db.query('stages');
    final uploaderRows = await db.query('uploader_stats');

    final rallies = rallyRows
        .map((r) => OfflineEntity(
              type: OfflineEntityType.rally,
              canonicalId: '${r['event_id']}',
              canonicalName: '${r['event_name']}',
              year: r['year'] as int?,
              country: r['country'] as String?,
            ))
        .toList();

    final people = peopleRows.map((r) {
      final rawNames = r['searchable_names'];
      List<String> names;
      try {
        names = (jsonDecode('$rawNames') as List).map((e) => '$e').toList();
      } catch (_) {
        names = ['${r['display_name']}'];
      }
      if (names.isEmpty) names = ['${r['display_name']}'];
      return OfflineEntity(
        type: OfflineEntityType.person,
        canonicalId: '${r['person_id']}',
        canonicalName: '${r['display_name']}',
        searchableNames: names,
        country: r['country'] as String?,
        driverId: r['driver_id'] as String?,
        codriverId: r['codriver_id'] as String?,
        accountId: r['account_id'] as String?,
      );
    }).toList();

    final stages = stageRows
        .map((r) => OfflineEntity(
              type: OfflineEntityType.stage,
              canonicalId: '${r['stage_id']}',
              canonicalName: '${r['stage_name']}',
              eventId: r['event_id'] as String?,
              stageNumber: r['stage_number'] as String?,
            ))
        .toList();

    final uploaders = uploaderRows
        .map((r) => OfflineEntity(
              type: OfflineEntityType.uploader,
              canonicalId: '${r['uploader_id']}',
              canonicalName: '${r['uploader_name']}',
              accountId: r['account_id'] as String?,
            ))
        .toList();

    return OfflineEntityIndex(
      rallies: rallies,
      people: people,
      stages: stages,
      uploaders: uploaders,
    );
  }

  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? args]) =>
      db.rawQuery(sql, args);
}
