import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'eval_models.dart';
import 'eval_report_formatter.dart';
import 'provider_evaluator.dart';
import 'query_benchmark_cases.dart';

void main() {
  group('1. Model Pricing & Cost Calculation Tests', () {
    test('Calculates exact cost for GPT-4o-mini', () {
      final pricing = ModelPricing.getPricing(model: 'gpt-4o-mini');
      expect(pricing, isNotNull);
      expect(pricing!.inputCostPerMillionTokens, 0.15);
      expect(pricing.outputCostPerMillionTokens, 0.60);

      // 1,000 prompt tokens + 1,000 completion tokens
      // Prompt: (1,000 / 1M) * 0.15 = $0.00015
      // Completion: (1,000 / 1M) * 0.60 = $0.0006
      // Total = $0.00075
      final cost = pricing.computeTotalCost(1000, 1000);
      expect(cost, closeTo(0.00075, 0.000001));
    });

    test('Calculates exact cost for Gemini 2.0 Flash', () {
      final pricing = ModelPricing.getPricing(model: 'gemini-2.0-flash');
      expect(pricing, isNotNull);
      expect(pricing!.inputCostPerMillionTokens, 0.10);
      expect(pricing.outputCostPerMillionTokens, 0.40);

      // 2,000 prompt tokens + 500 completion tokens
      // Prompt: 2,000 * 0.10 / 1M = 0.0002
      // Completion: 500 * 0.40 / 1M = 0.0002
      // Total = 0.0004
      final cost = pricing.computeTotalCost(2000, 500);
      expect(cost, closeTo(0.0004, 0.000001));
    });

    test('Calculates cost for Claude 3.5 Sonnet', () {
      final pricing = ModelPricing.getPricing(model: 'claude-3-5-sonnet-20241022');
      expect(pricing, isNotNull);
      expect(pricing!.inputCostPerMillionTokens, 3.00);
      expect(pricing.outputCostPerMillionTokens, 15.00);

      final cost = pricing.computeTotalCost(1000, 1000);
      expect(cost, closeTo(0.018, 0.00001));
    });

    test('Returns null for unknown model pricing (no invented numbers)', () {
      final pricing = ModelPricing.getPricing(model: 'unreleased-custom-model-9000');
      expect(pricing, isNull);
    });

    test('Returns zero cost for Mock parser', () {
      final pricing = ModelPricing.getPricing(model: 'mock-parser-v1', provider: LlmProvider.mock);
      expect(pricing, isNotNull);
      expect(pricing!.computeTotalCost(5000, 5000), 0.0);
    });
  });

  group('2. LatencyStats Percentile Tests', () {
    test('Computes mean, median (p50), p90, p95, p99 on latency distribution', () {
      final latencies = [100, 150, 200, 250, 300, 350, 400, 450, 500, 1000];
      final stats = LatencyStats.fromValues(latencies);

      expect(stats.count, 10);
      expect(stats.minMs, 100);
      expect(stats.maxMs, 1000);
      expect(stats.meanMs, 370.0);
      expect(stats.p50Ms, 350); // Median
      expect(stats.p90Ms, 500);
      expect(stats.p95Ms, 1000);
      expect(stats.p99Ms, 1000);
    });

    test('Handles empty latency list gracefully without throwing', () {
      final stats = LatencyStats.fromValues([]);
      expect(stats.count, 0);
      expect(stats.minMs, 0);
      expect(stats.maxMs, 0);
      expect(stats.meanMs, 0.0);
      expect(stats.p50Ms, 0);
    });
  });

  group('3. Metric Scoring & Failure Detection Tests', () {
    const evaluator = ProviderEvaluator();

    test('Scores 100% on exact match when all slots and intent match', () async {
      final fakeParser = _StaticLlmParser(
        result: const QueryParseResult(
          query: SearchQuery(
            intent: SearchIntent.searchVideoActions,
            actionType: 'jump',
            rallyName: 'Moonraker',
            limit: 20,
          ),
        ),
      );

      const tc = BenchmarkCase(
        id: 'TEST-PERFECT',
        query: 'Show jump highlights from Moonraker.',
        category: 'Video Actions',
        expectedIntent: SearchIntent.searchVideoActions,
        expectedFilters: {'actionType': 'jump', 'rallyName': 'Moonraker'},
      );

      final record = await evaluator.evaluateCase(testCase: tc, parser: fakeParser);
      expect(record.exactMatch, isTrue);
      expect(record.intentMatch, isTrue);
      expect(record.compoundComplete, isTrue);
      expect(record.hasHallucination, isFalse);
      expect(record.hasEntityPreserved, isTrue);
      expect(record.failures, isEmpty);
      expect(record.truePositiveSlots, 2);
      expect(record.falsePositiveSlots, 0);
      expect(record.falseNegativeSlots, 0);
    });

    test('Detects and penalizes hallucinated filters', () async {
      // User asked for "Show jumps in Ireland"
      // Model returned actionType='jump', country='Ireland', and hallucinated year=2025
      final fakeParser = _StaticLlmParser(
        result: const QueryParseResult(
          query: SearchQuery(
            intent: SearchIntent.searchVideoActions,
            actionType: 'jump',
            country: 'Ireland',
            year: 2025, // Hallucination!
          ),
        ),
      );

      const tc = BenchmarkCase(
        id: 'TEST-HALLUCINATION',
        query: 'Show jumps in Ireland.',
        category: 'Video Actions',
        expectedIntent: SearchIntent.searchVideoActions,
        expectedFilters: {'actionType': 'jump', 'country': 'Ireland'},
      );

      final record = await evaluator.evaluateCase(testCase: tc, parser: fakeParser);
      expect(record.exactMatch, isFalse);
      expect(record.hasHallucination, isTrue);
      expect(record.failures.any((f) => f.type == FailureType.hallucinatedFilter), isTrue);
      final hallucinationFailure = record.failures.firstWhere((f) => f.type == FailureType.hallucinatedFilter);
      expect(hallucinationFailure.slotName, 'year');
      expect(hallucinationFailure.actualValue, 2025);
    });

    test('Detects when entity phrase was rewritten / expanded into canonical DB name', () async {
      // User asked for "Who won Moonraker?"
      // Model outputted rallyName = "Moonraker Forestry Rally 2025" (expanded instead of raw phrase)
      final fakeParser = _StaticLlmParser(
        result: const QueryParseResult(
          query: SearchQuery(
            intent: SearchIntent.getRallyResults,
            rallyName: 'Moonraker Forestry Rally 2025',
          ),
        ),
      );

      const tc = BenchmarkCase(
        id: 'TEST-ENTITY-PRESERVE',
        query: 'Who won Moonraker?',
        category: 'Results',
        expectedIntent: SearchIntent.getRallyResults,
        expectedFilters: {'rallyName': 'Moonraker'},
      );

      final record = await evaluator.evaluateCase(testCase: tc, parser: fakeParser);
      expect(record.exactMatch, isFalse);
      expect(record.hasEntityPreserved, isFalse);
      expect(record.failures.any((f) => f.type == FailureType.entityRewritten), isTrue);
    });

    test('Evaluates clarification correctness when clarification is expected', () async {
      final fakeParser = _StaticLlmParser(
        result: QueryParseResult.clarification(
          clarificationQuestion: 'Which rally results are you looking for?',
        ),
      );

      const tc = BenchmarkCase(
        id: 'TEST-CLARIF',
        query: 'Show results',
        category: 'Ambiguous Queries',
        expectedClarification: true,
      );

      final record = await evaluator.evaluateCase(testCase: tc, parser: fakeParser);
      expect(record.clarificationMatch, isTrue);
      expect(record.exactMatch, isTrue);
      expect(record.failures, isEmpty);
    });

    test('Detects failure when clarification was expected but model guessed a query', () async {
      final fakeParser = _StaticLlmParser(
        result: const QueryParseResult(
          query: SearchQuery(intent: SearchIntent.searchRallies),
        ),
      );

      const tc = BenchmarkCase(
        id: 'TEST-CLARIF-FAIL',
        query: 'Show results',
        category: 'Ambiguous Queries',
        expectedClarification: true,
      );

      final record = await evaluator.evaluateCase(testCase: tc, parser: fakeParser);
      expect(record.clarificationMatch, isFalse);
      expect(record.exactMatch, isFalse);
      expect(record.failures.any((f) => f.type == FailureType.incorrectClarification), isTrue);
    });

    test('Calculates compound query completeness when all constraints are extracted', () async {
      final fakeParser = _StaticLlmParser(
        result: const QueryParseResult(
          query: SearchQuery(
            intent: SearchIntent.searchVideoActions,
            actionType: 'jump',
            driverName: 'Josh Moffett',
            country: 'Ireland',
            year: 2025,
          ),
        ),
      );

      const tc = BenchmarkCase(
        id: 'TEST-CMP',
        query: 'Show jump highlights featuring Josh Moffett from Irish rallies in 2025',
        category: 'Compound Queries',
        difficulty: CaseDifficulty.hard,
        expectedIntent: SearchIntent.searchVideoActions,
        expectedFilters: {
          'actionType': 'jump',
          'driverName': 'Josh Moffett',
          'country': 'Ireland',
          'year': 2025,
        },
      );

      final record = await evaluator.evaluateCase(testCase: tc, parser: fakeParser);
      expect(record.exactMatch, isTrue);
      expect(record.compoundComplete, isTrue);
      expect(record.truePositiveSlots, 4);
    });

    test('Detects missing filter in compound query', () async {
      final fakeParser = _StaticLlmParser(
        result: const QueryParseResult(
          query: SearchQuery(
            intent: SearchIntent.searchVideoActions,
            actionType: 'jump',
            driverName: 'Josh Moffett',
            // Missing country: Ireland, year: 2025
          ),
        ),
      );

      const tc = BenchmarkCase(
        id: 'TEST-CMP-MISSING',
        query: 'Show jump highlights featuring Josh Moffett from Irish rallies in 2025',
        category: 'Compound Queries',
        difficulty: CaseDifficulty.hard,
        expectedIntent: SearchIntent.searchVideoActions,
        expectedFilters: {
          'actionType': 'jump',
          'driverName': 'Josh Moffett',
          'country': 'Ireland',
          'year': 2025,
        },
      );

      final record = await evaluator.evaluateCase(testCase: tc, parser: fakeParser);
      expect(record.exactMatch, isFalse);
      expect(record.compoundComplete, isFalse);
      expect(record.failures.where((f) => f.type == FailureType.missingFilter).length, 2);
    });
  });

  group('4. Benchmark Dataset Integrity Tests', () {
    test('Benchmark dataset contains at least 150 cases with coverage across all 13 categories', () {
      final cases = QueryBenchmarkCases.allCases;
      expect(cases.length, greaterThanOrEqualTo(150));

      final categories = cases.map((c) => c.category).toSet();
      expect(categories.length, greaterThanOrEqualTo(13));

      expect(categories, contains('Rally Discovery'));
      expect(categories, contains('Driver Participation'));
      expect(categories, contains('Driver Wins'));
      expect(categories, contains('Results'));
      expect(categories, contains('Leaderboards'));
      expect(categories, contains('Video Search'));
      expect(categories, contains('Video Actions'));
      expect(categories, contains('Uploaders'));
      expect(categories, contains('Global Stats'));
      expect(categories, contains('Compound Queries'));
      expect(categories, contains('Ambiguous Queries'));
      expect(categories, contains('Casual Language'));
      expect(categories, contains('Typos'));

      // Check all cases have unique non-empty IDs
      final ids = cases.map((c) => c.id).toList();
      expect(ids.toSet().length, cases.length);
    });
  });

  group('5. Full Evaluation & Multi-Provider Comparison Tests', () {
    const evaluator = ProviderEvaluator();

    test('Evaluates Mock parser offline across a representative test suite', () async {
      final parser = MockLlmQueryParser();
      // Test across first 20 cases offline
      final sampleCases = QueryBenchmarkCases.allCases.take(20).toList();

      final report = await evaluator.evaluate(
        parser: parser,
        cases: sampleCases,
      );

      expect(report.numberOfCases, 20);
      expect(report.intentAccuracyPct, greaterThanOrEqualTo(90.0));
      expect(report.filterPrecisionPct, greaterThanOrEqualTo(85.0));
      expect(report.filterRecallPct, greaterThanOrEqualTo(80.0));
      expect(report.filterF1Pct, greaterThanOrEqualTo(80.0));
      expect(report.categoryMetrics, isNotEmpty);
      expect(report.difficultyMetrics, isNotEmpty);
      expect(report.productionWeightedScorePct, greaterThan(0.0));
    });

    test('Compares multiple mock/synthetic parsers in comparison matrix', () async {
      final parser1 = MockLlmQueryParser();
      final parser2 = _StaticLlmParser(
        result: const QueryParseResult(
          query: SearchQuery(intent: SearchIntent.searchRallies),
        ),
      );

      final sampleCases = QueryBenchmarkCases.allCases.take(10).toList();
      final comparison = await evaluator.compareProviders(
        parsers: [parser1, parser2],
        cases: sampleCases,
      );

      expect(comparison.length, 2);

      final compTable = EvalReportFormatter.formatComparisonTable(comparison);
      expect(compTable, contains('MULTI-PROVIDER BENCHMARK COMPARISON'));
      expect(compTable, contains('Intent'));
      expect(compTable, contains('Filter F1'));
      expect(compTable, contains('Exact Match'));

      final compMd = EvalReportFormatter.formatComparisonMarkdown(comparison);
      expect(compMd, contains('# LLM Provider Benchmark Comparison Matrix'));
      expect(compMd, contains('| Provider / Model |'));
    });

    test('Generates complete ASCII, Markdown, and JSON reports with all metrics and slots', () async {
      final parser = MockLlmQueryParser();
      final sampleCases = QueryBenchmarkCases.allCases.take(15).toList();

      final report = await evaluator.evaluate(
        parser: parser,
        cases: sampleCases,
      );

      final consoleStr = EvalReportFormatter.formatConsoleReport(report);
      expect(consoleStr, contains('AI RALLY SEARCH — LLM QUERY PARSER EVALUATION REPORT'));
      expect(consoleStr, contains('PRIMARY EVALUATION METRICS'));
      expect(consoleStr, contains('PRODUCTION WEIGHTED SCORE'));
      expect(consoleStr, contains('LATENCY DISTRIBUTION'));
      expect(consoleStr, contains('CATEGORY BREAKDOWN'));

      final mdStr = EvalReportFormatter.formatMarkdownReport(report);
      expect(mdStr, contains('# LLM Query Parser Evaluation Report'));
      expect(mdStr, contains('## Executive Summary'));
      expect(mdStr, contains('## Latency & Economics'));
      expect(mdStr, contains('## Per-Slot Extraction Metrics'));

      final jsonStr = EvalReportFormatter.formatJsonReport(report);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['numberOfCases'], 15);
      expect(decoded['summary']['intent_accuracy_pct'], isNotNull);
      expect(decoded['summary']['production_weighted_score_pct'], isNotNull);
      expect(decoded['slot_metrics']['driverName'], isNotNull);
      expect(decoded['records'], isList);
    });
  });
}

/// Helper static mock parser returning a fixed parse result for unit test assertions.
class _StaticLlmParser implements LlmQueryParser {
  final QueryParseResult result;

  _StaticLlmParser({required this.result});

  @override
  LlmProvider get provider => LlmProvider.mock;

  @override
  Future<QueryParseResult> parse(String query, {SearchContext? context}) async {
    return result;
  }
}
