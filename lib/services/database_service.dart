import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

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
    final whereClauses = <String>[];

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
    final whereClauses = <String>[];

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

  /// Closes the active database connection
  Future<void> close() async {
    if (_connection != null && _connection!.connected) {
      await _connection!.close();
      _connection = null;
      developer.log('MySQL connection closed.', name: 'DatabaseService');
    }
  }
}
