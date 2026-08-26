import '../../../models/entity_candidate.dart';
import '../../database_service.dart';

/// Abstract contract for database-backed entity candidate lookups.
abstract class IEntityLookupRepository {
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 10,
  });

  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    int limit = 10,
  });

  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 10,
  });

  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 10,
  });

  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 10,
  });
}

/// Production implementation of IEntityLookupRepository using AWS RDS MySQL via DatabaseService.
class DatabaseEntityLookupRepository implements IEntityLookupRepository {
  final DatabaseService _dbService;

  DatabaseEntityLookupRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 10,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final whereClauses = <String>[
      "(LOWER(ev.event_name) LIKE '%${clean.toLowerCase()}%' OR ev.event_id = '$clean')"
    ];

    if (year != null && year > 0) {
      whereClauses.add("(YEAR(ev.start_date) = $year OR YEAR(ev.end_date) = $year)");
    }

    if (country != null && country.trim().isNotEmpty && country.toUpperCase() != 'ALL') {
      final sanitizedCountry = country.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.country) LIKE '%$sanitizedCountry%'");
    }

    if (city != null && city.trim().isNotEmpty && city.toUpperCase() != 'ALL') {
      final sanitizedCity = city.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        ev.event_id,
        ev.event_name,
        ev.country,
        ev.city,
        YEAR(ev.start_date) AS event_year,
        ev.start_date
      FROM rally_events ev
      $whereSql
      ORDER BY 
        CASE 
          WHEN LOWER(ev.event_name) = '${clean.toLowerCase()}' THEN 1
          WHEN LOWER(ev.event_name) LIKE '${clean.toLowerCase()}%' THEN 2
          ELSE 3
        END,
        ev.start_date DESC
      LIMIT $limit;
    ''';

    final rows = await _dbService.query(sql);
    return rows.map((r) {
      final eventId = r['event_id']?.toString() ?? '';
      final name = r['event_name']?.toString() ?? '';
      final cCountry = r['country']?.toString();
      final cCity = r['city']?.toString();
      final cYear = r['event_year']?.toString();

      final parts = <String>[];
      if (cCountry != null && cCountry.isNotEmpty) parts.add(cCountry);
      if (cCity != null && cCity.isNotEmpty) parts.add(cCity);
      if (cYear != null && cYear.isNotEmpty) parts.add(cYear);

      return EntityCandidate(
        id: eventId,
        type: EntityType.rally,
        canonicalName: name,
        subtitle: parts.isNotEmpty ? parts.join(' • ') : null,
        metadata: {
          'country': cCountry,
          'city': cCity,
          'year': int.tryParse(cYear ?? ''),
        },
      );
    }).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    int limit = 10,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final cleanLower = clean.toLowerCase();

    // If context (event or year) is provided, prioritize participants
    if (eventId != null || eventName != null || (year != null && year > 0)) {
      final contextClauses = <String>[
        "(LOWER(dp.full_name) LIKE '%$cleanLower%' OR LOWER(dp.nick_name) LIKE '%$cleanLower%' OR LOWER(rr.crew) LIKE '%$cleanLower%')"
      ];
      if (eventId != null && eventId.isNotEmpty) {
        contextClauses.add("ev.event_id = '${eventId.replaceAll("'", "''")}'");
      } else if (eventName != null && eventName.isNotEmpty) {
        final sanitizedEv = eventName.replaceAll("'", "''").toLowerCase();
        contextClauses.add("LOWER(ev.event_name) LIKE '%$sanitizedEv%'");
      }
      if (year != null && year > 0) {
        contextClauses.add("(YEAR(ev.start_date) = $year OR YEAR(ev.end_date) = $year)");
      }

      final contextSql = '''
        SELECT DISTINCT
          dp.driver_id,
          dp.full_name,
          dp.nick_name,
          dp.country,
          MAX(ev.event_name) AS participated_event,
          MAX(YEAR(ev.start_date)) AS event_year
        FROM user_driver_profile dp
        INNER JOIN rally_entry_list el ON el.user_driver_id = dp.driver_id
        LEFT JOIN rally_results rr ON rr.entry_list_id = el.id
        LEFT JOIN rally_events ev ON (rr.rally_id = ev.event_id OR el.event_id = ev.event_id)
        WHERE ${contextClauses.join(' AND ')}
        GROUP BY dp.driver_id, dp.full_name, dp.nick_name, dp.country
        LIMIT $limit;
      ''';

      final contextRows = await _dbService.query(contextSql);
      if (contextRows.isNotEmpty) {
        return contextRows.map((r) {
          final id = r['driver_id']?.toString() ?? '';
          final name = r['full_name']?.toString() ?? '';
          final country = r['country']?.toString();
          final event = r['participated_event']?.toString();
          final yr = r['event_year']?.toString();

          final parts = <String>[];
          if (country != null && country.isNotEmpty) parts.add(country.toUpperCase());
          if (event != null && event.isNotEmpty) parts.add(event);
          if (yr != null && yr.isNotEmpty) parts.add(yr);

          return EntityCandidate(
            id: id,
            type: EntityType.driver,
            canonicalName: name,
            subtitle: parts.isNotEmpty ? parts.join(' • ') : null,
            metadata: {
              'country': country,
              'inContext': true,
            },
          );
        }).toList();
      }
    }

    // General driver lookup across user_driver_profile
    final sql = '''
      SELECT 
        dp.driver_id,
        dp.full_name,
        dp.nick_name,
        dp.country
      FROM user_driver_profile dp
      WHERE LOWER(dp.full_name) LIKE '%$cleanLower%' 
         OR LOWER(dp.nick_name) LIKE '%$cleanLower%'
      ORDER BY 
        CASE 
          WHEN LOWER(dp.full_name) = '$cleanLower' THEN 1
          WHEN LOWER(dp.full_name) LIKE '$cleanLower%' THEN 2
          ELSE 3
        END
      LIMIT $limit;
    ''';

    final rows = await _dbService.query(sql);
    return rows.map((r) {
      final id = r['driver_id']?.toString() ?? '';
      final name = r['full_name']?.toString() ?? '';
      final country = r['country']?.toString();

      return EntityCandidate(
        id: id,
        type: EntityType.driver,
        canonicalName: name,
        subtitle: country != null && country.isNotEmpty ? country.toUpperCase() : null,
        metadata: {
          'country': country,
          'inContext': false,
        },
      );
    }).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 10,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final cleanLower = clean.toLowerCase();
    final cleanNum = cleanLower.replaceAll('ss', '').replaceAll('stage', '').trim();

    final whereClauses = <String>[
      "(LOWER(stg.stage_name) LIKE '%$cleanLower%' OR stg.stage_number = '$clean' OR stg.stage_number = '$cleanNum')"
    ];

    if (eventId != null && eventId.isNotEmpty) {
      whereClauses.add("stg.event_id = '${eventId.replaceAll("'", "''")}'");
    } else if (eventName != null && eventName.isNotEmpty) {
      final sanitizedEv = eventName.replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.event_name) LIKE '%$sanitizedEv%'");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        stg.stage_id,
        stg.stage_name,
        stg.stage_number,
        stg.event_id,
        ev.event_name
      FROM rally_stages stg
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      $whereSql
      ORDER BY 
        CASE 
          WHEN LOWER(stg.stage_name) = '$cleanLower' THEN 1
          WHEN LOWER(stg.stage_name) LIKE '$cleanLower%' THEN 2
          ELSE 3
        END
      LIMIT $limit;
    ''';

    final rows = await _dbService.query(sql);
    return rows.map((r) {
      final stageId = r['stage_id']?.toString() ?? '';
      final stageName = r['stage_name']?.toString() ?? '';
      final stageNum = r['stage_number']?.toString();
      final evName = r['event_name']?.toString();
      final evId = r['event_id']?.toString();

      final parts = <String>[];
      if (evName != null && evName.isNotEmpty) parts.add(evName);
      if (stageNum != null && stageNum.isNotEmpty) parts.add('SS$stageNum');

      return EntityCandidate(
        id: stageId,
        type: EntityType.stage,
        canonicalName: stageName,
        subtitle: parts.isNotEmpty ? parts.join(' • ') : null,
        metadata: {
          'stageNumber': stageNum,
          'eventId': evId,
          'eventName': evName,
        },
      );
    }).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 10,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final cleanLower = clean.toLowerCase();
    final whereClauses = <String>[
      "ev.city IS NOT NULL AND ev.city != '' AND LOWER(ev.city) LIKE '%$cleanLower%'"
    ];

    if (country != null && country.isNotEmpty && country.toUpperCase() != 'ALL') {
      final sanitizedCountry = country.replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.country) LIKE '%$sanitizedCountry%'");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT DISTINCT 
        ev.city,
        ev.country
      FROM rally_events ev
      $whereSql
      LIMIT $limit;
    ''';

    final rows = await _dbService.query(sql);
    return rows.map((r) {
      final city = r['city']?.toString() ?? '';
      final ctry = r['country']?.toString();

      return EntityCandidate(
        id: city,
        type: EntityType.city,
        canonicalName: city,
        subtitle: ctry,
        metadata: {
          'country': ctry,
        },
      );
    }).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 10,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final cleanLower = clean.toLowerCase();
    final sql = '''
      SELECT DISTINCT 
        ua.id AS user_id,
        COALESCE(ua.user_name, ua.email) AS uploader_name,
        COUNT(rv.id) AS video_count
      FROM user_account ua
      INNER JOIN rally_videos rv ON rv.uploader_user_id = ua.id
      WHERE LOWER(ua.user_name) LIKE '%$cleanLower%' OR LOWER(ua.email) LIKE '%$cleanLower%'
      GROUP BY ua.id, ua.user_name, ua.email
      ORDER BY video_count DESC
      LIMIT $limit;
    ''';

    final rows = await _dbService.query(sql);
    return rows.map((r) {
      final id = r['user_id']?.toString() ?? '';
      final name = r['uploader_name']?.toString() ?? '';
      final count = r['video_count']?.toString();

      return EntityCandidate(
        id: id,
        type: EntityType.uploader,
        canonicalName: name,
        subtitle: count != null ? '$count videos' : null,
      );
    }).toList();
  }
}
