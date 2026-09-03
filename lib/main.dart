import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/general_search_screen.dart';
import 'services/offline/offline_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads PUBLIC client config only (API base URL, non-secret speech settings).
  // Server secrets (DB credentials, API keys) are never bundled in the app.
  await dotenv.load(fileName: 'assets/config/app_config.env');

  // Initialise the offline search stack (local SQLite snapshot + sync). Fully
  // guarded: on any failure this returns null and the app runs online-only.
  final rawUrl = dotenv.env['PYTHON_BACKEND_BASE_URL']?.trim();
  final backendBaseUrl = (rawUrl == null || rawUrl.isEmpty) ? null : Uri.tryParse(rawUrl);
  final offlineStack = await OfflineBootstrap.initialize(backendBaseUrl: backendBaseUrl);

  runApp(MyApp(offlineStack: offlineStack));
}

class MyApp extends StatelessWidget {
  final OfflineStack? offlineStack;
  const MyApp({super.key, this.offlineStack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Rally Search',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      // Search is the front door. The technical stream registry
      // (RallyStreamsPage) remains reachable as a secondary "Browse" area via
      // the search screen's app bar.
      home: GeneralSearchScreen(
        offlineEngine: offlineStack?.engine,
        offlineSync: offlineStack?.sync,
        connectivityProbe: offlineStack?.connectivity,
      ),
    );
  }
}
