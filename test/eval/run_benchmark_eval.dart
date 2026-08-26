import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/llm/eval/benchmark_dataset.dart';
import 'package:ai_rally_search/services/llm/eval/eval_report_formatter.dart';
import 'package:ai_rally_search/services/llm/eval/llm_evaluator.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/fallback_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/gemini_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/openai_query_parser.dart';

void main() {
  test('Execute Benchmark Evaluation & Generate Reports', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    final envFile = File('.env');
    if (envFile.existsSync()) {
      await dotenv.load(fileName: '.env');
    }

    final rawEvalProvider = dotenv.isInitialized ? (dotenv.env['EVAL_PROVIDER'] ?? 'mock') : 'mock';
    final providerType = LlmProvider.fromString(rawEvalProvider);

    LlmQueryParser parser;
    switch (providerType) {
      case LlmProvider.gemini:
        parser = GeminiQueryParser();
        break;
      case LlmProvider.openai:
        parser = OpenAIQueryParser();
        break;
      case LlmProvider.anthropic:
        parser = FallbackLlmQueryParser(primary: MockLlmQueryParser());
        break;
      case LlmProvider.mock:
      default:
        parser = MockLlmQueryParser();
        break;
    }

    print('\n======================================================');
    print('🏎️  RUNNING BENCHMARK EVALUATION FOR: ${parser.provider.name.toUpperCase()}');
    print('======================================================\n');

    final evaluator = const LlmEvaluator();

    final report = await evaluator.evaluateBenchmark(
      testCases: BenchmarkDataset.testCases,
      parser: parser,
      onProgress: (current, total, record) {
        final statusIcon = record.accuracy.exactMatch ? '✅' : (record.accuracy.intentMatch ? '⚠️' : '❌');
        final costStr = record.cost.formattedTotalCost;
        final latStr = '${record.latency.totalLatencyMs}ms';
        print('  [$current/$total] $statusIcon [${record.queryId}] "${record.inputQuery}" ($latStr, $costStr)');
      },
    );

    // Format and print console report
    final consoleReport = EvalReportFormatter.formatConsoleReport(report);
    print(consoleReport);

    // Save JSON and Markdown artifacts
    final jsonReport = EvalReportFormatter.formatJsonReport(report);
    File('eval_report.json').writeAsStringSync(jsonReport);
    print('💾 Saved JSON evaluation report to: eval_report.json');

    final mdReport = EvalReportFormatter.formatMarkdownReport(report);
    File('eval_summary.md').writeAsStringSync(mdReport);
    print('📝 Saved Markdown summary to: eval_summary.md');

    expect(report.totalQueries, BenchmarkDataset.testCases.length);
    expect(report.overallQualityScorePct, greaterThanOrEqualTo(80.0));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
