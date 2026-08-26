import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/llm/providers/openai_query_parser.dart';
import 'eval_models.dart';
import 'provider_evaluator.dart';
import 'query_benchmark_cases.dart';

void main() {
  test('Phase 4.1 — Regression Test for 12 Previous Failures', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    final envFile = File('.env');
    if (envFile.existsSync()) {
      await dotenv.load(fileName: '.env');
    }

    final parser = OpenAIQueryParser();
    const evaluator = ProviderEvaluator();

    final targetIds = [
      'ACT-08',
      'ACT-10',
      'ACT-11',
      'ACT-12',
      'ACT-18',
      'CMP-09',
      'CMP-10',
      'AMB-04',
      'AMB-07',
      'CAS-12',
      'TYP-06',
      'TYP-10',
    ];

    final targetCases = QueryBenchmarkCases.allCases.where((c) => targetIds.contains(c.id)).toList();
    print('================================================================');
    print('🏎️  PHASE 4.1: TESTING 12 TARGET FAILURE REGRESSIONS');
    print('================================================================');

    int passed = 0;
    for (int i = 0; i < targetCases.length; i++) {
      final c = targetCases[i];
      final record = await evaluator.evaluateCase(testCase: c, parser: parser);
      final icon = record.exactMatch ? '✅' : '❌';
      print('[$icon] [${c.id}] "${c.query}"');
      print('      Expected: intent=${c.expectedIntent?.name}, clarification=${c.expectedClarification}, filters=${c.expectedFilters}');
      if (record.parseResult.requiresClarification) {
        print('      Actual:   clarification=${record.parseResult.clarificationQuestion}');
      } else {
        final q = record.parseResult.query;
        print('      Actual:   intent=${q?.intent.name}, action=${q?.actionType}, rally=${q?.rallyName}, country=${q?.country}, stage=${q?.stageName}, year=${q?.year}');
      }
      if (record.failures.isNotEmpty) {
        for (final f in record.failures) {
          print('      ⚠️ ${f.type.name}: ${f.message}');
        }
      }
      if (record.exactMatch) {
        passed++;
      }
      print('');
      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('================================================================');
    print('REGRESSION RESULT: $passed / ${targetCases.length} PASSED');
    print('================================================================');

    expect(passed, targetCases.length, reason: 'All 12 previous failure cases must now pass');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
