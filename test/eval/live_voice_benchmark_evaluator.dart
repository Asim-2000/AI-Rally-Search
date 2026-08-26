import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/speech/speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/voice_entity_recovery_service.dart';
import 'audio_asset_resolver.dart';
import 'manifest/benchmark_manifest.dart';
import 'manifest/human_benchmark_models.dart';
import 'voice_benchmark_models.dart';

/// 12-Class failure taxonomy for voice search evaluation.
enum FailureAttribution {
  none,
  sttLanguage,
  sttWordError,
  sttEntityError,
  sttNumberError,
  preLlmRecovery,
  llmIntent,
  llmFilter,
  entityRetrieval,
  entityScoring,
  ambiguityPolicy,
  database,
  other;

  String get label {
    switch (this) {
      case FailureAttribution.none:
        return 'NONE';
      case FailureAttribution.sttLanguage:
        return 'STT_LANGUAGE';
      case FailureAttribution.sttWordError:
        return 'STT_WORD_ERROR';
      case FailureAttribution.sttEntityError:
        return 'STT_ENTITY_ERROR';
      case FailureAttribution.sttNumberError:
        return 'STT_NUMBER_ERROR';
      case FailureAttribution.preLlmRecovery:
        return 'PRE_LLM_RECOVERY';
      case FailureAttribution.llmIntent:
        return 'LLM_INTENT';
      case FailureAttribution.llmFilter:
        return 'LLM_FILTER';
      case FailureAttribution.entityRetrieval:
        return 'ENTITY_RETRIEVAL';
      case FailureAttribution.entityScoring:
        return 'ENTITY_SCORING';
      case FailureAttribution.ambiguityPolicy:
        return 'AMBIGUITY_POLICY';
      case FailureAttribution.database:
        return 'DATABASE';
      case FailureAttribution.other:
        return 'OTHER';
    }
  }

  String get description {
    switch (this) {
      case FailureAttribution.none:
        return 'No error; query executed with semantic success.';
      case FailureAttribution.sttLanguage:
        return 'STT provider rejected or failed to transcribe audio due to language support.';
      case FailureAttribution.sttWordError:
        return 'Heavy transcription word errors degraded query understanding.';
      case FailureAttribution.sttEntityError:
        return 'Entity name corrupted by STT beyond phonetic or fuzzy recovery.';
      case FailureAttribution.sttNumberError:
        return 'Year or stage number omitted or misrecognized in speech transcription.';
      case FailureAttribution.preLlmRecovery:
        return 'Pre-LLM voice recovery failed to map recognizable domain token.';
      case FailureAttribution.llmIntent:
        return 'LLM parsed an incorrect intent for the spoken query.';
      case FailureAttribution.llmFilter:
        return 'LLM omitted or hallucinated filter parameters.';
      case FailureAttribution.entityRetrieval:
        return 'Database entity candidate lookup failed to retrieve true match.';
      case FailureAttribution.entityScoring:
        return 'Entity resolver scored wrong candidate higher than true candidate.';
      case FailureAttribution.ambiguityPolicy:
        return 'System triggered unnecessary interactive clarification on clear query.';
      case FailureAttribution.database:
        return 'Deterministic SearchRepository / MySQL execution failed or returned an unexpected result.';
      case FailureAttribution.other:
        return 'Unexpected exception, network failure, missing audio asset, or timeout.';
    }
  }
}

/// Granular entity resolution outcome for every entity-matching attempt.
enum EntityResolutionOutcome {
  autoResolvedCorrect,
  autoResolvedIncorrect,
  clarificationRequiredCorrectly,
  unnecessaryClarification,
  noMatch;

  String get label {
    switch (this) {
      case EntityResolutionOutcome.autoResolvedCorrect:
        return 'AUTO_RESOLVED_CORRECT';
      case EntityResolutionOutcome.autoResolvedIncorrect:
        return 'AUTO_RESOLVED_INCORRECT'; // CRITICAL FALSE POSITIVE
      case EntityResolutionOutcome.clarificationRequiredCorrectly:
        return 'CLARIFICATION_REQUIRED_CORRECTLY';
      case EntityResolutionOutcome.unnecessaryClarification:
        return 'UNNECESSARY_CLARIFICATION';
      case EntityResolutionOutcome.noMatch:
        return 'NO_MATCH';
    }
  }
}

/// Detailed result of evaluating a live audio benchmark sample.
class LiveVoiceEvaluationSampleResult {
  final BenchmarkManifestEntry entry;
  final String actualTranscript;
  final String normalizedTranscript;
  final VoiceEntityRecoveryResult? recoveryResult;

  final double wer;
  final double eer;
  final bool rawDriverPreserved;
  final bool rawRallyPreserved;
  final bool rawStagePreserved;
  final bool rawActionPreserved;

  final bool recoveredDriverPreserved;
  final bool recoveredRallyPreserved;
  final bool recoveredStagePreserved;
  final bool recoveredActionPreserved;

  final bool intentMatched;
  final double filterPrecision;
  final double filterRecall;
  final double filterF1;
  final bool exactSemanticMatch;

  final bool rawSemanticSuccess;
  final bool postRecoverySemanticSuccess;
  final bool searchSemanticSuccess;

  final EntityResolutionOutcome entityResolutionOutcome;
  final bool entityResolutionSucceeded;
  final bool dbExecutionSucceeded;
  final int returnedRowCount;

  final FailureAttribution failureAttribution;

  final int sttLatencyMs;
  final int llmParseLatencyMs;
  final int entityResolutionLatencyMs;
  final int dbLatencyMs;
  final int totalLatencyMs;

  final SearchQuery? parsedQuery;
  final SearchQuery? resolvedQuery;
  final String? errorMessage;
  final bool audioMissing;

