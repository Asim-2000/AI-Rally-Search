import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../llm_provider_config.dart';
import '../llm_query_parser.dart';
import '../query_output_validator.dart';
import '../query_parse_result.dart';
import '../query_understanding_spec.dart';

/// Google Gemini implementation of LlmQueryParser using the Generative Language API
/// with responseMimeType="application/json" and responseSchema structured outputs.
class GeminiQueryParser implements LlmQueryParser {
  final LlmConfig config;
  final http.Client _client;

  GeminiQueryParser({
    LlmConfig? config,
    http.Client? client,
  })  : config = config ?? LlmConfig.fromEnvironment(defaultProvider: LlmProvider.gemini),
        _client = client ?? http.Client();

  @override
  LlmProvider get provider => LlmProvider.gemini;

  @override
  Future<QueryParseResult> parse(
    String userQuery, {
    SearchContext? context,
  }) async {
    final apiKey = config.apiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      return QueryParseResult.failure(
        error: 'Gemini API key is missing or empty. Please check your .env configuration (GEMINI_API_KEY).',
        provider: LlmProvider.gemini,
        model: config.model,
      );
    }

    final baseUrl = config.baseUrl ?? 'https://generativelanguage.googleapis.com/v1beta';
    final modelName = config.model.startsWith('models/') ? config.model : 'models/${config.model}';
    final url = Uri.parse('$baseUrl/$modelName:generateContent?key=$apiKey');

    final stopwatch = Stopwatch()..start();

    // Prepare contextual user message
    final StringBuffer promptBuffer = StringBuffer();
    if (context != null) {
      if (context.currentYear != null) {
        promptBuffer.writeln('[Context: current year is ${context.currentYear}]');
      }
      if (context.activeRally != null) {
        promptBuffer.writeln('[Context: active rally filter is "${context.activeRally}"]');
      }
      if (context.activeDriver != null) {
        promptBuffer.writeln('[Context: active driver filter is "${context.activeDriver}"]');
      }
    }
    promptBuffer.write(userQuery);

    final requestBody = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': promptBuffer.toString()}
          ],
        }
      ],
      'systemInstruction': {
        'parts': [
          {'text': QueryUnderstandingSpec.systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': config.temperature,
        'responseMimeType': 'application/json',
        'responseSchema': QueryUnderstandingSpec.geminiResponseSchema,
      },
    };

    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(config.timeout);

      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMilliseconds;

      if (response.statusCode != 200) {
        String errorDetail = 'HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(response.body);
          if (errJson is Map && errJson.containsKey('error')) {
            errorDetail = errJson['error']['message']?.toString() ?? errorDetail;
          }
        } catch (_) {}

        return QueryParseResult.failure(
          error: 'Gemini API request failed ($errorDetail)',
          provider: LlmProvider.gemini,
          model: config.model,
          latencyMs: latencyMs,
          rawResponse: response.body,
        );
      }

      final Map<String, dynamic> responseJson = jsonDecode(utf8.decode(response.bodyBytes));
      final candidates = responseJson['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        return QueryParseResult.failure(
          error: 'Gemini response contained no candidates',
          provider: LlmProvider.gemini,
          model: config.model,
          latencyMs: latencyMs,
          rawResponse: response.body,
        );
      }

      final candidate = candidates.first as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final textContent = (parts != null && parts.isNotEmpty) ? parts.first['text']?.toString() ?? '' : '';

      final usageMetadata = responseJson['usageMetadata'] as Map<String, dynamic>?;
      final promptTokens = usageMetadata?['promptTokenCount'] as int?;
      final completionTokens = usageMetadata?['candidatesTokenCount'] as int?;
      final totalTokens = usageMetadata?['totalTokenCount'] as int?;

      return QueryOutputValidator.validateAndParse(
        rawContent: textContent,
        provider: LlmProvider.gemini,
        model: config.model,
        latencyMs: latencyMs,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        totalTokens: totalTokens,
        metadata: {
          'finish_reason': candidate['finishReason'],
        },
      );
    } on TimeoutException {
      stopwatch.stop();
      return QueryParseResult.failure(
        error: 'Gemini API request timed out after ${config.timeout.inSeconds}s',
        provider: LlmProvider.gemini,
        model: config.model,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return QueryParseResult.failure(
        error: 'Gemini connection error: $e',
        provider: LlmProvider.gemini,
        model: config.model,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}
