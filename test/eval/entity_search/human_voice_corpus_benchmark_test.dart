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

import 'human_voice_dynamic_top3_evaluator.dart';
import 'human_voice_fixture_validator.dart';
import 'human_voice_smoke_evaluator.dart';

void main() {
  test('ES-8B validates and benchmarks the real-human corpus', () async {
    await dotenv.load(fileName: '.env');
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    expect(apiKey, isNotNull);
    expect(apiKey, isNotEmpty);

    final manifestFile = File(
      'test/eval/entity_search/human_voice_smoke_manifest.json',
    );
    final manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final fixtures = (manifest['fixtures'] as List)
        .cast<Map<String, dynamic>>();
    expect(manifest['schemaVersion'], 'ES8B_HUMAN_FIXTURE_V1');
    expect(fixtures, isNotEmpty);

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
      final validation = await const HumanVoiceFixtureValidator().validate(
        manifest: manifest,
        liveEntities: entities,
      );
      expect(
        validation['valid'],
        isTrue,
        reason: const JsonEncoder.withIndent('  ')
            .convert(validation['issues']),
      );
      expect(validation['fixturesSilentlyDropped'], 0);

      const noOp = NoOpAudioPreprocessor();
      for (final fixture in fixtures) {
        final file = File(fixture['filePath'] as String);
        final original = await file.readAsBytes();
        final processed = await noOp.process(
          inputBytes: original,
          filename: file.uri.pathSegments.last,
          strategy: AudioPreprocessingStrategy.raw,
        );
        expect(processed.changed, isFalse);
        expect(processed.bytes, orderedEquals(original));
        expect(await file.readAsBytes(), orderedEquals(original));
      }

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
        results.add(await evaluator.evaluate(fixture: fixture));
      }

      final duplicateMembers =
          ((validation['audioInventory'] as Map)['DUPLICATE_GROUPS'] as List)
              .whereType<Map>()
              .expand((group) {
                final members = (group['members'] as List)
                    .whereType<String>()
                    .toList();
                return members.skip(1);
              })
              .toSet();
      final uniqueResults = results
          .where((item) => !duplicateMembers.contains(item['recordingId']))
          .toList(growable: false);
      final perFileMetrics = _metrics(results);
      final uniqueAudioMetrics = _metrics(uniqueResults);
      final wrongConfidentCases = _wrongConfidentCases(results);
      final newlyIntroducedWrongConfident = wrongConfidentCases
          .where((item) => item['newlyIntroducedByDynamic'] == true)
          .toList(growable: false);
      final triggeredRecoveries = results
          .where((item) => item['secondPassTriggered'] == true)
          .map(_triggerSummary)
          .toList(growable: false);
      final recommendation = _recommendation(uniqueAudioMetrics);
      final permanentRegression = fixtures.firstWhere(
        (fixture) => fixture['fixtureId'] == 'human-smoke-001',
      )['permanentRegression'];
      expect(permanentRegression, isA<Map>());
      expect(
        (permanentRegression as Map)['regressionId'],
        'ES8A_ASIM1_DYNAMIC_TOP3_RECOVERY',
      );
      expect(permanentRegression['frozenRawOutcome'], 'NO_MATCH');
      expect(
        permanentRegression['dynamicTop3Outcome'],
        'CORRECT_CLARIFICATION',
      );

      final report = <String, Object?>{
        'phase': 'ES-8B',
        'architectureStatus': 'FROZEN_FOR_HUMAN_DATA_COLLECTION',
        'humanBenchmarkStatus': 'LABELED_SMOKE_TEST_ONLY',
        'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'oneCommandWorkflow': 'flutter test test/eval/entity_search/human_voice_corpus_benchmark_test.dart --reporter expanded',
        'strategies': ['RAW_BASELINE', 'RAW_DYNAMIC_TOP3'],
        'productionVoiceRoutingChanged': false,
        'runtimeDefaultsChanged': false,
        'entitySearchRankingChanged': false,
        'resolverThresholdsChanged': false,
        'audioPreprocessing': {
          'implementation': 'NoOpAudioPreprocessor',
          'enabled': false,
        },
        'staticSttContextEnabled': false,
        'dynamicTop3ProductionEnabled': false,
        'top5OrTop10Tested': false,
        'manifest': {
          'path': manifestFile.path,
          'schemaVersion': manifest['schemaVersion'],
          'fixtureCount': fixtures.length,
        },
        'validation': validation,
        'corpusCoverage': validation['coverage'],
        'collectionMilestones': validation['collectionMilestones'],
        'entityCoverageGuidance': validation['entityCoverageGuidance'],
        'perFileMetrics': perFileMetrics,
        'uniqueAudioMetrics': uniqueAudioMetrics,
        'primaryMetricsBasis': 'UNIQUE_AUDIO_SHA256_DEDUPLICATED',
        'wrongConfidentHumanResults': wrongConfidentCases,
        'newlyIntroducedWrongConfidentHumanResults':
            newlyIntroducedWrongConfident,
        'biasRecoveryReport': triggeredRecoveries,
        'permanentRegressions': [permanentRegression],
        'results': results,
        'recommendation': recommendation,
        'limitations': [
          'Collection milestones are engineering targets, not statistical proof thresholds.',
          'The current four unique recordings and one speaker remain a labeled smoke test only.',
          'No general human/accent robustness or production-latency claim is supported.',
        ],
      };
      expect(newlyIntroducedWrongConfident, isEmpty);

      const jsonPath =
          'test/eval/entity_search/human_voice_corpus_benchmark_report.json';
      const markdownPath =
          'test/eval/entity_search/HUMAN_VOICE_CORPUS_BENCHMARK_REPORT.md';
      await File(jsonPath)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      await File(markdownPath).writeAsString(_markdown(report));
      print(
        const JsonEncoder.withIndent('  ').convert({
          'validation': {
            'valid': validation['valid'],
            'errors': validation['errors'],
            'warnings': validation['warnings'],
          },
          'uniqueAudioMetrics': uniqueAudioMetrics,
          'recommendation': recommendation,
          'reports': [jsonPath, markdownPath],
        }),
      );
    } finally {
      speech.dispose();
      await db.close();
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

Map<String, Object?> _metrics(List<Map<String, Object?>> results) {
  final scorable = results
      .where((item) => item['canonicalScorable'] == true)
      .toList(growable: false);
  final rawEvaluations = results
      .map((item) => item['pass1'] as Map)
      .toList(growable: false);
  final dynamicEvaluations = results
      .map((item) => item['final'] as Map)
      .toList(growable: false);
  final rawScorable = scorable
      .map((item) => item['pass1'] as Map)
      .toList(growable: false);
  final dynamicScorable = scorable
      .map((item) => item['final'] as Map)
      .toList(growable: false);
  final deltas = <String, int>{
    'IMPROVED': 0,
    'UNCHANGED': 0,
    'WORSENED': 0,
    'UNSCORABLE_AMBIGUOUS': 0,
  };
  for (final result in results) {
    final delta = (result['comparisonToRaw'] as Map)['delta'] as String;
    deltas[delta] = (deltas[delta] ?? 0) + 1;
  }
  final triggerCount = results
      .where((item) => item['secondPassTriggered'] == true)
      .length;
  final rawTotalLatency = results
      .map((item) => ((item['pass1'] as Map)['latencyMs'] as Map)['total'])
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);
  final rawSttLatency = results
      .map((item) => ((item['pass1'] as Map)['latencyMs'] as Map)['stt'])
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);
  final dynamicTotalLatency = results
      .map((item) => (item['latencyMs'] as Map)['dynamicTotal'])
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);

  return {
    'files': results.length,
    'canonicalScorable': scorable.length,
    'RAW_BASELINE': _strategyMetrics(rawEvaluations, rawScorable),
    'RAW_DYNAMIC_TOP3': _strategyMetrics(dynamicEvaluations, dynamicScorable),
    'recoveryDelta': deltas,
    'secondPassTriggers': triggerCount,
    'secondPassTriggerRate': triggerCount / results.length,
    'averageSttCallsPerQuery':
        results
            .map((item) => item['sttCalls'] as int)
            .reduce((left, right) => left + right) /
        results.length,
    'latencyMs': {
      'RAW_BASELINE': _latencyStats(rawTotalLatency),
      'RAW_BASELINE_STT': _latencyStats(rawSttLatency),
      'RAW_DYNAMIC_TOP3': _latencyStats(dynamicTotalLatency),
    },
  };
}

