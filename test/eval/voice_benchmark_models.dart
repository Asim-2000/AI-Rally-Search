import 'dart:math';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/supported_language.dart';

/// Ground-truth benchmark case for real multilingual voice search evaluation.
class VoiceBenchmarkCase {
  final String id;
  final SupportedLanguage language;
  final String expectedTranscript;
  final List<int>? audioBytes;
  final String? audioPath;
  final List<String> expectedDrivers;
  final List<String> expectedRallies;
  final List<String> expectedStages;
  final List<String> expectedActions;
  final SearchQuery expectedQuery;

  const VoiceBenchmarkCase({
    required this.id,
    required this.language,
    required this.expectedTranscript,
    this.audioBytes,
    this.audioPath,
    this.expectedDrivers = const [],
    this.expectedRallies = const [],
    this.expectedStages = const [],
    this.expectedActions = const [],
    required this.expectedQuery,
  });
}

/// Evaluated result for a single multilingual voice query.
class VoiceEvaluationResult {
  final VoiceBenchmarkCase benchmarkCase;
  final String transcribedText;
  final double wordErrorRate;
  final double entityErrorRate;
  final bool driverPreserved;
  final bool rallyPreserved;
  final bool stagePreserved;
  final bool actionPreserved;
  final bool semanticQueryMatched;
  final bool databaseExecutionSucceeded;
  final int returnedRowCount;
  final int sttLatencyMs;
  final int llmParseLatencyMs;
  final int entityResolutionLatencyMs;
  final int dbLatencyMs;
  final int totalLatencyMs;
  final SearchQuery? resolvedQuery;
  final String? errorMessage;

  const VoiceEvaluationResult({
    required this.benchmarkCase,
    required this.transcribedText,
    required this.wordErrorRate,
    required this.entityErrorRate,
    required this.driverPreserved,
    required this.rallyPreserved,
    required this.stagePreserved,
    required this.actionPreserved,
    required this.semanticQueryMatched,
    required this.databaseExecutionSucceeded,
    required this.returnedRowCount,
    required this.sttLatencyMs,
    required this.llmParseLatencyMs,
    required this.entityResolutionLatencyMs,
    required this.dbLatencyMs,
    required this.totalLatencyMs,
    this.resolvedQuery,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': benchmarkCase.id,
        'language': benchmarkCase.language.languageCode,
        'locale': benchmarkCase.language.localeCode,
        'expected_transcript': benchmarkCase.expectedTranscript,
        'transcribed_text': transcribedText,
        'word_error_rate': wordErrorRate,
        'entity_error_rate': entityErrorRate,
        'driver_preserved': driverPreserved,
        'rally_preserved': rallyPreserved,
        'stage_preserved': stagePreserved,
        'action_preserved': actionPreserved,
        'semantic_query_matched': semanticQueryMatched,
        'database_execution_succeeded': databaseExecutionSucceeded,
        'returned_row_count': returnedRowCount,
        'stt_latency_ms': sttLatencyMs,
        'llm_parse_latency_ms': llmParseLatencyMs,
        'entity_resolution_latency_ms': entityResolutionLatencyMs,
        'db_latency_ms': dbLatencyMs,
        'total_latency_ms': totalLatencyMs,
        'resolved_query': resolvedQuery?.toMap(),
        'error_message': errorMessage,
      };
}

/// Helper methods for computing STT evaluation metrics (WER, Levenshtein, Entity Preservation).
class VoiceMetricsCalculator {
  VoiceMetricsCalculator._();

  /// Calculates Word Error Rate (WER) using Levenshtein distance on normalized word tokens.
  static double calculateWer(String reference, String hypothesis) {
    final refWords = _tokenize(reference);
    final hypWords = _tokenize(hypothesis);

    if (refWords.isEmpty) {
      return hypWords.isEmpty ? 0.0 : 1.0;
    }

    final d = List.generate(
      refWords.length + 1,
      (i) => List.filled(hypWords.length + 1, 0),
    );

    for (var i = 0; i <= refWords.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= hypWords.length; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= refWords.length; i++) {
      for (var j = 1; j <= hypWords.length; j++) {
        final cost = refWords[i - 1] == hypWords[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1, // deletion
          d[i][j - 1] + 1, // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return (d[refWords.length][hypWords.length] / refWords.length).clamp(0.0, 1.0);
  }

  /// Calculates Entity Error Rate across drivers, rallies, stages, and actions.
  static double calculateEntityErrorRate({
    required List<String> expectedEntities,
    required String hypothesis,
  }) {
    if (expectedEntities.isEmpty) return 0.0;

    final normHyp = hypothesis.toLowerCase();
    int missed = 0;
    for (final entity in expectedEntities) {
      if (!normHyp.contains(entity.toLowerCase())) {
        missed++;
      }
    }

    return missed / expectedEntities.length;
  }

  /// Checks if specific entity term is preserved in hypothesis.
  static bool isEntityPreserved(String expectedEntity, String hypothesis) {
    if (expectedEntity.isEmpty) return true;
    final normHyp = hypothesis.toLowerCase();
    final normExp = expectedEntity.toLowerCase();

    if (normHyp.contains(normExp)) return true;

    // Fuzzy check on tokens (e.g. "Moffett" in "Josh Moffett")
    final tokens = normExp.split(' ').where((t) => t.length > 2);
    for (final token in tokens) {
      if (normHyp.contains(token)) return true;
    }

    return false;
  }

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '') // preserve Arabic/Urdu unicode chars
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }
}
