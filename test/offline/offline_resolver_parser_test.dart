import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/services/friendly_response_service.dart';
import 'package:ai_rally_search/services/offline/offline_entity_index.dart';
import 'package:ai_rally_search/services/offline/offline_query_parser.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineEntityIndex _index() {
  return OfflineEntityIndex(
    rallies: const [
      OfflineEntity(type: OfflineEntityType.rally, canonicalId: 'A', canonicalName: 'Rally Alūksne 2026', year: 2026, country: 'Latvia'),
      OfflineEntity(type: OfflineEntityType.rally, canonicalId: 'D1', canonicalName: 'Wilton Donegal International Rally 2025', year: 2025, country: 'Ireland'),
      OfflineEntity(type: OfflineEntityType.rally, canonicalId: 'D2', canonicalName: 'Wilton Donegal International Rally 2026', year: 2026, country: 'Ireland'),
      OfflineEntity(type: OfflineEntityType.rally, canonicalId: 'D3', canonicalName: "McCafferty's Bars Donegal Forestry Rally 2025", year: 2025, country: 'Ireland'),
      OfflineEntity(type: OfflineEntityType.rally, canonicalId: 'B', canonicalName: 'Birr Stages Rally 2026', year: 2026, country: 'Ireland'),
    ],
    people: const [
      OfflineEntity(
        type: OfflineEntityType.person,
        canonicalId: 'person:account:freeman',
        canonicalName: 'Max Freeman',
        searchableNames: ['Max Freeman'],
        driverId: null,
        codriverId: 'cod-freeman',
        accountId: 'freeman',
      ),
      OfflineEntity(
        type: OfflineEntityType.person,
        canonicalId: 'person:driver:moffett',
        canonicalName: 'Josh Moffett',
        searchableNames: ['Josh Moffett'],
        driverId: 'drv-moffett',
      ),
    ],
    uploaders: const [
      OfflineEntity(type: OfflineEntityType.uploader, canonicalId: 'u1', canonicalName: 'Denisw555'),
    ],
  );
}

void main() {
  group('offline entity resolution safety', () {
    final index = _index();

    test('aluqsne -> confident Rally Alūksne (typo recovery)', () {
      final res = index.resolveRally('aluqsne');
      expect(res.isResolved, isTrue, reason: res.strategy);
      expect(res.resolved!.entity.canonicalId, 'A');
    });

    test('max freemn -> confident Max Freeman (person typo recovery)', () {
      final res = index.resolvePerson('max freemn');
      expect(res.isResolved, isTrue, reason: res.strategy);
      expect(res.resolved!.entity.canonicalId, 'person:account:freeman');
    });

    test('donegl -> clarification (genuine ambiguity, never a wrong guess)', () {
      final res = index.resolveRally('donegl');
      expect(res.isResolved, isFalse);
      expect(res.isAmbiguous, isTrue, reason: res.strategy);
      expect(res.candidates.length, greaterThanOrEqualTo(2));
    });

    test('never fabricates an id for gibberish', () {
      final res = index.resolveRally('zzzxqywv');
      expect(res.isResolved, isFalse);
    });
  });

  group('offline query parser', () {
    final parser = OfflineQueryParser(index: _index());

    test('rallies in ireland in 2025', () {
      final r = parser.parse('rallies in ireland in 2025');
      expect(r.kind, OfflineParseKind.results);
      expect(r.query!.intent, SearchIntent.searchRallies);
      expect(r.query!.countries, ['ireland']);
      expect(r.query!.years, [2025]);
    });

    test('rally aluksne -> SEARCH_RALLIES with resolved id', () {
      final r = parser.parse('rally aluksne');
      expect(r.kind, OfflineParseKind.results);
      expect(r.query!.intent, SearchIntent.searchRallies);
      expect(r.query!.rallyNames, ['A']);
    });

    test('max freeman rallies -> SEARCH_DRIVER_RALLIES', () {
      final r = parser.parse('max freeman rallies');
      expect(r.kind, OfflineParseKind.results);
      expect(r.query!.intent, SearchIntent.searchDriverRallies);
      expect(r.query!.driverIds, contains('cod-freeman'));
    });

    test('who won rally donegal -> clarification (ambiguous rally)', () {
      final r = parser.parse('who won rally donegal');
      expect(r.kind, OfflineParseKind.clarification);
      expect(r.intent, SearchIntent.getRallyResults);
    });

    test('videos of max freeman -> SEARCH_DRIVER_VIDEOS', () {
      final r = parser.parse('videos of max freeman');
      expect(r.kind, OfflineParseKind.results);
      expect(r.query!.intent, SearchIntent.searchDriverVideos);
      expect(r.query!.driverIds, contains('cod-freeman'));
    });

    test('jumps from rally ireland -> SEARCH_VIDEO_ACTIONS', () {
      final r = parser.parse('jumps from rally ireland');
      expect(r.kind, OfflineParseKind.results);
      expect(r.query!.intent, SearchIntent.searchVideoActions);
      expect(r.query!.actionTypes, ['jump']);
      expect(r.query!.countries, ['ireland']);
    });

    test('top drivers by wins -> GET_TOP_DRIVERS_BY_WINS', () {
      final r = parser.parse('top drivers by wins');
      expect(r.kind, OfflineParseKind.results);
      expect(r.query!.intent, SearchIntent.getTopDriversByWins);
    });

    test('top uploaders -> GET_TOP_UPLOADERS', () {
      final r = parser.parse('top uploaders');
      expect(r.kind, OfflineParseKind.results);
      expect(r.query!.intent, SearchIntent.getTopUploaders);
    });

    test('results for rally donegal -> clarification, TOP_FINISHERS intent', () {
      final r = parser.parse('results for rally donegal');
      expect(r.kind, OfflineParseKind.clarification);
      expect(r.intent, SearchIntent.getRallyTopFinishers);
    });

    test('special weather query is intercepted', () {
      final r = parser.parse('what is the weather');
      expect(r.kind, OfflineParseKind.special);
      expect(r.specialCategory, FriendlyResponseCategory.weather);
    });

    test('a normal rally query is NOT intercepted by special matcher', () {
      final r = parser.parse('rally aluksne');
      expect(r.kind, isNot(OfflineParseKind.special));
    });

    test('unsupported wording is safely declined, not guessed', () {
      final r = parser.parse('explain the offside rule in football');
      expect(r.kind, anyOf(OfflineParseKind.unsupported, OfflineParseKind.noMatch));
    });

    test('gibberish entity -> safe no-match', () {
      final r = parser.parse('rally zzzxqywv');
      expect(r.kind, OfflineParseKind.noMatch);
    });
  });
}
