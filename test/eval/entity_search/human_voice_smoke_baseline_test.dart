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
import 'package:ai_rally_search/services/speech/openai_speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'human_voice_smoke_evaluator.dart';
import 'pcm16_wav.dart';

void main() {
  test('ES-7 records immutable five-fixture real-human RAW baseline', () async {
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
    expect(fixtures, hasLength(manifest['humanSampleCount']));
    expect(fixtures, hasLength(5));
    expect(
      fixtures.every((item) => item['referenceTranscriptRaw'] != null),
      isTrue,
    );

    final firstBytes = await File(fixtures[0]['audioFile'] as String)
        .readAsBytes();
    final thirdBytes = await File(fixtures[2]['audioFile'] as String)
        .readAsBytes();
    expect(firstBytes, orderedEquals(thirdBytes));

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
      final rallyTruthRows = await db.query('''
        SELECT event_id, event_name
        FROM rally_events
        WHERE event_name = 'Rally Alūksne 2026'
      ''');
      expect(rallyTruthRows, hasLength(1));
      expect(
        rallyTruthRows.single['event_id'].toString(),
        '0cea6942-72e3-4257-a8c1-0f8148747d82',
      );

      final maxDriverProfiles = await db.query('''
        SELECT driver_id, account_id, full_name
        FROM user_driver_profile
        WHERE LOWER(full_name) = 'max freeman'
      ''');
      final maxCodriverProfiles = await db.query('''
        SELECT codriver_id, account_id, full_name
        FROM user_codriver_profile
        WHERE LOWER(full_name) = 'max freeman'
      ''');
      expect(maxDriverProfiles, isEmpty);
      expect(maxCodriverProfiles, hasLength(1));
      expect(
        maxCodriverProfiles.single['account_id'].toString(),
        'cf3ddf9c-a64b-4f59-a5e4-5230c44b4d87',
      );
      expect(
        maxCodriverProfiles.single['codriver_id'].toString(),
        '7a633b52-950e-49ef-8cab-34cd43e99366',
      );
      final maxCodriverParticipation = await db.query('''
        SELECT DISTINCT ev.event_id
        FROM rally_entry_list entry
        INNER JOIN rally_sub_events sub
          ON entry.sub_event_id = sub.sub_event_id
        INNER JOIN rally_events ev ON sub.event_id = ev.event_id
        WHERE entry.user_co_driver_id = '7a633b52-950e-49ef-8cab-34cd43e99366'
      ''');
      expect(maxCodriverParticipation, isNotEmpty);

      final entities = await MySqlEntitySearchDataSource(database: db)
          .loadEntities();
      final indexedIds = entities.map((entity) => entity.canonicalId).toSet();
      final expectedCanonicalIds = fixtures
          .map((fixture) => fixture['canonicalEntityId'])
          .whereType<String>()
          .toSet();
      expect(indexedIds, containsAll(expectedCanonicalIds));
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

      final results = <Map<String, Object?>>[];
      final fixtureMetadata = <Map<String, Object?>>[];
      for (final fixture in fixtures) {
        final audioFile = File(fixture['audioFile'] as String);
        expect(audioFile.existsSync(), isTrue);
        final bytes = await audioFile.readAsBytes();
        final wav = Pcm16Wav.decode(bytes);
        fixtureMetadata.add({
          ...fixture,
          ...wav.diagnostics(fileSizeBytes: bytes.length),
          'originalImmutable': true,
          'byteIdenticalDuplicateVerified':
              fixture['duplicateAudioOf'] == null ||
                  fixture['recordingId'] == 'human-smoke-001'
              ? false
              : bytes.length == firstBytes.length &&
                    List<int>.generate(
                      bytes.length,
                      (index) => index,
                    ).every((index) => bytes[index] == firstBytes[index]),
        });
        results.add(
          await evaluator.evaluateRaw(
            recordingId: fixture['recordingId'] as String,
            audioFile: audioFile,
            groundTruth: fixture,
          ),
        );
      }

      final report = <String, Object?>{
        'phase': 'ES-7',
        'realHumanAudio': true,
        'humanSampleCount': fixtures.length,
        'uniqueWaveformCount': manifest['uniqueWaveformCount'],
        'humanBenchmarkStatus': 'LABELED_SMOKE_TEST_ONLY',
        'rawBaselineCapturedBeforePreprocessing': true,
        'sttBiasingUsed': false,
        'productionVoiceBehaviorChanged': false,
        'provider': {
          'stt': 'OpenAI gpt-transcribe',
          'requestedLanguage': 'en',
          'detectedLanguageAvailable': false,
          'confidenceOrLogprobAvailable': results.any(
            (item) =>
                ((item['transcription'] as Map)['confidenceAvailable'] == true),
          ),
        },
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
        'independentLiveDbGroundTruth': {
          'derivedFromEntitySearchResults': false,
          'rallyAluksne': {
            'queryMethod': 'exact rally_events.event_name lookup',
            'eventId': rallyTruthRows.single['event_id'].toString(),
            'eventName': rallyTruthRows.single['event_name'].toString(),
            'interpretationAmbiguous': false,
          },
          'maxFreeman': {
            'queryMethod': 'exact driver/co-driver profile lookup plus raw entry-list participation joins',
            'canonicalPersonId':
                'person:account:${maxCodriverProfiles.single['account_id']}',
            'accountId': maxCodriverProfiles.single['account_id'].toString(),
            'driverProfileCount': maxDriverProfiles.length,
            'codriverProfileCount': maxCodriverProfiles.length,
            'codriverId': maxCodriverProfiles.single['codriver_id'].toString(),
            'driverParticipationCount': 0,
            'codriverParticipationCount': maxCodriverParticipation.length,
            'expectedQueryRoleSemantics': 'ANY',
            'actualLiveParticipationRole': 'CO_DRIVER_ONLY',
            'interpretationAmbiguous': false,
          },
        },
        'fixtureMetadata': fixtureMetadata,
        'groundTruth': {
          'status': 'HUMAN_SUPPLIED_FOR_ALL_5_TRANSCRIPTS',
          'source': manifest['groundTruthSource'],
          'referenceTranscriptsAvailable': fixtures
              .where((item) => item['referenceTranscriptRaw'] != null)
              .length,
          'entityMentionsAvailable': fixtures
              .where((item) => item['entityMention'] != null)
              .length,
          'canonicalEntityIdsAvailable': fixtures
              .where((item) => item['canonicalEntityId'] != null)
              .length,
          'entityTypesAvailable': fixtures
              .where((item) => item['entityType'] != null)
              .length,
          'labelsInferredFromStt': false,
          'labelsInferredFromWinningCandidate': false,
          'canonicalIdsVerifiedInLoadedIndex': true,
        },
        'results': results,
        'perFileMetrics': _metrics(results),
        'uniqueAudioMetrics': _metrics(
          results
              .where((item) => item['recordingId'] != 'human-smoke-003')
              .toList(growable: false),
        ),
      };
      const outputPath =
          'test/eval/entity_search/human_voice_smoke_baseline_report.json';
      await File(outputPath)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      print(const JsonEncoder.withIndent('  ').convert(report));
    } finally {
      speech.dispose();
      await db.close();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Map<String, Object?> _metrics(List<Map<String, Object?>> results) {
  final wers = results
      .map((item) => item['wer'])
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);
  final cers = results
      .map((item) => item['cer'])
      .whereType<num>()
      .map((value) => value.toDouble())
      .toList(growable: false);
  final canonical = results
      .where((item) => item['canonicalEntityCorrect'] != null)
      .toList(growable: false);
  final canonicalOutcomes = results
      .where((item) => item['canonicalOutcomeCorrect'] != null)
      .toList(growable: false);
  final entityMentions = results
      .where((item) => item['entityMentionExact'] != null)
      .toList(growable: false);
  final outcomeCounts = <String, int>{};
  for (final result in results) {
    final outcome = result['finalOutcome'] as String;
    outcomeCounts[outcome] = (outcomeCounts[outcome] ?? 0) + 1;
  }
  return {
    'files': results.length,
    'meanWer': wers.reduce((left, right) => left + right) / wers.length,
    'meanCer': cers.reduce((left, right) => left + right) / cers.length,
    'entityMentionExact': entityMentions
        .where((item) => item['entityMentionExact'] == true)
        .length,
    'entityMentionScorable': entityMentions.length,
    'finalCanonicalCorrect': canonical
        .where((item) => item['canonicalEntityCorrect'] == true)
        .length,
    'finalCanonicalScorable': canonical.length,
    'canonicalOutcomeCorrectIncludingClarification': canonicalOutcomes
        .where((item) => item['canonicalOutcomeCorrect'] == true)
        .length,
    'canonicalOutcomeScorable': canonicalOutcomes.length,
    'querySemanticsCorrect': results.where((item) {
      final querySemantics = item['querySemantics'];
      return querySemantics is Map &&
          querySemantics['semanticsCorrect'] == true;
    }).length,
    'querySemanticsScorable': results.length,
    'outcomes': outcomeCounts,
  };
}
