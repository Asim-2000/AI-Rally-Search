import 'dart:convert';
import 'eval_models.dart';
import 'llm_cost_calculator.dart';

/// Formatter that transforms BenchmarkEvaluationReport into ASCII tables,
/// Markdown reports, or JSON exports.
class EvalReportFormatter {
  EvalReportFormatter._();

  /// Generates a formatted ASCII summary table for terminal display.
  static String formatConsoleReport(BenchmarkEvaluationReport report) {
    final buf = StringBuffer();
    final sep = '=' * 78;
    final thinSep = '-' * 78;

    buf.writeln('\n$sep');
    buf.writeln(' 🏎️  AI RALLY SEARCH - LLM EVALUATION BENCHMARK REPORT');
    buf.writeln(' Provider: ${report.providerName.toUpperCase()} | Model: ${report.modelName} | Timestamp: ${report.timestamp.toIso8601String()}');
    buf.writeln(sep);

    // 1. Executive Summary
    buf.writeln('\n📊 EXECUTIVE SUMMARY');
    buf.writeln(thinSep);
    buf.writeln(' Total Benchmark Queries:      ${report.totalQueries}');
    buf.writeln(' Successful Query Parses:      ${report.successfulParses} (${(report.successfulParses / (report.totalQueries == 0 ? 1 : report.totalQueries) * 100).toStringAsFixed(1)}%)');
    buf.writeln(' Clarification Triggers:       ${report.clarificationTriggers}');
    buf.writeln(' Failed / Errored Queries:     ${report.failedParses}');
    buf.writeln(' Overall Quality Index:        ${report.overallQualityScorePct.toStringAsFixed(1)}%');
    buf.writeln(' Overall Correctness Score:    ${report.overallCorrectnessScorePct.toStringAsFixed(1)}%');

    // 2. Pillar 1: Cost Analysis
    buf.writeln('\n💰 PILLAR 1: COST METRICS');
    buf.writeln(thinSep);
    buf.writeln(' Total Prompt Tokens:          ${report.totalPromptTokens}');
    buf.writeln(' Total Completion Tokens:      ${report.totalCompletionTokens}');
    buf.writeln(' Total Tokens Processed:       ${report.totalTokens}');
    buf.writeln(' Total Cost (USD):             ${LlmCostCalculator.formatCostUsd(report.totalCostUsd)}');
    buf.writeln(' Average Cost per Query:       ${LlmCostCalculator.formatCostUsd(report.avgCostPerQueryUsd)}');
    buf.writeln(' Estimated Cost / 1,000 reqs:  \$${report.estimatedCostPerThousandUsd.toStringAsFixed(4)}');

    // 3. Pillar 2: Latency Analysis
    buf.writeln('\n⏱️  PILLAR 2: LATENCY DISTRIBUTION');
    buf.writeln(thinSep);
    buf.writeln(' Phase        | Min    | Mean   | P50 (Med) | P90    | P95    | Max');
    buf.writeln('--------------+--------+--------+-----------+--------+--------+--------');
    buf.writeln(
      ' LLM Parse    | '
      '${report.parseLatencyStats.minMs.toString().padRight(6)} | '
      '${report.parseLatencyStats.meanMs.toStringAsFixed(0).padRight(6)} | '
      '${report.parseLatencyStats.p50Ms.toString().padRight(9)} | '
      '${report.parseLatencyStats.p90Ms.toString().padRight(6)} | '
      '${report.parseLatencyStats.p95Ms.toString().padRight(6)} | '
      '${report.parseLatencyStats.maxMs} ms',
    );
    buf.writeln(
      ' Total E2E    | '
      '${report.totalLatencyStats.minMs.toString().padRight(6)} | '
      '${report.totalLatencyStats.meanMs.toStringAsFixed(0).padRight(6)} | '
      '${report.totalLatencyStats.p50Ms.toString().padRight(9)} | '
      '${report.totalLatencyStats.p90Ms.toString().padRight(6)} | '
      '${report.totalLatencyStats.p95Ms.toString().padRight(6)} | '
      '${report.totalLatencyStats.maxMs} ms',
    );

    // 4. Pillar 3: Correctness Metrics
    buf.writeln('\n🛡️  PILLAR 3: STRUCTURAL CORRECTNESS');
    buf.writeln(thinSep);
    buf.writeln(' Schema Adherence Rate:        ${report.schemaAdherencePct.toStringAsFixed(1)}%');
    buf.writeln(' Database Execution Safety:    ${report.dbExecutionSuccessPct.toStringAsFixed(1)}%');
    buf.writeln(' Domain Invariant Score:       ${report.overallCorrectnessScorePct.toStringAsFixed(1)}%');

    // 5. Pillar 4: Semantic Accuracy
    buf.writeln('\n🎯 PILLAR 4: SEMANTIC ACCURACY');
    buf.writeln(thinSep);
    buf.writeln(' Intent Classification:        ${report.intentAccuracyPct.toStringAsFixed(1)}%');
    buf.writeln(' Exact Match (All Slots):      ${report.exactMatchAccuracyPct.toStringAsFixed(1)}%');
    buf.writeln(' Slot / Entity Extraction:     ${report.slotAccuracyPct.toStringAsFixed(1)}%');
    buf.writeln(' Clarification Accuracy:       ${report.clarificationAccuracyPct.toStringAsFixed(1)}%');

    // 6. Category Breakdown Table
    buf.writeln('\n📁 CATEGORY BREAKDOWN');
    buf.writeln(thinSep);
    buf.writeln(' Category                 | Count | Exact Match | Intent Acc | Avg Latency | Avg Cost');
    buf.writeln('--------------------------+-------+-------------+------------+-------------+-----------');
    for (final metric in report.categoryMetrics.values) {
      final cat = metric.category.padRight(24);
      final count = metric.count.toString().padRight(5);
      final em = '${metric.exactMatchPct.toStringAsFixed(0)}%'.padRight(11);
      final intent = '${metric.intentAccuracyPct.toStringAsFixed(0)}%'.padRight(10);
      final lat = '${metric.avgLatencyMs.toStringAsFixed(0)} ms'.padRight(11);
      final cost = LlmCostCalculator.formatCostUsd(metric.avgCostUsd);
      buf.writeln(' $cat | $count | $em | $intent | $lat | $cost');
    }

    buf.writeln('$sep\n');
    return buf.toString();
  }

