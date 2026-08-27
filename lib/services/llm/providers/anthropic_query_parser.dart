import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../llm_provider_config.dart';
import '../llm_query_parser.dart';
import '../query_output_validator.dart';
import '../query_parse_result.dart';
import '../query_understanding_spec.dart';

/// Anthropic implementation of LlmQueryParser using the Messages API and Tool Use
/// for guaranteed structured schema output.
class AnthropicQueryParser implements LlmQueryParser {
  final LlmConfig config;
  final http.Client _client;

  AnthropicQueryParser({
    LlmConfig? config,
    http.Client? client,
  })  : config = config ?? LlmConfig.fromEnvironment(defaultProvider: LlmProvider.anthropic),
        _client = client ?? http.Client();

  @override
  LlmProvider get provider => LlmProvider.anthropic;

  @override
  Future<QueryParseResult> parse(
    String userQuery, {
    SearchContext? context,
  }) async {
    final apiKey = config.apiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      return QueryParseResult.failure(
        error: 'Anthropic API key is missing or empty. Please check your .env configuration (ANTHROPIC_API_KEY).',
        provider: LlmProvider.anthropic,
        model: config.model,
      );
    }

    final baseUrl = config.baseUrl ?? 'https://api.anthropic.com/v1';
    final url = Uri.parse('$baseUrl/messages');

    final stopwatch = Stopwatch()..start();

    // Prepare contextual user message
    final StringBuffer promptBuffer = StringBuffer();
    if (context != null) {
      promptBuffer.write(context.formatPromptContext());
    }
    promptBuffer.write(userQuery);

    final requestBody = {
      'model': config.model,
      'max_tokens': 1024,
      'system': QueryUnderstandingSpec.systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': promptBuffer.toString(),
        }
      ],
      'temperature': config.temperature,
      'tools': [
        {
          'name': 'rally_search_query',
          'description': 'Extract structured rally search query parameters according to the specification.',
          'input_schema': QueryUnderstandingSpec.jsonSchema['schema'],
        }
      ],
      'tool_choice': {
        'type': 'tool',
        'name': 'rally_search_query',
      },
    };

    // Retry loop for transient failures (HTTP 429, 5xx, timeout)
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
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
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
            error: 'Anthropic API request failed ($errorDetail)',
            provider: LlmProvider.anthropic,
            model: config.model,
            latencyMs: latencyMs,
            rawResponse: response.body,
          );
        }

        final Map<String, dynamic> responseJson = jsonDecode(utf8.decode(response.bodyBytes));
        final contentList = responseJson['content'] as List<dynamic>?;
        if (contentList == null || contentList.isEmpty) {
          return QueryParseResult.failure(
            error: 'Anthropic response contained no content blocks',
            provider: LlmProvider.anthropic,
            model: config.model,
            latencyMs: latencyMs,
            rawResponse: response.body,
          );
        }

        // Find tool_use block
        Map<String, dynamic>? toolInput;
        for (final block in contentList) {
          if (block is Map<String, dynamic> && block['type'] == 'tool_use') {
            final input = block['input'];
            if (input is Map<String, dynamic>) {
              toolInput = input;
              break;
            }
          }
        }

        if (toolInput == null) {
          // Fallback to text content if no tool_use block
          final textBlock = contentList.firstWhere(
            (b) => b is Map && b['type'] == 'text',
            orElse: () => null,
          );
          final rawText = textBlock?['text']?.toString() ?? '';
          return QueryOutputValidator.validateAndParse(
            rawContent: rawText,
            provider: LlmProvider.anthropic,
            model: config.model,
            latencyMs: latencyMs,
          );
        }

        final usage = responseJson['usage'] as Map<String, dynamic>?;
        final promptTokens = usage?['input_tokens'] as int?;
        final completionTokens = usage?['output_tokens'] as int?;

        return QueryOutputValidator.validateAndParse(
          rawContent: jsonEncode(toolInput),
          provider: LlmProvider.anthropic,
          model: config.model,
          latencyMs: latencyMs,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          totalTokens: (promptTokens ?? 0) + (completionTokens ?? 0),
          metadata: {
            'stop_reason': responseJson['stop_reason'],
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
          error: 'Anthropic API request timed out after ${config.timeout.inSeconds}s',
          provider: LlmProvider.anthropic,
          model: config.model,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } catch (e) {
        stopwatch.stop();
        return QueryParseResult.failure(
          error: 'Anthropic connection error: $e',
          provider: LlmProvider.anthropic,
          model: config.model,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    }

    stopwatch.stop();
    return QueryParseResult.failure(
      error: 'Anthropic retries exhausted',
      provider: LlmProvider.anthropic,
      model: config.model,
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  }
}
