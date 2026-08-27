import '../database_service.dart';
import 'entity_search_models.dart';
import 'entity_search_service.dart';

/// Startup snapshot loader. MySQL remains authoritative; no search SQL or
/// schema detail leaks through [IEntitySearchService].
class MySqlEntitySearchDataSource implements IEntitySearchDataSource {
  final DatabaseService database;

  MySqlEntitySearchDataSource({DatabaseService? database})
    : database = database ?? DatabaseService();

  @override
  Future<List<CanonicalSearchEntity>> loadEntities() async {
    // Keep reads sequential: DatabaseService intentionally owns one connection.
    final batches = <List<Map<String, dynamic>>>[
      await database.query('''
        SELECT event_id, event_name, country, city,
               YEAR(start_date) AS event_year
        FROM rally_events
        WHERE event_name IS NOT NULL AND TRIM(event_name) <> '';
      '''),
      await database.query('''
        SELECT account_id, driver_id AS profile_id, full_name, country,
               'driver' AS person_role
        FROM user_driver_profile
        WHERE account_id IS NOT NULL AND full_name IS NOT NULL AND TRIM(full_name) <> ''
        UNION ALL
        SELECT account_id, codriver_id AS profile_id, full_name, country,
               'co_driver' AS person_role
        FROM user_codriver_profile
        WHERE account_id IS NOT NULL AND full_name IS NOT NULL AND TRIM(full_name) <> '';
      '''),
      await database.query('''
        SELECT stg.stage_id, stg.stage_name, stg.stage_number, stg.event_id,
               ev.event_name
        FROM rally_stages stg
        LEFT JOIN rally_events ev ON ev.event_id = stg.event_id
        WHERE stg.stage_name IS NOT NULL AND TRIM(stg.stage_name) <> '';
      '''),
      await database.query('''
        SELECT fp.fan_id, fp.account_id, ua.user_name, fp.full_name, ua.email
        FROM user_fan_profile fp
        LEFT JOIN user_account ua ON ua.id = fp.account_id
        WHERE COALESCE(NULLIF(TRIM(ua.user_name), ''),
                       NULLIF(TRIM(fp.full_name), ''),
                       NULLIF(TRIM(ua.email), '')) IS NOT NULL;
      '''),
    ];

    final entities = <CanonicalSearchEntity>[];
    for (final row in batches[0]) {
      entities.add(
        CanonicalSearchEntity(
          canonicalId: row['event_id']?.toString() ?? '',
          canonicalName: row['event_name']?.toString() ?? '',
          entityType: SearchEntityType.rally,
          metadata: {
            'eventId': row['event_id']?.toString(),
            'year': int.tryParse(row['event_year']?.toString() ?? ''),
            'country': row['country']?.toString(),
            'city': row['city']?.toString(),
          },
        ),
      );
    }

    // One identity per account, even if the account owns both profile types.
    final people = <String, Map<String, Object?>>{};
    for (final row in batches[1]) {
      final accountId = row['account_id']?.toString() ?? '';
      if (accountId.isEmpty) continue;
      final current = people.putIfAbsent(
        accountId,
        () => {
          'name': row['full_name']?.toString() ?? '',
          'country': row['country']?.toString(),
          'role': row['person_role']?.toString(),
        },
      );
      if (row['person_role'] == 'driver') {
        current['driverId'] = row['profile_id']?.toString();
      } else {
        current['codriverId'] = row['profile_id']?.toString();
      }
      if (current['driverId'] != null && current['codriverId'] != null) {
        current['role'] = 'both';
      }
    }
    for (final entry in people.entries) {
      entities.add(
        CanonicalSearchEntity(
          canonicalId: entry.key,
          canonicalName: entry.value['name']?.toString() ?? '',
          entityType: SearchEntityType.person,
          metadata: {'accountId': entry.key, ...entry.value},
        ),
      );
    }

    for (final row in batches[2]) {
      entities.add(
        CanonicalSearchEntity(
          canonicalId: row['stage_id']?.toString() ?? '',
          canonicalName: row['stage_name']?.toString() ?? '',
          entityType: SearchEntityType.stage,
          metadata: {
            'stageId': row['stage_id']?.toString(),
            'stageNumber': row['stage_number']?.toString(),
            'eventId': row['event_id']?.toString(),
            'eventName': row['event_name']?.toString(),
          },
        ),
      );
    }
    for (final row in batches[3]) {
      final username = row['user_name']?.toString().trim() ?? '';
      final fullName = row['full_name']?.toString().trim() ?? '';
      final email = row['email']?.toString().trim() ?? '';
      entities.add(
        CanonicalSearchEntity(
          canonicalId: row['fan_id']?.toString() ?? '',
          canonicalName: username.isNotEmpty
              ? username
              : (fullName.isNotEmpty ? fullName : email),
          entityType: SearchEntityType.uploader,
          metadata: {
            'fanId': row['fan_id']?.toString(),
            'accountId': row['account_id']?.toString(),
            'username': username,
            'fullName': fullName,
          },
        ),
      );
    }
    return entities;
  }
}
