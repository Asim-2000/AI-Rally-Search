// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect rally_sub_events columns and Max Freeman entries', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();
    final conn = await db.connect();

    final subEventsDesc = await conn.execute('DESCRIBE rally_sub_events;');
    print('rally_sub_events columns:');
    for (final r in subEventsDesc.rows) print(r.assoc());

    // Search rally_entry_list for codriver_id = 7a633b52-950e-49ef-8cab-34cd43e99366
    final maxEntries = await conn.execute('''
      SELECT el.*, se.event_id, e.event_name, e.start_date, e.country
      FROM rally_entry_list el
      JOIN rally_sub_events se ON el.sub_event_id = se.sub_event_id
      JOIN rally_events e ON se.event_id = e.event_id
      WHERE el.user_co_driver_id = '7a633b52-950e-49ef-8cab-34cd43e99366';
    ''');
    print('\nMax Freeman entries in rally_entry_list: (${maxEntries.rows.length})');
    for (final r in maxEntries.rows) print(r.assoc());

    // Check if Max Freeman has any results in rally_results
    final maxResults = await conn.execute('''
      SELECT rr.*, e.event_name
      FROM rally_results rr
      JOIN rally_entry_list el ON rr.entry_list_id = el.id
      JOIN rally_events e ON rr.rally_id = e.event_id
      WHERE el.user_co_driver_id = '7a633b52-950e-49ef-8cab-34cd43e99366';
    ''');
    print('\nMax Freeman rows in rally_results: (${maxResults.rows.length})');
    for (final r in maxResults.rows) print(r.assoc());

    await db.close();
  });
}
