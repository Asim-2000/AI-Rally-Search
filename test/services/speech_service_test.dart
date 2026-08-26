import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/models/voice_state.dart';
import 'package:ai_rally_search/services/speech/mock_speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import 'package:ai_rally_search/services/speech/speech_service_factory.dart';
import 'package:ai_rally_search/services/speech/speech_vocabulary_context.dart';

void main() {
  group('ISpeechToTextService & MockSpeechToTextService Tests', () {
    late MockSpeechToTextService speechService;

    setUp(() {
      speechService = MockSpeechToTextService();
    });

    tearDown(() {
      speechService.dispose();
    });

    test('Initial state is idle', () {
      expect(speechService.currentState, equals(VoiceState.idle));
    });

    test('Transitions through idle -> listening -> processing -> idle on speech input', () async {
      final states = <VoiceState>[];
      speechService.stateStream.listen(states.add);

      String? resultTranscript;
      await speechService.startListening(
        language: SupportedLanguages.english,
        onResult: (text, isFinal) {
          resultTranscript = text;
        },
        onStateChanged: (state) {},
        onError: (error) {},
      );

      expect(speechService.currentState, equals(VoiceState.listening));

      final stopped = await speechService.stopListening();
      expect(stopped, isNotNull);
      expect(resultTranscript, equals(stopped));
      expect(speechService.currentState, equals(VoiceState.idle));
    });

    test('Handles permission rejection gracefully', () async {
      speechService.permissionGranted = false;
      VoiceError? reportedError;

      await speechService.startListening(
        language: SupportedLanguages.english,
        onResult: (_, __) {},
        onStateChanged: (_) {},
        onError: (error) {
          reportedError = error;
        },
      );

      expect(speechService.currentState, equals(VoiceState.error));
      expect(reportedError, isNotNull);
      expect(reportedError!.code, equals(VoiceError.permissionDenied));
    });

    test('Handles transcription error gracefully', () async {
      speechService.shouldFailTranscription = true;
      VoiceError? reportedError;

      await speechService.startListening(
        language: SupportedLanguages.english,
        onResult: (_, __) {},
        onStateChanged: (_) {},
        onError: (error) {
          reportedError = error;
        },
      );

      final result = await speechService.stopListening();
      expect(result, isNull);
      expect(speechService.currentState, equals(VoiceState.error));
      expect(reportedError, isNotNull);
    });

    test('Returns language-specific transcript for multilingual voice search', () async {
      speechService.setTranscriptForLanguage('fr', 'Montrez les sauts de Moffett au rallye de Donegal');
      speechService.setTranscriptForLanguage('ur', 'ڈونیگل میں موفیٹ کی جمپس دکھائیں');

      String? frenchTranscript;
      await speechService.startListening(
        language: SupportedLanguages.french,
        onResult: (text, isFinal) => frenchTranscript = text,
        onStateChanged: (_) {},
        onError: (_) {},
      );
      await speechService.stopListening();
      expect(frenchTranscript, equals('Montrez les sauts de Moffett au rallye de Donegal'));

      String? urduTranscript;
      await speechService.startListening(
        language: SupportedLanguages.urdu,
        onResult: (text, isFinal) => urduTranscript = text,
        onStateChanged: (_) {},
        onError: (_) {},
      );
      await speechService.stopListening();
      expect(urduTranscript, equals('ڈونیگل میں موفیٹ کی جمپس دکھائیں'));
    });
  });

  group('SpeechVocabularyContext Tests', () {
    test('Builds vocabulary prompt incorporating drivers, rallies, and actions', () {
      final vocab = DefaultSpeechVocabularyContext();
      final prompt = vocab.buildVocabularyPrompt();

      expect(prompt, contains('Rally motorsport search'));
      expect(prompt, contains('Josh Moffett'));
      expect(prompt, contains('Donegal International Rally'));
      expect(prompt, contains('jump'));
      expect(prompt, contains('drift'));
    });

    test('Accepts custom drivers and rallies', () {
      final vocab = DefaultSpeechVocabularyContext(
        customDrivers: ['Custom Driver A', 'Custom Driver B'],
        customRallies: ['Custom Rally 2025'],
      );

      final prompt = vocab.buildVocabularyPrompt();
      expect(prompt, contains('Custom Driver A'));
      expect(prompt, contains('Custom Rally 2025'));
    });
  });

  group('SpeechConfig & Factory Tests', () {
    test('Creates mock speech service by default when config is mock', () {
      const config = SpeechConfig(
        providerType: SpeechProviderType.mock,
        endpointUrl: 'http://localhost:8080',
      );
      final service = SpeechServiceFactory.create(config: config);
      expect(service, isA<MockSpeechToTextService>());
      service.dispose();
    });
  });
}