Map<String, Object?> _strategyMetrics(
  List<Map> evaluations,
  List<Map> scorable,
) {
  final wers = evaluations
      .map((item) => item['wer'])
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);
  final cers = evaluations
      .map((item) => item['cer'])
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);
  final outcomes = <String, int>{
    'CORRECT_CONFIDENT': 0,
    'CORRECT_CLARIFICATION': 0,
    'WRONG_CONFIDENT': 0,
    'WRONG_CLARIFICATION': 0,
    'NO_MATCH': 0,
  };
  for (final item in evaluations) {
    final outcome = item['finalOutcome'] as String;
    outcomes[outcome] = (outcomes[outcome] ?? 0) + 1;
  }
  return {
    'canonicalCorrect': scorable
        .where((item) => item['canonicalOutcomeCorrect'] == true)
        .length,
    'canonicalScorable': scorable.length,
    'canonicalCorrectRate': scorable.isEmpty
        ? null
        : scorable
                  .where((item) => item['canonicalOutcomeCorrect'] == true)
                  .length /
              scorable.length,
    'outcomes': outcomes,
    'meanWer': _mean(wers),
    'meanCer': _mean(cers),
  };
}

List<Map<String, Object?>> _wrongConfidentCases(
  List<Map<String, Object?>> results,
) {
  final cases = <Map<String, Object?>>[];
  for (final result in results) {
    final raw = result['pass1'] as Map;
    final dynamic = result['final'] as Map;
    if (raw['wrongConfident'] == true) {
      cases.add(_wrongCase(result, raw, 'RAW_BASELINE', false));
    }
    if (dynamic['wrongConfident'] == true) {
      cases.add(
        _wrongCase(
          result,
          dynamic,
          'RAW_DYNAMIC_TOP3',
          raw['wrongConfident'] != true,
        ),
      );
    }
  }
  return cases;
}

