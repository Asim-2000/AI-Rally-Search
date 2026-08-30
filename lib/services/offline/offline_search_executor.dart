import '../../models/search_intent.dart';
import '../../models/search_query.dart';
import '../../models/search_results.dart';
import '../../models/video_action.dart';
import 'offline_database.dart';

/// Executes a resolved [SearchQuery] over the local SQLite snapshot using nine
/// fixed, parameterised strategies — one per intent. There is NO dynamic SQL
/// generated from free text. Semantics mirror `search_repository.py`
/// (OR within a dimension, AND across dimensions; country-alias expansion;
/// pre-computed `final_results` for wins/classification) so offline results
/// match the authoritative online results for the same query.
class OfflineSearchExecutor {
  final OfflineDatabase database;
  const OfflineSearchExecutor(this.database);

  // Country alias expansion, ported verbatim from backend/app/repositories/sql.py.
  static const Map<String, List<String>> _countries = {
    'ireland': ['ireland', 'ie', 'irl', 'republic of ireland'],
    'portugal': ['portugal', 'pt', 'prt'],
    'united kingdom': ['united kingdom', 'uk', 'gb', 'gbr', 'great britain', 'england', 'scotland', 'wales'],
    'france': ['france', 'fr', 'fra'],
    'austria': ['austria', 'at', 'aut'],
    'norway': ['norway', 'no', 'nor'],
    'poland': ['poland', 'pl', 'pol'],
    'belgium': ['belgium', 'be', 'bel'],
    'spain': ['spain', 'es', 'esp'],
    'italy': ['italy', 'it', 'ita'],
    'latvia': ['latvia', 'lv', 'lva'],
    'czech republic': ['czech republic', 'cz', 'cze', 'czechia'],
    'germany': ['germany', 'de', 'deu'],
    'kenya': ['kenya', 'ke', 'ken'],
    'croatia': ['croatia', 'hr', 'hrv'],
    'netherlands': ['netherlands', 'nl', 'nld', 'holland'],
    'new zealand': ['new zealand', 'nz', 'nzl'],
    'lithuania': ['lithuania', 'lt', 'ltu'],
    'slovakia': ['slovakia', 'sk', 'svk'],
    'qatar': ['qatar', 'qa', 'qat'],
    'pakistan': ['pakistan', 'pk', 'pak'],
    'barbados': ['barbados', 'bb', 'brb'],
    'sweden': ['sweden', 'se', 'swe'],
    'finland': ['finland', 'fi', 'fin'],
    'estonia': ['estonia', 'ee', 'est'],
  };

  static List<String> _expandCountry(String clean) {
    for (final e in _countries.entries) {
      if (e.key == clean || e.value.contains(clean)) return e.value;
    }
    return [clean];
  }

  Future<SearchResponse<dynamic>> execute(SearchQuery q) async {
    switch (q.intent) {
      case SearchIntent.searchRallies:
        return _rallies(q);
      case SearchIntent.searchDriverRallies:
        return _participations(q);
      case SearchIntent.searchDriverWins:
        return _driverWins(q);
      case SearchIntent.getRallyResults:
        return _rallyResults(q, single: true);
      case SearchIntent.getRallyTopFinishers:
        return _rallyResults(q, single: false);
      case SearchIntent.searchVideoActions:
        return _videoActions(q);
      case SearchIntent.searchDriverVideos:
        return _driverVideos(q);
      case SearchIntent.getTopUploaders:
        return _topUploaders(q);
      case SearchIntent.getTopDriversByWins:
        return _topDrivers(q);
    }
  }

  // --- WHERE fragment helpers ---------------------------------------------

