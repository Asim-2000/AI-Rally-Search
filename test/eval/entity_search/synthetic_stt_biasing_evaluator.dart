import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/speech/speech_transcription_context.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/services/entity_search/controlled_fallback_entity_resolver.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'package:ai_rally_search/services/speech/speech_to_text_service.dart';
import 'package:ai_rally_search/services/speech/voice_entity_recovery_service.dart';

import 'synthetic_stt_biasing_corpus.dart';

enum SyntheticSttStrategy {
  baseline,
  staticContext,
  dynamicTop3,
  dynamicTop5,
  dynamicTop10,
}

class NegativeBiasCase {
  final String id;
  final String spokenText;
  final File audioFile;
  final List<String> biasVocabulary;
  final String? expectedSpokenCanonicalName;

  const NegativeBiasCase({
    required this.id,
    required this.spokenText,
    required this.audioFile,
    required this.biasVocabulary,
    this.expectedSpokenCanonicalName,
  });
}

class SyntheticSttEvaluationResult {
  final String sampleId;
  final String audioCondition;
  final SyntheticSttStrategy strategy;
  final TranscriptionOrigin transcriptionOrigin;
  final String expectedText;
  final String transcript;
  final String expectedCanonicalId;
  final String expectedCanonicalName;
  final SearchEntityType entityType;
  final bool secondPassTriggered;
  final int sttCalls;
  final int sttLatencyMs;
  final int totalLatencyMs;
  final bool canonicalAt1;
  final bool correctConfident;
  final bool wrongConfident;
  final bool clarification;
  final bool noMatch;
  final List<String> biasVocabulary;
  final double wer;
  final double cer;

  const SyntheticSttEvaluationResult({
    required this.sampleId,
    required this.audioCondition,
    required this.strategy,
    required this.transcriptionOrigin,
    required this.expectedText,
    required this.transcript,
    required this.expectedCanonicalId,
    required this.expectedCanonicalName,
    required this.entityType,
    required this.secondPassTriggered,
    required this.sttCalls,
    required this.sttLatencyMs,
    required this.totalLatencyMs,
    required this.canonicalAt1,
    required this.correctConfident,
    required this.wrongConfident,
    required this.clarification,
    required this.noMatch,
    required this.biasVocabulary,
    required this.wer,
    required this.cer,
  });

  Map<String, Object?> toJson() => {
    'sampleId': sampleId,
    'audioCondition': audioCondition,
    'strategy': strategy.name,
    'transcriptionOrigin': transcriptionOrigin.name,
    'expectedText': expectedText,
    'transcript': transcript,
    'expectedCanonicalId': expectedCanonicalId,
    'expectedCanonicalName': expectedCanonicalName,
    'entityType': entityType.name,
    'secondPassTriggered': secondPassTriggered,
    'sttCalls': sttCalls,
    'sttLatencyMs': sttLatencyMs,
    'totalLatencyMs': totalLatencyMs,
    'canonicalAt1': canonicalAt1,
    'correctConfident': correctConfident,
    'wrongConfident': wrongConfident,
    'clarification': clarification,
    'noMatch': noMatch,
    'biasVocabulary': biasVocabulary,
    'wer': wer,
    'cer': cer,
  };
}

class SyntheticSttBiasingEvaluator {
  static const staticPrompt =
      'A rally motorsport video search query. Preserve proper names, years, stage numbers, and uploader names exactly when spoken.';
  static const staticKeywords = [
    'rally',
    'driver',
    'co-driver',
    'stage',
    'uploader',
    'jumps',
    'videos',
  ];

  final ISpeechToTextService speech;
  final LlmQueryParser parser;
  final ControlledFallbackEntityResolver resolver;
  final InMemoryEntitySearchService entitySearch;
  final VoiceEntityRecoveryService recovery;
  final File cacheFile;
  late final Map<String, dynamic> _cache = _loadCache();

