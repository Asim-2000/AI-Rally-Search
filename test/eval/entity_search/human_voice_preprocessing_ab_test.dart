// ignore_for_file: avoid_print
@Tags(['live-db', 'live-api', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/controlled_fallback_entity_resolver.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_lookup_adapter.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser_factory.dart';
import 'package:ai_rally_search/services/speech/audio_preprocessor.dart';
import 'package:ai_rally_search/services/speech/openai_speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'human_voice_smoke_evaluator.dart';
import 'pcm16_wav.dart';

void main() {
  test('ES-7 conservative preprocessing A/B on five human fixtures', () async {
    await dotenv.load(fileName: '.env');
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    expect(apiKey, isNotNull);
    expect(apiKey, isNotEmpty);

    final baselineFile = File(
      'test/eval/entity_search/human_voice_smoke_baseline_report.json',
    );
    expect(
      baselineFile.existsSync(),
      isTrue,
      reason: 'The RAW baseline must be frozen before preprocessing A/B.',
    );
    final baseline =
        jsonDecode(await baselineFile.readAsString()) as Map<String, dynamic>;
    expect(baseline['rawBaselineCapturedBeforePreprocessing'], isTrue);
    final rawResults = (baseline['results'] as List)
        .cast<Map<String, dynamic>>();
    expect(rawResults, hasLength(5));

    final manifest = jsonDecode(
      await File('test/eval/entity_search/human_voice_smoke_manifest.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    final fixtures = (manifest['fixtures'] as List)
        .cast<Map<String, dynamic>>();

    final db = DatabaseService();
    final speech = OpenAiSpeechToTextService(
      config: SpeechConfig(
        providerType: SpeechProviderType.openAiDirectDev,
        endpointUrl: 'https://api.openai.com/v1/audio/transcriptions',
        apiKey: apiKey,
        model: 'gpt-transcribe',
        timeout: const Duration(seconds: 45),
      ),
    );
    try {
      final entities = await MySqlEntitySearchDataSource(database: db)
          .loadEntities();
      final entitySearch = InMemoryEntitySearchService.fromEntities(entities);
      final legacy = DatabaseEntityLookupRepository(dbService: db);
      final resolver = ControlledFallbackEntityResolver(
        legacyResolver: DatabaseEntityResolver(repository: legacy),
        entitySearchResolver: DatabaseEntityResolver(
          repository: EntitySearchLookupAdapter(
            searchService: entitySearch,
            cityFallback: legacy,
          ),
        ),
        config: const EntitySearchFallbackConfig(
          mode: EntitySearchFallbackMode.fallback,
        ),
      );
      final evaluator = HumanVoiceSmokeEvaluator(
        speech: speech,
        parser: LlmQueryParserFactory.create(),
        resolver: resolver,
        entitySearch: entitySearch,
      );
      const preprocessor = SpeechAudioPreprocessor();
      final processedResults = <Map<String, Object?>>[];
      final comparisons = <Map<String, Object?>>[];

      for (final fixture in fixtures) {
        final recordingId = fixture['recordingId'] as String;
        final original = File(fixture['audioFile'] as String);
        final originalBytes = await original.readAsBytes();
        final raw = rawResults.firstWhere(
          (item) => item['recordingId'] == recordingId,
        );
        for (final strategy in AudioPreprocessingStrategy.values.where(
          (strategy) => strategy != AudioPreprocessingStrategy.raw,
        )) {
          final processed = await preprocessor.process(
            inputBytes: originalBytes,
            filename: original.uri.pathSegments.last,
            strategy: strategy,
          );
          final outputWave = Pcm16Wav.decode(processed.bytes);
          final result = await evaluator.evaluateProcessed(
            recordingId: recordingId,
            originalAudioFile: original,
            processed: processed,
            groundTruth: fixture,
          );
          result['derivedAudio'] = {
            'storage': 'memory_only_not_persisted',
            'originalOverwritten': false,
            ...outputWave.diagnostics(fileSizeBytes: processed.bytes.length),
          };
          processedResults.add(result);
          comparisons.add(_compare(raw, result));
        }
        expect(await original.readAsBytes(), orderedEquals(originalBytes));
      }

      final uniqueComparisons = comparisons
          .where((item) => item['recordingId'] != 'human-smoke-003')
          .toList(growable: false);
      final allRuns = [...rawResults, ...processedResults];
      final uniqueRuns = allRuns
          .where((item) => item['recordingId'] != 'human-smoke-003')
          .toList(growable: false);
      final report = <String, Object?>{
        'phase': 'ES-7',
        'realHumanAudio': true,
        'humanSampleCount': fixtures.length,
        'uniqueWaveformCount': manifest['uniqueWaveformCount'],
        'humanBenchmarkStatus': 'LABELED_SMOKE_TEST_ONLY',
        'sttBiasingUsed': false,
        'productionVoiceBehaviorChanged': false,
        'originalAudioOverwritten': false,
        'rawBaselineReport': baselineFile.path,
        'audioInventory': {
          'TOTAL_FILES': fixtures.length,
          'UNIQUE_AUDIO_FILES': manifest['uniqueWaveformCount'],
          'DUPLICATE_GROUPS': [
            {
              'representative': 'human-smoke-001',
              'members': ['human-smoke-001', 'human-smoke-003'],
              'byteIdenticalVerified': true,
            },
          ],
        },
        'rawResults': rawResults,
        'preprocessingStrategies': [
          'VAD_ONLY: energy-based silence trim with 150 ms padding',
          'NORMALIZED: bounded RMS normalization, -23 dBFS target, -3 dBFS peak ceiling, +9.54 dB maximum gain',
          'NOISE_SUPPRESSED: conservative 10 ms soft noise gate, approximately -12 dB below adaptive threshold',
          'VAD_NORMALIZED_NOISE_SUPPRESSED: noise gate then normalization then silence trim',
        ],
        'processedResults': processedResults,
        'comparisonsToFrozenRaw': comparisons,
        'perFileStrategyMetrics': _strategyMetrics(comparisons),
        'uniqueAudioStrategyMetrics': _strategyMetrics(uniqueComparisons),
        'scoringAvailability': {
          'canonicalCorrectness': true,
          'canonicalFixtures': fixtures
              .where((item) => item['canonicalEntityId'] != null)
              .length,
          'targetCandidateRank': true,
          'correctConfident': true,
          'wrongConfident': true,
          'werCer': true,
          'transcriptFixtures': fixtures.length,
          'limitation': 'human-smoke-002 is a city query without a canonical city ID, so its canonical outcome remains unscored.',
        },
        'voiceExactMatchEscalation': {
          'status': 'ASSESSED_WHERE_CANONICAL_GROUND_TRUTH_EXISTS',
          'perFileAssessableRuns': allRuns
              .where((item) => item['expectedCanonicalEntityId'] != null)
              .length,
          'uniqueAudioAssessableRuns': uniqueRuns
              .where((item) => item['expectedCanonicalEntityId'] != null)
              .length,
          'perFileConfirmedCases': allRuns.where((item) {
            final finding = item['voiceExactMatchEscalation'];
            return finding is Map && finding['occurred'] == true;
          }).length,
          'uniqueAudioConfirmedCases': uniqueRuns.where((item) {
            final finding = item['voiceExactMatchEscalation'];
            return finding is Map && finding['occurred'] == true;
          }).length,
        },
        'optionalProviderComparison': {
          'performed': false,
          'reason': 'No second non-mock STT provider is already supported by the project.',
        },
        'recommendation': _recommendation(uniqueComparisons),
        'limitations': [
          'Five files are still a smoke test, not a statistically meaningful benchmark.',
          'Only four unique waveforms exist because human-smoke-003 is byte-identical to human-smoke-001.',
          'The city fixture has transcript ground truth but no canonical city ID.',
          'The current LLM query parser can vary for identical transcripts, which is a downstream confound visible in the frozen RAW duplicate pair.',
        ],
      };
      const outputPath =
          'test/eval/entity_search/human_voice_preprocessing_ab_report.json';
      await File(outputPath)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      print(const JsonEncoder.withIndent('  ').convert(report));
    } finally {
      speech.dispose();
      await db.close();
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Map<String, Object?> _compare(
  Map<String, dynamic> raw,
  Map<String, Object?> processed,
) {
  final rawTranscript =
      ((raw['transcription'] as Map)['transcript'] as String?) ?? '';
  final processedTranscript =
      ((processed['transcription'] as Map)['transcript'] as String?) ?? '';
  final rawResolver = raw['resolver'] as Map;
  final processedResolver = processed['resolver'] as Map;
  final rawMentions = _mentions(raw);
  final processedMentions = _mentions(processed);
  final unchanged =
      rawTranscript == processedTranscript &&
      rawResolver['decision'] == processedResolver['decision'] &&
      _sameStrings(
        (rawResolver['finalCanonicalEntityIds'] as List).cast<String>(),
        (processedResolver['finalCanonicalEntityIds'] as List).cast<String>(),
      );
  final rawCanonicalCorrect = raw['canonicalEntityCorrect'] as bool?;
  final processedCanonicalCorrect =
      processed['canonicalEntityCorrect'] as bool?;
  final rawCanonicalOutcomeCorrect = raw['canonicalOutcomeCorrect'] as bool?;
  final processedCanonicalOutcomeCorrect =
      processed['canonicalOutcomeCorrect'] as bool?;
  final rawWrongConfident = raw['wrongConfident'] as bool?;
  final processedWrongConfident = processed['wrongConfident'] as bool?;
  final rawWer = (raw['wer'] as num?)?.toDouble();
  final processedWer = (processed['wer'] as num?)?.toDouble();
  final rawCer = (raw['cer'] as num?)?.toDouble();
  final processedCer = (processed['cer'] as num?)?.toDouble();
  final assessment = _assessment(
    unchanged: unchanged,
    rawCanonicalCorrect: rawCanonicalOutcomeCorrect,
    processedCanonicalCorrect: processedCanonicalOutcomeCorrect,
    rawWrongConfident: rawWrongConfident,
    processedWrongConfident: processedWrongConfident,
    rawFinalOutcome: raw['finalOutcome'] as String?,
    processedFinalOutcome: processed['finalOutcome'] as String?,
    rawEntityMentionExact: raw['entityMentionExact'] as bool?,
    processedEntityMentionExact: processed['entityMentionExact'] as bool?,
    rawWer: rawWer,
    processedWer: processedWer,
    rawCer: rawCer,
    processedCer: processedCer,
  );
  return {
    'recordingId': processed['recordingId'],
    'strategy': processed['strategy'],
    'rawTranscript': rawTranscript,
    'processedTranscript': processedTranscript,
    'transcriptUnchanged': rawTranscript == processedTranscript,
    'tokenEditRateFromRaw': _editRate(
      rawTranscript.split(RegExp(r'\s+')),
      processedTranscript.split(RegExp(r'\s+')),
    ),
    'characterEditRateFromRaw': _editRate(
      rawTranscript.runes.toList(),
      processedTranscript.runes.toList(),
    ),
    'rawEntityMentions': rawMentions,
    'processedEntityMentions': processedMentions,
    'entityMentionChanged': !_sameStrings(rawMentions, processedMentions),
    'rawResolverDecision': rawResolver['decision'],
    'processedResolverDecision': processedResolver['decision'],
    'resolverOutcomeChanged':
        rawResolver['decision'] != processedResolver['decision'],
    'rawFinalCanonicalEntityIds': rawResolver['finalCanonicalEntityIds'],
    'processedFinalCanonicalEntityIds':
        processedResolver['finalCanonicalEntityIds'],
    'rawCanonicalEntityCorrect': rawCanonicalCorrect,
    'processedCanonicalEntityCorrect': processedCanonicalCorrect,
    'rawCanonicalOutcomeCorrect': rawCanonicalOutcomeCorrect,
    'processedCanonicalOutcomeCorrect': processedCanonicalOutcomeCorrect,
    'rawEntityMentionExact': raw['entityMentionExact'],
    'processedEntityMentionExact': processed['entityMentionExact'],
    'rawFinalOutcome': raw['finalOutcome'],
    'processedFinalOutcome': processed['finalOutcome'],
    'rawTargetCandidateRank': raw['targetCandidateRank'],
    'processedTargetCandidateRank': processed['targetCandidateRank'],
    'rawFinalSearchQuery': (raw['querySemantics'] as Map?)?['finalSearchQuery'],
    'processedFinalSearchQuery':
        (processed['querySemantics'] as Map?)?['finalSearchQuery'],
    'rawWrongConfident': rawWrongConfident,
    'processedWrongConfident': processedWrongConfident,
    'rawWer': rawWer,
    'processedWer': processedWer,
    'werDelta': rawWer == null || processedWer == null
        ? null
        : processedWer - rawWer,
    'rawCer': rawCer,
    'processedCer': processedCer,
    'cerDelta': rawCer == null || processedCer == null
        ? null
        : processedCer - rawCer,
    'observablePipelineOutputUnchanged': unchanged,
    'preprocessingRegressionAssessment': assessment,
  };
}

String _assessment({
  required bool unchanged,
  required bool? rawCanonicalCorrect,
  required bool? processedCanonicalCorrect,
  required bool? rawWrongConfident,
  required bool? processedWrongConfident,
  required String? rawFinalOutcome,
  required String? processedFinalOutcome,
  required bool? rawEntityMentionExact,
  required bool? processedEntityMentionExact,
  required double? rawWer,
  required double? processedWer,
  required double? rawCer,
  required double? processedCer,
}) {
  if (rawCanonicalCorrect != null && processedCanonicalCorrect != null) {
    if (!rawCanonicalCorrect && processedCanonicalCorrect) {
      return 'CANONICAL_IMPROVEMENT';
    }
    if (rawCanonicalCorrect && !processedCanonicalCorrect) {
      return 'CANONICAL_REGRESSION';
    }
    if (rawWrongConfident != true && processedWrongConfident == true) {
      return 'WRONG_CONFIDENT_REGRESSION';
    }
  }
  if (rawFinalOutcome != 'WRONG_CLARIFICATION' &&
      processedFinalOutcome == 'WRONG_CLARIFICATION') {
    return 'WRONG_CLARIFICATION_REGRESSION';
  }
  if (rawEntityMentionExact != null && processedEntityMentionExact != null) {
    if (!rawEntityMentionExact && processedEntityMentionExact) {
      return 'ENTITY_MENTION_IMPROVEMENT';
    }
    if (rawEntityMentionExact && !processedEntityMentionExact) {
      return 'ENTITY_MENTION_REGRESSION';
    }
  }
  if (rawWer != null && processedWer != null) {
    final delta = processedWer - rawWer;
    if (delta < -0.000001) return 'TRANSCRIPT_IMPROVEMENT';
    if (delta > 0.000001) return 'TRANSCRIPT_REGRESSION';
  }
  if (rawCer != null && processedCer != null) {
    final delta = processedCer - rawCer;
    if (delta < -0.000001) return 'TRANSCRIPT_IMPROVEMENT';
    if (delta > 0.000001) return 'TRANSCRIPT_REGRESSION';
  }
  return unchanged
      ? 'NO_OBSERVABLE_CHANGE'
      : 'CANONICAL_MENTION_AND_TRANSCRIPT_METRICS_UNCHANGED';
}

List<Map<String, Object?>> _strategyMetrics(
  List<Map<String, Object?>> comparisons,
) {
  final strategies =
      comparisons.map((item) => item['strategy'] as String).toSet().toList()
        ..sort();
  return strategies
      .map((strategy) {
        final rows = comparisons
            .where((item) => item['strategy'] == strategy)
            .toList(growable: false);
        final werValues = rows
            .map((item) => item['processedWer'])
            .whereType<double>()
            .toList(growable: false);
        final cerValues = rows
            .map((item) => item['processedCer'])
            .whereType<double>()
            .toList(growable: false);
        return <String, Object?>{
          'strategy': strategy,
          'runs': rows.length,
          'canonicalCorrect': rows
              .where((item) => item['processedCanonicalOutcomeCorrect'] == true)
              .length,
          'canonicalScorable': rows
              .where((item) => item['processedCanonicalOutcomeCorrect'] != null)
              .length,
          'finalCanonicalResolvedCorrect': rows
              .where((item) => item['processedCanonicalEntityCorrect'] == true)
              .length,
          'entityMentionExact': rows
              .where((item) => item['processedEntityMentionExact'] == true)
              .length,
          'wrongConfident': rows
              .where((item) => item['processedWrongConfident'] == true)
              .length,
          'meanWer': werValues.isEmpty
              ? null
              : werValues.reduce((left, right) => left + right) /
                    werValues.length,
          'meanCer': cerValues.isEmpty
              ? null
              : cerValues.reduce((left, right) => left + right) /
                    cerValues.length,
          'canonicalImprovements': rows
              .where(
                (item) =>
                    item['preprocessingRegressionAssessment'] ==
                    'CANONICAL_IMPROVEMENT',
              )
              .length,
          'canonicalRegressions': rows
              .where(
                (item) =>
                    item['preprocessingRegressionAssessment'] ==
                    'CANONICAL_REGRESSION',
              )
              .length,
          'outcomeRegressions': rows
              .where(
                (item) =>
                    item['preprocessingRegressionAssessment'] ==
                    'WRONG_CLARIFICATION_REGRESSION',
              )
              .length,
          'entityMentionImprovements': rows
              .where(
                (item) =>
                    item['preprocessingRegressionAssessment'] ==
                    'ENTITY_MENTION_IMPROVEMENT',
              )
              .length,
          'entityMentionRegressions': rows
              .where(
                (item) =>
                    item['preprocessingRegressionAssessment'] ==
                    'ENTITY_MENTION_REGRESSION',
              )
              .length,
          'transcriptImprovements': rows
              .where(
                (item) =>
                    item['preprocessingRegressionAssessment'] ==
                    'TRANSCRIPT_IMPROVEMENT',
              )
              .length,
          'transcriptRegressions': rows
              .where(
                (item) =>
                    item['preprocessingRegressionAssessment'] ==
                    'TRANSCRIPT_REGRESSION',
              )
              .length,
        };
      })
      .toList(growable: false);
}

String _recommendation(List<Map<String, Object?>> comparisons) {
  final assessments = comparisons
      .map((item) => item['preprocessingRegressionAssessment'])
      .whereType<String>()
      .toList(growable: false);
  final improvements = assessments
      .where(
        (item) =>
            item == 'CANONICAL_IMPROVEMENT' ||
            item == 'ENTITY_MENTION_IMPROVEMENT' ||
            item == 'TRANSCRIPT_IMPROVEMENT',
      )
      .length;
  final regressions = assessments
      .where(
        (item) =>
            item == 'CANONICAL_REGRESSION' ||
            item == 'WRONG_CONFIDENT_REGRESSION' ||
            item == 'WRONG_CLARIFICATION_REGRESSION' ||
            item == 'ENTITY_MENTION_REGRESSION' ||
            item == 'TRANSCRIPT_REGRESSION',
      )
      .length;
  if (improvements > 0 && regressions == 0) {
    return 'AUDIO PREPROCESSING PROMISING';
  }
  if (regressions > 0 && improvements == 0) {
    return 'AUDIO PREPROCESSING HARMFUL';
  }
  if (improvements == 0 && regressions == 0) {
    return 'AUDIO PREPROCESSING LOW VALUE';
  }
  return 'INSUFFICIENT / MIXED';
}

List<String> _mentions(Map<dynamic, dynamic> result) {
  final understanding = result['queryUnderstanding'];
  if (understanding is! Map || understanding['rawEntityMentions'] is! List) {
    return const [];
  }
  return (understanding['rawEntityMentions'] as List)
      .whereType<Map>()
      .map((item) => '${item['entityType']}:${item['mention']}')
      .toList(growable: false);
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

double _editRate<T>(List<T> reference, List<T> hypothesis) {
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
