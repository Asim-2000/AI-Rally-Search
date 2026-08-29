import '../supported_language.dart';
import 'spoken_audio_context.dart';
import 'spoken_word_timestamp.dart';
import 'transcript_hypothesis.dart';

/// Rich transcription payload produced by an STT service.
///
/// Encapsulates the mandatory 1-best transcript, along with optional N-best alternatives,
/// optional word-level timestamps, optional confidence scores, and optional retained audio context.
class SpeechTranscriptionResult {
  /// The mandatory canonical 1-best transcript.
  final String text;

  /// Optional N-best alternative transcript hypotheses from the recognizer.
  final List<TranscriptHypothesis> hypotheses;

  /// Optional word-level timestamp alignments.
  final List<SpokenWordTimestamp> words;

  /// Optional retained audio buffer and lifecycle controller.
  final SpokenAudioContext? audioContext;

  /// The active language used or detected during transcription.
  final SupportedLanguage language;

  /// Total duration of the audio in milliseconds.
  final int durationMs;

  /// Optional overall acoustic confidence score [0.0, 1.0].
  final double? confidence;

  /// Provider name (e.g. 'openai', 'OS_NATIVE').
  final String? provider;

  /// Model identifier (e.g. 'gpt-transcribe', 'whisper-1', 'NATIVE_DEVICE_STT').
  final String? model;

  /// Latency in milliseconds.
  final double? latencyMs;

  const SpeechTranscriptionResult({
    required this.text,
    this.hypotheses = const [],
    this.words = const [],
    this.audioContext,
    required this.language,
    this.durationMs = 0,
    this.confidence,
    this.provider,
    this.model,
    this.latencyMs,
  });

  /// Factory creating a basic 1-best result from a text string.
  factory SpeechTranscriptionResult.textOnly({
    required String text,
    SupportedLanguage? language,
  }) {
    return SpeechTranscriptionResult(
      text: text,
      language: language ?? SupportedLanguages.defaultLanguage,
    );
  }

  /// True if alternative transcript hypotheses are available.
  bool get hasHypotheses => hypotheses.isNotEmpty;

  /// True if word-level timestamps are available.
  bool get hasTimestamps => words.isNotEmpty;

  /// True if retained audio context is present.
  bool get hasAudioContext => audioContext != null;

  /// Safely disposes any attached audio context.
  void disposeAudio() {
    audioContext?.dispose();
  }

  @override
  String toString() =>
      'SpeechTranscriptionResult(text: "$text", hypotheses: ${hypotheses.length}, words: ${words.length}, hasAudio: $hasAudioContext)';
}
