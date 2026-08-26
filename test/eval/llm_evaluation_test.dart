import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/eval/benchmark_dataset.dart';
import 'package:ai_rally_search/services/llm/eval/eval_models.dart';
import 'package:ai_rally_search/services/llm/eval/eval_report_formatter.dart';
import 'package:ai_rally_search/services/llm/eval/llm_cost_calculator.dart';
import 'package:ai_rally_search/services/llm/eval/llm_evaluator.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';

void main() {
  group('Pillar 1: LlmCostCalculator Tests', () {
    test('Calculates exact cost for Gemini 2.0 Flash', () {
      final pricing = LlmCostCalculator.getPricing(model: 'gemini-2.0-flash');
      expect(pricing.promptCostPerMillion, 0.10);
      expect(pricing.completionCostPerMillion, 0.40);

      // 1,000 prompt tokens + 500 completion tokens
      // Prompt: (1,000 / 1M) * 0.10 = $0.0001
      // Completion: (500 / 1M) * 0.40 = $0.0002
      // Total = $0.0003
      final cost = LlmCostCalculator.calculateCost(
        promptTokens: 1000,
        completionTokens: 500,
        model: 'gemini-2.0-flash',
      );
      expect(cost, closeTo(0.0003, 0.0000001));
    });

    test('Calculates exact cost for GPT-4o-mini', () {
      final cost = LlmCostCalculator.calculateCost(
        promptTokens: 1000,
        completionTokens: 1000,
        model: 'gpt-4o-mini',
      );
      // 0.15/1M * 1000 + 0.60/1M * 1000 = 0.00015 + 0.0006 = 0.00075
      expect(cost, closeTo(0.00075, 0.0000001));
    });

    test('Calculates zero cost for Mock parser', () {
      final cost = LlmCostCalculator.calculateCost(
        promptTokens: 5000,
        completionTokens: 2000,
        model: 'mock-parser-v1',
      );
      expect(cost, 0.0);
    });

    test('Formats USD cost strings correctly', () {
      expect(LlmCostCalculator.formatCostUsd(0.0), '\$0.000000');
      expect(LlmCostCalculator.formatCostUsd(0.000045), '\$0.000045');
      expect(LlmCostCalculator.formatCostUsd(1.23456), '\$1.2346');
    });

    test('Estimates cost per 1,000 queries', () {
      final perThousand = LlmCostCalculator.estimateCostPerThousand(0.0002);
      expect(perThousand, closeTo(0.20, 0.0001));
    });
  });

  group('Pillar 2: LatencyStats & Breakdown Tests', () {
    test('Calculates correct percentiles on latency list', () {
      final latencies = [100, 150, 200, 250, 300, 350, 400, 450, 500, 1000];
      final stats = LatencyStats.fromValues(latencies);

      expect(stats.count, 10);
      expect(stats.minMs, 100);
      expect(stats.maxMs, 1000);
      expect(stats.meanMs, 370.0);
      expect(stats.p50Ms, 350); // Median
      expect(stats.p90Ms, 500);
      expect(stats.p99Ms, 1000);
    });

    test('Handles empty latency list gracefully', () {
      final stats = LatencyStats.fromValues([]);
      expect(stats.count, 0);
      expect(stats.minMs, 0);
      expect(stats.meanMs, 0.0);
    });
  });

  group('Pillar 3: Correctness Verification Tests', () {
    final evaluator = const LlmEvaluator();

    test('Scores 1.0 on a fully valid SearchQuery', () async {
      final parser = MockLlmQueryParser();
      final tc = BenchmarkTestCase(
        id: 'TEST-01',
        input: 'Show jump highlights from Moonraker.',
        category: 'Action Highlights',
        description: 'Test jump query',
        expectedQuery: const SearchQuery(
          intent: SearchIntent.searchVideoActions,
          actionType: 'jump',
          rallyName: 'Moonraker',
          limit: 20,
        ),
      );

      final record = await evaluator.evaluateTestCase(testCase: tc, parser: parser);
      expect(record.correctness.isFullyCorrect, isTrue);
      expect(record.correctness.score, 1.0);
      expect(record.correctness.violations, isEmpty);
    });
  });

  group('Pillar 4: Semantic Accuracy & Golden Dataset Tests', () {
    final evaluator = const LlmEvaluator();

    test('Validates exact match accuracy on Mock parser across Golden Dataset', () async {
      final parser = MockLlmQueryParser();
      final report = await evaluator.evaluateBenchmark(
        testCases: BenchmarkDataset.testCases,
        parser: parser,
      );

      expect(report.totalQueries, BenchmarkDataset.testCases.length);
      expect(report.successfulParses, greaterThanOrEqualTo(19));
      expect(report.overallQualityScorePct, greaterThanOrEqualTo(90.0));
      expect(report.schemaAdherencePct, 100.0);
      expect(report.intentAccuracyPct, greaterThanOrEqualTo(95.0));
    });

    test('Detects slot mismatch when driver name differs', () async {
      final parser = MockLlmQueryParser();
      final tc = BenchmarkTestCase(
        id: 'TEST-MISMATCH',
        input: 'Show videos featuring Josh Moffett.',
        category: 'Driver Videos',
        description: 'Driver mismatch test',
        expectedQuery: const SearchQuery(
          intent: SearchIntent.searchDriverVideos,
          driverName: 'Sebastien Ogier', // Expected Ogier but parser will return Moffett
          limit: 20,
        ),
      );

      final record = await evaluator.evaluateTestCase(testCase: tc, parser: parser);
      expect(record.accuracy.intentMatch, isTrue);
      expect(record.accuracy.exactMatch, isFalse);
      expect(record.accuracy.slotMatches['driverName'], isFalse);
    });
  });

  group('Report Formatter Tests', () {
    test('Generates valid ASCII, Markdown, and JSON evaluation reports', () async {
      final evaluator = const LlmEvaluator();
      final parser = MockLlmQueryParser();
      final report = await evaluator.evaluateBenchmark(
        testCases: BenchmarkDataset.testCases,
        parser: parser,
      );

      final consoleStr = EvalReportFormatter.formatConsoleReport(report);
      expect(consoleStr, contains('AI RALLY SEARCH - LLM EVALUATION BENCHMARK REPORT'));
      expect(consoleStr, contains('PILLAR 1: COST METRICS'));
      expect(consoleStr, contains('PILLAR 2: LATENCY DISTRIBUTION'));
      expect(consoleStr, contains('PILLAR 3: STRUCTURAL CORRECTNESS'));
      expect(consoleStr, contains('PILLAR 4: SEMANTIC ACCURACY'));

      final mdStr = EvalReportFormatter.formatMarkdownReport(report);
      expect(mdStr, contains('# LLM Evaluation Benchmark Report'));
      expect(mdStr, contains('Executive Summary'));

      final jsonStr = EvalReportFormatter.formatJsonReport(report);
      final decoded = jsonDecode(jsonStr);
      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded['summary']['total_queries'], BenchmarkDataset.testCases.length);
    });
  });
}
