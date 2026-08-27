import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';

void main() {
  group('Multi-Value SearchQuery Tests', () {
    test('Constructs with multi-value fields and preserves list integrity', () {
      final query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        countries: const ['Ireland', 'Scotland'],
        years: const [2024, 2025],
        driverNames: const ['Josh Moffett', 'Sam Moffett'],
        rallyNames: const ['Moonraker', 'Trackrod'],
        driverMatchMode: MatchMode.any,
      );

      expect(query.actionTypes, equals(['jump', 'drift']));
      expect(query.countries, equals(['Ireland', 'Scotland']));
      expect(query.years, equals([2024, 2025]));
      expect(query.driverNames, equals(['Josh Moffett', 'Sam Moffett']));
      expect(query.rallyNames, equals(['Moonraker', 'Trackrod']));
      expect(query.driverMatchMode, equals(MatchMode.any));

      // Singular getters return first element as fallback, but canonical lists remain intact
      expect(query.actionType, equals('jump'));
      expect(query.country, equals('Ireland'));
      expect(query.year, equals(2024));
      expect(query.driverName, equals('Josh Moffett'));
      expect(query.rallyName, equals('Moonraker'));
    });

    test('Serializes and deserializes multi-value fields to and from Map', () {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: const ['Ireland', 'Scotland', 'Portugal'],
        years: const [2024, 2025],
        yearFrom: 2023,
        yearTo: 2025,
        driverNames: const ['Josh Moffett', 'Sam Moffett'],
        driverMatchMode: MatchMode.all,
      );

      final map = query.toMap();
      expect(map['intent'], equals('SEARCH_RALLIES'));
      expect(map['countries'], equals(['Ireland', 'Scotland', 'Portugal']));
      expect(map['years'], equals([2024, 2025]));
      expect(map['yearFrom'], equals(2023));
      expect(map['yearTo'], equals(2025));
      expect(map['driverNames'], equals(['Josh Moffett', 'Sam Moffett']));
      expect(map['driverMatchMode'], equals('ALL'));

      final fromMap = SearchQuery.fromMap(map);
      expect(fromMap.intent, equals(SearchIntent.searchRallies));
      expect(fromMap.countries, equals(['Ireland', 'Scotland', 'Portugal']));
      expect(fromMap.years, equals([2024, 2025]));
      expect(fromMap.yearFrom, equals(2023));
      expect(fromMap.yearTo, equals(2025));
      expect(fromMap.driverNames, equals(['Josh Moffett', 'Sam Moffett']));
      expect(fromMap.driverMatchMode, equals(MatchMode.all));
    });

    test('Resolves aggregated aliases for multiple countries', () {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: const ['Ireland', 'Portugal', 'Sweden'],
      );

      final aliases = query.resolvedCountryAliases;
      // Ireland aliases
      expect(aliases, contains('ireland'));
      expect(aliases, contains('ie'));
      expect(aliases, contains('irl'));
      // Portugal aliases
      expect(aliases, contains('portugal'));
      expect(aliases, contains('pt'));
      // Sweden aliases
      expect(aliases, contains('sweden'));
      expect(aliases, contains('se'));
    });

    test('Resolves aggregated action types with _segments expansion', () {
      final query = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift', 'spin_segments'],
      );

      final resolved = query.resolvedActionTypes;
      expect(resolved, contains('jump'));
      expect(resolved, contains('jump_segments'));
      expect(resolved, contains('drift'));
      expect(resolved, contains('drift_segments'));
      expect(resolved, contains('spin'));
      expect(resolved, contains('spin_segments'));
    });

    test('Legacy singular constructor arguments populate plural lists canonically', () {
      final query = SearchQuery(
        intent: SearchIntent.searchRallies,
        country: 'Ireland',
        year: 2025,
        driverName: 'Josh Moffett',
        actionType: 'jump',
      );

      expect(query.countries, equals(['Ireland']));
      expect(query.years, equals([2025]));
      expect(query.driverNames, equals(['Josh Moffett']));
      expect(query.actionTypes, equals(['jump']));
      expect(query.country, equals('Ireland'));
      expect(query.year, equals(2025));
      expect(query.driverName, equals('Josh Moffett'));
      expect(query.actionType, equals('jump'));
    });

    test('Legacy singular Map keys deserialize into plural lists canonically', () {
      final legacyMap = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'country': 'Ireland',
        'year': 2025,
        'driver_name': 'Josh Moffett',
        'action_type': 'jump',
        'rally_name': 'Moonraker',
      };

      final deserialized = SearchQuery.fromMap(legacyMap);
      expect(deserialized.countries, equals(['Ireland']));
      expect(deserialized.years, equals([2025]));
      expect(deserialized.driverNames, equals(['Josh Moffett']));
      expect(deserialized.actionTypes, equals(['jump']));
      expect(deserialized.rallyNames, equals(['Moonraker']));
    });
  });
}
