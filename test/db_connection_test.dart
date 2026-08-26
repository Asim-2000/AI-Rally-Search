// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AWS RDS MySQL Database Connection Test', () async {
    await dotenv.load(fileName: '.env');
    final dbService = DatabaseService();

    final status = await dbService.testConnection();
    print('DB Connection Status: $status');

    expect(status['success'], isTrue,
        reason: 'Failed to connect: ${status['error']}');
    expect(status['tableCount'], greaterThan(0));
    print('Successfully verified ${status['tableCount']} tables in AWS RDS!');

    await dbService.close();
  });
}
