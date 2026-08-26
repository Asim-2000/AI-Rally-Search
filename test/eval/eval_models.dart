import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';

/// Difficulty grading for benchmark test cases.
enum CaseDifficulty {
  easy,
  medium,
  hard;

  static CaseDifficulty fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'hard':
        return CaseDifficulty.hard;
      case 'medium':
        return CaseDifficulty.medium;
      case 'easy':
      default:
        return CaseDifficulty.easy;
    }
  }
}

/// A structured natural language benchmark query case.
class BenchmarkCase {
  final String id;
  final String query;
  final String category;
  final CaseDifficulty difficulty;
  final SearchIntent? expectedIntent;
  final Map<String, dynamic> expectedFilters;
  final bool expectedClarification;
  final SearchContext? context;
  final String? description;
  final String? semanticCaseId;
  final String? languageCode;
  final String? locale;

  const BenchmarkCase({
    required this.id,
    required this.query,
    required this.category,
    this.difficulty = CaseDifficulty.easy,
    this.expectedIntent,
    this.expectedFilters = const {},
    this.expectedClarification = false,
    this.context,
    this.description,
    this.semanticCaseId,
    this.languageCode,
    this.locale,
  });


  /// Helper getter returning query as an expected SearchQuery model if intent is present.
  SearchQuery? get expectedQuery {
    if (expectedIntent == null) return null;
    return SearchQuery(
      intent: expectedIntent!,
      driverName: expectedFilters['driverName'] as String?,
      rallyName: (expectedFilters['rallyName'] ?? expectedFilters['targetRallyName']) as String?,
      actionType: expectedFilters['actionType'] as String?,
      country: expectedFilters['country'] as String?,
      city: expectedFilters['city'] as String?,
      stageName: expectedFilters['stageName'] as String?,
      year: expectedFilters['year'] as int?,
      limit: (expectedFilters['limit'] as int?) ?? 20,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'category': category,
        'difficulty': difficulty.name,
        'expectedIntent': expectedIntent?.name,
        'expectedFilters': expectedFilters,
        'expectedClarification': expectedClarification,
        'description': description,
      };
}

/// Configurable pricing parameters per 1M tokens.
class ModelPricing {
  final double inputCostPerMillionTokens;
  final double outputCostPerMillionTokens;

  const ModelPricing({
    required this.inputCostPerMillionTokens,
    required this.outputCostPerMillionTokens,
  });

  double computePromptCost(int promptTokens) =>
      (promptTokens / 1000000.0) * inputCostPerMillionTokens;

  double computeCompletionCost(int completionTokens) =>
      (completionTokens / 1000000.0) * outputCostPerMillionTokens;

  double computeTotalCost(int promptTokens, int completionTokens) =>
      computePromptCost(promptTokens) + computeCompletionCost(completionTokens);

  /// Known registry of LLM pricing.
  static final Map<String, ModelPricing> _pricingRegistry = {
    // OpenAI Models
    'gpt-4o-mini': const ModelPricing(
      inputCostPerMillionTokens: 0.15,
      outputCostPerMillionTokens: 0.60,
    ),
    'gpt-4o': const ModelPricing(
      inputCostPerMillionTokens: 2.50,
      outputCostPerMillionTokens: 10.00,
    ),
    'gpt-4.5-preview': const ModelPricing(
      inputCostPerMillionTokens: 75.00,
      outputCostPerMillionTokens: 150.00,
    ),
    // Google Gemini Models
    'gemini-2.0-flash': const ModelPricing(
      inputCostPerMillionTokens: 0.10,
      outputCostPerMillionTokens: 0.40,
    ),
    'gemini-2.0-flash-lite': const ModelPricing(
      inputCostPerMillionTokens: 0.075,
      outputCostPerMillionTokens: 0.30,
    ),
    'gemini-1.5-pro': const ModelPricing(
      inputCostPerMillionTokens: 1.25,
      outputCostPerMillionTokens: 5.00,
    ),
    'gemini-3.6-flash': const ModelPricing(
      inputCostPerMillionTokens: 0.10,
      outputCostPerMillionTokens: 0.40,
    ),
    // Anthropic Claude Models
    'claude-3-5-sonnet-20241022': const ModelPricing(
      inputCostPerMillionTokens: 3.00,
      outputCostPerMillionTokens: 15.00,
    ),
    'claude-3-5-haiku-20241022': const ModelPricing(
      inputCostPerMillionTokens: 0.80,
      outputCostPerMillionTokens: 4.00,
    ),
    // Mock
    'mock-parser-v1': const ModelPricing(
      inputCostPerMillionTokens: 0.0,
      outputCostPerMillionTokens: 0.0,
    ),
  };

