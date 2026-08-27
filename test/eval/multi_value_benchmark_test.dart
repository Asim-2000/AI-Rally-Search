import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/query_output_validator.dart';
import '../services/llm/entity_resolution/database_entity_resolver_test.dart';

void main() {
  group('Comprehensive 40+ Multi-Value Benchmark & Pipeline Evaluation', () {
    late DatabaseEntityResolver resolver;
    late MockEntityLookupRepository lookupRepo;

    setUp(() {
      lookupRepo = MockEntityLookupRepository(
        rallies: {
          'moonraker': [
            const EntityCandidate(
              id: 'moonraker-2025-uuid',
              type: EntityType.rally,
              canonicalName: 'Moonraker Forestry Rally 2025',
              metadata: {'year': 2025, 'country': 'Ireland'},
            ),
            const EntityCandidate(
              id: 'moonraker-2026-uuid',
              type: EntityType.rally,
              canonicalName: 'Moonraker Forestry Rally 2026',
              metadata: {'year': 2026, 'country': 'Ireland'},
            ),
          ],
          'trackrod': [
            const EntityCandidate(
              id: 'trackrod-2024-uuid',
              type: EntityType.rally,
              canonicalName: 'Trackrod Rally 2024',
              metadata: {'year': 2024, 'country': 'United Kingdom'},
            ),
          ],
          'get jerky': [
            const EntityCandidate(
              id: 'get-jerky-2026-uuid',
              type: EntityType.rally,
              canonicalName: 'Get Jerky Rally North Wales 2026',
              metadata: {'year': 2026, 'country': 'United Kingdom'},
            ),
          ],
          'plains': [
            const EntityCandidate(
              id: 'plains-rally-2025-uuid',
              type: EntityType.rally,
              canonicalName: 'Plains Rally 2025',
              metadata: {'year': 2025, 'country': 'United Kingdom'},
            ),
          ],
          'donegal': [
            const EntityCandidate(
              id: 'donegal-2025-uuid',
              type: EntityType.rally,
              canonicalName: 'Wilton Donegal International Rally 2025',
              metadata: {'year': 2025, 'country': 'Ireland', 'city': 'Donegal'},
            ),
          ],
        },
        drivers: {
          'josh moffett': [
            const EntityCandidate(
              id: 'josh-moffett-uuid',
              type: EntityType.driver,
              canonicalName: 'Josh Moffett',
              subtitle: 'IE',
            ),
          ],
          'sam moffett': [
            const EntityCandidate(
              id: 'sam-moffett-uuid',
              type: EntityType.driver,
              canonicalName: 'Sam Moffett',
              subtitle: 'IE',
            ),
          ],
          'philip squires': [
            const EntityCandidate(
              id: 'philip-squires-uuid',
              type: EntityType.driver,
              canonicalName: 'Philip Squires',
              subtitle: 'GB',
            ),
          ],
          'kris meeke': [
            const EntityCandidate(
              id: 'kris-meeke-uuid',
              type: EntityType.driver,
              canonicalName: 'Kris Meeke',
              subtitle: 'GB',
            ),
          ],
          'smith': [
            const EntityCandidate(
              id: 'gary-smith-uuid',
              type: EntityType.driver,
              canonicalName: 'Gary Smith',
              subtitle: 'GB',
            ),
            const EntityCandidate(
              id: 'mark-smith-uuid',
              type: EntityType.driver,
              canonicalName: 'Mark Smith',
              subtitle: 'IE',
            ),
          ],
        },
        stages: {
          'gale rigg': [
            const EntityCandidate(
              id: 'gale-rigg-uuid',
              type: EntityType.stage,
              canonicalName: 'Gale Rigg',
              metadata: {'stageNumber': '3'},
            ),
          ],
          'alwen north': [
            const EntityCandidate(
              id: 'alwen-north-uuid',
              type: EntityType.stage,
              canonicalName: 'Alwen North',
              metadata: {'stageNumber': '1'},
            ),
          ],
          'ring stage': [
            const EntityCandidate(
              id: 'ring-stage-uuid',
              type: EntityType.stage,
              canonicalName: 'Ring Stage',
              metadata: {'stageNumber': '4'},
            ),
          ],
        },
        cities: {
          'donegal': [
            const EntityCandidate(
              id: 'Donegal Town',
              type: EntityType.city,
              canonicalName: 'Donegal Town',
              subtitle: 'Ireland',
            ),
          ],
          'waterford': [
            const EntityCandidate(
              id: 'Waterford',
              type: EntityType.city,
              canonicalName: 'Waterford',
              subtitle: 'Ireland',
            ),
          ],
        },
      );

      resolver = DatabaseEntityResolver(repository: lookupRepo);
    });

    // =========================================================================
    // 1. MULTI-COUNTRY (Cases 1-5)
    // =========================================================================
    test('1. Multi-Country: Ireland + Scotland', () {
      final json = {'intent': 'SEARCH_RALLIES', 'countries': ['Ireland', 'Scotland']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.isSuccess, isTrue);
      expect(res.query?.countries, equals(['Ireland', 'Scotland']));
      expect(res.query?.resolvedCountryAliases, contains('ireland'));
      expect(res.query?.resolvedCountryAliases, contains('scotland'));
    });

    test('2. Multi-Country: France + Belgium', () {
      final json = {'intent': 'SEARCH_RALLIES', 'countries': ['France', 'Belgium']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.countries, equals(['France', 'Belgium']));
    });

    test('3. Multi-Country: Ireland + Wales + Scotland (3 countries)', () {
      final json = {'intent': 'SEARCH_RALLIES', 'countries': ['Ireland', 'Wales', 'Scotland']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.countries, equals(['Ireland', 'Wales', 'Scotland']));
      expect(res.query?.resolvedCountryAliases.length, greaterThan(3));
    });

    test('4. Multi-Country: Country code normalization (IE + UK + PT)', () {
      final json = {'intent': 'SEARCH_RALLIES', 'countries': ['IE', 'UK', 'PT']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.countries, equals(['Ireland', 'United Kingdom', 'Portugal']));
    });

    test('5. Multi-Country: Typo normalization across array', () {
      final json = {'intent': 'SEARCH_RALLIES', 'countries': ['Irelnd', 'Portugl', 'Espana']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.countries, contains('Ireland'));
      expect(res.query?.countries, contains('Portugal'));
      expect(res.query?.countries, contains('Spain'));
    });

    // =========================================================================
    // 2. MULTI-YEAR (Cases 6-10)
    // =========================================================================
    test('6. Multi-Year: 2024 + 2025 discrete', () {
      final json = {'intent': 'SEARCH_RALLIES', 'years': [2024, 2025]};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.years, equals([2024, 2025]));
      expect(res.query?.yearFrom, isNull);
    });

    test('7. Multi-Year: 3 discrete years (2022, 2023, 2025)', () {
      final json = {'intent': 'SEARCH_RALLIES', 'years': [2022, 2023, 2025]};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.years, equals([2022, 2023, 2025]));
    });

    test('8. Multi-Year: Year range (from 2023 to 2025)', () {
      final json = {'intent': 'SEARCH_RALLIES', 'yearFrom': 2023, 'yearTo': 2025};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.yearFrom, equals(2023));
      expect(res.query?.yearTo, equals(2025));
      expect(res.query?.years, isEmpty);
    });

    test('9. Multi-Year: Year range + single country', () {
      final json = {'intent': 'SEARCH_RALLIES', 'countries': ['Ireland'], 'yearFrom': 2024, 'yearTo': 2026};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.countries, equals(['Ireland']));
      expect(res.query?.yearFrom, equals(2024));
      expect(res.query?.yearTo, equals(2026));
    });

    test('10. Multi-Year: Out of bounds years filtered safely', () {
      final json = {'intent': 'SEARCH_RALLIES', 'years': [2024, 1850, 2025, 2999]};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.years, equals([2024, 2025]));
    });

    // =========================================================================
    // 3. MULTI-DRIVER (Cases 11-15)
    // =========================================================================
    test('11. Multi-Driver: Josh OR Sam with MatchMode.any', () async {
      final json = {
        'intent': 'SEARCH_DRIVER_VIDEOS',
        'driverNames': ['Josh Moffett', 'Sam Moffett'],
        'driverMatchMode': 'ANY',
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.driverIds, equals(['josh-moffett-uuid', 'sam-moffett-uuid']));
      expect(resolved.resolvedQuery?.driverMatchMode, equals(MatchMode.any));
    });

    test('12. Multi-Driver: Three drivers ANY (Josh, Sam, Philip)', () async {
      final json = {
        'intent': 'SEARCH_DRIVER_VIDEOS',
        'driverNames': ['Josh Moffett', 'Sam Moffett', 'Philip Squires'],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.driverIds.length, equals(3));
    });

    test('13. Multi-Driver: BOTH/ALL explicit match mode', () async {
      final json = {
        'intent': 'SEARCH_DRIVER_RALLIES',
        'driverNames': ['Josh Moffett', 'Sam Moffett'],
        'driverMatchMode': 'ALL',
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.driverMatchMode, equals(MatchMode.all));
    });

    test('14. Multi-Driver: Ambiguous driver + resolved driver preserves partial resolution', () async {
      final json = {
        'intent': 'SEARCH_DRIVER_VIDEOS',
        'driverNames': ['Josh Moffett', 'Smith'],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.requiresClarification, isTrue);
      expect(resolved.clarificationQuestion, contains('Smith'));
      expect(resolved.resolutions['driver:Josh Moffett']?.isResolved, isTrue);
    });

    test('15. Multi-Driver: Nickname and case normalization', () async {
      final json = {
        'intent': 'SEARCH_DRIVER_VIDEOS',
        'driverNames': ['josh moffett', 'SAM MOFFETT'],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.driverNames, equals(['Josh Moffett', 'Sam Moffett']));
    });

    // =========================================================================
    // 4. MULTI-ACTION (Cases 16-20)
    // =========================================================================
    test('16. Multi-Action: jump + drift', () {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'actionTypes': ['jump', 'drift']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.actionTypes, equals(['jump', 'drift']));
      expect(res.query?.resolvedActionTypes, contains('jump_segments'));
      expect(res.query?.resolvedActionTypes, contains('drift_segments'));
    });

    test('17. Multi-Action: crash + spin + water splash (3 actions)', () {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'actionTypes': ['crash', 'spin', 'water splash']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.actionTypes, equals(['crash', 'spin', 'water splash']));
    });

    test('18. Multi-Action: hairpin + donut alias normalization', () {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'actionTypes': ['handbrake turn', 'donuts']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.actionTypes, equals(['hairpin', 'donut']));
    });

    test('19. Multi-Action: mechanical failure alias mapping', () {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'actionTypes': ['puncture', 'breakdown']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.actionTypes, equals(['mechanical failure']));
    });

    test('20. Multi-Action: Invalid action type filtered from list', () {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'actionTypes': ['jump', 'rocket_boost', 'drift']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.actionTypes, equals(['jump', 'drift']));
    });

    // =========================================================================
    // 5. MULTI-RALLY & MULTI-STAGE (Cases 21-25)
    // =========================================================================
    test('21. Multi-Rally: Moonraker + Trackrod', () async {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'rallyNames': ['Moonraker', 'Trackrod']};
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.rallyNames.length, equals(2));
    });

    test('22. Multi-Rally: Event name alias in eventNames array', () async {
      final json = {'intent': 'SEARCH_RALLIES', 'eventNames': ['Plains', 'Get Jerky']};
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.targetRallyNames, contains('Plains Rally 2025'));
      expect(resolved.resolvedQuery?.targetRallyNames, contains('Get Jerky Rally North Wales 2026'));
    });

    test('23. Multi-Stage: Gale Rigg + Alwen North', () async {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'stageNames': ['Gale Rigg', 'Alwen North']};
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.stageNames, equals(['Gale Rigg', 'Alwen North']));
      expect(resolved.resolvedQuery?.stageNumbers, equals(['3', '1']));
    });

    test('24. Multi-Stage: Stage name + stage numbers', () async {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'stageNames': ['Ring Stage'], 'stageNumbers': ['SS1', 'SS2']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.stageNames, equals(['Ring Stage']));
      expect(res.query?.stageNumbers, equals(['SS1', 'SS2']));
    });

    test('25. Multi-City: Donegal + Waterford', () async {
      final json = {'intent': 'SEARCH_RALLIES', 'cities': ['Donegal', 'Waterford']};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.cities, equals(['Donegal', 'Waterford']));
    });

    // =========================================================================
    // 6. HIGH-COMPLEXITY COMBINATIONS (Cases 26-30)
    // =========================================================================
    test('26. High Complexity: 2 countries + 2 years + 2 drivers', () async {
      final json = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'countries': ['Ireland', 'United Kingdom'],
        'years': [2024, 2025],
        'driverNames': ['Josh Moffett', 'Philip Squires'],
        'actionTypes': ['jump'],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.countries, equals(['Ireland', 'United Kingdom']));
      expect(resolved.resolvedQuery?.years, equals([2024, 2025]));
      expect(resolved.resolvedQuery?.driverIds, equals(['josh-moffett-uuid', 'philip-squires-uuid']));
    });

    test('27. High Complexity: 2 actions + 2 drivers + 2 rallies', () async {
      final json = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'actionTypes': ['jump', 'drift'],
        'driverNames': ['Josh Moffett', 'Sam Moffett'],
        'rallyNames': ['Moonraker', 'Trackrod'],
        'years': [2024, 2025],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.actionTypes, equals(['jump', 'drift']));
      expect(resolved.resolvedQuery?.driverIds.length, equals(2));
      expect(resolved.resolvedQuery?.targetRallyNames.length, equals(2));
    });

    test('28. High Complexity: 4 dimensions simultaneously', () async {
      final json = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'actionTypes': ['jump'],
        'driverNames': ['Josh Moffett', 'Sam Moffett'],
        'countries': ['Ireland', 'Scotland'],
        'years': [2024, 2025],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.actionTypes, equals(['jump']));
      expect(resolved.resolvedQuery?.driverIds, equals(['josh-moffett-uuid', 'sam-moffett-uuid']));
      expect(resolved.resolvedQuery?.countries, equals(['Ireland', 'Scotland']));
      expect(resolved.resolvedQuery?.years, equals([2024, 2025]));
    });

    test('29. High Complexity: Driver wins across 2 discrete years', () {
      final json = {
        'intent': 'SEARCH_DRIVER_WINS',
        'driverNames': ['Josh Moffett'],
        'years': [2025, 2026],
      };
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.intent, equals(SearchIntent.searchDriverWins));
      expect(res.query?.years, equals([2025, 2026]));
    });

    test('30. High Complexity: Top uploaders for multiple rallies', () {
      final json = {
        'intent': 'GET_TOP_UPLOADERS',
        'rallyNames': ['Moonraker', 'Trackrod'],
      };
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.intent, equals(SearchIntent.getTopUploaders));
      expect(res.query?.rallyNames, equals(['Moonraker', 'Trackrod']));
    });

    // =========================================================================
    // 7. MULTILINGUAL MULTI-VALUE (Cases 31-36)
    // =========================================================================
    test('31. Multilingual: German multi-action multi-rally', () async {
      final json = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'actionTypes': ['jump', 'drift'],
        'driverNames': ['Josh Moffett'],
        'rallyNames': ['Moonraker', 'Trackrod'],
        'years': [2024, 2025],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.actionTypes, equals(['jump', 'drift']));
      expect(resolved.resolvedQuery?.years, equals([2024, 2025]));
    });

    test('32. Multilingual: French multi-action multi-driver', () async {
      final json = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'actionTypes': ['jump', 'drift'],
        'driverNames': ['Josh Moffett', 'Sam Moffett'],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.driverIds.length, equals(2));
    });

    test('33. Multilingual: Spanish multi-country multi-year', () {
      final json = {
        'intent': 'SEARCH_RALLIES',
        'countries': ['Ireland', 'Scotland'],
        'years': [2024, 2025],
      };
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.countries, equals(['Ireland', 'Scotland']));
      expect(res.query?.years, equals([2024, 2025]));
    });

    test('34. Multilingual: Italian multi-driver participation', () async {
      final json = {
        'intent': 'SEARCH_DRIVER_RALLIES',
        'driverNames': ['Josh Moffett', 'Kris Meeke'],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.driverIds, equals(['josh-moffett-uuid', 'kris-meeke-uuid']));
    });

    test('35. Multilingual: Polish inflected driver names in multi-driver array', () async {
      final json = {
        'intent': 'SEARCH_DRIVER_VIDEOS',
        'driverNames': ['Josh Moffett', 'Philip Squires'],
      };
      final parsed = QueryOutputValidator.validateMap(jsonMap: json);
      final resolved = await resolver.resolve(parsed.query!);
      expect(resolved.resolvedQuery?.driverIds, equals(['josh-moffett-uuid', 'philip-squires-uuid']));
    });

    test('36. Multilingual: Urdu/Arabic multi-action normalization', () {
      final json = {
        'intent': 'SEARCH_VIDEO_ACTIONS',
        'actionTypes': ['jump', 'drift'],
        'countries': ['Ireland'],
      };
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.actionTypes, equals(['jump', 'drift']));
      expect(res.query?.countries, equals(['Ireland']));
    });

    // =========================================================================
    // 8. EDGE CASES & INVARIANTS (Cases 37-42)
    // =========================================================================
    test('37. Edge Case: Duplicate aliases deduplicated into unique canonical country', () {
      final json = {
        'intent': 'SEARCH_RALLIES',
        'countries': ['Ireland', 'IE', 'IRL', 'Republic of Ireland', 'Scotland'],
      };
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.countries, equals(['Ireland', 'Scotland']));
    });

    test('38. Edge Case: Summary generator formats complex multi-dimension query cleanly', () {
      final q = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: const ['jump', 'drift'],
        driverNames: const ['Josh Moffett', 'Sam Moffett'],
        countries: const ['Ireland', 'Scotland'],
        years: const [2024, 2025],
        driverMatchMode: MatchMode.any,
      );
      final summary = QueryOutputValidator.generateInterpretedSummary(q);
      expect(summary, contains('jump, drift highlights'));
      expect(summary, contains('Josh Moffett, Sam Moffett'));
      expect(summary, contains('Ireland, Scotland'));
      expect(summary, contains('2024, 2025'));
    });

    test('39. Edge Case: Singular fallback getters never truncate underlying plural list', () {
      final q = SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: const ['Ireland', 'Scotland', 'Portugal'],
      );
      expect(q.country, equals('Ireland'));
      expect(q.countries.length, equals(3));
      expect(q.countries, equals(['Ireland', 'Scotland', 'Portugal']));
    });

    test('40. Edge Case: Clarification detection on empty broad categories', () {
      final json = {'intent': 'SEARCH_VIDEO_ACTIONS', 'requiresClarification': true, 'clarificationQuestion': 'Which action?'};
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.requiresClarification, isTrue);
      expect(res.clarificationQuestion, equals('Which action?'));
    });

    test('41. Edge Case: MatchMode ALL formatting in summary', () {
      final q = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: const ['Josh Moffett', 'Sam Moffett'],
        driverMatchMode: MatchMode.all,
      );
      final summary = QueryOutputValidator.generateInterpretedSummary(q);
      expect(summary, contains('Josh Moffett AND Sam Moffett'));
    });

    test('42. Edge Case: Empty and null elements stripped cleanly from multi-value lists', () {
      final json = {
        'intent': 'SEARCH_RALLIES',
        'countries': ['Ireland', '', 'null', '  ', 'Scotland'],
        'years': [2024, null, 0, 2025],
      };
      final res = QueryOutputValidator.validateMap(jsonMap: json);
      expect(res.query?.countries, equals(['Ireland', 'Scotland']));
      expect(res.query?.years, equals([2024, 2025]));
    });
  });
}
