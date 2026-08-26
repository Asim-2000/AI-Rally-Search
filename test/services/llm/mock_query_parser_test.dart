import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';

void main() {
  group('MockLlmQueryParser Tests', () {
    late MockLlmQueryParser parser;

    setUp(() {
      parser = MockLlmQueryParser();
    });

    test('Parses rally search with country and year', () async {
      final res = await parser.parse('Show rallies in Ireland in 2025');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchRallies);
      expect(res.query!.country, 'Ireland');
      expect(res.query!.year, 2025);
    });

    test('Parses "show me rallies in poland" correctly to country=Poland', () async {
      final res = await parser.parse('show me rallies in poland');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchRallies);
      expect(res.query!.country, 'Poland');
    });

    test('Parses compound video action with driver, rally, and action', () async {
      final res = await parser.parse('Show jump highlights featuring Josh Moffett from Moonraker');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.searchVideoActions);
      expect(res.query!.actionType, 'jump');
      expect(res.query!.driverName, 'Josh Moffett');
      expect(res.query!.targetRallyName, 'Moonraker Forestry Rally');
    });

    test('Supports simulated failure', () async {
      final failParser = MockLlmQueryParser(
        simulateFailure: true,
        failureMessage: 'Test simulated error',
      );
      final res = await failParser.parse('Any query');
      expect(res.isSuccess, isFalse);
      expect(res.error, 'Test simulated error');
    });

    test('Supports simulated clarification', () async {
      final clarifyParser = MockLlmQueryParser(
        simulateClarification: true,
        clarificationQuestion: 'Which driver?',
      );
      final res = await clarifyParser.parse('Any query');
      expect(res.isSuccess, isFalse);
      expect(res.requiresClarification, isTrue);
      expect(res.clarificationQuestion, 'Which driver?');
    });

    test('Supports custom overrides', () async {
      final customParser = MockLlmQueryParser(
        customMappings: {
          'custom query': const SearchQuery(
            intent: SearchIntent.getTopDriversByWins,
            limit: 5,
          ),
        },
      );
      final res = await customParser.parse('custom query');
      expect(res.isSuccess, isTrue);
      expect(res.query!.intent, SearchIntent.getTopDriversByWins);
      expect(res.query!.limit, 5);
    });
  });
}
