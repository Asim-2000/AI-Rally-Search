import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/models/result_referent_context.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const fixturePath =
    'backend/benchmarks/conversation/fixtures/conversation_parity_fixtures_v1.json';
const expectedSha256 =
    '4172ed92f9d78052919d55c692ad3c18076230ad2ed3a5dc14ad6dc0e9f0bab2';

void main() {
  final bytes = File(fixturePath).readAsBytesSync();
  final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  final cases = (data['cases'] as List).cast<Map<String, dynamic>>();

  test('fixture is byte-for-byte frozen with exactly 12 cases', () {
    expect(sha256.convert(bytes).toString(), expectedSha256);
    expect(cases, hasLength(12));
  });

  for (final fixtureCase in cases) {
    test('Dart oracle evaluates ${fixtureCase['id']}', () async {
      final contextData =
          (fixtureCase['context'] as Map<String, dynamic>?) ?? const {};
      final previous = contextData['previous_query'] as Map<String, dynamic>?;
      final context = SearchContext(
        activeRally: contextData['active_rally'] as String?,
        activeDriver: contextData['active_driver'] as String?,
        previousQuery: previous == null ? null : SearchQuery.fromJson(previous),
        referents: ResultReferentContext(
          activeRally: contextData['active_rally'] as String?,
          activeDriver: contextData['active_driver'] as String?,
          lastWinner: contextData['last_winner'] as String?,
          activeDrivers:
              (contextData['active_drivers'] as List? ?? const []).cast<String>(),
          activeRallies:
              (contextData['active_rallies'] as List? ?? const []).cast<String>(),
        ),
      );
      final result = await MockLlmQueryParser().parse(
        fixtureCase['query'] as String,
        context: context,
      );

      if (fixtureCase['expected_clarification'] == true) {
        expect(result.requiresClarification, isTrue);
        final fragment =
            fixtureCase['expected_clarification_question_contains'] as String?;
        if (fragment != null) {
          expect(result.clarificationQuestion?.toLowerCase(),
              contains(fragment.toLowerCase()));
        }
        return;
      }

      expect(result.isSuccess, isTrue);
      final query = result.query!;
      final expected = fixtureCase['expected_query'] as Map<String, dynamic>;
      if (expected.containsKey('intent')) {
        expect(query.intent.toIntentString(), expected['intent']);
      }
      if (expected.containsKey('driverNames')) {
        expect(query.driverNames, expected['driverNames']);
      }
      if (expected.containsKey('rallyNames')) {
        expect(query.rallyNames, expected['rallyNames']);
      }
      if (expected.containsKey('actionTypes')) {
        expect(query.actionTypes, expected['actionTypes']);
      }
      if (expected.containsKey('years')) {
        expect(query.years, expected['years']);
      }
      if (expected.containsKey('personRole')) {
        expect(query.personRole.toRoleString(), expected['personRole']);
      }
      if (expected.containsKey('driverMatchMode')) {
        expect(query.driverMatchMode.toModeString(), expected['driverMatchMode']);
      }

      final expectedReferents =
          fixtureCase['expected_referents'] as Map<String, dynamic>?;
      if (expectedReferents != null) {
        final referents = ResultReferentContext.fromSearchResponse(
          _oracleResponse(query),
          previous: context.referents,
          queryRallies: query.targetRallyNames,
          queryDrivers: query.driverNames,
          queryPersonRole: query.personRole,
        );
        if (expectedReferents.containsKey('active_rally')) {
          expect(referents.activeRally, expectedReferents['active_rally']);
        }
        if (expectedReferents.containsKey('active_driver')) {
          expect(referents.activeDriver, expectedReferents['active_driver']);
        }
        if (expectedReferents.containsKey('last_winner')) {
          expect(referents.lastWinner, expectedReferents['last_winner']);
        }
      }
    });
  }
}

SearchResponse<dynamic> _oracleResponse(SearchQuery query) {
  SearchResponse<dynamic> common(List<dynamic> results) => SearchResponse<dynamic>(
        intent: query.intent,
        results: results,
        totalCount: results.length,
        hasMore: false,
        limit: query.limit,
        offset: query.offset,
      );
  switch (query.intent) {
    case SearchIntent.searchRallies:
      return common([
        RallySearchResult(
          eventId: 'event-2025',
          eventName: 'Donegal International Rally 2025',
          country: 'Ireland',
          city: 'Letterkenny',
          stagesCount: 14,
        ),
      ]);
    case SearchIntent.getRallyResults:
    case SearchIntent.getRallyTopFinishers:
      return common([
        const RallyResult(
          id: 101,
          rallyId: 'event-2025',
          eventName: 'Donegal International Rally 2025',
          driverId: 'driver-101',
          driverName: 'Josh Moffett',
          posOverall: 1,
        ),
      ]);
    case SearchIntent.searchDriverVideos:
      return common([
        VideoSearchResult(videoId: 101, driverName: 'Josh Moffett'),
      ]);
    case SearchIntent.searchVideoActions:
      return common([
        VideoAction(
          id: 501,
          videoId: 101,
          actionType: 'jump',
          title: 'Jump',
          startTime: 0,
          endTime: 1,
          duration: 1,
          eventName: 'Donegal International Rally 2025',
          driverName: 'Josh Moffett',
        ),
      ]);
    default:
      return common(const []);
  }
}
