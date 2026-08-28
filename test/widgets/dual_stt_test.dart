import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_rally_search/l10n/generated/app_localizations.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/python_search_api_client.dart';
import 'package:ai_rally_search/services/speech/mock_speech_to_text_service.dart';

class DualTestSearchRepository implements ISearchRepository {
  SearchQuery? lastQuery;

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    lastQuery = query;
    return SearchResponse<RallySearchResult>(
      intent: SearchIntent.searchRallies,
      results: [
        RallySearchResult(
          eventId: 'e-1',
          eventName: 'Donegal International Rally',
          country: 'Ireland',
          city: 'Letterkenny',
          stagesCount: 14,
          startDate: DateTime(2025, 6, 20),
        ),
      ],
      totalCount: 1,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) async =>
      (await search(query)) as SearchResponse<RallySearchResult>;
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(SearchQuery query) async =>
      throw UnimplementedError();
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(SearchQuery query) async =>
      throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery query) async =>
      throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery query) async =>
      throw UnimplementedError();
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery query) async =>
      throw UnimplementedError();
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(SearchQuery query) async =>
      throw UnimplementedError();
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(SearchQuery query) async =>
      throw UnimplementedError();
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(SearchQuery query) async =>
      throw UnimplementedError();
}

class FakeDualParser implements LlmQueryParser {
  @override
  LlmProvider get provider => LlmProvider.mock;

  @override
  Future<QueryParseResult> parse(String rawQuery, {SearchContext? context}) async {
    return QueryParseResult(
      rawResponse: '{"intent": "SEARCH_RALLIES", "country": "Ireland"}',
      query: const SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: ['Ireland'],
      ),
      confidence: 1.0,
      provider: LlmProvider.mock,
      model: 'fake',
    );
  }
}

