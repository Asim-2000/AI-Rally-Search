import 'dart:math';
import '../../../models/entity_candidate.dart';
import '../../../models/search_query.dart';
import '../../../models/speech/speech_transcription_result.dart';
import '../llm_query_parser.dart';
import 'acoustic/acoustic_candidate_scorer.dart';
import 'database_entity_resolver.dart';
import 'entity_lookup_repository.dart';
import 'entity_resolver.dart';
import 'phonetic_matching_helper.dart';
import 'pronunciation/algorithmic_pronunciation_encoder.dart';
import 'pronunciation/entity_pronunciation_metadata.dart';
import 'pronunciation/phonetic_entity_index.dart';
import 'pronunciation/pronunciation_encoder.dart';

/// Spoken Entity Resolver orchestrating multi-modal spoken entity resolution.
///
/// Implements a safe, calibrated fallback cascade:
/// 1. Primary lexical resolver is evaluated first. If confident winner exists,
///    it resolves immediately (0 overhead).
/// 2. If lexical resolution is ambiguous, below threshold, or returns no candidates,
///    it invokes phonetic candidate retrieval and rescoring.
/// 3. Phonetic fallback operates under a CLARIFICATION-ONLY policy: it surfaces
///    "Did you mean?" suggestions to the user, preventing unconfirmed auto-execution.
class SpokenEntityResolver implements EntityResolver {
  final DatabaseEntityResolver _baseResolver;
  final IEntityLookupRepository _repository;
  final IPronunciationEncoder _pronunciationEncoder;
  final IPhoneticEntityIndex? _phoneticIndex;
  final IAcousticCandidateScorer _acousticScorer;

  SpokenEntityResolver({
    required IEntityLookupRepository repository,
    DatabaseEntityResolver? baseResolver,
    IPronunciationEncoder? pronunciationEncoder,
    IPhoneticEntityIndex? phoneticIndex,
    IAcousticCandidateScorer? acousticScorer,
    double minConfidenceThreshold = 0.75,
    double minScoreGap = 0.15,
  })  : _repository = repository,
        _baseResolver = baseResolver ??
            DatabaseEntityResolver(
              repository: repository,
              minConfidenceThreshold: minConfidenceThreshold,
              minScoreGap: minScoreGap,
            ),
        _pronunciationEncoder = pronunciationEncoder ?? AlgorithmicPronunciationEncoder(),
        _phoneticIndex = phoneticIndex,
        _acousticScorer = acousticScorer ?? const NoOpAcousticCandidateScorer();

  /// Access to underlying lookup repository.
  IEntityLookupRepository get repository => _repository;

  /// Access to pronunciation encoder.
  IPronunciationEncoder get pronunciationEncoder => _pronunciationEncoder;

  /// Access to phonetic entity index.
  IPhoneticEntityIndex? get phoneticIndex => _phoneticIndex;

  /// Access to acoustic candidate scorer.
  IAcousticCandidateScorer get acousticScorer => _acousticScorer;

  /// Typed search resolution path: delegates directly to [DatabaseEntityResolver]
  /// with zero semantic branching or threshold changes.
  @override
  Future<EntityResolutionResult> resolve(
    SearchQuery query, {
    SearchContext? context,
  }) {
    return _baseResolver.resolve(query, context: context);
  }

  /// Voice search resolution path: orchestrates multi-modal resolution over
  /// the primary parsed query, optional N-best STT hypotheses, and phonetic fallback.
  Future<EntityResolutionResult> resolveSpoken({
    required SearchQuery parsedQuery,
    required SpeechTranscriptionResult speechResult,
    SearchContext? context,
  }) async {
    // 1. Primary candidate resolution via standard lexical resolver
    final primaryResult = await resolve(parsedQuery, context: context);

    // If primary query resolved cleanly (confident match), return primary result immediately
    if (primaryResult.isSuccess && !primaryResult.requiresClarification && primaryResult.error == null) {
      return primaryResult;
    }

    // 2. If lexical resolver failed, had no candidate, or required clarification,
    // invoke Phonetic Fallback (Clarification-Only).
    if (_phoneticIndex != null) {
      final phoneticClarification = await _attemptPhoneticFallback(
        parsedQuery: parsedQuery,
        speechResult: speechResult,
        primaryResult: primaryResult,
      );
      if (phoneticClarification != null) {
        return phoneticClarification;
      }
    }

    return primaryResult;
  }

  /// Executes phonetic fallback candidate retrieval and surfaces interactive clarification chips.
  Future<EntityResolutionResult?> _attemptPhoneticFallback({
    required SearchQuery parsedQuery,
    required SpeechTranscriptionResult speechResult,
    required EntityResolutionResult primaryResult,
  }) async {
    final index = _phoneticIndex;
    if (index == null) return null;

    // Search query slots in order of priority: Rallies -> Drivers -> Stages
    for (final rallyName in parsedQuery.rallyNames) {
      if (rallyName.trim().isEmpty) continue;
      final candidates = await index.searchRallies(rallyName.trim(), limit: 10);
      if (candidates.isNotEmpty) {
        return _buildPhoneticClarification(
          parsedQuery: parsedQuery,
          candidates: candidates,
          entityType: EntityType.rally,
        );
      }
    }

    for (final driverName in parsedQuery.driverNames) {
      if (driverName.trim().isEmpty) continue;
      final candidates = await index.searchPersons(driverName.trim(), limit: 10);
      if (candidates.isNotEmpty) {
        return _buildPhoneticClarification(
          parsedQuery: parsedQuery,
          candidates: candidates,
          entityType: EntityType.driver,
        );
      }
    }

    for (final stageName in parsedQuery.stageNames) {
      if (stageName.trim().isEmpty) continue;
      final candidates = await index.searchStages(stageName.trim(), limit: 10);
      if (candidates.isNotEmpty) {
        return _buildPhoneticClarification(
          parsedQuery: parsedQuery,
          candidates: candidates,
          entityType: EntityType.stage,
        );
      }
    }

    // Fallback on full transcription text if slots were empty
    final fullText = speechResult.text.trim();
    if (fullText.isNotEmpty) {
      final candidates = await index.retrieveCandidates(fullText, limit: 10);
      if (candidates.isNotEmpty) {
        return _buildPhoneticClarification(
          parsedQuery: parsedQuery,
          candidates: candidates,
          entityType: candidates.first.type,
        );
      }
    }

    return null;
  }

  EntityResolutionResult _buildPhoneticClarification({
    required SearchQuery parsedQuery,
    required List<EntityCandidate> candidates,
    required EntityType entityType,
  }) {
    final topCandidate = candidates.first;
    final question = 'Did you mean "${topCandidate.canonicalName}"?';

    return EntityResolutionResult.clarification(
      parsedQuery: parsedQuery,
      clarificationQuestion: question,
      candidates: candidates.take(5).toList(),
      resolutions: {
        entityType.name: EntityResolution(
          type: entityType,
          rawPhrase: topCandidate.canonicalName,
          confidence: 0.65,
          strategy: 'phonetic_fallback_clarification',
          isAmbiguous: true,
          candidateOptions: candidates.take(5).toList(),
        ),
      },
    );
  }
}
