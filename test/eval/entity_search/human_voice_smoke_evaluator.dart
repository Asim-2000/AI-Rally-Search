import 'dart:io';
import 'dart:math';

import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/speech/speech_transcription_context.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/services/entity_search/controlled_fallback_entity_resolver.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:ai_rally_search/services/speech/audio_preprocessor.dart';
import 'package:ai_rally_search/services/speech/speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/voice_entity_recovery_service.dart';

class HumanVoiceSmokeEvaluator {
  final ISpeechToTextService speech;
  final LlmQueryParser parser;
  final ControlledFallbackEntityResolver resolver;
  final InMemoryEntitySearchService entitySearch;
  final VoiceEntityRecoveryService recovery;

  const HumanVoiceSmokeEvaluator({
    required this.speech,
    required this.parser,
    required this.resolver,
    required this.entitySearch,
    this.recovery = const VoiceEntityRecoveryService(),
  });

  Future<Map<String, Object?>> evaluateRaw({
    required String recordingId,
    required File audioFile,
    required Map<String, dynamic> groundTruth,
  }) async => _evaluateBytes(
    recordingId: recordingId,
    audioFile: audioFile,
    audioBytes: await audioFile.readAsBytes(),
    transcriptionFilename: audioFile.uri.pathSegments.last,
    strategy: 'RAW',
    preprocessingLatency: Duration.zero,
    preprocessingDiagnostics: const {'implementation': 'no_op'},
    transcriptionContext: const SpeechTranscriptionContext(
      origin: TranscriptionOrigin.baseline,
      prompt: '',
      keywords: [],
      languageHints: ['en'],
    ),
    groundTruth: groundTruth,
  );

  Future<Map<String, Object?>> evaluateRawWithContext({
    required String recordingId,
    required File audioFile,
    required Map<String, dynamic> groundTruth,
    required SpeechTranscriptionContext transcriptionContext,
    required String strategy,
  }) async => _evaluateBytes(
    recordingId: recordingId,
    audioFile: audioFile,
    audioBytes: await audioFile.readAsBytes(),
    transcriptionFilename: audioFile.uri.pathSegments.last,
    strategy: strategy,
    preprocessingLatency: Duration.zero,
    preprocessingDiagnostics: const {'implementation': 'no_op'},
    transcriptionContext: transcriptionContext,
    groundTruth: groundTruth,
  );

  Future<Map<String, Object?>> evaluateProcessed({
    required String recordingId,
    required File originalAudioFile,
    required AudioPreprocessingResult processed,
    required Map<String, dynamic> groundTruth,
  }) async => _evaluateBytes(
    recordingId: recordingId,
    audioFile: originalAudioFile,
    audioBytes: processed.bytes,
    transcriptionFilename: processed.filename,
    strategy: processed.strategy.name,
    preprocessingLatency: processed.latency,
    preprocessingDiagnostics: processed.diagnostics,
    transcriptionContext: const SpeechTranscriptionContext(
      origin: TranscriptionOrigin.baseline,
      prompt: '',
      keywords: [],
      languageHints: ['en'],
    ),
    groundTruth: groundTruth,
  );

