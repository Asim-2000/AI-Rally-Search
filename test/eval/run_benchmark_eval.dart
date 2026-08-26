import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/anthropic_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/gemini_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/openai_query_parser.dart';
import 'eval_models.dart';
import 'eval_report_formatter.dart';
import 'multilingual_benchmark_cases.dart';
import 'provider_evaluator.dart';
import 'query_benchmark_cases.dart';

void main([List<String> args = const []]) {
  test('Run Benchmark Evaluation Suite', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    print('================================================================');
    print('🏎️  AI RALLY SEARCH — LLM BENCHMARK EVALUATOR');
    print('================================================================');

    // Load .env if present
    final envFile = File('.env');
    if (envFile.existsSync()) {
      await dotenv.load(fileName: '.env');
    }

    // Determine mode and target provider
    bool compareMode = Platform.environment['EVAL_COMPARE'] == 'true' || args.contains('--compare');
    bool isMultilingual = Platform.environment['EVAL_MULTILINGUAL'] == 'true' ||
        args.contains('--multilingual') ||
        args.contains('-m');
    String? filterLang;

    String providerArg = Platform.environment['EVAL_PROVIDER'] ??
        (dotenv.isInitialized ? (dotenv.env['EVAL_PROVIDER'] ?? 'mock') : 'mock');

    for (final arg in args) {
      if (arg.startsWith('--provider=')) {
        providerArg = arg.split('=')[1].trim().toLowerCase();
      } else if (arg == '--openai') {
        providerArg = 'openai';
      } else if (arg == '--gemini') {
        providerArg = 'gemini';
      } else if (arg == '--anthropic') {
        providerArg = 'anthropic';
      } else if (arg == '--mock') {
        providerArg = 'mock';
      } else if (arg == '--multilingual' || arg == '-m') {
        isMultilingual = true;
      } else if (arg.startsWith('--lang=')) {
        filterLang = arg.split('=')[1].trim().toLowerCase();
        isMultilingual = true;
      }
    }

    List<BenchmarkCase> testCases;
    if (isMultilingual) {
      if (filterLang != null && filterLang.isNotEmpty) {
        testCases = MultilingualBenchmarkCases.allCases
            .where((c) => c.languageCode?.toLowerCase() == filterLang)
            .toList();
        print('Loaded ${testCases.length} multilingual test cases for language: "$filterLang".');
      } else {
        testCases = MultilingualBenchmarkCases.allCases;
        print('Loaded ${testCases.length} multilingual test cases across 19 languages.');
      }
    } else {
      testCases = QueryBenchmarkCases.allCases;
      print('Loaded ${testCases.length} English benchmark test cases across 13 categories.');
    }


    final evaluator = const ProviderEvaluator();
    final reportsDir = Directory('test/eval/reports');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    if (compareMode) {
      print('\nStarting Multi-Provider Comparative Benchmark...');
      final parsers = <LlmQueryParser>[];

      if (dotenv.isInitialized && dotenv.env['OPENAI_API_KEY']?.isNotEmpty == true) {
        parsers.add(OpenAIQueryParser());
      }
      if (dotenv.isInitialized && dotenv.env['GEMINI_API_KEY']?.isNotEmpty == true) {
        parsers.add(GeminiQueryParser());
      }
      if (dotenv.isInitialized && dotenv.env['ANTHROPIC_API_KEY']?.isNotEmpty == true) {
        parsers.add(AnthropicQueryParser());
      }
      parsers.add(MockLlmQueryParser());

      print('Evaluating ${parsers.length} providers: ${parsers.map((p) => p.provider.name).join(', ')}');

      final comparisonReports = await evaluator.compareProviders(
        parsers: parsers,
        cases: testCases,
        delayBetweenQueries: const Duration(milliseconds: 50),
        onProgress: (provider, current, total, record) {
          final icon = record.exactMatch ? '✅' : (record.intentMatch ? '⚠️' : '❌');
          stdout.write('\r[$provider] Progress: $current/$total ($icon ${record.testCase.id})');
        },
      );
      print('\n');

      final compTable = EvalReportFormatter.formatComparisonTable(comparisonReports);
      print(compTable);

      final compMd = EvalReportFormatter.formatComparisonMarkdown(comparisonReports);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mdPath = 'test/eval/reports/comparison_report_$timestamp.md';
      File(mdPath).writeAsStringSync(compMd);
      print('📝 Saved comparison Markdown report to: $mdPath');

      final jsonMap = comparisonReports.map((k, v) => MapEntry(k, v.toJson()));
      final jsonPath = 'test/eval/reports/comparison_report_$timestamp.json';
      File(jsonPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonMap));
      print('💾 Saved comparison JSON data to: $jsonPath\n');
    } else {
      LlmQueryParser parser;
      switch (providerArg) {
        case 'openai':
          parser = OpenAIQueryParser();
          break;
        case 'gemini':
          parser = GeminiQueryParser();
          break;
        case 'anthropic':
          parser = AnthropicQueryParser();
          break;
        case 'mock':
        default:
          parser = MockLlmQueryParser();
          break;
      }

      print('\nRunning benchmark evaluation for provider: ${parser.provider.name.toUpperCase()}...');

      final report = await evaluator.evaluate(
        parser: parser,
        cases: testCases,
        delayBetweenQueries: providerArg != 'mock' ? const Duration(milliseconds: 100) : null,
        onProgress: (current, total, record) {
          final icon = record.exactMatch ? '✅' : (record.intentMatch ? '⚠️' : '❌');
          final costStr = record.costUsd != null ? '\$${record.costUsd!.toStringAsFixed(6)}' : 'N/A';
          stdout.write('\r  [$current/$total] $icon [${record.testCase.id}] "${record.testCase.query.padRight(40).substring(0, 40)}" (${record.latencyMs}ms, $costStr)');
        },
      );
      print('\n');

      final consoleReport = EvalReportFormatter.formatConsoleReport(report);
      print(consoleReport);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final modelSlug = report.modelName.replaceAll('/', '_').replaceAll(':', '_');

      // Save individual Markdown report
      final mdReport = EvalReportFormatter.formatMarkdownReport(report);
      final mdPath = 'test/eval/reports/${report.providerName}_${modelSlug}_$timestamp.md';
      File(mdPath).writeAsStringSync(mdReport);
      print('📝 Saved Markdown report to: $mdPath');

      // Save individual JSON report
      final jsonReport = EvalReportFormatter.formatJsonReport(report);
      final jsonPath = 'test/eval/reports/${report.providerName}_${modelSlug}_$timestamp.json';
      File(jsonPath).writeAsStringSync(jsonReport);
      print('💾 Saved JSON report to: $jsonPath\n');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
