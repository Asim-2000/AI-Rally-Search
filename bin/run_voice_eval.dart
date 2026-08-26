import 'dart:io';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser_factory.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import 'package:ai_rally_search/services/speech/speech_service_factory.dart';
import '../test/eval/multilingual_voice_benchmark_cases.dart';
import '../test/eval/voice_benchmark_evaluator.dart';

void main(List<String> args) async {
  stdout.writeln('===========================================================');
  stdout.writeln('🎙️ Phase 5B Multilingual Voice Search Benchmark Runner');
  stdout.writeln('===========================================================');

  final speechConfig = SpeechConfig.fromEnvironment();
  stdout.writeln('STT Provider: ${speechConfig.providerType.name}');
  stdout.writeln('STT Endpoint: ${speechConfig.endpointUrl}');

  final speechService = SpeechServiceFactory.create(config: speechConfig);
  final searchRepo = SearchRepository();
  final parser = LlmQueryParserFactory.create();
  final lookupRepo = DatabaseEntityLookupRepository();
  final resolver = DatabaseEntityResolver(repository: lookupRepo);

  final nlSearchService = NaturalLanguageSearchService(
    parser: parser,
    entityResolver: resolver,
    repository: searchRepo,
  );

  final evaluator = VoiceBenchmarkEvaluator(
    speechService: speechService,
    nlSearchService: nlSearchService,
    searchRepository: searchRepo,
  );

  stdout.writeln('Running benchmark across ${MultilingualVoiceBenchmarkCases.all.length} multilingual test cases...');
  final results = await evaluator.evaluateSuite(MultilingualVoiceBenchmarkCases.all);

  const outputDir = 'test/eval/reports';
  VoiceBenchmarkEvaluator.saveEvaluationReports(
    results: results,
    outputDir: outputDir,
  );

  stdout.writeln('\nBenchmark completed successfully!');
  stdout.writeln('Reports saved in $outputDir/');

  final avgWer = results.map((r) => r.wordErrorRate).reduce((a, b) => a + b) / results.length;
  final driverPres = results.where((r) => r.driverPreserved).length / results.length;
  final rallyPres = results.where((r) => r.rallyPreserved).length / results.length;
  final actionPres = results.where((r) => r.actionPreserved).length / results.length;
  final avgLatency = results.map((r) => r.totalLatencyMs).reduce((a, b) => a + b) / results.length;

  stdout.writeln('\n---------------- Summary ----------------');
  stdout.writeln('Average WER: ${(avgWer * 100).toStringAsFixed(1)}%');
  stdout.writeln('Driver Name Preservation: ${(driverPres * 100).toStringAsFixed(1)}%');
  stdout.writeln('Rally Name Preservation: ${(rallyPres * 100).toStringAsFixed(1)}%');
  stdout.writeln('Action Term Preservation: ${(actionPres * 100).toStringAsFixed(1)}%');
  stdout.writeln('Average E2E Latency: ${avgLatency.toStringAsFixed(0)} ms');
  stdout.writeln('-----------------------------------------');

  exit(0);
}
