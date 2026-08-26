import 'dart:convert';
import 'eval_models.dart';

/// Formatter generating ASCII Console, Markdown, and JSON evaluation reports.
class EvalReportFormatter {
  EvalReportFormatter._();

  /// Formats a single provider evaluation report into human-readable ASCII console output.
  static String formatConsoleReport(ProviderEvaluationReport report) {
    final sb = StringBuffer();

    sb.writeln('================================================================');
    sb.writeln('AI RALLY SEARCH — LLM QUERY PARSER EVALUATION REPORT');
    sb.writeln('================================================================');
    sb.writeln('Provider:             ${report.providerName.toUpperCase()}');
    sb.writeln('Model:                ${report.modelName}');
    sb.writeln('Timestamp:            ${report.timestamp.toIso8601String()}');
    sb.writeln('Total Test Cases:     ${report.numberOfCases}');
    sb.writeln('Successful Parses:    ${report.successfulParses}');
    sb.writeln('Failed Parses:        ${report.failedParses}');
    sb.writeln('Clarifications:       ${report.clarificationTriggers}');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('PRIMARY EVALUATION METRICS');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('Intent Accuracy:          ${_pct(report.intentAccuracyPct)}');
    sb.writeln('Filter Precision:         ${_pct(report.filterPrecisionPct)}');
    sb.writeln('Filter Recall:            ${_pct(report.filterRecallPct)}');
    sb.writeln('Filter F1 Score:          ${_pct(report.filterF1Pct)}');
    sb.writeln('Exact Match Rate:         ${_pct(report.exactMatchRatePct)}');
    sb.writeln('Compound Completeness:    ${_pct(report.compoundAccuracyPct)}');
    sb.writeln('Clarification Accuracy:   ${_pct(report.clarificationAccuracyPct)}');
    sb.writeln('Hallucination Rate:       ${_pct(report.hallucinationRatePct)}');
    sb.writeln('Entity Preservation Rate: ${_pct(report.entityPreservationRatePct)}');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('PRODUCTION WEIGHTED SCORE');
    sb.writeln('Weighted Overall Score:   ${_pct(report.productionWeightedScorePct)}');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('LATENCY DISTRIBUTION (ms)');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('Average:   ${report.latencyStats.meanMs.toStringAsFixed(1)} ms');
    sb.writeln('Min / Max: ${report.latencyStats.minMs} ms / ${report.latencyStats.maxMs} ms');
    sb.writeln('Median (P50): ${report.latencyStats.p50Ms} ms');
    sb.writeln('P90 / P95:    ${report.latencyStats.p90Ms} ms / ${report.latencyStats.p95Ms} ms');
    sb.writeln('P99:          ${report.latencyStats.p99Ms} ms');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('TOKEN USAGE & ESTIMATED COST');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('Prompt Tokens:     ${report.totalPromptTokens}');
    sb.writeln('Comp Tokens:       ${report.totalCompletionTokens}');
    sb.writeln('Total Tokens:      ${report.totalTokens}');
    sb.writeln('Total Cost:        ${_cost(report.totalCostUsd)}');
    sb.writeln('Cost / 1,000 req:  ${_cost(report.estimatedCostPerThousandUsd)}');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('CATEGORY BREAKDOWN');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('Category                  Count  Intent   Exact    F1     Compound  Avg Lat');
    sb.writeln('------------------------------------------------------------------------');
    report.categoryMetrics.forEach((name, m) {
      sb.writeln(
        '${name.padRight(25)} '
        '${m.count.toString().padLeft(5)}  '
        '${_pct(m.intentAccuracyPct).padLeft(7)}  '
        '${_pct(m.exactMatchPct).padLeft(7)}  '
        '${_pct(m.filterF1Pct).padLeft(6)}  '
        '${_pct(m.compoundCompletenessPct).padLeft(8)}  '
        '${m.avgLatencyMs.toStringAsFixed(0).padLeft(6)}ms',
      );
    });

    if (report.failureTypeCounts.isNotEmpty) {
      sb.writeln('----------------------------------------------------------------');
      sb.writeln('FAILURE CLASSIFICATION');
      sb.writeln('----------------------------------------------------------------');
      report.failureTypeCounts.forEach((type, count) {
        sb.writeln('• ${type.description.padRight(35)} : $count');
      });
    }

    if (report.failedRecords.isNotEmpty) {
      sb.writeln('----------------------------------------------------------------');
      sb.writeln('FAILURE CASE SAMPLES (Top ${report.failedRecords.length > 5 ? 5 : report.failedRecords.length})');
      sb.writeln('----------------------------------------------------------------');
      for (final rec in report.failedRecords.take(5)) {
        sb.writeln('[${rec.testCase.id}] Query: "${rec.testCase.query}"');
        sb.writeln('  Expected: Intent=${rec.testCase.expectedIntent?.name}, Filters=${rec.testCase.expectedFilters}');
        sb.writeln('  Actual:   Intent=${rec.parseResult.query?.intent.name}, Filters={${_formatActualFilters(rec)}}');
        sb.writeln('  Failures:');
        for (final f in rec.failures) {
          sb.writeln('    - [${f.type.name}] ${f.message}');
        }
        sb.writeln('');
      }
    }

    sb.writeln('================================================================');
    return sb.toString();
  }

