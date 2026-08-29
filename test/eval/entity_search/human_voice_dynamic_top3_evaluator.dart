import 'dart:io';

import 'package:ai_rally_search/models/speech/speech_transcription_context.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';

import 'human_voice_smoke_evaluator.dart';

class HumanVoiceDynamicTop3Evaluator {
  final HumanVoiceSmokeEvaluator pipeline;

  const HumanVoiceDynamicTop3Evaluator({required this.pipeline});

  Future<Map<String, Object?>> evaluate({
    required Map<String, dynamic> fixture,
    Map<String, dynamic>? frozenRawBaseline,
  }) async {
    final recordingId = fixture['recordingId'] as String;
    final audioFile = File(fixture['audioFile'] as String);
    final pass1 = await pipeline.evaluateRawWithContext(
      recordingId: recordingId,
      audioFile: audioFile,
      groundTruth: fixture,
      strategy: 'DYNAMIC_TOP3_PASS1_RAW',
      transcriptionContext: const SpeechTranscriptionContext(
        origin: TranscriptionOrigin.baseline,
        prompt: '',
        keywords: [],
        languageHints: ['en'],
      ),
    );

    final hints = _topCanonicalNames(pass1, limit: 3);
    final candidateTrigger = _triggerDecision(pass1);
    final protectedFrozenWinner =
        frozenRawBaseline?['canonicalOutcomeCorrect'] == true;
    final trigger = protectedFrozenWinner
        ? (
            fires: false,
            phoneticOnly: candidateTrigger.phoneticOnly,
            reason: 'FROZEN_BASELINE_SAFE_WINNER_PROTECTED',
          )
        : candidateTrigger;
    final secondPassTriggered = trigger.fires && hints.isNotEmpty;
    Map<String, Object?>? pass2;
    if (secondPassTriggered) {
      pass2 = await pipeline.evaluateRawWithContext(
        recordingId: recordingId,
        audioFile: audioFile,
        groundTruth: fixture,
        strategy: 'DYNAMIC_TOP3_PASS2_RAW',
        transcriptionContext: SpeechTranscriptionContext(
          origin: TranscriptionOrigin.dynamicBiased,
          prompt: 'Candidate spellings: ${hints.join(', ')}.',
          keywords: hints,
          languageHints: const ['en'],
        ),
      );
    }

    final finalEvaluation = pass2 == null
        ? Map<String, Object?>.from(pass1)
        : _applyCircularEvidenceGuard(pass1: pass1, pass2: pass2, hints: hints);
    final comparisonBaseline = frozenRawBaseline ?? pass1;
    final baselineOutcome = comparisonBaseline['finalOutcome'] as String;
    final finalOutcome = finalEvaluation['finalOutcome'] as String;
    final canonicalScorable =
        fixture['canonicalScorable'] == true ||
        fixture['canonicalEntityId'] != null;
    final delta = _outcomeDelta(
      baselineOutcome: baselineOutcome,
      finalOutcome: finalOutcome,
      canonicalScorable: canonicalScorable,
    );
    final pass1Latency = pass1['latencyMs'] as Map;
    final pass2Latency = pass2?['latencyMs'] as Map?;

    return {
      'recordingId': recordingId,
      'audioFile': audioFile.path,
      'referenceTranscriptRaw': fixture['referenceTranscriptRaw'],
      'referenceTranscriptNormalized': fixture['referenceTranscriptNormalized'],
      'canonicalScorable': canonicalScorable,
      'canonicalInterpretationAmbiguous':
          fixture['canonicalInterpretationAmbiguous'] == true,
      'expectedIntent': fixture['expectedIntents'],
      'expectedPersonRole': fixture['expectedPersonRole'],
      'expectedCanonicalEntityId': fixture['canonicalEntityId'],
      'expectedCanonicalEntityName': fixture['canonicalEntityName'],
      'pipeline': {
        'audioInput': 'original_unmodified_wav',
        'audioPreprocessor': 'NoOpAudioPreprocessor',
        'audioPreprocessingUsed': false,
        'staticDomainContextUsed': false,
        'dynamicCandidateCount': 3,
        'maximumSecondPasses': 1,
      },
      'triggerPolicy': {
        'fired': trigger.fires,
        'reason': trigger.reason,
        'topCandidatePhoneticOnly': trigger.phoneticOnly,
        'candidatePolicyWouldFire': candidateTrigger.fires,
        'candidatePolicyReason': candidateTrigger.reason,
        'protectedFrozenBaselineWinner': protectedFrozenWinner,
        'secondPassSkippedBecauseNoCandidateHints':
            trigger.fires && hints.isEmpty,
      },
      'secondPassTriggered': secondPassTriggered,
      'top3Hints': hints,
      'pass1': pass1,
      'pass2': pass2,
      'final': finalEvaluation,
      'comparisonToRaw': {
        'source': frozenRawBaseline == null
            ? 'CURRENT_UNBIASED_PASS1'
            : 'FROZEN_ACCEPTED_RAW_BASELINE',
        'baselineOutcome': baselineOutcome,
        'dynamicOutcome': finalOutcome,
        'delta': delta,
        'baselineCanonicalOutcomeCorrect':
            comparisonBaseline['canonicalOutcomeCorrect'],
        'dynamicCanonicalOutcomeCorrect':
            finalEvaluation['canonicalOutcomeCorrect'],
        'baselineWrongConfident': comparisonBaseline['wrongConfident'],
        'dynamicWrongConfident': finalEvaluation['wrongConfident'],
      },
      'comparisonToFrozenRaw': {
        'source': frozenRawBaseline == null
            ? 'CURRENT_UNBIASED_PASS1'
            : 'FROZEN_ACCEPTED_RAW_BASELINE',
        'baselineOutcome': baselineOutcome,
        'dynamicOutcome': finalOutcome,
        'delta': delta,
        'baselineCanonicalOutcomeCorrect':
            comparisonBaseline['canonicalOutcomeCorrect'],
        'dynamicCanonicalOutcomeCorrect':
            finalEvaluation['canonicalOutcomeCorrect'],
        'baselineWrongConfident': comparisonBaseline['wrongConfident'],
        'dynamicWrongConfident': finalEvaluation['wrongConfident'],
      },
      'latencyMs': {
        'rawBaselineStt': (comparisonBaseline['latencyMs'] as Map)['stt'],
        'rawBaselineTotal': (comparisonBaseline['latencyMs'] as Map)['total'],
        'frozenBaselineStt': (comparisonBaseline['latencyMs'] as Map)['stt'],
        'frozenBaselineTotal':
            (comparisonBaseline['latencyMs'] as Map)['total'],
        'dynamicPass1Stt': pass1Latency['stt'],
        'dynamicPass1Total': pass1Latency['total'],
        'dynamicSecondPassStt': pass2Latency?['stt'],
        'dynamicSecondPassTotal': pass2Latency?['total'],
        'dynamicTotal':
            (pass1Latency['total'] as num).toDouble() +
            ((pass2Latency?['total'] as num?)?.toDouble() ?? 0),
      },
      'sttCalls': secondPassTriggered ? 2 : 1,
    };
  }