  /// Retrieves pricing for a model or returns null if pricing is unknown.
  static ModelPricing? getPricing({required String model, LlmProvider? provider}) {
    final cleanModel = model.toLowerCase().replaceAll('models/', '').trim();
    if (_pricingRegistry.containsKey(cleanModel)) {
      return _pricingRegistry[cleanModel];
    }
    for (final entry in _pricingRegistry.entries) {
      if (cleanModel.contains(entry.key) || entry.key.contains(cleanModel)) {
        return entry.value;
      }
    }
    if (provider == LlmProvider.mock) {
      return const ModelPricing(inputCostPerMillionTokens: 0.0, outputCostPerMillionTokens: 0.0);
    }
    return null;
  }
}

/// Latency statistics container for evaluation benchmarks.
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
        'mean_ms': double.parse(meanMs.toStringAsFixed(1)),
        'p50_ms': p50Ms,
        'p90_ms': p90Ms,
        'p95_ms': p95Ms,
        'p99_ms': p99Ms,
      };
}

/// Specific failure classification categories.
enum FailureType {
  timeout,
  httpError,
  invalidJson,
  schemaValidationFailure,
  invalidIntent,
  missingFilter,
  incorrectFilterValue,
  hallucinatedFilter,
  entityRewritten,
  incorrectLimit,
  incorrectClarification,
  providerException;

  String get description {
    switch (this) {
      case FailureType.timeout:
        return 'Request timeout';
      case FailureType.httpError:
        return 'HTTP error';
      case FailureType.invalidJson:
        return 'Invalid JSON response';
      case FailureType.schemaValidationFailure:
        return 'Schema validation failure';
      case FailureType.invalidIntent:
        return 'Wrong search intent';
      case FailureType.missingFilter:
        return 'Missing expected filter';
      case FailureType.incorrectFilterValue:
        return 'Incorrect filter value';
      case FailureType.hallucinatedFilter:
        return 'Hallucinated filter';
      case FailureType.entityRewritten:
        return 'Entity phrase rewritten / expanded';
      case FailureType.incorrectLimit:
        return 'Incorrect limit';
      case FailureType.incorrectClarification:
        return 'Incorrect clarification behavior';
      case FailureType.providerException:
        return 'Provider technical exception';
    }
  }
}

/// Detailed description of a single evaluation failure.
class EvaluationFailure {
  final FailureType type;
  final String? slotName;
  final dynamic expectedValue;
  final dynamic actualValue;
  final String message;

  const EvaluationFailure({
    required this.type,
    this.slotName,
    this.expectedValue,
    this.actualValue,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'slot_name': slotName,
        'expected': expectedValue?.toString(),
        'actual': actualValue?.toString(),
        'message': message,
      };
}

/// Evaluation record for a single benchmark query case.
class CaseEvaluationRecord {
  final BenchmarkCase testCase;
  final QueryParseResult parseResult;
  final int latencyMs;
  final int promptTokens;
  final int completionTokens;
  final double? costUsd;

  final bool intentMatch;
  final bool exactMatch;
  final bool clarificationMatch;
  final bool compoundComplete;
  final bool hasHallucination;
  final bool hasEntityPreserved;

  final int truePositiveSlots;
  final int falsePositiveSlots;
  final int falseNegativeSlots;
  final Map<String, bool> slotMatches;
  final List<EvaluationFailure> failures;

  const CaseEvaluationRecord({
    required this.testCase,
    required this.parseResult,
    required this.latencyMs,
    required this.promptTokens,
    required this.completionTokens,
    this.costUsd,
    required this.intentMatch,
    required this.exactMatch,
    required this.clarificationMatch,
    required this.compoundComplete,
    required this.hasHallucination,
    required this.hasEntityPreserved,
    required this.truePositiveSlots,
    required this.falsePositiveSlots,
    required this.falseNegativeSlots,
    required this.slotMatches,
    required this.failures,
  });

