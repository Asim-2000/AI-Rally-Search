import '../../models/search_query.dart';
import 'eval/llm_cost_calculator.dart';
import 'llm_provider_config.dart';

/// Provider-independent result model representing the outcome of
/// parsing a natural-language query into a structured SearchQuery.
class QueryParseResult {
  /// The canonical structured query extracted from natural language.
  /// Null if parsing failed or clarification is needed.
  final SearchQuery? query;

  /// True if the user's query is ambiguous and cannot be safely executed.
  final bool requiresClarification;

  /// Specific clarification question to display to the user.
  final String? clarificationQuestion;

  /// Error message if query parsing or network communication failed.
  final String? error;

  /// User-friendly summary generated deterministically from SearchQuery
  /// (e.g. "Showing jump highlights | Driver: Josh Moffett | Year: 2025")
  final String? interpretedSummary;

  /// The LLM provider that processed the query.
  final LlmProvider? provider;

  /// Specific model identifier used (e.g. "gpt-4o-mini").
  final String? model;

  /// End-to-end latency in milliseconds.
  final int? latencyMs;

  /// Token usage statistics.
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  /// Estimated USD cost for this parse operation.
  final double? estimatedCostUsd;

  /// Confidence score between 0.0 and 1.0 (if provided).
  final double? confidence;

  /// Raw unparsed response text from the LLM (useful for debugging/logging).
  final String? rawResponse;

  /// Additional debugging/telemetry metadata.
  final Map<String, dynamic> metadata;

  const QueryParseResult({
    this.query,
    this.requiresClarification = false,
    this.clarificationQuestion,
    this.error,
    this.interpretedSummary,
    this.provider,
    this.model,
    this.latencyMs,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.estimatedCostUsd,
    this.confidence,
    this.rawResponse,
    this.metadata = const {},
  });

  /// Success indicator: A valid SearchQuery is present without error or clarification.
  bool get isSuccess => query != null && !requiresClarification && error == null;

  /// Human-readable cost formatted as USD string.
  String get formattedCost =>
      estimatedCostUsd != null ? LlmCostCalculator.formatCostUsd(estimatedCostUsd!) : '\$0.000000';

  /// Human-readable latency formatted as ms.
  String get formattedLatency => latencyMs != null ? '${latencyMs}ms' : '0ms';

  /// Creates a failed parse result.
  factory QueryParseResult.failure({
    required String error,
    LlmProvider? provider,
    String? model,
    int? latencyMs,
    String? rawResponse,
    Map<String, dynamic>? metadata,
  }) {
    return QueryParseResult(
      error: error,
      provider: provider,
      model: model,
      latencyMs: latencyMs,
      rawResponse: rawResponse,
      metadata: metadata ?? {},
    );
  }

  /// Creates a clarification-needed result.
  factory QueryParseResult.clarification({
    required String clarificationQuestion,
    LlmProvider? provider,
    String? model,
    int? latencyMs,
    String? rawResponse,
    Map<String, dynamic>? metadata,
  }) {
    return QueryParseResult(
      requiresClarification: true,
      clarificationQuestion: clarificationQuestion,
      provider: provider,
      model: model,
      latencyMs: latencyMs,
      rawResponse: rawResponse,
      metadata: metadata ?? {},
    );
  }
}
