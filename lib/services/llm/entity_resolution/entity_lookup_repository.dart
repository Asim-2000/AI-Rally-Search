import '../../../models/entity_candidate.dart';
import '../../../models/search_query.dart';
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
    PersonRole personRole = PersonRole.any,
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

  /// Generates a bounded, high-recall list of candidate search patterns incorporating
  /// normalized full phrase, space-collapsed, descriptor-stripped stem, 3-char token prefixes,
  /// and end-anchors for long tokens.
  List<String> _buildCandidatePatterns(String phrase) {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final patterns = <String>{};
    final normalized = PhoneticMatchingHelper.normalize(clean);
    if (normalized.isNotEmpty) patterns.add(normalized);

    final collapsed = PhoneticMatchingHelper.collapseSpaces(clean);
    if (collapsed.isNotEmpty) patterns.add(collapsed);

    final coreStem = PhoneticMatchingHelper.stripDescriptors(normalized);
    if (coreStem.isNotEmpty && coreStem != normalized) {
      patterns.add(coreStem);
      final collapsedCore = PhoneticMatchingHelper.collapseSpaces(coreStem);
      if (collapsedCore.isNotEmpty) patterns.add(collapsedCore);
    }

    // Conservative acoustic-folded comparison representations
    final acousticNorm = PhoneticMatchingHelper.acousticFold(normalized);
    if (acousticNorm.isNotEmpty && acousticNorm != normalized) {
      patterns.add(acousticNorm);
    }
    final acousticCollapsed = PhoneticMatchingHelper.acousticFold(collapsed);
    if (acousticCollapsed.isNotEmpty && acousticCollapsed != collapsed) {
      patterns.add(acousticCollapsed);
    }

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

    // Token prefixes (length >= 3) and anchor fragments
    // Filter out generic motorsport words and years from standalone single-token patterns
    const genericWords = {
      'rally',
      'rallye',
      'rali',
      'rajd',
      'rallijsprints',
      'stage',
      'stages',
      'forestry',
      'championship',
      'series',
      'international',
      'regional',
    };

    final tokens = normalized.split(' ').where((t) => t.length >= 3).toList();
    if (tokens.length == 2) {
      patterns.add('${tokens[1]} ${tokens[0]}');
    }
    final distinctiveTokens = tokens
        .where(
          (t) => !genericWords.contains(t) && !RegExp(r'^\d{4}$').hasMatch(t),
        )
        .toList();
    final targetTokens = distinctiveTokens.isNotEmpty
        ? distinctiveTokens
        : tokens;

    // Prioritize distinctive tokens
    final orderedTokens = targetTokens.length > 1
        ? [
            targetTokens.last,
            ...targetTokens.sublist(0, targetTokens.length - 1),
          ]
        : targetTokens;

    for (final token in orderedTokens) {
      patterns.add(token);

      // Irish/Scottish O' / Mc / Mac prefix decomposition (e.g. oconnor -> connor, mcrae -> rae)
      if (token.startsWith('o') && token.length >= 5) {
        patterns.add(token.substring(1));
        patterns.add("o'${token.substring(1)}");
        patterns.add("o ${token.substring(1)}");
      } else if (token.startsWith('mc') && token.length >= 5) {
        patterns.add(token.substring(2));
      } else if (token.startsWith('mac') && token.length >= 6) {
        patterns.add(token.substring(3));
      }

      // 3-character & 4-character prefix for phonetic/orthographic tolerance
      if (token.length >= 3) {
        patterns.add(token.substring(0, 3));
      }
      if (token.length >= 4) {
        patterns.add(token.substring(0, 4));
      }

      // Generalized root stem for long words by trimming common phonetic/transcription tail (e.g. loncarich -> loncar, bogovich -> bogov)
      if (token.length >= 6) {
        patterns.add(token.substring(0, token.length - 2));
      }
      if (token.length >= 7) {
        patterns.add(token.substring(0, token.length - 3));
      }

      // Suffix/anchor fragment for long words (length >= 6) to catch prefix acoustic errors
      if (token.length >= 6) {
        final mid = token.substring(3);
        if (mid.length >= 3) {
          patterns.add(mid);
        }
      }
    }

    // Bounded internal character n-grams from collapsed and acoustic representations
    final ngrams = PhoneticMatchingHelper.generateNgramAnchors(
      collapsed,
      n: 3,
      maxAnchors: 4,
    );
    patterns.addAll(ngrams);
    if (acousticCollapsed != collapsed) {
      final acNgrams = PhoneticMatchingHelper.generateNgramAnchors(
        acousticCollapsed,
        n: 3,
        maxAnchors: 3,
      );
      patterns.addAll(acNgrams);
    }

    // Bounded budget: Return at most 12 most informative unique patterns
    return patterns.take(12).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 35,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final patterns = _buildCandidatePatterns(phrase);
    final patternClauses = <String>[];
    for (final p in patterns) {
      final pEscaped = p.replaceAll("'", "''").toLowerCase();
      patternClauses.add("LOWER(ev.event_name) LIKE '%$pEscaped%'");
      if (pEscaped.length >= 3 && !pEscaped.contains(' ')) {
        patternClauses.add(
          "REPLACE(LOWER(ev.event_name), ' ', '') LIKE '%$pEscaped%'",
        );
      }
    }

    patternClauses.add("ev.event_id = '$clean'");

    final whereClauses = <String>['(${patternClauses.join(' OR ')})'];

    if (year != null && year > 0) {
      whereClauses.add(
        "(YEAR(ev.start_date) = $year OR YEAR(ev.end_date) = $year)",
      );
    }

    if (country != null &&
        country.trim().isNotEmpty &&
        country.toUpperCase() != 'ALL') {
      final sanitizedCountry = country
          .trim()
          .replaceAll("'", "''")
          .toLowerCase();
      whereClauses.add("LOWER(ev.country) LIKE '%$sanitizedCountry%'");
    }

    if (city != null && city.trim().isNotEmpty && city.toUpperCase() != 'ALL') {
      final sanitizedCity = city.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    final normalized = PhoneticMatchingHelper.normalize(clean);
    final coreStem = PhoneticMatchingHelper.stripDescriptors(normalized);
    final distinctive = coreStem.isNotEmpty ? coreStem : normalized;
    final distEscaped = distinctive.replaceAll("'", "''").toLowerCase();

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql =
        '''
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
          WHEN LOWER(ev.event_name) LIKE '%$distEscaped%' THEN 3
          ELSE 4
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
    PersonRole personRole = PersonRole.any,
    int limit = 35,
  }) async {
    final clean = phrase.trim().replaceAll("'", "''");
    if (clean.isEmpty) return [];

    final patterns = _buildCandidatePatterns(phrase);
    final driverPatternClauses = <String>[];
    final codriverPatternClauses = <String>[];
    for (final p in patterns) {
      final pEscaped = p.replaceAll("'", "''").toLowerCase();
      driverPatternClauses.add("LOWER(dp.full_name) LIKE '%$pEscaped%'");
      codriverPatternClauses.add("LOWER(cdp.full_name) LIKE '%$pEscaped%'");
      if (pEscaped.length >= 3 && !pEscaped.contains(' ')) {
        driverPatternClauses.add(
          "REPLACE(LOWER(dp.full_name), ' ', '') LIKE '%$pEscaped%'",
        );
        codriverPatternClauses.add(
          "REPLACE(LOWER(cdp.full_name), ' ', '') LIKE '%$pEscaped%'",
        );
      }
    }

    driverPatternClauses.add(
      "LOWER(dp.nick_name) LIKE '%${clean.toLowerCase()}%'",
    );
    codriverPatternClauses.add(
      "LOWER(cdp.nick_name) LIKE '%${clean.toLowerCase()}%'",
    );

    final driverNameMatchSql = '(${driverPatternClauses.join(' OR ')})';
    final codriverNameMatchSql = '(${codriverPatternClauses.join(' OR ')})';

    final normalized = PhoneticMatchingHelper.normalize(clean);
    final tokens = normalized.split(' ').where((t) => t.length >= 3).toList();
    final surnameToken = tokens.isNotEmpty
        ? tokens.last.replaceAll("'", "''")
        : clean.replaceAll("'", "''");
    final surnamePrefix = surnameToken.length >= 3
        ? surnameToken.substring(0, 3)
        : surnameToken;

    final driverRankSql =
        '''
      CASE 
        WHEN LOWER(dp.full_name) = '${clean.toLowerCase()}' THEN 1
        WHEN LOWER(dp.full_name) LIKE '${clean.toLowerCase()}%' THEN 2
        WHEN LOWER(dp.full_name) LIKE '%$surnameToken%' THEN 3
        WHEN LOWER(dp.full_name) LIKE '%$surnamePrefix%' THEN 4
        ELSE 5
      END
    ''';

    final codriverRankSql =
        '''
      CASE 
        WHEN LOWER(cdp.full_name) = '${clean.toLowerCase()}' THEN 1
        WHEN LOWER(cdp.full_name) LIKE '${clean.toLowerCase()}%' THEN 2
        WHEN LOWER(cdp.full_name) LIKE '%$surnameToken%' THEN 3
        WHEN LOWER(cdp.full_name) LIKE '%$surnamePrefix%' THEN 4
        ELSE 5
      END
    ''';

    // If context (event or year) is provided, prioritize participants
    if (eventId != null || eventName != null || (year != null && year > 0)) {
      final driverContextClauses = <String>[driverNameMatchSql];
      final codriverContextClauses = <String>[codriverNameMatchSql];
      if (eventId != null && eventId.isNotEmpty) {
        final sanitizedEvId = eventId.replaceAll("'", "''");
        driverContextClauses.add("ev.event_id = '$sanitizedEvId'");
        codriverContextClauses.add("ev.event_id = '$sanitizedEvId'");
      } else if (eventName != null && eventName.isNotEmpty) {
        final sanitizedEv = eventName.replaceAll("'", "''").toLowerCase();
        driverContextClauses.add("LOWER(ev.event_name) LIKE '%$sanitizedEv%'");
        codriverContextClauses.add(
          "LOWER(ev.event_name) LIKE '%$sanitizedEv%'",
        );
      }
      if (year != null && year > 0) {
        driverContextClauses.add(
          "(YEAR(ev.start_date) = $year OR YEAR(ev.end_date) = $year)",
        );
        codriverContextClauses.add(
          "(YEAR(ev.start_date) = $year OR YEAR(ev.end_date) = $year)",
        );
      }

      final contextSql =
          '''
        (SELECT DISTINCT
          dp.driver_id AS id,
          dp.account_id,
          dp.full_name,
          dp.nick_name,
          dp.country,
          'driver' AS role,
          MAX(ev.event_name) AS participated_event,
          MAX(YEAR(ev.start_date)) AS event_year,
          $driverRankSql AS match_rank
        FROM user_driver_profile dp
        INNER JOIN rally_entry_list el ON el.user_driver_id = dp.driver_id
        INNER JOIN rally_sub_events se ON el.sub_event_id = se.sub_event_id
        INNER JOIN rally_events ev ON se.event_id = ev.event_id
        WHERE ${driverContextClauses.join(' AND ')}
        GROUP BY dp.driver_id, dp.account_id, dp.full_name, dp.nick_name, dp.country)
        UNION ALL
        (SELECT DISTINCT
          cdp.codriver_id AS id,
          cdp.account_id,
          cdp.full_name,
          cdp.nick_name,
          cdp.country,
          'co_driver' AS role,
          MAX(ev.event_name) AS participated_event,
          MAX(YEAR(ev.start_date)) AS event_year,
          $codriverRankSql AS match_rank
        FROM user_codriver_profile cdp
        INNER JOIN rally_entry_list el ON el.user_co_driver_id = cdp.codriver_id
        INNER JOIN rally_sub_events se ON el.sub_event_id = se.sub_event_id
        INNER JOIN rally_events ev ON se.event_id = ev.event_id
        WHERE ${codriverContextClauses.join(' AND ')}
        GROUP BY cdp.codriver_id, cdp.account_id, cdp.full_name, cdp.nick_name, cdp.country)
        ORDER BY match_rank ASC
        LIMIT 60;
      ''';

      final contextRows = await _dbService.query(contextSql);
      if (contextRows.isNotEmpty) {
        return await _mergeAndMapPersonCandidates(
          contextRows,
          inContext: true,
          cleanPhrase: clean,
          limit: limit,
        );
      }
    }

    // General lookup across BOTH user_driver_profile and user_codriver_profile
    final sql =
        '''
      (SELECT 
        dp.driver_id AS id,
        dp.account_id,
        dp.full_name,
        dp.nick_name,
        dp.country,
        'driver' AS role,
        NULL AS participated_event,
        NULL AS event_year,
        $driverRankSql AS match_rank
      FROM user_driver_profile dp
      WHERE $driverNameMatchSql
      ORDER BY match_rank ASC
      LIMIT 50)
      UNION ALL
      (SELECT 
        cdp.codriver_id AS id,
        cdp.account_id,
        cdp.full_name,
        cdp.nick_name,
        cdp.country,
        'co_driver' AS role,
        NULL AS participated_event,
        NULL AS event_year,
        $codriverRankSql AS match_rank
      FROM user_codriver_profile cdp
      WHERE $codriverNameMatchSql
      ORDER BY match_rank ASC
      LIMIT 50)
      ORDER BY match_rank ASC;
    ''';

    final rows = await _dbService.query(sql);
    return await _mergeAndMapPersonCandidates(
      rows,
      inContext: false,
      cleanPhrase: clean,
      limit: limit,
    );
  }

  /// Consolidates person rows from driver and co-driver tables into unified candidates.
  /// Uses account_id as the authoritative cross-role identity bridge.
  Future<List<EntityCandidate>> _mergeAndMapPersonCandidates(
    List<Map<String, dynamic>> rows, {
    required bool inContext,
    required String cleanPhrase,
    required int limit,
  }) async {
    // Collect all matched account_ids to discover cross-role profiles
    final matchedAccountIds = <String>{};
    for (final r in rows) {
      final acc = r['account_id']?.toString()?.trim();
      if (acc != null && acc.isNotEmpty && acc != 'null') {
        matchedAccountIds.add(acc);
      }
    }

    List<Map<String, dynamic>> allRows = List<Map<String, dynamic>>.from(rows);

    // If account_ids exist, query both user_driver_profile and user_codriver_profile for complete cross-role discovery
    if (matchedAccountIds.isNotEmpty) {
      final accIn = matchedAccountIds
          .map((a) => "'${a.replaceAll("'", "''")}'")
          .join(', ');
      final crossRoleSql =
          '''
        (SELECT 
          dp.driver_id AS id,
          dp.account_id,
          dp.full_name,
          dp.nick_name,
          dp.country,
          'driver' AS role,
          NULL AS participated_event,
          NULL AS event_year,
          1 AS match_rank
        FROM user_driver_profile dp
        WHERE dp.account_id IN ($accIn))
        UNION ALL
        (SELECT 
          cdp.codriver_id AS id,
          cdp.account_id,
          cdp.full_name,
          cdp.nick_name,
          cdp.country,
          'co_driver' AS role,
          NULL AS participated_event,
          NULL AS event_year,
          1 AS match_rank
        FROM user_codriver_profile cdp
        WHERE cdp.account_id IN ($accIn));
      ''';
      final crossRows = await _dbService.query(crossRoleSql);
      if (crossRows.isNotEmpty) {
        allRows.addAll(crossRows);
      }
    }

    // Group by account_id (authoritative) or normalized full_name fallback
    final merged = <String, Map<String, dynamic>>{};

    for (final r in allRows) {
      final name = r['full_name']?.toString()?.trim() ?? '';
      if (name.isEmpty) continue;
      final accountId = r['account_id']?.toString()?.trim();
      final hasAcc =
          accountId != null && accountId.isNotEmpty && accountId != 'null';
      final key = hasAcc ? 'acc:$accountId' : 'name:${name.toLowerCase()}';

      if (!merged.containsKey(key)) {
        final entry = Map<String, dynamic>.from(r);
        if (r['role'] == 'driver') {
          entry['driver_id'] = r['id'];
        } else if (r['role'] == 'co_driver') {
          entry['codriver_id'] = r['id'];
        }
        merged[key] = entry;
      } else {
        final existing = merged[key]!;
        final existingRole = existing['role']?.toString();
        final currentRole = r['role']?.toString();
        if (existingRole != null &&
            currentRole != null &&
            existingRole != currentRole) {
          existing['role'] = 'both';
        }
        if (currentRole == 'driver') {
          existing['driver_id'] = r['id'];
          // Preserve driver name if existing was empty
          if (existing['driver_name'] == null)
            existing['driver_name'] = r['full_name'];
        } else if (currentRole == 'co_driver') {
          existing['codriver_id'] = r['id'];
          if (existing['codriver_name'] == null)
            existing['codriver_name'] = r['full_name'];
        }
        if (r['participated_event'] != null) {
          existing['participated_event'] = r['participated_event'];
        }
        if (r['event_year'] != null) {
          existing['event_year'] = r['event_year'];
        }
      }
    }

    final candidates = merged.values.map((r) {
      final role = r['role']?.toString() ?? 'driver';
      final accountId = r['account_id']?.toString()?.trim();
      final driverId =
          r['driver_id']?.toString() ??
          (role == 'driver' ? r['id']?.toString() : null);
      final codriverId =
          r['codriver_id']?.toString() ??
          (role == 'co_driver' ? r['id']?.toString() : null);
      final id = driverId ?? codriverId ?? r['id']?.toString() ?? '';
      final name = r['full_name']?.toString() ?? '';
      final country = r['country']?.toString();
      final event = r['participated_event']?.toString();
      final yr = r['event_year']?.toString();

      final parts = <String>[];
      if (role == 'both') {
        parts.add('DRIVER / CO-DRIVER');
      } else if (role == 'co_driver') {
        parts.add('CO-DRIVER');
      } else {
        parts.add('DRIVER');
      }
      if (country != null && country.isNotEmpty)
        parts.add(country.toUpperCase());
      if (event != null && event.isNotEmpty) parts.add(event);
      if (yr != null && yr.isNotEmpty) parts.add(yr);

      return EntityCandidate(
        id: id,
        type: EntityType.driver,
        canonicalName: name,
        subtitle: parts.isNotEmpty ? parts.join(' • ') : null,
        metadata: {
          'country': country,
          'role': role,
          'accountId': accountId,
          'driverId': driverId,
          'codriverId': codriverId,
          'inContext': inContext,
          'year': int.tryParse(yr ?? ''),
          'matchRank': r['match_rank'],
        },
      );
    }).toList();

    // Sort by match rank first, then exact matches
    candidates.sort((a, b) {
      final aRank =
          int.tryParse(a.metadata?['matchRank']?.toString() ?? '') ?? 5;
      final bRank =
          int.tryParse(b.metadata?['matchRank']?.toString() ?? '') ?? 5;
      if (aRank != bRank) return aRank.compareTo(bRank);

      final aName = a.canonicalName.toLowerCase();
      final bName = b.canonicalName.toLowerCase();
      final target = cleanPhrase.toLowerCase();
      if (aName == target && bName != target) return -1;
      if (bName == target && aName != target) return 1;
      if (aName.startsWith(target) && !bName.startsWith(target)) return -1;
      if (bName.startsWith(target) && !aName.startsWith(target)) return 1;
      return 0;
    });

    return candidates.take(limit).toList();
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
    final cleanNum = cleanLower
        .replaceAll('ss', '')
        .replaceAll('stage', '')
        .trim();

    final patterns = _buildCandidatePatterns(phrase);
    final patternClauses = <String>[];
    for (final p in patterns) {
      final pEscaped = p.replaceAll("'", "''").toLowerCase();
      patternClauses.add("LOWER(stg.stage_name) LIKE '%$pEscaped%'");
      if (pEscaped.length >= 3 &&
          !pEscaped.contains(' ') &&
          !pEscaped.endsWith('%')) {
        patternClauses.add(
          "REPLACE(LOWER(stg.stage_name), ' ', '') LIKE '%$pEscaped%'",
        );
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
    final sql =
        '''
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

    if (country != null &&
        country.trim().isNotEmpty &&
        country.toUpperCase() != 'ALL') {
      final sanitizedCountry = country
          .trim()
          .replaceAll("'", "''")
          .toLowerCase();
      whereClauses.add("LOWER(ev.country) LIKE '%$sanitizedCountry%'");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql =
        '''
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
        subtitle: cCountry != null && cCountry.isNotEmpty
            ? cCountry.toUpperCase()
            : null,
        metadata: {'country': cCountry},
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
    final sql =
        '''
      SELECT 
        fp.fan_id AS id,
        ua.user_name AS username,
        fp.full_name,
        ua.email,
        fp.profile_picture
      FROM user_fan_profile fp
      LEFT JOIN user_account ua ON fp.account_id = ua.id
      WHERE LOWER(fp.full_name) LIKE '%$cleanLower%' 
         OR LOWER(ua.user_name) LIKE '%$cleanLower%'
         OR LOWER(ua.email) LIKE '%$cleanLower%'
      ORDER BY 
        CASE 
          WHEN LOWER(fp.full_name) = '$cleanLower' OR LOWER(ua.user_name) = '$cleanLower' THEN 1
          WHEN LOWER(fp.full_name) LIKE '$cleanLower%' OR LOWER(ua.user_name) LIKE '$cleanLower%' THEN 2
          ELSE 3
        END
      LIMIT $limit;
    ''';

    final rows = await _dbService.query(sql);
    return rows.map((r) {
      final id = r['id']?.toString() ?? '';
      final fullName = r['full_name']?.toString()?.trim();
      final username = r['username']?.toString()?.trim();
      final email = r['email']?.toString()?.trim();
      final profilePic = r['profile_picture']?.toString();

      final displayName = (username != null && username.isNotEmpty)
          ? username
          : ((fullName != null && fullName.isNotEmpty)
                ? fullName
                : ((email != null && email.isNotEmpty)
                      ? email
                      : 'Rally Contributor'));

      return EntityCandidate(
        id: id,
        type: EntityType.uploader,
        canonicalName: displayName,
        subtitle:
            (fullName != null && fullName.isNotEmpty && fullName != username)
            ? fullName
            : (username != null && username.isNotEmpty ? '@$username' : null),
        metadata: {
          'username': username,
          'fullName': fullName,
          'fanId': id,
          'profilePicture': profilePic,
        },
      );
    }).toList();
  }
}
