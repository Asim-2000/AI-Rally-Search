import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'audio_asset_resolver.dart';
import 'live_voice_benchmark_evaluator.dart';
import 'manifest/benchmark_manifest.dart';
import 'manifest/human_benchmark_models.dart';
import 'manifest/human_pilot_manifest.dart';

void main() {
  group('Phase 5C — Human Benchmark Models & Serialization Tests', () {
    test('HumanBenchmarkManifestEntry serializes and deserializes correctly', () {
      const entry = HumanBenchmarkManifestEntry(
        sampleId: 'human-ga-spk01-archD',
        audioAssetId: 'ga_archD_spk01',
        language: SupportedLanguages.irish,
        locale: 'ga-IE',
        speakerId: 'spk_ga_01',
        archetype: QueryArchetype.archetypeD_videoAction,
        environment: AcousticEnvironment.moderateNoise,
        deviceClass: DeviceClass.mobileInternalMic,
        functionalTags: ['native_fluency', 'moderate_noise'],
        naturalPromptGiven: 'Ask naturally in Irish for jump highlights of Josh Moffett.',
        humanVerifiedTranscript: 'Taispeáin léimeanna Josh Moffett.',
        verificationTier: TranscriptVerificationTier.speakerVerified,
        expectedIntent: SearchIntent.searchVideoActions,
        expectedFilters: {
          'driverName': 'Josh Moffett',
          'actionType': 'jump',
          'year': 2025,
        },
        expectedEntities: ['Josh Moffett'],
        expectedDrivers: ['Josh Moffett', 'Moffett'],
        expectedActions: ['jump', 'léimeanna'],
        collectionDate: '2026-08-27',
        consentVersion: 'v1.0',
        retentionClass: 'pilot_wave1_active',
      );

      final json = entry.toManifestJson();
      expect(json['sample_id'], 'human-ga-spk01-archD');
      expect(json['audio_asset_id'], 'ga_archD_spk01');
      expect(json['benchmark_type'], 'human');
      expect(json['language'], 'ga');
      expect(json['locale'], 'ga-IE');
      expect(json['speaker_id'], 'spk_ga_01');
      expect(json['archetype'], 'archetypeD_videoAction');
      expect(json['archetype_code'], 'D');
      expect(json['environment'], 'moderateNoise');
      expect(json['device_class'], 'mobileInternalMic');
      expect(json['verification_tier'], 'speakerVerified');
      expect(json['expected_intent'], 'searchVideoActions');

      final deserialized = HumanBenchmarkManifestEntry.fromJson(json);
      expect(deserialized.sampleId, entry.sampleId);
      expect(deserialized.audioAssetId, entry.audioAssetId);
      expect(deserialized.language, SupportedLanguages.irish);
      expect(deserialized.speakerId, 'spk_ga_01');
      expect(deserialized.archetype, QueryArchetype.archetypeD_videoAction);
      expect(deserialized.environment, AcousticEnvironment.moderateNoise);
      expect(deserialized.deviceClass, DeviceClass.mobileInternalMic);
      expect(deserialized.verificationTier, TranscriptVerificationTier.speakerVerified);
      expect(deserialized.isAudioTranscribedAndVerified, isTrue);
      expect(deserialized.expectedQuery.intent, SearchIntent.searchVideoActions);
      expect(deserialized.expectedQuery.driverName, 'Josh Moffett');
      expect(deserialized.expectedQuery.actionType, 'jump');
    });

    test('Data minimization: entry contains zero PII demographic fields', () {
      final entry = HumanPilotBenchmarkManifest.entries.first;
      final json = entry.toManifestJson();

      expect(json.containsKey('name'), isFalse);
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('age'), isFalse);
      expect(json.containsKey('location'), isFalse);
      expect(json.containsKey('ethnicity'), isFalse);
      expect(json.containsKey('religion'), isFalse);
      expect(json.containsKey('accent_connacht'), isFalse);
    });
  });

  group('Phase 5C — Wave-1 Manifest Completeness & Coverage Tests', () {
    test('Wave-1 human manifest contains exactly 95 structural entries', () {
      expect(HumanPilotBenchmarkManifest.entries.length, 95);
    });

    test('All 19 supported languages are represented with 5 samples each', () {
      final langCounts = <SupportedLanguage, int>{};
      for (final entry in HumanPilotBenchmarkManifest.entries) {
        langCounts[entry.language] = (langCounts[entry.language] ?? 0) + 1;
      }

      expect(langCounts.length, 19);
      for (final lang in SupportedLanguages.all) {
        expect(
          langCounts[lang],
          5,
          reason: 'Language ${lang.displayName} (${lang.languageCode}) must have 5 archetypes',
        );
      }
    });

    test('All 5 semantic archetypes are represented across each language', () {
      for (final lang in SupportedLanguages.all) {
        final langEntries = HumanPilotBenchmarkManifest.entries.where((e) => e.language == lang).toList();
        expect(langEntries.length, 5);

        final archetypes = langEntries.map((e) => e.archetype).toSet();
        expect(archetypes.contains(QueryArchetype.archetypeA_rallyDiscovery), isTrue);
        expect(archetypes.contains(QueryArchetype.archetypeB_driverParticipation), isTrue);
        expect(archetypes.contains(QueryArchetype.archetypeC_compoundQuery), isTrue);
        expect(archetypes.contains(QueryArchetype.archetypeD_videoAction), isTrue);
        expect(archetypes.contains(QueryArchetype.archetypeE_stageCodeSwitch), isTrue);
      }
    });

    test('Unrecorded Wave-1 samples have empty transcripts and unverified tier', () {
      for (final entry in HumanPilotBenchmarkManifest.entries) {
        expect(
          entry.humanVerifiedTranscript,
          isEmpty,
          reason: 'Sample ${entry.sampleId} should not have fabricated ground truth',
        );
        expect(
          entry.verificationTier,
          TranscriptVerificationTier.unverified,
          reason: 'Sample ${entry.sampleId} must start in unverified tier',
        );
        expect(entry.naturalPromptGiven, isNotEmpty);
      }
    });

    test('Synthetic and human datasets are strictly segregated with distinct types', () {
      for (final synthEntry in SyntheticSmokeBenchmarkManifest.entries) {
        expect(synthEntry.benchmarkType, BenchmarkType.synthetic);
      }
      for (final humanEntry in HumanPilotBenchmarkManifest.entries) {
        expect(humanEntry.benchmarkType, BenchmarkType.human);
      }
    });
  });

  group('Phase 5C — AudioAssetResolver Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('human_audio_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Resolves flat audio files (.wav, .m4a, .mp3)', () async {
      final wavFile = File('${tempDir.path}/ga_archD_spk01.wav')..writeAsStringSync('audio_bytes');
      final resolver = LocalDirectoryAssetResolver(tempDir);

      expect(await resolver.hasAsset('ga_archD_spk01'), isTrue);
      final resolved = await resolver.resolveAudioFile('ga_archD_spk01');
      expect(resolved.path, wavFile.path);
    });

    test('Resolves partitioned subdirectories (e.g. <dir>/ga/ga_archA_spk01.m4a)', () async {
      final subDir = Directory('${tempDir.path}/ga')..createSync();
      final m4aFile = File('${subDir.path}/ga_archA_spk01.m4a')..writeAsStringSync('audio_bytes');
      final resolver = LocalDirectoryAssetResolver(tempDir);

      expect(await resolver.hasAsset('ga_archA_spk01'), isTrue);
      final resolved = await resolver.resolveAudioFile('ga_archA_spk01');
      expect(resolved.path, m4aFile.path);
    });

    test('Gracefully throws AudioFileNotFoundException for missing audio', () async {
      final resolver = LocalDirectoryAssetResolver(tempDir);
      expect(await resolver.hasAsset('non_existent_asset'), isFalse);

      expect(
        () async => await resolver.resolveAudioFile('non_existent_asset'),
        throwsA(isA<AudioFileNotFoundException>()),
      );
    });
  });

  group('Phase 5C — Metrics & Outcome Calculations', () {
    test('EntityResolutionOutcome correctly categorizes autoResolvedIncorrect as critical failure', () {
      expect(EntityResolutionOutcome.autoResolvedIncorrect.label, 'AUTO_RESOLVED_INCORRECT');
      expect(EntityResolutionOutcome.autoResolvedCorrect.label, 'AUTO_RESOLVED_CORRECT');
      expect(EntityResolutionOutcome.unnecessaryClarification.label, 'UNNECESSARY_CLARIFICATION');
    });

    test('12-Class FailureAttribution has accurate MySQL database attribution', () {
      expect(FailureAttribution.database.label, 'DATABASE');
      expect(
        FailureAttribution.database.description,
        'Deterministic SearchRepository / MySQL execution failed or returned an unexpected result.',
      );
      expect(FailureAttribution.values.length, 13); // none + 12 categories
    });

    test('Report generation handles missing audio files gracefully without crashing', () async {
      final tempOutDir = Directory.systemTemp.createTempSync('report_test_');

      final sampleResult = LiveVoiceEvaluationSampleResult(
        entry: HumanPilotBenchmarkManifest.entries.first,
        actualTranscript: '',
        normalizedTranscript: '',
        wer: 0.0,
        eer: 0.0,
        rawDriverPreserved: false,
        rawRallyPreserved: false,
        rawStagePreserved: false,
        rawActionPreserved: false,
        recoveredDriverPreserved: false,
        recoveredRallyPreserved: false,
        recoveredStagePreserved: false,
        recoveredActionPreserved: false,
        intentMatched: false,
        filterPrecision: 0.0,
        filterRecall: 0.0,
        filterF1: 0.0,
        exactSemanticMatch: false,
        rawSemanticSuccess: false,
        postRecoverySemanticSuccess: false,
        searchSemanticSuccess: false,
        entityResolutionOutcome: EntityResolutionOutcome.noMatch,
        entityResolutionSucceeded: false,
        dbExecutionSucceeded: false,
        returnedRowCount: 0,
        failureAttribution: FailureAttribution.other,
        sttLatencyMs: 0,
        llmParseLatencyMs: 0,
        entityResolutionLatencyMs: 0,
        dbLatencyMs: 0,
        totalLatencyMs: 0,
        audioMissing: true,
        errorMessage: 'Audio asset not found: "en_archA_spk01"',
      );

      final reportPath = await LiveVoiceBenchmarkEvaluator.generateReports(
        results: [sampleResult],
        outputDir: tempOutDir.path,
        benchmarkType: BenchmarkType.human,
      );

      final mdContent = File(reportPath).readAsStringSync();
      expect(mdContent.contains('HUMAN PILOT — WAVE 1'), isTrue);
      expect(mdContent.contains('Missing Audio Detected'), isTrue);
      expect(mdContent.contains('Wave 1 is a failure-discovery pilot'), isTrue);

      tempOutDir.deleteSync(recursive: true);
    });
  });
}
