import '../../../models/search_intent.dart';
import '../../../models/search_query.dart';
import '../../search_repository.dart';
import '../llm_provider_config.dart';
import '../llm_query_parser.dart';
import '../query_parse_result.dart';
import '../query_understanding_spec.dart';
import 'benchmark_dataset.dart';
import 'eval_models.dart';
import 'llm_cost_calculator.dart';

/// Engine responsible for evaluating LLM query understanding across
/// Cost, Latency, Correctness, and Accuracy.
class LlmEvaluator {
  final ISearchRepository? searchRepository;

  const LlmEvaluator({this.searchRepository});

  /// Evaluates a single natural language test case.
  Future<QueryEvaluationRecord> evaluateTestCase({
    required BenchmarkTestCase testCase,
    required LlmQueryParser parser,
    ISearchRepository? repository,
  }) async {
    final repo = repository ?? searchRepository;
    final totalStopwatch = Stopwatch()..start();

    // 1. Execute LLM parsing
    final parseResult = await parser.parse(testCase.input, context: testCase.context);
    final parseLatencyMs = parseResult.latencyMs ?? 0;

    // 2. Execute DB search if parse succeeded and repository is provided
    int dbLatencyMs = 0;
    dynamic dbResult;
    String? executionError;

    if (parseResult.isSuccess && parseResult.query != null && repo != null) {
      final dbStopwatch = Stopwatch()..start();
      try {
        dbResult = await repo.search(parseResult.query!);
        dbStopwatch.stop();
        dbLatencyMs = dbStopwatch.elapsedMilliseconds;
      } catch (e) {
        dbStopwatch.stop();
        executionError = e.toString();
      }
    }

    totalStopwatch.stop();
    final totalLatencyMs = parseLatencyMs + dbLatencyMs;

    // 3. Compute Latency Breakdown
    final latency = LatencyBreakdown(
      parseLatencyMs: parseLatencyMs,
      dbLatencyMs: dbLatencyMs,
      totalLatencyMs: totalLatencyMs,
    );

    // 4. Compute Cost Breakdown
    final cost = _computeCost(parseResult, parser.provider);

    // 5. Compute Correctness Report
    final correctness = _verifyCorrectness(parseResult, executionError);

    // 6. Compute Accuracy Report
    final accuracy = _evaluateAccuracy(testCase, parseResult);

    return QueryEvaluationRecord(
      queryId: testCase.id,
      inputQuery: testCase.input,
      category: testCase.category,
      parseResult: parseResult,
      groundTruthQuery: testCase.expectedQuery,
      expectedClarification: testCase.expectClarification,
      latency: latency,
      cost: cost,
      correctness: correctness,
      accuracy: accuracy,
      dbExecutionResult: dbResult,
      executionError: executionError,
    );
  }

  /// Evaluates an entire benchmark dataset and generates an aggregate report.
  Future<BenchmarkEvaluationReport> evaluateBenchmark({
    required List<BenchmarkTestCase> testCases,
    required LlmQueryParser parser,
    ISearchRepository? repository,
    Duration? delayBetweenQueries,
    void Function(int current, int total, QueryEvaluationRecord record)? onProgress,
  }) async {
    final records = <QueryEvaluationRecord>[];
    final repo = repository ?? searchRepository;

    int totalQueries = testCases.length;
    for (int i = 0; i < testCases.length; i++) {
      final tc = testCases[i];
      final record = await evaluateTestCase(
        testCase: tc,
        parser: parser,
        repository: repo,
      );
      records.add(record);
      onProgress?.call(i + 1, totalQueries, record);

      if (delayBetweenQueries != null && i < testCases.length - 1) {
        await Future.delayed(delayBetweenQueries);
      }
    }

    String modelName = 'standard';
    if (records.isNotEmpty && records.first.parseResult.model != null) {
      modelName = records.first.parseResult.model!;
    } else {
      modelName = parser.provider.name;
    }

    return _aggregateReport(
      records: records,
      provider: parser.provider,
      modelName: modelName,
    );
  }

