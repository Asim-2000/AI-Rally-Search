import '../../../models/search_intent.dart';
import '../../../models/search_query.dart';
import '../llm_provider_config.dart';
import '../query_parse_result.dart';
import 'llm_cost_calculator.dart';

/// Latency metrics for a single query execution.
class LatencyBreakdown {
  final int parseLatencyMs;
  final int dbLatencyMs;
  final int totalLatencyMs;

  const LatencyBreakdown({
    required this.parseLatencyMs,
    this.dbLatencyMs = 0,
    required this.totalLatencyMs,
  });

  factory LatencyBreakdown.fromParse(int parseMs, [int dbMs = 0]) {
    return LatencyBreakdown(
      parseLatencyMs: parseMs,
      dbLatencyMs: dbMs,
      totalLatencyMs: parseMs + dbMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'parse_latency_ms': parseLatencyMs,
        'db_latency_ms': dbLatencyMs,
        'total_latency_ms': totalLatencyMs,
      };
}

/// Token and monetary cost metrics for a single query execution.
class CostBreakdown {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double promptCostUsd;
  final double completionCostUsd;
  final double totalCostUsd;
  final String model;
  final LlmProvider? provider;

  const CostBreakdown({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.promptCostUsd,
    required this.completionCostUsd,
    required this.totalCostUsd,
    required this.model,
    this.provider,
  });

  factory CostBreakdown.fromTokens({
    required int promptTokens,
    required int completionTokens,
    required String model,
    LlmProvider? provider,
  }) {
    final pricing = LlmCostCalculator.getPricing(model: model, provider: provider);
    final pCost = pricing.computePromptCost(promptTokens);
    final cCost = pricing.computeCompletionCost(completionTokens);
    return CostBreakdown(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
      promptCostUsd: pCost,
      completionCostUsd: cCost,
      totalCostUsd: pCost + cCost,
      model: model,
      provider: provider,
    );
  }

  factory CostBreakdown.zero({String model = 'mock-parser-v1', LlmProvider? provider}) {
    return CostBreakdown(
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0,
      promptCostUsd: 0.0,
      completionCostUsd: 0.0,
      totalCostUsd: 0.0,
      model: model,
      provider: provider,
    );
  }

  String get formattedTotalCost => LlmCostCalculator.formatCostUsd(totalCostUsd);

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
        'prompt_cost_usd': promptCostUsd,
        'completion_cost_usd': completionCostUsd,
        'total_cost_usd': totalCostUsd,
        'formatted_cost': formattedTotalCost,
        'model': model,
        'provider': provider?.name,
      };
}

/// Structural correctness verification against schema and domain invariants.
class CorrectnessReport {
  final bool isJsonValid;
  final bool hasValidIntent;
  final bool hasValidActionType;
  final bool hasValidYear;
  final bool hasValidPagination;
  final bool isClarificationSafe;
  final bool isDbExecutable;
  final List<String> violations;

  const CorrectnessReport({
    required this.isJsonValid,
    required this.hasValidIntent,
    required this.hasValidActionType,
    required this.hasValidYear,
    required this.hasValidPagination,
    required this.isClarificationSafe,
    required this.isDbExecutable,
    required this.violations,
  });

  /// Overall correctness score between 0.0 (total failure) and 1.0 (perfect compliance).
  double get score {
    int totalChecks = 7;
    int passed = 0;
    if (isJsonValid) passed++;
    if (hasValidIntent) passed++;
    if (hasValidActionType) passed++;
    if (hasValidYear) passed++;
    if (hasValidPagination) passed++;
    if (isClarificationSafe) passed++;
    if (isDbExecutable) passed++;
    return passed / totalChecks;
  }

  bool get isFullyCorrect => violations.isEmpty;

  Map<String, dynamic> toJson() => {
        'score': score,
        'is_fully_correct': isFullyCorrect,
        'is_json_valid': isJsonValid,
        'has_valid_intent': hasValidIntent,
        'has_valid_action_type': hasValidActionType,
        'has_valid_year': hasValidYear,
        'has_valid_pagination': hasValidPagination,
        'is_clarification_safe': isClarificationSafe,
        'is_db_executable': isDbExecutable,
        'violations': violations,
      };
}