  const LiveVoiceEvaluationSampleResult({
    required this.entry,
    required this.actualTranscript,
    required this.normalizedTranscript,
    this.recoveryResult,
    required this.wer,
    required this.eer,
    required this.rawDriverPreserved,
    required this.rawRallyPreserved,
    required this.rawStagePreserved,
    required this.rawActionPreserved,
    required this.recoveredDriverPreserved,
    required this.recoveredRallyPreserved,
    required this.recoveredStagePreserved,
    required this.recoveredActionPreserved,
    required this.intentMatched,
    required this.filterPrecision,
    required this.filterRecall,
    required this.filterF1,
    required this.exactSemanticMatch,
    required this.rawSemanticSuccess,
    required this.postRecoverySemanticSuccess,
    required this.searchSemanticSuccess,
    required this.entityResolutionOutcome,
    required this.entityResolutionSucceeded,
    required this.dbExecutionSucceeded,
    required this.returnedRowCount,
    required this.failureAttribution,
    required this.sttLatencyMs,
    required this.llmParseLatencyMs,
    required this.entityResolutionLatencyMs,
    required this.dbLatencyMs,
    required this.totalLatencyMs,
    this.parsedQuery,
    this.resolvedQuery,
    this.errorMessage,
    this.audioMissing = false,
  });

  Map<String, dynamic> toJson() => {
        'id': entry.id,
        'benchmark_type': entry.benchmarkType.name,
        'audio_file': entry.audioFile,
        'language': entry.language.languageCode,
        'locale': entry.locale,
        'expected_transcript': entry.expectedTranscript,
        'actual_transcript': actualTranscript,
        'normalized_transcript': normalizedTranscript,
        'recovery_mappings': recoveryResult?.entityRecoveryMappings ?? {},
        'wer': wer,
        'eer': eer,
        'raw_driver_preserved': rawDriverPreserved,
        'raw_rally_preserved': rawRallyPreserved,
        'raw_stage_preserved': rawStagePreserved,
        'raw_action_preserved': rawActionPreserved,
        'recovered_driver_preserved': recoveredDriverPreserved,
        'recovered_rally_preserved': recoveredRallyPreserved,
        'recovered_stage_preserved': recoveredStagePreserved,
        'recovered_action_preserved': recoveredActionPreserved,
        'intent_matched': intentMatched,
        'filter_precision': filterPrecision,
        'filter_recall': filterRecall,
        'filter_f1': filterF1,
        'exact_semantic_match': exactSemanticMatch,
        'raw_semantic_success': rawSemanticSuccess,
        'post_recovery_semantic_success': postRecoverySemanticSuccess,
        'search_semantic_success': searchSemanticSuccess,
        'entity_resolution_outcome': entityResolutionOutcome.label,
        'entity_resolution_succeeded': entityResolutionSucceeded,
        'db_execution_succeeded': dbExecutionSucceeded,
        'returned_row_count': returnedRowCount,
        'failure_attribution': failureAttribution.label,
        'stt_latency_ms': sttLatencyMs,
        'llm_parse_latency_ms': llmParseLatencyMs,
        'entity_resolution_latency_ms': entityResolutionLatencyMs,
        'db_latency_ms': dbLatencyMs,
        'total_latency_ms': totalLatencyMs,
        'expected_query': entry.expectedQuery.toMap(),
        'parsed_query': parsedQuery?.toMap(),
        'resolved_query': resolvedQuery?.toMap(),
        'error_message': errorMessage,
        'audio_missing': audioMissing,
      };
}

/// Live Voice Benchmark Evaluator supporting both synthetic regression benchmarks
/// and human validation benchmarks with pluggable asset resolution.
class LiveVoiceBenchmarkEvaluator {
  final ISpeechToTextService speechService;
  final NaturalLanguageSearchService nlSearchService;
  final VoiceEntityRecoveryService voiceRecoveryService;
  final AudioAssetResolver? assetResolver;

  LiveVoiceBenchmarkEvaluator({
    required this.speechService,
    required this.nlSearchService,
    VoiceEntityRecoveryService? voiceRecoveryService,
    this.assetResolver,
  }) : voiceRecoveryService = voiceRecoveryService ?? const VoiceEntityRecoveryService();

  Future<List<LiveVoiceEvaluationSampleResult>> evaluateManifest(
    List<BenchmarkManifestEntry> entries, {
    void Function(LiveVoiceEvaluationSampleResult sample, int index, int total)? onProgress,
  }) async {
    final results = <LiveVoiceEvaluationSampleResult>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final sampleResult = await evaluateSample(entry);
      results.add(sampleResult);
      onProgress?.call(sampleResult, i + 1, entries.length);
    }