  /// Cost calculation helper
  CostBreakdown _computeCost(QueryParseResult parseResult, LlmProvider provider) {
    final promptTokens = parseResult.promptTokens ?? 0;
    final completionTokens = parseResult.completionTokens ?? 0;
    final modelName = parseResult.model ?? 'default';

    if (promptTokens == 0 && completionTokens == 0) {
      return CostBreakdown.zero(model: modelName, provider: provider);
    }

    return CostBreakdown.fromTokens(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      model: modelName,
      provider: provider,
    );
  }

  /// Structural Correctness verification
  CorrectnessReport _verifyCorrectness(QueryParseResult result, String? executionError) {
    final violations = <String>[];
    bool isJsonValid = true;
    bool hasValidIntent = true;
    bool hasValidActionType = true;
    bool hasValidYear = true;
    bool hasValidPagination = true;
    bool isClarificationSafe = true;
    bool isDbExecutable = executionError == null;

    if (result.error != null && !result.requiresClarification) {
      if (result.error!.contains('JSON') || result.error!.contains('Format')) {
        isJsonValid = false;
        violations.add('Invalid JSON output: ${result.error}');
      }
    }

    if (result.isSuccess && result.query != null) {
      final q = result.query!;

      // 1. Intent validation
      if (!SearchIntent.values.contains(q.intent)) {
        hasValidIntent = false;
        violations.add('Unknown intent value: ${q.intent}');
      }

      // 2. Action type validation
      if (q.actionType != null) {
        final action = q.actionType!.trim().toLowerCase();
        if (!QueryUnderstandingSpec.supportedActionTypes.contains(action)) {
          hasValidActionType = false;
          violations.add('Unsupported actionType "$action" outside canonical list');
        }
      }

      // 3. Year validation
      if (q.year != null) {
        if (q.year! < 1950 || q.year! > 2050) {
          hasValidYear = false;
          violations.add('Year ${q.year} outside valid range [1950, 2050]');
        }
      }

      // 4. Pagination validation
      if (q.limit <= 0 || q.limit > 200) {
        hasValidPagination = false;
        violations.add('Limit ${q.limit} outside safe range [1, 200]');
      }
      if (q.offset < 0) {
        hasValidPagination = false;
        violations.add('Offset ${q.offset} is negative');
      }
    }

    if (executionError != null) {
      violations.add('Database query execution error: $executionError');
    }

    return CorrectnessReport(
      isJsonValid: isJsonValid,
      hasValidIntent: hasValidIntent,
      hasValidActionType: hasValidActionType,
      hasValidYear: hasValidYear,
      hasValidPagination: hasValidPagination,
      isClarificationSafe: isClarificationSafe,
      isDbExecutable: isDbExecutable,
      violations: violations,
    );
  }

