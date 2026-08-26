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

    // List all tables
    // Test connection & table count
    final res = await db.testConnection();
    expect(res['success'], isTrue);
    print('DB Connection Healthy: ${res['tableCount']} tables found.');

    await db.close();
  });
}


