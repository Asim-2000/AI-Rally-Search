import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../../models/speech/speech_transcription_result.dart';
import '../../models/speech/speech_transcription_context.dart';
import '../../models/speech/spoken_audio_context.dart';
import '../../models/speech/spoken_word_timestamp.dart';
import '../../models/speech/transcript_hypothesis.dart';
import '../../models/supported_language.dart';
import '../../models/voice_state.dart';
import 'speech_config.dart';
import 'speech_to_text_service.dart';
import 'speech_vocabulary_context.dart';

/// Speech-to-Text service implementation communicating with a production backend proxy
/// or directly with OpenAI Whisper in explicit local dev mode.
class OpenAiSpeechToTextService implements ISpeechToTextService {
  bool get _isGptTranscribe => config.model == 'gpt-transcribe';

  @override
  SpeechTranscriptionCapabilities get transcriptionCapabilities =>
      _isGptTranscribe
      ? const SpeechTranscriptionCapabilities(
          freeFormContext: true,
          keywordHints: true,
          multipleLanguageHints: true,
        )
      : const SpeechTranscriptionCapabilities(freeFormContext: true);
  final SpeechConfig config;
  final SpeechVocabularyContext vocabularyContext;
  final http.Client _httpClient;
  AudioRecorder? _recorder;

  VoiceState _currentState = VoiceState.idle;
  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();

  void Function(String text, bool isFinal)? _onResult;
  void Function(VoiceState state)? _onStateChanged;
  void Function(VoiceError error)? _onError;
  SupportedLanguage? _activeLanguage;
  Timer? _maxDurationTimer;
  DateTime? _recordingStartTime;

  OpenAiSpeechToTextService({
    required this.config,
    SpeechVocabularyContext? vocabularyContext,
    http.Client? httpClient,
    AudioRecorder? recorder,
  }) : vocabularyContext =
           vocabularyContext ?? DefaultSpeechVocabularyContext(),
       _httpClient = httpClient ?? http.Client(),
       _recorder = recorder;

  AudioRecorder get _activeRecorder => _recorder ??= AudioRecorder();

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
      _recordingStartTime = DateTime.now();

      // Start recording into temporary storage or buffer
      if (kIsWeb) {
        await _activeRecorder.start(recordConfig, path: '');
      } else {
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${tempDir.path}/voice_query_$timestamp.m4a';
        await _activeRecorder.start(recordConfig, path: filePath);
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
    final durationMs = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
        : 0;

    try {
      final recordedPath = await _activeRecorder.stop();
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
        try {
          if (await audioFile.exists()) await audioFile.delete();
        } catch (_) {}
        return null;
      }

      final spokenContext = SpokenAudioContext(
        bytes: Uint8List.fromList(audioBytes),
        format: 'm4a',
        sampleRate: 44100,
        channels: 1,
        durationMs: durationMs,
        localFilePath: recordedPath,
      );

      final result = await _transcribeAudioBytesDetailed(
        audioBytes: audioBytes,
        filename: 'query.m4a',
        language: _activeLanguage ?? SupportedLanguages.defaultLanguage,
        audioContext: spokenContext,
        durationMs: durationMs,
      );

      if (result == null || result.text.trim().isEmpty) {
        spokenContext.dispose();
        _setState(VoiceState.error);
        _onError?.call(
          const VoiceError(
            code: VoiceError.noSpeechDetected,
            message: 'No intelligible speech detected.',
          ),
        );
        return null;
      }

      final cleanTranscript = result.text.trim();
      _onResult?.call(cleanTranscript, true);
      _setState(VoiceState.idle);
      return result;
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
    final spokenContext = SpokenAudioContext(
      bytes: Uint8List.fromList(bytes),
      format: filename.endsWith('.wav') ? 'wav' : 'm4a',
      sampleRate: 44100,
      channels: 1,
      durationMs: 0,
    );

    return _transcribeAudioBytesDetailed(
      audioBytes: bytes,
      filename: filename,
      language: language,
      audioContext: spokenContext,
      durationMs: 0,
      context: context,
    );
  }

  @override
  Future<String?> transcribeAudioFile(
    dynamic file, {
    required SupportedLanguage language,
    SpeechTranscriptionContext? context,
  }) async {
    List<int> bytes;
    String filename = 'audio.m4a';
    String? path;
    if (file is File) {
      bytes = await file.readAsBytes();
      filename = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'audio.m4a';
      path = file.path;
    } else if (file is String) {
      final f = File(file);
      bytes = await f.readAsBytes();
      filename = f.uri.pathSegments.isNotEmpty
          ? f.uri.pathSegments.last
          : 'audio.m4a';
      path = file;
    } else {
      throw ArgumentError('file must be File or String path');
    }

    final spokenContext = SpokenAudioContext(
      bytes: Uint8List.fromList(bytes),
      format: filename.endsWith('.wav') ? 'wav' : 'm4a',
      sampleRate: 44100,
      channels: 1,
      durationMs: 0,
      localFilePath: path,
    );

    final res = await _transcribeAudioBytesDetailed(
      audioBytes: bytes,
      filename: filename,
      language: language,
      audioContext: spokenContext,
      durationMs: 0,
      context: context,
    );
    return res?.text;
  }

