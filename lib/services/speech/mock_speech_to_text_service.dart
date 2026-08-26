import 'dart:async';
import '../../models/supported_language.dart';
import '../../models/voice_state.dart';
import 'speech_to_text_service.dart';

/// Mock speech recognition service for unit tests, widget tests, and CI.
class MockSpeechToTextService implements ISpeechToTextService {
  VoiceState _currentState = VoiceState.idle;
  final StreamController<VoiceState> _stateController = StreamController<VoiceState>.broadcast();

  bool permissionGranted = true;
  bool shouldFailTranscription = false;
  VoiceError? simulatedError;
  Duration simulatedProcessingDelay;
  String? defaultTranscript;
  final Map<String, String> _languageTranscripts = {};

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
    if (_currentState != VoiceState.listening) {
      return null;
    }

    _setState(VoiceState.processing);
    if (simulatedProcessingDelay > Duration.zero) {
      await Future.delayed(simulatedProcessingDelay);
    }

    if (shouldFailTranscription || simulatedError != null) {
      _setState(VoiceState.error);
      final error = simulatedError ??
          const VoiceError(
            code: VoiceError.transcriptionFailed,
            message: 'Mock transcription failure',
          );
      _activeErrorCallback?.call(error);
      return null;
    }

    final langCode = _activeLanguage?.languageCode.toLowerCase() ?? 'en';
    final transcript = _languageTranscripts[langCode] ?? defaultTranscript ?? 'Show rallies in 2025';

    _activeResultCallback?.call(transcript, true);
    _setState(VoiceState.idle);
    return transcript;
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
  }) async {
    if (shouldFailTranscription || simulatedError != null) {
      return null;
    }
    final langCode = language.languageCode.toLowerCase();
    return _languageTranscripts[langCode] ?? defaultTranscript ?? 'Show rallies in 2025';
  }

  @override
  Future<String?> transcribeAudioFile(
    dynamic file, {
    required SupportedLanguage language,
  }) async {
    return transcribeAudioBytes([], language: language);
  }

  @override
  void dispose() {
    _stateController.close();
  }
}