  /// Country/city/year/rally-name filter over a rallies alias -> (clauses, args).
  ({List<String> clauses, List<Object?> args}) _rallyFilters(SearchQuery q, String r) {
    final clauses = <String>[];
    final args = <Object?>[];

    // Country dimension (OR).
    final aliases = <String>{};
    for (final c in q.countries) {
      final clean = c.trim().toLowerCase();
      if (clean == 'all' || clean.isEmpty) continue;
      aliases.addAll(_expandCountry(clean));
    }
    final countryExpr = <String>[];
    for (final a in aliases) {
      countryExpr.add('LOWER($r.country) = ?');
      args.add(a);
    }
    for (final c in q.countries) {
      final clean = c.trim();
      if (clean.length > 2 && clean.toUpperCase() != 'ALL') {
        countryExpr.add('LOWER($r.country) LIKE ?');
        args.add('%${clean.toLowerCase()}%');
      }
    }
    if (countryExpr.isNotEmpty) clauses.add('(${countryExpr.join(' OR ')})');

    // City dimension.
    final cityExpr = <String>[];
    for (final c in q.cities) {
      if (c.toUpperCase() == 'ALL') continue;
      cityExpr.add('LOWER($r.city) LIKE ?');
      args.add('%${c.toLowerCase()}%');
    }
    if (cityExpr.isNotEmpty) clauses.add('(${cityExpr.join(' OR ')})');

    // Year dimension.
    final yearExpr = <String>[];
    for (final y in q.years) {
      yearExpr.add('$r.year = ?');
      args.add(y);
    }
    if (q.yearFrom != null && q.yearTo != null) {
      yearExpr.add('$r.year BETWEEN ? AND ?');
      args.addAll([q.yearFrom, q.yearTo]);
    } else if (q.yearFrom != null) {
      yearExpr.add('$r.year >= ?');
      args.add(q.yearFrom);
    } else if (q.yearTo != null) {
      yearExpr.add('$r.year <= ?');
      args.add(q.yearTo);
    }
    if (yearExpr.isNotEmpty) clauses.add('(${yearExpr.join(' OR ')})');

    // Rally name / id dimension.
    final nameExpr = <String>[];
    for (final name in q.targetRallyNames) {
      nameExpr.add('(LOWER($r.event_name) LIKE ? OR $r.event_id = ?)');
      args.add('%${name.toLowerCase()}%');
      args.add(name.toLowerCase());
    }
    if (nameExpr.isNotEmpty) clauses.add('(${nameExpr.join(' OR ')})');

    return (clauses: clauses, args: args);
  }

  /// Person filter against driver_id / codriver_id columns -> (clause, args).
  ({String? clause, List<Object?> args}) _personFilter(SearchQuery q,
      {String driverCol = 'driver_id', String codriverCol = 'codriver_id', bool driverOnly = false}) {
    final exprs = <String>[];
    final args = <Object?>[];
    for (final id in q.driverIds) {
      if (driverOnly) {
        exprs.add('$driverCol = ?');
        args.add(id);
        continue;
      }
      switch (q.personRole) {
        case PersonRole.driver:
          exprs.add('$driverCol = ?');
          args.add(id);
          break;
        case PersonRole.coDriver:
          exprs.add('$codriverCol = ?');
          args.add(id);
          break;
        case PersonRole.any:
          exprs.add('($driverCol = ? OR $codriverCol = ?)');
          args.addAll([id, id]);
          break;
      }
    }
    for (final name in q.driverNames) {
      exprs.add('LOWER(driver_name) LIKE ?');
      args.add('%${name.toLowerCase()}%');
    }
    if (exprs.isEmpty) return (clause: null, args: <Object?>[]);
    return (clause: '(${exprs.join(' OR ')})', args: args);
  }

  /// event_id IN (rally-filtered) sub-clause for video/classification scoping.
  ({String? clause, List<Object?> args}) _eventScope(SearchQuery q, String col) {
    final rf = _rallyFilters(q, 'r');
    if (rf.clauses.isEmpty) return (clause: null, args: <Object?>[]);
    final where = rf.clauses.join(' AND ');
    return (clause: '$col IN (SELECT event_id FROM rallies r WHERE $where)', args: rf.args);
  }

  // --- Strategies ----------------------------------------------------------

  Future<SearchResponse<dynamic>> _rallies(SearchQuery q) async {
    final rf = _rallyFilters(q, 'rallies');
    final clauses = [...rf.clauses];
    final args = [...rf.args];

    // Driver participation filter.
    final pf = _personFilter(q, driverCol: 'driver_id', codriverCol: 'codriver_id');
    if (pf.clause != null) {
      clauses.add('event_id IN (SELECT event_id FROM participation WHERE ${pf.clause})');
      args.addAll(pf.args);
    }

    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final total = await _count('SELECT COUNT(*) FROM rallies $where', args);
    final rows = await database.rawQuery(
      'SELECT event_id, event_name, status, country, city, start_date, end_date, stages_count, year '
      'FROM rallies $where ORDER BY (start_date IS NULL), start_date DESC LIMIT ? OFFSET ?',
      [...args, q.limit, q.offset],
    );
    return _decode(SearchIntent.searchRallies, rows, total, q);
  }