Map<String, Object?> _wrongCase(
  Map<String, Object?> result,
  Map evaluation,
  String strategy,
  bool newlyIntroduced,
) => {
  'fixtureId': result['recordingId'],
  'filePath': result['audioFile'],
  'strategy': strategy,
  'transcript': (evaluation['transcription'] as Map)['transcript'],
  'expectedCanonicalId': result['expectedCanonicalEntityId'],
  'expectedCanonicalName': result['expectedCanonicalEntityName'],
  'resolvedCanonicalIds':
      (evaluation['resolver'] as Map)['finalCanonicalEntityIds'],
  'resolvedCanonicalNames':
      (evaluation['resolver'] as Map)['finalCanonicalEntityNames'],
  'newlyIntroducedByDynamic': newlyIntroduced,
};

Map<String, Object?> _triggerSummary(Map<String, Object?> result) {
  final pass1 = result['pass1'] as Map;
  final pass2 = result['pass2'] as Map;
  final finalEvaluation = result['final'] as Map;
  final circularEvidence = finalEvaluation['dynamicCircularEvidence'];
  return {
    'fixtureId': result['recordingId'],
    'filePath': result['audioFile'],
    'pass1Transcript': (pass1['transcription'] as Map)['transcript'],
    'triggerReason': (result['triggerPolicy'] as Map)['reason'],
    'top3Hints': result['top3Hints'],
    'pass2Transcript': (pass2['transcription'] as Map)['transcript'],
    'rawOutcome': pass1['finalOutcome'],
    'dynamicOutcome': finalEvaluation['finalOutcome'],
    'delta': (result['comparisonToRaw'] as Map)['delta'],
    'circularEvidenceConfirmationRequired':
        circularEvidence is Map && circularEvidence['guardApplied'] == true,
    if (circularEvidence is Map) 'circularEvidence': circularEvidence,
  };
}

