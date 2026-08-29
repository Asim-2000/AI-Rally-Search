import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/services/friendly_response_service.dart';
import 'package:ai_rally_search/services/special_query_matcher.dart';

void main() {
  const matcher = SpecialQueryMatcher();

  group('SpecialQueryMatcher', () {
    final cases = <String, FriendlyResponseCategory>{
      'What is the weather?': FriendlyResponseCategory.weather,
      'Hello!': FriendlyResponseCategory.greeting,
      'Thank you': FriendlyResponseCategory.thanks,
      'Who are you?': FriendlyResponseCategory.identity,
      'What can you do?': FriendlyResponseCategory.capabilities,
      'Tell me a joke': FriendlyResponseCategory.joke,
      'Are you alive?': FriendlyResponseCategory.alive,
      'Who is the best rally driver?': FriendlyResponseCategory.rallyOpinion,
      'What is the capital of France?': FriendlyResponseCategory.unsupported,
    };

    for (final entry in cases.entries) {
      test('matches ${entry.key}', () {
        expect(matcher.match(entry.key)?.category, entry.value);
      });
    }

    test('does not consume a complex rally weather query', () {
      expect(matcher.match('weather at Rally Aluksne 2026'), isNull);
    });

    test('does not consume normal rally queries', () {
      expect(matcher.match('Who won Rally Aluksne 2026?'), isNull);
    });
  });

  group('FriendlyResponseService', () {
    test('has useful copy for every category', () {
      const service = FriendlyResponseService();
      for (final category in FriendlyResponseCategory.values) {
        expect(service.responseFor(category), isNotEmpty);
      }
    });

    test('variant selection is injectable and deterministic', () {
      final service = FriendlyResponseService(selector: (_, __) => 1);
      expect(
        service.responseFor(FriendlyResponseCategory.greeting),
        'Hi, navigator. What rally are we looking for?',
      );
    });

    test('machine error codes remain explicit', () {
      expect(SearchErrorCode.searchNoResults.value, 'SEARCH_NO_RESULTS');
      expect(SearchErrorCode.queryParseFailed.value, 'QUERY_PARSE_FAILED');
      expect(SearchErrorCode.networkError.value, 'NETWORK_ERROR');
      expect(SearchErrorCode.requestTimeout.value, 'REQUEST_TIMEOUT');
      expect(SearchErrorCode.serverError.value, 'SERVER_ERROR');
      expect(SearchErrorCode.emptyTranscript.value, 'EMPTY_TRANSCRIPT');
    });
  });
}
