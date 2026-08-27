/// Represents an alternative transcription hypothesis from an STT engine.
class TranscriptHypothesis {
  /// The transcribed alternative text.
  final String text;

  /// Normalized acoustic/language model confidence score [0.0, 1.0].
  final double confidence;

  /// Optional log probability of the token or sentence hypothesis.
  final double? logProb;

  const TranscriptHypothesis({
    required this.text,
    required this.confidence,
    this.logProb,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'confidence': confidence,
        if (logProb != null) 'logProb': logProb,
      };

  @override
  String toString() => 'TranscriptHypothesis(text: "$text", confidence: $confidence)';
}
