import '../../../../models/entity_candidate.dart';
import '../../../../models/speech/spoken_audio_context.dart';
import '../../../../models/speech/spoken_word_timestamp.dart';

/// Optional provider interface for candidate-vs-audio acoustic scoring and CTC reranking.
///
/// NOTE: This component is optional and no-op in MVP.
abstract class IAcousticCandidateScorer {
  /// Computes acoustic similarity scores [0.0, 1.0] for a list of candidates against the raw audio signal.
  ///
  /// Returns a map of candidate ID to acoustic score.
  Future<Map<String, double>> rescoreCandidates({
    required SpokenAudioContext audioContext,
    required List<EntityCandidate> candidates,
    SpokenWordTimestamp? mentionWindow,
  });
}

/// Default no-op acoustic candidate scorer for MVP.
class NoOpAcousticCandidateScorer implements IAcousticCandidateScorer {
  const NoOpAcousticCandidateScorer();

  @override
  Future<Map<String, double>> rescoreCandidates({
    required SpokenAudioContext audioContext,
    required List<EntityCandidate> candidates,
    SpokenWordTimestamp? mentionWindow,
  }) async {
    // No-op: returns empty map, preserving existing lexical/phonetic scoring in MVP
    return const {};
  }
}
