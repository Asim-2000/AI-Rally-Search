/// Represents a word-level timing alignment and confidence in a spoken audio transcript.
class SpokenWordTimestamp {
  /// The transcribed word.
  final String word;

  /// Start offset in milliseconds from the beginning of the audio.
  final int startMs;

  /// End offset in milliseconds from the beginning of the audio.
  final int endMs;

  /// Optional confidence score for this individual word token [0.0, 1.0].
  final double? confidence;

  const SpokenWordTimestamp({
    required this.word,
    required this.startMs,
    required this.endMs,
    this.confidence,
  });

  /// Duration of this spoken word in milliseconds.
  int get durationMs => (endMs - startMs).clamp(0, 1000000);

  Map<String, dynamic> toJson() => {
        'word': word,
        'startMs': startMs,
        'endMs': endMs,
        if (confidence != null) 'confidence': confidence,
      };

  @override
  String toString() => 'SpokenWordTimestamp("$word", ${startMs}ms..${endMs}ms)';
}
