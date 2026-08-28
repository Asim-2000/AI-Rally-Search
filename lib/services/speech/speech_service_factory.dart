import 'cloud_speech_to_text_service.dart';
import 'speech_config.dart';
import 'speech_to_text_service.dart';
import 'mock_speech_to_text_service.dart';
import 'openai_speech_to_text_service.dart';
import 'native_device_speech_to_text_service.dart';
import 'speech_vocabulary_context.dart';
import '../python_search_api_client.dart';

/// Factory responsible for instantiating the appropriate Speech-to-Text service adapter.
class SpeechServiceFactory {
  SpeechServiceFactory._();

  /// Creates an ISpeechToTextService instance based on configuration or environment.
  static ISpeechToTextService create({
    SpeechConfig? config,
    SpeechVocabularyContext? vocabularyContext,
  }) {
    final speechConfig = config ?? SpeechConfig.fromEnvironment();

    switch (speechConfig.providerType) {
      case SpeechProviderType.nativeDevice:
        return NativeDeviceSpeechToTextService(config: speechConfig);
      case SpeechProviderType.openAiDirectDev:
      case SpeechProviderType.openAiProxy:
        return OpenAiSpeechToTextService(
          config: speechConfig,
          vocabularyContext: vocabularyContext,
        );
      case SpeechProviderType.mock:
        return MockSpeechToTextService();
    }
  }

  /// Creates a Native mobile speech recognition service instance.
  static ISpeechToTextService createNative({SpeechConfig? config}) {
    final speechConfig = config ?? SpeechConfig.fromEnvironment();
    if (speechConfig.providerType == SpeechProviderType.mock) {
      return MockSpeechToTextService();
    }
    return NativeDeviceSpeechToTextService(config: speechConfig);
  }

  /// Creates a Cloud speech transcription service instance backed by backend /v1/voice/transcribe.
  static ISpeechToTextService createCloud({
    SpeechConfig? config,
    PythonSearchApiClient? pythonApiClient,
  }) {
    final speechConfig = config ?? SpeechConfig.fromEnvironment();
    if (speechConfig.providerType == SpeechProviderType.mock) {
      return MockSpeechToTextService();
    }
    return CloudSpeechToTextService(
      config: speechConfig,
      apiClient: pythonApiClient,
    );
  }
}