  Future<Map<String, Object?>> _evaluateBytes({
    required String recordingId,
    required File audioFile,
    required List<int> audioBytes,
    required String transcriptionFilename,
    required String strategy,
    required Duration preprocessingLatency,
    required Map<String, Object?> preprocessingDiagnostics,
    required SpeechTranscriptionContext transcriptionContext,
    required Map<String, dynamic> groundTruth,
  }) async {
    final totalWatch = Stopwatch()..start();

    final sttWatch = Stopwatch()..start();
    final transcription = await speech.transcribeAudioBytesDetailed(
      audioBytes,
      language: SupportedLanguages.english,
      filename: transcriptionFilename,
      context: transcriptionContext,
    );
    sttWatch.stop();
    final transcript = transcription?.text.trim() ?? '';
    final recovered = recovery.recover(transcript);

    final parseWatch = Stopwatch()..start();
    final parse = transcript.isEmpty
        ? null
        : await parser.parse(recovered.normalizedTranscript);
    parseWatch.stop();
    final query = parse?.query;
    final expectedCanonicalId = groundTruth['canonicalEntityId'] as String?;
    final acceptableResolutionIds = <Object?>[
      expectedCanonicalId,
      ...(groundTruth['equivalentResolverEntityIds'] as List? ?? const []),
    ].whereType<String>().toSet();
    final referenceTranscriptRaw =
        groundTruth['referenceTranscriptRaw'] as String?;
    final referenceTranscriptNormalized =
        groundTruth['referenceTranscriptNormalized'] as String? ??
        referenceTranscriptRaw;

    final searchWatch = Stopwatch()..start();
    final candidateGroups = query == null
        ? <Map<String, Object?>>[]
        : await _candidateGroups(query, expectedCanonicalId);
    searchWatch.stop();

    final resolverWatch = Stopwatch()..start();
    final resolution = query == null
        ? null
        : await resolver.resolveControlled(query, voice: true);
    resolverWatch.stop();
    totalWatch.stop();

    final resolved =
        resolution?.resolutions.values
            .where((item) => item.isResolved)
            .map((item) => item.resolvedCandidate!)
            .toList(growable: false) ??
        const <EntityCandidate>[];
    final resolvedById = <String, EntityCandidate>{
      for (final candidate in resolved) candidate.id: candidate,
    };
    final resolvedIds = resolvedById.keys.toList(growable: false);
    final resolverDecision = resolution == null
        ? 'no_match'
        : resolution.requiresClarification
        ? 'clarification'
        : resolved.isNotEmpty
        ? 'resolved'
        : 'no_match';
    final canonicalCorrect = expectedCanonicalId == null
        ? null
        : resolvedIds.any(acceptableResolutionIds.contains);
    final correctConfident = canonicalCorrect == null
        ? null
        : resolverDecision == 'resolved' && canonicalCorrect;
    final wrongConfident = canonicalCorrect == null
        ? null
        : resolverDecision == 'resolved' && !canonicalCorrect;
    final targetRanks = candidateGroups
        .map((group) => group['targetCandidateRank'])
        .whereType<int>()
        .toList(growable: false);
    final targetCandidateRank = targetRanks.isEmpty
        ? null
        : targetRanks.reduce(min);
    final mentions = query == null
        ? const <({String mention, SearchEntityType type})>[]
        : _mentions(query);
    final exactMatchEscalation = _voiceExactMatchEscalation(
      expectedCanonicalId: expectedCanonicalId,
      acceptableResolutionIds: acceptableResolutionIds,
      wrongConfident: wrongConfident,
      transcript: transcript,
      mentions: mentions.map((item) => item.mention),
      resolved: resolvedById.values,
    );
    final semanticMentions = query == null
        ? const <({String mention, String type})>[]
        : _semanticMentions(query);
    final expectedEntityMention = groundTruth['entityMention'] as String?;
    final entityMentionExact = expectedEntityMention == null
        ? null
        : semanticMentions.any(
            (item) =>
                PhoneticMatchingHelper.normalize(item.mention) ==
                PhoneticMatchingHelper.normalize(expectedEntityMention),
          );
    final expectedIntents =
        (groundTruth['expectedIntents'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false);
    final actualIntent = query?.intent.toIntentString();
    final intentCorrect = expectedIntents.isEmpty
        ? null
        : actualIntent != null && expectedIntents.contains(actualIntent);
    final expectedPersonRole = groundTruth['expectedPersonRole'] as String?;
    final actualPersonRole = query?.personRole.name.toUpperCase();
    final personRoleCorrect = expectedPersonRole == null
        ? null
        : actualPersonRole == expectedPersonRole;
    final expectedCanonicalName = groundTruth['canonicalEntityName'] as String?;
    final clarificationQuestion = resolution?.clarificationQuestion;
    final clarificationMatchesExpected =
        expectedCanonicalName != null && clarificationQuestion != null
        ? PhoneticMatchingHelper.normalize(clarificationQuestion)
              .contains(PhoneticMatchingHelper.normalize(expectedCanonicalName))
        : false;
    final correctClarification =
        expectedCanonicalId != null &&
        resolverDecision == 'clarification' &&
        clarificationMatchesExpected;
    final wrongClarification =
        expectedCanonicalId != null &&
        resolverDecision == 'clarification' &&
        !clarificationMatchesExpected;
    final finalOutcome = resolverDecision == 'resolved'
        ? canonicalCorrect == true
              ? 'CORRECT_CONFIDENT'
              : 'WRONG_CONFIDENT'
        : resolverDecision == 'clarification'
        ? correctClarification
              ? 'CORRECT_CLARIFICATION'
              : 'WRONG_CLARIFICATION'
        : 'NO_MATCH';
    final canonicalOutcomeCorrect = expectedCanonicalId == null
        ? null
        : canonicalCorrect == true || correctClarification;
    final finalQuery = resolution?.resolvedQuery ?? query;

    return {
      'recordingId': recordingId,
      'audioFile': audioFile.path,
      'transcriptionInputFilename': transcriptionFilename,
      'strategy': strategy,
      'realHumanAudio': true,
      'groundTruthStatus': groundTruth['groundTruthStatus'],
      'referenceTranscript': referenceTranscriptRaw,
      'referenceTranscriptRaw': referenceTranscriptRaw,
      'referenceTranscriptNormalized': referenceTranscriptNormalized,
      'referenceNormalizationNote': groundTruth['referenceNormalizationNote'],
      'expectedEntityMention': expectedEntityMention,
      'expectedCanonicalEntityId': expectedCanonicalId,
      'expectedCanonicalEntityName': expectedCanonicalName,
      'equivalentResolverEntityIds':
          groundTruth['equivalentResolverEntityIds'] ?? const <String>[],
      'expectedEntityType': groundTruth['entityType'],
      'expectedQuerySemantics': {
        'intents': expectedIntents,
        'personRole': expectedPersonRole,
        'description': groundTruth['expectedQuerySemantics'],
      },
      'transcription': {
        'origin': transcriptionContext.origin.name,
        'biasingUsed': transcriptionContext.hasBias,
        'prompt': transcriptionContext.prompt,
        'keywords': transcriptionContext.keywords,
        'transcript': transcript,
        'requestedLanguage': 'en',
        'detectedLanguage': null,
        'detectedLanguageAvailable': false,
        'confidence': transcription?.confidence,
        'confidenceAvailable': transcription?.confidence != null,
        'logprob': null,
        'logprobAvailable': false,
      },
      'normalizedTranscript': recovered.normalizedTranscript,
      'queryUnderstanding': query == null
          ? {
              'success': false,
              'error': parse?.error ?? 'No parseable transcript',
            }
          : {
              'success': true,
              'intent': query.intent.name,
              'rawEntityMentions': semanticMentions
                  .map(
                    (item) => {
                      'mention': item.mention,
                      'entityType': item.type,
                    },
                  )
                  .toList(growable: false),
              'query': query.toJson(),
              'provider': parse?.provider?.name,
              'model': parse?.model,
            },
      'candidateGroups': candidateGroups,
      'targetCandidateRank': targetCandidateRank,
      'entityMentionExact': entityMentionExact,
      'querySemantics': {
        'actualIntent': actualIntent,
        'intentCorrect': intentCorrect,
        'actualPersonRole': actualPersonRole,
        'personRoleCorrect': personRoleCorrect,
        'parsedSearchQuery': query?.toJson(),
        'finalSearchQuery': finalQuery?.toJson(),
        'semanticsCorrect': query == null
            ? false
            : (intentCorrect ?? true) &&
                  (personRoleCorrect ?? true) &&
                  (entityMentionExact ?? true),
      },
      'resolver': {
        'decision': resolverDecision,
        'requiresClarification': resolution?.requiresClarification ?? false,
        'clarificationQuestion': resolution?.clarificationQuestion,
        'resolutions':
            resolution?.resolutions.map(
              (key, value) => MapEntry(key, value.toJson()),
            ) ??
            const {},
        'finalCanonicalEntityIds': resolvedIds,
        'finalCanonicalEntityNames': resolvedById.values
            .map((candidate) => candidate.canonicalName)
            .toList(growable: false),
      },
      'canonicalEntityCorrect': canonicalCorrect,
      'canonicalOutcomeCorrect': canonicalOutcomeCorrect,
      'correctConfident': correctConfident,
      'correctClarification': correctClarification,
      'clarificationMatchesExpectedEntity': clarificationMatchesExpected,
      'clarification': resolverDecision == 'clarification',
      'noMatch': resolverDecision == 'no_match',
      'wrongConfident': wrongConfident,
      'wrongClarification': wrongClarification,
      'finalOutcome': finalOutcome,
      'wer': referenceTranscriptNormalized == null
          ? null
          : _wordErrorRate(referenceTranscriptNormalized, transcript),
      'cer': referenceTranscriptNormalized == null
          ? null
          : _characterErrorRate(referenceTranscriptNormalized, transcript),
      'preprocessingDiagnostics': preprocessingDiagnostics,
      'voiceExactMatchEscalation': exactMatchEscalation,
      'latencyMs': {
        'stt': sttWatch.elapsedMilliseconds,
        'queryUnderstanding': parseWatch.elapsedMilliseconds,
        'entitySearch': searchWatch.elapsedMilliseconds,
        'resolver': resolverWatch.elapsedMilliseconds,
        'preprocessing': preprocessingLatency.inMicroseconds / 1000,
        'total':
            totalWatch.elapsedMilliseconds +
            preprocessingLatency.inMicroseconds / 1000,
      },
    };
  }

  Future<List<Map<String, Object?>>> _candidateGroups(
    SearchQuery query,
    String? expectedCanonicalId,
  ) async {
    final groups = <Map<String, Object?>>[];
    for (final item in _mentions(query)) {
      final candidates = await entitySearch.search(
        EntitySearchRequest(
          rawMention: item.mention,
          entityType: item.type,
          limit: 10,
          year: query.years.firstOrNull,
          country: query.countries.firstOrNull,
          personRole: query.personRole,
        ),
      );
      groups.add({
        'rawMention': item.mention,
        'entityType': item.type.name,
        'targetCandidateRank': expectedCanonicalId == null
            ? null
            : _candidateRank(candidates, expectedCanonicalId),
        'candidates': candidates
            .map(
              (candidate) => {
                'rank': candidates.indexOf(candidate) + 1,
                'canonicalId': candidate.canonicalId,
                'canonicalName': candidate.canonicalName,
                'score': candidate.score,
                'componentScores': candidate.signals.toMap(),
                'matchedBy': candidate.matchedBy.toList()..sort(),
              },
            )
            .toList(growable: false),
      });
    }
    return groups;
  }

  static List<({String mention, SearchEntityType type})> _mentions(
    SearchQuery query,
  ) => [
    for (final mention in query.targetRallyNames)
      (mention: mention, type: SearchEntityType.rally),
    for (final mention in query.driverNames)
      (mention: mention, type: SearchEntityType.person),
    for (final mention in query.stageNames)
      (mention: mention, type: SearchEntityType.stage),
    for (final mention in query.uploaders)
      (mention: mention, type: SearchEntityType.uploader),
  ];

  static List<({String mention, String type})> _semanticMentions(
    SearchQuery query,
  ) => [
    for (final item in _mentions(query))
      (mention: item.mention, type: item.type.name),
    for (final city in query.cities) (mention: city, type: 'city'),
  ];

  static int? _candidateRank(
    List<EntitySearchCandidate> candidates,
    String expectedCanonicalId,
  ) {
    final index = candidates.indexWhere(
      (candidate) => candidate.canonicalId == expectedCanonicalId,
    );
    return index < 0 ? null : index + 1;
  }

  static Map<String, Object?> _voiceExactMatchEscalation({
    required String? expectedCanonicalId,
    required Set<String> acceptableResolutionIds,
    required bool? wrongConfident,
    required String transcript,
    required Iterable<String> mentions,
    required Iterable<EntityCandidate> resolved,
  }) {
    if (expectedCanonicalId == null) {
      return const {
        'status': 'NOT_ASSESSABLE_NO_CANONICAL_GROUND_TRUTH',
        'occurred': null,
        'reason': 'The fixture has no expected canonical entity ID.',
      };
    }
    if (wrongConfident != true) {
      return const {
        'status': 'ASSESSED',
        'occurred': false,
        'reason': 'No wrong confident canonical resolution occurred.',
      };
    }
    final normalizedTranscript = PhoneticMatchingHelper.normalize(transcript);
    final normalizedMentions = mentions
        .map(PhoneticMatchingHelper.normalize)
        .toSet();
    for (final candidate in resolved) {
      if (acceptableResolutionIds.contains(candidate.id)) continue;
      final normalizedName = PhoneticMatchingHelper.normalize(
        candidate.canonicalName,
      );
      final exactInStt =
          normalizedMentions.contains(normalizedName) ||
          normalizedTranscript == normalizedName ||
          normalizedTranscript.contains(' $normalizedName ') ||
          normalizedTranscript.startsWith('$normalizedName ') ||
          normalizedTranscript.endsWith(' $normalizedName');
      if (exactInStt) {
        return {
          'status': 'ASSESSED',
          'occurred': true,
          'differentCanonicalEntityId': candidate.id,
          'differentCanonicalEntityName': candidate.canonicalName,
          'reason': 'Unbiased STT/query understanding supplied the exact name of a different canonical entity and the resolver auto-resolved it.',
        };
      }
    }
    return const {
      'status': 'ASSESSED',
      'occurred': false,
      'reason': 'A wrong confident resolution occurred without an exact different-entity name in the STT/query mention.',
    };
  }

  static double _wordErrorRate(String reference, String hypothesis) {
    final referenceTokens = PhoneticMatchingHelper.normalize(reference)
        .split(' ');
    final hypothesisTokens = PhoneticMatchingHelper.normalize(hypothesis)
        .split(' ');
    return _editRate(referenceTokens, hypothesisTokens);
  }

  static double _characterErrorRate(String reference, String hypothesis) {
    final normalizedReference = PhoneticMatchingHelper.normalize(reference);
    final normalizedHypothesis = PhoneticMatchingHelper.normalize(hypothesis);
    return _editRate(
      normalizedReference.runes.toList(),
      normalizedHypothesis.runes.toList(),
    );
  }

  static double _editRate<T>(List<T> reference, List<T> hypothesis) {
    if (reference.isEmpty) return hypothesis.isEmpty ? 0 : 1;
    var previous = List<int>.generate(hypothesis.length + 1, (index) => index);
    for (var row = 1; row <= reference.length; row++) {
      final current = List<int>.filled(hypothesis.length + 1, 0)..[0] = row;
      for (var column = 1; column <= hypothesis.length; column++) {
        final substitution =
            previous[column - 1] +
            (reference[row - 1] == hypothesis[column - 1] ? 0 : 1);
        current[column] = min(
          min(previous[column] + 1, current[column - 1] + 1),
          substitution,
        );
      }
      previous = current;
    }
    return previous.last / reference.length;
  }
}