  /// Formats a single provider evaluation report into detailed Markdown.
  static String formatMarkdownReport(ProviderEvaluationReport report) {
    final sb = StringBuffer();

    sb.writeln('# LLM Query Parser Evaluation Report');
    sb.writeln('');
    sb.writeln('**Provider:** `${report.providerName.toUpperCase()}` | **Model:** `${report.modelName}` | **Evaluated At:** `${report.timestamp.toIso8601String()}`');
    sb.writeln('');
    sb.writeln('## Executive Summary');
    sb.writeln('');
    sb.writeln('| Metric | Score | Target | Status |');
    sb.writeln('|---|---|---|---|');
    sb.writeln('| **Intent Accuracy** | ${_pct(report.intentAccuracyPct)} | ≥ 95.0% | ${_status(report.intentAccuracyPct, 95.0)} |');
    sb.writeln('| **Filter Precision** | ${_pct(report.filterPrecisionPct)} | ≥ 90.0% | ${_status(report.filterPrecisionPct, 90.0)} |');
    sb.writeln('| **Filter Recall** | ${_pct(report.filterRecallPct)} | ≥ 90.0% | ${_status(report.filterRecallPct, 90.0)} |');
    sb.writeln('| **Filter F1 Score** | ${_pct(report.filterF1Pct)} | ≥ 90.0% | ${_status(report.filterF1Pct, 90.0)} |');
    sb.writeln('| **Exact Match Rate** | ${_pct(report.exactMatchRatePct)} | ≥ 85.0% | ${_status(report.exactMatchRatePct, 85.0)} |');
    sb.writeln('| **Compound Completeness** | ${_pct(report.compoundAccuracyPct)} | ≥ 85.0% | ${_status(report.compoundAccuracyPct, 85.0)} |');
    sb.writeln('| **Clarification Accuracy** | ${_pct(report.clarificationAccuracyPct)} | ≥ 90.0% | ${_status(report.clarificationAccuracyPct, 90.0)} |');
    sb.writeln('| **Hallucination Rate** | ${_pct(report.hallucinationRatePct)} | ≤ 2.0% | ${_invStatus(report.hallucinationRatePct, 2.0)} |');
    sb.writeln('| **Entity Preservation** | ${_pct(report.entityPreservationRatePct)} | ≥ 95.0% | ${_status(report.entityPreservationRatePct, 95.0)} |');
    sb.writeln('| **Production Weighted Score** | **${_pct(report.productionWeightedScorePct)}** | ≥ 90.0% | ${_status(report.productionWeightedScorePct, 90.0)} |');
    sb.writeln('');
    sb.writeln('## Latency & Economics');
    sb.writeln('');
    sb.writeln('| Metric | Value |');
    sb.writeln('|---|---|');
    sb.writeln('| Total Test Cases | ${report.numberOfCases} |');
    sb.writeln('| Mean Latency | ${report.latencyStats.meanMs.toStringAsFixed(1)} ms |');
    sb.writeln('| P50 (Median) Latency | ${report.latencyStats.p50Ms} ms |');
    sb.writeln('| P95 Latency | ${report.latencyStats.p95Ms} ms |');
    sb.writeln('| Total Tokens (Prompt / Completion) | ${report.totalTokens} (${report.totalPromptTokens} / ${report.totalCompletionTokens}) |');
    sb.writeln('| Total Evaluation Cost | ${_cost(report.totalCostUsd)} |');
    sb.writeln('| Estimated Cost / 1,000 Queries | ${_cost(report.estimatedCostPerThousandUsd)} |');
    sb.writeln('');
    sb.writeln('## Category Performance Breakdown');
    sb.writeln('');
    sb.writeln('| Category | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |');
    sb.writeln('|---|---|---|---|---|---|---|');
    report.categoryMetrics.forEach((name, m) {
      sb.writeln('| $name | ${m.count} | ${_pct(m.intentAccuracyPct)} | ${_pct(m.exactMatchPct)} | ${_pct(m.filterF1Pct)} | ${_pct(m.compoundCompletenessPct)} | ${m.avgLatencyMs.toStringAsFixed(0)} ms |');
    });
    sb.writeln('');
    sb.writeln('## Per-Slot Extraction Metrics');
    sb.writeln('');
    sb.writeln('| Slot | Expected | Extracted | Correct | Precision | Recall | F1 |');
    sb.writeln('|---|---|---|---|---|---|---|');
    report.slotMetrics.forEach((slot, sm) {
      sb.writeln('| `$slot` | ${sm.totalExpected} | ${sm.totalExtracted} | ${sm.correctlyExtracted} | ${_pct(sm.precisionPct)} | ${_pct(sm.recallPct)} | ${_pct(sm.f1Pct)} |');
    });
    sb.writeln('');

    if (report.failedRecords.isNotEmpty) {
      sb.writeln('## Failure Diagnostic Samples');
      sb.writeln('');
      for (final rec in report.failedRecords.take(10)) {
        sb.writeln('### `[${rec.testCase.id}]` "${rec.testCase.query}"');
        sb.writeln('- **Category:** `${rec.testCase.category}` (${rec.testCase.difficulty.name})');
        sb.writeln('- **Expected:** Intent=`${rec.testCase.expectedIntent?.name}`, Filters=`${rec.testCase.expectedFilters}`');
        sb.writeln('- **Actual:** Intent=`${rec.parseResult.query?.intent.name}`, Filters=`{${_formatActualFilters(rec)}}`');
        sb.writeln('- **Failures:**');
        for (final f in rec.failures) {
          sb.writeln('  - **`${f.type.name}`**: ${f.message}');
        }
        sb.writeln('');
      }
    }

    return sb.toString();
  }

