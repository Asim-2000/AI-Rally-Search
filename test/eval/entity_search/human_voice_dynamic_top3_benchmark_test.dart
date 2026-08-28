// ignore_for_file: avoid_print
@Tags(['live-db', 'live-api', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';

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

import 'human_voice_dynamic_top3_evaluator.dart';
import 'human_voice_smoke_evaluator.dart';

void main() {
  test('ES-8A real-human RAW plus dynamic top-3 second pass', () async {
    await dotenv.load(fileName: '.env');
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    expect(apiKey, isNotNull);
    expect(apiKey, isNotEmpty);

    final manifest = jsonDecode(
      await File('test/eval/entity_search/human_voice_smoke_manifest.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    final fixtures = (manifest['fixtures'] as List)
        .cast<Map<String, dynamic>>();
    expect(fixtures, hasLength(5));
    expect(manifest['uniqueWaveformCount'], 4);

    final baselineReportFile = File(
      'test/eval/entity_search/human_voice_smoke_baseline_report.json',
    );
    final baselineReport = jsonDecode(
      await baselineReportFile.readAsString(),
    ) as Map<String, dynamic>;
    final frozenResults = (baselineReport['results'] as List)
        .cast<Map<String, dynamic>>();
    expect(frozenResults, hasLength(5));
    expect(
      (baselineReport['uniqueAudioMetrics']
          as Map)['canonicalOutcomeCorrectIncludingClarification'],
      2,
    );
    expect(
      (baselineReport['uniqueAudioMetrics'] as Map)['canonicalOutcomeScorable'],
      3,
    );

    final diagnosisFile = File(
      'test/eval/entity_search/es8a_raw_failure_diagnosis.json',
    );
    final diagnosis =
        jsonDecode(await diagnosisFile.readAsString()) as Map<String, dynamic>;
    expect(diagnosis['recordedBeforeDynamicBiasingImplementation'], isTrue);
    expect(
      (diagnosis['failedRecording'] as Map)['recordingId'],
      'human-smoke-001',
    );

    const audioPreprocessor = NoOpAudioPreprocessor();
    for (final fixture in fixtures) {
      final audioFile = File(fixture['audioFile'] as String);
      final original = await audioFile.readAsBytes();
      final processed = await audioPreprocessor.process(
        inputBytes: original,
        filename: audioFile.uri.pathSegments.last,
        strategy: AudioPreprocessingStrategy.raw,
      );
      expect(processed.changed, isFalse);
      expect(processed.bytes, orderedEquals(original));
      expect(await audioFile.readAsBytes(), orderedEquals(original));
    }

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
      final indexedIds = entities.map((item) => item.canonicalId).toSet();
      expect(indexedIds, contains('0cea6942-72e3-4257-a8c1-0f8148747d82'));
      expect(
        indexedIds,
        contains('person:account:cf3ddf9c-a64b-4f59-a5e4-5230c44b4d87'),
      );
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
      final pipeline = HumanVoiceSmokeEvaluator(
        speech: speech,
        parser: LlmQueryParserFactory.create(),
        resolver: resolver,
        entitySearch: entitySearch,
      );
      final evaluator = HumanVoiceDynamicTop3Evaluator(pipeline: pipeline);
      final results = <Map<String, Object?>>[];
      for (final fixture in fixtures) {
        final frozen = frozenResults.firstWhere(
          (item) => item['recordingId'] == fixture['recordingId'],
        );
        results.add(
          await evaluator.evaluate(fixture: fixture, frozenRawBaseline: frozen),
        );
      }

      final uniqueResults = results
          .where((item) => item['recordingId'] != 'human-smoke-003')
          .toList(growable: false);
      final perFileMetrics = _metrics(results);
      final uniqueAudioMetrics = _metrics(uniqueResults);
      final recommendation = _recommendation(uniqueAudioMetrics);
      final report = <String, Object?>{
        'phase': 'ES-8A',
        'experiment': 'REAL_HUMAN_DYNAMIC_TOP3_BIASING_SMOKE_TEST',
        'humanBenchmarkStatus': 'LABELED_SMOKE_TEST_ONLY',
        'realHumanAudio': true,
        'productionVoiceRoutingChanged': false,
        'sttBiasingProductionEnabled': false,
        'audioPreprocessing': {
          'implementation': 'NoOpAudioPreprocessor',
          'enabled': false,
          'originalAudioOverwritten': false,
        },
        'biasingConfiguration': {
          'strategy': 'DYNAMIC_TOP3_SECOND_PASS_ONLY',
          'topK': 3,
          'staticDomainContextUsed': false,
          'maximumSecondPasses': 1,
          'sameOriginalAudioRetranscribed': true,
          'circularExactEvidenceMayAutoConfirm': false,
        },
        'audioInventory': {
          'TOTAL_FILES': 5,
          'UNIQUE_AUDIO_FILES': 4,
          'DUPLICATE_GROUPS': [
            {
              'representative': 'human-smoke-001',
              'members': ['human-smoke-001', 'human-smoke-003'],
              'byteIdenticalVerified': true,
            },
          ],
        },
        'canonicalGroundTruth': {
          'rallyAluksneEventId': '0cea6942-72e3-4257-a8c1-0f8148747d82',
          'maxFreemanCanonicalPersonId':
              'person:account:cf3ddf9c-a64b-4f59-a5e4-5230c44b4d87',
          'ambiguousCityFixtureForcedToEvent': false,
        },
        'frozenRawBaseline': {
          'report': baselineReportFile.path,
          'sha256': diagnosis['frozenRawBaselineSha256'],
          'diagnosis': diagnosisFile.path,
        },
        'perFileMetrics': perFileMetrics,
        'uniqueAudioMetrics': uniqueAudioMetrics,
        'results': results,
        'existingSyntheticEvidence': {
          'report': 'test/eval/entity_search/synthetic_stt_biasing_report.json',
          'rerun': false,
          'dynamicTop3WasBestSafetyUtilityConfiguration': true,
          'remainedExperimental': true,
        },
        'safety': {
          'requiredDynamicWrongConfident': 0,
          'actualPerFileDynamicWrongConfident':
              perFileMetrics['dynamicWrongConfident'],
          'actualUniqueDynamicWrongConfident':
              uniqueAudioMetrics['dynamicWrongConfident'],
          'blocker': (uniqueAudioMetrics['dynamicWrongConfident'] as int) > 0,
          'previouslyCorrectBaselineCasesRetranscribed': results.where((item) {
            final comparison = item['comparisonToFrozenRaw'] as Map;
            return comparison['baselineCanonicalOutcomeCorrect'] == true &&
                item['secondPassTriggered'] == true;
          }).length,
        },
        'recommendation': recommendation,
        'limitations': [
          'Four unique human waveforms are a labeled smoke test only.',
          'No production latency or human/accent robustness claim can be extrapolated.',
          'Query Understanding is LLM-backed and can vary for identical transcripts.',
          'Dynamically hinted exact spellings are circular evidence and are downgraded to clarification when they would otherwise auto-resolve.',
        ],
      };

      expect(perFileMetrics['dynamicWrongConfident'], 0);
      expect(uniqueAudioMetrics['dynamicWrongConfident'], 0);
      for (final recordingId in ['human-smoke-004', 'human-smoke-005']) {
        final item = results.firstWhere(
          (result) => result['recordingId'] == recordingId,
        );
        expect(
          item['secondPassTriggered'],
          isFalse,
          reason: 'The existing safe human winner must not be retranscribed.',
        );
      }
      expect(
        results.every((item) => (item['top3Hints'] as List).length <= 3),
        isTrue,
      );
      expect(results.every((item) => (item['sttCalls'] as int) <= 2), isTrue);

      const outputPath =
          'test/eval/entity_search/human_voice_dynamic_top3_report.json';
      await File(outputPath)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      print(const JsonEncoder.withIndent('  ').convert(report));
    } finally {
      speech.dispose();
      await db.close();
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Map<String, Object?> _metrics(List<Map<String, Object?>> results) {
  final scorable = results
      .where((item) => item['canonicalScorable'] == true)
      .toList(growable: false);
  final triggered = results
      .where((item) => item['secondPassTriggered'] == true)
      .toList(growable: false);
  final deltas = <String, int>{
    'IMPROVED': 0,
    'UNCHANGED': 0,
    'WORSENED': 0,
    'UNSCORABLE_AMBIGUOUS': 0,
  };
  final baselineOutcomes = <String, int>{};
  final dynamicOutcomes = <String, int>{};
  for (final item in results) {
    final comparison = item['comparisonToFrozenRaw'] as Map;
    final delta = comparison['delta'] as String;
    deltas[delta] = (deltas[delta] ?? 0) + 1;
    final baseline = comparison['baselineOutcome'] as String;
    final dynamic = comparison['dynamicOutcome'] as String;
    baselineOutcomes[baseline] = (baselineOutcomes[baseline] ?? 0) + 1;
    dynamicOutcomes[dynamic] = (dynamicOutcomes[dynamic] ?? 0) + 1;
  }
  final baselineStt = results
      .map((item) => (item['latencyMs'] as Map)['frozenBaselineStt'])
      .whereType<num>();
  final baselineTotal = results
      .map((item) => (item['latencyMs'] as Map)['frozenBaselineTotal'])
      .whereType<num>();
  final pass1Stt = results
      .map((item) => (item['latencyMs'] as Map)['dynamicPass1Stt'])
      .whereType<num>();
  final pass1Total = results
      .map((item) => (item['latencyMs'] as Map)['dynamicPass1Total'])
      .whereType<num>();
  final secondPassStt = triggered
      .map((item) => (item['latencyMs'] as Map)['dynamicSecondPassStt'])
      .whereType<num>();
  final dynamicTotal = results
      .map((item) => (item['latencyMs'] as Map)['dynamicTotal'])
      .whereType<num>();

  return {
    'files': results.length,
    'canonicalScorable': scorable.length,
    'baselineCanonicalCorrect': scorable.where((item) {
      final comparison = item['comparisonToFrozenRaw'] as Map;
      return comparison['baselineCanonicalOutcomeCorrect'] == true;
    }).length,
    'dynamicCanonicalCorrect': scorable.where((item) {
      final comparison = item['comparisonToFrozenRaw'] as Map;
      return comparison['dynamicCanonicalOutcomeCorrect'] == true;
    }).length,
    'dynamicWrongConfident': scorable.where((item) {
      final comparison = item['comparisonToFrozenRaw'] as Map;
      return comparison['dynamicWrongConfident'] == true;
    }).length,
    'secondPassTriggers': triggered.length,
    'secondPassTriggerRate': triggered.length / results.length,
    'averageSttCallsPerQuery':
        results
            .map((item) => item['sttCalls'] as int)
            .reduce((left, right) => left + right) /
        results.length,
    'recoveryDelta': deltas,
    'baselineOutcomes': baselineOutcomes,
    'dynamicOutcomes': dynamicOutcomes,
    'circularEvidenceGuardsApplied': results.where((item) {
      final finalEvaluation = item['final'] as Map;
      final evidence = finalEvaluation['dynamicCircularEvidence'];
      return evidence is Map && evidence['guardApplied'] == true;
    }).length,
    'latencyMs': {
      'averageFrozenBaselineStt': _mean(baselineStt),
      'averageFrozenBaselineTotal': _mean(baselineTotal),
      'averageDynamicPass1Stt': _mean(pass1Stt),
      'averageDynamicPass1Total': _mean(pass1Total),
      'averageDynamicSecondPassSttWhenTriggered': _mean(secondPassStt),
      'averageDynamicTotal': _mean(dynamicTotal),
    },
  };
}

String _recommendation(Map<String, Object?> uniqueMetrics) {
  if ((uniqueMetrics['dynamicWrongConfident'] as int) > 0 ||
      ((uniqueMetrics['recoveryDelta'] as Map)['WORSENED'] as int) > 0) {
    return 'UNSAFE — DO NOT USE';
  }
  final baseline = uniqueMetrics['baselineCanonicalCorrect'] as int;
  final dynamic = uniqueMetrics['dynamicCanonicalCorrect'] as int;
  final improved = (uniqueMetrics['recoveryDelta'] as Map)['IMPROVED'] as int;
  if (dynamic > baseline && improved > 0) {
    return 'PROMISING — COLLECT MORE HUMAN AUDIO';
  }
  return 'NO BENEFIT — KEEP BIASING SHELVED';
}

double? _mean(Iterable<num> values) {
  final list = values.map((value) => value.toDouble()).toList(growable: false);
  if (list.isEmpty) return null;
  return list.reduce((left, right) => left + right) / list.length;
}
