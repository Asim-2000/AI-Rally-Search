import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../models/speech/speech_transcription_context.dart';
import '../../models/speech/speech_transcription_result.dart';
import '../../models/supported_language.dart';
import '../../models/voice_state.dart';
import '../python_search_api_client.dart';
import 'speech_config.dart';
import 'speech_to_text_service.dart';

/// Speech-to-Text service implementation that records audio locally and calls
/// the backend transcription-only endpoint (POST /v1/voice/transcribe).
class CloudSpeechToTextService implements ISpeechToTextService {
  final PythonSearchApiClient? apiClient;
  final SpeechConfig config;
  AudioRecorder? _recorder;
  String? _currentRecordingPath;

  VoiceState _currentState = VoiceState.idle;
  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();

  void Function(String text, bool isFinal)? _onResult;
  void Function(VoiceState state)? _onStateChanged;
  void Function(VoiceError error)? _onError;
  SupportedLanguage? _activeLanguage;
  Timer? _maxDurationTimer;

  CloudSpeechToTextService({
    this.apiClient,
    SpeechConfig? config,
    AudioRecorder? recorder,
  })  : config = config ?? SpeechConfig.fromEnvironment(),
        _recorder = recorder;

  AudioRecorder get _activeRecorder => _recorder ??= AudioRecorder();

  @override
  SpeechTranscriptionCapabilities get transcriptionCapabilities =>
      const SpeechTranscriptionCapabilities(
        freeFormContext: true,
        keywordHints: false,
        multipleLanguageHints: false,
      );

  @override
  VoiceState get currentState => _currentState;

  @override
  Stream<VoiceState> get stateStream => _stateController.stream;

