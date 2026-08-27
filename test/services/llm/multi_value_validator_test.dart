import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/query_output_validator.dart';

void main() {
  group('QueryOutputValidator Multi-Value Tests', () {
    test('Validates multi-value arrays from JSON and generates multi-filter summary', () {
      const rawJson = '''
      {
        "intent": "SEARCH_VIDEO_ACTIONS",
        "actionTypes": ["jump", "drift"],
        "driverNames": ["Josh Moffett", "Sam Moffett"],
        "rallyNames": ["Moonraker", "Trackrod"],
        "countries": ["Ireland", "Scotland"],
        "years": [2024, 2025],
        "driverMatchMode": "ANY",
        "limit": 20,
        "offset": 0,
        "requiresClarification": false,
        "clarificationQuestion": null
      }
      ''';

      final result = QueryOutputValidator.validateAndParse(rawContent: rawJson);
      expect(result.isSuccess, isTrue);
      expect(result.requiresClarification, isFalse);

      final q = result.query!;
      expect(q.intent, equals(SearchIntent.searchVideoActions));
      expect(q.actionTypes, equals(['jump', 'drift']));
      expect(q.driverNames, equals(['Josh Moffett', 'Sam Moffett']));
      expect(q.rallyNames, equals(['Moonraker', 'Trackrod']));
      expect(q.countries, equals(['Ireland', 'Scotland']));
      expect(q.years, equals([2024, 2025]));
      expect(q.driverMatchMode, equals(MatchMode.any));

      expect(result.interpretedSummary, contains('jump, drift highlights'));
      expect(result.interpretedSummary, contains('Josh Moffett, Sam Moffett'));
      expect(result.interpretedSummary, contains('Moonraker, Trackrod'));
      expect(result.interpretedSummary, contains('Ireland, Scotland'));
      expect(result.interpretedSummary, contains('2024, 2025'));
    });

    test('Deduplicates country aliases and normalizes typos across arrays', () {
      final jsonMap = {
        'intent': 'SEARCH_RALLIES',
        'countries': ['ROI', 'Ireland', 'ie', 'Irelnd', 'Scotland'],
      };

      final result = QueryOutputValidator.validateMap(jsonMap: jsonMap);
      expect(result.isSuccess, isTrue);
      final q = result.query!;
      // 'ROI', 'Ireland', 'ie', 'Irelnd' all normalize to 'Ireland', so deduplicated to 'Ireland', 'Scotland'
      expect(q.countries, equals(['Ireland', 'Scotland']));
    });

    test('Deduplicates and normalizes action aliases across arrays', () {
      final jsonMap = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'actionTypes': ['jumps', 'jump', 'jumping', 'drifting', 'slide'],
      };

      final result = QueryOutputValidator.validateMap(jsonMap: jsonMap);
      expect(result.isSuccess, isTrue);
      final q = result.query!;
      expect(q.actionTypes, equals(['jump', 'drift']));
    });

    test('Validates year ranges and formats range in summary', () {
      final jsonMap = {
        'intent': 'SEARCH_RALLIES',
        'yearFrom': 2023,
        'yearTo': 2025,
      };

      final result = QueryOutputValidator.validateMap(jsonMap: jsonMap);
      expect(result.isSuccess, isTrue);
      final q = result.query!;
      expect(q.yearFrom, equals(2023));
      expect(q.yearTo, equals(2025));
      expect(result.interpretedSummary, contains('2023–2025'));
    });

    test('Handles MatchMode.all for driver queries', () {
      final jsonMap = {
        'intent': 'SEARCH_DRIVER_RALLIES',
        'driverNames': ['Josh Moffett', 'Sam Moffett'],
        'driverMatchMode': 'ALL',
      };

      final result = QueryOutputValidator.validateMap(jsonMap: jsonMap);
      expect(result.isSuccess, isTrue);
      final q = result.query!;
      expect(q.driverMatchMode, equals(MatchMode.all));
      expect(result.interpretedSummary, contains('Josh Moffett AND Sam Moffett'));
    });

    test('Filters out invalid action types from array safely', () {
      final jsonMap = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'actionTypes': ['jump', 'invalid_action_type', 'drift'],
      };

      final result = QueryOutputValidator.validateMap(jsonMap: jsonMap);
      expect(result.isSuccess, isTrue);
      final q = result.query!;
      expect(q.actionTypes, equals(['jump', 'drift']));
    });
  });
}
