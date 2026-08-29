import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_rally_search/models/conversational_search_session.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/services/python_search_api_client.dart';

const _baseUrl = String.fromEnvironment('LIVE_PYTHON_BACKEND_URL');

void main() {
  final skipReason = _baseUrl.isEmpty
      ? 'LIVE_PYTHON_BACKEND_URL is not configured'
      : false;

  test(
    'Flutter client reaches Python typed search and pagination metadata',
    () async {
      final client = PythonSearchApiClient(baseUrl: Uri.parse(_baseUrl));
      final first = await client.search(
        const SearchQuery(
          intent: SearchIntent.searchRallies,
          limit: 1,
          offset: 0,
        ),
      );
      expect(first.results, isNotEmpty);
      expect((first.results.single as RallySearchResult).eventId, isNotEmpty);
      expect(first.limit, 1);
      expect(first.offset, 0);
      expect(first.totalCount, greaterThan(0));
      if (first.hasMore) {
        final second = await client.search(
          const SearchQuery(
            intent: SearchIntent.searchRallies,
            limit: 1,
            offset: 1,
          ),
        );
        expect(second.offset, 1);
        expect(
          (second.results.single as RallySearchResult).eventId,
          isNot((first.results.single as RallySearchResult).eventId),
        );
      }
    },
    skip: skipReason,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'Flutter client completes Python multi-turn conversation',
    () async {
      final client = PythonSearchApiClient(baseUrl: Uri.parse(_baseUrl));
      final turn1 = await client.conversation(
        query: 'Show Moonraker Forestry Rally 2026',
        session: SearchConversationSession.initial,
        language: 'en',
        requestId: 1,
      );
      expect(turn1.requestId, 1);
      expect(turn1.result.isSuccess, isTrue);
      expect(turn1.result.searchResponse?.results, isNotEmpty);

      final turn2 = await client.conversation(
        query: 'Who won it?',
        session: turn1.session,
        language: 'en',
        requestId: 2,
      );
      expect(turn2.requestId, 2);
      expect(turn2.result.isSuccess, isTrue);
      expect(turn2.result.resolvedQuery?.intent, SearchIntent.getRallyResults);
    },
    skip: skipReason,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'Flutter client receives clarification without bogus results',
    () async {
      final client = PythonSearchApiClient(baseUrl: Uri.parse(_baseUrl));
      final response = await client.conversation(
        query: 'Who won Donegal International Rally?',
        session: SearchConversationSession.initial,
        language: 'en',
        requestId: 3,
      );
      expect(response.result.requiresClarification, isTrue);
      expect(response.result.candidates.length, greaterThanOrEqualTo(2));
      expect(response.result.searchResponse, isNull);
    },
    skip: skipReason,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'Flutter client submits labeled audio through Python voice pipeline',
    () async {
      final client = PythonSearchApiClient(baseUrl: Uri.parse(_baseUrl));
      final audio = File('test/eval/audio/human/record_out.wav');
      final response = await client.voice(
        audioBytes: await audio.readAsBytes(),
        filename: 'record_out.wav',
        session: SearchConversationSession.initial,
        language: 'en',
        requestId: 4,
      );
      expect(response.transcription?.text, isNotEmpty);
      expect(response.result.isSuccess, isTrue);
      expect(response.result.searchResponse?.results, isNotEmpty);
    },
    skip: skipReason,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
