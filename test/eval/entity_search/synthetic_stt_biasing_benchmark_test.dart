// ignore_for_file: avoid_print
@Tags(['live-db', 'live-api', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/controlled_fallback_entity_resolver.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_lookup_adapter.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser_factory.dart';
import 'package:ai_rally_search/services/speech/openai_speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_stt_audio_fixture_generator.dart';
import 'synthetic_stt_biasing_corpus.dart';
import 'synthetic_stt_biasing_evaluator.dart';

void main() {
  test('ES-6A synthetic STT biasing benchmark', () async {
    await dotenv.load(fileName: '.env');
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    expect(apiKey, isNotNull);
    expect(apiKey, isNotEmpty);
    final db = DatabaseService();
    final entities = await MySqlEntitySearchDataSource(database: db)
        .loadEntities();
    final corpus = SyntheticSttCorpusBuilder().build(entities);
    expect(corpus.entities.length, 140);
    expect(corpus.utterances.length, 280);

    const fixturePath = 'test/eval/audio/es6a';
    final audioDirectory = Directory(fixturePath);
    final audioStats = await SyntheticSttAudioFixtureGenerator(audioDirectory)
        .generate(corpus);

    final negatives = _negativeCorpus(entities, corpus);
    await SyntheticSttAudioFixtureGenerator(audioDirectory).generate(
      SyntheticSttCorpus(
        entities: negatives.map((item) => item.target).toList(),
        utterances: negatives,
      ),
    );

    final service = InMemoryEntitySearchService.fromEntities(entities);
    final legacy = DatabaseEntityLookupRepository(dbService: db);
    final resolver = ControlledFallbackEntityResolver(
      legacyResolver: DatabaseEntityResolver(repository: legacy),
      entitySearchResolver: DatabaseEntityResolver(
        repository: EntitySearchLookupAdapter(
          searchService: service,
          cityFallback: legacy,
        ),
      ),
      config: const EntitySearchFallbackConfig(
        mode: EntitySearchFallbackMode.fallback,
      ),
    );
    final speech = OpenAiSpeechToTextService(
      config: SpeechConfig(
        providerType: SpeechProviderType.openAiDirectDev,
        endpointUrl: 'https://api.openai.com/v1/audio/transcriptions',
        apiKey: apiKey,
        model: 'gpt-transcribe',
        timeout: const Duration(seconds: 45),
      ),
    );
    expect(speech.transcriptionCapabilities.keywordHints, isTrue);
    final evaluator = SyntheticSttBiasingEvaluator(
      speech: speech,
      parser: LlmQueryParserFactory.create(),
      resolver: resolver,
      entitySearch: service,
      cacheFile: File('test/eval/entity_search/es6a_transcript_cache.json'),
    );
    final configuredMax = int.tryParse(
      Platform.environment['ES6A_MAX_AUDIO_FILES'] ?? '',
    );
    final results = await evaluator.evaluate(
      corpus.utterances,
      audioDirectory,
      maxAudioFiles: configuredMax,
      onProgress: (done, total) => print('ES-6A audio $done/$total'),
    );
    final biasNames = corpus.entities.map((e) => e.canonicalName).toList();
    final personBiasNames = <String>[
      ...entities
          .where(
            (entity) =>
                entity.entityType == SearchEntityType.person &&
                entity.canonicalName == 'Paweł Molgo',
          )
          .map((entity) => entity.canonicalName),
      ...corpus.entities
          .where((entity) => entity.entityType == SearchEntityType.person)
          .map((entity) => entity.canonicalName),
    ].where((name) => name != 'Josh Moffett').toSet().take(10).toList();
    final negativeCases = <NegativeBiasCase>[
      NegativeBiasCase(
        id: 'negative_all_rallies',
        spokenText: negatives[0].text,
        audioFile: File('$fixturePath/${negatives[0].id}_clean.wav'),
        biasVocabulary: biasNames
            .where(
              (name) =>
                  corpus.entities
                      .firstWhere((e) => e.canonicalName == name)
                      .entityType ==
                  SearchEntityType.rally,
            )
            .take(10)
            .toList(),
      ),
      NegativeBiasCase(
        id: 'negative_another_rally',
        spokenText: negatives[1].text,
        audioFile: File('$fixturePath/${negatives[1].id}_clean.wav'),
        biasVocabulary: biasNames.take(10).toList(),
      ),
      NegativeBiasCase(
        id: 'negative_wrong_person',
        spokenText: negatives[2].text,
        audioFile: File('$fixturePath/${negatives[2].id}_clean.wav'),
        biasVocabulary: personBiasNames,
        expectedSpokenCanonicalName: 'Josh Moffett',
      ),
    ];
    final negativeResults = await evaluator.evaluateNegativeBias(negativeCases);
    final summary = _summarize(results, negativeResults);
    final actualSttAudioSeconds = _actualSttAudioSeconds(
      results,
      audioDirectory,
      negativeCases,
      negativeResults,
    );
    final report = {
      'phase': 'ES-6A',
      'humanVoiceBenchmark': 'BLOCKED',
      'syntheticOnly': true,
      'seed': syntheticSttBiasingSeed,
      'corpus': {
        'entities': {
          for (final type in SearchEntityType.values)
            type.name: corpus.entities
                .where((e) => e.entityType == type)
                .length,
        },
        'entityNames': {
          for (final type in SearchEntityType.values)
            type.name: corpus.entities
                .where((e) => e.entityType == type)
                .map((e) => e.canonicalName)
                .toList(),
        },
        'utterances': corpus.utterances.length,
        'audioFilesExpected': corpus.utterances.length * 2,
        'audioConditions': ['clean', 'noisy'],
        'voices': ['Samantha', 'Daniel'],
        'speakingRatesWpm': [165, 180, 205, 210],
        'noisyPerturbations': [
          'deterministic low background noise',
          'volume reduction',
          'mild dynamic compression',
          'leading/trailing silence',
        ],
        'manifest': corpus.utterances.map((e) => e.toJson()).toList(),
      },
      'provider': {
        'stt': 'OpenAI gpt-transcribe',
        'capabilitiesUsed': ['prompt', 'keywords[]', 'languages[]'],
        'tts': 'macOS say local system TTS',
      },
      'audioGeneration': audioStats.toJson(),
      'results': summary,
      'negativeBias': {
        'cases': negativeResults,
        'biasInducedEntityErrors': negativeResults
            .where((item) => item['biasInducedEntityError'] == true)
            .length,
      },
      'cost': {
        'ttsApiCalls': 0,
        'localTtsSynthesesForFullCorpus': corpus.utterances.length * 2,
        'syntheticAudioDurationSeconds': audioStats.totalDurationMs / 1000,
        'baselineSttCalls':
            results
                .where((e) => e.strategy == SyntheticSttStrategy.baseline)
                .length +
            negativeCases.length,
        'staticContextSttCalls': results
            .where((e) => e.strategy == SyntheticSttStrategy.staticContext)
            .length,
        'dynamicSecondPassSttCalls':
            results.where((e) => e.secondPassTriggered).length +
            negativeResults.length,
        'sttCalls':
            _actualSttCalls(results) +
            negativeCases.length +
            negativeResults.length,
        'measuredSttAudioSeconds': actualSttAudioSeconds,
        'gptTranscribePricePerMinuteUsd': 0.0045,
        'estimatedExperimentalSttCostUsd': actualSttAudioSeconds / 60 * 0.0045,
        'productionCostExtrapolation': null,
      },
      'historicalTranscriptRegression': {
        'audioBenchmark': false,
        'inputs': [
          'aluksni',
          'aluksnay',
          'aluksney',
          'alux new',
          'a looks nay',
          'eluksne',
          'aluknse',
          'pawel malgo',
          'shea brain',
          'donny gall',
          'kemel berg',
          'dushniki',
        ],
        'report': 'test/eval/entity_search/known_real_device_report.json',
      },
      'limitations': [
        'Synthetic TTS is not human speech or accent validation.',
        'Dynamic-biased STT output is causally influenced by Entity Search and is not independent confirmation.',
        if (configuredMax != null)
          'Execution was explicitly limited to $configuredMax audio files.',
      ],
      'details': results.map((e) => e.toJson()).toList(),
    };
    const reportPath =
        'test/eval/entity_search/synthetic_stt_biasing_report.json';
    await File(reportPath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    print(const JsonEncoder.withIndent('  ').convert(summary));
    speech.dispose();
    await db.close();
  }, timeout: const Timeout(Duration(hours: 3)));
}

List<SyntheticSttUtterance> _negativeCorpus(
  List<CanonicalSearchEntity> source,
  SyntheticSttCorpus corpus,
) {
  final rally = corpus.entities.firstWhere(
    (e) => e.entityType == SearchEntityType.rally,
  );
  final person = corpus.entities.firstWhere(
    (e) => e.entityType == SearchEntityType.person,
  );
  return [
    SyntheticSttUtterance(
      id: 'negative_all_rallies',
      target: rally,
      text: 'show all rallies',
      templateIndex: 0,
    ),
    SyntheticSttUtterance(
      id: 'negative_another_rally',
      target: rally,
      text: 'show another rally',
      templateIndex: 1,
    ),
    SyntheticSttUtterance(
      id: 'negative_josh_moffett',
      target: person,
      text: 'show Josh Moffett',
      templateIndex: 0,
    ),
  ];
}

Map<String, Object?> _summarize(
  List<SyntheticSttEvaluationResult> results,
  List<Map<String, Object?>> negatives,
) {
  final baseline = {
    for (final result in results.where(
      (r) => r.strategy == SyntheticSttStrategy.baseline,
    ))
      '${result.sampleId}|${result.audioCondition}': result,
  };
  return {
    for (final strategy in SyntheticSttStrategy.values)
      strategy.name: _strategySummary(
        results.where((r) => r.strategy == strategy).toList(),
        baseline,
        negatives
            .where(
              (item) =>
                  item['topK'] ==
                  switch (strategy) {
                    SyntheticSttStrategy.dynamicTop3 => 3,
                    SyntheticSttStrategy.dynamicTop5 => 5,
                    SyntheticSttStrategy.dynamicTop10 => 10,
                    _ => -1,
                  },
            )
            .toList(),
      ),
  };
}

Map<String, Object?> _strategySummary(
  List<SyntheticSttEvaluationResult> values,
  Map<String, SyntheticSttEvaluationResult> baseline,
  List<Map<String, Object?>> negatives,
) {
  if (values.isEmpty) return {'cases': 0};
  final totalLatency = values.map((e) => e.totalLatencyMs).toList()..sort();
  var positiveBiasErrors = 0;
  for (final value in values) {
    final original = baseline['${value.sampleId}|${value.audioCondition}'];
    if (original != null &&
        !original.wrongConfident &&
        ((original.canonicalAt1 && !value.canonicalAt1) ||
            value.wrongConfident)) {
      positiveBiasErrors++;
    }
  }
  return {
    'cases': values.length,
    'canonicalAccuracy':
        values.where((e) => e.canonicalAt1).length / values.length,
    'canonicalRecallAt1':
        values.where((e) => e.canonicalAt1).length / values.length,
    'correctConfident': values.where((e) => e.correctConfident).length,
    'clarification': values.where((e) => e.clarification).length,
    'noMatch': values.where((e) => e.noMatch).length,
    'wrongConfident': values.where((e) => e.wrongConfident).length,
    'secondPassTriggerRate':
        values.where((e) => e.secondPassTriggered).length / values.length,
    'averageSttCallsPerQuery':
        values.map((e) => e.sttCalls).reduce((a, b) => a + b) / values.length,
    'averageSttLatencyMs':
        values.map((e) => e.sttLatencyMs).reduce((a, b) => a + b) /
        values.length,
    'averageTotalLatencyMs':
        totalLatency.reduce((a, b) => a + b) / values.length,
    'p95TotalLatencyMs':
        totalLatency[min(
          totalLatency.length - 1,
          (totalLatency.length * .95).floor(),
        )],
    'wer': values.map((e) => e.wer).reduce((a, b) => a + b) / values.length,
    'cer': values.map((e) => e.cer).reduce((a, b) => a + b) / values.length,
    'biasInducedEntityErrors':
        positiveBiasErrors +
        negatives.where((e) => e['biasInducedEntityError'] == true).length,
    'cleanCanonicalAccuracy': _conditionAccuracy(values, 'clean'),
    'noisyCanonicalAccuracy': _conditionAccuracy(values, 'noisy'),
  };
}

double _conditionAccuracy(
  List<SyntheticSttEvaluationResult> values,
  String condition,
) {
  final selected = values.where((e) => e.audioCondition == condition).toList();
  return selected.isEmpty
      ? 0
      : selected.where((e) => e.canonicalAt1).length / selected.length;
}

int _actualSttCalls(List<SyntheticSttEvaluationResult> results) {
  final baseline = results
      .where((e) => e.strategy == SyntheticSttStrategy.baseline)
      .length;
  final staticCalls = results
      .where((e) => e.strategy == SyntheticSttStrategy.staticContext)
      .length;
  final second = results.where((e) => e.secondPassTriggered).length;
  return baseline + staticCalls + second;
}

double _actualSttAudioSeconds(
  List<SyntheticSttEvaluationResult> results,
  Directory directory,
  List<NegativeBiasCase> negativeCases,
  List<Map<String, Object?>> negativeResults,
) {
  var seconds = 0.0;
  for (final baseline in results.where(
    (e) => e.strategy == SyntheticSttStrategy.baseline,
  )) {
    final file = File(
      '${directory.path}/${baseline.sampleId}_${baseline.audioCondition}.wav',
    );
    final duration = _wavSeconds(file);
    seconds += duration * 2;
    final dynamicCalls = results
        .where(
          (e) =>
              e.sampleId == baseline.sampleId &&
              e.audioCondition == baseline.audioCondition &&
              e.secondPassTriggered,
        )
        .length;
    seconds += duration * dynamicCalls;
  }
  for (final negative in negativeCases) {
    final dynamicCalls = negativeResults
        .where((result) => result['id'] == negative.id)
        .length;
    seconds += _wavSeconds(negative.audioFile) * (1 + dynamicCalls);
  }
  return seconds;
}

double _wavSeconds(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  final byteRate = data.getUint32(28, Endian.little);
  final dataBytes = data.getUint32(40, Endian.little);
  return dataBytes / byteRate;
}
