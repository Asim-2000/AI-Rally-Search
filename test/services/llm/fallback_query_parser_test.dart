import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/providers/fallback_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';

void main() {
  group('FallbackLlmQueryParser Tests', () {
    test('Uses primary parser when primary succeeds', () async {
      final primary = MockLlmQueryParser(
        customMappings: {
          'query': const SearchQuery(
            intent: SearchIntent.searchRallies,
            country: 'Ireland',
          ),
        },
      );
      final fallback = MockLlmQueryParser(
        customMappings: {
          'query': const SearchQuery(
            intent: SearchIntent.searchRallies,
            country: 'France',
          ),
        },
      );

      final fallbackParser = FallbackLlmQueryParser(
        primary: primary,
        fallbacks: [fallback],
      );

      final res = await fallbackParser.parse('query');
      expect(res.isSuccess, isTrue);
      expect(res.query!.country, 'Ireland');
      expect(res.metadata['fallback_used'], isNull);
    });

    test('Cascades to fallback when primary fails', () async {
      final primary = MockLlmQueryParser(
        simulateFailure: true,
        failureMessage: 'Primary OpenAI Timeout',
      );
      final fallback = MockLlmQueryParser(
        customMappings: {
          'query': const SearchQuery(
            intent: SearchIntent.searchRallies,
            country: 'France',
          ),
        },
      );

      final fallbackParser = FallbackLlmQueryParser(
        primary: primary,
        fallbacks: [fallback],
      );

      final res = await fallbackParser.parse('query');
      expect(res.isSuccess, isTrue);
      expect(res.query!.country, 'France');
      expect(res.metadata['fallback_used'], isTrue);
      expect(res.metadata['primary_provider'], LlmProvider.mock.name);
    });

    test('Returns failure if all configured parsers in fallback chain fail', () async {
      final primary = MockLlmQueryParser(simulateFailure: true);
      final fallback1 = MockLlmQueryParser(simulateFailure: true);
      final fallback2 = MockLlmQueryParser(simulateFailure: true);

      final fallbackParser = FallbackLlmQueryParser(
        primary: primary,
        fallbacks: [fallback1, fallback2],
      );

      final res = await fallbackParser.parse('query');
      expect(res.isSuccess, isFalse);
      expect(res.error, contains('All configured LLM query parsers failed'));
      expect(res.metadata['fallback_exhausted'], isTrue);
    });
  });
}