Widget createDualTestApp({
  required ISearchRepository repository,
  required MockSpeechToTextService nativeSpeech,
  required MockSpeechToTextService cloudSpeech,
  PythonSearchApiClient? pythonApiClient,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: GeneralSearchScreen(
      repository: repository,
      llmParser: FakeDualParser(),
      nativeSpeechService: nativeSpeech,
      cloudSpeechService: cloudSpeech,
      pythonApiClient: pythonApiClient,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setupScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Dual STT Test Mode Verification', () {
    late DualTestSearchRepository mockRepo;
    late MockSpeechToTextService mockNativeSpeech;
    late MockSpeechToTextService mockCloudSpeech;
    late List<String> requestedHttpPaths;
    late List<Map<String, dynamic>> conversationPayloads;
    late PythonSearchApiClient mockPythonClient;

    setUp(() {
      dotenv.loadFromString(envString: 'ENTITY_SEARCH_FALLBACK_MODE=OFF');
      mockRepo = DualTestSearchRepository();
      mockNativeSpeech = MockSpeechToTextService(
        defaultTranscript: 'show rallies where Max Freeman participated',
      );
      mockCloudSpeech = MockSpeechToTextService(
        defaultTranscript: 'show rallies where Max Freeman participated cloud',
      );
      requestedHttpPaths = [];
      conversationPayloads = [];

      mockPythonClient = PythonSearchApiClient(
        baseUrl: Uri.parse('https://api.test'),
        httpClient: MockClient((request) async {
          requestedHttpPaths.add(request.url.path);
          if (request.url.path == '/v1/conversation/search') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            conversationPayloads.add(body);
            final requestId = body['requestId'] as int? ?? 1;
            return http.Response(
              jsonEncode({
                'requestId': requestId,
                'session': {
                  'activeQuery': const SearchQuery(intent: SearchIntent.searchRallies).toJson(),
                  'referents': {},
                  'history': [],
                  'inheritedFields': [],
                  'currentRefinementFields': [],
                  'activeRequestId': requestId,
                },
                'result': {
                  'error': null,
                  'friendlyMessage': 'Results for rally search',
                  'referents': {},
                  'searchResponse': {
                    'intent': 'SEARCH_RALLIES',
                    'results': [
                      {
                        'eventId': 'e-1',
                        'eventName': 'Donegal Rally',
                        'country': 'Ireland',
                        'stagesCount': 10,
                      }
                    ],
                    'totalCount': 1,
                  },
                },
              }),
              200,
            );
          } else if (request.url.path == '/v1/voice/transcribe') {
            return http.Response(
              jsonEncode({
                'transcript': 'cloud transcription result for Max Freeman',
                'provider': 'openai',
                'model': 'whisper-1',
                'language': 'en',
                'latencyMs': 450.0,
                'uncalibratedConfidence': 0.95,
              }),
              200,
            );
          }
          return http.Response('{"error": "not found"}', 404);
        }),
      );
    });

    testWidgets('1 & 2: Native button invokes native STT only and does NOT upload audio', (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      final nativeBtn = find.byKey(const Key('native_voice_button'));
      expect(nativeBtn, findsOneWidget);

      await tester.tap(nativeBtn);
      await tester.pump();

      expect(mockNativeSpeech.isListening, isTrue);
      expect(mockCloudSpeech.isListening, isFalse);
      expect(requestedHttpPaths, isEmpty); // No audio upload or HTTP request

      await tester.tap(nativeBtn);
      await tester.pumpAndSettle();

      expect(requestedHttpPaths, isEmpty); // Still no HTTP upload
      expect(find.text('show rallies where Max Freeman participated'), findsOneWidget);
    });

    testWidgets('3, 4, 5, 6: Cloud button transcribes via transcribe endpoint without voice/search or DB execution', (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      final cloudBtn = find.byKey(const Key('cloud_voice_button'));
      expect(cloudBtn, findsOneWidget);

      await tester.tap(cloudBtn);
      await tester.pump();

      expect(mockCloudSpeech.isListening, isTrue);
      expect(mockNativeSpeech.isListening, isFalse);
      expect(requestedHttpPaths, isEmpty);

      await tester.tap(cloudBtn);
      await tester.pumpAndSettle();

      // Cloud speech completed, populates transcript
      expect(find.text('show rallies where Max Freeman participated cloud'), findsOneWidget);
      // Ensure /v1/voice/search was NOT called
      expect(requestedHttpPaths, isNot(contains('/v1/voice/search')));
    });

    testWidgets('7, 8, 9, 10, 11: Both methods populate same text controller, do not auto-submit, allow edits, submit to conversation', (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      // 1. Native voice
      final nativeBtn = find.byKey(const Key('native_voice_button'));
      await tester.tap(nativeBtn);
      await tester.pump();
      await tester.tap(nativeBtn);
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      expect(tester.widget<TextField>(textFieldFinder).controller?.text, 'show rallies where Max Freeman participated');
      expect(conversationPayloads, isEmpty); // No auto-submit!

      // Edit text
      await tester.enterText(textFieldFinder, 'show rallies where Max Freeman participated in 2025');
      await tester.pumpAndSettle();

      // Explicitly press Search
      final searchBtn = find.widgetWithText(FilledButton, 'Search');
      await tester.tap(searchBtn);
      await tester.pumpAndSettle();

      expect(requestedHttpPaths, contains('/v1/conversation/search'));
      expect(conversationPayloads.last['query'], 'show rallies where Max Freeman participated in 2025');
    });

    testWidgets('12, 13, 14: Native failure does not disable Cloud, Cloud failure does not disable Native, Typed search remains usable', (tester) async {
      setupScreen(tester);
      mockNativeSpeech.permissionGranted = false;

      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      // Tap native -> fails
      await tester.tap(find.byKey(const Key('native_voice_button')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      // Cloud remains usable!
      await tester.tap(find.byKey(const Key('cloud_voice_button')));
      await tester.pump();
      expect(mockCloudSpeech.isListening, isTrue);

      await tester.tap(find.byKey(const Key('cloud_voice_button')));
      await tester.pumpAndSettle();
      expect(find.text('show rallies where Max Freeman participated cloud'), findsOneWidget);

      // Typed search remains usable!
      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, 'typed search query');
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();

      expect(conversationPayloads.last['query'], 'typed search query');
    });

    testWidgets('15: Starting one STT mode cancels the other safely', (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      // Start Native
      await tester.tap(find.byKey(const Key('native_voice_button')));
      await tester.pump();
      expect(mockNativeSpeech.isListening, isTrue);
      expect(mockCloudSpeech.isIdle, isTrue);

      // Tap Cloud -> Native must be cancelled immediately
      await tester.tap(find.byKey(const Key('cloud_voice_button')));
      await tester.pump();
      expect(mockNativeSpeech.isIdle, isTrue);
      expect(mockCloudSpeech.isListening, isTrue);

      // Tap Native again -> Cloud must be cancelled
      await tester.tap(find.byKey(const Key('native_voice_button')));
      await tester.pump();
      expect(mockCloudSpeech.isIdle, isTrue);
      expect(mockNativeSpeech.isListening, isTrue);
    });

    testWidgets('16 & 17: Stale transcription protection across modes', (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      // Start Cloud
      await tester.tap(find.byKey(const Key('cloud_voice_button')));
      await tester.pump();

      // User starts Native before Cloud returns
      await tester.tap(find.byKey(const Key('native_voice_button')));
      await tester.pump();

      // Native delivers transcript
      mockNativeSpeech.emitPartialResult('Native transcript win');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, 'Native transcript win');

      // Stale cloud transcript callback should NOT overwrite Native transcript
      mockCloudSpeech.emitPartialResult('Old cloud transcript');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, 'Native transcript win');
    });

    testWidgets('18: Disposal and Clear cancel release listeners and clear state', (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('native_voice_button')));
      await tester.pump();
      expect(mockNativeSpeech.isListening, isTrue);

      // Tap Clear
      mockNativeSpeech.emitPartialResult('some words');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear_rounded).first);
      await tester.pump();

      expect(mockNativeSpeech.isIdle, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, isEmpty);
    });

    testWidgets('19: Locale propagation passes selected language', (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      // Change language to German
      final dropdown = find.byType(DropdownButton<SupportedLanguage>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final deItem = find.text('Deutsch (DE)').last;
      await tester.tap(deItem);
      await tester.pumpAndSettle();

      // Start Native
      await tester.tap(find.byKey(const Key('native_voice_button')));
      await tester.pump();

      // Submit search in German
      mockNativeSpeech.emitPartialResult('Zeige Rallyes in Irland');
      await tester.tap(find.byKey(const Key('native_voice_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();

      expect(conversationPayloads.last['language'], 'de');
    });

    testWidgets('20: wasEditedBeforeSubmit telemetry correctly detects edits and STT Source indicator is shown', (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(createDualTestApp(
        repository: mockRepo,
        nativeSpeech: mockNativeSpeech,
        cloudSpeech: mockCloudSpeech,
        pythonApiClient: mockPythonClient,
      ));
      await tester.pumpAndSettle();

      // Perform Cloud voice
      await tester.tap(find.byKey(const Key('cloud_voice_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cloud_voice_button')));
      await tester.pumpAndSettle();

      // Verify STT source indicator is displayed
      expect(find.text('Cloud Whisper transcript'), findsOneWidget);

      // Edit transcript
      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, 'edited query');
      await tester.pumpAndSettle();

      expect(find.text('Cloud Whisper transcript (edited)'), findsOneWidget);

      // Submit search
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();

      final dynamic state = tester.state(find.byType(GeneralSearchScreen));
      expect(state.lastVoiceTelemetry?['sttMethod'], 'CLOUD');
      expect(state.lastVoiceTelemetry?['wasEditedBeforeSubmit'], isTrue);
    });
  });
}