String _recommendation(Map<String, Object?> uniqueMetrics) {
  final raw = uniqueMetrics['RAW_BASELINE'] as Map;
  final dynamic = uniqueMetrics['RAW_DYNAMIC_TOP3'] as Map;
  final delta = uniqueMetrics['recoveryDelta'] as Map;
  final dynamicWrong = (dynamic['outcomes'] as Map)['WRONG_CONFIDENT'] as int;
  final rawWrong = (raw['outcomes'] as Map)['WRONG_CONFIDENT'] as int;
  if (dynamicWrong > rawWrong || (delta['WORSENED'] as int) > 0) {
    return 'UNSAFE — DO NOT USE';
  }
  if ((dynamic['canonicalCorrect'] as int) > (raw['canonicalCorrect'] as int) &&
      (delta['IMPROVED'] as int) > 0) {
    return 'PROMISING — COLLECT MORE HUMAN AUDIO';
  }
  return 'NO BENEFIT — KEEP BIASING SHELVED';
}

Map<String, Object?> _latencyStats(List<double> values) => {
  'average': _mean(values),
  'p50': _percentile(values, 0.50),
  'p95': _percentile(values, 0.95),
};

double? _mean(List<double> values) => values.isEmpty
    ? null
    : values.reduce((left, right) => left + right) / values.length;

double? _percentile(List<double> values, double percentile) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final index = max(0, (percentile * sorted.length).ceil() - 1);
  return sorted[index];
}

