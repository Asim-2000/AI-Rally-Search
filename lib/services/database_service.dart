import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mysql_client/mysql_client.dart';
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

  /// Searches video actions deterministically using structured query filters
  Future<List<Map<String, dynamic>>> searchVideoActions(
    VideoActionSearchQuery searchQuery,
  ) async {
    final whereClauses = <String>[
      "rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''",
      "(rs.video_type IS NULL OR rs.video_type != 'instantReplay')"
    ];

    // Action types filter
    final resolvedActions = searchQuery.resolvedActionTypes;
    if (resolvedActions.isNotEmpty) {
      final actionIn = resolvedActions
          .map((a) => "'${a.replaceAll("'", "''")}'")
          .join(', ');
      whereClauses.add("va.action_name IN ($actionIn)");
    }

    // Country filter
    final countryAliases = searchQuery.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases
          .map((c) => "'${c.replaceAll("'", "''")}'")
          .join(', ');
      final mainCountry = searchQuery.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    // Event name filter (case-insensitive substring)
    if (searchQuery.eventName != null && searchQuery.eventName!.trim().isNotEmpty) {
      final sanitizedEvent = searchQuery.eventName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.event_name) LIKE '%$sanitizedEvent%'");
    }

    // Stage name filter (case-insensitive substring)
    if (searchQuery.stageName != null && searchQuery.stageName!.trim().isNotEmpty) {
      final sanitizedStage = searchQuery.stageName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(stg.stage_name) LIKE '%$sanitizedStage%'");
    }

    // Stage number filter
    if (searchQuery.stageNumber != null && searchQuery.stageNumber!.trim().isNotEmpty) {
      final sanitizedNum = searchQuery.stageNumber!.trim().replaceAll("'", "''").toLowerCase();
      final cleanNum = sanitizedNum.replaceAll('ss', '').trim();
      whereClauses.add("(stg.stage_number = '$cleanNum' OR stg.stage_number = '$sanitizedNum' OR LOWER(stg.stage_name) LIKE '%stage $cleanNum%')");
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
      LIMIT ${searchQuery.limit} OFFSET ${searchQuery.offset};
    ''';

    return await query(sql);
  }

  /// Returns total count of video actions matching the search query
  Future<int> countVideoActions(
    VideoActionSearchQuery searchQuery,
  ) async {
    final whereClauses = <String>[
      "rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''",
      "(rs.video_type IS NULL OR rs.video_type != 'instantReplay')"
    ];

    final resolvedActions = searchQuery.resolvedActionTypes;
    if (resolvedActions.isNotEmpty) {
      final actionIn = resolvedActions
          .map((a) => "'${a.replaceAll("'", "''")}'")
          .join(', ');
      whereClauses.add("va.action_name IN ($actionIn)");
    }

    final countryAliases = searchQuery.resolvedCountryAliases;
    if (countryAliases.isNotEmpty) {
      final countryIn = countryAliases
          .map((c) => "'${c.replaceAll("'", "''")}'")
          .join(', ');
      final mainCountry = searchQuery.country!.trim().replaceAll("'", "''").toLowerCase();
      if (mainCountry.length > 2) {
        whereClauses.add("(LOWER(ev.country) IN ($countryIn) OR LOWER(ev.country) LIKE '%$mainCountry%')");
      } else {
        whereClauses.add("LOWER(ev.country) IN ($countryIn)");
      }
    }

    if (searchQuery.eventName != null && searchQuery.eventName!.trim().isNotEmpty) {
      final sanitizedEvent = searchQuery.eventName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(ev.event_name) LIKE '%$sanitizedEvent%'");
    }

    if (searchQuery.stageName != null && searchQuery.stageName!.trim().isNotEmpty) {
      final sanitizedStage = searchQuery.stageName!.trim().replaceAll("'", "''").toLowerCase();
      whereClauses.add("LOWER(stg.stage_name) LIKE '%$sanitizedStage%'");
    }

    if (searchQuery.stageNumber != null && searchQuery.stageNumber!.trim().isNotEmpty) {
      final sanitizedNum = searchQuery.stageNumber!.trim().replaceAll("'", "''").toLowerCase();
      final cleanNum = sanitizedNum.replaceAll('ss', '').trim();
      whereClauses.add("(stg.stage_number = '$cleanNum' OR stg.stage_number = '$sanitizedNum' OR LOWER(stg.stage_name) LIKE '%stage $cleanNum%')");
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