/// Accuracy evaluation comparing generated output against ground truth.
class AccuracyReport {
  final bool intentMatch;
  final bool exactMatch;
  final bool clarificationMatch;
  final Map<String, bool> slotMatches;
  final double slotAccuracy;
  final String? mismatchReason;

  const AccuracyReport({
    required this.intentMatch,
    required this.exactMatch,
    required this.clarificationMatch,
    required this.slotMatches,
    required this.slotAccuracy,
    this.mismatchReason,
  });

  /// Composite accuracy score (0.0 to 1.0).
  double get compositeScore {
    if (exactMatch) return 1.0;
    double score = 0.0;
    if (intentMatch) score += 0.4;
    score += (slotAccuracy * 0.4);
    if (clarificationMatch) score += 0.2;
    return score.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'intent_match': intentMatch,
        'exact_match': exactMatch,
        'clarification_match': clarificationMatch,
        'slot_matches': slotMatches,
        'slot_accuracy': slotAccuracy,
        'composite_score': compositeScore,
        'mismatch_reason': mismatchReason,
      };
}

/// Comprehensive evaluation record for a single natural language query.
class QueryEvaluationRecord {
  final String queryId;
  final String inputQuery;
  final String category;
  final QueryParseResult parseResult;
  final SearchQuery? groundTruthQuery;
  final bool expectedClarification;
  final LatencyBreakdown latency;
  final CostBreakdown cost;
  final CorrectnessReport correctness;
  final AccuracyReport accuracy;
  final dynamic dbExecutionResult;
  final String? executionError;

  const QueryEvaluationRecord({
    required this.queryId,
    required this.inputQuery,
    required this.category,
    required this.parseResult,
    this.groundTruthQuery,
    this.expectedClarification = false,
    required this.latency,
    required this.cost,
    required this.correctness,
    required this.accuracy,
    this.dbExecutionResult,
    this.executionError,
  });

  Map<String, dynamic> toJson() => {
        'query_id': queryId,
        'input_query': inputQuery,
        'category': category,
        'is_success': parseResult.isSuccess,
        'latency': latency.toJson(),
        'cost': cost.toJson(),
        'correctness': correctness.toJson(),
        'accuracy': accuracy.toJson(),
        'interpreted_summary': parseResult.interpretedSummary,
        'execution_error': executionError,
      };
}

/// Latency statistics summary for a benchmark run.
class LatencyStats {
  final int count;
  final int minMs;
  final int maxMs;
  final double meanMs;
  final int p50Ms;
  final int p90Ms;
  final int p95Ms;
  final int p99Ms;

  const LatencyStats({
    required this.count,
    required this.minMs,
    required this.maxMs,
    required this.meanMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.p95Ms,
    required this.p99Ms,
  });

  factory LatencyStats.fromValues(List<int> latencies) {
    if (latencies.isEmpty) {
      return const LatencyStats(
        count: 0,
        minMs: 0,
        maxMs: 0,
        meanMs: 0.0,
        p50Ms: 0,
        p90Ms: 0,
        p95Ms: 0,
        p99Ms: 0,
      );
    }

    final sorted = List<int>.from(latencies)..sort();
    final count = sorted.length;
    final min = sorted.first;
    final max = sorted.last;
    final sum = sorted.reduce((a, b) => a + b);
    final mean = sum / count;

    int percentile(double p) {
      final index = ((count - 1) * p).round();
      return sorted[index];
    }

    return LatencyStats(
      count: count,
      minMs: min,
      maxMs: max,
      meanMs: mean,
      p50Ms: percentile(0.50),
      p90Ms: percentile(0.90),
      p95Ms: percentile(0.95),
      p99Ms: percentile(0.99),
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'min_ms': minMs,
        'max_ms': maxMs,
        'mean_ms': double.parse(meanMs.toStringAsFixed(2)),
        'p50_ms': p50Ms,
        'p90_ms': p90Ms,
        'p95_ms': p95Ms,
        'p99_ms': p99Ms,
      };
}

/// Comprehensive benchmark report aggregating all evaluation records.
class BenchmarkEvaluationReport {
  final String providerName;
  final String modelName;
  final DateTime timestamp;
  final int totalQueries;
  final int successfulParses;
  final int failedParses;
  final int clarificationTriggers;

  // Latency Aggregates
  final LatencyStats parseLatencyStats;
  final LatencyStats dbLatencyStats;
  final LatencyStats totalLatencyStats;

