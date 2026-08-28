import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/speech/speech_transcription_context.dart';
import '../../models/speech/speech_transcription_result.dart';
import '../../models/supported_language.dart';
import '../../models/voice_state.dart';
import 'speech_config.dart';
import 'speech_to_text_service.dart';

/// Small adapter boundary around the platform plugin so lifecycle behavior can
/// be tested without invoking MethodChannels.
abstract class NativeSpeechRecognizer {
  Future<bool> initialize({
    required void Function(String code, bool permanent) onError,
    required void Function(String status) onStatus,
  });

  Future<bool> hasPermission();
  Future<List<String>> locales();
  Future<String?> systemLocale();
  Future<void> listen({
    required String? localeId,
    required Duration listenFor,
    required void Function(String text, bool isFinal, double? confidence)
    onResult,
  });
  Future<void> stop();
  Future<void> cancel();
}

class SpeechToTextNativeRecognizer implements NativeSpeechRecognizer {
  final SpeechToText _speech;

  SpeechToTextNativeRecognizer({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String code, bool permanent) onError,
    required void Function(String status) onStatus,
  }) => _speech.initialize(
    onError: (SpeechRecognitionError error) =>
        onError(error.errorMsg, error.permanent),
    onStatus: onStatus,
    options: [SpeechToText.androidNoBluetooth],
  );

  @override
  Future<bool> hasPermission() => _speech.hasPermission;

  @override
  Future<List<String>> locales() async =>
      (await _speech.locales()).map((locale) => locale.localeId).toList();

  @override
  Future<String?> systemLocale() async =>
      (await _speech.systemLocale())?.localeId;

  @override
  Future<void> listen({
    required String? localeId,
    required Duration listenFor,
    required void Function(String text, bool isFinal, double? confidence)
    onResult,
  }) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) => onResult(
        result.recognizedWords,
        result.finalResult,
        result.hasConfidenceRating ? result.confidence : null,
      ),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
        listenFor: listenFor,
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

/// Production mobile speech adapter backed by the operating system's native
/// recognizer. `NATIVE_DEVICE_STT` describes the integration boundary; the OS
/// may itself use an online recognizer depending on device settings.
class NativeDeviceSpeechToTextService implements ISpeechToTextService {
  final SpeechConfig config;
  final NativeSpeechRecognizer _recognizer;
  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();

  VoiceState _state = VoiceState.idle;
  bool _initialized = false;
  bool _disposed = false;
  bool _cancelled = false;
  int _generation = 0;
  String _latestText = '';
  double? _latestConfidence;
  SupportedLanguage _language = SupportedLanguages.defaultLanguage;
  void Function(String text, bool isFinal)? _onResult;
  void Function(VoiceState state)? _onStateChanged;
  void Function(VoiceError error)? _onError;
  Completer<SpeechTranscriptionResult?>? _stopCompleter;

  NativeDeviceSpeechToTextService({
    SpeechConfig? config,
    NativeSpeechRecognizer? recognizer,
  }) : config =
           config ??
           const SpeechConfig(
             providerType: SpeechProviderType.nativeDevice,
             endpointUrl: '',
             model: 'NATIVE_DEVICE_STT',
           ),
       _recognizer = recognizer ?? SpeechToTextNativeRecognizer();

  @override
  SpeechTranscriptionCapabilities get transcriptionCapabilities =>
      const SpeechTranscriptionCapabilities();

  @override
  VoiceState get currentState => _state;

  @override
  Stream<VoiceState> get stateStream => _stateController.stream;

  void _setState(VoiceState state) {
    if (_disposed) return;
    _state = state;
    _stateController.add(state);
    _onStateChanged?.call(state);
  }

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      _initialized = await _recognizer.initialize(
        onError: _handlePlatformError,
        onStatus: _handlePlatformStatus,
      );
      return _initialized;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() => _recognizer.hasPermission();

