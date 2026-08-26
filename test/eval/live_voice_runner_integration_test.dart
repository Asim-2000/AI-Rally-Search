import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/speech/mock_speech_to_text_service.dart';
import 'audio_asset_resolver.dart';
import 'live_voice_benchmark_evaluator.dart';
import 'manifest/benchmark_manifest.dart';
import 'manifest/human_benchmark_models.dart';
import 'manifest/human_pilot_manifest.dart';

void main() {
  group('Live Voice Benchmark Runner Integration Tests', () {
    test('Human Wave-1 evaluation runs gracefully with unrecorded/missing audio', () async {
      final mockSpeechService = MockSpeechToTextService();
      final parser = MockLlmQueryParser();
      final resolver = DatabaseEntityResolver(repository: DatabaseEntityLookupRepository());
      final searchRepo = SearchRepository();

      final nlSearchService = NaturalLanguageSearchService(
        parser: parser,
        entityResolver: resolver,
        repository: searchRepo,
      );

      final tempDir = Directory.systemTemp.createTempSync('human_pilot_test_');
      final assetResolver = LocalDirectoryAssetResolver(tempDir);

      final evaluator = LiveVoiceBenchmarkEvaluator(
        speechService: mockSpeechService,
        nlSearchService: nlSearchService,
        assetResolver: assetResolver,
      );

      // Run on subset of Wave-1 human entries
      final testEntries = HumanPilotBenchmarkManifest.entries.take(5).toList();
      final results = await evaluator.evaluateManifest(testEntries);

      expect(results.length, 5);
      for (final r in results) {
        expect(r.audioMissing, isTrue);
        expect(r.failureAttribution, FailureAttribution.other);
      }

      final reportDir = Directory('${tempDir.path}/reports');
      final reportPath = await LiveVoiceBenchmarkEvaluator.generateReports(
        results: results,
        outputDir: reportDir.path,
        benchmarkType: BenchmarkType.human,
      );

      expect(File(reportPath).existsSync(), isTrue);
      final md = File(reportPath).readAsStringSync();
      expect(md.contains('HUMAN PILOT — WAVE 1'), isTrue);
      expect(md.contains('Missing Audio Detected'), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('Filter by language and archetype works precisely on Wave-1 manifest', () {
      final irishEntries = HumanPilotBenchmarkManifest.entries.where((e) => e.language.languageCode == 'ga').toList();
      expect(irishEntries.length, 5);

      final archetypeDEntries = HumanPilotBenchmarkManifest.entries.where((e) => e.archetype == QueryArchetype.archetypeD_videoAction).toList();
      expect(archetypeDEntries.length, 19);

      final gaArchD = HumanPilotBenchmarkManifest.entries.where(
        (e) => e.language.languageCode == 'ga' && e.archetype == QueryArchetype.archetypeD_videoAction,
      ).toList();
      expect(gaArchD.length, 1);
      expect(gaArchD.first.sampleId, 'human-ga-spk01-archD');
      expect(gaArchD.first.audioAssetId, 'ga_archD_spk01');
    });
  });
}
