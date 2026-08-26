import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/llm/providers/openai_query_parser.dart';
import 'eval_models.dart';
import 'multilingual_benchmark_cases.dart';
import 'provider_evaluator.dart';

void main() {
  test('Phase 5A.1 — Multilingual Regression Test for 20 Failure Cases', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    final envFile = File('.env');
    if (envFile.existsSync()) {
      await dotenv.load(fileName: '.env');
    }

    final parser = OpenAIQueryParser();
    const evaluator = ProviderEvaluator();

    final targetIds = [
      'EN-02',
      'FR-02',
      'IT-02',
      'PL-02',
      'PL-08',
      'PL-12',
      'PL-16',
      'LV-02',
      'CS-08',
      'CS-16',
      'HR-02',
      'HR-08',
      'HR-12',
      'HR-16',
      'SK-08',
      'SK-11',
      'SK-16',
      'UR-02',
      'AR-02',
      'GA-02',
    ];

    final targetCases = MultilingualBenchmarkCases.allCases
        .where((c) => targetIds.contains(c.id))
        .toList();

    print('================================================================');
    print('🏎️  PHASE 5A.1: TESTING 20 TARGET MULTILINGUAL REGRESSIONS');
    print('================================================================');

    int passed = 0;
    final failureDetails = <Map<String, dynamic>>[];

    for (int i = 0; i < targetCases.length; i++) {
      final c = targetCases[i];
      final record = await evaluator.evaluateCase(testCase: c, parser: parser);
      final icon = record.exactMatch ? '✅' : '❌';
      print('[$icon] [${c.id}] (${c.languageCode}) "${c.query}"');
      print('      Expected: intent=${c.expectedIntent?.name}, clarification=${c.expectedClarification}, filters=${c.expectedFilters}');
      if (record.parseResult.requiresClarification) {
        print('      Actual:   clarification=${record.parseResult.clarificationQuestion}');
      } else {
        final q = record.parseResult.query;
        print('      Actual:   intent=${q?.intent.name}, driver=${q?.driverName}, rally=${q?.rallyName}, city=${q?.city}, country=${q?.country}, action=${q?.actionType}, year=${q?.year}');
      }

      if (record.failures.isNotEmpty) {
        for (final f in record.failures) {
          print('      ⚠️ ${f.type.name}: ${f.message}');
        }
        failureDetails.add({
          'id': c.id,
          'lang': c.languageCode,
          'query': c.query,
          'expected': {
            'intent': c.expectedIntent?.name,
            'filters': c.expectedFilters,
          },
          'actual': record.parseResult.query != null
              ? {
                  'intent': record.parseResult.query!.intent.name,
                  'driverName': record.parseResult.query!.driverName,
                  'rallyName': record.parseResult.query!.rallyName,
                  'city': record.parseResult.query!.city,
                  'country': record.parseResult.query!.country,
                  'actionType': record.parseResult.query!.actionType,
                  'year': record.parseResult.query!.year,
                }
              : 'Requires clarification (${record.parseResult.clarificationQuestion})',
          'failures': record.failures.map((f) => '[${f.type.name}] ${f.message}').toList(),
        });
      } else {
        passed++;
      }
      print('');
      await Future.delayed(const Duration(milliseconds: 80));
    }

    print('================================================================');
    print('REGRESSION RESULT: $passed / ${targetCases.length} PASSED');
    print('================================================================');

    if (failureDetails.isNotEmpty) {
      print('REMAINING FAILURES (${failureDetails.length}):');
      for (final f in failureDetails) {
        print('  • [${f['id']}] "${f['query']}":');
        print('    Expected: ${f['expected']}');
        print('    Actual:   ${f['actual']}');
        print('    Reasons:  ${f['failures']}');
      }
    }

    expect(passed, targetCases.length, reason: 'All 20 multilingual regression cases should pass');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
