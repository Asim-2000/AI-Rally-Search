import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/gemini_query_parser.dart';

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
  group('GeminiQueryParser Unit Tests', () {
    const testConfig = LlmConfig(
      provider: LlmProvider.gemini,
      model: 'gemini-1.5-flash',
      apiKey: 'test-gemini-key-12345',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    );

    test('Parses valid Gemini structured JSON response into SearchQuery', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.toString(), contains('generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent'));
        expect(request.url.queryParameters['key'], 'test-gemini-key-12345');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['generationConfig']['responseMimeType'], 'application/json');
        expect(body['generationConfig']['responseSchema'], isNotNull);

        const mockResponse = '''
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "{\\"intent\\": \\"SEARCH_VIDEO_ACTIONS\\", \\"actionType\\": \\"jump\\", \\"driverName\\": \\"Josh Moffett\\", \\"rallyName\\": \\"Moonraker Forestry Rally\\", \\"country\\": \\"Ireland\\", \\"year\\": 2025, \\"limit\\": 20, \\"offset\\": 0, \\"requiresClarification\\": false, \\"clarificationQuestion\\": null}"
                  }
                ],
                "role": "model"
              },
              "finishReason": "STOP"
            }
          ],
          "usageMetadata": {
            "promptTokenCount": 110,
            "candidatesTokenCount": 42,
            "totalTokenCount": 152
          }
        }
        ''';

        return http.Response(mockResponse, 200, headers: {'content-type': 'application/json'});
      });

      final parser = GeminiQueryParser(config: testConfig, client: mockClient);
      final result = await parser.parse('Show jump highlights featuring Josh Moffett from Moonraker in 2025');

      expect(result.isSuccess, isTrue);
      expect(result.provider, LlmProvider.gemini);
      expect(result.model, 'gemini-1.5-flash');
      expect(result.promptTokens, 110);
      expect(result.completionTokens, 42);
      expect(result.totalTokens, 152);

      final q = result.query!;
      expect(q.intent, SearchIntent.searchVideoActions);
      expect(q.actionType, 'jump');
      expect(q.driverName, 'Josh Moffett');
      expect(q.targetRallyName, 'Moonraker Forestry Rally');
      expect(q.country, 'Ireland');
      expect(q.year, 2025);
      expect(result.interpretedSummary, contains('jump highlights'));
    });

    test('Passes search context to user prompt', () async {
      bool contextPassed = false;
      final mockClient = MockHttpClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final contents = body['contents'] as List<dynamic>;
        final userText = contents.first['parts'].first['text'] as String;

        expect(userText, contains('current year is 2026'));
        expect(userText, contains('active rally filter is "Donegal"'));
        contextPassed = true;

        const mockResponse = '{"candidates":[{"content":{"parts":[{"text":"{\\"intent\\":\\"SEARCH_RALLIES\\",\\"year\\":2026}"}]}}]}';
        return http.Response(mockResponse, 200);
      });

      final parser = GeminiQueryParser(config: testConfig, client: mockClient);
      await parser.parse(
        'Show this year\'s rally',
        context: const SearchContext(currentYear: 2026, activeRally: 'Donegal'),
      );

      expect(contextPassed, isTrue);
    });

    test('Handles API HTTP errors gracefully without exposing secrets', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response(
          '{"error": {"message": "API key not valid. Please pass a valid API key."}}',
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final parser = GeminiQueryParser(config: testConfig, client: mockClient);
      final result = await parser.parse('Show rallies in Ireland');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('API key not valid'));
      expect(result.error, isNot(contains('test-gemini-key-12345')));
    });

    test('Fails immediately when Gemini API key is missing', () async {
      const missingKeyConfig = LlmConfig(
        provider: LlmProvider.gemini,
        model: 'gemini-1.5-flash',
        apiKey: null,
      );

      final parser = GeminiQueryParser(config: missingKeyConfig);
      final result = await parser.parse('Show rallies in Poland');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Gemini API key is missing or empty'));
    });
  });
}