String _markdown(Map<String, Object?> report) {
  final validation = report['validation'] as Map;
  final inventory = validation['audioInventory'] as Map;
  final uniqueMetrics = report['uniqueAudioMetrics'] as Map;
  final perFileMetrics = report['perFileMetrics'] as Map;
  final raw = uniqueMetrics['RAW_BASELINE'] as Map;
  final dynamic = uniqueMetrics['RAW_DYNAMIC_TOP3'] as Map;
  final recovery = uniqueMetrics['recoveryDelta'] as Map;
  final latency = uniqueMetrics['latencyMs'] as Map;
  final rawLatency = latency['RAW_BASELINE'] as Map;
  final dynamicLatency = latency['RAW_DYNAMIC_TOP3'] as Map;
  final coverage = (report['corpusCoverage'] as Map)['uniqueAudio'] as Map;
  final milestones = (report['collectionMilestones'] as List).whereType<Map>();
  final wrong = report['wrongConfidentHumanResults'] as List;
  final newlyIntroducedWrong =
      report['newlyIntroducedWrongConfidentHumanResults'] as List;
  final triggers = (report['biasRecoveryReport'] as List).whereType<Map>();
  final buffer = StringBuffer()
    ..writeln('# Human Voice Corpus Benchmark')
    ..writeln()
    ..writeln('`HUMAN_BENCHMARK_STATUS = LABELED_SMOKE_TEST_ONLY`')
    ..writeln()
    ..writeln('Architecture status: **FROZEN FOR HUMAN DATA COLLECTION**.')
    ..writeln()
    ..writeln('Recommendation: **${report['recommendation']}**')
    ..writeln()
    ..writeln('## Fixture validation')
    ..writeln()
    ..writeln('| Measure | Value |')
    ..writeln('|---|---:|')
    ..writeln('| Valid | ${validation['valid']} |')
    ..writeln('| Errors | ${validation['errors']} |')
    ..writeln('| Warnings | ${validation['warnings']} |')
    ..writeln(
      '| Fixtures silently dropped | ${validation['fixturesSilentlyDropped']} |',
    )
    ..writeln('| TOTAL_FILES | ${inventory['TOTAL_FILES']} |')
    ..writeln('| UNIQUE_AUDIO_FILES | ${inventory['UNIQUE_AUDIO_FILES']} |')
    ..writeln(
      '| DUPLICATE_GROUPS | ${(inventory['DUPLICATE_GROUPS'] as List).length} |',
    )
    ..writeln()
    ..writeln('## Primary unique-audio metrics')
    ..writeln()
    ..writeln('| Metric | RAW_BASELINE | RAW_DYNAMIC_TOP3 |')
    ..writeln('|---|---:|---:|')
    ..writeln(
      '| Canonical correct | ${raw['canonicalCorrect']}/${raw['canonicalScorable']} | ${dynamic['canonicalCorrect']}/${dynamic['canonicalScorable']} |',
    )
    ..writeln(
      '| Correct confident | ${(raw['outcomes'] as Map)['CORRECT_CONFIDENT']} | ${(dynamic['outcomes'] as Map)['CORRECT_CONFIDENT']} |',
    )
    ..writeln(
      '| Correct clarification | ${(raw['outcomes'] as Map)['CORRECT_CLARIFICATION']} | ${(dynamic['outcomes'] as Map)['CORRECT_CLARIFICATION']} |',
    )
    ..writeln(
      '| WRONG_CONFIDENT | ${(raw['outcomes'] as Map)['WRONG_CONFIDENT']} | ${(dynamic['outcomes'] as Map)['WRONG_CONFIDENT']} |',
    )
    ..writeln(
      '| Wrong clarification | ${(raw['outcomes'] as Map)['WRONG_CLARIFICATION']} | ${(dynamic['outcomes'] as Map)['WRONG_CLARIFICATION']} |',
    )
    ..writeln(
      '| No-match | ${(raw['outcomes'] as Map)['NO_MATCH']} | ${(dynamic['outcomes'] as Map)['NO_MATCH']} |',
    )
    ..writeln(
      '| Mean WER | ${_percent(raw['meanWer'])} | ${_percent(dynamic['meanWer'])} |',
    )
    ..writeln(
      '| Mean CER | ${_percent(raw['meanCer'])} | ${_percent(dynamic['meanCer'])} |',
    )
    ..writeln()
    ..writeln(
      'Recovery: **${recovery['IMPROVED']} improved, ${recovery['UNCHANGED']} unchanged, ${recovery['WORSENED']} worsened**.',
    )
    ..writeln()
    ..writeln(
      'Second-pass trigger rate: ${_percent(uniqueMetrics['secondPassTriggerRate'])}; average STT calls/query: ${(uniqueMetrics['averageSttCallsPerQuery'] as num).toStringAsFixed(3)}.',
    )
    ..writeln()
    ..writeln('| Total latency | RAW_BASELINE | RAW_DYNAMIC_TOP3 |')
    ..writeln('|---|---:|---:|')
    ..writeln(
      '| Average | ${_milliseconds(rawLatency['average'])} | ${_milliseconds(dynamicLatency['average'])} |',
    )
    ..writeln(
      '| p50 | ${_milliseconds(rawLatency['p50'])} | ${_milliseconds(dynamicLatency['p50'])} |',
    )
    ..writeln(
      '| p95 | ${_milliseconds(rawLatency['p95'])} | ${_milliseconds(dynamicLatency['p95'])} |',
    )
    ..writeln()
    ..writeln(
      'Per-file metrics are retained in JSON (${perFileMetrics['files']} files); primary metrics are SHA-256-deduplicated.',
    )
    ..writeln()
    ..writeln('## WRONG_CONFIDENT safety')
    ..writeln()
    ..writeln(
      wrong.isEmpty
          ? '**No wrong-confident human results.**'
          : '**${wrong.length} wrong-confident human results — inspect individually below.**',
    )
    ..writeln();
  for (final item in wrong.whereType<Map>()) {
    buffer.writeln(
      '- `${item['fixtureId']}` / `${item['strategy']}`: ${item['transcript']} → ${item['resolvedCanonicalNames']}',
    );
  }
  buffer
    ..writeln()
    ..writeln('### Newly introduced by RAW_DYNAMIC_TOP3')
    ..writeln()
    ..writeln(
      newlyIntroducedWrong.isEmpty
          ? '**None.**'
          : '**${newlyIntroducedWrong.length} newly introduced wrong-confident results — listed individually below.**',
    );
  for (final item in newlyIntroducedWrong.whereType<Map>()) {
    buffer.writeln(
      '- `${item['fixtureId']}`: ${item['transcript']} → ${item['resolvedCanonicalNames']}',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Bias recovery triggers')
    ..writeln();
  if (triggers.isEmpty) buffer.writeln('No second-pass triggers.');
  for (final item in triggers) {
    buffer
      ..writeln('### ${item['fixtureId']}')
      ..writeln()
      ..writeln('- Pass 1: ${item['pass1Transcript']}')
      ..writeln('- Trigger: `${item['triggerReason']}`')
      ..writeln('- Top 3: ${(item['top3Hints'] as List).join('; ')}')
      ..writeln('- Pass 2: ${item['pass2Transcript']}')
      ..writeln(
        '- Outcome: `${item['rawOutcome']} → ${item['dynamicOutcome']}` (`${item['delta']}`)',
      )
      ..writeln(
        '- `CIRCULAR_EVIDENCE_CONFIRMATION_REQUIRED = ${item['circularEvidenceConfirmationRequired']}`',
      )
      ..writeln();
  }
  buffer
    ..writeln('## Corpus coverage — unique audio')
    ..writeln()
    ..writeln('```json')
    ..writeln(const JsonEncoder.withIndent('  ').convert(coverage))
    ..writeln('```')
    ..writeln()
    ..writeln('## Collection milestones')
    ..writeln()
    ..writeln(
      '| Milestone | Unique recordings | Speakers | Remaining | Reached |',
    )
    ..writeln('|---|---:|---:|---:|---|');
  for (final milestone in milestones) {
    buffer.writeln(
      '| ${milestone['milestone']} | ${milestone['currentUniqueRecordings']}/${milestone['targetUniqueRecordings']} | ${milestone['currentSpeakers']}/${milestone['targetSpeakers']} | ${milestone['uniqueRecordingsRemaining']} recordings, ${milestone['speakersRemaining']} speakers | ${milestone['reached']} |',
    );
  }
  buffer
    ..writeln()
    ..writeln(
      'These are engineering collection milestones, not statistical proof thresholds.',
    )
    ..writeln()
    ..writeln('## Permanent regression')
    ..writeln()
    ..writeln(
      '`asim1.wav` remains `ES8A_ASIM1_DYNAMIC_TOP3_RECOVERY`: frozen RAW “Alex\'s” → `NO_MATCH`; dynamic “Alūksne Rally” → guarded `CORRECT_CLARIFICATION`.',
    )
    ..writeln()
    ..writeln('## One-command workflow')
    ..writeln()
    ..writeln('```bash')
    ..writeln(report['oneCommandWorkflow'])
    ..writeln('```')
    ..writeln()
    ..writeln(
      'The command validates every fixture, runs RAW and dynamic top-3, and regenerates this Markdown file plus the machine-readable JSON report.',
    );
  return buffer.toString();
}

String _percent(Object? value) =>
    value is num ? '${(value.toDouble() * 100).toStringAsFixed(2)}%' : 'n/a';

String _milliseconds(Object? value) =>
    value is num ? '${value.toDouble().toStringAsFixed(1)} ms' : 'n/a';
