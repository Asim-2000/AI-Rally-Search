import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/offline/offline_search_engine.dart';

/// A minimal snapshot with one Irish rally, distinct by name from anything the
/// fake online repository returns.
Map<String, dynamic> irelandSnapshot() => {
      'schema_version': 1,
      'data_version': 'v1',
      'snapshot_id': '1-v1-core',
      'segment': 'core',
      'generated_at': '2026-08-30T00:00:00Z',
      'rallies': <Map<String, Object?>>[
        {
          'event_id': 'ev1',
          'event_name': 'Rally Alpha 2025',
          'country': 'Ireland',
          'city': 'Cork',
          'year': 2025,
          'start_date': '2025-05-01',
          'end_date': null,
          'status': null,
          'stages_count': 3,
        },
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

Future<OfflineSearchEngine> offlineEngine(OfflineDatabase db) =>
    OfflineSearchEngine.create(db);
