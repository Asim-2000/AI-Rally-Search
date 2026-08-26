import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/llm/eval/benchmark_dataset.dart';
import 'package:ai_rally_search/services/llm/eval/eval_report_formatter.dart';
import 'package:ai_rally_search/services/llm/eval/llm_evaluator.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/fallback_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/gemini_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/openai_query_parser.dart';

void main(List<String> args) async {
  print('🏎️  Initializing AI Rally Search LLM Benchmark Runner...\n');

  // Load .env if available
  final envFile = File('.env');
  if (envFile.existsSync()) {
    await dotenv.load(fileName: '.env');
  }

  // Parse CLI args
  String providerArg = 'mock';
  String? modelArg;
  String? jsonOutputPath = 'eval_report.json';
  String? mdOutputPath = 'eval_summary.md';

  for (final arg in args) {
    if (arg.startsWith('--provider=')) {
      providerArg = arg.split('=')[1].trim().toLowerCase();
    } else if (arg.startsWith('--model=')) {
      modelArg = arg.split('=')[1].trim();
    } else if (arg.startsWith('--json=')) {
      jsonOutputPath = arg.split('=')[1].trim();
    } else if (arg.startsWith('--md=')) {
      mdOutputPath = arg.split('=')[1].trim();
    } else if (arg == '--help' || arg == '-h') {
      print('Usage: dart run bin/run_eval.dart [options]');
      print('Options:');
      print('  --provider=<gemini|openai|mock|fallback>   Target LLM provider (default: mock)');
      print('  --model=<model-name>                      LLM model name (optional)');
      print('  --json=<path>                             Path to save JSON evaluation report (default: eval_report.json)');
      print('  --md=<path>                               Path to save Markdown report (default: eval_summary.md)');
      return;
    }
  }

  // Initialize parser based on provider
  LlmQueryParser parser;
  final provider = LlmProvider.fromString(providerArg);

  switch (provider) {
    case LlmProvider.gemini:
      final config = LlmConfig.fromEnvironment(defaultProvider: LlmProvider.gemini);
      final finalConfig = modelArg != null ? config.copyWith(model: modelArg) : config;
      parser = GeminiQueryParser(config: finalConfig);
      break;
    case LlmProvider.openai:
      final config = LlmConfig.fromEnvironment(defaultProvider: LlmProvider.openai);
      final finalConfig = modelArg != null ? config.copyWith(model: modelArg) : config;
      parser = OpenAIQueryParser(config: finalConfig);
      break;
    case LlmProvider.mock:
      parser = MockLlmQueryParser();
      break;
    case LlmProvider.anthropic:
    default:
      parser = FallbackLlmQueryParser(primary: MockLlmQueryParser());
      break;
  }

  print('⚡ Evaluating Provider: ${provider.name.toUpperCase()}');
  print('📋 Test Cases: ${BenchmarkDataset.testCases.length} queries across ${BenchmarkDataset.testCases.map((c) => c.category).toSet().length} categories\n');

  final evaluator = const LlmEvaluator();

  final report = await evaluator.evaluateBenchmark(
    testCases: BenchmarkDataset.testCases,
    parser: parser,
    onProgress: (current, total, record) {
      final statusIcon = record.accuracy.exactMatch ? '✅' : (record.accuracy.intentMatch ? '⚠️' : '❌');
      final costStr = record.cost.formattedTotalCost;
      final latStr = '${record.latency.totalLatencyMs}ms';
      stdout.write('  [$current/$total] $statusIcon [${record.queryId}] ${record.inputQuery} ($latStr, $costStr)\n');
    },
  );

  // Print Formatted Console Report
  final consoleReport = EvalReportFormatter.formatConsoleReport(report);
  print(consoleReport);

  // Save JSON report
  if (jsonOutputPath != null && jsonOutputPath.isNotEmpty) {
    final jsonContent = EvalReportFormatter.formatJsonReport(report);
    File(jsonOutputPath).writeAsStringSync(jsonContent);
    print('💾 JSON Report saved to: $jsonOutputPath');
  }

  // Save Markdown report
  if (mdOutputPath != null && mdOutputPath.isNotEmpty) {
    final mdContent = EvalReportFormatter.formatMarkdownReport(report);
    File(mdOutputPath).writeAsStringSync(mdContent);
    print('📝 Markdown Summary saved to: $mdOutputPath');
  }

  print('\n🎯 Evaluation complete!');
}
