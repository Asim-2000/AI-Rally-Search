import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/models/voice_state.dart';
import 'package:ai_rally_search/services/speech/native_device_speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import 'package:ai_rally_search/services/speech/speech_service_factory.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNativeRecognizer implements NativeSpeechRecognizer {
  bool available = true;
  bool permitted = true;
  List<String> availableLocales = ['en_US', 'lv_LV', 'fr_FR'];
  String? defaultLocale = 'en_US';
  int cancelCount = 0;
  int stopCount = 0;
  String? listenedLocale;
  void Function(String code, bool permanent)? errorCallback;
  void Function(String status)? statusCallback;
  void Function(String text, bool isFinal, double? confidence)? resultCallback;

  @override
  Future<bool> initialize({
    required void Function(String code, bool permanent) onError,
    required void Function(String status) onStatus,
  }) async {
    errorCallback = onError;
    statusCallback = onStatus;
    return available;
  }

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<List<String>> locales() async => availableLocales;

  @override
  Future<String?> systemLocale() async => defaultLocale;

  @override
  Future<void> listen({
    required String? localeId,
    required Duration listenFor,
    required void Function(String text, bool isFinal, double? confidence)
    onResult,
  }) async {
    listenedLocale = localeId;
    resultCallback = onResult;
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> cancel() async => cancelCount++;
}

void main() {
  late FakeNativeRecognizer recognizer;
  late NativeDeviceSpeechToTextService service;

  setUp(() {
    recognizer = FakeNativeRecognizer();
    service = NativeDeviceSpeechToTextService(recognizer: recognizer);
  });

  tearDown(() => service.dispose());

  test('NATIVE_DEVICE_STT is the configured native production adapter', () {
    const config = SpeechConfig(
      providerType: SpeechProviderType.nativeDevice,
      endpointUrl: '',
      model: 'NATIVE_DEVICE_STT',
    );
    final created = SpeechServiceFactory.create(config: config);
    expect(created, isA<NativeDeviceSpeechToTextService>());
    created.dispose();
  });

  test('native device recognition is the no-override production default', () {
    expect(
      SpeechProviderType.fromString(null),
      SpeechProviderType.nativeDevice,
    );
    final created = SpeechServiceFactory.create();
    expect(created, isA<NativeDeviceSpeechToTextService>());
    created.dispose();
  });

  test(
    'emits partial and final text and uses the selected exact locale',
    () async {
      final results = <(String, bool)>[];
      final states = <VoiceState>[];

      await service.startListening(
        language: SupportedLanguages.latvian,
        onResult: (text, finalResult) => results.add((text, finalResult)),
        onStateChanged: states.add,
        onError: (_) => fail('unexpected error'),
      );

      expect(recognizer.listenedLocale, 'lv_LV');
      expect(service.currentState, VoiceState.listening);
      recognizer.resultCallback?.call('Alūksnes', false, 0.7);
      recognizer.resultCallback?.call('Alūksnes rallijs', true, 0.9);

      expect(results, [('Alūksnes', false), ('Alūksnes rallijs', true)]);
      expect(service.currentState, VoiceState.idle);
      expect(
        states,
        containsAllInOrder([
          VoiceState.requestingPermission,
          VoiceState.listening,
          VoiceState.idle,
        ]),
      );
    },
  );

  test('falls back to the closest locale with the same language', () async {
    recognizer.availableLocales = ['en-US', 'en-AU'];

    await service.startListening(
      language: SupportedLanguages.english,
      onResult: (_, _) {},
      onStateChanged: (_) {},
      onError: (_) => fail('unexpected error'),
    );

    expect(recognizer.listenedLocale, 'en-US');
  });

  test('reports an unsupported selected locale without starting', () async {
    recognizer.availableLocales = ['en_US'];
    VoiceError? error;

    await service.startListening(
      language: SupportedLanguages.latvian,
      onResult: (_, _) {},
      onStateChanged: (_) {},
      onError: (value) => error = value,
    );

    expect(error?.code, VoiceError.unsupportedLocale);
    expect(service.currentState, VoiceState.error);
    expect(recognizer.resultCallback, isNull);
  });

  test(
    'distinguishes denied permission from unavailable recognition',
    () async {
      recognizer.available = false;
      recognizer.permitted = false;
      VoiceError? error;

      await service.startListening(
        language: SupportedLanguages.english,
        onResult: (_, _) {},
        onStateChanged: (_) {},
        onError: (value) => error = value,
      );

      expect(error?.code, VoiceError.permissionDenied);
      expect(error?.message, contains('type your search'));
    },
  );

  test('manual stop returns the final native result', () async {
    await service.startListening(
      language: SupportedLanguages.english,
      onResult: (_, _) {},
      onStateChanged: (_) {},
      onError: (_) => fail('unexpected error'),
    );

    final stopped = service.stopListeningDetailed();
    await Future<void>.delayed(Duration.zero);
    recognizer.resultCallback?.call('Max McRae jumps', true, 0.88);
    final result = await stopped;

    expect(recognizer.stopCount, 1);
    expect(result?.text, 'Max McRae jumps');
    expect(result?.confidence, 0.88);
  });

  test('cancel invalidates late results and resets to idle', () async {
    final results = <String>[];
    await service.startListening(
      language: SupportedLanguages.english,
      onResult: (text, _) => results.add(text),
      onStateChanged: (_) {},
      onError: (_) => fail('unexpected error'),
    );
    final staleCallback = recognizer.resultCallback;

    await service.cancelListening();
    staleCallback?.call('stale transcript', true, 1);

    expect(results, isEmpty);
    expect(service.currentState, VoiceState.idle);
    expect(recognizer.cancelCount, 1);
  });

  test(
    'clear-style cancel cannot return an in-flight partial as final',
    () async {
      await service.startListening(
        language: SupportedLanguages.english,
        onResult: (_, _) {},
        onStateChanged: (_) {},
        onError: (_) => fail('unexpected error'),
      );
      recognizer.resultCallback?.call(
        'partial that must be discarded',
        false,
        0.5,
      );

      final stopping = service.stopListeningDetailed();
      await Future<void>.delayed(Duration.zero);
      await service.cancelListening();

      expect(await stopping, isNull);
      expect(service.currentState, VoiceState.idle);
    },
  );

  test('maps native timeout, no-speech, locale and audio failures', () async {
    const cases = {
      'error_speech_timeout': VoiceError.timeout,
      'error_no_match': VoiceError.noSpeechDetected,
      'error_language_unavailable': VoiceError.unsupportedLocale,
      'error_audio_error': VoiceError.recordingFailed,
    };

    for (final entry in cases.entries) {
      VoiceError? received;
      await service.startListening(
        language: SupportedLanguages.english,
        onResult: (_, _) {},
        onStateChanged: (_) {},
        onError: (error) => received = error,
      );
      recognizer.errorCallback?.call(entry.key, true);
      expect(received?.code, entry.value);
      await service.cancelListening();
    }
  });
}
