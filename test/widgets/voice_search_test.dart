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

class MockSearchRepository implements ISearchRepository {
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
  Future<SearchResponse<RallySearchResult>> searchRallies(
    SearchQuery query,
  ) async {
    return (await search(query)) as SearchResponse<RallySearchResult>;
  }

  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(
    SearchQuery query,
  ) async => throw UnimplementedError();
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(
    SearchQuery query,
  ) async => throw UnimplementedError();
}

class FakeLlmParser implements LlmQueryParser {
  @override
  LlmProvider get provider => LlmProvider.mock;

  @override
  Future<QueryParseResult> parse(
    String rawQuery, {
    SearchContext? context,
  }) async {
    return QueryParseResult(
      rawResponse: '{"intent": "SEARCH_VIDEO_ACTIONS", "driver_name": "Josh Moffett", "action_type": "jump"}',
      query: const SearchQuery(
        intent: SearchIntent.searchVideoActions,
        driverName: 'Josh Moffett',
        actionType: 'jump',
      ),
      confidence: 1.0,
      provider: LlmProvider.mock,
      model: 'fake',
    );
  }
}

Widget createTestApp({
  required ISearchRepository repository,
  required MockSpeechToTextService speechService,
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
      llmParser: FakeLlmParser(),
      speechService: speechService,
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

  group('Voice Search UI Integration Tests', () {
    late MockSearchRepository mockRepo;
    late MockSpeechToTextService mockSpeech;

    setUp(() {
      dotenv.loadFromString(envString: 'ENTITY_SEARCH_FALLBACK_MODE=OFF');
      mockRepo = MockSearchRepository();
      mockSpeech = MockSpeechToTextService(
        defaultTranscript: 'Show jumps featuring Moffett',
      );
    });

    testWidgets('Voice search button is present and starts idle', (
      tester,
    ) async {
      setupScreen(tester);

      await tester.pumpWidget(
        createTestApp(repository: mockRepo, speechService: mockSpeech),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('native_voice_button')), findsOneWidget);
      expect(find.byKey(const Key('cloud_voice_button')), findsOneWidget);
    });

    testWidgets(
      'Tapping mic button triggers listening and populates transcript without auto-executing',
      (tester) async {
        setupScreen(tester);

        mockSpeech.defaultTranscript = 'Show drifts in Galway 2024';

        await tester.pumpWidget(
          createTestApp(repository: mockRepo, speechService: mockSpeech),
        );
        await tester.pumpAndSettle();
        mockRepo.lastQuery = null;

        // Tap native voice button to start listening
        final micButton = find.byKey(const Key('native_voice_button'));
        await tester.tap(micButton);
        await tester.pump();

        expect(mockSpeech.isListening, isTrue);

        // Native interim results immediately populate the editable field.
        mockSpeech.emitPartialResult('Show drifts in');
        await tester.pump();
        var textField = tester.widget<TextField>(find.byType(TextField).first);
        expect(textField.controller?.text, 'Show drifts in');
        expect(mockRepo.lastQuery, isNull);

        // Tap voice button again to stop & finish transcription
        await tester.tap(micButton);
        await tester.pump(const Duration(milliseconds: 250));

        // Verify transcript is populated in textfield
        expect(find.text('Show drifts in Galway 2024'), findsOneWidget);

        // Verify text field holds the value for review/edit
        final textFieldFinder = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.controller?.text == 'Show drifts in Galway 2024',
        );
        expect(textFieldFinder, findsOneWidget);
        expect(mockRepo.lastQuery, isNull);

        // The human-edited text is authoritative and only explicit submission
        // enters the same typed search path.
        await tester.enterText(
          find.byType(TextField).first,
          'Show edited drifts in Galway 2024',
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller
              ?.text,
          'Show edited drifts in Galway 2024',
        );
      },
    );

    testWidgets(
      'Native transcript uses conversation endpoint only after explicit submission',
      (tester) async {
        setupScreen(tester);
        mockSpeech.defaultTranscript = 'Max McRae at Aluksne';
        final requestedPaths = <String>[];
        String? submittedQuery;
        final pythonClient = PythonSearchApiClient(
          baseUrl: Uri.parse('https://api.example'),
          httpClient: MockClient((request) async {
            requestedPaths.add(request.url.path);
            submittedQuery =
                (jsonDecode(request.body) as Map<String, dynamic>)['query']
                    as String?;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final requestId = body['requestId'] as int;
            return http.Response(
              jsonEncode({
                'requestId': requestId,
                'session': {
                  'activeQuery': const SearchQuery(
                    intent: SearchIntent.searchRallies,
                  ).toJson(),
                  'referents': {},
                  'history': [],
                  'inheritedFields': [],
                  'currentRefinementFields': [],
                  'activeRequestId': requestId,
                },
                'result': {
                  'error': 'test response',
                  'friendlyMessage': 'test response',
                  'referents': {},
                },
              }),
              200,
            );
          }),
        );

        await tester.pumpWidget(
          createTestApp(
            repository: mockRepo,
            speechService: mockSpeech,
            pythonApiClient: pythonClient,
          ),
        );
        await tester.pumpAndSettle();

        final mic = find.byKey(const Key('native_voice_button'));
        await tester.tap(mic);
        await tester.pump();
        mockSpeech.emitPartialResult('Max McRae');
        await tester.pump();
        expect(requestedPaths, isEmpty);

        await tester.tap(mic);
        await tester.pumpAndSettle();
        expect(requestedPaths, isEmpty);

        await tester.enterText(
          find.byType(TextField).first,
          'Max McRae at Aluksne edited',
        );
        await tester.tap(find.byKey(const Key('submit_search_button')));
        await tester.pumpAndSettle();

        expect(requestedPaths, ['/v1/conversation/search']);
        expect(submittedQuery, 'Max McRae at Aluksne edited');
        expect(requestedPaths, isNot(contains('/v1/voice/search')));
      },
    );

    testWidgets('Clear cancels listening and rejects stale partials', (
      tester,
    ) async {
      setupScreen(tester);
      await tester.pumpWidget(
        createTestApp(repository: mockRepo, speechService: mockSpeech),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('native_voice_button')));
      await tester.pump();
      mockSpeech.emitPartialResult('temporary words');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'temporary words',
      );

      await tester.tap(find.byIcon(Icons.clear_rounded).first);
      await tester.pump();
      expect(mockSpeech.isIdle, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        isEmpty,
      );

      mockSpeech.emitPartialResult('late stale words');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        isEmpty,
      );
    });

    testWidgets(
      'RTL text direction applies when Arabic or Urdu language is selected',
      (tester) async {
        setupScreen(tester);

        await tester.pumpWidget(
          createTestApp(repository: mockRepo, speechService: mockSpeech),
        );
        await tester.pumpAndSettle();

        // Find language dropdown
        final dropdown = find.byType(DropdownButton<SupportedLanguage>);
        expect(dropdown, findsOneWidget);

        // Open dropdown
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        // Select Arabic
        final arabicItem = find.text('العربية (AR)').last;
        await tester.tap(arabicItem);
        await tester.pumpAndSettle();

        // Verify TextField has RTL text direction
        final textFieldFinder = find.byType(TextField).first;
        expect(textFieldFinder, findsOneWidget);
        final textField = tester.widget<TextField>(textFieldFinder);
        expect(textField.textDirection, equals(TextDirection.rtl));
        expect(textField.textAlign, equals(TextAlign.right));
      },
    );

    testWidgets(
      'Microphone permission failure displays snackbar and allows typed search fallback',
      (tester) async {
        setupScreen(tester);

        mockSpeech.permissionGranted = false;

        await tester.pumpWidget(
          createTestApp(repository: mockRepo, speechService: mockSpeech),
        );
        await tester.pumpAndSettle();

        // Tap native voice button
        final micButton = find.byKey(const Key('native_voice_button'));
        await tester.tap(micButton);
        await tester.pumpAndSettle();

        // Verify snackbar error message is shown
        expect(find.byType(SnackBar), findsOneWidget);

        // Verify typed search continues to work seamlessly
        final textFieldFinder = find.byType(TextField).first;
        await tester.enterText(textFieldFinder, 'Moffett crashes 2025');
        await tester.pumpAndSettle();

        final searchButton = find.byKey(const Key('submit_search_button'));
        await tester.tap(searchButton);
        await tester.pump(const Duration(milliseconds: 250));

        // Typed search completed successfully
        expect(find.text('Moffett crashes 2025'), findsOneWidget);
      },
    );
  });
}