  Future<SearchResponse<dynamic>> _participations(SearchQuery q) async {
    final clauses = <String>[];
    final args = <Object?>[];
    final pf = _personFilter(q);
    if (pf.clause != null) {
      clauses.add(pf.clause!);
      args.addAll(pf.args);
    }
    final rf = _rallyFilters(q, 'r');
    clauses.addAll(rf.clauses);
    args.addAll(rf.args);

    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final base = 'FROM participation p JOIN rallies r ON p.event_id = r.event_id $where';
    final total = await _count('SELECT COUNT(DISTINCT p.event_id) $base', args);
    final rows = await database.rawQuery(
      'SELECT p.event_id AS rally_id, r.event_name, p.person_id, p.driver_name, p.role, '
      'NULL AS pos_overall, r.country, r.city, r.start_date '
      '$base ORDER BY (r.start_date IS NULL), r.start_date DESC LIMIT ? OFFSET ?',
      [...args, q.limit, q.offset],
    );
    return _decode(SearchIntent.searchDriverRallies, rows, total, q);
  }

  Future<SearchResponse<dynamic>> _driverWins(SearchQuery q) async {
    final clauses = <String>['f.pos_overall = 1'];
    final args = <Object?>[];
    final pf = _personFilter(q, driverOnly: true);
    if (pf.clause != null) {
      clauses.add(pf.clause!);
      args.addAll(pf.args);
    }
    final rf = _rallyFilters(q, 'r');
    clauses.addAll(rf.clauses);
    args.addAll(rf.args);
    final where = 'WHERE ${clauses.join(' AND ')}';
    final base = 'FROM final_results f JOIN rallies r ON f.event_id = r.event_id $where';
    final total = await _count('SELECT COUNT(*) $base', args);
    final rows = await database.rawQuery(
      'SELECT f.event_id AS rally_id, r.event_name, f.driver_id AS person_id, f.driver_name, '
      'f.pos_overall, r.start_date $base ORDER BY (r.start_date IS NULL), r.start_date DESC LIMIT ? OFFSET ?',
      [...args, q.limit, q.offset],
    );
    return _decode(SearchIntent.searchDriverWins, rows, total, q);
  }

