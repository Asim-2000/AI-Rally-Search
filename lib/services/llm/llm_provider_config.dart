import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supported LLM provider identifiers.
enum LlmProvider {
  openai,
  anthropic,
  gemini,
  mock;

  static LlmProvider fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'openai':
      case 'gpt':
        return LlmProvider.openai;
      case 'anthropic':
      case 'claude':
        return LlmProvider.anthropic;
      case 'gemini':
      case 'google':
        return LlmProvider.gemini;
      case 'mock':
      default:
        return LlmProvider.mock;
    }
  }
}

/// Provider-independent configuration for LLM query parsers.
class LlmConfig {
  final LlmProvider provider;
  final String model;
  final String? apiKey;
  final String? baseUrl;
  final Duration timeout;
  final int maxRetries;
  final double temperature;

  const LlmConfig({
    required this.provider,
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
    this.temperature = 0.0,
  });

  /// Factory constructing configuration from environment variables (.env).
  factory LlmConfig.fromEnvironment({
    LlmProvider? defaultProvider,
  }) {
    if (!dotenv.isInitialized) {
      return LlmConfig(
        provider: defaultProvider ?? LlmProvider.mock,
        model: 'mock-parser-v1',
      );
    }

    final rawProvider = dotenv.env['LLM_PROVIDER'];
    final provider = defaultProvider ?? LlmProvider.fromString(rawProvider);

    switch (provider) {
      case LlmProvider.openai:
        return LlmConfig(
          provider: LlmProvider.openai,
          model: dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o-mini',
          apiKey: dotenv.env['OPENAI_API_KEY'],
          baseUrl: dotenv.env['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1',
        );

      case LlmProvider.anthropic:
        return LlmConfig(
          provider: LlmProvider.anthropic,
          model: dotenv.env['ANTHROPIC_MODEL'] ?? 'claude-3-5-sonnet-20241022',
          apiKey: dotenv.env['ANTHROPIC_API_KEY'],
          baseUrl: dotenv.env['ANTHROPIC_BASE_URL'] ?? 'https://api.anthropic.com/v1',
        );

      case LlmProvider.gemini:
        return LlmConfig(
          provider: LlmProvider.gemini,
          model: dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-flash',
          apiKey: dotenv.env['GEMINI_API_KEY'],
          baseUrl: dotenv.env['GEMINI_BASE_URL'] ?? 'https://generativelanguage.googleapis.com/v1beta',
        );

      case LlmProvider.mock:
      default:
        return const LlmConfig(
          provider: LlmProvider.mock,
          model: 'mock-parser-v1',
        );
    }
  }

  LlmConfig copyWith({
    LlmProvider? provider,
    String? model,
    String? apiKey,
    String? baseUrl,
    Duration? timeout,
    int? maxRetries,
    double? temperature,
  }) {
    return LlmConfig(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      temperature: temperature ?? this.temperature,
    );
  }
}
