import 'package:ai_rally_search/l10n/generated/app_localizations.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/offline/offline_search_engine.dart';
import 'package:ai_rally_search/services/offline/offline_search_router.dart';
import 'package:ai_rally_search/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _OfflineProbe implements ConnectivityProbe {
  @override
  Future<bool> isOnline() async => false;
}

Map<String, dynamic> _snapshot() => {
      'schema_version': 1,
      'data_version': 'v1',
      'snapshot_id': '1-v1-core',
      'segment': 'core',
      'generated_at': '2026-08-30T00:00:00Z',
      'rallies': <Map<String, Object?>>[
        {'event_id': 'ev1', 'event_name': 'Rally Alpha 2025', 'country': 'Ireland', 'city': 'Cork', 'year': 2025, 'start_date': '2025-05-01', 'end_date': null, 'status': null, 'stages_count': 3},
        {'event_id': 'ev2', 'event_name': 'Rally Beta 2024', 'country': 'Portugal', 'city': 'Porto', 'year': 2024, 'start_date': '2024-04-01', 'end_date': null, 'status': null, 'stages_count': 5},
      ],
      'people': const [],
      'stages': const [],
      'participation': const [],
      'final_results': const [],
      'driver_wins': const [],
      'uploader_stats': const [],
      'video_meta': const [],
      'video_actions': const [],
    };

Future<Widget> _app(OfflineSearchEngine engine) async {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: GeneralSearchScreen(offlineEngine: engine, connectivityProbe: _OfflineProbe()),
  );
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('offline device answers a rally search locally with the offline banner',
      (tester) async {
    final db = await OfflineDatabase.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    await db.importSnapshot(_snapshot());
    final engine = await OfflineSearchEngine.create(db);

    await tester.pumpWidget(await _app(engine));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).first, 'rallies in ireland in 2025');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // Offline banner present (product-tone headline), and the local rally result.
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text('Still racing — even without signal 🏁'), findsOneWidget);
    expect(find.textContaining('Rally Alpha'), findsWidgets);
    // Portugal rally must NOT appear (country filter honoured offline).
    expect(find.textContaining('Rally Beta'), findsNothing);

    await db.close();
  });

  testWidgets('offline special (weather) query returns the cheesy personality response',
      (tester) async {
    final db = await OfflineDatabase.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    await db.importSnapshot(_snapshot());
    final engine = await OfflineSearchEngine.create(db);

    await tester.pumpWidget(await _app(engine));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).first, 'what is the weather');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(
      find.textContaining('Hopefully sideways'),
      findsOneWidget,
    );

    await db.close();
  });
}