  SyntheticSttBiasingEvaluator({
    required this.speech,
    required this.parser,
    required this.resolver,
    required this.entitySearch,
    required this.cacheFile,
    this.recovery = const VoiceEntityRecoveryService(),
  });

  Future<List<SyntheticSttEvaluationResult>> evaluate(
    List<SyntheticSttUtterance> utterances,
    Directory audioDirectory, {
    int? maxAudioFiles,
    void Function(int completed, int total)? onProgress,
  }) async {
    final work =
        <({SyntheticSttUtterance utterance, File file, String condition})>[];
    for (final utterance in utterances) {
      for (final condition in ['clean', 'noisy']) {
        final file = File(
          '${audioDirectory.path}/${utterance.id}_$condition.wav',
        );
        if (file.existsSync()) {
          work.add((utterance: utterance, file: file, condition: condition));
        }
      }
    }
    final selected = maxAudioFiles == null
        ? work
        : work.take(maxAudioFiles).toList();
    final results = <SyntheticSttEvaluationResult>[];
    for (var offset = 0; offset < selected.length; offset += 3) {
      final batch = selected.skip(offset).take(3).toList();
      final partials = await Future.wait(batch.map(_evaluateAudioItem));
      for (final partial in partials) {
        results.addAll(partial);
      }
      onProgress?.call(
        min(offset + batch.length, selected.length),
        selected.length,
      );
      _saveCache();
    }
    return results;
  }

  Future<List<SyntheticSttEvaluationResult>> _evaluateAudioItem(
    ({SyntheticSttUtterance utterance, File file, String condition}) item,
  ) async {
    final results = <SyntheticSttEvaluationResult>[];
    final baselineWatch = Stopwatch()..start();
    final baselineStt = await _transcribe(
      item.file,
      const SpeechTranscriptionContext(
        origin: TranscriptionOrigin.baseline,
        languageHints: ['en'],
      ),
    );
    final baselineSttMs = baselineWatch.elapsedMilliseconds;
    final baseline = await _evaluateTranscript(
      item.utterance,
      item.condition,
      SyntheticSttStrategy.baseline,
      TranscriptionOrigin.baseline,
      baselineStt,
      sttCalls: 1,
      sttLatencyMs: baselineSttMs,
      totalWatch: baselineWatch,
    );
    results.add(baseline.result);

    final staticWatch = Stopwatch()..start();
    final staticText = await _transcribe(
      item.file,
      const SpeechTranscriptionContext(
        origin: TranscriptionOrigin.staticContext,
        prompt: staticPrompt,
        keywords: staticKeywords,
        languageHints: ['en'],
      ),
    );
    final staticSttMs = staticWatch.elapsedMilliseconds;
    final staticEval = await _evaluateTranscript(
      item.utterance,
      item.condition,
      SyntheticSttStrategy.staticContext,
      TranscriptionOrigin.staticContext,
      staticText,
      sttCalls: 1,
      sttLatencyMs: staticSttMs,
      totalWatch: staticWatch,
    );
    results.add(staticEval.result);

    for (final pair in const [
      (3, SyntheticSttStrategy.dynamicTop3),
      (5, SyntheticSttStrategy.dynamicTop5),
      (10, SyntheticSttStrategy.dynamicTop10),
    ]) {
      if (!baseline.shouldTriggerSecondPass) {
        results.add(
          _copyAsDynamic(
            baseline.result,
            pair.$2,
            baseline.candidateVocabulary.take(pair.$1).toList(),
          ),
        );
        continue;
      }
      final vocabulary = baseline.candidateVocabulary.take(pair.$1).toList();
      final dynamicWatch = Stopwatch()..start();
      final biased = await _transcribe(
        item.file,
        SpeechTranscriptionContext(
          origin: TranscriptionOrigin.dynamicBiased,
          prompt:
              '$staticPrompt Candidate spellings from the live database may include: ${vocabulary.join(', ')}.',
          keywords: vocabulary,
          languageHints: const ['en'],
        ),
      );
      final secondSttMs = dynamicWatch.elapsedMilliseconds;
      final dynamic = await _evaluateTranscript(
        item.utterance,
        item.condition,
        pair.$2,
        TranscriptionOrigin.dynamicBiased,
        biased,
        sttCalls: 2,
        sttLatencyMs: baselineSttMs + secondSttMs,
        totalWatch: dynamicWatch,
        fixedVocabulary: vocabulary,
        priorElapsedMs: baseline.result.totalLatencyMs,
      );
      results.add(dynamic.result);
    }
    return results;
  }

