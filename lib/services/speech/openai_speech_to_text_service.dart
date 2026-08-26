import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../../models/supported_language.dart';
import '../../models/voice_state.dart';
import 'speech_config.dart';
import 'speech_to_text_service.dart';
import 'speech_vocabulary_context.dart';

/// Speech-to-Text service implementation communicating with a production backend proxy
/// or directly with OpenAI Whisper in explicit local dev mode.
class OpenAiSpeechToTextService implements ISpeechToTextService {
  final SpeechConfig config;
  final SpeechVocabularyContext vocabularyContext;
  final http.Client _httpClient;
  final AudioRecorder _recorder;

  VoiceState _currentState = VoiceState.idle;
  final StreamController<VoiceState> _stateController = StreamController<VoiceState>.broadcast();

  void Function(String text, bool isFinal)? _onResult;
  void Function(VoiceState state)? _onStateChanged;
  void Function(VoiceError error)? _onError;
  SupportedLanguage? _activeLanguage;
  Timer? _maxDurationTimer;

  OpenAiSpeechToTextService({
    required this.config,
    SpeechVocabularyContext? vocabularyContext,
    http.Client? httpClient,
    AudioRecorder? recorder,
  })  : vocabularyContext = vocabularyContext ?? DefaultSpeechVocabularyContext(),
        _httpClient = httpClient ?? http.Client(),
        _recorder = recorder ?? AudioRecorder();

  @override
  VoiceState get currentState => _currentState;

  @override
  Stream<VoiceState> get stateStream => _stateController.stream;

  void _setState(VoiceState newState) {
    _currentState = newState;
    _stateController.add(newState);
    _onStateChanged?.call(newState);
  }

  @override
  Future<bool> initialize() async {
    return true;
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      _setState(VoiceState.requestingPermission);
      final hasPerm = await _recorder.hasPermission();
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
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        _setState(VoiceState.error);
        onError(
          const VoiceError(
            code: VoiceError.permissionDenied,
            message: 'Microphone permission was denied. Please allow microphone access in system settings.',
          ),
        );
        return;
      }

      // Determine appropriate audio format across platforms
      const recordConfig = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      );

      _setState(VoiceState.listening);

      // Start recording into temporary storage or buffer
      if (kIsWeb) {
        await _recorder.start(recordConfig, path: '');
      } else {
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${tempDir.path}/voice_query_$timestamp.m4a';
        await _recorder.start(recordConfig, path: filePath);
      }

      // Guard with max recording duration
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
    _maxDurationTimer?.cancel();
    if (_currentState != VoiceState.listening) {
      return null;
    }

    _setState(VoiceState.processing);

    try {
      final recordedPath = await _recorder.stop();
      if (recordedPath == null || recordedPath.isEmpty) {
        _setState(VoiceState.error);
        _onError?.call(
          const VoiceError(
            code: VoiceError.noSpeechDetected,
            message: 'No audio recorded from microphone.',
          ),
        );
        return null;
      }

      // Read audio bytes
      final File audioFile = File(recordedPath);
      if (!await audioFile.exists()) {
        _setState(VoiceState.error);
        _onError?.call(
          const VoiceError(
            code: VoiceError.recordingFailed,
            message: 'Recorded audio file could not be found.',
          ),
        );
        return null;
      }

      final audioBytes = await audioFile.readAsBytes();
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

      final transcript = await _transcribeAudioBytes(
        audioBytes: audioBytes,
        filename: 'query.m4a',
        language: _activeLanguage ?? SupportedLanguages.defaultLanguage,
      );

      // Clean up temporary audio file
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {}

      if (transcript == null || transcript.trim().isEmpty) {
        _setState(VoiceState.error);
        _onError?.call(
          const VoiceError(
            code: VoiceError.noSpeechDetected,
            message: 'No intelligible speech detected.',
          ),
        );
        return null;
      }

      final cleanTranscript = transcript.trim();
      _onResult?.call(cleanTranscript, true);
      _setState(VoiceState.idle);
      return cleanTranscript;
    } catch (e) {
      _setState(VoiceState.error);
      _onError?.call(
        VoiceError(
          code: VoiceError.transcriptionFailed,
          message: 'Speech transcription failed: $e',
          details: e,
        ),
      );
      return null;
    }
  }

  /// Sends audio payload to configured proxy / STT endpoint.
  Future<String?> _transcribeAudioBytes({
    required List<int> audioBytes,
    required String filename,
    required SupportedLanguage language,
  }) async {
    final uri = Uri.parse(config.endpointUrl);
    final request = http.MultipartRequest('POST', uri);

    // Attach headers
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${config.apiKey}';
    }
    request.headers.addAll(config.customHeaders);

    // Form fields
    request.fields['model'] = config.model;
    request.fields['language'] = _mapToWhisperLanguage(language.languageCode);
    request.fields['response_format'] = 'json';

    // Domain vocabulary prompt context
    final prompt = vocabularyContext.buildVocabularyPrompt(language: language);
    if (prompt.isNotEmpty) {
      request.fields['prompt'] = prompt;
    }

    // Attach audio file
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await _httpClient.send(request).timeout(config.timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      return jsonBody['text'] as String?;
    } else {
      throw Exception('STT HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Maps ISO language codes to Whisper supported codes.
  String _mapToWhisperLanguage(String code) {
    switch (code.toLowerCase()) {
      case 'nb':
      case 'nn':
        return 'no'; // Norwegian
      case 'ga':
        return 'ga'; // Irish
      case 'cy':
        return 'cy'; // Welsh
      default:
        return code.toLowerCase();
    }
  }

  @override
  Future<void> cancelListening() async {
    _maxDurationTimer?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    _setState(VoiceState.idle);
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    _recorder.dispose();
    _stateController.close();
  }
}
