import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/result_referent_context.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_understanding_spec.dart';
import 'package:ai_rally_search/services/llm/query_output_validator.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';

void main() {
  late DatabaseService dbService;
  late SearchRepository searchRepo;
  late DatabaseEntityLookupRepository lookupRepo;
  late DatabaseEntityResolver resolver;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    dbService = DatabaseService();
    searchRepo = SearchRepository(dbService: dbService);
    lookupRepo = DatabaseEntityLookupRepository(dbService: dbService);
    resolver = DatabaseEntityResolver(repository: lookupRepo);
  });

  group('1. LLM QueryUnderstandingSpec & QueryOutputValidator personRole Tests', () {
    test('QueryUnderstandingSpec contains personRole in all provider schemas', () {
      // OpenAI JSON Schema
      final openAiProps = (QueryUnderstandingSpec.jsonSchema['schema'] as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
      expect(openAiProps.containsKey('personRole'), isTrue);
      final openAiPersonRole = openAiProps['personRole'] as Map<String, dynamic>;
      expect(openAiPersonRole['enum'], containsAll(['ANY', 'DRIVER', 'CO_DRIVER']));

      // Gemini Response Schema
      final geminiProps = QueryUnderstandingSpec.geminiResponseSchema['properties'] as Map<String, dynamic>;
      expect(geminiProps.containsKey('personRole'), isTrue);
      final geminiPersonRole = geminiProps['personRole'] as Map<String, dynamic>;
      expect(geminiPersonRole['enum'], containsAll(['ANY', 'DRIVER', 'CO_DRIVER']));

      // System prompt instructions
      expect(QueryUnderstandingSpec.systemPrompt, contains('personRole'));
      expect(QueryUnderstandingSpec.systemPrompt, contains('CO_DRIVER'));
      expect(QueryUnderstandingSpec.systemPrompt, contains('DRIVER'));
    });

    test('QueryOutputValidator parses personRole for all roles', () {
      // DRIVER
      final driverMap = {
        'intent': 'SEARCH_DRIVER_RALLIES',
        'driverNames': ['Josh Moffett'],
        'personRole': 'DRIVER',
      };
      final resDriver = QueryOutputValidator.validateMap(jsonMap: driverMap);
      expect(resDriver.isSuccess, isTrue);
      expect(resDriver.query!.personRole, PersonRole.driver);

      // CO_DRIVER
      final codriverMap = {
        'intent': 'SEARCH_DRIVER_RALLIES',
        'driverNames': ['Max Freeman'],
        'personRole': 'CO_DRIVER',
      };
      final resCodriver = QueryOutputValidator.validateMap(jsonMap: codriverMap);
      expect(resCodriver.isSuccess, isTrue);
      expect(resCodriver.query!.personRole, PersonRole.coDriver);

      // ANY
      final anyMap = {
        'intent': 'SEARCH_DRIVER_RALLIES',
        'driverNames': ['Max Freeman'],
        'personRole': 'ANY',
      };
      final resAny = QueryOutputValidator.validateMap(jsonMap: anyMap);
      expect(resAny.isSuccess, isTrue);
      expect(resAny.query!.personRole, PersonRole.any);

      // Default / Missing -> ANY
      final defaultMap = {
        'intent': 'SEARCH_DRIVER_RALLIES',
        'driverNames': ['Max Freeman'],
      };
      final resDefault = QueryOutputValidator.validateMap(jsonMap: defaultMap);
      expect(resDefault.isSuccess, isTrue);
      expect(resDefault.query!.personRole, PersonRole.any);
    });
  });

  group('2. Max Freeman Golden Verification (Live DB Relational Truth)', () {
    test('Max Freeman: DRIVER -> 0, CO_DRIVER -> 9, ANY -> 9', () async {
      // Independent raw SQL truth queries
      const codriverTruthSql = '''
        SELECT DISTINCT ev.event_id, ev.event_name
        FROM rally_entry_list el
        INNER JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
        INNER JOIN rally_sub_events se ON el.sub_event_id = se.sub_event_id
        INNER JOIN rally_events ev ON se.event_id = ev.event_id
        WHERE LOWER(cdp.full_name) LIKE '%max freeman%'
      ''';
      final rawCodriverRows = await dbService.query(codriverTruthSql);
      final expectedCodriverEventIds = rawCodriverRows.map((r) => r['event_id'].toString()).toSet();
      expect(expectedCodriverEventIds.length, 9);

      const driverTruthSql = '''
        SELECT DISTINCT ev.event_id, ev.event_name
        FROM rally_entry_list el
        INNER JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
        INNER JOIN rally_sub_events se ON el.sub_event_id = se.sub_event_id
        INNER JOIN rally_events ev ON se.event_id = ev.event_id
        WHERE LOWER(dp.full_name) LIKE '%max freeman%'
      ''';
      final rawDriverRows = await dbService.query(driverTruthSql);
      final expectedDriverEventIds = rawDriverRows.map((r) => r['event_id'].toString()).toSet();
      expect(expectedDriverEventIds.length, 0);

      // 1. Resolve and search with PersonRole.coDriver
      final qCoDriver = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.coDriver,
      );
      final resCoDriver = await resolver.resolve(qCoDriver);
      final responseCoDriver = await searchRepo.search(resCoDriver.resolvedQuery!);
      expect(responseCoDriver.totalCount, 9);
      final actualCodriverIds = responseCoDriver.results.map((r) => r.rallyId).toSet();
      expect(actualCodriverIds, equals(expectedCodriverEventIds));

      // 2. Resolve and search with PersonRole.driver
      final qDriver = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.driver,
      );
      final resDriver = await resolver.resolve(qDriver);
      final responseDriver = await searchRepo.search(resDriver.resolvedQuery!);
      expect(responseDriver.totalCount, 0);
      expect(responseDriver.results.isEmpty, isTrue);

      // 3. Resolve and search with PersonRole.any
      final qAny = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.any,
      );
      final resAny = await resolver.resolve(qAny);
      final responseAny = await searchRepo.search(resAny.resolvedQuery!);
      expect(responseAny.totalCount, 9);
      final actualAnyIds = responseAny.results.map((r) => r.rallyId).toSet();
      expect(actualAnyIds, equals(expectedCodriverEventIds));
    });
  });

  group('3. Dual-Role Golden Verification (Live DB Account 419633b1-56ca-483a-8c10-0141d7cc3092)', () {
    test('Chris Melly / Melly Chris: DRIVER -> 7, CO_DRIVER -> 16, ANY -> 23 distinct events', () async {
      const accId = '419633b1-56ca-483a-8c10-0141d7cc3092';

      // Independent DB truth queries
      final driverTruthSql = '''
        SELECT DISTINCT ev.event_id, ev.event_name
        FROM rally_entry_list el
        INNER JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
        INNER JOIN rally_sub_events se ON el.sub_event_id = se.sub_event_id
        INNER JOIN rally_events ev ON se.event_id = ev.event_id
        WHERE dp.account_id = '$accId'
      ''';
      final rawDriverRows = await dbService.query(driverTruthSql);
      final expectedDriverEventIds = rawDriverRows.map((r) => r['event_id'].toString()).toSet();
      expect(expectedDriverEventIds.length, 7);

      final codriverTruthSql = '''
        SELECT DISTINCT ev.event_id, ev.event_name
        FROM rally_entry_list el
        INNER JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
        INNER JOIN rally_sub_events se ON el.sub_event_id = se.sub_event_id
        INNER JOIN rally_events ev ON se.event_id = ev.event_id
        WHERE cdp.account_id = '$accId'
      ''';
      final rawCodriverRows = await dbService.query(codriverTruthSql);
      final expectedCodriverEventIds = rawCodriverRows.map((r) => r['event_id'].toString()).toSet();
      expect(expectedCodriverEventIds.length, 16);

      final expectedAllEventIds = {...expectedDriverEventIds, ...expectedCodriverEventIds};
      expect(expectedAllEventIds.length, 23);

      // Verify EntityLookupRepository discovers BOTH roles and account_id bridge
      final candidates = await lookupRepo.lookupDrivers('melly chris');
      expect(candidates.isNotEmpty, isTrue);
      final cand = candidates.first;
      expect(cand.metadata?['accountId'], accId);
      expect(cand.metadata?['role'], 'both');
      expect(cand.metadata?['driverId'], isNotNull);
      expect(cand.metadata?['codriverId'], isNotNull);

      // 1. DRIVER role query
      final qDriver = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['melly chris'],
        personRole: PersonRole.driver,
      );
      final resDriver = await resolver.resolve(qDriver);
      final respDriver = await searchRepo.search(resDriver.resolvedQuery!);
      expect(respDriver.totalCount, 7);
      final actualDriverIds = respDriver.results.map((r) => r.rallyId).toSet();
      expect(actualDriverIds, equals(expectedDriverEventIds));

      // 2. CO_DRIVER role query (even when queried using driver profile name "melly chris")
      final qCodriver = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['melly chris'],
        personRole: PersonRole.coDriver,
      );
      final resCodriver = await resolver.resolve(qCodriver);
      final respCodriver = await searchRepo.search(resCodriver.resolvedQuery!);
      expect(respCodriver.totalCount, 16);
      final actualCodriverIds = respCodriver.results.map((r) => r.rallyId).toSet();
      expect(actualCodriverIds, equals(expectedCodriverEventIds));

      // 3. ANY role query (unifies all 23 distinct events without duplication)
      final qAny = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['melly chris'],
        personRole: PersonRole.any,
        limit: 50,
      );
      final resAny = await resolver.resolve(qAny);
      final respAny = await searchRepo.search(resAny.resolvedQuery!);
      expect(respAny.totalCount, 23);
      final actualAnyIds = respAny.results.map((r) => r.rallyId).toSet();
      expect(actualAnyIds, equals(expectedAllEventIds));
      expect(actualAnyIds.length, 23);
    });
  });

  group('4. Conversational personRole Inheritance Tests', () {
    test('Explicit role persists across multi-turn queries unless changed or cleared', () {
      // Turn 1: "Which rallies did Max Freeman co-drive in?"
      final turn1Query = SearchQuery(
        intent: SearchIntent.searchDriverRallies,
        driverNames: ['Max Freeman'],
        personRole: PersonRole.coDriver,
      );
      final turn1Resp = SearchResponse(
        intent: SearchIntent.searchDriverRallies,
        results: [],
        totalCount: 9,
        hasMore: false,
        limit: 20,
        offset: 0,
      );
      final contextTurn1 = ResultReferentContext.fromSearchResponse(
        turn1Resp,
        queryDriver: 'Max Freeman',
        queryPersonRole: turn1Query.personRole,
      );
      expect(contextTurn1.activeDriver, 'Max Freeman');
      expect(contextTurn1.activePersonRole, PersonRole.coDriver);

      final searchContextTurn1 = SearchContext(
        referents: contextTurn1,
        previousQuery: turn1Query,
      );
      final promptTextTurn1 = searchContextTurn1.formatPromptContext();
      expect(promptTextTurn1, contains('active driver is "Max Freeman" (role: CO_DRIVER)'));
      expect(promptTextTurn1, contains('role: CO_DRIVER'));

      // Turn 2: Follow-up "What about 2026?" (inherits coDriver role)
      final turn2Context = contextTurn1.copyWith();
      expect(turn2Context.activePersonRole, PersonRole.coDriver);

      // Turn 3: User changes role: "Now show rallies where he drove"
      final turn3Context = turn2Context.copyWith(activePersonRole: PersonRole.driver);
      expect(turn3Context.activePersonRole, PersonRole.driver);

      // Turn 4: User clears role: "Forget the role"
      final turn4Context = turn3Context.copyWith(clearActivePersonRole: true);
      expect(turn4Context.activePersonRole, isNull);
    });
  });

  group('5. Video & VideoAction Paths with Person Filters', () {
    test('searchDriverVideos respects resolved person identity', () async {
      final q = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Josh Moffett'],
        limit: 10,
      );
      final res = await resolver.resolve(q);
      final resp = await searchRepo.search(res.resolvedQuery!);
      expect(resp.intent, SearchIntent.searchDriverVideos);
      expect(resp.results, isNotEmpty);
      for (final vid in resp.results) {
        expect(vid.driverName?.toLowerCase(), contains('moffett'));
      }
    });

    test('searchVideoActions with person filter correctly filters highlights', () async {
      final q = SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverNames: ['Josh Moffett'],
        actionTypes: ['jump'],
        limit: 10,
      );
      final res = await resolver.resolve(q);
      final resp = await searchRepo.search(res.resolvedQuery!);
      expect(resp.intent, SearchIntent.searchVideoActions);
    });
  });
}
