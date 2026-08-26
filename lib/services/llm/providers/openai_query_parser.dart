import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../llm_provider_config.dart';
import '../llm_query_parser.dart';
import '../query_output_validator.dart';
import '../query_parse_result.dart';
import '../query_understanding_spec.dart';

/// OpenAI implementation of LlmQueryParser using Chat Completions Structured Outputs.
class OpenAIQueryParser implements LlmQueryParser {
  final LlmConfig config;
  final http.Client _client;

  OpenAIQueryParser({
    LlmConfig? config,
    http.Client? client,
  })  : config = config ?? LlmConfig.fromEnvironment(defaultProvider: LlmProvider.openai),
        _client = client ?? http.Client();

  @override
  LlmProvider get provider => LlmProvider.openai;

  @override
  Future<QueryParseResult> parse(
    String userQuery, {
    SearchContext? context,
  }) async {
    final apiKey = config.apiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      return QueryParseResult.failure(
        error: 'OpenAI API key is missing or empty. Please check your .env configuration.',
        provider: LlmProvider.openai,
        model: config.model,
      );
    }

    final baseUrl = config.baseUrl ?? 'https://api.openai.com/v1';
    final url = Uri.parse('$baseUrl/chat/completions');

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
      'model': config.model,
      'messages': [
        {
          'role': 'system',
          'content': QueryUnderstandingSpec.systemPrompt,
        },
        {
          'role': 'user',
          'content': promptBuffer.toString(),
        },
      ],
      'temperature': config.temperature,
      'response_format': {
        'type': 'json_schema',
        'json_schema': QueryUnderstandingSpec.jsonSchema,
      },
    };

    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
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
          error: 'OpenAI API request failed ($errorDetail)',
          provider: LlmProvider.openai,
          model: config.model,
          latencyMs: latencyMs,
          rawResponse: response.body,
        );
      }

      final Map<String, dynamic> responseJson = jsonDecode(utf8.decode(response.bodyBytes));
      final choices = responseJson['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return QueryParseResult.failure(
          error: 'OpenAI response contained no choices',
          provider: LlmProvider.openai,
          model: config.model,
          latencyMs: latencyMs,
          rawResponse: response.body,
        );
      }

      final message = choices.first['message'];
      final content = message?['content']?.toString() ?? '';

      final usage = responseJson['usage'] as Map<String, dynamic>?;
      final promptTokens = usage?['prompt_tokens'] as int?;
      final completionTokens = usage?['completion_tokens'] as int?;
      final totalTokens = usage?['total_tokens'] as int?;

      return QueryOutputValidator.validateAndParse(
        rawContent: content,
        provider: LlmProvider.openai,
        model: config.model,
        latencyMs: latencyMs,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        totalTokens: totalTokens,
        metadata: {
          'finish_reason': choices.first['finish_reason'],
          'system_fingerprint': responseJson['system_fingerprint'],
        },
      );
    } on TimeoutException {
      stopwatch.stop();
      return QueryParseResult.failure(
        error: 'OpenAI API request timed out after ${config.timeout.inSeconds}s',
        provider: LlmProvider.openai,
        model: config.model,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return QueryParseResult.failure(
        error: 'OpenAI connection error: $e',
        provider: LlmProvider.openai,
        model: config.model,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}
