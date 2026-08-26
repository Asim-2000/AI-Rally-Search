import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser_factory.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/speech/openai_speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import 'live_voice_benchmark_evaluator.dart';
import 'manifest/benchmark_manifest.dart';

void main() {
  test('Phase 5B.1 Live Voice Benchmark (38 Synthetic Samples across 19 Languages)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    final envFile = File('.env');
    if (envFile.existsSync()) {
      await dotenv.load(fileName: '.env');
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    expect(apiKey, isNotNull, reason: 'OPENAI_API_KEY must be configured in .env for live voice benchmark');
    expect(apiKey!.isNotEmpty, isTrue);

    final speechConfig = SpeechConfig(
      providerType: SpeechProviderType.openAiDirectDev,
      endpointUrl: 'https://api.openai.com/v1/audio/transcriptions',
      apiKey: apiKey,
      model: dotenv.env['SPEECH_MODEL'] ?? 'whisper-1',
    );

    final speechService = OpenAiSpeechToTextService(config: speechConfig);
    final parser = LlmQueryParserFactory.create();
    final lookupRepo = DatabaseEntityLookupRepository();
    final resolver = DatabaseEntityResolver(repository: lookupRepo);
    final searchRepo = SearchRepository();

    final nlSearchService = NaturalLanguageSearchService(
      parser: parser,
      entityResolver: resolver,
      repository: searchRepo,
    );

    final evaluator = LiveVoiceBenchmarkEvaluator(
      speechService: speechService,
      nlSearchService: nlSearchService,
    );

    final manifestEntries = SyntheticSmokeBenchmarkManifest.entries;
    expect(manifestEntries.length, equals(38));

    print('\n🚀 Starting Live Voice Benchmark on ${manifestEntries.length} audio samples (19 languages)...');

    final results = await evaluator.evaluateManifest(
      manifestEntries,
      onProgress: (sample, index, total) {
        final status = sample.searchSemanticSuccess ? '✅' : '❌';
        print(
          '[$index/$total] $status ${sample.entry.language.displayName} (${sample.entry.locale}): "${sample.actualTranscript}" '
          '| WER: ${(sample.wer * 100).toStringAsFixed(1)}% | Intent: ${sample.intentMatched} | E2E: ${sample.totalLatencyMs}ms',
        );
      },
    );

    expect(results.length, equals(38));

    const outputDir = 'test/eval/reports';
    await LiveVoiceBenchmarkEvaluator.generateReports(
      results: results,
      outputDir: outputDir,
    );

    final avgWer = results.map((r) => r.wer).reduce((a, b) => a + b) / results.length;
    final intentAcc = results.where((r) => r.intentMatched).length / results.length;
    final searchSuccess = results.where((r) => r.searchSemanticSuccess).length / results.length;

    print('\n===========================================================');
    print('📊 LIVE BENCHMARK COMPLETE');
    print('===========================================================');
    print('Average WER: ${(avgWer * 100).toStringAsFixed(1)}%');
    print('Intent Accuracy: ${(intentAcc * 100).toStringAsFixed(1)}%');
    print('Search Semantic Success Rate: ${(searchSuccess * 100).toStringAsFixed(1)}%');
    print('Detailed reports written to: $outputDir/');
    print('===========================================================');

    expect(results.isNotEmpty, isTrue);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
