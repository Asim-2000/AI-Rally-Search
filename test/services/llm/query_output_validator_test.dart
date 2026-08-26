import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/query_output_validator.dart';

void main() {
  group('QueryOutputValidator Unit Tests', () {
    test('Valid raw JSON parsed and validated into canonical SearchQuery', () {
      const rawJson = '''
      {
        "intent": "SEARCH_VIDEO_ACTIONS",
        "actionType": "jump",
        "driverName": "Josh Moffett",
        "rallyName": "Moonraker Forestry Rally",
        "country": "Ireland",
        "year": 2025,
        "limit": 10,
        "offset": 0,
        "requiresClarification": false,
        "clarificationQuestion": null
      }
      ''';

      final result = QueryOutputValidator.validateAndParse(
        rawContent: rawJson,
        provider: LlmProvider.openai,
        model: 'gpt-4o-mini',
        latencyMs: 120,
        promptTokens: 100,
        completionTokens: 50,
        totalTokens: 150,
      );

      expect(result.isSuccess, isTrue);
      expect(result.requiresClarification, isFalse);
      expect(result.error, isNull);

      final q = result.query!;
      expect(q.intent, SearchIntent.searchVideoActions);
      expect(q.actionType, 'jump');
      expect(q.driverName, 'Josh Moffett');
      expect(q.rallyName, 'Moonraker Forestry Rally');
      expect(q.country, 'Ireland');
      expect(q.year, 2025);
      expect(q.limit, 10);
      expect(result.latencyMs, 120);
      expect(result.totalTokens, 150);
      expect(result.interpretedSummary, contains('jump highlights'));
      expect(result.interpretedSummary, contains('Josh Moffett'));
    });

    test('Extracts JSON wrapped in markdown code fence (```json ... ```)', () {
      const rawWithFence = '''
      Here is the query you requested:
      ```json
      {
        "intent": "SEARCH_RALLIES",
        "country": "Ireland",
        "year": 2026
      }
      ```
      Hope this helps!
      ''';

      final result = QueryOutputValidator.validateAndParse(rawContent: rawWithFence);
      expect(result.isSuccess, isTrue);
      expect(result.query!.intent, SearchIntent.searchRallies);
      expect(result.query!.country, 'Ireland');
      expect(result.query!.year, 2026);
    });

    test('Rejects / sanitizes invalid action types to null', () {
      final map = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'actionType': 'rocket_jump', // Invalid action
      };

      final result = QueryOutputValidator.validateMap(jsonMap: map);
      expect(result.isSuccess, isTrue);
      expect(result.query!.actionType, isNull);
    });

    test('Sanitizes invalid out-of-bounds year to null', () {
      final map = {
        'intent': 'SEARCH_RALLIES',
        'year': 999999, // Unrealistic year
      };

      final result = QueryOutputValidator.validateMap(jsonMap: map);
      expect(result.isSuccess, isTrue);
      expect(result.query!.year, isNull);
    });

    test('Clamps limit within bounds (1 to 200)', () {
      final map = {
        'intent': 'SEARCH_RALLIES',
        'limit': 5000,
      };

      final result = QueryOutputValidator.validateMap(jsonMap: map);
      expect(result.isSuccess, isTrue);
      expect(result.query!.limit, 200);
    });

    test('Detects and returns clarification when requested by LLM', () {
      final map = {
        'intent': 'SEARCH_RALLIES',
        'requiresClarification': true,
        'clarificationQuestion': 'Which year of the rally are you looking for?',
      };

      final result = QueryOutputValidator.validateMap(jsonMap: map);
      expect(result.isSuccess, isFalse);
      expect(result.requiresClarification, isTrue);
      expect(result.clarificationQuestion, 'Which year of the rally are you looking for?');
    });

    test('Fails safely on malformed / empty input', () {
      final result = QueryOutputValidator.validateAndParse(rawContent: 'This is not JSON at all');
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Failed to extract valid JSON'));
    });

    test('Normalizes action aliases (water splash, donut, hairpin, watr splash)', () {
      expect(QueryOutputValidator.normalizeActionType('water splash'), 'water splash');
      expect(QueryOutputValidator.normalizeActionType('water splashes'), 'water splash');
      expect(QueryOutputValidator.normalizeActionType('water crossing'), 'water splash');
      expect(QueryOutputValidator.normalizeActionType('watr splash'), 'water splash');
      expect(QueryOutputValidator.normalizeActionType('splashes'), 'water splash');
      expect(QueryOutputValidator.normalizeActionType('donut'), 'donut');
      expect(QueryOutputValidator.normalizeActionType('donuts'), 'donut');
      expect(QueryOutputValidator.normalizeActionType('doughnut'), 'donut');
      expect(QueryOutputValidator.normalizeActionType('doughnuts'), 'donut');
      expect(QueryOutputValidator.normalizeActionType('hairpin'), 'hairpin');
      expect(QueryOutputValidator.normalizeActionType('hairpins'), 'hairpin');
      expect(QueryOutputValidator.normalizeActionType('handbrake turn'), 'hairpin');
      expect(QueryOutputValidator.normalizeActionType('jumsp'), 'jump');
    });

    test('Normalizes country typos deterministically', () {
      expect(QueryOutputValidator.normalizeCountry('Irelnd'), 'Ireland');
      expect(QueryOutputValidator.normalizeCountry('irelnd'), 'Ireland');
      expect(QueryOutputValidator.normalizeCountry('great britan'), 'United Kingdom');
      expect(QueryOutputValidator.normalizeCountry('germny'), 'Germany');
      expect(QueryOutputValidator.normalizeCountry('portugl'), 'Portugal');
      expect(QueryOutputValidator.normalizeCountry('polnd'), 'Poland');
      expect(QueryOutputValidator.normalizeCountry('spn'), 'Spain');
      expect(QueryOutputValidator.normalizeCountry('latva'), 'Latvia');
    });
  });
}