  bool get isSuccess => failures.isEmpty && exactMatch;

  Map<String, dynamic> toJson() => {
        'id': testCase.id,
        'query': testCase.query,
        'category': testCase.category,
        'difficulty': testCase.difficulty.name,
        'intent_match': intentMatch,
        'exact_match': exactMatch,
        'clarification_match': clarificationMatch,
        'compound_complete': compoundComplete,
        'has_hallucination': hasHallucination,
        'entity_preserved': hasEntityPreserved,
        'latency_ms': latencyMs,
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'cost_usd': costUsd,
        'slot_matches': slotMatches,
        'failures': failures.map((f) => f.toJson()).toList(),
      };
}

/// Aggregate metrics for a subset (category, difficulty, etc.).
class SubsetMetrics {
  final String name;
  final int count;
  final double intentAccuracyPct;
  final double exactMatchPct;
  final double filterF1Pct;
  final double compoundCompletenessPct;
  final double avgLatencyMs;
  final double? avgCostUsd;

  const SubsetMetrics({
    required this.name,
    required this.count,
    required this.intentAccuracyPct,
    required this.exactMatchPct,
    required this.filterF1Pct,
    required this.compoundCompletenessPct,
    required this.avgLatencyMs,
    this.avgCostUsd,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'count': count,
        'intent_accuracy_pct': intentAccuracyPct,
        'exact_match_pct': exactMatchPct,
        'filter_f1_pct': filterF1Pct,
        'compound_completeness_pct': compoundCompletenessPct,
        'avg_latency_ms': double.parse(avgLatencyMs.toStringAsFixed(1)),
        'avg_cost_usd': avgCostUsd,
      };
}

/// Metric tracking for individual slot extraction accuracy.
class SlotExtractionMetric {
  final String slotName;
  final int totalExpected;
  final int totalExtracted;
  final int correctlyExtracted;

  const SlotExtractionMetric({
    required this.slotName,
    required this.totalExpected,
    required this.totalExtracted,
    required this.correctlyExtracted,
  });

  double get precisionPct =>
      totalExtracted > 0 ? (correctlyExtracted / totalExtracted) * 100.0 : 100.0;

  double get recallPct =>
      totalExpected > 0 ? (correctlyExtracted / totalExpected) * 100.0 : 100.0;

  double get f1Pct {
    final p = precisionPct / 100.0;
    final r = recallPct / 100.0;
    if (p + r == 0) return 0.0;
    return (2 * p * r / (p + r)) * 100.0;
  }

  Map<String, dynamic> toJson() => {
        'slot': slotName,
        'total_expected': totalExpected,
        'total_extracted': totalExtracted,
        'correctly_extracted': correctlyExtracted,
        'precision_pct': double.parse(precisionPct.toStringAsFixed(1)),
        'recall_pct': double.parse(recallPct.toStringAsFixed(1)),
        'f1_pct': double.parse(f1Pct.toStringAsFixed(1)),
      };
}

/// Full comprehensive benchmark report across a test run.
class ProviderEvaluationReport {
  final String providerName;
  final String modelName;
  final DateTime timestamp;
  final int numberOfCases;
  final int successfulParses;
  final int failedParses;
  final int clarificationTriggers;

  // Primary Metrics
  final double intentAccuracyPct;
  final double filterPrecisionPct;
  final double filterRecallPct;
  final double filterF1Pct;
  final double exactMatchRatePct;
  final double compoundAccuracyPct;
  final double clarificationAccuracyPct;
  final double hallucinationRatePct;
  final double entityPreservationRatePct;

  // Production Weighted Score (Higher weight on compound, exact match, no hallucination, intent)
  final double productionWeightedScorePct;

  // Latency
  final LatencyStats latencyStats;

  // Tokens & Cost
  final int totalPromptTokens;
  final int totalCompletionTokens;
  final int totalTokens;
  final double? totalCostUsd;
  final double? avgCostPerQueryUsd;
  final double? estimatedCostPerThousandUsd;