  Future<List<Map<String, Object?>>> evaluateNegativeBias(
    List<NegativeBiasCase> cases,
  ) async {
    final results = <Map<String, Object?>>[];
    for (final item in cases) {
      final baselineText = await _transcribe(
        item.audioFile,
        const SpeechTranscriptionContext(
          origin: TranscriptionOrigin.baseline,
          languageHints: ['en'],
        ),
      );
      final baselineResolution = await _resolvedNames(baselineText);
      final baselineWrong = _wrongForNegative(
        baselineResolution,
        item.expectedSpokenCanonicalName,
      );
      for (final topK in const [3, 5, 10]) {
        final vocabulary = item.biasVocabulary.take(topK).toList();
        final biasedText = await _transcribe(
          item.audioFile,
          SpeechTranscriptionContext(
            origin: TranscriptionOrigin.dynamicBiased,
            prompt:
                '$staticPrompt Candidate spellings from the live database may include: ${vocabulary.join(', ')}.',
            keywords: vocabulary,
            languageHints: const ['en'],
          ),
        );
        final biasedResolution = await _resolvedNames(biasedText);
        final biasedWrong = _wrongForNegative(
          biasedResolution,
          item.expectedSpokenCanonicalName,
        );
        final baselineBiasEcho = _echoedVocabulary(baselineText, vocabulary);
        final biasedBiasEcho = _echoedVocabulary(biasedText, vocabulary);
        results.add({
          'id': item.id,
          'topK': topK,
          'spokenText': item.spokenText,
          'expectedSpokenCanonicalName': item.expectedSpokenCanonicalName,
          'biasVocabulary': vocabulary,
          'baselineTranscript': baselineText,
          'dynamicTranscript': biasedText,
          'baselineResolvedNames': baselineResolution,
          'dynamicResolvedNames': biasedResolution,
          'baselineWrong': baselineWrong,
          'dynamicWrong': biasedWrong,
          'biasInducedEntityError':
              !baselineWrong &&
              (biasedWrong || (!baselineBiasEcho && biasedBiasEcho)),
        });
      }
    }
    _saveCache();
    return results;
  }

  Future<List<String>> _resolvedNames(String transcript) async {
    final parse = await _parseWithBackoff(
      recovery.recover(transcript).normalizedTranscript,
    );
    if (!parse.isSuccess || parse.query == null) return const [];
    final result = await resolver.resolveControlled(parse.query!, voice: true);
    return result.resolutions.values
        .where((value) => value.isResolved)
        .map((value) => value.resolvedCandidate?.canonicalName)
        .whereType<String>()
        .toList(growable: false);
  }

  static bool _wrongForNegative(
    List<String> resolved,
    String? expectedCanonicalName,
  ) {
    if (expectedCanonicalName == null) return resolved.isNotEmpty;
    if (resolved.isEmpty) return false;
    final expected = _normalize(expectedCanonicalName);
    return resolved.any((name) => _normalize(name) != expected);
  }

  static bool _echoedVocabulary(String transcript, List<String> vocabulary) {
    final normalized = _normalize(transcript);
    return vocabulary.any((value) {
      final name = _normalize(value);
      return name.isNotEmpty && normalized.contains(name);
    });
  }

