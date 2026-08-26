import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/providers/openai_query_parser.dart';
import 'eval_models.dart';
import 'query_benchmark_cases.dart';

void main() {
  test('OpenAI Live 5 Smoke Test Cases', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    print('================================================================');
    print('🏎️  AI RALLY SEARCH — OPENAI LIVE SMOKE TEST (5 BENCHMARK CASES)');
    print('================================================================');

    // Load .env
    final envFile = File('.env');
    if (envFile.existsSync()) {
      await dotenv.load(fileName: '.env');
    }

    final parser = OpenAIQueryParser();
    print('Provider: ${parser.provider.name.toUpperCase()}');
    print('Model:    ${parser.config.model}');
    print('Timeout:  ${parser.config.timeout.inSeconds}s');
    print('Base URL: ${parser.config.baseUrl ?? "https://api.openai.com/v1"}\n');

    // Define the 5 target smoke test cases
    final smokeCases = [
      QueryBenchmarkCases.allCases.firstWhere((c) => c.id == 'RAL-01'), // Simple rally search
      QueryBenchmarkCases.allCases.firstWhere((c) => c.id == 'CMP-08'), // Compound action+driver+rally+year
      QueryBenchmarkCases.allCases.firstWhere((c) => c.id == 'CAS-05'), // Noisy/casual query
      QueryBenchmarkCases.allCases.firstWhere((c) => c.id == 'RES-01'), // Entity-preservation query ("Moonraker")
      QueryBenchmarkCases.allCases.firstWhere((c) => c.id == 'AMB-01'), // Ambiguous entity query
    ];

    int passedCount = 0;

    for (int i = 0; i < smokeCases.length; i++) {
      final testCase = smokeCases[i];
      print('----------------------------------------------------------------');
      print('CASE ${i + 1}/${smokeCases.length} [${testCase.id}] (${testCase.category})');
      print('Query: "${testCase.query}"');
      print('Expected Intent:        ${testCase.expectedIntent?.name ?? "null (clarification expected: ${testCase.expectedClarification})"}');
      print('Expected Filters:       ${testCase.expectedFilters}');
      print('Expected Clarification: ${testCase.expectedClarification}');
      print('----------------------------------------------------------------');

      final result = await parser.parse(testCase.query, context: testCase.context);

      print('⏱️ Latency: ${result.latencyMs} ms | Tokens: ${result.promptTokens} prompt + ${result.completionTokens} completion = ${result.totalTokens} total');

      if (!result.isSuccess && !result.requiresClarification) {
        print('❌ FAILED: ${result.error}');
        continue;
      }

      if (result.requiresClarification) {
        print('ℹ️ Clarification Requested: "${result.clarificationQuestion}"');
        print('Expected Clarification: ${testCase.expectedClarification}');
        if (testCase.expectedClarification) {
          print('✅ PASSED (Correctly requested clarification)');
          passedCount++;
        } else {
          print('❌ UNEXPECTED CLARIFICATION');
        }
      } else {
        final sq = result.query!;
        print('PARSED SearchQuery (Before Entity Resolution):');
        print('  • Intent:     ${sq.intent.name}');
        print('  • ActionType: ${sq.actionType}');
        print('  • DriverName: ${sq.driverName != null ? "\"${sq.driverName}\"" : "null"}');
        print('  • RallyName:  ${sq.rallyName != null ? "\"${sq.rallyName}\"" : "null"}');
        print('  • StageName:  ${sq.stageName != null ? "\"${sq.stageName}\"" : "null"}');
        print('  • Country:    ${sq.country != null ? "\"${sq.country}\"" : "null"}');
        print('  • City:       ${sq.city != null ? "\"${sq.city}\"" : "null"}');
        print('  • Year:       ${sq.year}');
        print('  • Limit:      ${sq.limit}');

        // Check verbatim entity preservation
        if (testCase.query.contains('Moonraker')) {
          final preserved = sq.rallyName == 'Moonraker' || sq.rallyName?.contains('Moonraker') == true;
          print('🔍 Entity Preservation Check ("Moonraker"): ${preserved ? "✅ PRESERVED VERBATIM (\"${sq.rallyName}\")" : "❌ NOT PRESERVED (\"${sq.rallyName}\")"}');
        }
        if (testCase.query.contains('Josh Moffett')) {
          final preserved = sq.driverName == 'Josh Moffett';
          print('🔍 Entity Preservation Check ("Josh Moffett"): ${preserved ? "✅ PRESERVED VERBATIM (\"${sq.driverName}\")" : "❌ NOT PRESERVED (\"${sq.driverName}\")"}');
        }

        // Check Intent Match
        bool intentMatch = sq.intent == testCase.expectedIntent;
        print('🎯 Intent Match: ${intentMatch ? "✅" : "❌ (expected ${testCase.expectedIntent?.name}, got ${sq.intent.name})"}');

        if (intentMatch) {
          passedCount++;
        }
      }
      print('');
    }

    print('================================================================');
    print('SMOKE TEST SUMMARY: $passedCount / ${smokeCases.length} PASSED');
    print('================================================================\n');

    expect(passedCount, smokeCases.length);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
