// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect rally_events countries', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();
    final conn = await db.connect();

    // 1. Describe table
    final desc = await conn.execute('DESCRIBE rally_events;');
    print('\n=== rally_events SCHEMA ===');
    for (final row in desc.rows) {
      final map = row.assoc();
      print('${map['Field']} (${map['Type']})');
    }

    // 2. Distinct countries with event counts
    final countryCounts = await conn.execute('''
      SELECT country, COUNT(*) as event_count
      FROM rally_events
      GROUP BY country
      ORDER BY country;
    ''');
    print('\n=== DISTINCT COUNTRIES & EVENT COUNTS IN rally_events ===');
    for (final row in countryCounts.rows) {
      final map = row.assoc();
      print('Country: "${map['country']}" | Events: ${map['event_count']}');
    }

    // 3. Inspect specific rows that have short/unusual country codes or names
    final sampleRows = await conn.execute('''
      SELECT event_id, event_name, country, city, YEAR(start_date) as year
      FROM rally_events
      WHERE country IN ('at', 'es', 'gb', 'hr', 'ie', 'ke', 'lv', 'none', 'qa', 'Scotland', 'Wales')
         OR country IS NULL OR TRIM(country) = '';
    ''');
    print('\n=== SPECIAL / 2-LETTER / OUTLIER ROWS IN rally_events ===');
    for (final row in sampleRows.rows) {
      final map = row.assoc();
      print('ID: ${map['event_id']} | Name: "${map['event_name']}" | Year: ${map['year']} | City: "${map['city']}" | Country: "${map['country']}"');
    }

    // 4. Sample check on total rally events
    final total = await conn.execute('SELECT COUNT(*) as total FROM rally_events;');
    print('\nTotal rally_events: ${total.rows.first.assoc()['total']}');

    await db.close();
  });
}