  Future<String> _transcribe(
    File file,
    SpeechTranscriptionContext context,
  ) async {
    final key =
        '${file.path}|${context.origin.name}|${context.prompt}|${context.keywords.join('|')}';
    final cached = _cache[key]?.toString();
    if (cached != null) return cached;
    final text = await speech.transcribeAudioFile(
      file,
      language: SupportedLanguages.english,
      context: context,
    );
    final value = text?.trim() ?? '';
    _cache[key] = value;
    return value;
  }

  Future<_TranscriptEvaluation> _evaluateTranscript(
    SyntheticSttUtterance utterance,
    String condition,
    SyntheticSttStrategy strategy,
    TranscriptionOrigin origin,
    String transcript, {
    required int sttCalls,
    required int sttLatencyMs,
    required Stopwatch totalWatch,
    int priorElapsedMs = 0,
    List<String>? fixedVocabulary,
  }) async {
    final parse = await _parseWithBackoff(
      recovery.recover(transcript).normalizedTranscript,
    );
    final query = parse.query;
    List<EntitySearchCandidate> candidates = const [];
    EntityResolutionResult? resolution;
    if (parse.isSuccess && query != null) {
      final mention = _mention(query, utterance.target.entityType);
      if (mention != null) {
        candidates = await entitySearch.search(
          EntitySearchRequest(
            rawMention: mention,
            entityType: utterance.target.entityType,
            personRole: query.personRole,
            year: query.years.firstOrNull,
            limit: 10,
          ),
        );
      }
      resolution = await resolver.resolveControlled(query, voice: true);
    }
    totalWatch.stop();
    final resolved = resolution?.resolutions.values
        .where((value) => value.isResolved)
        .firstOrNull
        ?.resolvedCandidate;
    final correctResolved =
        resolved != null &&
        _matchesIdentity(resolved.id, resolved.canonicalName, utterance.target);
    final wrongResolved = resolved != null && !correctResolved;
    final requiresClarification = resolution?.requiresClarification ?? false;
    final top = candidates.firstOrNull;
    final vocabulary = fixedVocabulary ?? _vocabulary(candidates);
    final safelyResolved =
        resolved != null && !wrongResolved && !requiresClarification;
    final phoneticOnly =
        top != null &&
        top.matchedBy.contains('phonetic') &&
        !top.matchedBy.contains('exact') &&
        !top.matchedBy.contains('normalized_exact') &&
        !top.matchedBy.contains('token');
    return _TranscriptEvaluation(
      result: SyntheticSttEvaluationResult(
        sampleId: utterance.id,
        audioCondition: condition,
        strategy: strategy,
        transcriptionOrigin: origin,
        expectedText: utterance.text,
        transcript: transcript,
        expectedCanonicalId: utterance.target.canonicalId,
        expectedCanonicalName: utterance.target.canonicalName,
        entityType: utterance.target.entityType,
        secondPassTriggered: origin == TranscriptionOrigin.dynamicBiased,
        sttCalls: sttCalls,
        sttLatencyMs: sttLatencyMs,
        totalLatencyMs: priorElapsedMs + totalWatch.elapsedMilliseconds,
        canonicalAt1: top?.canonicalId == utterance.target.canonicalId,
        correctConfident: correctResolved && !requiresClarification,
        wrongConfident: wrongResolved && !requiresClarification,
        clarification: requiresClarification,
        noMatch: resolved == null && !requiresClarification,
        biasVocabulary: vocabulary,
        wer: _errorRate(
          utterance.text.split(RegExp(r'\s+')),
          transcript.split(RegExp(r'\s+')),
        ),
        cer: _errorRate(
          utterance.text.runes.toList(),
          transcript.runes.toList(),
        ),
      ),
      shouldTriggerSecondPass: !safelyResolved || phoneticOnly,
      candidateVocabulary: vocabulary,
    );
  }

  static String? _mention(SearchQuery query, SearchEntityType type) =>
      switch (type) {
        SearchEntityType.rally => query.rallyNames.firstOrNull,
        SearchEntityType.person => query.driverNames.firstOrNull,
        SearchEntityType.stage => query.stageNames.firstOrNull,
        SearchEntityType.uploader => query.uploaders.firstOrNull,
      };