  // Breakdowns
  final Map<String, SlotExtractionMetric> slotMetrics;
  final Map<String, SubsetMetrics> categoryMetrics;
  final Map<String, SubsetMetrics> difficultyMetrics;
  final Map<String, SubsetMetrics> languageMetrics;
  final Map<FailureType, int> failureTypeCounts;
  final List<CaseEvaluationRecord> records;

  const ProviderEvaluationReport({
    required this.providerName,
    required this.modelName,
    required this.timestamp,
    required this.numberOfCases,
    required this.successfulParses,
    required this.failedParses,
    required this.clarificationTriggers,
    required this.intentAccuracyPct,
    required this.filterPrecisionPct,
    required this.filterRecallPct,
    required this.filterF1Pct,
    required this.exactMatchRatePct,
    required this.compoundAccuracyPct,
    required this.clarificationAccuracyPct,
    required this.hallucinationRatePct,
    required this.entityPreservationRatePct,
    required this.productionWeightedScorePct,
    required this.latencyStats,
    required this.totalPromptTokens,
    required this.totalCompletionTokens,
    required this.totalTokens,
    this.totalCostUsd,
    this.avgCostPerQueryUsd,
    this.estimatedCostPerThousandUsd,
    required this.slotMetrics,
    required this.categoryMetrics,
    required this.difficultyMetrics,
    this.languageMetrics = const {},
    required this.failureTypeCounts,
    required this.records,
  });

  List<CaseEvaluationRecord> get failedRecords =>
      records.where((r) => !r.isSuccess).toList();

  Map<String, dynamic> toJson() => {
        'provider': providerName,
        'model': modelName,
        'timestamp': timestamp.toIso8601String(),
        'numberOfCases': numberOfCases,
        'cases_evaluated': numberOfCases,
        'summary': {
          'successful_parses': successfulParses,
          'failed_parses': failedParses,
          'clarification_triggers': clarificationTriggers,
          'intent_accuracy_pct': intentAccuracyPct,
          'filter_precision_pct': filterPrecisionPct,
          'filter_recall_pct': filterRecallPct,
          'filter_f1_pct': filterF1Pct,
          'exact_match_rate_pct': exactMatchRatePct,
          'compound_accuracy_pct': compoundAccuracyPct,
          'clarification_accuracy_pct': clarificationAccuracyPct,
          'hallucination_rate_pct': hallucinationRatePct,
          'entity_preservation_rate_pct': entityPreservationRatePct,
          'production_weighted_score_pct': productionWeightedScorePct,
        },
        'successful_parses': successfulParses,
        'failed_parses': failedParses,
        'clarification_triggers': clarificationTriggers,
        'intent_accuracy_pct': intentAccuracyPct,
        'filter_precision_pct': filterPrecisionPct,
        'filter_recall_pct': filterRecallPct,
        'filter_f1_pct': filterF1Pct,
        'exact_match_rate_pct': exactMatchRatePct,
        'compound_accuracy_pct': compoundAccuracyPct,
        'clarification_accuracy_pct': clarificationAccuracyPct,
        'hallucination_rate_pct': hallucinationRatePct,
        'entity_preservation_rate_pct': entityPreservationRatePct,
        'production_weighted_score_pct': productionWeightedScorePct,
        'latency_stats': latencyStats.toJson(),
        'total_prompt_tokens': totalPromptTokens,
        'total_completion_tokens': totalCompletionTokens,
        'total_tokens': totalTokens,
        'total_cost_usd': totalCostUsd,
        'avg_cost_per_query_usd': avgCostPerQueryUsd,
        'estimated_cost_per_1000_usd': estimatedCostPerThousandUsd,
        'slot_metrics': slotMetrics.map((k, v) => MapEntry(k, v.toJson())),
        'category_metrics': categoryMetrics.map((k, v) => MapEntry(k, v.toJson())),
        'difficulty_metrics': difficultyMetrics.map((k, v) => MapEntry(k, v.toJson())),
        'language_metrics': languageMetrics.map((k, v) => MapEntry(k, v.toJson())),
        'failure_counts': failureTypeCounts.map((k, v) => MapEntry(k.name, v)),
        'records': records.map((r) => r.toJson()).toList(),
      };

}