  // Cost Aggregates
  final int totalPromptTokens;
  final int totalCompletionTokens;
  final int totalTokens;
  final double totalCostUsd;
  final double avgCostPerQueryUsd;
  final double estimatedCostPerThousandUsd;

  // Accuracy Aggregates
  final double exactMatchAccuracyPct;
  final double intentAccuracyPct;
  final double slotAccuracyPct;
  final double clarificationAccuracyPct;
  final double overallQualityScorePct;

  // Correctness Aggregates
  final double schemaAdherencePct;
  final double dbExecutionSuccessPct;
  final double overallCorrectnessScorePct;

  // Category Breakdowns
  final Map<String, CategoryMetric> categoryMetrics;

  // Individual Records
  final List<QueryEvaluationRecord> records;

  const BenchmarkEvaluationReport({
    required this.providerName,
    required this.modelName,
    required this.timestamp,
    required this.totalQueries,
    required this.successfulParses,
    required this.failedParses,
    required this.clarificationTriggers,
    required this.parseLatencyStats,
    required this.dbLatencyStats,
    required this.totalLatencyStats,
    required this.totalPromptTokens,
    required this.totalCompletionTokens,
    required this.totalTokens,
    required this.totalCostUsd,
    required this.avgCostPerQueryUsd,
    required this.estimatedCostPerThousandUsd,
    required this.exactMatchAccuracyPct,
    required this.intentAccuracyPct,
    required this.slotAccuracyPct,
    required this.clarificationAccuracyPct,
    required this.overallQualityScorePct,
    required this.schemaAdherencePct,
    required this.dbExecutionSuccessPct,
    required this.overallCorrectnessScorePct,
    required this.categoryMetrics,
    required this.records,
  });

  Map<String, dynamic> toJson() => {
        'provider': providerName,
        'model': modelName,
        'timestamp': timestamp.toIso8601String(),
        'summary': {
          'total_queries': totalQueries,
          'successful_parses': successfulParses,
          'failed_parses': failedParses,
          'clarification_triggers': clarificationTriggers,
          'overall_quality_score_pct': overallQualityScorePct,
          'overall_correctness_score_pct': overallCorrectnessScorePct,
        },
        'latency': {
          'parse': parseLatencyStats.toJson(),
          'db': dbLatencyStats.toJson(),
          'total': totalLatencyStats.toJson(),
        },
        'cost': {
          'total_prompt_tokens': totalPromptTokens,
          'total_completion_tokens': totalCompletionTokens,
          'total_tokens': totalTokens,
          'total_cost_usd': totalCostUsd,
          'formatted_total_cost': LlmCostCalculator.formatCostUsd(totalCostUsd),
          'avg_cost_per_query_usd': avgCostPerQueryUsd,
          'estimated_cost_per_1000_queries_usd': estimatedCostPerThousandUsd,
        },
        'accuracy': {
          'exact_match_accuracy_pct': exactMatchAccuracyPct,
          'intent_accuracy_pct': intentAccuracyPct,
          'slot_accuracy_pct': slotAccuracyPct,
          'clarification_accuracy_pct': clarificationAccuracyPct,
        },
        'correctness': {
          'schema_adherence_pct': schemaAdherencePct,
          'db_execution_success_pct': dbExecutionSuccessPct,
          'overall_correctness_pct': overallCorrectnessScorePct,
        },
        'categories': categoryMetrics.map((k, v) => MapEntry(k, v.toJson())),
        'records': records.map((r) => r.toJson()).toList(),
      };
}

/// Metrics breakdown per test case category.
class CategoryMetric {
  final String category;
  final int count;
  final double exactMatchPct;
  final double intentAccuracyPct;
  final double avgLatencyMs;
  final double avgCostUsd;

  const CategoryMetric({
    required this.category,
    required this.count,
    required this.exactMatchPct,
    required this.intentAccuracyPct,
    required this.avgLatencyMs,
    required this.avgCostUsd,
  });

  Map<String, dynamic> toJson() => {
        'count': count,
        'exact_match_pct': exactMatchPct,
        'intent_accuracy_pct': intentAccuracyPct,
        'avg_latency_ms': double.parse(avgLatencyMs.toStringAsFixed(1)),
        'avg_cost_usd': avgCostUsd,
      };
}
