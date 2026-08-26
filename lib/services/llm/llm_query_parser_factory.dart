import 'package:http/http.dart' as http;
import 'llm_provider_config.dart';
import 'llm_query_parser.dart';
import 'providers/gemini_query_parser.dart';
import 'providers/mock_query_parser.dart';
import 'providers/openai_query_parser.dart';

/// Factory responsible for instantiating the active LlmQueryParser
/// based on configuration or environment settings.
class LlmQueryParserFactory {
  LlmQueryParserFactory._();

  /// Creates a configured LlmQueryParser instance.
  static LlmQueryParser create({
    LlmConfig? config,
    http.Client? client,
  }) {
    final effectiveConfig = config ?? LlmConfig.fromEnvironment();

    switch (effectiveConfig.provider) {
      case LlmProvider.openai:
        return OpenAIQueryParser(
          config: effectiveConfig,
          client: client,
        );

      case LlmProvider.gemini:
        return GeminiQueryParser(
          config: effectiveConfig,
          client: client,
        );

      case LlmProvider.anthropic:
        throw UnsupportedError(
          'AnthropicQueryParser is scheduled for a future update. '
          'Please configure LlmProvider.gemini, LlmProvider.openai, or LlmProvider.mock in .env.',
        );

      case LlmProvider.mock:
      default:
        return MockLlmQueryParser();
    }
  }
}
