import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_rally_search/models/conversational_search_session.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/services/python_search_api_client.dart';

void main() {
  test(
    'maps all nine deterministic intents into existing domain models',
    () async {
      final fixtures = <SearchIntent, Map<String, dynamic>>{
        SearchIntent.searchRallies: {
          'kind': 'rally',
          'event_id': 'e1',
          'event_name': 'Donegal',
        },
        SearchIntent.searchDriverRallies: {
          'kind': 'participation',
          'rally_id': 'e1',
          'event_name': 'Donegal',
          'driver_name': 'Max',
        },
        SearchIntent.searchDriverWins: {
          'kind': 'participation',
          'rally_id': 'e1',
          'event_name': 'Donegal',
          'driver_name': 'Max',
        },
        SearchIntent.getRallyResults: {
          'kind': 'classification',
          'id': 1,
          'rally_id': 'e1',
          'event_name': 'Donegal',
          'driver_name': 'Max',
          'pos_overall': 1,
        },
        SearchIntent.getRallyTopFinishers: {
          'kind': 'classification',
          'id': 1,
          'rally_id': 'e1',
          'event_name': 'Donegal',
          'driver_name': 'Max',
          'pos_overall': 1,
        },
        SearchIntent.searchVideoActions: {
          'kind': 'video_action',
          'id': 1,
          'video_id': 2,
          'action_type': 'jump',
          'start_action': 2.5,
          'end_action': 5.0,
          'video_url': 'https://video',
        },
        SearchIntent.searchDriverVideos: {
          'kind': 'video',
          'video_id': 2,
          'driver_name': 'Max',
          'video_url': 'https://video',
        },
        SearchIntent.getTopUploaders: {
          'kind': 'uploader',
          'uploader_id': 'u1',
          'uploader_name': 'Uploader',
          'upload_count': 4,
        },
        SearchIntent.getTopDriversByWins: {
          'kind': 'driver_wins',
          'person_id': 'p1',
          'driver_name': 'Max',
          'win_count': 3,
        },
      };
      var index = 0;
      final client = PythonSearchApiClient(
        baseUrl: Uri.parse('https://api.example'),
        httpClient: MockClient((request) async {
          final intent = fixtures.keys.elementAt(index++);
          return http.Response(
            jsonEncode({
              'intent': intent.toIntentString(),
              'results': [fixtures[intent]],
              'total_count': 1,
              'has_more': false,
              'limit': 20,
              'offset': 0,
            }),
            200,
          );
        }),
      );

      for (final intent in fixtures.keys) {
        final response = await client.search(SearchQuery(intent: intent));
        expect(response.intent, intent);
        expect(response.results, hasLength(1));
        if (intent == SearchIntent.searchVideoActions) {
          final action = response.results.single as VideoAction;
          expect(action.startTime, 2.5);
          expect(action.videoUrl, 'https://video');
        }
      }
    },
  );

  test(
    'conversation preserves request id and maps clarification candidates',
    () async {
      final client = PythonSearchApiClient(
        baseUrl: Uri.parse('https://api.example'),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'requestId': 7,
              'session': _sessionJson(activeRequestId: 7),
              'result': {
                'requiresClarification': true,
                'clarificationQuestion': 'Which rally?',
                'candidates': [
                  {'id': 'e1', 'type': 'rally', 'canonical_name': 'Donegal'},
                ],
                'referents': {},
              },
            }),
            200,
          ),
        ),
      );
      final response = await client.conversation(
        query: 'Donegal',
        session: SearchConversationSession.initial,
        language: 'en',
        requestId: 7,
      );
      expect(response.requestId, 7);
      expect(response.result.requiresClarification, isTrue);
      expect(response.result.candidates.single.canonicalName, 'Donegal');
    },
  );

  test('voice posts raw audio and maps transcription telemetry', () async {
    final client = PythonSearchApiClient(
      baseUrl: Uri.parse('https://api.example'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/voice/search');
        expect(request.bodyBytes, [1, 2, 3]);
        expect(request.url.queryParameters['requestId'], '9');
        return http.Response(
          jsonEncode({
            'requestId': 9,
            'session': _sessionJson(activeRequestId: 9),
            'result': {
              'error': 'no result',
              'friendlyMessage': 'Try again',
              'referents': {},
            },
            'transcription': {
              'text': 'show jumps',
              'language': 'en',
              'durationMs': 42,
            },
            'telemetry': {'totalLatencyMs': 10},
          }),
          200,
        );
      }),
    );
    final response = await client.voice(
      audioBytes: Uint8List.fromList([1, 2, 3]),
      filename: 'query.m4a',
      session: SearchConversationSession.initial,
      language: 'en',
      requestId: 9,
    );
    expect(response.transcription?.text, 'show jumps');
    expect(response.telemetry['totalLatencyMs'], 10);
  });

  test(
    'maps timeout failures without exposing technical details to UI',
    () async {
      final client = PythonSearchApiClient(
        baseUrl: Uri.parse('https://api.example'),
        typedTimeout: Duration.zero,
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        client.search(const SearchQuery(intent: SearchIntent.searchRallies)),
        throwsA(
          isA<PythonApiException>().having(
            (e) => e.category,
            'category',
            'timeout',
          ),
        ),
      );
    },
  );
}

Map<String, dynamic> _sessionJson({required int activeRequestId}) => {
  'activeQuery': const SearchQuery(intent: SearchIntent.searchRallies).toJson(),
  'referents': {},
  'history': [],
  'inheritedFields': [],
  'currentRefinementFields': [],
  'activeRequestId': activeRequestId,
};
