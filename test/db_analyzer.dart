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

    // Sample events
    final eventsSample = await conn.execute(
      'SELECT event_id, event_name, country, city, status, start_date, end_date FROM `rally_events` LIMIT 5;'
    );
    print('\n--- Sample Rally Events ---');
    for (final row in eventsSample.rows) {
      print(row.assoc());
    }

    // Sample stages
    final stagesSample = await conn.execute(
      'SELECT stage_id, stage_name, event_id, stage_number FROM `rally_stages` LIMIT 5;'
    );
    print('\n--- Sample Rally Stages ---');
    for (final row in stagesSample.rows) {
      print(row.assoc());
    }

    await db.close();
  });
}
