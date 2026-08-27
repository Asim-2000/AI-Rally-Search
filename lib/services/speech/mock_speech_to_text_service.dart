import 'dart:async';
import 'dart:typed_data';

import '../../models/speech/speech_transcription_result.dart';
import '../../models/speech/speech_transcription_context.dart';
import '../../models/speech/spoken_audio_context.dart';
import '../../models/speech/spoken_word_timestamp.dart';
import '../../models/speech/transcript_hypothesis.dart';
import '../../models/supported_language.dart';
import '../../models/voice_state.dart';
import 'speech_to_text_service.dart';

/// Mock speech recognition service for unit tests, widget tests, and CI.
class MockSpeechToTextService implements ISpeechToTextService {
  @override
  SpeechTranscriptionCapabilities get transcriptionCapabilities =>
      const SpeechTranscriptionCapabilities();
  VoiceState _currentState = VoiceState.idle;
  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();

  bool permissionGranted = true;
  bool shouldFailTranscription = false;
  VoiceError? simulatedError;
  Duration simulatedProcessingDelay;
  String? defaultTranscript;
  final Map<String, String> _languageTranscripts = {};
  List<TranscriptHypothesis> mockHypotheses = [];
  List<SpokenWordTimestamp> mockWords = [];
  bool mockAttachAudioContext = false;

  void Function(String text, bool isFinal)? _activeResultCallback;
  void Function(VoiceState state)? _activeStateCallback;
  void Function(VoiceError error)? _activeErrorCallback;
  SupportedLanguage? _activeLanguage;

  MockSpeechToTextService({
    this.permissionGranted = true,
    this.shouldFailTranscription = false,
    this.simulatedError,
    this.simulatedProcessingDelay = const Duration(milliseconds: 50),
    this.defaultTranscript = 'Show jumps featuring Moffett in Donegal',
    Map<String, String>? languageTranscripts,
    this.mockHypotheses = const [],
    this.mockWords = const [],
    this.mockAttachAudioContext = false,
  }) {
    if (languageTranscripts != null) {
      _languageTranscripts.addAll(languageTranscripts);
    }
  }

  @override
  VoiceState get currentState => _currentState;

  bool get isListening => _currentState == VoiceState.listening;
  bool get isProcessing => _currentState == VoiceState.processing;
  bool get isIdle => _currentState == VoiceState.idle;

  @override
  Stream<VoiceState> get stateStream => _stateController.stream;

  void setTranscriptForLanguage(String languageCode, String transcript) {
    _languageTranscripts[languageCode.toLowerCase()] = transcript;
  }

  void _setState(VoiceState newState) {
    _currentState = newState;
    _stateController.add(newState);
    _activeStateCallback?.call(newState);
  }

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> startListening({
    required SupportedLanguage language,
    required void Function(String text, bool isFinal) onResult,
    required void Function(VoiceState state) onStateChanged,
    required void Function(VoiceError error) onError,
  }) async {
    _activeLanguage = language;
    _activeResultCallback = onResult;
    _activeStateCallback = onStateChanged;
    _activeErrorCallback = onError;

    if (!permissionGranted) {
      _setState(VoiceState.error);
      onError(
        simulatedError ??
            const VoiceError(
              code: VoiceError.permissionDenied,
              message: 'Microphone permission denied',
            ),
      );
      return;
    }

    _setState(VoiceState.listening);
  }

  @override
  Future<String?> stopListening() async {
    final detailed = await stopListeningDetailed();
    return detailed?.text;
  }

  @override
  Future<SpeechTranscriptionResult?> stopListeningDetailed() async {
    if (_currentState != VoiceState.listening) {
      return null;
    }

    _setState(VoiceState.processing);
    if (simulatedProcessingDelay > Duration.zero) {
      await Future.delayed(simulatedProcessingDelay);
    }

    if (shouldFailTranscription || simulatedError != null) {
      _setState(VoiceState.error);
      final error =
          simulatedError ??
          const VoiceError(
            code: VoiceError.transcriptionFailed,
            message: 'Mock transcription failure',
          );
      _activeErrorCallback?.call(error);
      return null;
    }

    final lang = _activeLanguage ?? SupportedLanguages.defaultLanguage;
    final langCode = lang.languageCode.toLowerCase();
    final transcript =
        _languageTranscripts[langCode] ??
        defaultTranscript ??
        'Show rallies in 2025';

    _activeResultCallback?.call(transcript, true);
    _setState(VoiceState.idle);

    SpokenAudioContext? audioContext;
    if (mockAttachAudioContext) {
      audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList([0, 1, 2, 3]),
        durationMs: 1500,
        format: 'm4a',
      );
    }

    return SpeechTranscriptionResult(
      text: transcript,
      language: lang,
      durationMs: 1500,
      hypotheses: mockHypotheses,
      words: mockWords,
      audioContext: audioContext,
    );
  }

  @override
  Future<void> cancelListening() async {
    _setState(VoiceState.idle);
    _activeResultCallback = null;
    _activeStateCallback = null;
    _activeErrorCallback = null;
  }

  @override
  Future<String?> transcribeAudioBytes(
    List<int> bytes, {
    required SupportedLanguage language,
    String filename = 'audio.m4a',
    SpeechTranscriptionContext? context,
  }) async {
    final detailed = await transcribeAudioBytesDetailed(
      bytes,
      language: language,
      filename: filename,
      context: context,
    );
    return detailed?.text;
  }

  @override
  Future<SpeechTranscriptionResult?> transcribeAudioBytesDetailed(
    List<int> bytes, {
    required SupportedLanguage language,
    String filename = 'audio.m4a',
    SpeechTranscriptionContext? context,
  }) async {
    if (shouldFailTranscription || simulatedError != null) {
      return null;
    }
    final langCode = language.languageCode.toLowerCase();
    final transcript =
        _languageTranscripts[langCode] ??
        defaultTranscript ??
        'Show rallies in 2025';

    SpokenAudioContext? audioContext;
    if (mockAttachAudioContext || bytes.isNotEmpty) {
      audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList(bytes.isNotEmpty ? bytes : [0, 1, 2, 3]),
        durationMs: 1500,
        format: 'm4a',
      );
    }

    return SpeechTranscriptionResult(
      text: transcript,
      language: language,
      durationMs: 1500,
      hypotheses: mockHypotheses,
      words: mockWords,
      audioContext: audioContext,
    );
  }

  @override
  Future<String?> transcribeAudioFile(
    dynamic file, {
    required SupportedLanguage language,
    SpeechTranscriptionContext? context,
  }) async {
    return transcribeAudioBytes([], language: language, context: context);
  }

  @override
  void dispose() {
    _stateController.close();
  }
}
