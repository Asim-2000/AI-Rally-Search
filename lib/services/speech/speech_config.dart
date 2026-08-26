import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Available Speech-to-Text provider strategies.
enum SpeechProviderType {
  /// Production backend proxy (safe for client deployment, no API key exposed).
  openAiProxy,

  /// Direct OpenAI API call for local developer evaluation and testing.
  openAiDirectDev,

  /// Deterministic mock for unit and widget tests.
  mock;

  static SpeechProviderType fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'openai_direct_dev':
      case 'openai_direct':
      case 'direct':
        return SpeechProviderType.openAiDirectDev;
      case 'openai_proxy':
      case 'proxy':
      case 'openai':
        return SpeechProviderType.openAiProxy;
      case 'mock':
      default:
        return SpeechProviderType.openAiProxy;
    }
  }
}

/// Provider-independent configuration for speech transcription services.
class SpeechConfig {
  final SpeechProviderType providerType;
  final String endpointUrl;
  final String? apiKey;
  final String model;
  final Duration timeout;
  final Duration maxRecordingDuration;
  final Map<String, String> customHeaders;

  const SpeechConfig({
    required this.providerType,
    required this.endpointUrl,
    this.apiKey,
    this.model = 'whisper-1',
    this.timeout = const Duration(seconds: 15),
    this.maxRecordingDuration = const Duration(seconds: 30),
    this.customHeaders = const {},
  });

  /// Factory creating configuration from environment variables (.env).
  factory SpeechConfig.fromEnvironment({SpeechProviderType? overrideProvider}) {
    if (!dotenv.isInitialized) {
      return const SpeechConfig(
        providerType: SpeechProviderType.mock,
        endpointUrl: 'http://localhost:8080/v1/audio/transcriptions',
      );
    }

    final rawProvider = dotenv.env['SPEECH_PROVIDER'];
    final provider = overrideProvider ?? SpeechProviderType.fromString(rawProvider);
    final model = dotenv.env['SPEECH_MODEL'] ?? 'whisper-1';
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    final rawTimeout = int.tryParse(dotenv.env['SPEECH_TIMEOUT_SECONDS'] ?? '15') ?? 15;

    // Production proxy endpoint vs dev direct URL
    final proxyUrl = dotenv.env['SPEECH_PROXY_URL'] ??
        dotenv.env['API_PROXY_URL'] ??
        'http://localhost:8080/v1/audio/transcriptions';
    final directUrl = dotenv.env['OPENAI_AUDIO_URL'] ??
        '${dotenv.env['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1'}/audio/transcriptions';

    switch (provider) {
      case SpeechProviderType.openAiDirectDev:
        return SpeechConfig(
          providerType: SpeechProviderType.openAiDirectDev,
          endpointUrl: directUrl,
          apiKey: apiKey,
          model: model,
          timeout: Duration(seconds: rawTimeout),
        );
      case SpeechProviderType.openAiProxy:
        return SpeechConfig(
          providerType: SpeechProviderType.openAiProxy,
          // If proxy URL is not set but apiKey exists in dev, fallback gracefully to directUrl if requested
          endpointUrl: dotenv.env['SPEECH_PROXY_URL'] != null ? proxyUrl : directUrl,
          apiKey: apiKey,
          model: model,
          timeout: Duration(seconds: rawTimeout),
        );
      case SpeechProviderType.mock:
      default:
        return SpeechConfig(
          providerType: SpeechProviderType.mock,
          endpointUrl: proxyUrl,
          model: model,
          timeout: Duration(seconds: rawTimeout),
        );
    }
  }

  SpeechConfig copyWith({
    SpeechProviderType? providerType,
    String? endpointUrl,
    String? apiKey,
    String? model,
    Duration? timeout,
    Duration? maxRecordingDuration,
    Map<String, String>? customHeaders,
  }) {
    return SpeechConfig(
      providerType: providerType ?? this.providerType,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      timeout: timeout ?? this.timeout,
      maxRecordingDuration: maxRecordingDuration ?? this.maxRecordingDuration,
      customHeaders: customHeaders ?? this.customHeaders,
    );
  }
}
