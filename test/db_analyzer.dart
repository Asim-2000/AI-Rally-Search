// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Refined AWS RDS MySQL Database Analysis', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();
    final conn = await db.connect();

    // Distinct action names
    final actions = await conn.execute(
      'SELECT DISTINCT id, action_name FROM `rally_video_actions`;'
    );
    print('\n--- Video Actions ---');
    for (final row in actions.rows) {
      print(row.assoc());
    }

    // Distinct countries in events
    final countries = await conn.execute(
      'SELECT DISTINCT country FROM `rally_events` WHERE country IS NOT NULL;'
    );
    print('\n--- Rally Event Countries ---');
    for (final row in countries.rows) {
      print(row.assoc());
    }

    final stats = await conn.execute('''
      SELECT 
        COUNT(*) as total_actions,
        SUM(CASE WHEN rs.clip_start_time IS NOT NULL THEN 1 ELSE 0 END) as with_clip_start,
        SUM(CASE WHEN rs.clip_duration IS NOT NULL THEN 1 ELSE 0 END) as with_clip_duration,
        AVG(rs.clip_start_time) as avg_clip_start,
        AVG(rs.clip_duration) as avg_clip_duration
      FROM rally_video_metadata vm
      INNER JOIN rally_video_actions va ON vm.action_id = va.id
      INNER JOIN rally_streams rs ON vm.video_id = rs.video_id
      WHERE rs.on_demand_url IS NOT NULL AND rs.on_demand_url != '';
    ''');
    print('\n--- Action Stats ---');
    for (final row in stats.rows) {
      print(row.assoc());
    }

    final sample2 = await conn.execute('''
      SELECT 
        vm.id AS metadata_id,
        rs.id AS stream_id,
        rs.video_id,
        rs.clip_start_time,
        rs.clip_duration,
        vm.start_action,
        vm.end_action,
        va.action_name
      FROM rally_video_metadata vm
      INNER JOIN rally_video_actions va ON vm.action_id = va.id
      INNER JOIN rally_streams rs ON vm.video_id = rs.video_id
      WHERE rs.on_demand_url IS NOT NULL AND rs.on_demand_url != ''
      ORDER BY vm.id DESC
      LIMIT 10;
    ''');
    print('\n--- Latest 10 Actions ---');
    for (final row in sample2.rows) {
      print(row.assoc());
    }

    await db.close();
  });
}