  @override
  Future<bool> requestPermission() => initialize();

  @override
  Future<void> startListening({
    required SupportedLanguage language,
    required void Function(String text, bool isFinal) onResult,
    required void Function(VoiceState state) onStateChanged,
    required void Function(VoiceError error) onError,
  }) async {
    if (_state == VoiceState.listening || _state == VoiceState.processing) {
      await cancelListening();
    }

    final generation = ++_generation;
    _cancelled = false;
    _latestText = '';
    _latestConfidence = null;
    _language = language;
    _onResult = onResult;
    _onStateChanged = onStateChanged;
    _onError = onError;
    _stopCompleter = null;
    _setState(VoiceState.requestingPermission);

    final available = await initialize();
    if (!_isCurrent(generation)) return;
    if (!available) {
      final permitted = await hasPermission().catchError((_) => false);
      _reportError(
        VoiceError(
          code: permitted
              ? VoiceError.speechUnavailable
              : VoiceError.permissionDenied,
          message: permitted
              ? 'Speech recognition is unavailable on this device. You can still type your search.'
              : 'Microphone or speech-recognition permission was denied. Enable it in system settings, or type your search.',
        ),
      );
      return;
    }

    final localeId = await _resolveLocale(language).catchError((_) => null);
    if (!_isCurrent(generation)) return;
    if (localeId == null) {
      _reportError(
        VoiceError(
          code: VoiceError.unsupportedLocale,
          message:
              '${language.displayName} speech recognition is not installed on this device. Choose another language or type your search.',
        ),
      );
      return;
    }

    try {
      await _recognizer.listen(
        localeId: localeId,
        listenFor: config.maxRecordingDuration,
        onResult: (text, isFinal, confidence) {
          if (!_isCurrent(generation) || _cancelled) return;
          final trimmed = text.trim();
          _latestText = trimmed;
          _latestConfidence = confidence;
          if (trimmed.isNotEmpty) _onResult?.call(trimmed, isFinal);
          if (isFinal) {
            _completeStopResult();
            _setState(VoiceState.idle);
          }
        },
      );
      if (_isCurrent(generation) && _state == VoiceState.requestingPermission) {
        _setState(VoiceState.listening);
      }
    } catch (error) {
      if (_isCurrent(generation)) {
        _reportError(
          VoiceError(
            code: VoiceError.speechUnavailable,
            message: 'Speech recognition could not start. You can still type your search.',
            details: error,
          ),
        );
      }
    }
  }

  Future<String?> _resolveLocale(SupportedLanguage language) async {
    final available = await _recognizer.locales();
    // Some Android recognizers expose no reliable locale inventory even
    // though they accept an explicit BCP-47 locale at listen time.
    if (available.isEmpty) return language.localeCode;
    String normalize(String value) => value.toLowerCase().replaceAll('_', '-');
    final desired = normalize(language.localeCode);
    for (final locale in available) {
      if (normalize(locale) == desired) return locale;
    }
    final languageCode = language.languageCode.toLowerCase();
    for (final locale in available) {
      if (normalize(locale).split('-').first == languageCode) return locale;
    }
    return null;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  Future<String?> stopListening() async =>
      (await stopListeningDetailed())?.text;

  @override
  Future<SpeechTranscriptionResult?> stopListeningDetailed() async {
    if (_state != VoiceState.listening) return null;
    _setState(VoiceState.processing);
    _stopCompleter = Completer<SpeechTranscriptionResult?>();
    await _recognizer.stop();
    return _stopCompleter!.future.timeout(
      const Duration(milliseconds: 2500),
      onTimeout: () {
        if (_latestText.isEmpty) {
          _reportError(
            const VoiceError(
              code: VoiceError.noSpeechDetected,
              message:
                  'No speech was detected. Try again, or type your search.',
            ),
          );
          return null;
        }
        final result = _buildResult();
        _setState(VoiceState.idle);
        return result;
      },
    );
  }

  SpeechTranscriptionResult _buildResult() => SpeechTranscriptionResult(
    text: _latestText,
    language: _language,
    confidence: _latestConfidence,
  );

  void _completeStopResult() {
    final completer = _stopCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(_latestText.isEmpty ? null : _buildResult());
    }
  }