    return results;
  }

  Future<LiveVoiceEvaluationSampleResult> evaluateSample(
    BenchmarkManifestEntry entry,
  ) async {
    final totalStopwatch = Stopwatch()..start();
    final sttStopwatch = Stopwatch();

    String actualTranscript = '';
    String? errorMessage;
    bool isSttLanguageError = false;
    bool isAudioMissing = false;

    // 1. Resolve Audio File (via Asset Resolver or physical file path)
    File? audioFile;
    try {
      if (assetResolver != null) {
        audioFile = await assetResolver!.resolveAudioFile(entry.audioFile);
      } else {
        final directFile = File(entry.audioFile);
        if (directFile.existsSync()) {
          audioFile = directFile;
        } else {
          // Fallback search in test/eval/audio/human and test/eval/audio/synthetic
          for (final candidateDir in [
            'test/eval/audio/human',
            'test/eval/audio/synthetic',
            'test/eval/audio',
          ]) {
            for (final ext in ['wav', 'm4a', 'mp3']) {
              final f = File('$candidateDir/${entry.audioFile}.$ext');
              if (f.existsSync()) {
                audioFile = f;
                break;
              }
              final directF = File('$candidateDir/${entry.audioFile}');
              if (directF.existsSync()) {
                audioFile = directF;
                break;
              }
            }
            if (audioFile != null) break;
          }
        }
      }

      if (audioFile == null || !audioFile.existsSync()) {
        isAudioMissing = true;
        errorMessage = 'Audio asset not found: "${entry.audioFile}"';
      }
    } catch (e) {
      isAudioMissing = true;
      errorMessage = 'Asset resolution error: $e';
    }

    // 2. STT Transcription
    if (!isAudioMissing && audioFile != null) {
      try {
        sttStopwatch.start();
        final sttResult = await speechService.transcribeAudioFile(
          audioFile,
          language: entry.language,
        );
        sttStopwatch.stop();

        actualTranscript = sttResult?.trim() ?? '';
        if (actualTranscript.isEmpty) {
          errorMessage = 'STT returned empty transcript';
        }
      } catch (e) {
        sttStopwatch.stop();
        final errStr = e.toString();
        if (errStr.contains('unsupported_language') ||
            (errStr.contains('Language') && errStr.contains('not supported'))) {
          isSttLanguageError = true;
        }
        errorMessage = 'STT Error: $e';
      }
    }

    // 3. Pre-LLM Voice Recovery
    final recovery = voiceRecoveryService.recover(
      actualTranscript,
      languageCode: entry.language.languageCode,
    );
    final normalizedTranscript = recovery.normalizedTranscript;

    // 4. Acoustic & Entity Metrics
    final wer = (entry.expectedTranscript.isNotEmpty && actualTranscript.isNotEmpty)
        ? VoiceMetricsCalculator.calculateWer(entry.expectedTranscript, actualTranscript)
        : (actualTranscript.isEmpty && !isAudioMissing ? 1.0 : 0.0);

    final allExpectedEntities = [
      ...entry.expectedEntities,
      ...entry.expectedDrivers,
      ...entry.expectedRallies,
      ...entry.expectedStages,
      ...entry.expectedActions,
    ];

    final eer = VoiceMetricsCalculator.calculateEntityErrorRate(
      expectedEntities: allExpectedEntities,
      hypothesis: actualTranscript,
    );

    final rawDriverPreserved = entry.expectedDrivers.isEmpty ||
        entry.expectedDrivers.any((d) => VoiceMetricsCalculator.isEntityPreserved(d, actualTranscript));
    final rawRallyPreserved = entry.expectedRallies.isEmpty ||
        entry.expectedRallies.any((r) => VoiceMetricsCalculator.isEntityPreserved(r, actualTranscript));
    final rawStagePreserved = entry.expectedStages.isEmpty ||
        entry.expectedStages.any((s) => VoiceMetricsCalculator.isEntityPreserved(s, actualTranscript));
    final rawActionPreserved = entry.expectedActions.isEmpty ||
        entry.expectedActions.any((a) => VoiceMetricsCalculator.isEntityPreserved(a, actualTranscript));

    final recDriverPreserved = entry.expectedDrivers.isEmpty ||
        entry.expectedDrivers.any((d) => VoiceMetricsCalculator.isEntityPreserved(d, normalizedTranscript));
    final recRallyPreserved = entry.expectedRallies.isEmpty ||
        entry.expectedRallies.any((r) => VoiceMetricsCalculator.isEntityPreserved(r, normalizedTranscript));
    final recStagePreserved = entry.expectedStages.isEmpty ||
        entry.expectedStages.any((s) => VoiceMetricsCalculator.isEntityPreserved(s, normalizedTranscript));
    final recActionPreserved = entry.expectedActions.isEmpty ||
        entry.expectedActions.any((a) => VoiceMetricsCalculator.isEntityPreserved(a, normalizedTranscript));

    // 5. NLP Query Parsing & Entity Resolution
    SearchQuery? parsedQuery;
    SearchQuery? resolvedQuery;
    bool intentMatched = false;
    double filterPrecision = 0.0;
    double filterRecall = 0.0;
    double filterF1 = 0.0;
    bool exactSemanticMatch = false;

    bool rawSemanticSuccess = false;
    bool postRecoverySemanticSuccess = false;
    bool searchSemanticSuccess = false;

    EntityResolutionOutcome resolutionOutcome = EntityResolutionOutcome.noMatch;
    bool entityResolutionSucceeded = false;
    bool dbExecutionSucceeded = false;
    int returnedRowCount = 0;
    bool unnecessaryClarification = false;

    int parseLatencyMs = 0;
    int entityResolutionLatencyMs = 0;
    int dbLatencyMs = 0;

    if (actualTranscript.isNotEmpty) {
      try {
        final searchContext = SearchContext(
          currentYear: DateTime.now().year,
          locale: entry.locale,
          languageCode: entry.language.languageCode,
        );

        final nlResult = await nlSearchService.search(
          actualTranscript,
          context: searchContext,
        );

        parseLatencyMs = nlResult.parseLatencyMs;
        entityResolutionLatencyMs = nlResult.entityResolutionLatencyMs;
        dbLatencyMs = nlResult.dbLatencyMs;

        parsedQuery = nlResult.parsedQuery ?? nlResult.query;
        resolvedQuery = nlResult.resolvedQuery ?? parsedQuery;

        if (nlResult.requiresClarification) {
          unnecessaryClarification = true;
        }

        if (parsedQuery != null) {
          intentMatched = parsedQuery.intent == entry.expectedIntent;

          final fScore = _calculateFilterScores(entry.expectedFilters, parsedQuery);
          filterPrecision = fScore.precision;
          filterRecall = fScore.recall;
          filterF1 = fScore.f1;
          exactSemanticMatch = intentMatched && (filterF1 >= 0.99);
        }

        entityResolutionSucceeded = !nlResult.requiresClarification && (nlResult.error == null);
        dbExecutionSucceeded = nlResult.searchResponse != null;
        returnedRowCount = nlResult.totalCount;

        // Evaluate Entity Resolution Outcomes (Classifying False Positives vs Correct Auto-Resolution)
        final hasExpectedEntities = entry.expectedDrivers.isNotEmpty || entry.expectedRallies.isNotEmpty;
        if (hasExpectedEntities) {
          if (nlResult.requiresClarification) {
            resolutionOutcome = EntityResolutionOutcome.unnecessaryClarification;
          } else if (resolvedQuery != null) {
            final driverMatched = entry.expectedDrivers.isEmpty ||
                (resolvedQuery.driverName != null &&
                    entry.expectedDrivers.any((d) =>
                        resolvedQuery!.driverName!.toLowerCase().contains(d.toLowerCase()) ||
                        d.toLowerCase().contains(resolvedQuery!.driverName!.toLowerCase())));

            final rallyMatched = entry.expectedRallies.isEmpty ||
                (resolvedQuery.rallyName != null &&
                    entry.expectedRallies.any((r) =>
                        resolvedQuery!.rallyName!.toLowerCase().contains(r.toLowerCase()) ||
                        r.toLowerCase().contains(resolvedQuery!.rallyName!.toLowerCase())));

            if (driverMatched && rallyMatched) {
              resolutionOutcome = EntityResolutionOutcome.autoResolvedCorrect;
            } else if ((resolvedQuery.driverName != null && !driverMatched) ||
                (resolvedQuery.rallyName != null && !rallyMatched)) {
              // Confidently resolved to the WRONG entity (Critical False Positive)
              resolutionOutcome = EntityResolutionOutcome.autoResolvedIncorrect;
            } else {
              resolutionOutcome = EntityResolutionOutcome.noMatch;
            }
          }
        } else {
          resolutionOutcome = EntityResolutionOutcome.autoResolvedCorrect;
        }

        // Semantic Success: Correct Intent + Key Filters match + DB Success + NO False-Positive Entity Resolution
        if (resolvedQuery != null && dbExecutionSucceeded && resolutionOutcome != EntityResolutionOutcome.autoResolvedIncorrect) {
          final intentOk = resolvedQuery.intent == entry.expectedIntent;
          final driverOk = entry.expectedFilters['driverName'] == null ||
              (resolvedQuery.driverName != null &&
                  entry.expectedDrivers.any((d) => resolvedQuery!.driverName!.toLowerCase().contains(d.toLowerCase())));
          final countryOk = entry.expectedFilters['country'] == null ||
              (resolvedQuery.country?.toLowerCase() == entry.expectedFilters['country'].toString().toLowerCase());
          final actionOk = entry.expectedFilters['actionType'] == null ||
              (resolvedQuery.actionType?.toLowerCase() == entry.expectedFilters['actionType'].toString().toLowerCase());

          searchSemanticSuccess = intentOk && driverOk && countryOk && actionOk;
          postRecoverySemanticSuccess = searchSemanticSuccess;
          rawSemanticSuccess = searchSemanticSuccess && (recovery.entityRecoveryMappings.isEmpty);
        }
      } catch (e) {
        errorMessage = (errorMessage != null ? '$errorMessage | ' : '') + 'NL Pipeline Error: $e';
      }
    }

    // 6. 12-Class Failure Attribution
    FailureAttribution attribution = FailureAttribution.none;
    if (isAudioMissing) {
      attribution = FailureAttribution.other;
    } else if (!searchSemanticSuccess) {
      if (actualTranscript.isEmpty) {
        attribution = isSttLanguageError ? FailureAttribution.sttLanguage : FailureAttribution.sttWordError;
      } else if (resolutionOutcome == EntityResolutionOutcome.autoResolvedIncorrect) {
        attribution = FailureAttribution.entityScoring;
      } else if (unnecessaryClarification) {
        attribution = FailureAttribution.ambiguityPolicy;
      } else if (!intentMatched) {
        attribution = FailureAttribution.llmIntent;
      } else if (filterF1 < 0.5) {
        if (!rawDriverPreserved && !rawRallyPreserved && !rawActionPreserved) {
          attribution = FailureAttribution.sttEntityError;
        } else if (entry.expectedFilters.containsKey('year') && (parsedQuery?.year == null || parsedQuery?.year != entry.expectedFilters['year'])) {
          attribution = FailureAttribution.sttNumberError;
        } else {
          attribution = FailureAttribution.llmFilter;
        }
      } else if (!entityResolutionSucceeded) {
        attribution = FailureAttribution.entityRetrieval;
      } else if (!dbExecutionSucceeded) {
        attribution = FailureAttribution.database;
      } else {
        attribution = FailureAttribution.llmFilter;
      }
    }

    totalStopwatch.stop();

    return LiveVoiceEvaluationSampleResult(
      entry: entry,
      actualTranscript: actualTranscript,
      normalizedTranscript: normalizedTranscript,
      recoveryResult: recovery,
      wer: wer,
      eer: eer,
      rawDriverPreserved: rawDriverPreserved,
      rawRallyPreserved: rawRallyPreserved,
      rawStagePreserved: rawStagePreserved,
      rawActionPreserved: rawActionPreserved,
      recoveredDriverPreserved: recDriverPreserved,
      recoveredRallyPreserved: recRallyPreserved,
      recoveredStagePreserved: recStagePreserved,
      recoveredActionPreserved: recActionPreserved,
      intentMatched: intentMatched,
      filterPrecision: filterPrecision,
      filterRecall: filterRecall,
      filterF1: filterF1,
      exactSemanticMatch: exactSemanticMatch,
      rawSemanticSuccess: rawSemanticSuccess,
      postRecoverySemanticSuccess: postRecoverySemanticSuccess,
      searchSemanticSuccess: searchSemanticSuccess,
      entityResolutionOutcome: resolutionOutcome,
      entityResolutionSucceeded: entityResolutionSucceeded,
      dbExecutionSucceeded: dbExecutionSucceeded,
      returnedRowCount: returnedRowCount,
      failureAttribution: attribution,
      sttLatencyMs: sttStopwatch.elapsedMilliseconds,
      llmParseLatencyMs: parseLatencyMs,
      entityResolutionLatencyMs: entityResolutionLatencyMs,
      dbLatencyMs: dbLatencyMs,
      totalLatencyMs: totalStopwatch.elapsedMilliseconds,
      parsedQuery: parsedQuery,
      resolvedQuery: resolvedQuery,
      errorMessage: errorMessage,
      audioMissing: isAudioMissing,
    );
  }

  static _FilterScore _calculateFilterScores(Map<String, dynamic> expectedFilters, SearchQuery actual) {
    if (expectedFilters.isEmpty) {
      return const _FilterScore(1.0, 1.0, 1.0);
    }

    int expectedCount = expectedFilters.length;
    int truePositives = 0;
    int falsePositives = 0;

    final actualMap = <String, dynamic>{};
    if (actual.driverName != null) actualMap['driverName'] = actual.driverName;
    if (actual.rallyName != null) actualMap['rallyName'] = actual.rallyName;
    if (actual.country != null) actualMap['country'] = actual.country;
    if (actual.city != null) actualMap['city'] = actual.city;
    if (actual.actionType != null) actualMap['actionType'] = actual.actionType;
    if (actual.year != null) actualMap['year'] = actual.year;
    if (actual.stageName != null) actualMap['stageName'] = actual.stageName;

    for (final expKey in expectedFilters.keys) {
      final expVal = expectedFilters[expKey].toString().toLowerCase();
      final actVal = actualMap[expKey]?.toString().toLowerCase();

      if (actVal != null && (actVal.contains(expVal) || expVal.contains(actVal))) {
        truePositives++;
      }
    }

    for (final actKey in actualMap.keys) {
      if (!expectedFilters.containsKey(actKey)) {
        falsePositives++;
      }
    }

    final precision = (truePositives + falsePositives > 0)
        ? truePositives / (truePositives + falsePositives)
        : 0.0;
    final recall = expectedCount > 0 ? truePositives / expectedCount : 0.0;
    final f1 = (precision + recall > 0) ? (2 * precision * recall) / (precision + recall) : 0.0;

    return _FilterScore(precision, recall, f1);
  }

  /// Generates and persists JSON and Markdown benchmark reports.
  static Future<String> generateReports({
    required List<LiveVoiceEvaluationSampleResult> results,
    required String outputDir,
    BenchmarkType benchmarkType = BenchmarkType.synthetic,
    String? modelName,
  }) async {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = benchmarkType == BenchmarkType.human ? 'live_voice_human' : 'live_voice_synthetic';
    final jsonFile = File('$outputDir/${prefix}_$timestamp.json');
    final mdFile = File('$outputDir/${prefix}_$timestamp.md');

    // Aggregate statistics
    final totalSamples = results.length;
    final evaluatedSamples = results.where((r) => !r.audioMissing).toList();
    final evalCount = evaluatedSamples.length;

    final avgWer = evalCount == 0 ? 0.0 : evaluatedSamples.map((r) => r.wer).reduce((a, b) => a + b) / evalCount;
    final rawEntityAcc = evalCount == 0
        ? 0.0
        : evaluatedSamples
                .map((r) =>
                    ((r.rawDriverPreserved ? 1 : 0) +
                        (r.rawRallyPreserved ? 1 : 0) +
                        (r.rawStagePreserved ? 1 : 0) +
                        (r.rawActionPreserved ? 1 : 0)) /
                    4.0)
                .reduce((a, b) => a + b) /
            evalCount;

    final recoveredEntityAcc = evalCount == 0
        ? 0.0
        : evaluatedSamples
                .map((r) =>
                    ((r.recoveredDriverPreserved ? 1 : 0) +
                        (r.recoveredRallyPreserved ? 1 : 0) +
                        (r.recoveredStagePreserved ? 1 : 0) +
                        (r.recoveredActionPreserved ? 1 : 0)) /
                    4.0)
                .reduce((a, b) => a + b) /
            evalCount;

    final intentAcc = evalCount == 0
        ? 0.0
        : evaluatedSamples.where((r) => r.intentMatched).length / evalCount;
    final avgF1 = evalCount == 0
        ? 0.0
        : evaluatedSamples.map((r) => r.filterF1).reduce((a, b) => a + b) / evalCount;
    final exactMatch = evalCount == 0
        ? 0.0
        : evaluatedSamples.where((r) => r.exactSemanticMatch).length / evalCount;

    final rawSuccess = evalCount == 0
        ? 0.0
        : evaluatedSamples.where((r) => r.rawSemanticSuccess).length / evalCount;
    final postRecoverySuccess = evalCount == 0
        ? 0.0
        : evaluatedSamples.where((r) => r.postRecoverySemanticSuccess).length / evalCount;
    final searchSuccess = evalCount == 0
        ? 0.0
        : evaluatedSamples.where((r) => r.searchSemanticSuccess).length / evalCount;

    final falsePositiveCount = evaluatedSamples.where((r) => r.entityResolutionOutcome == EntityResolutionOutcome.autoResolvedIncorrect).length;
    final fpRate = evalCount == 0 ? 0.0 : falsePositiveCount / evalCount;

    // Latencies
    final sttLatencies = evaluatedSamples.map((r) => r.sttLatencyMs).toList()..sort();
    final llmLatencies = evaluatedSamples.map((r) => r.llmParseLatencyMs).toList()..sort();
    final erLatencies = evaluatedSamples.map((r) => r.entityResolutionLatencyMs).toList()..sort();
    final dbLatencies = evaluatedSamples.map((r) => r.dbLatencyMs).toList()..sort();
    final totalLatencies = evaluatedSamples.map((r) => r.totalLatencyMs).toList()..sort();

    final sttP50 = _percentile(sttLatencies, 0.50);
    final sttP90 = _percentile(sttLatencies, 0.90);
    final sttP95 = _percentile(sttLatencies, 0.95);
    final sttP99 = _percentile(sttLatencies, 0.99);

    final e2eP50 = _percentile(totalLatencies, 0.50);
    final e2eP90 = _percentile(totalLatencies, 0.90);
    final e2eP95 = _percentile(totalLatencies, 0.95);
    final e2eP99 = _percentile(totalLatencies, 0.99);

    // Failure attribution counts
    final failureCounts = <FailureAttribution, int>{};
    for (final fa in FailureAttribution.values) {
      failureCounts[fa] = 0;
    }
    for (final r in results) {
      failureCounts[r.failureAttribution] = (failureCounts[r.failureAttribution] ?? 0) + 1;
    }

    // Entity resolution counts
    final erCounts = <EntityResolutionOutcome, int>{};
    for (final ero in EntityResolutionOutcome.values) {
      erCounts[ero] = 0;
    }
    for (final r in evaluatedSamples) {
      erCounts[r.entityResolutionOutcome] = (erCounts[r.entityResolutionOutcome] ?? 0) + 1;
    }

    // Save JSON
    final jsonReport = {
      'timestamp': DateTime.now().toIso8601String(),
      'benchmark_type': benchmarkType.name,
      'model_name': modelName ?? 'whisper-1',
      'total_samples': totalSamples,
      'evaluated_samples': evalCount,
      'missing_audio_samples': totalSamples - evalCount,
      'summary': {
        'avg_wer': avgWer,
        'raw_entity_accuracy': rawEntityAcc,
        'recovered_entity_accuracy': recoveredEntityAcc,
        'intent_accuracy': intentAcc,
        'filter_f1': avgF1,
        'semantic_exact_match': exactMatch,
        'raw_semantic_success': rawSuccess,
        'post_recovery_semantic_success': postRecoverySuccess,
        'search_semantic_success': searchSuccess,
        'false_positive_entity_resolution_rate': fpRate,
        'stt_latency': {'p50': sttP50, 'p90': sttP90, 'p95': sttP95, 'p99': sttP99},
        'e2e_latency': {'p50': e2eP50, 'p90': e2eP90, 'p95': e2eP95, 'p99': e2eP99},
      },
      'failure_attributions': {
        for (final fa in FailureAttribution.values) fa.label: failureCounts[fa],
      },
      'entity_resolution_breakdown': {
        for (final ero in EntityResolutionOutcome.values) ero.label: erCounts[ero],
      },
      'samples': results.map((r) => r.toJson()).toList(),
    };
    jsonFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonReport));

    // Build Markdown Report
    final buf = StringBuffer();
    if (benchmarkType == BenchmarkType.human) {
      buf.writeln('# 🎙️ Phase 5C Live Voice Search Benchmark Report (HUMAN PILOT — WAVE 1)');
      buf.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
      buf.writeln('**Benchmark Type**: `human` (Untuned Wave-1 Baseline)');
      buf.writeln('**STT Model**: `${modelName ?? "whisper-1"}`');
      buf.writeln('**Dataset Scope**: N = $totalSamples maximum (1 speaker per language × 5 archetypes × 19 languages)');
      buf.writeln();
      buf.writeln('> [!IMPORTANT]');
      buf.writeln('> **Wave 1 Purpose & Scope**: Wave 1 is a failure-discovery pilot and is not statistically representative of population-level, dialect-level, or accent-level performance. Human and synthetic benchmark metrics remain strictly segregated.');
      buf.writeln();
    } else {
      buf.writeln('# 🎙️ Phase 5B Live Voice Search Benchmark Report (SYNTHETIC)');
      buf.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
      buf.writeln('**Benchmark Type**: `synthetic` (Real Audio Execution)');
      buf.writeln('**Total Samples**: $totalSamples');
      buf.writeln();
    }

    buf.writeln('## 📊 Executive Summary');
    buf.writeln('| Metric | Measured Value | Gate Target | Gate Status |');
    buf.writeln('| :--- | :---: | :---: | :---: |');
    buf.writeln('| **Search Semantic Success Rate** | **${(searchSuccess * 100).toStringAsFixed(1)}%** | >= 90.0% | ${searchSuccess >= 0.90 ? '✅ PASSED' : '❌ FAILED'} |');
    buf.writeln('| **Post-Recovery Entity Accuracy** | ${(recoveredEntityAcc * 100).toStringAsFixed(1)}% | >= 95.0% | ${recoveredEntityAcc >= 0.95 ? '✅ PASSED' : '❌ FAILED'} |');
    buf.writeln('| **Raw STT Entity Accuracy** | ${(rawEntityAcc * 100).toStringAsFixed(1)}% | N/A | ℹ️ Informational |');
    buf.writeln('| **Intent Accuracy** | ${(intentAcc * 100).toStringAsFixed(1)}% | >= 95.0% | ${intentAcc >= 0.95 ? '✅ PASSED' : '❌ FAILED'} |');
    buf.writeln('| **Filter F1 Score** | ${avgF1.toStringAsFixed(2)} | >= 0.90 | ${avgF1 >= 0.90 ? '✅ PASSED' : '❌ FAILED'} |');
    buf.writeln('| **False-Positive Entity Resolution Rate** | **${(fpRate * 100).toStringAsFixed(1)}%** | <= 1.0% | ${fpRate <= 0.01 ? '✅ PASSED' : '❌ FAILED (Critical)'} |');
    buf.writeln('| **Raw Semantic Success Rate** | ${(rawSuccess * 100).toStringAsFixed(1)}% | N/A | ℹ️ Baseline |');
    buf.writeln('| **Word Error Rate (WER)** | ${(avgWer * 100).toStringAsFixed(1)}% | N/A | ℹ️ Informational |');
    buf.writeln('| **STT Latency (p50 / p95)** | $sttP50 ms / $sttP95 ms | N/A | ℹ️ Informational |');
    buf.writeln('| **End-to-End Latency (p50 / p95)** | $e2eP50 ms / $e2eP95 ms | N/A | ℹ️ Informational |');
    buf.writeln('| **Missing Audio Files** | ${totalSamples - evalCount} / $totalSamples | 0 | ${(totalSamples - evalCount) == 0 ? '✅ NONE' : '⚠️ Missing Audio Detected'} |');
    buf.writeln();

    // Per-Language Table
    buf.writeln('## 🌍 Per-Language Diagnostics (All 19 Supported Languages)');
    buf.writeln('| Language | Samples | WER | Raw Ent Acc | Rec Ent Acc | Intent Acc | Filter F1 | Raw Success | Search Success | FP Rate | STT p50/p95 | E2E p50/p95 |');
    buf.writeln('| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |');

    final byLanguage = <SupportedLanguage, List<LiveVoiceEvaluationSampleResult>>{};
    for (final r in results) {
      byLanguage.putIfAbsent(r.entry.language, () => []).add(r);
    }

    for (final lang in SupportedLanguages.all) {
      final lResults = (byLanguage[lang] ?? []).where((r) => !r.audioMissing).toList();
      final totalLCount = (byLanguage[lang] ?? []).length;
      if (totalLCount == 0) continue;

      if (lResults.isEmpty) {
        buf.writeln('| ${lang.displayName} (${lang.languageCode.toUpperCase()}) | $totalLCount | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | ⚠️ No Audio Ingested |');
        continue;
      }

      final lCount = lResults.length;
      final lWer = lResults.map((r) => r.wer).reduce((a, b) => a + b) / lCount;
      final lRawEnt = lResults.map((r) => ((r.rawDriverPreserved ? 1 : 0) + (r.rawRallyPreserved ? 1 : 0) + (r.rawStagePreserved ? 1 : 0) + (r.rawActionPreserved ? 1 : 0)) / 4.0).reduce((a, b) => a + b) / lCount;
      final lRecEnt = lResults.map((r) => ((r.recoveredDriverPreserved ? 1 : 0) + (r.recoveredRallyPreserved ? 1 : 0) + (r.recoveredStagePreserved ? 1 : 0) + (r.recoveredActionPreserved ? 1 : 0)) / 4.0).reduce((a, b) => a + b) / lCount;
      final lIntent = lResults.where((r) => r.intentMatched).length / lCount;
      final lF1 = lResults.map((r) => r.filterF1).reduce((a, b) => a + b) / lCount;
      final lRawSucc = lResults.where((r) => r.rawSemanticSuccess).length / lCount;
      final lSuccess = lResults.where((r) => r.searchSemanticSuccess).length / lCount;
      final lFp = lResults.where((r) => r.entityResolutionOutcome == EntityResolutionOutcome.autoResolvedIncorrect).length / lCount;

      final lSttLat = lResults.map((r) => r.sttLatencyMs).toList()..sort();
      final lTotalLat = lResults.map((r) => r.totalLatencyMs).toList()..sort();

      buf.writeln(
          '| ${lang.displayName} (${lang.languageCode.toUpperCase()}) | $lCount | ${(lWer * 100).toStringAsFixed(1)}% | ${(lRawEnt * 100).toStringAsFixed(1)}% | ${(lRecEnt * 100).toStringAsFixed(1)}% | ${(lIntent * 100).toStringAsFixed(1)}% | ${lF1.toStringAsFixed(2)} | ${(lRawSucc * 100).toStringAsFixed(1)}% | **${(lSuccess * 100).toStringAsFixed(1)}%** | ${(lFp * 100).toStringAsFixed(1)}% | ${_percentile(lSttLat, 0.5)}/${_percentile(lSttLat, 0.95)}ms | ${_percentile(lTotalLat, 0.5)}/${_percentile(lTotalLat, 0.95)}ms |');
    }
    buf.writeln();

    // Archetype Diagnostics Table (For Human Benchmarks)
    if (benchmarkType == BenchmarkType.human) {
      buf.writeln('## 🎯 Archetype Diagnostics (A through E)');
      buf.writeln('| Archetype | Title | Samples | WER | Intent Acc | Filter F1 | Search Success | FP Rate |');
      buf.writeln('| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |');

      for (final arch in QueryArchetype.values) {
        final archSamples = evaluatedSamples.where((r) => r.entry is HumanBenchmarkManifestEntry && (r.entry as HumanBenchmarkManifestEntry).archetype == arch).toList();
        if (archSamples.isEmpty) {
          buf.writeln('| Archetype ${arch.code} | ${arch.title} | 0 | N/A | N/A | N/A | N/A | N/A |');
          continue;
        }
        final aCount = archSamples.length;
        final aWer = archSamples.map((r) => r.wer).reduce((a, b) => a + b) / aCount;
        final aIntent = archSamples.where((r) => r.intentMatched).length / aCount;
        final aF1 = archSamples.map((r) => r.filterF1).reduce((a, b) => a + b) / aCount;
        final aSuccess = archSamples.where((r) => r.searchSemanticSuccess).length / aCount;
        final aFp = archSamples.where((r) => r.entityResolutionOutcome == EntityResolutionOutcome.autoResolvedIncorrect).length / aCount;

        buf.writeln('| Archetype ${arch.code} | ${arch.title} | $aCount | ${(aWer * 100).toStringAsFixed(1)}% | ${(aIntent * 100).toStringAsFixed(1)}% | ${aF1.toStringAsFixed(2)} | **${(aSuccess * 100).toStringAsFixed(1)}%** | ${(aFp * 100).toStringAsFixed(1)}% |');
      }
      buf.writeln();

      // Acoustic Environment Table
      buf.writeln('## 🔊 Acoustic Environment Performance');
      buf.writeln('| Environment | Samples | Avg WER | Intent Acc | Search Success |');
      buf.writeln('| :--- | :---: | :---: | :---: | :---: |');
      for (final env in AcousticEnvironment.values) {
        final envSamples = evaluatedSamples.where((r) => r.entry is HumanBenchmarkManifestEntry && (r.entry as HumanBenchmarkManifestEntry).environment == env).toList();
        if (envSamples.isEmpty) continue;
        final eCount = envSamples.length;
        final eWer = envSamples.map((r) => r.wer).reduce((a, b) => a + b) / eCount;
        final eIntent = envSamples.where((r) => r.intentMatched).length / eCount;
        final eSucc = envSamples.where((r) => r.searchSemanticSuccess).length / eCount;
        buf.writeln('| ${env.label} | $eCount | ${(eWer * 100).toStringAsFixed(1)}% | ${(eIntent * 100).toStringAsFixed(1)}% | **${(eSucc * 100).toStringAsFixed(1)}%** |');
      }
      buf.writeln();
    }

    // Entity Resolution Outcomes Table
    buf.writeln('## 🏷️ Entity Resolution Outcome Breakdown');
    buf.writeln('| Outcome Category | Count | Percentage | Description |');
    buf.writeln('| :--- | :---: | :---: | :--- |');
    for (final ero in EntityResolutionOutcome.values) {
      final cnt = erCounts[ero] ?? 0;
      final pct = evalCount > 0 ? (cnt / evalCount * 100).toStringAsFixed(1) : '0.0';
      buf.writeln('| `${ero.label}` | $cnt | $pct% | ${_getOutcomeDescription(ero)} |');
    }
    buf.writeln();

    // 12-Class Failure Attribution Breakdown
    buf.writeln('## 🛑 12-Class Failure Attribution Breakdown');
    buf.writeln('| Primary Failure Stage | Count | Percentage | Description |');
    buf.writeln('| :--- | :---: | :---: | :--- |');
    for (final fa in FailureAttribution.values) {
      final cnt = failureCounts[fa] ?? 0;
      final pct = totalSamples > 0 ? (cnt / totalSamples * 100).toStringAsFixed(1) : '0.0';
      buf.writeln('| `${fa.label}` | $cnt | $pct% | ${fa.description} |');
    }
    buf.writeln();

    // Detailed Sample Traces
    buf.writeln('## 🔍 Detailed Sample Traces & Diagnostics');
    for (final r in results) {
      final icon = r.audioMissing ? '⚠️' : (r.searchSemanticSuccess ? '✅' : '❌');
      buf.writeln('### $icon [${r.entry.id}] ${r.entry.language.displayName} (`${r.entry.locale}`)');
      buf.writeln('- **Audio Asset ID**: `${r.entry.audioFile}`');
      if (r.entry is HumanBenchmarkManifestEntry) {
        final h = r.entry as HumanBenchmarkManifestEntry;
        buf.writeln('- **Speaker ID / Archetype**: `${h.speakerId}` | Archetype ${h.archetype.code} (${h.archetype.title})');
        buf.writeln('- **Environment / Device**: `${h.environment.label}` | `${h.deviceClass.label}`');
        buf.writeln('- **Natural Prompt Given**: "${h.naturalPromptGiven}"');
        buf.writeln('- **Human Verified Transcript**: "${h.humanVerifiedTranscript}" (`${h.verificationTier.label}`)');
      } else {
        buf.writeln('- **Expected Transcript**: "${r.entry.expectedTranscript}"');
      }
      buf.writeln('- **Actual STT Transcript**: "${r.actualTranscript}"');
      if (r.recoveryResult != null && r.recoveryResult!.hasRecoveries) {
        buf.writeln('- **Normalized Transcript**: "${r.normalizedTranscript}"');
        buf.writeln('- **Domain Anchor Mappings**: `${r.recoveryResult!.entityRecoveryMappings}`');
      }
      buf.writeln('- **WER**: ${(r.wer * 100).toStringAsFixed(1)}% | **Failure Attribution**: `${r.failureAttribution.label}`');
      buf.writeln('- **Entity Resolution Outcome**: `${r.entityResolutionOutcome.label}`');
      buf.writeln('- **Parsed Intent**: `${r.parsedQuery?.intent.name}` (Expected: `${r.entry.expectedIntent.name}`)');
      buf.writeln('- **Resolved Query**: `${r.resolvedQuery?.toMap()}`');
      buf.writeln('- **DB Execution**: ${r.dbExecutionSucceeded ? "SUCCESS (${r.returnedRowCount} rows returned)" : "FAILED"}');
      buf.writeln('- **Latency**: STT: ${r.sttLatencyMs}ms | LLM: ${r.llmParseLatencyMs}ms | ER: ${r.entityResolutionLatencyMs}ms | DB: ${r.dbLatencyMs}ms | **Total: ${r.totalLatencyMs}ms**');
      if (r.errorMessage != null) {
        buf.writeln('- **Error / Diagnostics**: `${r.errorMessage}`');
      }
      buf.writeln();
    }

    mdFile.writeAsStringSync(buf.toString());
    return mdFile.path;
  }

  static String _getOutcomeDescription(EntityResolutionOutcome outcome) {
    switch (outcome) {
      case EntityResolutionOutcome.autoResolvedCorrect:
        return 'Ambiguous/fuzzy token correctly matched database entity.';
      case EntityResolutionOutcome.autoResolvedIncorrect:
        return 'CRITICAL FAILURE: Confidently mapped to incorrect database entity.';
      case EntityResolutionOutcome.clarificationRequiredCorrectly:
        return 'Genuinely ambiguous token triggered interactive clarification.';
      case EntityResolutionOutcome.unnecessaryClarification:
        return 'Clear unambiguous token triggered unnecessary clarification.';
      case EntityResolutionOutcome.noMatch:
        return 'No entity candidate was resolved or required.';
    }
  }

  static int _percentile(List<int> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final index = (p * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

class _FilterScore {
  final double precision;
  final double recall;
  final double f1;
  const _FilterScore(this.precision, this.recall, this.f1);
}
