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
        error: 'OpenAI API key is missing or empty. Please check your .env configuration (OPENAI_API_KEY).',
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
      if (context.locale != null || context.languageCode != null) {
        final loc = context.locale ?? context.languageCode;
        promptBuffer.writeln('[Context: app locale is "$loc"]');
      }
    }
    promptBuffer.write(userQuery);

    final Map<String, dynamic> requestBody = {
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
      if (modelSupportsTemperature(config.model)) 'temperature': config.temperature,
      'response_format': {
        'type': 'json_schema',
        'json_schema': QueryUnderstandingSpec.jsonSchema,
      },
    };

    int attempts = 0;
    final int maxAttempts = config.maxRetries + 1;

    while (attempts < maxAttempts) {
      attempts++;
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

        if (response.statusCode >= 500 || response.statusCode == 429) {
          if (attempts < maxAttempts) {
            final backoffMs = 500 * (1 << (attempts - 1));
            await Future.delayed(Duration(milliseconds: backoffMs));
            continue;
          }
        }

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
        if (attempts < maxAttempts) {
          final backoffMs = 500 * (1 << (attempts - 1));
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
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

    stopwatch.stop();
    return QueryParseResult.failure(
      error: 'OpenAI retries exhausted',
      provider: LlmProvider.openai,
      model: config.model,
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Returns whether the specified OpenAI model supports a custom temperature parameter.
  ///
  /// OpenAI reasoning models (e.g. o1, o3, o4 series) and next-generation models like
  /// gpt-5 (e.g. gpt-5.6-luna) only support the default temperature and reject requests
  /// containing an explicit temperature parameter with an HTTP 400 error.
  static bool modelSupportsTemperature(String model) {
    final cleanModel = model.toLowerCase().replaceAll('models/', '').trim();
    final baseModel = cleanModel.contains('/') ? cleanModel.split('/').last : cleanModel;

    if (baseModel.startsWith('o1') ||
        baseModel.startsWith('o3') ||
        baseModel.startsWith('o4') ||
        baseModel.startsWith('gpt-5') ||
        baseModel.startsWith('chatgpt-5') ||
        baseModel.contains('reasoning')) {
      return false;
    }
    return true;
  }
}

