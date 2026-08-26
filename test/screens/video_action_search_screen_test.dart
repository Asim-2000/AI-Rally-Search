import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/video_action_search_query.dart';
import 'package:ai_rally_search/screens/video_action_search_screen.dart';

void main() {
  testWidgets('VideoActionSearchScreen UI structure and filter controls render correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoActionSearchScreen(
          initialQuery: VideoActionSearchQuery(
            actionType: 'jump',
            country: 'Austria',
            eventName: 'OBM Land',
          ),
        ),
      ),
    );

    // Verify AppBar
    expect(find.text('Action Moments Search'), findsOneWidget);

    // Verify Search text field
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('OBM Land'), findsOneWidget);

    // Verify Action dropdown value
    expect(find.text('Jump'), findsOneWidget);

    // Verify Country dropdown label
    expect(find.text('Austria (AT)'), findsOneWidget);

    // Verify Search button
    expect(find.text('Search'), findsOneWidget);

    // Toggle advanced filters
    final stageFiltersButton = find.text('Stage Filters');
    expect(stageFiltersButton, findsOneWidget);
    await tester.tap(stageFiltersButton);
    await tester.pumpAndSettle();

    expect(find.text('Less Filters'), findsOneWidget);
    expect(find.text('Stage Name (e.g. Gale Rigg)'), findsOneWidget);
    expect(find.text('Stage # (e.g. 3)'), findsOneWidget);
  });
}