  void _setState(VoiceState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
    _onStateChanged?.call(newState);
  }

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _activeRecorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      _setState(VoiceState.requestingPermission);
      final hasPerm = await _activeRecorder.hasPermission();
      _setState(VoiceState.idle);
      return hasPerm;
    } catch (e) {
      _setState(VoiceState.idle);
      return false;
    }
  }

  @override
  Future<void> startListening({
    required SupportedLanguage language,
    required void Function(String text, bool isFinal) onResult,
    required void Function(VoiceState state) onStateChanged,
    required void Function(VoiceError error) onError,
  }) async {
    _activeLanguage = language;
    _onResult = onResult;
    _onStateChanged = onStateChanged;
    _onError = onError;

    try {
      _setState(VoiceState.requestingPermission);
      final hasPerm = await _activeRecorder.hasPermission();
      if (!hasPerm) {
        _setState(VoiceState.error);
        onError(
          const VoiceError(
            code: VoiceError.permissionDenied,
            message: 'Microphone permission was denied.',
          ),
        );
        return;
      }

      const recordConfig = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      );

      _setState(VoiceState.listening);

      if (kIsWeb) {
        await _activeRecorder.start(recordConfig, path: '');
        _currentRecordingPath = null;
      } else {
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${tempDir.path}/cloud_voice_$timestamp.m4a';
        _currentRecordingPath = filePath;
        await _activeRecorder.start(recordConfig, path: filePath);
      }

      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(config.maxRecordingDuration, () {
        if (_currentState == VoiceState.listening) {
          stopListening();
        }
      });
    } catch (e) {
      _setState(VoiceState.error);
      onError(
        VoiceError(
          code: VoiceError.recordingFailed,
          message: 'Failed to initiate microphone recording: $e',
          details: e,
        ),
      );
    }
  }

  @override
  Future<String?> stopListening() async {
    final detailed = await stopListeningDetailed();
    return detailed?.text;
  }

  @override
  Future<SpeechTranscriptionResult?> stopListeningDetailed() async {
    _maxDurationTimer?.cancel();
    if (_currentState != VoiceState.listening) {
      return null;
    }

    _setState(VoiceState.processing);
    String? recordedPath;
    try {
      recordedPath = await _activeRecorder.stop();
      final path = recordedPath ?? _currentRecordingPath;
      if (path == null || path.isEmpty) {
        _setState(VoiceState.error);
        _onError?.call(
          const VoiceError(
            code: VoiceError.noSpeechDetected,
            message: 'No audio recorded from microphone.',
          ),
        );
        return null;
      }

      final file = File(path);
      if (!await file.exists()) {
        _setState(VoiceState.error);
        _onError?.call(
          const VoiceError(
            code: VoiceError.recordingFailed,
            message: 'Recorded audio file could not be found.',
          ),
        );
        return null;
      }

      final audioBytes = await file.readAsBytes();
      if (audioBytes.isEmpty) {
        _setState(VoiceState.error);
        _onError?.call(
          const VoiceError(
            code: VoiceError.noSpeechDetected,
            message: 'Audio recording was empty.',
          ),
        );
        return null;
      }

      final languageCode = _activeLanguage?.languageCode ?? 'en';
      final SpeechTranscriptionResult transcription;

      if (apiClient != null) {
        final resp = await apiClient!.transcribe(
          audioBytes: audioBytes,
          filename: 'voice.m4a',
          language: languageCode,
        );
        if (resp.transcript.trim().isEmpty) {
          _setState(VoiceState.error);
          _onError?.call(
            const VoiceError(
              code: VoiceError.noSpeechDetected,
              message: 'No intelligible speech detected.',
            ),
          );
          return null;
        }
        transcription = SpeechTranscriptionResult(
          text: resp.transcript.trim(),
          language: _activeLanguage ?? SupportedLanguages.defaultLanguage,
          provider: resp.provider,
          model: resp.model,
          confidence: resp.uncalibratedConfidence,
          latencyMs: resp.latencyMs,
        );
      } else {
        throw const VoiceError(
          code: VoiceError.transcriptionFailed,
          message: 'Python backend client is not configured for cloud transcription.',
        );
      }

      _onResult?.call(transcription.text, true);
      _setState(VoiceState.idle);
      return transcription;
    } catch (e) {
      _setState(VoiceState.error);
      final voiceErr = e is VoiceError
          ? e
          : VoiceError(
              code: VoiceError.transcriptionFailed,
              message: 'Cloud speech transcription failed: $e',
              details: e,
            );
      _onError?.call(voiceErr);
      return null;
    } finally {
      // Clean up temporary audio recording file immediately
      final pathToDelete = recordedPath ?? _currentRecordingPath;
      if (pathToDelete != null && pathToDelete.isNotEmpty) {
        try {
          final f = File(pathToDelete);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
      _currentRecordingPath = null;
    }
  }

  @override
  Future<void> cancelListening() async {
    _maxDurationTimer?.cancel();
    if (_currentState == VoiceState.listening ||
        _currentState == VoiceState.processing) {
      try {
        await _activeRecorder.stop();
      } catch (_) {}
    }
    if (_currentRecordingPath != null) {
      try {
        final f = File(_currentRecordingPath!);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
      _currentRecordingPath = null;
    }
    _setState(VoiceState.idle);
  }

  @override
  Future<String?> transcribeAudioBytes(
    List<int> bytes, {
    required SupportedLanguage language,
    String filename = 'audio.m4a',
    SpeechTranscriptionContext? context,
  }) async {
    final result = await transcribeAudioBytesDetailed(
      bytes,
      language: language,
      filename: filename,
      context: context,
    );
    return result?.text;
  }

  @override
  Future<SpeechTranscriptionResult?> transcribeAudioBytesDetailed(
    List<int> bytes, {
    required SupportedLanguage language,
    String filename = 'audio.m4a',
    SpeechTranscriptionContext? context,
  }) async {
    if (apiClient == null) return null;
    final resp = await apiClient!.transcribe(
      audioBytes: Uint8List.fromList(bytes),
      filename: filename,
      language: language.languageCode,
    );
    return SpeechTranscriptionResult(
      text: resp.transcript.trim(),
      language: language,
      provider: resp.provider,
      model: resp.model,
      confidence: resp.uncalibratedConfidence,
      latencyMs: resp.latencyMs,
    );
  }

  @override
  Future<String?> transcribeAudioFile(
    dynamic file, {
    required SupportedLanguage language,
    SpeechTranscriptionContext? context,
  }) async {
    if (file is File) {
      final bytes = await file.readAsBytes();
      return transcribeAudioBytes(
        bytes,
        language: language,
        filename: file.path.split('/').last,
        context: context,
      );
    }
    return null;
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    cancelListening();
    _stateController.close();
    _recorder?.dispose();
  }
}