  /// Semantic Accuracy evaluation against ground truth
  AccuracyReport _evaluateAccuracy(BenchmarkTestCase tc, QueryParseResult result) {
    // Check clarification accuracy
    if (tc.expectClarification) {
      final clarificationMatch = result.requiresClarification;
      return AccuracyReport(
        intentMatch: clarificationMatch,
        exactMatch: clarificationMatch,
        clarificationMatch: clarificationMatch,
        slotMatches: const {},
        slotAccuracy: clarificationMatch ? 1.0 : 0.0,
        mismatchReason: clarificationMatch ? null : 'Expected clarification, but got query execution or error',
      );
    }

    if (!result.isSuccess || result.query == null) {
      return AccuracyReport(
        intentMatch: false,
        exactMatch: false,
        clarificationMatch: !result.requiresClarification,
        slotMatches: const {},
        slotAccuracy: 0.0,
        mismatchReason: 'Query parse failed: ${result.error ?? 'Unknown error'}',
      );
    }

    final actual = result.query!;
    final expected = tc.expectedQuery!;

    // 1. Intent Match
    final bool intentMatch = actual.intent == expected.intent;

    // 2. Slot matches
    final Map<String, bool> slotMatches = {
      'driverName': _matchString(actual.driverName, expected.driverName),
      'targetRallyName': _matchString(actual.targetRallyName, expected.targetRallyName),
      'actionType': _matchString(actual.actionType, expected.actionType),
      'country': _matchString(actual.country, expected.country),
      'city': _matchString(actual.city, expected.city),
      'stageName': _matchString(actual.stageName, expected.stageName),
      'year': actual.year == expected.year,
      'limit': expected.limit == 20 ? true : actual.limit == expected.limit,
    };

    final int matchingSlots = slotMatches.values.where((m) => m).length;
    final double slotAccuracy = matchingSlots / slotMatches.length;

    // 3. Exact match
    final bool exactMatch = intentMatch && slotMatches.values.every((m) => m);

    String? mismatchReason;
    if (!exactMatch) {
      final failedSlots = slotMatches.entries.where((e) => !e.value).map((e) => e.key).toList();
      if (!intentMatch) {
        mismatchReason = 'Intent mismatch: expected ${expected.intent.toIntentString()}, got ${actual.intent.toIntentString()}';
      } else {
        mismatchReason = 'Slot mismatch in: ${failedSlots.join(', ')}';
      }
    }

    return AccuracyReport(
      intentMatch: intentMatch,
      exactMatch: exactMatch,
      clarificationMatch: true,
      slotMatches: slotMatches,
      slotAccuracy: slotAccuracy,
      mismatchReason: mismatchReason,
    );
  }

  bool _matchString(String? actual, String? expected) {
    if (actual == null && expected == null) return true;
    if (actual == null || expected == null) return false;
    final a = actual.trim().toLowerCase();
    final e = expected.trim().toLowerCase();
    return a == e || a.contains(e) || e.contains(a);
  }

