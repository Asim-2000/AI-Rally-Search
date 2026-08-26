import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser_factory.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/speech/openai_speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import '../test/eval/live_voice_benchmark_evaluator.dart';
import '../test/eval/manifest/benchmark_manifest.dart';

void main(List<String> args) async {
  stdout.writeln('===========================================================');
  stdout.writeln('🎙️ Phase 5B.1 Live Voice Search Benchmark Runner');
  stdout.writeln('===========================================================');

  final envFile = File('.env');
  if (envFile.existsSync()) {
    await dotenv.load(fileName: '.env');
  }

  final apiKey = dotenv.env['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('ERROR: OPENAI_API_KEY must be configured in .env');
    exit(1);
  }

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
  stdout.writeln('Running live evaluation on ${manifestEntries.length} audio files...\n');

  final results = await evaluator.evaluateManifest(
    manifestEntries,
    onProgress: (sample, index, total) {
      final status = sample.searchSemanticSuccess ? '✅' : '❌';
      stdout.writeln(
        '[$index/$total] $status ${sample.entry.language.displayName} (${sample.entry.locale}): "${sample.actualTranscript}" '
        '| WER: ${(sample.wer * 100).toStringAsFixed(1)}% | Intent: ${sample.intentMatched} | E2E: ${sample.totalLatencyMs}ms',
      );
    },
  );

  const outputDir = 'test/eval/reports';
  LiveVoiceBenchmarkEvaluator.saveEvaluationReports(
    results: results,
    outputDir: outputDir,
    benchmarkType: BenchmarkType.synthetic,
    modelName: speechConfig.model,
  );

  stdout.writeln('\n===========================================================');
  stdout.writeln('📊 Benchmark evaluation complete. Reports saved in $outputDir/');
  stdout.writeln('===========================================================');
  exit(0);
}
