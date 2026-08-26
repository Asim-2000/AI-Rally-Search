import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/openai_query_parser.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = await handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('OpenAIQueryParser Unit Tests', () {
    const testConfig = LlmConfig(
      provider: LlmProvider.openai,
      model: 'gpt-4o-mini',
      apiKey: 'test-sk-123456789',
      baseUrl: 'https://api.openai.com/v1',
    );

    test('Parses valid OpenAI structured JSON response into SearchQuery', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.toString(), 'https://api.openai.com/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer test-sk-123456789');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-4o-mini');
        expect(body['response_format']['type'], 'json_schema');

        const mockResponse = '''
        {
          "id": "chatcmpl-test",
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "content": "{\\"intent\\": \\"SEARCH_VIDEO_ACTIONS\\", \\"actionType\\": \\"drift\\", \\"rallyName\\": \\"Trackrod Rally\\", \\"stageName\\": \\"Gale Rigg\\", \\"year\\": null, \\"limit\\": 20, \\"offset\\": 0, \\"requiresClarification\\": false, \\"clarificationQuestion\\": null}"
              },
              "finish_reason": "stop"
            }
          ],
          "usage": {
            "prompt_tokens": 120,
            "completion_tokens": 45,
            "total_tokens": 165
          }
        }
        ''';

        return http.Response(mockResponse, 200, headers: {'content-type': 'application/json'});
      });

      final parser = OpenAIQueryParser(config: testConfig, client: mockClient);
      final result = await parser.parse('Show drift highlights from Trackrod Rally on Gale Rigg');

      expect(result.isSuccess, isTrue);
      expect(result.provider, LlmProvider.openai);
      expect(result.model, 'gpt-4o-mini');
      expect(result.promptTokens, 120);
      expect(result.completionTokens, 45);
      expect(result.totalTokens, 165);

      final q = result.query!;
      expect(q.intent, SearchIntent.searchVideoActions);
      expect(q.actionType, 'drift');
      expect(q.targetRallyName, 'Trackrod Rally');
      expect(q.stageName, 'Gale Rigg');
      expect(result.interpretedSummary, contains('drift highlights'));
    });

    test('Includes context metadata in prompt when provided', () async {
      bool contextChecked = false;
      final mockClient = MockHttpClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        final userMessage = messages.last['content'] as String;

        expect(userMessage, contains('current year is 2026'));
        expect(userMessage, contains('active rally filter is "Moonraker"'));
        contextChecked = true;

        return http.Response(
          '{"choices":[{"message":{"content":"{\\"intent\\":\\"SEARCH_RALLIES\\",\\"year\\":2026}"}}]}',
          200,
        );
      });

      final parser = OpenAIQueryParser(config: testConfig, client: mockClient);
      await parser.parse(
        'Show this year\'s event',
        context: const SearchContext(currentYear: 2026, activeRally: 'Moonraker'),
      );

      expect(contextChecked, isTrue);
    });

    test('Handles HTTP 401 Unauthorized cleanly without leaking keys', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response(
          '{"error": {"message": "Incorrect API key provided"}}',
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final parser = OpenAIQueryParser(config: testConfig, client: mockClient);
      final result = await parser.parse('Show rallies in Ireland');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Incorrect API key provided'));
      expect(result.error, isNot(contains('test-sk-123456789')));
    });

    test('Rejects early if API key is missing', () async {
      const emptyKeyConfig = LlmConfig(
        provider: LlmProvider.openai,
        model: 'gpt-4o-mini',
        apiKey: null,
      );

      final parser = OpenAIQueryParser(config: emptyKeyConfig);
      final result = await parser.parse('Show rallies');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('OpenAI API key is missing or empty'));
    });
  });
}