  /// Aggregates evaluation records into a BenchmarkEvaluationReport
  BenchmarkEvaluationReport _aggregateReport({
    required List<QueryEvaluationRecord> records,
    required LlmProvider provider,
    required String modelName,
  }) {
    final totalQueries = records.length;
    final successfulParses = records.where((r) => r.parseResult.isSuccess).length;
    final failedParses = records.where((r) => !r.parseResult.isSuccess && !r.parseResult.requiresClarification).length;
    final clarificationTriggers = records.where((r) => r.parseResult.requiresClarification).length;

    // Latencies
    final parseLatencies = records.map((r) => r.latency.parseLatencyMs).toList();
    final dbLatencies = records.map((r) => r.latency.dbLatencyMs).toList();
    final totalLatencies = records.map((r) => r.latency.totalLatencyMs).toList();

    final parseLatencyStats = LatencyStats.fromValues(parseLatencies);
    final dbLatencyStats = LatencyStats.fromValues(dbLatencies);
    final totalLatencyStats = LatencyStats.fromValues(totalLatencies);

    // Costs
    int totalPromptTokens = 0;
    int totalCompletionTokens = 0;
    double totalCostUsd = 0.0;

    for (final r in records) {
      totalPromptTokens += r.cost.promptTokens;
      totalCompletionTokens += r.cost.completionTokens;
      totalCostUsd += r.cost.totalCostUsd;
    }

    final avgCostPerQuery = totalQueries > 0 ? totalCostUsd / totalQueries : 0.0;
    final costPerThousand = avgCostPerQuery * 1000.0;

    // Accuracy
    int exactMatchCount = records.where((r) => r.accuracy.exactMatch).length;
    int intentMatchCount = records.where((r) => r.accuracy.intentMatch).length;
    int clarificationMatchCount = records.where((r) => r.accuracy.clarificationMatch).length;
    double totalSlotAccuracy = records.fold(0.0, (acc, r) => acc + r.accuracy.slotAccuracy);
    double totalCompositeAccuracy = records.fold(0.0, (acc, r) => acc + r.accuracy.compositeScore);

    final exactMatchPct = totalQueries > 0 ? (exactMatchCount / totalQueries) * 100.0 : 0.0;
    final intentAccuracyPct = totalQueries > 0 ? (intentMatchCount / totalQueries) * 100.0 : 0.0;
    final slotAccuracyPct = totalQueries > 0 ? (totalSlotAccuracy / totalQueries) * 100.0 : 0.0;
    final clarificationAccuracyPct = totalQueries > 0 ? (clarificationMatchCount / totalQueries) * 100.0 : 0.0;
    final overallQualityPct = totalQueries > 0 ? (totalCompositeAccuracy / totalQueries) * 100.0 : 0.0;

    // Correctness
    int validSchemaCount = records.where((r) => r.correctness.isJsonValid).length;
    int dbSuccessCount = records.where((r) => r.correctness.isDbExecutable).length;
    double totalCorrectnessScore = records.fold(0.0, (acc, r) => acc + r.correctness.score);

    final schemaAdherencePct = totalQueries > 0 ? (validSchemaCount / totalQueries) * 100.0 : 0.0;
    final dbExecutionSuccessPct = totalQueries > 0 ? (dbSuccessCount / totalQueries) * 100.0 : 0.0;
    final overallCorrectnessPct = totalQueries > 0 ? (totalCorrectnessScore / totalQueries) * 100.0 : 0.0;

    // Category Metrics
    final Map<String, List<QueryEvaluationRecord>> categoryGroups = {};
    for (final r in records) {
      categoryGroups.putIfAbsent(r.category, () => []).add(r);
    }

    final categoryMetrics = <String, CategoryMetric>{};
    categoryGroups.forEach((category, catRecords) {
      final count = catRecords.length;
      final emCount = catRecords.where((r) => r.accuracy.exactMatch).length;
      final intCount = catRecords.where((r) => r.accuracy.intentMatch).length;
      final sumLatency = catRecords.fold(0, (acc, r) => acc + r.latency.totalLatencyMs);
      final sumCost = catRecords.fold(0.0, (acc, r) => acc + r.cost.totalCostUsd);

      categoryMetrics[category] = CategoryMetric(
        category: category,
        count: count,
        exactMatchPct: (emCount / count) * 100.0,
        intentAccuracyPct: (intCount / count) * 100.0,
        avgLatencyMs: sumLatency / count,
        avgCostUsd: sumCost / count,
      );
    });

    return BenchmarkEvaluationReport(
      providerName: provider.name,
      modelName: modelName,
      timestamp: DateTime.now(),
      totalQueries: totalQueries,
      successfulParses: successfulParses,
      failedParses: failedParses,
      clarificationTriggers: clarificationTriggers,
      parseLatencyStats: parseLatencyStats,
      dbLatencyStats: dbLatencyStats,
      totalLatencyStats: totalLatencyStats,
      totalPromptTokens: totalPromptTokens,
      totalCompletionTokens: totalCompletionTokens,
      totalTokens: totalPromptTokens + totalCompletionTokens,
      totalCostUsd: totalCostUsd,
      avgCostPerQueryUsd: avgCostPerQuery,
      estimatedCostPerThousandUsd: costPerThousand,
      exactMatchAccuracyPct: exactMatchPct,
      intentAccuracyPct: intentAccuracyPct,
      slotAccuracyPct: slotAccuracyPct,
      clarificationAccuracyPct: clarificationAccuracyPct,
      overallQualityScorePct: overallQualityPct,
      schemaAdherencePct: schemaAdherencePct,
      dbExecutionSuccessPct: dbExecutionSuccessPct,
      overallCorrectnessScorePct: overallCorrectnessPct,
      categoryMetrics: categoryMetrics,
      records: records,
    );
  }
}
