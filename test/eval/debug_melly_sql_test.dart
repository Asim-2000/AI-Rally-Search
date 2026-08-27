// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect all dual-role accounts', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();

    final allDual = await db.query('''
      SELECT 
        d.full_name AS driver_name,
        cd.full_name AS codriver_name,
        d.account_id,
        d.driver_id, cd.codriver_id,
        (SELECT COUNT(DISTINCT sub_event_id) FROM rally_entry_list WHERE user_driver_id = d.driver_id) AS driver_events,
        (SELECT COUNT(DISTINCT sub_event_id) FROM rally_entry_list WHERE user_co_driver_id = cd.codriver_id) AS codriver_events
      FROM user_driver_profile d
      JOIN user_codriver_profile cd ON d.account_id = cd.account_id
      WHERE d.driver_id IN (SELECT user_driver_id FROM rally_entry_list)
        AND cd.codriver_id IN (SELECT user_co_driver_id FROM rally_entry_list)
      LIMIT 20;
    ''');

    print('Total dual-role accounts with entries in both: ${allDual.length}');
    for (final r in allDual) {
      print('  Account ${r['account_id']}: Driver="${r['driver_name']}" (${r['driver_events']} ev) | Co-Driver="${r['codriver_name']}" (${r['codriver_events']} ev)');
    }

    await db.close();
  });
}