  /// Sends audio payload to configured proxy / STT endpoint and returns rich SpeechTranscriptionResult.
  Future<SpeechTranscriptionResult?> _transcribeAudioBytesDetailed({
    required List<int> audioBytes,
    required String filename,
    required SupportedLanguage language,
    SpokenAudioContext? audioContext,
    int durationMs = 0,
    SpeechTranscriptionContext? context,
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
    final whisperLang = _mapToWhisperLanguage(language.languageCode);
    if (_isGptTranscribe) {
      final hints = context?.languageHints.isNotEmpty == true
          ? context!.languageHints
          : [if (whisperLang != null) whisperLang];
      for (var i = 0; i < hints.length; i++) {
        request.fields['languages[$i]'] = hints[i];
      }
      request.fields['response_format'] = 'json';
    } else {
      if (whisperLang != null) request.fields['language'] = whisperLang;
      request.fields['response_format'] = 'verbose_json';
    }

    // Domain vocabulary prompt context
    final prompt =
        context?.prompt ??
        vocabularyContext.buildVocabularyPrompt(language: language);
    if (prompt.isNotEmpty) {
      request.fields['prompt'] = prompt;
    }
    if (_isGptTranscribe && context != null) {
      final validKeywords = context.keywords
          .map((value) => value.trim())
          .where(
            (value) => value.isNotEmpty && !value.contains(RegExp(r'[<>\r\n]')),
          )
          .toList(growable: false);
      for (var i = 0; i < validKeywords.length; i++) {
        request.fields['keywords[$i]'] = validKeywords[i];
      }
    }

    // Attach audio file
    request.files.add(
      http.MultipartFile.fromBytes('file', audioBytes, filename: filename),
    );

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(config.timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (jsonBody['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return null;

      final parsedDurationMs = jsonBody['duration'] != null
          ? ((jsonBody['duration'] as num).toDouble() * 1000).toInt()
          : durationMs;

      // Extract optional word-level timestamps if returned by verbose_json
      final words = <SpokenWordTimestamp>[];
      if (jsonBody['words'] is List) {
        for (final w in jsonBody['words']) {
          if (w is Map) {
            final wordStr = w['word']?.toString() ?? '';
            final startSec = (w['start'] as num?)?.toDouble() ?? 0.0;
            final endSec = (w['end'] as num?)?.toDouble() ?? startSec;
            final conf = (w['confidence'] as num?)?.toDouble();
            if (wordStr.isNotEmpty) {
              words.add(
                SpokenWordTimestamp(
                  word: wordStr,
                  startMs: (startSec * 1000).toInt(),
                  endMs: (endSec * 1000).toInt(),
                  confidence: conf,
                ),
              );
            }
          }
        }
      }

      // Extract segment confidence / logprobs if available
      double? overallConfidence;
      final hypotheses = <TranscriptHypothesis>[];
      if (jsonBody['segments'] is List) {
        final segments = jsonBody['segments'] as List;
        if (segments.isNotEmpty) {
          double totalLogProb = 0.0;
          int count = 0;
          for (final s in segments) {
            if (s is Map && s['avg_logprob'] is num) {
              totalLogProb += (s['avg_logprob'] as num).toDouble();
              count++;
            }
          }
          if (count > 0) {
            final avgLogProb = totalLogProb / count;
            // Approximate confidence: exp(avgLogProb) clamped to [0.0, 1.0]
            overallConfidence = exp(avgLogProb).clamp(0.0, 1.0);
          }
        }
      }

      return SpeechTranscriptionResult(
        text: text,
        hypotheses: hypotheses,
        words: words,
        audioContext: audioContext,
        language: language,
        durationMs: parsedDurationMs,
        confidence: overallConfidence,
      );
    } else {
      throw Exception('STT HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Official OpenAI Whisper supported language codes.
  static const Set<String> _whisperSupportedLanguageWhitelist = {
    'af',
    'am',
    'ar',
    'as',
    'az',
    'ba',
    'be',
    'bg',
    'bn',
    'bo',
    'br',
    'bs',
    'ca',
    'cs',
    'cy',
    'da',
    'de',
    'el',
    'en',
    'es',
    'et',
    'eu',
    'fa',
    'fi',
    'fo',
    'fr',
    'gl',
    'gu',
    'ha',
    'haw',
    'he',
    'hi',
    'hr',
    'ht',
    'hu',
    'hy',
    'id',
    'is',
    'it',
    'ja',
    'jw',
    'ka',
    'kk',
    'km',
    'kn',
    'ko',
    'la',
    'lb',
    'ln',
    'lo',
    'lt',
    'lv',
    'mg',
    'mi',
    'mk',
    'ml',
    'mn',
    'mr',
    'ms',
    'mt',
    'my',
    'ne',
    'nl',
    'nn',
    'no',
    'oc',
    'pa',
    'pl',
    'ps',
    'pt',
    'ro',
    'ru',
    'sa',
    'sd',
    'si',
    'sk',
    'sl',
    'sn',
    'so',
    'sq',
    'sr',
    'su',
    'sv',
    'sw',
    'ta',
    'te',
    'tg',
    'th',
    'tk',
    'tl',
    'tr',
    'tt',
    'uk',
    'ur',
    'uz',
    'vi',
    'yi',
    'yo',
    'zh',
  };

  /// Maps ISO language codes to Whisper supported codes, returning null for auto-detection if unsupported.
  String? _mapToWhisperLanguage(String code) {
    final cleanCode = code.toLowerCase().trim();
    if (cleanCode == 'nb' || cleanCode == 'nn') {
      return 'no'; // Norwegian
    }
    if (_whisperSupportedLanguageWhitelist.contains(cleanCode)) {
      return cleanCode;
    }
    // Unsupported explicit language code (e.g. 'ga' for Irish) -> Fallback to automatic language detection
    return null;
  }

  @override
  Future<void> cancelListening() async {
    _maxDurationTimer?.cancel();
    try {
      await _recorder?.cancel();
    } catch (_) {}
    _setState(VoiceState.idle);
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    _recorder?.dispose();
    _stateController.close();
  }
}