  void _handlePlatformStatus(String status) {
    if (_disposed || _cancelled) return;
    if ((status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) &&
        _state == VoiceState.listening) {
      if (_latestText.isEmpty) {
        _reportError(
          const VoiceError(
            code: VoiceError.noSpeechDetected,
            message: 'No speech was detected. Try again, or type your search.',
          ),
        );
      } else {
        _onResult?.call(_latestText, true);
        _completeStopResult();
        _setState(VoiceState.idle);
      }
    }
  }

  void _handlePlatformError(String code, bool permanent) {
    if (_disposed || _cancelled) return;
    _reportError(_mapError(code));
  }

  VoiceError _mapError(String rawCode) {
    final code = rawCode.toLowerCase();
    if (code.contains('speech_recognizer_disabled')) {
      return const VoiceError(
        code: VoiceError.permissionDenied,
        message: 'Speech-recognition permission is disabled. Enable it in system settings, or type your search.',
      );
    }
    if (code.contains('permission')) {
      return const VoiceError(
        code: VoiceError.permissionDenied,
        message: 'Microphone permission was denied. Enable it in system settings, or type your search.',
      );
    }
    if (code.contains('language_not_supported') ||
        code.contains('language_unavailable')) {
      return const VoiceError(
        code: VoiceError.unsupportedLocale,
        message: 'The selected speech language is unavailable. Choose another language or type your search.',
      );
    }
    if (code.contains('speech_timeout')) {
      return const VoiceError(
        code: VoiceError.timeout,
        message: 'Listening timed out. Try again, or type your search.',
      );
    }
    if (code.contains('no_match')) {
      return const VoiceError(
        code: VoiceError.noSpeechDetected,
        message: 'No speech was recognized. Try again, or type your search.',
      );
    }
    if (code.contains('network')) {
      return const VoiceError(
        code: VoiceError.networkError,
        message: 'The device speech service could not connect. Check your connection, or type your search.',
      );
    }
    if (code.contains('audio')) {
      return const VoiceError(
        code: VoiceError.recordingFailed,
        message: 'The microphone could not capture audio. You can still type your search.',
      );
    }
    return VoiceError(
      code: VoiceError.speechUnavailable,
      message:
          'Speech recognition is unavailable. You can still type your search.',
      details: rawCode,
    );
  }

  void _reportError(VoiceError error) {
    final completer = _stopCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _setState(VoiceState.error);
    _onError?.call(error);
  }

  @override
  Future<void> cancelListening() async {
    _cancelled = true;
    ++_generation;
    final completer = _stopCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    await _recognizer.cancel();
    _latestText = '';
    _onResult = null;
    _onError = null;
    _setState(VoiceState.idle);
  }

  @override
  Future<String?> transcribeAudioBytes(
    List<int> bytes, {
    required SupportedLanguage language,
    String filename = 'audio.m4a',
    SpeechTranscriptionContext? context,
  }) async => null;

  @override
  Future<SpeechTranscriptionResult?> transcribeAudioBytesDetailed(
    List<int> bytes, {
    required SupportedLanguage language,
    String filename = 'audio.m4a',
    SpeechTranscriptionContext? context,
  }) async => null;

  @override
  Future<String?> transcribeAudioFile(
    dynamic file, {
    required SupportedLanguage language,
    SpeechTranscriptionContext? context,
  }) async => null;

  @override
  void dispose() {
    if (_disposed) return;
    _cancelled = true;
    ++_generation;
    _recognizer.cancel();
    _disposed = true;
    _stateController.close();
  }
}