  /// Formats a multi-provider comparison table.
  static String formatComparisonTable(Map<String, ProviderEvaluationReport> reports) {
    final sb = StringBuffer();

    sb.writeln('========================================================================================================================');
    sb.writeln('MULTI-PROVIDER BENCHMARK COMPARISON');
    sb.writeln('========================================================================================================================');
    sb.writeln('Provider / Model                  Intent   Filter F1  Exact Match  Compound  Clarif   Halluc  Avg Lat  P95 Lat  Cost/1k   Score');
    sb.writeln('------------------------------------------------------------------------------------------------------------------------');

    reports.forEach((name, r) {
      sb.writeln(
        '${name.padRight(32)} '
        '${_pct(r.intentAccuracyPct).padLeft(7)}  '
        '${_pct(r.filterF1Pct).padLeft(8)}  '
        '${_pct(r.exactMatchRatePct).padLeft(9)}  '
        '${_pct(r.compoundAccuracyPct).padLeft(8)}  '
        '${_pct(r.clarificationAccuracyPct).padLeft(6)}  '
        '${_pct(r.hallucinationRatePct).padLeft(6)}  '
        '${(r.latencyStats.meanMs.toStringAsFixed(0) + 'ms').padLeft(7)}  '
        '${(r.latencyStats.p95Ms.toString() + 'ms').padLeft(7)}  '
        '${_cost(r.estimatedCostPerThousandUsd).padLeft(8)}  '
        '${_pct(r.productionWeightedScorePct).padLeft(6)}',
      );
    });

    sb.writeln('========================================================================================================================');
    return sb.toString();
  }

  /// Formats a multi-provider comparison into a Markdown table.
  static String formatComparisonMarkdown(Map<String, ProviderEvaluationReport> reports) {
    final sb = StringBuffer();

    sb.writeln('# LLM Provider Benchmark Comparison Matrix');
    sb.writeln('');
    sb.writeln('| Provider / Model | Intent Acc | Filter F1 | Exact Match | Compound | Clarification | Hallucination | Avg Latency | P95 Latency | Cost / 1k | Prod Score |');
    sb.writeln('|---|---|---|---|---|---|---|---|---|---|---|');

    reports.forEach((name, r) {
      sb.writeln('| **$name** | ${_pct(r.intentAccuracyPct)} | ${_pct(r.filterF1Pct)} | ${_pct(r.exactMatchRatePct)} | ${_pct(r.compoundAccuracyPct)} | ${_pct(r.clarificationAccuracyPct)} | ${_pct(r.hallucinationRatePct)} | ${r.latencyStats.meanMs.toStringAsFixed(0)} ms | ${r.latencyStats.p95Ms} ms | ${_cost(r.estimatedCostPerThousandUsd)} | **${_pct(r.productionWeightedScorePct)}** |');
    });

    return sb.toString();
  }

  /// Formats report as machine-readable JSON.
  static String formatJsonReport(ProviderEvaluationReport report) {
    return const JsonEncoder.withIndent('  ').convert(report.toJson());
  }

  // --- Internal format helpers ---

  static String _pct(double val) => '${val.toStringAsFixed(1)}%';

  static String _cost(double? cost) => cost != null ? '\$${cost.toStringAsFixed(cost < 0.01 ? 6 : 4)}' : 'N/A';

  static String _status(double val, double target) => val >= target ? '✅ PASS' : '⚠️ WARN';

  static String _invStatus(double val, double maxTarget) => val <= maxTarget ? '✅ PASS' : '❌ FAIL';

  static String _formatActualFilters(CaseEvaluationRecord rec) {
    if (rec.parseResult.query == null) return 'null';
    final q = rec.parseResult.query!;
    final slots = <String>[];
    if (q.driverName != null) slots.add('driver: "${q.driverName}"');
    if (q.targetRallyName != null) slots.add('rally: "${q.targetRallyName}"');
    if (q.actionType != null) slots.add('action: "${q.actionType}"');
    if (q.country != null) slots.add('country: "${q.country}"');
    if (q.city != null) slots.add('city: "${q.city}"');
    if (q.stageName != null) slots.add('stage: "${q.stageName}"');
    if (q.year != null) slots.add('year: ${q.year}');
    if (q.limit != 20) slots.add('limit: ${q.limit}');
    return slots.join(', ');
  }
}
