import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_output_validator.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'eval_models.dart';

/// Comprehensive LLM Query Parser Evaluation Engine.
/// Benchmarks semantic query understanding strictly in isolation from DatabaseService and EntityResolver.
class ProviderEvaluator {
  const ProviderEvaluator();

  /// Evaluates a single benchmark case against an [LlmQueryParser].
  Future<CaseEvaluationRecord> evaluateCase({
    required BenchmarkCase testCase,
    required LlmQueryParser parser,
  }) async {
    final parseResult = await parser.parse(testCase.query, context: testCase.context);
    final latencyMs = parseResult.latencyMs ?? 0;
    final promptTokens = parseResult.promptTokens ?? 0;
    final completionTokens = parseResult.completionTokens ?? 0;
    final modelName = parseResult.model ?? 'default';

    // 1. Cost calculation
    final pricing = ModelPricing.getPricing(model: modelName, provider: parser.provider);
    final costUsd = pricing?.computeTotalCost(promptTokens, completionTokens);

    final failures = <EvaluationFailure>[];

    // 2. Handle technical/provider failures
    if (!parseResult.isSuccess && !parseResult.requiresClarification) {
      final err = parseResult.error ?? 'Unknown error';
      FailureType fType = FailureType.providerException;
      if (err.toLowerCase().contains('timeout')) {
        fType = FailureType.timeout;
      } else if (err.toLowerCase().contains('http')) {
        fType = FailureType.httpError;
      } else if (err.toLowerCase().contains('json') || err.toLowerCase().contains('format')) {
        fType = FailureType.invalidJson;
      } else if (err.toLowerCase().contains('validation') || err.toLowerCase().contains('schema')) {
        fType = FailureType.schemaValidationFailure;
      }

      failures.add(EvaluationFailure(
        type: fType,
        message: 'Parser failed: $err',
      ));

      return CaseEvaluationRecord(
        testCase: testCase,
        parseResult: parseResult,
        latencyMs: latencyMs,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        costUsd: costUsd,
        intentMatch: false,
        exactMatch: false,
        clarificationMatch: !testCase.expectedClarification,
        compoundComplete: false,
        hasHallucination: false,
        hasEntityPreserved: true,
        truePositiveSlots: 0,
        falsePositiveSlots: 0,
        falseNegativeSlots: testCase.expectedFilters.length + (testCase.expectedIntent != null ? 1 : 0),
        slotMatches: const {},
        failures: failures,
      );
    }

    // 3. Clarification correctness
    final bool clarificationMatch = parseResult.requiresClarification == testCase.expectedClarification;
    if (!clarificationMatch) {
      failures.add(EvaluationFailure(
        type: FailureType.incorrectClarification,
        expectedValue: testCase.expectedClarification,
        actualValue: parseResult.requiresClarification,
        message: testCase.expectedClarification
            ? 'Expected query to trigger clarification, but parser produced structured query'
            : 'Parser incorrectly triggered clarification for a clear query',
      ));
    }

    // If clarification was expected and correctly triggered, score as full match
    if (testCase.expectedClarification) {
      return CaseEvaluationRecord(
        testCase: testCase,
        parseResult: parseResult,
        latencyMs: latencyMs,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        costUsd: costUsd,
        intentMatch: clarificationMatch,
        exactMatch: clarificationMatch,
        clarificationMatch: clarificationMatch,
        compoundComplete: clarificationMatch,
        hasHallucination: false,
        hasEntityPreserved: true,
        truePositiveSlots: 0,
        falsePositiveSlots: 0,
        falseNegativeSlots: 0,
        slotMatches: const {},
        failures: failures,
      );
    }

    final actual = parseResult.query ?? const SearchQuery(intent: SearchIntent.searchRallies);
    final expectedIntent = testCase.expectedIntent;
    final expectedFilters = testCase.expectedFilters;

    // 4. Intent evaluation
    final bool intentMatch = expectedIntent == null || actual.intent == expectedIntent;
    if (!intentMatch) {
      failures.add(EvaluationFailure(
        type: FailureType.invalidIntent,
        slotName: 'intent',
        expectedValue: expectedIntent?.name,
        actualValue: actual.intent.name,
        message: 'Expected intent ${expectedIntent?.name}, got ${actual.intent.name}',
      ));
    }

    // 5. Normalized Filter Slot Evaluation
    final evaluatedSlots = <String, bool>{};
    int tpSlots = 0;
    int fpSlots = 0;
    int fnSlots = 0;
    bool hasHallucination = false;
    bool hasEntityPreserved = true;

    final allSlotNames = {
      'driverName',
      'rallyName',
      'actionType',
      'country',
      'city',
      'stageName',
      'year',
      'limit',
    };

    for (final slot in allSlotNames) {
      final expectedVal = _getExpectedSlotValue(expectedFilters, slot);
      final actualVal = _getActualSlotValue(actual, slot);

      if (expectedVal != null && actualVal != null) {
        final isMatch = _compareSlotValues(slot, expectedVal, actualVal);
        evaluatedSlots[slot] = isMatch;
        if (isMatch) {
          tpSlots++;
          // Check entity preservation for entity strings (e.g. rallyName, driverName)
          if ((slot == 'rallyName' || slot == 'driverName') && expectedVal is String && actualVal is String) {
            if (_isOverlyExpanded(expectedVal, actualVal)) {
              hasEntityPreserved = false;
              failures.add(EvaluationFailure(
                type: FailureType.entityRewritten,
                slotName: slot,
                expectedValue: expectedVal,
                actualValue: actualVal,
                message: 'Entity was overly expanded or rewritten from user phrase "$expectedVal" to "$actualVal"',
              ));
            }
          }
        } else {
          fpSlots++;
          fnSlots++;
          failures.add(EvaluationFailure(
            type: FailureType.incorrectFilterValue,
            slotName: slot,
            expectedValue: expectedVal,
            actualValue: actualVal,
            message: 'Slot "$slot" mismatch: expected "$expectedVal", got "$actualVal"',
          ));
        }
      } else if (expectedVal != null && actualVal == null) {
        evaluatedSlots[slot] = false;
        fnSlots++;
        failures.add(EvaluationFailure(
          type: FailureType.missingFilter,
          slotName: slot,
          expectedValue: expectedVal,
          actualValue: null,
          message: 'Missing expected filter "$slot" (expected "$expectedVal")',
        ));
      } else if (expectedVal == null && actualVal != null) {
        // Slot extracted when not expected.
        // Special case: default limit (20) when not specified in expectedFilters is NOT a hallucination.
        if (slot == 'limit' && (actualVal == 20 || actualVal == null)) {
          // Ignored harmless default
        } else {
          evaluatedSlots[slot] = false;
          fpSlots++;
          hasHallucination = true;
          failures.add(EvaluationFailure(
            type: FailureType.hallucinatedFilter,
            slotName: slot,
            expectedValue: null,
            actualValue: actualVal,
            message: 'Hallucinated unsupported filter "$slot" with value "$actualVal"',
          ));
        }
      }
    }

    // 6. Compound Query Completeness
    // If query is compound (has >= 2 expected filters or categorized as Compound Queries),
    // compoundComplete requires all expected slots to match.
    final bool isCompound = expectedFilters.length >= 2 || testCase.category == 'Compound Queries';
    final bool compoundComplete = !isCompound || (intentMatch && fnSlots == 0 && fpSlots == 0);

    // 7. Exact query match
    final bool exactMatch = intentMatch && clarificationMatch && failures.isEmpty;

    return CaseEvaluationRecord(
      testCase: testCase,
      parseResult: parseResult,
      latencyMs: latencyMs,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      costUsd: costUsd,
      intentMatch: intentMatch,
      exactMatch: exactMatch,
      clarificationMatch: clarificationMatch,
      compoundComplete: compoundComplete,
      hasHallucination: hasHallucination,
      hasEntityPreserved: hasEntityPreserved,
      truePositiveSlots: tpSlots,
      falsePositiveSlots: fpSlots,
      falseNegativeSlots: fnSlots,
      slotMatches: evaluatedSlots,
      failures: failures,
    );
  }