  Future<SearchResponse<dynamic>> _rallyResults(SearchQuery q, {required bool single}) async {
    final clauses = <String>[single ? 'f.pos_overall = 1' : 'f.pos_overall IS NOT NULL'];
    final args = <Object?>[];
    final rf = _rallyFilters(q, 'r');
    clauses.addAll(rf.clauses);
    args.addAll(rf.args);
    // Classification intents are driver-only.
    final pf = _personFilter(q, driverOnly: true);
    if (pf.clause != null) {
      clauses.add(pf.clause!);
      args.addAll(pf.args);
    }
    final where = 'WHERE ${clauses.join(' AND ')}';
    final base = 'FROM final_results f JOIN rallies r ON f.event_id = r.event_id $where';
    final limit = single ? 1 : q.limit;
    final offset = single ? 0 : q.offset;
    final rows = await database.rawQuery(
      'SELECT f.id, f.event_id AS rally_id, r.event_name, f.driver_id, f.driver_name, f.pos_overall '
      '$base ORDER BY f.pos_overall ASC, f.id ASC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    final total = single ? rows.length : await _count('SELECT COUNT(*) $base', args);
    final intent = single ? SearchIntent.getRallyResults : SearchIntent.getRallyTopFinishers;
    return _decode(intent, rows, total, q);
  }

  Future<SearchResponse<dynamic>> _videoActions(SearchQuery q) async {
    final clauses = <String>[];
    final args = <Object?>[];
    // Action-type dimension with _segments expansion.
    final actionExpr = <String>[];
    for (final a in q.actionTypes) {
      final clean = a.toLowerCase().endsWith('_segments')
          ? a.toLowerCase().substring(0, a.length - '_segments'.length)
          : a.toLowerCase();
      actionExpr.add('action_type = ?');
      args.add(clean);
      actionExpr.add('action_type = ?');
      args.add('${clean}_segments');
    }
    if (actionExpr.isNotEmpty) clauses.add('(${actionExpr.join(' OR ')})');

    final pf = _personFilter(q);
    if (pf.clause != null) {
      clauses.add(pf.clause!);
      args.addAll(pf.args);
    }
    final scope = _eventScope(q, 'event_id');
    if (scope.clause != null) {
      clauses.add(scope.clause!);
      args.addAll(scope.args);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final total = await _count('SELECT COUNT(*) FROM video_actions $where', args);
    final rows = await database.rawQuery(
      'SELECT id, video_id, action_type_id, action_type, NULL AS stream_id, event_name, driver_name, '
      'start_action, end_action, points, on_demand_url AS video_url, thumbnail_url, stage_name, '
      'stage_number, event_country FROM video_actions $where ORDER BY id DESC LIMIT ? OFFSET ?',
      [...args, q.limit, q.offset],
    );
    return _decode(SearchIntent.searchVideoActions, rows, total, q);
  }

  Future<SearchResponse<dynamic>> _driverVideos(SearchQuery q) async {
    final clauses = <String>[];
    final args = <Object?>[];
    final pf = _personFilter(q);
    if (pf.clause != null) {
      clauses.add(pf.clause!);
      args.addAll(pf.args);
    }
    final scope = _eventScope(q, 'event_id');
    if (scope.clause != null) {
      clauses.add(scope.clause!);
      args.addAll(scope.args);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final total = await _count('SELECT COUNT(*) FROM video_meta $where', args);
    final rows = await database.rawQuery(
      'SELECT video_id, NULL AS stream_id, on_demand_url AS video_url, thumbnail_url, event_name, '
      'stage_name, stage_number, person_id AS driver_id, driver_name, '
      'length_seconds AS video_length_seconds, created_at FROM video_meta $where '
      'ORDER BY video_id DESC LIMIT ? OFFSET ?',
      [...args, q.limit, q.offset],
    );
    return _decode(SearchIntent.searchDriverVideos, rows, total, q);
  }

  Future<SearchResponse<dynamic>> _topUploaders(SearchQuery q) async {
    final total = await _count('SELECT COUNT(*) FROM uploader_stats', const []);
    final rows = await database.rawQuery(
      'SELECT uploader_id, account_id, uploader_name, upload_count FROM uploader_stats '
      'ORDER BY upload_count DESC LIMIT ? OFFSET ?',
      [q.limit, q.offset],
    );
    return _decode(SearchIntent.getTopUploaders, rows, total, q);
  }

  Future<SearchResponse<dynamic>> _topDrivers(SearchQuery q) async {
    final total = await _count('SELECT COUNT(*) FROM driver_wins', const []);
    final rows = await database.rawQuery(
      'SELECT person_id, driver_id, driver_name, win_count FROM driver_wins '
      'ORDER BY win_count DESC LIMIT ? OFFSET ?',
      [q.limit, q.offset],
    );
    return _decode(SearchIntent.getTopDriversByWins, rows, total, q);
  }

  // --- Support -------------------------------------------------------------

  Future<int> _count(String sql, List<Object?> args) async {
    final rows = await database.rawQuery(sql, args);
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    return v is int ? v : int.tryParse('$v') ?? 0;
  }

  SearchResponse<dynamic> _decode(
    SearchIntent intent,
    List<Map<String, Object?>> rows,
    int total,
    SearchQuery q,
  ) {
    final results = rows.map<dynamic>((raw) {
      final m = Map<String, dynamic>.from(raw);
      switch (intent) {
        case SearchIntent.searchRallies:
          return RallySearchResult.fromMap(m);
        case SearchIntent.searchDriverRallies:
        case SearchIntent.searchDriverWins:
          return RallyParticipationResult.fromMap(m);
        case SearchIntent.getRallyResults:
        case SearchIntent.getRallyTopFinishers:
          return RallyResult.fromMap(m);
        case SearchIntent.searchVideoActions:
          return VideoAction.fromMap(m);
        case SearchIntent.searchDriverVideos:
          return VideoSearchResult.fromMap(m);
        case SearchIntent.getTopUploaders:
          return UploaderSearchResult.fromMap(m);
        case SearchIntent.getTopDriversByWins:
          return DriverWinResult.fromMap(m);
      }
    }).toList();
    return SearchResponse<dynamic>(
      intent: intent,
      results: results,
      totalCount: total,
      hasMore: q.offset + results.length < total,
      limit: q.limit,
      offset: q.offset,
    );
  }
}
