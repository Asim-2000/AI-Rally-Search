import '../../../models/entity_candidate.dart';
import '../../database_service.dart';
import 'phonetic_matching_helper.dart';
import 'transliteration_helper.dart';

/// Abstract contract for database-backed entity candidate lookups.
abstract class IEntityLookupRepository {
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 25,
  });

  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    int limit = 25,
  });

  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 25,
  });

  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 25,
  });

  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 25,
  });
}

/// Production implementation of IEntityLookupRepository using AWS RDS MySQL via DatabaseService.
class DatabaseEntityLookupRepository implements IEntityLookupRepository {
  final DatabaseService _dbService;

  DatabaseEntityLookupRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Generates a robust SQL candidate matching clause incorporating exact,
  /// space-collapsed, transliterated, and token-level patterns.
  List<String> _buildCandidatePatterns(String phrase) {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final patterns = <String>{};
    final normalized = PhoneticMatchingHelper.normalize(clean);
    if (normalized.isNotEmpty) patterns.add(normalized);

    final collapsed = PhoneticMatchingHelper.collapseSpaces(clean);
    if (collapsed.isNotEmpty) patterns.add(collapsed);

    // Cross-script transliterations
    if (TransliterationHelper.isArabicOrUrdu(clean)) {
      final translits = TransliterationHelper.transliterateToLatin(clean);
      for (final t in translits) {
        final tNorm = PhoneticMatchingHelper.normalize(t);
        if (tNorm.isNotEmpty) patterns.add(tNorm);
        final tCollapsed = PhoneticMatchingHelper.collapseSpaces(t);
        if (tCollapsed.isNotEmpty) patterns.add(tCollapsed);
      }
    }

    // Significant token and prefix patterns (length >= 3)
    final tokens = normalized.split(' ').where((t) => t.length >= 3).toList();
    for (final token in tokens) {
      patterns.add(token);
      if (token.length >= 4) {
        patterns.add('${token.substring(0, 4)}%');
      }
    }

    return patterns.toList();
  }

  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 25,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final patterns = _buildCandidatePatterns(phrase);
    final patternClauses = <String>[];
    for (final p in patterns) {
      final pEscaped = p.replaceAll("'", "''").toLowerCase();
      if (pEscaped.endsWith('%')) {
        patternClauses.add("LOWER(ev.event_name) LIKE '$pEscaped'");
      } else {
        patternClauses.add("LOWER(ev.event_name) LIKE '%$pEscaped%'");
      }
      if (pEscaped.length >= 4 && !pEscaped.contains(' ') && !pEscaped.endsWith('%')) {
        patternClauses.add("REPLACE(LOWER(ev.event_name), ' ', '') LIKE '%$pEscaped%'");
      }
    }

    patternClauses.add("ev.event_id = '$clean'");

    final whereClauses = <String>['(${patternClauses.join(' OR ')})'];

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
    int limit = 25,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final patterns = _buildCandidatePatterns(phrase);
    final patternClauses = <String>[];
    for (final p in patterns) {
      final pEscaped = p.replaceAll("'", "''").toLowerCase();
      if (pEscaped.endsWith('%')) {
        patternClauses.add("LOWER(dp.full_name) LIKE '$pEscaped'");
      } else {
        patternClauses.add("LOWER(dp.full_name) LIKE '%$pEscaped%'");
      }
      if (pEscaped.length >= 4 && !pEscaped.contains(' ') && !pEscaped.endsWith('%')) {
        patternClauses.add("REPLACE(LOWER(dp.full_name), ' ', '') LIKE '%$pEscaped%'");
      }
    }

    patternClauses.add("LOWER(dp.nick_name) LIKE '%${clean.toLowerCase()}%'");

    final nameMatchSql = '(${patternClauses.join(' OR ')})';

    // If context (event or year) is provided, prioritize participants
    if (eventId != null || eventName != null || (year != null && year > 0)) {
      final contextClauses = <String>[nameMatchSql];
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
        LEFT JOIN rally_events ev ON rr.rally_id = ev.event_id
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
              'year': int.tryParse(yr ?? ''),
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
      WHERE $nameMatchSql
      ORDER BY 
        CASE 
          WHEN LOWER(dp.full_name) = '${clean.toLowerCase()}' THEN 1
          WHEN LOWER(dp.full_name) LIKE '${clean.toLowerCase()}%' THEN 2
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
    int limit = 25,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final cleanLower = clean.toLowerCase();
    final cleanNum = cleanLower.replaceAll('ss', '').replaceAll('stage', '').trim();

    final patterns = _buildCandidatePatterns(phrase);
    final patternClauses = <String>[];
    for (final p in patterns) {
      final pEscaped = p.replaceAll("'", "''").toLowerCase();
      patternClauses.add("LOWER(stg.stage_name) LIKE '%$pEscaped%'");
      if (pEscaped.length >= 4 && !pEscaped.contains(' ') && !pEscaped.endsWith('%')) {
        patternClauses.add("REPLACE(LOWER(stg.stage_name), ' ', '') LIKE '%$pEscaped%'");
      }
    }

    patternClauses.add("stg.stage_number = '$clean'");
    if (cleanNum.isNotEmpty) {
      patternClauses.add("stg.stage_number = '$cleanNum'");
    }

    final whereClauses = <String>['(${patternClauses.join(' OR ')})'];

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
    int limit = 25,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final cleanLower = clean.toLowerCase();
    final whereClauses = <String>[
      "LOWER(ev.city) LIKE '%$cleanLower%'",
      "ev.city IS NOT NULL",
      "TRIM(ev.city) != ''",
    ];

    if (country != null && country.trim().isNotEmpty && country.toUpperCase() != 'ALL') {
      final sanitizedCountry = country.trim().replaceAll("'", "''").toLowerCase();
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
      final cCountry = r['country']?.toString();

      return EntityCandidate(
        id: 'city_${city.toLowerCase().replaceAll(' ', '_')}',
        type: EntityType.city,
        canonicalName: city,
        subtitle: cCountry != null && cCountry.isNotEmpty ? cCountry.toUpperCase() : null,
        metadata: {
          'country': cCountry,
        },
      );
    }).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 25,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final cleanLower = clean.toLowerCase();
    final sql = '''
      SELECT 
        u.id,
        u.username,
        u.display_name,
        u.avatar_url
      FROM users u
      WHERE LOWER(u.username) LIKE '%$cleanLower%' 
         OR LOWER(u.display_name) LIKE '%$cleanLower%'
      LIMIT $limit;
    ''';

    final rows = await _dbService.query(sql);
    return rows.map((r) {
      final id = r['id']?.toString() ?? '';
      final username = r['username']?.toString() ?? '';
      final displayName = r['display_name']?.toString();

      return EntityCandidate(
        id: id,
        type: EntityType.uploader,
        canonicalName: displayName != null && displayName.isNotEmpty ? displayName : username,
        subtitle: '@$username',
        metadata: {
          'username': username,
        },
      );
    }).toList();
  }
}
