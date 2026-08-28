import 'speech_config.dart';
import 'speech_to_text_service.dart';
import 'mock_speech_to_text_service.dart';
import 'openai_speech_to_text_service.dart';
import 'native_device_speech_to_text_service.dart';
import 'speech_vocabulary_context.dart';

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
}
