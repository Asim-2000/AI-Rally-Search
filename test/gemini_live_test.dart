import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/providers/gemini_query_parser.dart';

void main() {
  test('Live Gemini API Query Understanding Integration Test', () async {
    print('==============================================');
    print('Testing Live Gemini API Query Understanding...');
    print('==============================================');

    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    // Secrets are no longer bundled as an app asset. Load a developer's local
    // on-disk .env (if present) for this live test; otherwise skip.
    final envFile = File('.env');
    if (envFile.existsSync()) {
      dotenv.loadFromString(
        envString: envFile.readAsStringSync(),
        isOptional: true,
      );
    }
    if ((dotenv.maybeGet('GEMINI_API_KEY') ?? '').isEmpty) {
      markTestSkipped(
        'Live Gemini test skipped: GEMINI_API_KEY unavailable. Provide a local '
        '.env to run this test (keys are no longer shipped in the app bundle).',
      );
      return;
    }
    print('Loaded .env successfully');

    final config = LlmConfig.fromEnvironment(defaultProvider: LlmProvider.gemini);
    print('Provider: ${config.provider}');
    print('Model: ${config.model}');
    print('Base URL: ${config.baseUrl}');
    print('API Key length: ${config.apiKey?.length ?? 0}');

    final parser = GeminiQueryParser(config: config);

    final testQueries = [
      'Show jump highlights featuring Josh Moffett from Moonraker in 2025',
      'Which rallies did Josh Moffett win in 2026?',
      'show me rallies in poland',
      'Who finished first in Moonraker?',
      'Who are the top uploaders for Moonraker?',
    ];

    for (final q in testQueries) {
      print('\n--- Query: "$q" ---');
      final result = await parser.parse(q);

      if (result.isSuccess) {
        final parsed = result.query!;
        print('✅ SUCCESS (${result.latencyMs}ms, tokens: ${result.totalTokens})');
        print('   Intent: ${parsed.intent.toIntentString()}');
        if (parsed.actionType != null) print('   Action: ${parsed.actionType}');
        if (parsed.driverName != null) print('   Driver: ${parsed.driverName}');
        if (parsed.targetRallyName != null) print('   Rally: ${parsed.targetRallyName}');
        if (parsed.country != null) print('   Country: ${parsed.country}');
        if (parsed.year != null) print('   Year: ${parsed.year}');
        print('   Interpreted Summary: "${result.interpretedSummary}"');
      } else if (result.requiresClarification) {
        print('⚠️ REQUIRES CLARIFICATION: ${result.clarificationQuestion}');
      } else {
        print('❌ ERROR: ${result.error}');
        if (result.rawResponse != null) {
          print('   Raw Response: ${result.rawResponse}');
        }
      }
    }

    print('\n==============================================');
    print('Gemini Live Test Complete');
    print('==============================================');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
