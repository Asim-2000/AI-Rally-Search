import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_rally_search/l10n/generated/app_localizations.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/speech/speech_transcription_result.dart';
import 'package:ai_rally_search/models/speech/spoken_audio_context.dart';
import 'package:ai_rally_search/models/speech/spoken_word_timestamp.dart';
import 'package:ai_rally_search/models/speech/transcript_hypothesis.dart';
import 'package:ai_rally_search/models/supported_language.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/spoken_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/speech/mock_speech_to_text_service.dart';
import 'package:ai_rally_search/widgets/voice_search_button.dart';

class SpyingLookupRepository implements IEntityLookupRepository {
  @override
  Future<List<EntityCandidate>> lookupRallies(String phrase, {int? year, String? country, String? city, int limit = 10}) async {
    return const [
      EntityCandidate(
        id: 'rally-donegal',
        canonicalName: 'Donegal International Rally',
        type: EntityType.rally,
        score: 0.95,
      ),
    ];
  }

  @override
  Future<List<EntityCandidate>> lookupDrivers(String phrase, {String? eventId, String? eventName, int? year, int limit = 10}) async => const [];
  @override
  Future<List<EntityCandidate>> lookupStages(String phrase, {String? eventId, String? eventName, int limit = 10}) async => const [];
  @override
  Future<List<EntityCandidate>> lookupCities(String phrase, {String? country, int limit = 10}) async => const [];
  @override
  Future<List<EntityCandidate>> lookupUploaders(String phrase, {int limit = 10}) async => const [];
  @override
  Future<List<EntityCandidate>> lookupEntities(String phrase, {int limit = 10}) async => const [];
}

class TrackingSpokenEntityResolver extends SpokenEntityResolver {
  SpeechTranscriptionResult? lastReceivedSpeechResult;
  bool? audioContextWasAliveDuringResolution;
  int resolveSpokenCallCount = 0;
  int resolveTypedCallCount = 0;

  TrackingSpokenEntityResolver({required super.repository});

  @override
  Future<EntityResolutionResult> resolve(SearchQuery query, {SearchContext? context}) {
    resolveTypedCallCount++;
    return super.resolve(query, context: context);
  }

  @override
  Future<EntityResolutionResult> resolveSpoken({
    required SearchQuery parsedQuery,
    required SpeechTranscriptionResult speechResult,
    SearchContext? context,
  }) async {
    resolveSpokenCallCount++;
    lastReceivedSpeechResult = speechResult;
    audioContextWasAliveDuringResolution = speechResult.audioContext != null && !speechResult.audioContext!.isDisposed;
    return super.resolveSpoken(
      parsedQuery: parsedQuery,
      speechResult: speechResult,
      context: context,
    );
  }
}

class TrackingNlSearchService extends NaturalLanguageSearchService {
  int searchSpokenCallCount = 0;
  int searchTypedCallCount = 0;
  SpeechTranscriptionResult? lastSearchSpokenArg;

  TrackingNlSearchService({
    required super.parser,
    required super.entityResolver,
    required super.repository,
  });

  @override
  Future<NaturalLanguageSearchResult> search(String naturalQuery, {SearchContext? context, SpeechTranscriptionResult? speechResult}) {
    searchTypedCallCount++;
    return super.search(naturalQuery, context: context, speechResult: speechResult);
  }

  @override
  Future<NaturalLanguageSearchResult> searchSpoken(SpeechTranscriptionResult speechResult, {SearchContext? context}) {
    searchSpokenCallCount++;
    lastSearchSpokenArg = speechResult;
    return super.searchSpoken(speechResult, context: context);
  }
}