  /// Evaluates an entire benchmark suite and generates a structured report.
  Future<ProviderEvaluationReport> evaluate({
    required LlmQueryParser parser,
    required List<BenchmarkCase> cases,
    Duration? delayBetweenQueries,
    void Function(int current, int total, CaseEvaluationRecord record)? onProgress,
  }) async {
    final records = <CaseEvaluationRecord>[];
    final totalCases = cases.length;

    for (int i = 0; i < totalCases; i++) {
      final c = cases[i];
      final record = await evaluateCase(testCase: c, parser: parser);
      records.add(record);
      onProgress?.call(i + 1, totalCases, record);

      if (delayBetweenQueries != null && i < totalCases - 1) {
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

  /// Runs multi-provider evaluation against identical benchmark cases.
  Future<Map<String, ProviderEvaluationReport>> compareProviders({
    required List<LlmQueryParser> parsers,
    required List<BenchmarkCase> cases,
    Duration? delayBetweenQueries,
    void Function(String provider, int current, int total, CaseEvaluationRecord record)? onProgress,
  }) async {
    final results = <String, ProviderEvaluationReport>{};

    for (final parser in parsers) {
      final report = await evaluate(
        parser: parser,
        cases: cases,
        delayBetweenQueries: delayBetweenQueries,
        onProgress: (cur, tot, rec) => onProgress?.call(parser.provider.name, cur, tot, rec),
      );
      results['${parser.provider.name} (${report.modelName})'] = report;
    }

    return results;
  }

  // --- Helper Methods ---

  dynamic _getExpectedSlotValue(Map<String, dynamic> filters, String slot) {
    if (slot == 'rallyName') {
      return filters['rallyName'] ?? filters['targetRallyName'];
    }
    return filters[slot];
  }

  dynamic _getActualSlotValue(SearchQuery query, String slot) {
    switch (slot) {
      case 'driverName':
        return query.driverName;
      case 'rallyName':
        return query.targetRallyName;
      case 'actionType':
        return query.actionType;
      case 'country':
        return query.country;
      case 'city':
        return query.city;
      case 'stageName':
        return query.stageName;
      case 'year':
        return query.year;
      case 'limit':
        return query.limit;
      default:
        return null;
    }
  }

  bool _compareSlotValues(String slot, dynamic expected, dynamic actual) {
    if (expected == null && actual == null) return true;
    if (expected == null || actual == null) return false;

    if (slot == 'year' || slot == 'limit') {
      return expected.toString() == actual.toString();
    }

    final expStr = expected.toString().trim().toLowerCase();
    final actStr = actual.toString().trim().toLowerCase();

    if (slot == 'actionType') {
      // Normalize aliases like 'jumps' -> 'jump' or 'doughnut' -> 'donut'
      return QueryOutputValidator.normalizeActionType(expStr) ==
          QueryOutputValidator.normalizeActionType(actStr);
    }

    if (slot == 'country') {
      return QueryOutputValidator.normalizeCountry(expStr) ==
          QueryOutputValidator.normalizeCountry(actStr);
    }

    // Entity strings: driverName, rallyName, city, stageName
    return expStr == actStr ||
        expStr.contains(actStr) ||
        actStr.contains(expStr);
  }

  bool _isOverlyExpanded(String expected, String actual) {
    final exp = expected.trim().toLowerCase();
    final act = actual.trim().toLowerCase();
    // If expected is short (e.g. "moonraker") and actual expands to "moonraker forestry rally 2025"
    if (exp != act && act.contains(exp) && (act.length - exp.length) > 10) {
      return true;
    }
    return false;
  }

  ProviderEvaluationReport _aggregateReport({
    required List<CaseEvaluationRecord> records,
    required LlmProvider provider,
    required String modelName,
  }) {
    final totalCases = records.length;
    final successfulParses = records.where((r) => r.parseResult.isSuccess).length;
    final failedParses = records.where((r) => !r.parseResult.isSuccess && !r.parseResult.requiresClarification).length;
    final clarificationTriggers = records.where((r) => r.parseResult.requiresClarification).length;

    // Latency
    final latencies = records.map((r) => r.latencyMs).toList();
    final latencyStats = LatencyStats.fromValues(latencies);

    // Tokens & Costs
    int totalPromptTokens = 0;
    int totalCompletionTokens = 0;
    double? totalCostUsd;

    for (final r in records) {
      totalPromptTokens += r.promptTokens;
      totalCompletionTokens += r.completionTokens;
      if (r.costUsd != null) {
        totalCostUsd = (totalCostUsd ?? 0.0) + r.costUsd!;
      }
    }

    final avgCostPerQuery = (totalCostUsd != null && totalCases > 0) ? totalCostUsd / totalCases : null;
    final costPerThousand = avgCostPerQuery != null ? avgCostPerQuery * 1000.0 : null;

    // Primary Accuracies
    final intentMatches = records.where((r) => r.intentMatch).length;
    final exactMatches = records.where((r) => r.exactMatch).length;
    final clarificationMatches = records.where((r) => r.clarificationMatch).length;
    final hallucinations = records.where((r) => r.hasHallucination).length;
    final entityPreserved = records.where((r) => r.hasEntityPreserved).length;

    final compoundRecords = records.where((r) =>
        r.testCase.expectedFilters.length >= 2 || r.testCase.category == 'Compound Queries').toList();
    final compoundMatches = compoundRecords.where((r) => r.compoundComplete).length;

    final intentAccuracyPct = totalCases > 0 ? (intentMatches / totalCases) * 100.0 : 0.0;
    final exactMatchRatePct = totalCases > 0 ? (exactMatches / totalCases) * 100.0 : 0.0;
    final clarificationAccuracyPct = totalCases > 0 ? (clarificationMatches / totalCases) * 100.0 : 0.0;
    final hallucinationRatePct = totalCases > 0 ? (hallucinations / totalCases) * 100.0 : 0.0;
    final entityPreservationRatePct = totalCases > 0 ? (entityPreserved / totalCases) * 100.0 : 100.0;
    final compoundAccuracyPct = compoundRecords.isNotEmpty
        ? (compoundMatches / compoundRecords.length) * 100.0
        : 100.0;

    // Filter Precision, Recall, F1 across all evaluated cases
    int totalTp = 0;
    int totalFp = 0;
    int totalFn = 0;

    for (final r in records) {
      totalTp += r.truePositiveSlots;
      totalFp += r.falsePositiveSlots;
      totalFn += r.falseNegativeSlots;
    }

    final double precision = (totalTp + totalFp) > 0 ? totalTp / (totalTp + totalFp) : 1.0;
    final double recall = (totalTp + totalFn) > 0 ? totalTp / (totalTp + totalFn) : 1.0;
    final double f1 = (precision + recall) > 0 ? (2 * precision * recall) / (precision + recall) : 0.0;

    final filterPrecisionPct = precision * 100.0;
    final filterRecallPct = recall * 100.0;
    final filterF1Pct = f1 * 100.0;

    // Production Weighted Score (Weights: Compound 30%, Exact Match 25%, Hallucination Avoidance 25%, Intent 20%)
    final hallucinationAvoidancePct = (100.0 - hallucinationRatePct).clamp(0.0, 100.0);
    final productionWeightedScorePct = (compoundAccuracyPct * 0.30) +
        (exactMatchRatePct * 0.25) +
        (hallucinationAvoidancePct * 0.25) +
        (intentAccuracyPct * 0.20);

    // Slot Metrics
    final slotNames = [
      'driverName',
      'rallyName',
      'actionType',
      'country',
      'city',
      'stageName',
      'year',
      'limit',
    ];
    final slotMetrics = <String, SlotExtractionMetric>{};
    for (final slot in slotNames) {
      int expCount = 0;
      int extCount = 0;
      int corCount = 0;
      for (final r in records) {
        final hasExp = _getExpectedSlotValue(r.testCase.expectedFilters, slot) != null;
        final hasAct = r.parseResult.query != null && _getActualSlotValue(r.parseResult.query!, slot) != null;
        if (hasExp) expCount++;
        if (hasAct) extCount++;
        if (hasExp && hasAct && (r.slotMatches[slot] == true)) {
          corCount++;
        }
      }
      slotMetrics[slot] = SlotExtractionMetric(
        slotName: slot,
        totalExpected: expCount,
        totalExtracted: extCount,
        correctlyExtracted: corCount,
      );
    }

    // Category Metrics
    final categoryGroups = <String, List<CaseEvaluationRecord>>{};
    for (final r in records) {
      categoryGroups.putIfAbsent(r.testCase.category, () => []).add(r);
    }

    final categoryMetrics = <String, SubsetMetrics>{};
    categoryGroups.forEach((cat, catRecords) {
      final cCount = catRecords.length;
      final cIntents = catRecords.where((r) => r.intentMatch).length;
      final cExacts = catRecords.where((r) => r.exactMatch).length;
      final cCompound = catRecords.where((r) => r.compoundComplete).length;

      int cTp = 0, cFp = 0, cFn = 0;
      int sumLat = 0;
      double? sumCost;

      for (final cr in catRecords) {
        cTp += cr.truePositiveSlots;
        cFp += cr.falsePositiveSlots;
        cFn += cr.falseNegativeSlots;
        sumLat += cr.latencyMs;
        if (cr.costUsd != null) {
          sumCost = (sumCost ?? 0.0) + cr.costUsd!;
        }
      }

      final cP = (cTp + cFp) > 0 ? cTp / (cTp + cFp) : 1.0;
      final cR = (cTp + cFn) > 0 ? cTp / (cTp + cFn) : 1.0;
      final cF1 = (cP + cR) > 0 ? (2 * cP * cR) / (cP + cR) * 100.0 : 0.0;

      categoryMetrics[cat] = SubsetMetrics(
        name: cat,
        count: cCount,
        intentAccuracyPct: (cIntents / cCount) * 100.0,
        exactMatchPct: (cExacts / cCount) * 100.0,
        filterF1Pct: cF1,
        compoundCompletenessPct: (cCompound / cCount) * 100.0,
        avgLatencyMs: sumLat / cCount,
        avgCostUsd: sumCost != null ? sumCost / cCount : null,
      );
    });

    // Difficulty Metrics
    final difficultyGroups = <String, List<CaseEvaluationRecord>>{};
    for (final r in records) {
      difficultyGroups.putIfAbsent(r.testCase.difficulty.name, () => []).add(r);
    }

    final difficultyMetrics = <String, SubsetMetrics>{};
    difficultyGroups.forEach((diff, diffRecords) {
      final dCount = diffRecords.length;
      final dIntents = diffRecords.where((r) => r.intentMatch).length;
      final dExacts = diffRecords.where((r) => r.exactMatch).length;
      final dCompound = diffRecords.where((r) => r.compoundComplete).length;

      int dTp = 0, dFp = 0, dFn = 0;
      int sumLat = 0;
      double? sumCost;

      for (final dr in diffRecords) {
        dTp += dr.truePositiveSlots;
        dFp += dr.falsePositiveSlots;
        dFn += dr.falseNegativeSlots;
        sumLat += dr.latencyMs;
        if (dr.costUsd != null) {
          sumCost = (sumCost ?? 0.0) + dr.costUsd!;
        }
      }

      final dP = (dTp + dFp) > 0 ? dTp / (dTp + dFp) : 1.0;
      final dR = (dTp + dFn) > 0 ? dTp / (dTp + dFn) : 1.0;
      final dF1 = (dP + dR) > 0 ? (2 * dP * dR) / (dP + dR) * 100.0 : 0.0;

      difficultyMetrics[diff] = SubsetMetrics(
        name: diff,
        count: dCount,
        intentAccuracyPct: (dIntents / dCount) * 100.0,
        exactMatchPct: (dExacts / dCount) * 100.0,
        filterF1Pct: dF1,
        compoundCompletenessPct: (dCompound / dCount) * 100.0,
        avgLatencyMs: sumLat / dCount,
        avgCostUsd: sumCost != null ? sumCost / dCount : null,
      );
    });

    // Failure Counts
    final failureCounts = <FailureType, int>{};
    for (final r in records) {
      for (final f in r.failures) {
        failureCounts[f.type] = (failureCounts[f.type] ?? 0) + 1;
      }
    }

    return ProviderEvaluationReport(
      providerName: provider.name,
      modelName: modelName,
      timestamp: DateTime.now(),
      numberOfCases: totalCases,
      successfulParses: successfulParses,
      failedParses: failedParses,
      clarificationTriggers: clarificationTriggers,
      intentAccuracyPct: intentAccuracyPct,
      filterPrecisionPct: filterPrecisionPct,
      filterRecallPct: filterRecallPct,
      filterF1Pct: filterF1Pct,
      exactMatchRatePct: exactMatchRatePct,
      compoundAccuracyPct: compoundAccuracyPct,
      clarificationAccuracyPct: clarificationAccuracyPct,
      hallucinationRatePct: hallucinationRatePct,
      entityPreservationRatePct: entityPreservationRatePct,
      productionWeightedScorePct: productionWeightedScorePct,
      latencyStats: latencyStats,
      totalPromptTokens: totalPromptTokens,
      totalCompletionTokens: totalCompletionTokens,
      totalTokens: totalPromptTokens + totalCompletionTokens,
      totalCostUsd: totalCostUsd,
      avgCostPerQueryUsd: avgCostPerQuery,
      estimatedCostPerThousandUsd: costPerThousand,
      slotMetrics: slotMetrics,
      categoryMetrics: categoryMetrics,
      difficultyMetrics: difficultyMetrics,
      failureTypeCounts: failureCounts,
      records: records,
    );
  }
}
