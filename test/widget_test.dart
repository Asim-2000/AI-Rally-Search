import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/main.dart';
import 'package:ai_rally_search/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders RallyStreamsPage smoke test',
      (WidgetTester tester) async {
    await dotenv.load(fileName: '.env');

    await tester.runAsync(() async {
      await tester.pumpWidget(const MyApp());
      await Future.delayed(const Duration(seconds: 2));
      await tester.pump();
      await DatabaseService().close();
    });

    expect(find.text('Rally Streams'), findsOneWidget);
  });
}