  static List<String> _vocabulary(List<EntitySearchCandidate> candidates) {
    final values = <String>[];
    for (final candidate in candidates) {
      for (final name in <String>[
        candidate.canonicalName,
        if (candidate.metadata['searchableNames'] is Iterable)
          ...(candidate.metadata['searchableNames'] as Iterable).map(
            (e) => e.toString(),
          ),
      ]) {
        if (name.trim().isNotEmpty && !values.contains(name)) values.add(name);
      }
    }
    return values;
  }

  static bool _matchesIdentity(
    String id,
    String name,
    SyntheticSttEntity target,
  ) {
    if (id == target.canonicalId) return true;
    if (target.canonicalId.endsWith(id) || id.endsWith(target.canonicalId)) {
      return true;
    }
    return _normalize(name) == _normalize(target.canonicalName);
  }

  static String _normalize(String value) =>
      PhoneticMatchingHelper.collapseSpaces(
        PhoneticMatchingHelper.stripDescriptors(value),
      );

  static SyntheticSttEvaluationResult _copyAsDynamic(
    SyntheticSttEvaluationResult baseline,
    SyntheticSttStrategy strategy,
    List<String> vocabulary,
  ) => SyntheticSttEvaluationResult(
    sampleId: baseline.sampleId,
    audioCondition: baseline.audioCondition,
    strategy: strategy,
    transcriptionOrigin: TranscriptionOrigin.baseline,
    expectedText: baseline.expectedText,
    transcript: baseline.transcript,
    expectedCanonicalId: baseline.expectedCanonicalId,
    expectedCanonicalName: baseline.expectedCanonicalName,
    entityType: baseline.entityType,
    secondPassTriggered: false,
    sttCalls: 1,
    sttLatencyMs: baseline.sttLatencyMs,
    totalLatencyMs: baseline.totalLatencyMs,
    canonicalAt1: baseline.canonicalAt1,
    correctConfident: baseline.correctConfident,
    wrongConfident: baseline.wrongConfident,
    clarification: baseline.clarification,
    noMatch: baseline.noMatch,
    biasVocabulary: vocabulary,
    wer: baseline.wer,
    cer: baseline.cer,
  );

  static double _errorRate<T>(List<T> expected, List<T> actual) {
    if (expected.isEmpty) return actual.isEmpty ? 0 : 1;
    final previous = List<int>.generate(actual.length + 1, (i) => i);
    for (var i = 1; i <= expected.length; i++) {
      var diagonal = previous[0];
      previous[0] = i;
      for (var j = 1; j <= actual.length; j++) {
        final above = previous[j];
        previous[j] = expected[i - 1] == actual[j - 1]
            ? diagonal
            : 1 + min(diagonal, min(previous[j], previous[j - 1]));
        diagonal = above;
      }
    }
    return previous.last / expected.length;
  }

  Future<QueryParseResult> _parseWithBackoff(String transcript) async {
    late QueryParseResult result;
    for (var attempt = 0; attempt < 6; attempt++) {
      result = await parser.parse(transcript);
      final error = result.error?.toString().toLowerCase() ?? '';
      if (!error.contains('429') && !error.contains('rate limit')) {
        return result;
      }
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
    }
    return result;
  }

  Map<String, dynamic> _loadCache() {
    if (!cacheFile.existsSync()) return {};
    return jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
  }

  void _saveCache() {
    cacheFile.parent.createSync(recursive: true);
    cacheFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(_cache),
    );
  }
}

class _TranscriptEvaluation {
  final SyntheticSttEvaluationResult result;
  final bool shouldTriggerSecondPass;
  final List<String> candidateVocabulary;
  const _TranscriptEvaluation({
    required this.result,
    required this.shouldTriggerSecondPass,
    required this.candidateVocabulary,
  });
}
