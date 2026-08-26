import 'dart:io';
import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser_factory.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/speech/openai_speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/speech_config.dart';
import '../test/eval/audio_asset_resolver.dart';
import '../test/eval/live_voice_benchmark_evaluator.dart';
import '../test/eval/manifest/benchmark_manifest.dart';
import '../test/eval/manifest/human_benchmark_models.dart';
import '../test/eval/manifest/human_pilot_manifest.dart';

Map<String, String> _loadDotEnv() {
  final env = <String, String>{};
  final file = File('.env');
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx > 0) {
        final key = trimmed.substring(0, eqIdx).trim();
        var val = trimmed.substring(eqIdx + 1).trim();
        if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
          val = val.substring(1, val.length - 1);
        } else if (val.startsWith("'") && val.endsWith("'") && val.length >= 2) {
          val = val.substring(1, val.length - 1);
        }
        env[key] = val;
      }
    }
  }
  return env;
}

void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('AI Rally Voice Search Benchmark Runner');
    stdout.writeln('========================================');
    stdout.writeln('Usage: dart run bin/run_live_voice_eval.dart [options]');
    stdout.writeln();
    stdout.writeln('Options:');
    stdout.writeln('  --dataset=<synthetic|human>  Target benchmark dataset (default: synthetic)');
    stdout.writeln('  --language=<code>            Filter by ISO language code (e.g. en, ga, ur, de)');
    stdout.writeln('  --archetype=<A-E>            Filter by semantic archetype letter (A, B, C, D, or E)');
    stdout.writeln('  --sample=<sampleId>          Run evaluation on a single sample ID');
    stdout.writeln('  --model=<name>               Speech-to-text model override (default: whisper-1)');
    stdout.writeln('  --outputDir=<path>           Reports directory (default: test/eval/reports)');
    stdout.writeln('  --help, -h                   Show this help message');
    exit(0);
  }

  // Parse arguments
  String datasetType = 'synthetic';
  String? languageFilter;
  String? archetypeFilter;
  String? sampleFilter;
  String outputDir = 'test/eval/reports';

  for (final arg in args) {
    if (arg.startsWith('--dataset=')) {
      datasetType = arg.substring('--dataset='.length).trim().toLowerCase();
    } else if (arg.startsWith('--language=')) {
      languageFilter = arg.substring('--language='.length).trim().toLowerCase();
    } else if (arg.startsWith('--archetype=')) {
      archetypeFilter = arg.substring('--archetype='.length).trim().toUpperCase();
    } else if (arg.startsWith('--sample=')) {
      sampleFilter = arg.substring('--sample='.length).trim();
    } else if (arg.startsWith('--outputDir=')) {
      outputDir = arg.substring('--outputDir='.length).trim();
    }
  }

  final isHumanDataset = datasetType == 'human';
  final benchmarkType = isHumanDataset ? BenchmarkType.human : BenchmarkType.synthetic;

  stdout.writeln('===========================================================');
  stdout.writeln('🎙️ Live Voice Search Benchmark Runner [${benchmarkType.name.toUpperCase()}]');
  stdout.writeln('===========================================================');
  if (isHumanDataset) {
    stdout.writeln('⚠️  WAVE-1 HUMAN PILOT: Failure-discovery baseline across native speakers.');
    stdout.writeln('⚠️  Human and synthetic metrics remain strictly segregated.');
  }

  final env = _loadDotEnv();
  final apiKey = env['OPENAI_API_KEY'] ?? Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('ERROR: OPENAI_API_KEY must be configured in .env or environment');
    exit(1);
  }

  final speechModel = env['SPEECH_MODEL'] ?? Platform.environment['SPEECH_MODEL'] ?? 'whisper-1';
  final speechConfig = SpeechConfig(
    providerType: SpeechProviderType.openAiDirectDev,
    endpointUrl: 'https://api.openai.com/v1/audio/transcriptions',
    apiKey: apiKey,
    model: speechModel,
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

  final assetResolver = isHumanDataset
      ? const LocalDirectoryAssetResolver(Directory('test/eval/audio/human'))
      : null;

  final evaluator = LiveVoiceBenchmarkEvaluator(
    speechService: speechService,
    nlSearchService: nlSearchService,
    assetResolver: assetResolver,
  );

  // Select Manifest
  List<BenchmarkManifestEntry> entries;
  if (isHumanDataset) {
    entries = List<BenchmarkManifestEntry>.from(HumanPilotBenchmarkManifest.entries);
  } else {
    entries = List<BenchmarkManifestEntry>.from(SyntheticSmokeBenchmarkManifest.entries);
  }

  // Apply Filters
  if (languageFilter != null) {
    entries = entries.where((e) => e.language.languageCode == languageFilter).toList();
  }
  if (archetypeFilter != null) {
    entries = entries.where((e) {
      if (e is HumanBenchmarkManifestEntry) {
        return e.archetype.code == archetypeFilter;
      }
      return true;
    }).toList();
  }
  if (sampleFilter != null) {
    entries = entries.where((e) => e.id == sampleFilter).toList();
  }

  if (entries.isEmpty) {
    stdout.writeln('No benchmark entries matched filters (language: $languageFilter, archetype: $archetypeFilter, sample: $sampleFilter).');
    exit(0);
  }

  stdout.writeln('Executing evaluation on ${entries.length} samples...\n');

  final results = await evaluator.evaluateManifest(
    entries,
    onProgress: (sample, index, total) {
      final status = sample.audioMissing
          ? '⚠️ MISSING'
          : (sample.searchSemanticSuccess ? '✅ SUCCESS' : '❌ FAILED');
      final langStr = '${sample.entry.language.displayName} (${sample.entry.locale})';
      stdout.writeln(
        '[$index/$total] $status $langStr [${sample.entry.id}] '
        '| Transcript: "${sample.actualTranscript}" '
        '| WER: ${(sample.wer * 100).toStringAsFixed(1)}% '
        '| Intent: ${sample.intentMatched} '
        '| Attribution: ${sample.failureAttribution.label} '
        '| E2E: ${sample.totalLatencyMs}ms',
      );
    },
  );

  final mdPath = await LiveVoiceBenchmarkEvaluator.generateReports(
    results: results,
    outputDir: outputDir,
    benchmarkType: benchmarkType,
    modelName: speechModel,
  );

  stdout.writeln('\n===========================================================');
  stdout.writeln('📊 Benchmark evaluation complete.');
  stdout.writeln('📄 Markdown report generated: $mdPath');
  stdout.writeln('===========================================================');
  exit(0);
}
