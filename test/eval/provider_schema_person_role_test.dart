import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/query_understanding_spec.dart';
import 'package:ai_rally_search/services/llm/query_output_validator.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';

void main() {
  group('Provider-Specific Schema & Serialization Tests for personRole', () {
    test('OpenAI Structured Output Payload parses personRole correctly', () {
      const openAiJson = '''
      {
        "intent": "SEARCH_DRIVER_RALLIES",
        "rallyNames": [],
        "eventNames": [],
        "countries": [],
        "cities": [],
        "stageNames": [],
        "stageNumbers": [],
        "driverNames": ["Max Freeman"],
        "actionTypes": [],
        "years": [],
        "yearFrom": null,
        "yearTo": null,
        "driverMatchMode": "ANY",
        "personRole": "CO_DRIVER",
        "limit": 20,
        "offset": 0,
        "requiresClarification": false,
        "clarificationQuestion": null
      }
      ''';

      final res = QueryOutputValidator.validateAndParse(
        rawContent: openAiJson,
        provider: LlmProvider.openai,
        model: 'gpt-4o-mini',
      );
      expect(res.isSuccess, isTrue);
      expect(res.query!.personRole, PersonRole.coDriver);
      expect(res.query!.driverNames, ['Max Freeman']);
    });

    test('Gemini responseSchema JSON output parses personRole correctly', () {
      const geminiJson = '''
      {
        "intent": "SEARCH_DRIVER_RALLIES",
        "driverNames": ["Josh Moffett"],
        "personRole": "DRIVER",
        "requiresClarification": false
      }
      ''';

      final res = QueryOutputValidator.validateAndParse(
        rawContent: geminiJson,
        provider: LlmProvider.gemini,
        model: 'gemini-2.0-flash',
      );
      expect(res.isSuccess, isTrue);
      expect(res.query!.personRole, PersonRole.driver);
      expect(res.query!.driverNames, ['Josh Moffett']);
    });

    test('Anthropic Tool Call Input Schema parses personRole correctly', () {
      final anthropicInputMap = {
        'intent': 'SEARCH_DRIVER_RALLIES',
        'rallyNames': <String>[],
        'eventNames': <String>[],
        'countries': ['Ireland'],
        'cities': <String>[],
        'stageNames': <String>[],
        'stageNumbers': <String>[],
        'driverNames': ['Craig Breen'],
        'actionTypes': <String>[],
        'years': [2023],
        'yearFrom': null,
        'yearTo': null,
        'driverMatchMode': 'ANY',
        'personRole': 'ANY',
        'limit': 20,
        'offset': 0,
        'requiresClarification': false,
        'clarificationQuestion': null,
      };

      final res = QueryOutputValidator.validateMap(
        jsonMap: anthropicInputMap,
        provider: LlmProvider.anthropic,
        model: 'claude-3-5-sonnet-20241022',
      );
      expect(res.isSuccess, isTrue);
      expect(res.query!.personRole, PersonRole.any);
      expect(res.query!.driverNames, ['Craig Breen']);
      expect(res.query!.countries, ['Ireland']);
    });

    test('MockLlmQueryParser preserves personRole for navigator and driver queries', () async {
      final mockParser = MockLlmQueryParser();

      final resCoDriver = await mockParser.parse('rallies co-driven by Max Freeman');
      expect(resCoDriver.isSuccess, isTrue);
      expect(resCoDriver.query!.personRole, PersonRole.coDriver);
      expect(resCoDriver.query!.driverNames, ['Max Freeman']);

      final resDriver = await mockParser.parse('rallies driven by Josh Moffett');
      expect(resDriver.isSuccess, isTrue);
      expect(resDriver.query!.personRole, PersonRole.driver);
      expect(resDriver.query!.driverNames, ['Josh Moffett']);

      final resGeneral = await mockParser.parse('rallies with Josh Moffett');
      expect(resGeneral.isSuccess, isTrue);
      expect(resGeneral.query!.personRole, PersonRole.any);
      expect(resGeneral.query!.driverNames, ['Josh Moffett']);
    });

    test('SearchQuery toMap and fromMap serialization roundtrip preserves personRole', () {
      for (final role in PersonRole.values) {
        final query = SearchQuery(
          intent: SearchIntent.searchDriverRallies,
          driverNames: ['Test Driver'],
          personRole: role,
        );

        final map = query.toMap();
        expect(map['personRole'], role.toRoleString());

        final fromMapQuery = SearchQuery.fromMap(map);
        expect(fromMapQuery.personRole, role);
      }
    });
  });
}