class SpyingSearchRepository implements ISearchRepository {
  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    if (query.intent == SearchIntent.searchRallies) {
      return SearchResponse<RallySearchResult>(
        intent: query.intent,
        results: [
          RallySearchResult(
            eventId: 'rally-donegal',
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

    return SearchResponse<VideoAction>(
      intent: query.intent,
      results: const [
        VideoAction(
          id: 1,
          videoId: 1,
          actionType: 'jump',
          title: 'Donegal Jump 2025',
          startTime: 12.0,
          endTime: 16.0,
          duration: 4.0,
          driverName: 'Josh Moffett',
          eventName: 'Donegal International Rally',
        ),
      ],
      totalCount: 1,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) async => (await search(query)) as SearchResponse<RallySearchResult>;
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery query) async => (await search(query)) as SearchResponse<VideoAction>;
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(SearchQuery query) async => throw UnimplementedError();
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(SearchQuery query) async => throw UnimplementedError();
}

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
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

  group('True End-to-End Spoken Voice Search Integration', () {
    testWidgets('Voice search triggers searchSpoken, preserves rich metadata into SpokenEntityResolver, and disposes audio', (tester) async {
      setupScreen(tester);

      final audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        durationMs: 3200,
        format: 'm4a',
      );

      final richSpeechResult = SpeechTranscriptionResult(
        text: 'Donegal rally 2025',
        language: SupportedLanguages.english,
        durationMs: 3200,
        confidence: 0.94, // providerConfidenceSignal
        hypotheses: const [
          TranscriptHypothesis(text: 'Donegal rally 2025', confidence: 0.94, logProb: -0.06),
          TranscriptHypothesis(text: 'Donegal rally 25', confidence: 0.81, logProb: -0.21),
        ],
        words: const [
          SpokenWordTimestamp(word: 'Donegal', startMs: 200, endMs: 900, confidence: 0.98),
          SpokenWordTimestamp(word: 'rally', startMs: 950, endMs: 1400, confidence: 0.96),
          SpokenWordTimestamp(word: '2025', startMs: 1450, endMs: 2200, confidence: 0.92),
        ],
        audioContext: audioContext,
      );

      final mockStt = MockSpeechToTextService(
        defaultTranscript: 'Donegal rally 2025',
        mockHypotheses: richSpeechResult.hypotheses,
        mockWords: richSpeechResult.words,
        mockAttachAudioContext: true,
        simulatedProcessingDelay: Duration.zero,
      );

      final lookupRepo = SpyingLookupRepository();
      final spokenResolver = TrackingSpokenEntityResolver(repository: lookupRepo);
      final searchRepo = SpyingSearchRepository();
      final parser = MockLlmQueryParser(
        customMappings: {
          'donegal rally 2025': const SearchQuery(
            intent: SearchIntent.searchRallies,
            rallyNames: ['Donegal'],
            years: [2025],
          ),
        },
      );

      final trackingNlService = TrackingNlSearchService(
        parser: parser,
        entityResolver: spokenResolver,
        repository: searchRepo,
      );

      await tester.pumpWidget(
        createTestApp(
          GeneralSearchScreen(
            speechService: mockStt,
            llmParser: parser,
            nlSearchService: trackingNlService,
            repository: searchRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the VoiceSearchButton to start recording
      final micFinder = find.byType(VoiceSearchButton);
      expect(micFinder, findsOneWidget);
      await tester.tap(micFinder);
      await tester.pump();

      expect(mockStt.isListening, isTrue);

      // Stop listening to complete recording and trigger searchSpoken
      await tester.tap(micFinder);
      await tester.pumpAndSettle();

      // Assertions:
      // A. searchSpoken() was invoked on NaturalLanguageSearchService
      expect(trackingNlService.searchSpokenCallCount, 1);
      expect(trackingNlService.lastSearchSpokenArg, isNotNull);

      // B. SpokenEntityResolver receives SpeechTranscriptionResult
      expect(spokenResolver.resolveSpokenCallCount, 1);
      final receivedSpeech = spokenResolver.lastReceivedSpeechResult;
      expect(receivedSpeech, isNotNull);

      // C. Rich metadata survived intact into the resolver
      expect(receivedSpeech!.text, 'Donegal rally 2025');
      expect(receivedSpeech.hypotheses.length, 2);
      expect(receivedSpeech.hypotheses.first.text, 'Donegal rally 2025');
      expect(receivedSpeech.words.length, 3);
      expect(receivedSpeech.words.first.word, 'Donegal');
      expect(receivedSpeech.words.first.durationMs, 700);

      // D. audioContext was still alive during SpokenEntityResolver resolution
      expect(spokenResolver.audioContextWasAliveDuringResolution, isTrue);

      // E. audioContext is disposed after resolution completes
      expect(receivedSpeech.audioContext?.isDisposed, isTrue);

      // G. Search field contains the editable transcript
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, 'Donegal rally 2025');
    });

    test('audioContext is deterministically disposed even if query parser throws', () async {
      final audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList([10, 20, 30]),
        durationMs: 1000,
      );

      final speechResult = SpeechTranscriptionResult(
        text: 'throw error test',
        language: SupportedLanguages.english,
        audioContext: audioContext,
      );

      final lookupRepo = SpyingLookupRepository();
      final spokenResolver = TrackingSpokenEntityResolver(repository: lookupRepo);
      final parser = MockLlmQueryParser(
        simulateFailure: true,
        failureMessage: 'Intentional parser crash',
      );

      final nlService = NaturalLanguageSearchService(
        parser: parser,
        entityResolver: spokenResolver,
        repository: SpyingSearchRepository(),
      );

      expect(audioContext.isDisposed, isFalse);
      final result = await nlService.searchSpoken(speechResult);

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Intentional parser crash'));
      // Assert F: audioContext is guaranteed disposed in finally block
      expect(audioContext.isDisposed, isTrue);
    });

    test('audioContext is deterministically disposed even if repository search throws', () async {
      final audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList([10, 20, 30]),
        durationMs: 1000,
      );

      final speechResult = SpeechTranscriptionResult(
        text: 'failing search query',
        language: SupportedLanguages.english,
        audioContext: audioContext,
      );

      final lookupRepo = SpyingLookupRepository();
      final spokenResolver = TrackingSpokenEntityResolver(repository: lookupRepo);
      final parser = MockLlmQueryParser(
        customMappings: {
          'failing search query': const SearchQuery(intent: SearchIntent.searchRallies),
        },
      );

      // Repo that throws
      final nlService = NaturalLanguageSearchService(
        parser: parser,
        entityResolver: spokenResolver,
        repository: FailingSearchRepository(),
      );

      expect(audioContext.isDisposed, isFalse);
      final result = await nlService.searchSpoken(speechResult);

      expect(result.isSuccess, isFalse);
      // Assert F: audioContext is guaranteed disposed in finally block
      expect(audioContext.isDisposed, isTrue);
    });
  });
}

class FailingSearchRepository implements ISearchRepository {
  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    throw Exception('Database connection timed out');
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) async => throw UnimplementedError();
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
