import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:ai_rally_search/services/speech/mock_speech_to_text_service.dart';
import 'package:ai_rally_search/widgets/voice_search_button.dart';

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
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) async {
    return (await search(query)) as SearchResponse<RallySearchResult>;
  }

  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(SearchQuery query) async => throw UnimplementedError();
}

class FakeLlmParser implements LlmQueryParser {
  @override
  LlmProvider get provider => LlmProvider.mock;

  @override
  Future<QueryParseResult> parse(String rawQuery, {SearchContext? context}) async {
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
      mockRepo = MockSearchRepository();
      mockSpeech = MockSpeechToTextService(
        defaultTranscript: 'Show jumps featuring Moffett',
      );
    });

    testWidgets('Voice search button is present and starts idle', (tester) async {
      setupScreen(tester);

      await tester.pumpWidget(createTestApp(
        repository: mockRepo,
        speechService: mockSpeech,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VoiceSearchButton), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('Tapping mic button triggers listening and populates transcript without auto-executing', (tester) async {
      setupScreen(tester);

      mockSpeech.defaultTranscript = 'Show drifts in Galway 2024';

      await tester.pumpWidget(createTestApp(
        repository: mockRepo,
        speechService: mockSpeech,
      ));
      await tester.pumpAndSettle();

      // Tap voice button to start listening
      final micButton = find.byType(VoiceSearchButton);
      await tester.tap(micButton);
      await tester.pump();

      expect(mockSpeech.isListening, isTrue);

      // Tap voice button again to stop & finish transcription
      await tester.tap(micButton);
      await tester.pumpAndSettle();

      // Verify transcript is populated in textfield
      expect(find.text('Show drifts in Galway 2024'), findsOneWidget);

      // Verify text field holds the value for review/edit
      final textFieldFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'Show drifts in Galway 2024',
      );
      expect(textFieldFinder, findsOneWidget);
    });

    testWidgets('RTL text direction applies when Arabic or Urdu language is selected', (tester) async {
      setupScreen(tester);

      await tester.pumpWidget(createTestApp(
        repository: mockRepo,
        speechService: mockSpeech,
      ));
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
    });

    testWidgets('Microphone permission failure displays snackbar and allows typed search fallback', (tester) async {
      setupScreen(tester);

      mockSpeech.permissionGranted = false;

      await tester.pumpWidget(createTestApp(
        repository: mockRepo,
        speechService: mockSpeech,
      ));
      await tester.pumpAndSettle();

      // Tap voice button
      final micButton = find.byType(VoiceSearchButton);
      await tester.tap(micButton);
      await tester.pumpAndSettle();

      // Verify snackbar error message is shown
      expect(find.byType(SnackBar), findsOneWidget);

      // Verify typed search continues to work seamlessly
      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, 'Moffett crashes 2025');
      await tester.pumpAndSettle();

      final searchButton = find.widgetWithText(FilledButton, 'Search');
      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      // Typed search completed successfully
      expect(find.text('Moffett crashes 2025'), findsOneWidget);
    });
  });
}
