import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/main.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches on the search-first home', (
    WidgetTester tester,
  ) async {
    await dotenv.load(fileName: '.env');

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Search is the front door, not the technical stream registry.
    expect(find.byType(GeneralSearchScreen), findsOneWidget);
    expect(find.text('Rally Search'), findsWidgets);
    // Old technical registry is NOT the launch surface.
    expect(find.text('Rally Streams'), findsNothing);
  });
}