  /// Generates a Markdown document summarizing the benchmark run.
  static String formatMarkdownReport(BenchmarkEvaluationReport report) {
    final buf = StringBuffer();

    buf.writeln('# LLM Evaluation Benchmark Report');
    buf.writeln('');
    buf.writeln('**Provider:** `${report.providerName}` | **Model:** `${report.modelName}` | **Date:** `${report.timestamp.toIso8601String()}`');
    buf.writeln('');
    buf.writeln('## Executive Summary');
    buf.writeln('');
    buf.writeln('| Metric | Value |');
    buf.writeln('| :--- | :--- |');
    buf.writeln('| **Total Queries** | `${report.totalQueries}` |');
    buf.writeln('| **Successful Parses** | `${report.successfulParses}` |');
    buf.writeln('| **Clarification Triggers** | `${report.clarificationTriggers}` |');
    buf.writeln('| **Overall Quality Score** | **`${report.overallQualityScorePct.toStringAsFixed(1)}%`** |');
    buf.writeln('| **Overall Correctness Score** | **`${report.overallCorrectnessScorePct.toStringAsFixed(1)}%`** |');
    buf.writeln('');
    buf.writeln('## Pillar 1: Cost Metrics');
    buf.writeln('');
    buf.writeln('| Metric | Value |');
    buf.writeln('| :--- | :--- |');
    buf.writeln('| Total Tokens | `${report.totalTokens}` (`${report.totalPromptTokens}` prompt + `${report.totalCompletionTokens}` completion) |');
    buf.writeln('| Total Cost (USD) | `${LlmCostCalculator.formatCostUsd(report.totalCostUsd)}` |');
    buf.writeln('| Average Cost / Query | `${LlmCostCalculator.formatCostUsd(report.avgCostPerQueryUsd)}` |');
    buf.writeln('| Estimated Cost / 1,000 Queries | `\$${report.estimatedCostPerThousandUsd.toStringAsFixed(4)}` |');
    buf.writeln('');
    buf.writeln('## Pillar 2: Latency Distribution');
    buf.writeln('');
    buf.writeln('| Metric | LLM Parse Latency | Total End-to-End Latency |');
    buf.writeln('| :--- | :--- | :--- |');
    buf.writeln('| **Mean** | `${report.parseLatencyStats.meanMs.toStringAsFixed(1)} ms` | `${report.totalLatencyStats.meanMs.toStringAsFixed(1)} ms` |');
    buf.writeln('| **P50 (Median)** | `${report.parseLatencyStats.p50Ms} ms` | `${report.totalLatencyStats.p50Ms} ms` |');
    buf.writeln('| **P90** | `${report.parseLatencyStats.p90Ms} ms` | `${report.totalLatencyStats.p90Ms} ms` |');
    buf.writeln('| **P95** | `${report.parseLatencyStats.p95Ms} ms` | `${report.totalLatencyStats.p95Ms} ms` |');
    buf.writeln('| **Max** | `${report.parseLatencyStats.maxMs} ms` | `${report.totalLatencyStats.maxMs} ms` |');
    buf.writeln('');
    buf.writeln('## Pillar 3: Correctness & Pillar 4: Accuracy');
    buf.writeln('');
    buf.writeln('| Dimension | Evaluation Metric | Score |');
    buf.writeln('| :--- | :--- | :--- |');
    buf.writeln('| **Correctness** | Schema Adherence | `${report.schemaAdherencePct.toStringAsFixed(1)}%` |');
    buf.writeln('| **Correctness** | DB Execution Safety | `${report.dbExecutionSuccessPct.toStringAsFixed(1)}%` |');
    buf.writeln('| **Accuracy** | Intent Classification | `${report.intentAccuracyPct.toStringAsFixed(1)}%` |');
    buf.writeln('| **Accuracy** | Exact Match (All Fields) | `${report.exactMatchAccuracyPct.toStringAsFixed(1)}%` |');
    buf.writeln('| **Accuracy** | Slot / Entity Accuracy | `${report.slotAccuracyPct.toStringAsFixed(1)}%` |');
    buf.writeln('| **Accuracy** | Clarification Precision | `${report.clarificationAccuracyPct.toStringAsFixed(1)}%` |');
    buf.writeln('');
    buf.writeln('## Category Breakdown');
    buf.writeln('');
    buf.writeln('| Category | Queries | Exact Match | Intent Acc | Avg Latency | Avg Cost |');
    buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- |');
    for (final m in report.categoryMetrics.values) {
      buf.writeln('| ${m.category} | ${m.count} | ${m.exactMatchPct.toStringAsFixed(0)}% | ${m.intentAccuracyPct.toStringAsFixed(0)}% | ${m.avgLatencyMs.toStringAsFixed(0)} ms | ${LlmCostCalculator.formatCostUsd(m.avgCostUsd)} |');
    }

    return buf.toString();
  }

  /// Generates a pretty-printed JSON string for storage or CI/CD pipelines.
  static String formatJsonReport(BenchmarkEvaluationReport report) {
    return const JsonEncoder.withIndent('  ').convert(report.toJson());
  }
}
