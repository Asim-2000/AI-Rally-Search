import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';

void main() {
  group('SearchIntent Tests', () {
    test('Serializes and parses all search intents correctly', () {
      for (final intent in SearchIntent.values) {
        final str = intent.toIntentString();
        final parsed = SearchIntent.fromString(str);
        expect(parsed, equals(intent));
      }
    });

    test('Parses lenient user/LLM variations of intent strings', () {
      expect(SearchIntent.fromString('search_rallies'), equals(SearchIntent.searchRallies));
      expect(SearchIntent.fromString('driver_wins'), equals(SearchIntent.searchDriverWins));
      expect(SearchIntent.fromString('RALLY_LEADERBOARD'), equals(SearchIntent.getRallyTopFinishers));
      expect(SearchIntent.fromString('action_moments'), equals(SearchIntent.searchVideoActions));
      expect(SearchIntent.fromString('top_uploaders'), equals(SearchIntent.getTopUploaders));
      expect(SearchIntent.fromString('most_wins'), equals(SearchIntent.getTopDriversByWins));
    });
  });

  group('SearchQuery Model & Normalization Tests', () {
    test('Serializes to and from JSON Map preserving all properties', () {
      const query = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyName: 'Moonraker Forestry Rally',
        country: 'Ireland',
        city: 'Letterkenny',
        year: 2026,
        driverName: 'Josh Moffett',
        limit: 15,
        offset: 30,
      );

      final map = query.toMap();
      expect(map['intent'], equals('SEARCH_RALLIES'));
      expect(map['rallyName'], equals('Moonraker Forestry Rally'));
      expect(map['country'], equals('Ireland'));
      expect(map['city'], equals('Letterkenny'));
      expect(map['year'], equals(2026));
      expect(map['driverName'], equals('Josh Moffett'));
      expect(map['limit'], equals(15));
      expect(map['offset'], equals(30));

      final deserialized = SearchQuery.fromMap(map);
      expect(deserialized.intent, equals(SearchIntent.searchRallies));
      expect(deserialized.targetRallyName, equals('Moonraker Forestry Rally'));
      expect(deserialized.country, equals('Ireland'));
      expect(deserialized.city, equals('Letterkenny'));
      expect(deserialized.year, equals(2026));
      expect(deserialized.driverName, equals('Josh Moffett'));
      expect(deserialized.limit, equals(15));
      expect(deserialized.offset, equals(30));
    });

    test('Resolves country aliases for bidirectional searching', () {
      const queryIE = SearchQuery(intent: SearchIntent.searchRallies, country: 'Ireland');
      expect(queryIE.resolvedCountryAliases, contains('ireland'));
      expect(queryIE.resolvedCountryAliases, contains('ie'));

      const queryUK = SearchQuery(intent: SearchIntent.searchRallies, country: 'UK');
      expect(queryUK.resolvedCountryAliases, contains('united kingdom'));
      expect(queryUK.resolvedCountryAliases, contains('gb'));

      const queryPT = SearchQuery(intent: SearchIntent.searchRallies, country: 'Portugal');
      expect(queryPT.resolvedCountryAliases, contains('portugal'));
      expect(queryPT.resolvedCountryAliases, contains('pt'));
    });

    test('Resolves action types including suffix normalization', () {
      const query = SearchQuery(intent: SearchIntent.searchVideoActions, actionType: 'jump');
      expect(query.resolvedActionTypes, equals(['jump', 'jump_segments']));

      const query2 = SearchQuery(intent: SearchIntent.searchVideoActions, actionType: 'drift_segments');
      expect(query2.resolvedActionTypes, equals(['drift', 'drift_segments']));
    });
  });

  group('Typed SearchResult Models Tests', () {
    test('RallySearchResult parses correctly from database map', () {
      final raw = {
        'event_id': 'evt-123',
        'event_name': 'Donegal Rally 2026',
        'status': 'active',
        'country': 'Ireland',
        'city': 'Letterkenny',
        'start_date': '2026-06-15 00:00:00',
        'end_date': '2026-06-17 23:59:00',
        'stages_count': 20,
        'thumbnail': 'https://assets.example.com/thumb.webp',
      };

      final result = RallySearchResult.fromMap(raw);
      expect(result.eventId, equals('evt-123'));
      expect(result.eventName, equals('Donegal Rally 2026'));
      expect(result.country, equals('Ireland'));
      expect(result.city, equals('Letterkenny'));
      expect(result.stagesCount, equals(20));
      expect(result.year, equals(2026));
      expect(result.formattedLocation, equals('Letterkenny, Ireland'));
    });

    test('RallyParticipationResult formats finish position correctly', () {
      final win = RallyParticipationResult.fromMap({
        'rally_id': 'r-1',
        'event_name': 'Moonraker Rally',
        'driver_name': 'Josh Moffett',
        'pos_overall': 1,
      });
      // Phase 3: compact finish-position copy; winner meaning preserved.
      expect(win.finishPositionDisplay, equals('P1 · Winner'));

      final second = RallyParticipationResult.fromMap({
        'rally_id': 'r-1',
        'event_name': 'Moonraker Rally',
        'driver_name': 'Jordan Hone',
        'pos_overall': 2,
      });
      expect(second.finishPositionDisplay, equals('P2'));

      final fourth = RallyParticipationResult.fromMap({
        'rally_id': 'r-1',
        'event_name': 'Moonraker Rally',
        'driver_name': 'Gareth Mimnagh',
        'pos_overall': 4,
      });
      expect(fourth.finishPositionDisplay, equals('P4'));
    });

    test('RallyResult formats top finisher badges correctly', () {
      final res1 = RallyResult.fromMap({
        'id': 100,
        'rally_id': 'r-1',
        'event_name': 'Moonraker',
        'driver_name': 'Josh Moffett',
        'pos_overall': 1,
        'total_time': '2325.8',
      });
      expect(res1.positionBadge, equals('🏆 1st'));

      final res5 = RallyResult.fromMap({
        'id': 105,
        'rally_id': 'r-1',
        'event_name': 'Moonraker',
        'driver_name': 'Niall McCullagh',
        'pos_overall': 5,
        'total_time': '2369.2',
      });
      expect(res5.positionBadge, equals('#5'));
    });

    test('SearchResponse handles pagination helper getters', () {
      final response = SearchResponse<String>(
        intent: SearchIntent.searchRallies,
        results: ['r1', 'r2'],
        totalCount: 50,
        hasMore: true,
        limit: 20,
        offset: 20,
      );

      expect(response.currentPage, equals(2));
      expect(response.totalPages, equals(3));
    });
  });
}
