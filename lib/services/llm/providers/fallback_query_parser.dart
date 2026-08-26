import '../llm_provider_config.dart';
import '../llm_query_parser.dart';
import '../query_parse_result.dart';

/// Chaining query parser that tries a primary LlmQueryParser and falls back to
/// alternative parsers if the primary parser fails.
class FallbackLlmQueryParser implements LlmQueryParser {
  final LlmQueryParser primary;
  final List<LlmQueryParser> fallbacks;

  FallbackLlmQueryParser({
    required this.primary,
    this.fallbacks = const [],
  });

  @override
  LlmProvider get provider => primary.provider;

  @override
  Future<QueryParseResult> parse(
    String userQuery, {
    SearchContext? context,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Attempt primary parser
    try {
      final primaryResult = await primary.parse(userQuery, context: context);
      if (primaryResult.isSuccess || primaryResult.requiresClarification) {
        return primaryResult;
      }
    } catch (_) {
      // Primary threw exception, proceed to fallback
    }

    // 2. Attempt each fallback in sequence
    for (final fallback in fallbacks) {
      try {
        final fallbackResult = await fallback.parse(userQuery, context: context);
        if (fallbackResult.isSuccess || fallbackResult.requiresClarification) {
          stopwatch.stop();
          return QueryParseResult(
            query: fallbackResult.query,
            requiresClarification: fallbackResult.requiresClarification,
            clarificationQuestion: fallbackResult.clarificationQuestion,
            error: fallbackResult.error,
            interpretedSummary: fallbackResult.interpretedSummary,
            provider: fallback.provider,
            model: fallbackResult.model,
            latencyMs: stopwatch.elapsedMilliseconds,
            promptTokens: fallbackResult.promptTokens,
            completionTokens: fallbackResult.completionTokens,
            totalTokens: fallbackResult.totalTokens,
            confidence: fallbackResult.confidence,
            rawResponse: fallbackResult.rawResponse,
            metadata: {
              ...fallbackResult.metadata,
              'fallback_used': true,
              'primary_provider': primary.provider.name,
            },
          );
        }
      } catch (_) {
        // Continue to next fallback
      }
    }

    stopwatch.stop();
    return QueryParseResult.failure(
      error: 'All configured LLM query parsers failed to process the query',
      provider: primary.provider,
      latencyMs: stopwatch.elapsedMilliseconds,
      metadata: {'fallback_exhausted': true},
    );
  }
}