  static ({bool fires, bool phoneticOnly, String reason}) _triggerDecision(
    Map<String, Object?> pass1,
  ) {
    final resolver = pass1['resolver'] as Map;
    final decision = resolver['decision'] as String;
    final topCandidate = _topCandidate(pass1);
    final matchedBy = (topCandidate?['matchedBy'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final phoneticOnly =
        topCandidate != null &&
        matchedBy.contains('phonetic') &&
        !matchedBy.contains('exact') &&
        !matchedBy.contains('normalized_exact') &&
        !matchedBy.contains('token');

    if (decision == 'resolved' && !phoneticOnly) {
      return (
        fires: false,
        phoneticOnly: false,
        reason: 'PASS1_SAFELY_RESOLVED',
      );
    }
    if (decision == 'clarification' && topCandidate != null) {
      final question = resolver['clarificationQuestion']?.toString() ?? '';
      final topName = topCandidate['canonicalName']?.toString() ?? '';
      if (_containsNormalized(question, topName)) {
        return (
          fires: false,
          phoneticOnly: phoneticOnly,
          reason: 'PASS1_SAFE_TOP1_CLARIFICATION',
        );
      }
      return (
        fires: true,
        phoneticOnly: phoneticOnly,
        reason: 'PASS1_CLARIFICATION_DISAGREES_WITH_ENTITY_SEARCH_TOP1',
      );
    }
    if (phoneticOnly) {
      return (
        fires: true,
        phoneticOnly: true,
        reason: 'PASS1_TOP_CANDIDATE_PHONETIC_ONLY',
      );
    }
    return (
      fires: true,
      phoneticOnly: false,
      reason: decision == 'no_match'
          ? 'PASS1_NO_MATCH'
          : 'PASS1_NOT_SAFELY_RESOLVED',
    );
  }

  static List<String> _topCanonicalNames(
    Map<String, Object?> evaluation, {
    required int limit,
  }) {
    final names = <String>[];
    final groups = evaluation['candidateGroups'] as List? ?? const [];
    for (final group in groups.whereType<Map>()) {
      final candidates = group['candidates'] as List? ?? const [];
      for (final candidate in candidates.whereType<Map>()) {
        final name = candidate['canonicalName']?.toString().trim() ?? '';
        if (name.isNotEmpty && !names.contains(name)) names.add(name);
        if (names.length == limit) return names;
      }
    }
    return names;
  }

  static Map? _topCandidate(Map<String, Object?> evaluation) {
    final groups = evaluation['candidateGroups'] as List? ?? const [];
    for (final group in groups.whereType<Map>()) {
      final candidates = group['candidates'] as List? ?? const [];
      if (candidates.isNotEmpty && candidates.first is Map) {
        return candidates.first as Map;
      }
    }
    return null;
  }

  static Map<String, Object?> _applyCircularEvidenceGuard({
    required Map<String, Object?> pass1,
    required Map<String, Object?> pass2,
    required List<String> hints,
  }) {
    final result = Map<String, Object?>.from(pass2);
    final resolver = Map<String, Object?>.from(pass2['resolver'] as Map);
    final resolvedNames =
        (resolver['finalCanonicalEntityNames'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false);
    final resolvedName = resolvedNames.isEmpty ? null : resolvedNames.first;
    final pass1Transcript =
        ((pass1['transcription'] as Map)['transcript'] as String?) ?? '';
    final pass2Transcript =
        ((pass2['transcription'] as Map)['transcript'] as String?) ?? '';
    final resolvedWasHinted =
        resolvedName != null &&
        hints.any((hint) => _sameNormalized(hint, resolvedName));
    final pass2ContainsExactHint =
        resolvedName != null &&
        _containsCanonicalSpelling(pass2Transcript, resolvedName);
    final pass1ContainedExactName =
        resolvedName != null &&
        _containsCanonicalSpelling(pass1Transcript, resolvedName);
    final confidentResolution = resolver['decision'] == 'resolved';
    final applyGuard =
        confidentResolution &&
        resolvedWasHinted &&
        pass2ContainsExactHint &&
        !pass1ContainedExactName;

    if (!applyGuard) {
      result['dynamicCircularEvidence'] = {
        'detected': false,
        'guardApplied': false,
        'resolvedWasHinted': resolvedWasHinted,
        'pass2ContainsExactHint': pass2ContainsExactHint,
        'pass1ContainedExactName': pass1ContainedExactName,
      };
      return result;
    }

    final correct = pass2['canonicalEntityCorrect'] == true;
    resolver['decision'] = 'clarification';
    resolver['requiresClarification'] = true;
    resolver['clarificationQuestion'] = 'Did you mean "$resolvedName"?';
    resolver['finalCanonicalEntityIds'] = const <String>[];
    resolver['finalCanonicalEntityNames'] = const <String>[];
    result['resolver'] = resolver;
    result['canonicalEntityCorrect'] = false;
    result['canonicalOutcomeCorrect'] = correct;
    result['correctConfident'] = false;
    result['wrongConfident'] = false;
    result['correctClarification'] = correct;
    result['wrongClarification'] = !correct;
    result['clarification'] = true;
    result['noMatch'] = false;
    result['finalOutcome'] = correct
        ? 'CORRECT_CLARIFICATION'
        : 'WRONG_CLARIFICATION';
    final semantics = Map<String, Object?>.from(
      result['querySemantics'] as Map,
    );
    semantics['finalSearchQuery'] = semantics['parsedSearchQuery'];
    result['querySemantics'] = semantics;
    result['voiceExactMatchEscalation'] = {
      'status': 'DYNAMIC_HINT_NOT_INDEPENDENT_CONFIRMATION',
      'occurred': false,
      'reason': 'A hinted exact spelling from pass 2 was downgraded to clarification because it is circular evidence.',
    };
    result['dynamicCircularEvidence'] = {
      'detected': true,
      'guardApplied': true,
      'resolvedWasHinted': true,
      'pass2ContainsExactHint': true,
      'pass1ContainedExactName': false,
      'hintedCanonicalName': resolvedName,
      'unguardedResolverDecision': 'resolved',
      'guardedResolverDecision': 'clarification',
    };
    return result;
  }

  static String _outcomeDelta({
    required String baselineOutcome,
    required String finalOutcome,
    required bool canonicalScorable,
  }) {
    if (!canonicalScorable) {
      return baselineOutcome == finalOutcome
          ? 'UNCHANGED'
          : 'UNSCORABLE_AMBIGUOUS';
    }
    final baselineScore = _outcomeScore(baselineOutcome);
    final finalScore = _outcomeScore(finalOutcome);
    if (finalScore > baselineScore) return 'IMPROVED';
    if (finalScore < baselineScore) return 'WORSENED';
    return 'UNCHANGED';
  }

  static int _outcomeScore(String outcome) => switch (outcome) {
    'CORRECT_CONFIDENT' => 4,
    'CORRECT_CLARIFICATION' => 3,
    'NO_MATCH' => 2,
    'WRONG_CLARIFICATION' => 1,
    'WRONG_CONFIDENT' => 0,
    _ => -1,
  };

  static bool _containsNormalized(String text, String value) {
    final normalizedText = PhoneticMatchingHelper.normalize(text);
    final normalizedValue = PhoneticMatchingHelper.normalize(value);
    return normalizedValue.isNotEmpty &&
        normalizedText.contains(normalizedValue);
  }

  static bool _containsCanonicalSpelling(String text, String value) {
    if (_containsNormalized(text, value)) return true;
    final strippedText = PhoneticMatchingHelper.stripDescriptors(text);
    final strippedValue = PhoneticMatchingHelper.stripDescriptors(value);
    return strippedValue.length >= 4 && strippedText.contains(strippedValue);
  }

  static bool _sameNormalized(String left, String right) =>
      PhoneticMatchingHelper.normalize(left) ==
      PhoneticMatchingHelper.normalize(right);
}
