import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mysql_client/mysql_client.dart';
import '../models/search_query.dart';
import '../models/video_action_search_query.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  MySQLConnection? _connection;

  String get host => dotenv.env['DB_HOST'] ?? '';
  int get port => int.tryParse(dotenv.env['DB_PORT'] ?? '3306') ?? 3306;
  String get databaseName => dotenv.env['DB_NAME'] ?? '';
  String get userName => dotenv.env['DB_USER'] ?? '';
  String get password => dotenv.env['DB_PASSWORD'] ?? '';
  bool get isSecure =>
      (dotenv.env['DB_USE_SSL'] ?? 'false').toLowerCase() == 'true';

  bool get isConnected => _connection != null && _connection!.connected;

  /// Connects to the AWS RDS MySQL database
  Future<MySQLConnection> connect() async {
    if (_connection != null && _connection!.connected) {
      return _connection!;
    }

    try {
      developer.log(
        'Connecting to MySQL: $host:$port/$databaseName as $userName',
        name: 'DatabaseService',
      );

      _connection = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: userName,
        password: password,
        databaseName: databaseName,
        secure: isSecure,
      );

      await _connection!.connect();
      developer.log('MySQL connection established successfully.',
          name: 'DatabaseService');
      return _connection!;
    } catch (e, st) {
      developer.log('Failed to connect to MySQL database',
          name: 'DatabaseService', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Tests the database connection and returns connection info & table count
  Future<Map<String, dynamic>> testConnection() async {
    final stopwatch = Stopwatch()..start();
    try {
      final conn = await connect();
      final result = await conn.execute('SHOW TABLES;');
      stopwatch.stop();

      final tables = result.rows
          .map((row) => row.assoc().values.first?.toString() ?? '')
          .toList();

      return {
        'success': true,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'host': host,
        'database': databaseName,
        'tableCount': tables.length,
        'tables': tables,
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'error': e.toString(),
      };
    }
  }

  /// Executes a query and returns the results as a `List<Map<String, dynamic>>`
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final conn = await connect();
    final result = await conn.execute(sql, params ?? {});
    return result.rows.map((row) => row.assoc()).toList();
  }

  /// Fetches a paginated list of rally streams with optional filters and sorting
  Future<List<Map<String, dynamic>>> getRallyStreams({
    int limit = 10,
    int offset = 0,
    String? searchQuery,
    String? videoType,
    String? clipStatus,
    String sortBy = 'id',
    bool sortAscending = false,
  }) async {
    final whereClauses = <String>[
      "(video_type IS NULL OR video_type != 'instantReplay')"
    ];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final sanitized = searchQuery.trim().replaceAll("'", "''");
      final isNum = int.tryParse(sanitized) != null;
      if (isNum) {
        whereClauses.add('(id = $sanitized OR video_id = $sanitized OR on_demand_url LIKE \'%$sanitized%\')');
      } else {
        whereClauses.add('(on_demand_url LIKE \'%$sanitized%\' OR video_type LIKE \'%$sanitized%\' OR clip_status LIKE \'%$sanitized%\')');
      }
    }

    if (videoType != null && videoType.isNotEmpty && videoType.toLowerCase() != 'all') {
      final sanitizedType = videoType.replaceAll("'", "''");
      whereClauses.add('video_type = \'$sanitizedType\'');
    }

    if (clipStatus != null && clipStatus.isNotEmpty && clipStatus.toLowerCase() != 'all') {
      final sanitizedStatus = clipStatus.replaceAll("'", "''");
      whereClauses.add('clip_status = \'$sanitizedStatus\'');
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final orderDirection = sortAscending ? 'ASC' : 'DESC';
    final sql = 'SELECT * FROM `rally_streams` $whereSql ORDER BY `$sortBy` $orderDirection LIMIT $limit OFFSET $offset;';

    return await query(sql);
  }

  /// Returns the total count of rally streams matching the filter
  Future<int> getRallyStreamsCount({
    String? searchQuery,
    String? videoType,
    String? clipStatus,
  }) async {
    final whereClauses = <String>[
      "(video_type IS NULL OR video_type != 'instantReplay')"
    ];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final sanitized = searchQuery.trim().replaceAll("'", "''");
      final isNum = int.tryParse(sanitized) != null;
      if (isNum) {
        whereClauses.add('(id = $sanitized OR video_id = $sanitized OR on_demand_url LIKE \'%$sanitized%\')');
      } else {
        whereClauses.add('(on_demand_url LIKE \'%$sanitized%\' OR video_type LIKE \'%$sanitized%\' OR clip_status LIKE \'%$sanitized%\')');
      }
    }

    if (videoType != null && videoType.isNotEmpty && videoType.toLowerCase() != 'all') {
      final sanitizedType = videoType.replaceAll("'", "''");
      whereClauses.add('video_type = \'$sanitizedType\'');
    }

    if (clipStatus != null && clipStatus.isNotEmpty && clipStatus.toLowerCase() != 'all') {
      final sanitizedStatus = clipStatus.replaceAll("'", "''");
      whereClauses.add('clip_status = \'$sanitizedStatus\'');
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final sql = 'SELECT COUNT(*) as count FROM `rally_streams` $whereSql;';

    final result = await query(sql);
    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }

  /// Fetches actions / moments for a specific source video ID
  Future<List<Map<String, dynamic>>> getVideoActionsForVideo(int videoId) async {
    final sql = '''
      SELECT 
        vm.id AS id,
        vm.video_id AS video_id,
        rs.id AS stream_id,
        rs.on_demand_url AS on_demand_url,
        rs.clip_start_time AS clip_start_time,
        rs.clip_duration AS clip_duration,
        va.id AS action_type_id,
        va.action_name AS action_name,
        vm.start_action AS start_action,
        vm.end_action AS end_action,
        vm.points AS points,
        rv.thumbnail AS thumbnail_url,
        stg.stage_name,
        stg.stage_number,
        ev.event_name,
        ev.country AS event_country
      FROM rally_video_metadata vm
      INNER JOIN rally_video_actions va ON vm.action_id = va.id
      LEFT JOIN rally_streams rs ON vm.video_id = rs.video_id AND (rs.video_type IS NULL OR rs.video_type != 'instantReplay')
      LEFT JOIN rally_videos rv ON vm.video_id = rv.id
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      WHERE vm.video_id = $videoId
      ORDER BY vm.start_action ASC;
    ''';

    return await query(sql);
  }

  /// Fetches actions / moments for a specific rally stream ID
  Future<List<Map<String, dynamic>>> getVideoActionsForStream(int streamId) async {
    final sql = '''
      SELECT 
        vm.id AS id,
        vm.video_id AS video_id,
        rs.id AS stream_id,
        rs.on_demand_url AS on_demand_url,
        rs.clip_start_time AS clip_start_time,
        rs.clip_duration AS clip_duration,
        va.id AS action_type_id,
        va.action_name AS action_name,
        vm.start_action AS start_action,
        vm.end_action AS end_action,
        vm.points AS points,
        rv.thumbnail AS thumbnail_url,
        stg.stage_name,
        stg.stage_number,
        ev.event_name,
        ev.country AS event_country
      FROM rally_streams rs
      INNER JOIN rally_video_metadata vm ON rs.video_id = vm.video_id
      INNER JOIN rally_video_actions va ON vm.action_id = va.id
      LEFT JOIN rally_videos rv ON rs.video_id = rv.id
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      WHERE rs.id = $streamId
      ORDER BY vm.start_action ASC;
    ''';

    return await query(sql);
  }

  /// Fetches recent action moments across all streams
  Future<List<Map<String, dynamic>>> getRecentVideoActions({
    int limit = 20,
    int offset = 0,
    String? actionType,
  }) async {
    final whereClauses = <String>[
      "rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''",
      "(rs.video_type IS NULL OR rs.video_type != 'instantReplay')"
    ];

    if (actionType != null && actionType.isNotEmpty && actionType.toLowerCase() != 'all') {
      final sanitizedType = actionType.replaceAll("'", "''");
      whereClauses.add("(va.action_name = '$sanitizedType' OR va.action_name = '${sanitizedType}_segments')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        vm.id AS id,
        vm.video_id AS video_id,
        MIN(rs.id) AS stream_id,
        MIN(rs.on_demand_url) AS on_demand_url,
        MIN(rs.clip_start_time) AS clip_start_time,
        MIN(rs.clip_duration) AS clip_duration,
        va.id AS action_type_id,
        va.action_name AS action_name,
        vm.start_action AS start_action,
        vm.end_action AS end_action,
        vm.points AS points,
        rv.thumbnail AS thumbnail_url,
        stg.stage_name,
        stg.stage_number,
        ev.event_name,
        ev.country AS event_country
      FROM rally_video_metadata vm
      INNER JOIN rally_video_actions va ON vm.action_id = va.id
      INNER JOIN rally_streams rs ON vm.video_id = rs.video_id
      LEFT JOIN rally_videos rv ON vm.video_id = rv.id
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      $whereSql
      GROUP BY vm.id, vm.video_id, va.id, va.action_name, vm.start_action, vm.end_action, vm.points, rv.thumbnail, stg.stage_name, stg.stage_number, ev.event_name, ev.country
      ORDER BY vm.id DESC
      LIMIT $limit OFFSET $offset;
    ''';

    return await query(sql);
  }

  /// Searches video actions deterministically using structured query filters (supports SearchQuery and VideoActionSearchQuery)
  Future<List<Map<String, dynamic>>> searchVideoActions(
    dynamic searchQuery,
  ) async {
    final whereClauses = <String>[
      "rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''",
      "(rs.video_type IS NULL OR rs.video_type != 'instantReplay')"
    ];

    // Action types filter
    List<String> resolvedActions = [];
    if (searchQuery is SearchQuery) {
      resolvedActions = searchQuery.resolvedActionTypes;
    } else if (searchQuery is VideoActionSearchQuery) {
      resolvedActions = searchQuery.resolvedActionTypes;
    }
    if (resolvedActions.isNotEmpty) {
      final actionIn = resolvedActions
          .map((a) => "'${a.replaceAll("'", "''")}'")
          .join(', ');
      whereClauses.add("va.action_name IN ($actionIn)");
    }

    // Country filter
    List<String> countryAliases = [];
    String? countryVal;
    if (searchQuery is SearchQuery) {
      countryAliases = searchQuery.resolvedCountryAliases;
      countryVal = searchQuery.country;
    } else if (searchQuery is VideoActionSearchQuery) {
      countryAliases = searchQuery.resolvedCountryAliases;
      countryVal = searchQuery.country;
    }

    if (countryAliases.isNotEmpty && countryVal != null) {
      final countryIn = countryAliases
          .map((c) => "'${c.replaceAll("'", "''")}'")
          .join(', ');
      final mainCountry = countryVal.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    // City filter
    final cityVal = searchQuery is SearchQuery ? searchQuery.city : null;
    if (cityVal != null && cityVal.trim().isNotEmpty && cityVal.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = cityVal.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    // Year filter
    final yearVal = searchQuery is SearchQuery ? searchQuery.year : null;
    if (yearVal != null && yearVal > 0) {
      whereClauses.add("(YEAR(ev.start_date) = $yearVal OR YEAR(ev.end_date) = $yearVal)");
    }

    // Event name filter (case-insensitive substring)
    final eventName = searchQuery is SearchQuery
        ? searchQuery.targetRallyName
        : (searchQuery is VideoActionSearchQuery ? searchQuery.eventName : null);
    if (eventName != null && eventName.trim().isNotEmpty) {
      final sanitizedEvent = eventName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    // Stage name filter (case-insensitive substring)
    final stageName = searchQuery.stageName as String?;
    if (stageName != null && stageName.trim().isNotEmpty) {
      final sanitizedStage = stageName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(stg.stage_name) LIKE '%$sanitizedStage%'");
    }

    // Stage number filter
    final stageNum = searchQuery.stageNumber as String?;
    if (stageNum != null && stageNum.trim().isNotEmpty) {
      final sanitizedNum = stageNum.trim().replaceAll("'", "''").toLowerCase();
      final cleanNum = sanitizedNum.replaceAll('ss', '').trim();
      whereClauses.add("(stg.stage_number = '$cleanNum' OR stg.stage_number = '$sanitizedNum' OR LOWER(stg.stage_name) LIKE '%stage $cleanNum%')");
    }

    // Driver filter (Driver Name / Driver ID)
    final driverId = searchQuery is SearchQuery ? searchQuery.driverId : null;
    final driverName = searchQuery is SearchQuery ? searchQuery.driverName : null;
    if (driverId != null && driverId.trim().isNotEmpty) {
      final sanitizedId = driverId.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (driverName != null && driverName.trim().isNotEmpty) {
      final sanitizedName = driverName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%')");
    }

    final limit = searchQuery.limit as int;
    final offset = searchQuery.offset as int;

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        vm.id AS id,
        vm.video_id AS video_id,
        MIN(rs.id) AS stream_id,
        MIN(rs.on_demand_url) AS on_demand_url,
        MIN(rs.clip_start_time) AS clip_start_time,
        MIN(rs.clip_duration) AS clip_duration,
        va.id AS action_type_id,
        va.action_name AS action_name,
        vm.start_action AS start_action,
        vm.end_action AS end_action,
        vm.points AS points,
        rv.thumbnail AS thumbnail_url,
        stg.stage_name,
        stg.stage_number,
        ev.event_name,
        ev.country AS event_country,
        dp.full_name AS driver_name
      FROM rally_video_metadata vm
      INNER JOIN rally_video_actions va ON vm.action_id = va.id
      INNER JOIN rally_streams rs ON vm.video_id = rs.video_id
      LEFT JOIN rally_videos rv ON vm.video_id = rv.id
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      LEFT JOIN rally_entry_list el ON vm.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql
      GROUP BY vm.id, vm.video_id, va.id, va.action_name, vm.start_action, vm.end_action, vm.points, rv.thumbnail, stg.stage_name, stg.stage_number, ev.event_name, ev.country, dp.full_name
      ORDER BY vm.id DESC
      LIMIT $limit OFFSET $offset;
    ''';

    return await query(sql);
  }

  /// Returns total count of video actions matching the search query
  Future<int> countVideoActions(
    dynamic searchQuery,
  ) async {
    final whereClauses = <String>[
      "rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''",
      "(rs.video_type IS NULL OR rs.video_type != 'instantReplay')"
    ];

    List<String> resolvedActions = [];
    if (searchQuery is SearchQuery) {
      resolvedActions = searchQuery.resolvedActionTypes;
    } else if (searchQuery is VideoActionSearchQuery) {
      resolvedActions = searchQuery.resolvedActionTypes;
    }
    if (resolvedActions.isNotEmpty) {
      final actionIn = resolvedActions
          .map((a) => "'${a.replaceAll("'", "''")}'")
          .join(', ');
      whereClauses.add("va.action_name IN ($actionIn)");
    }

    List<String> countryAliases = [];
    String? countryVal;
    if (searchQuery is SearchQuery) {
      countryAliases = searchQuery.resolvedCountryAliases;
      countryVal = searchQuery.country;
    } else if (searchQuery is VideoActionSearchQuery) {
      countryAliases = searchQuery.resolvedCountryAliases;
      countryVal = searchQuery.country;
    }

    if (countryAliases.isNotEmpty && countryVal != null) {
      final countryIn = countryAliases
          .map((c) => "'${c.replaceAll("'", "''")}'")
          .join(', ');
      final mainCountry = countryVal.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    final cityVal = searchQuery is SearchQuery ? searchQuery.city : null;
    if (cityVal != null && cityVal.trim().isNotEmpty && cityVal.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = cityVal.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    final yearVal = searchQuery is SearchQuery ? searchQuery.year : null;
    if (yearVal != null && yearVal > 0) {
      whereClauses.add("(YEAR(ev.start_date) = $yearVal OR YEAR(ev.end_date) = $yearVal)");
    }

    final eventName = searchQuery is SearchQuery
        ? searchQuery.targetRallyName
        : (searchQuery is VideoActionSearchQuery ? searchQuery.eventName : null);
    if (eventName != null && eventName.trim().isNotEmpty) {
      final sanitizedEvent = eventName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    final stageName = searchQuery.stageName as String?;
    if (stageName != null && stageName.trim().isNotEmpty) {
      final sanitizedStage = stageName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(stg.stage_name) LIKE '%$sanitizedStage%'");
    }

    final stageNum = searchQuery.stageNumber as String?;
    if (stageNum != null && stageNum.trim().isNotEmpty) {
      final sanitizedNum = stageNum.trim().replaceAll("'", "''").toLowerCase();
      final cleanNum = sanitizedNum.replaceAll('ss', '').trim();
      whereClauses.add("(stg.stage_number = '$cleanNum' OR stg.stage_number = '$sanitizedNum' OR LOWER(stg.stage_name) LIKE '%stage $cleanNum%')");
    }

    final driverId = searchQuery is SearchQuery ? searchQuery.driverId : null;
    final driverName = searchQuery is SearchQuery ? searchQuery.driverName : null;
    if (driverId != null && driverId.trim().isNotEmpty) {
      final sanitizedId = driverId.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (driverName != null && driverName.trim().isNotEmpty) {
      final sanitizedName = driverName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT COUNT(DISTINCT vm.id) as count
      FROM rally_video_metadata vm
      INNER JOIN rally_video_actions va ON vm.action_id = va.id
      INNER JOIN rally_streams rs ON vm.video_id = rs.video_id
      LEFT JOIN rally_videos rv ON vm.video_id = rv.id
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      LEFT JOIN rally_entry_list el ON vm.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql;
    ''';

    final result = await query(sql);
    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }


  // ==========================================
  // PHASE 2: GENERAL RALLY SEARCH QUERIES
  // ==========================================

  /// Subquery condition that identifies the final stage of each rally event
  static const String _finalStageSubquery = '''
    (ev.event_id, CAST(stg.stage_number AS UNSIGNED)) IN (
      SELECT s2.event_id, MAX(CAST(s2.stage_number AS UNSIGNED))
      FROM rally_stages s2
      INNER JOIN rally_results r2 ON s2.stage_id = r2.stage_id AND s2.event_id = r2.rally_id
      GROUP BY s2.event_id
    )
  ''';

  /// Searches rally events by country, city, year, driver, or event name
  Future<List<Map<String, dynamic>>> searchRallies(SearchQuery q) async {
    final whereClauses = <String>[];

    // Country filter
    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases
          .map((c) => "'${c.replaceAll("'", "''")}'")
          .join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    // City filter
    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    // Year filter
    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    // Event name filter
    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    // Driver participation filter (if driverName / driverId specified)
    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add('''
        ev.event_id IN (
          SELECT DISTINCT rrx.rally_id 
          FROM rally_results rrx 
          LEFT JOIN rally_entry_list elx ON rrx.entry_list_id = elx.id 
          LEFT JOIN user_driver_profile dpx ON elx.user_driver_id = dpx.driver_id 
          WHERE (dpx.driver_id = '$sanitizedId' OR elx.user_driver_id = '$sanitizedId')
        )
      ''');
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedDriver = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add('''
        ev.event_id IN (
          SELECT DISTINCT rrx.rally_id 
          FROM rally_results rrx 
          LEFT JOIN rally_entry_list elx ON rrx.entry_list_id = elx.id 
          LEFT JOIN user_driver_profile dpx ON elx.user_driver_id = dpx.driver_id 
          WHERE (LOWER(dpx.full_name) LIKE '%$sanitizedDriver%' OR LOWER(dpx.nick_name) LIKE '%$sanitizedDriver%' OR LOWER(rrx.crew) LIKE '%$sanitizedDriver%')
        )
      ''');
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final sql = '''
      SELECT 
        ev.event_id,
        ev.event_name,
        ev.status,
        ev.start_date,
        ev.end_date,
        ev.stages_count,
        ev.country,
        ev.city,
        ev.thumbnail,
        ev.logo,
        COUNT(DISTINCT stg.stage_id) AS calculated_stages_count
      FROM rally_events ev
      LEFT JOIN rally_stages stg ON ev.event_id = stg.event_id
      $whereSql
      GROUP BY ev.event_id, ev.event_name, ev.status, ev.start_date, ev.end_date, ev.stages_count, ev.country, ev.city, ev.thumbnail, ev.logo
      ORDER BY ev.start_date DESC
      LIMIT ${q.limit} OFFSET ${q.offset};
    ''';

    return await query(sql);
  }

  /// Returns total count of rallies matching search criteria
  Future<int> countRallies(SearchQuery q) async {
    final whereClauses = <String>[];

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases
          .map((c) => "'${c.replaceAll("'", "''")}'")
          .join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add('''
        ev.event_id IN (
          SELECT DISTINCT rrx.rally_id 
          FROM rally_results rrx 
          LEFT JOIN rally_entry_list elx ON rrx.entry_list_id = elx.id 
          LEFT JOIN user_driver_profile dpx ON elx.user_driver_id = dpx.driver_id 
          WHERE (dpx.driver_id = '$sanitizedId' OR elx.user_driver_id = '$sanitizedId')
        )
      ''');
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedDriver = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add('''
        ev.event_id IN (
          SELECT DISTINCT rrx.rally_id 
          FROM rally_results rrx 
          LEFT JOIN rally_entry_list elx ON rrx.entry_list_id = elx.id 
          LEFT JOIN user_driver_profile dpx ON elx.user_driver_id = dpx.driver_id 
          WHERE (LOWER(dpx.full_name) LIKE '%$sanitizedDriver%' OR LOWER(dpx.nick_name) LIKE '%$sanitizedDriver%' OR LOWER(rrx.crew) LIKE '%$sanitizedDriver%')
        )
      ''');
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final sql = 'SELECT COUNT(DISTINCT ev.event_id) AS count FROM rally_events ev $whereSql;';

    final result = await query(sql);
    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }

  /// Searches rallies a driver participated in, returning overall result/finishing position
  Future<List<Map<String, dynamic>>> searchDriverRallies(SearchQuery q) async {
    final whereClauses = <String>[_finalStageSubquery];

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedName = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%' OR LOWER(rr.crew) LIKE '%$sanitizedName%')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        ev.event_id AS rally_id,
        ev.event_name,
        ev.country,
        ev.city,
        ev.start_date,
        dp.driver_id,
        COALESCE(dp.full_name, rr.crew) AS driver_name,
        rr.crew,
        rr.car_number,
        el.car,
        rr.make,
        rr.pos_overall,
        rr.total_time
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql
      ORDER BY ev.start_date DESC
      LIMIT ${q.limit} OFFSET ${q.offset};
    ''';

    return await query(sql);
  }

  /// Total count of driver rally participations
  Future<int> countDriverRallies(SearchQuery q) async {
    final whereClauses = <String>[_finalStageSubquery];

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedName = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%' OR LOWER(rr.crew) LIKE '%$sanitizedName%')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT COUNT(DISTINCT ev.event_id) AS count
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql;
    ''';

    final result = await query(sql);
    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }

  /// Searches rallies a driver won (1 win counted per rally event on final stage)
  Future<List<Map<String, dynamic>>> searchDriverWins(SearchQuery q) async {
    final whereClauses = <String>[
      'rr.pos_overall = 1',
      _finalStageSubquery,
    ];

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedName = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%' OR LOWER(rr.crew) LIKE '%$sanitizedName%')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        ev.event_id AS rally_id,
        ev.event_name,
        ev.country,
        ev.city,
        ev.start_date,
        dp.driver_id,
        COALESCE(dp.full_name, rr.crew) AS driver_name,
        rr.crew,
        rr.car_number,
        el.car,
        rr.make,
        rr.pos_overall,
        rr.total_time
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql
      ORDER BY ev.start_date DESC
      LIMIT ${q.limit} OFFSET ${q.offset};
    ''';

    return await query(sql);
  }

  /// Count of driver wins
  Future<int> countDriverWins(SearchQuery q) async {
    final whereClauses = <String>[
      'rr.pos_overall = 1',
      _finalStageSubquery,
    ];

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedName = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%' OR LOWER(rr.crew) LIKE '%$sanitizedName%')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT COUNT(DISTINCT ev.event_id) AS count
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql;
    ''';

    final result = await query(sql);
    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }

  /// Gets the top ranked finishers for a rally on the final classification stage
  Future<List<Map<String, dynamic>>> getRallyTopFinishers(SearchQuery q) async {
    final whereClauses = <String>[
      'rr.pos_overall IS NOT NULL',
      _finalStageSubquery,
    ];

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedName = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%' OR LOWER(rr.crew) LIKE '%$sanitizedName%')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        rr.id,
        rr.rally_id,
        ev.event_name,
        rr.stage_id,
        stg.stage_name,
        stg.stage_number,
        dp.driver_id,
        COALESCE(dp.full_name, rr.crew) AS driver_name,
        rr.crew,
        rr.car_number,
        rr.make,
        rr.class_type,
        rr.pos_overall,
        rr.pos_stage,
        rr.total_time,
        rr.stage_time,
        rr.diff_leader,
        rr.diff_prev
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql
      ORDER BY rr.pos_overall ASC
      LIMIT ${q.limit} OFFSET ${q.offset};
    ''';

    return await query(sql);
  }

  /// Count of rally top finishers
  Future<int> countRallyTopFinishers(SearchQuery q) async {
    final whereClauses = <String>[
      'rr.pos_overall IS NOT NULL',
      _finalStageSubquery,
    ];

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedName = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%' OR LOWER(rr.crew) LIKE '%$sanitizedName%')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT COUNT(DISTINCT rr.id) AS count
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql;
    ''';

    final result = await query(sql);
    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }

  /// Gets the first-place winner / result of a rally
  Future<List<Map<String, dynamic>>> getRallyResults(SearchQuery q) async {
    final singleWinnerQuery = q.copyWith(limit: 1, offset: 0);
    final whereClauses = <String>[
      'rr.pos_overall = 1',
      _finalStageSubquery,
    ];

    final targetName = singleWinnerQuery.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    if (singleWinnerQuery.year != null && singleWinnerQuery.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${singleWinnerQuery.year} OR YEAR(ev.end_date) = ${singleWinnerQuery.year})");
    }

    final countryAliases = singleWinnerQuery.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = singleWinnerQuery.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (singleWinnerQuery.driverId != null && singleWinnerQuery.driverId!.trim().isNotEmpty) {
      final sanitizedId = singleWinnerQuery.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (singleWinnerQuery.driverName != null && singleWinnerQuery.driverName!.trim().isNotEmpty) {
      final sanitizedName = singleWinnerQuery.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%' OR LOWER(rr.crew) LIKE '%$sanitizedName%')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        rr.id,
        rr.rally_id,
        ev.event_name,
        rr.stage_id,
        stg.stage_name,
        stg.stage_number,
        dp.driver_id,
        COALESCE(dp.full_name, rr.crew) AS driver_name,
        rr.crew,
        rr.car_number,
        rr.make,
        rr.class_type,
        rr.pos_overall,
        rr.pos_stage,
        rr.total_time,
        rr.stage_time,
        rr.diff_leader,
        rr.diff_prev
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql
      ORDER BY rr.pos_overall ASC
      LIMIT 1;
    ''';

    return await query(sql);
  }

  /// Searches videos featuring a specific driver via metadata -> entry_list -> driver_profile
  Future<List<Map<String, dynamic>>> searchDriverVideos(SearchQuery q) async {
    final whereClauses = <String>[
      "rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''",
      "(rs.video_type IS NULL OR rs.video_type != 'instantReplay')",
    ];

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedName = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%')");
    }

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    if (q.stageName != null && q.stageName!.trim().isNotEmpty) {
      final sanitizedStage = q.stageName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(stg.stage_name) LIKE '%$sanitizedStage%'");
    }

    if (q.stageNumber != null && q.stageNumber!.trim().isNotEmpty) {
      final sanitizedNum = q.stageNumber!.trim().replaceAll("'", "''").toLowerCase();
      final cleanNum = sanitizedNum.replaceAll('ss', '').trim();
      whereClauses.add("(stg.stage_number = '$cleanNum' OR stg.stage_number = '$sanitizedNum' OR LOWER(stg.stage_name) LIKE '%stage $cleanNum%')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        rv.id AS video_id,
        MIN(rs.id) AS stream_id,
        MIN(rs.on_demand_url) AS on_demand_url,
        rv.thumbnail,
        ev.event_name,
        stg.stage_name,
        stg.stage_number,
        dp.driver_id,
        dp.full_name AS driver_name,
        rv.video_length_seconds,
        rv.created_at
      FROM rally_videos rv
      INNER JOIN rally_video_metadata vm ON rv.id = vm.video_id
      INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
      INNER JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      LEFT JOIN rally_streams rs ON rv.id = rs.video_id
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      $whereSql
      GROUP BY rv.id, rv.thumbnail, ev.event_name, stg.stage_name, stg.stage_number, dp.driver_id, dp.full_name, rv.video_length_seconds, rv.created_at
      ORDER BY rv.id DESC
      LIMIT ${q.limit} OFFSET ${q.offset};
    ''';

    return await query(sql);
  }

  /// Total count of videos featuring a driver
  Future<int> countDriverVideos(SearchQuery q) async {
    final whereClauses = <String>[
      "rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''",
      "(rs.video_type IS NULL OR rs.video_type != 'instantReplay')",
    ];

    if (q.driverId != null && q.driverId!.trim().isNotEmpty) {
      final sanitizedId = q.driverId!.trim().replaceAll("'", "''");
      whereClauses.add("(dp.driver_id = '$sanitizedId' OR el.user_driver_id = '$sanitizedId')");
    } else if (q.driverName != null && q.driverName!.trim().isNotEmpty) {
      final sanitizedName = q.driverName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(dp.full_name) LIKE '%$sanitizedName%' OR LOWER(dp.nick_name) LIKE '%$sanitizedName%')");
    }

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (q.city != null && q.city!.trim().isNotEmpty && q.city!.trim().toUpperCase() != 'ALL') {
      final sanitizedCity = q.city!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.city) LIKE '%$sanitizedCity%'");
    }

    if (q.stageName != null && q.stageName!.trim().isNotEmpty) {
      final sanitizedStage = q.stageName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(stg.stage_name) LIKE '%$sanitizedStage%'");
    }

    if (q.stageNumber != null && q.stageNumber!.trim().isNotEmpty) {
      final sanitizedNum = q.stageNumber!.trim().replaceAll("'", "''").toLowerCase();
      final cleanNum = sanitizedNum.replaceAll('ss', '').trim();
      whereClauses.add("(stg.stage_number = '$cleanNum' OR stg.stage_number = '$sanitizedNum' OR LOWER(stg.stage_name) LIKE '%stage $cleanNum%')");
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT COUNT(DISTINCT rv.id) AS count
      FROM rally_videos rv
      INNER JOIN rally_video_metadata vm ON rv.id = vm.video_id
      INNER JOIN rally_entry_list el ON vm.entry_list_id = el.id
      INNER JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      LEFT JOIN rally_streams rs ON rv.id = rs.video_id
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      $whereSql;
    ''';

    final result = await query(sql);

    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }

  /// Gets top uploaders for a rally or globally
  Future<List<Map<String, dynamic>>> getTopUploaders(SearchQuery q) async {
    final whereClauses = <String>['rv.uploader_user_id IS NOT NULL'];

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        rv.uploader_user_id,
        COALESCE(ua.user_name, ua.email, 'Anonymous') AS uploader_name,
        COUNT(rv.id) AS upload_count,
        MAX(ev.event_name) AS event_name
      FROM rally_videos rv
      LEFT JOIN user_account ua ON rv.uploader_user_id = ua.id
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      $whereSql
      GROUP BY rv.uploader_user_id, ua.user_name, ua.email
      ORDER BY upload_count DESC
      LIMIT ${q.limit} OFFSET ${q.offset};
    ''';

    return await query(sql);
  }

  /// Total count of uploaders
  Future<int> countTopUploaders(SearchQuery q) async {
    final whereClauses = <String>['rv.uploader_user_id IS NOT NULL'];

    final targetName = q.targetRallyName;
    if (targetName != null && targetName.trim().isNotEmpty) {
      final sanitizedEvent = targetName.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("(LOWER(ev.event_name) LIKE '%$sanitizedEvent%' OR ev.event_id = '$sanitizedEvent')");
    }

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT COUNT(DISTINCT rv.uploader_user_id) AS count
      FROM rally_videos rv
      LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
      LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
      $whereSql;
    ''';

    final result = await query(sql);
    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }

  /// Gets ranked leaderboard of drivers with most career rally wins (1 win counted per rally event)
  Future<List<Map<String, dynamic>>> getTopDriversByWins(SearchQuery q) async {
    final whereClauses = <String>[
      'rr.pos_overall = 1',
      _finalStageSubquery,
    ];

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT 
        dp.driver_id,
        COALESCE(dp.full_name, rr.crew) AS driver_name,
        dp.country,
        dp.profile_picture,
        COUNT(DISTINCT rr.rally_id) AS win_count,
        MAX(ev.event_name) AS latest_rally_won
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql
      GROUP BY dp.driver_id, COALESCE(dp.full_name, rr.crew), dp.country, dp.profile_picture
      ORDER BY win_count DESC
      LIMIT ${q.limit} OFFSET ${q.offset};
    ''';

    return await query(sql);
  }

  /// Total count of winning drivers
  Future<int> countTopDriversByWins(SearchQuery q) async {
    final whereClauses = <String>[
      'rr.pos_overall = 1',
      _finalStageSubquery,
    ];

    if (q.year != null && q.year! > 0) {
      whereClauses.add("(YEAR(ev.start_date) = ${q.year} OR YEAR(ev.end_date) = ${q.year})");
    }

    final countryAliases = q.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases.map((c) => "'${c.replaceAll("'", "''")}'").join(', ');
      final mainCountry = q.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    final whereSql = 'WHERE ${whereClauses.join(' AND ')}';
    final sql = '''
      SELECT COUNT(DISTINCT COALESCE(dp.driver_id, rr.crew)) AS count
      FROM rally_results rr
      INNER JOIN rally_events ev ON rr.rally_id = ev.event_id
      INNER JOIN rally_stages stg ON rr.stage_id = stg.stage_id
      LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
      LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
      $whereSql;
    ''';

    final result = await query(sql);
    if (result.isNotEmpty) {
      final countVal = result.first['count'];
      if (countVal is int) return countVal;
      return int.tryParse(countVal.toString()) ?? 0;
    }
    return 0;
  }


  /// Closes the active database connection
  Future<void> close() async {
    if (_connection != null && _connection!.connected) {
      await _connection!.close();
      _connection = null;
      developer.log('MySQL connection closed.', name: 'DatabaseService');
    }
  }
}

