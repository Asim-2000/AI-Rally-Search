import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

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
import 'package:ai_rally_search/services/llm/entity_resolution/acoustic/acoustic_candidate_scorer.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/pronunciation/entity_pronunciation_metadata.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/pronunciation/pronunciation_encoder.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/spoken_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:ai_rally_search/services/speech/mock_speech_to_text_service.dart';

class TestLookupRepo implements IEntityLookupRepository {
  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 10,
  }) async {
    if (phrase.toLowerCase().contains('donegal')) {
      return const [
        EntityCandidate(
          id: 'rally-donegal',
          canonicalName: 'Donegal International Rally',
          type: EntityType.rally,
          score: 0.95,
        ),
      ];
    }
    return const [];
  }

  @override
  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    int limit = 10,
  }) async {
    if (phrase.toLowerCase().contains('moffett')) {
      return const [
        EntityCandidate(
          id: 'driver-moffett',
          canonicalName: 'Josh Moffett',
          type: EntityType.driver,
          score: 0.95,
        ),
      ];
    }
    return const [];
  }

  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 10,
  }) async =>
      const [];

  @override
  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 10,
  }) async =>
      const [];

  @override
  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 10,
  }) async =>
      const [];

  @override
  Future<List<EntityCandidate>> lookupEntities(
    String phrase, {
    int limit = 10,
  }) async =>
      const [];
}

class TestSearchRepo implements ISearchRepository {
  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    return SearchResponse<dynamic>(
      intent: query.intent,
      results: ['test_result_1'],
      totalCount: 1,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
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

void main() {
  group('Spoken Audio Context & Speech Transcription Models', () {
    test('SpokenAudioContext retains bytes and disposes on-disk file deterministically', () {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      tempFile.writeAsBytesSync([1, 2, 3, 4, 5]);
      expect(tempFile.existsSync(), isTrue);

      final audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        durationMs: 2500,
        format: 'm4a',
        sampleRate: 44100,
        channels: 1,
        localFilePath: tempFile.path,
      );

      expect(audioContext.isDisposed, isFalse);
      expect(audioContext.byteLength, 5);
      expect(audioContext.durationMs, 2500);

      // Dispose should delete the temp file
      audioContext.dispose();
      expect(audioContext.isDisposed, isTrue);
      expect(tempFile.existsSync(), isFalse);

      // Calling dispose again should be idempotent and safe
      expect(() => audioContext.dispose(), returnsNormally);
    });

    test('SpeechTranscriptionResult encapsulates optional hypotheses and timestamps', () {
      const hyp1 = TranscriptHypothesis(text: 'Show jumps in Donegal', confidence: 0.95, logProb: -0.05);
      const hyp2 = TranscriptHypothesis(text: 'Show jumps in Donegall', confidence: 0.75, logProb: -0.28);
      const word1 = SpokenWordTimestamp(word: 'Donegal', startMs: 1200, endMs: 1800, confidence: 0.98);

      final result = SpeechTranscriptionResult(
        text: 'Show jumps in Donegal',
        language: SupportedLanguages.english,
        durationMs: 2000,
        hypotheses: [hyp1, hyp2],
        words: [word1],
      );

      expect(result.text, 'Show jumps in Donegal');
      expect(result.hasHypotheses, isTrue);
      expect(result.hypotheses.length, 2);
      expect(result.hasTimestamps, isTrue);
      expect(result.words.first.durationMs, 600);
      expect(result.hasAudioContext, isFalse);
    });

    test('SpeechTranscriptionResult.textOnly creates simple backward-compatible result', () {
      final res = SpeechTranscriptionResult.textOnly(text: 'Kalle Rovanperä Sweden');
      expect(res.text, 'Kalle Rovanperä Sweden');
      expect(res.hasHypotheses, isFalse);
      expect(res.hasTimestamps, isFalse);
      expect(res.hasAudioContext, isFalse);
    });
  });

  group('ISpeechToTextService Backward Compatibility', () {
    test('MockSpeechToTextService implements stopListening and stopListeningDetailed interchangeably', () async {
      final mockStt = MockSpeechToTextService(
        defaultTranscript: 'Craig Breen Memorial',
        mockAttachAudioContext: true,
      );

      await mockStt.startListening(
        language: SupportedLanguages.english,
        onResult: (_, __) {},
        onStateChanged: (_) {},
        onError: (_) {},
      );

      final detailed = await mockStt.stopListeningDetailed();
      expect(detailed, isNotNull);
      expect(detailed!.text, 'Craig Breen Memorial');
      expect(detailed.hasAudioContext, isTrue);
      expect(detailed.audioContext!.byteLength, greaterThan(0));

      // Test standard stopListening
      await mockStt.startListening(
        language: SupportedLanguages.english,
        onResult: (_, __) {},
        onStateChanged: (_) {},
        onError: (_) {},
      );
      final text = await mockStt.stopListening();
      expect(text, 'Craig Breen Memorial');
    });

    test('transcribeAudioBytes and transcribeAudioBytesDetailed operate compatibly', () async {
      final mockStt = MockSpeechToTextService(
        defaultTranscript: 'Monte Carlo 2025',
      );

      final text = await mockStt.transcribeAudioBytes([10, 20, 30], language: SupportedLanguages.english);
      expect(text, 'Monte Carlo 2025');

      final detailed = await mockStt.transcribeAudioBytesDetailed([10, 20, 30], language: SupportedLanguages.english);
      expect(detailed, isNotNull);
      expect(detailed!.text, 'Monte Carlo 2025');
    });
  });

  group('Pronunciation & Acoustic Provider Abstractions', () {
    test('PassThroughPronunciationEncoder encodes canonical metadata without crashing', () async {
      const encoder = PassThroughPronunciationEncoder();
      final metadata = await encoder.encodeEntity(
        id: 'driver-001',
        name: 'Ott Tänak',
        type: EntityType.driver,
        languageHints: ['et'],
      );

      expect(metadata.canonicalId, 'driver-001');
      expect(metadata.canonicalName, 'Ott Tänak');
      expect(metadata.primaryPhonetic, 'ott tänak');
      expect(metadata.languageHints, ['et']);

      final keys = await encoder.generateRetrievalKeys('Ott Tänak');
      expect(keys, contains('ott tänak'));

      final sim = await encoder.comparePhonetic('ott tanak', 'ott tanak');
      expect(sim, 1.0);
    });

    test('EntityPronunciationMetadata serializes to and from JSON', () {
      const metadata = EntityPronunciationMetadata(
        canonicalId: 'rally-monte-carlo',
        canonicalName: 'Rallye Automobile de Monte-Carlo',
        entityType: EntityType.rally,
        languageHints: ['fr', 'en'],
        normalizedSpelling: 'rallye automobile de monte carlo',
        phoneticRepresentations: {
          'native': 'ʁali otɔmɔbil də mɔ̃te kaʁlo',
          'international': 'ræli ɒtəməbiːl də mɒnti kɑːloʊ',
        },
        retrievalKeys: ['monte', 'carlo', 'rallye'],
      );

      final json = metadata.toJson();
      final reconstructed = EntityPronunciationMetadata.fromJson(json);

      expect(reconstructed.canonicalId, metadata.canonicalId);
      expect(reconstructed.canonicalName, metadata.canonicalName);
      expect(reconstructed.entityType, EntityType.rally);
      expect(reconstructed.primaryPhonetic, 'ʁali otɔmɔbil də mɔ̃te kaʁlo');
      expect(reconstructed.internationalPhonetic, 'ræli ɒtəməbiːl də mɒnti kɑːloʊ');
    });

    test('NoOpAcousticCandidateScorer returns empty map without throwing', () async {
      const scorer = NoOpAcousticCandidateScorer();
      final audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList([1, 2, 3]),
        durationMs: 1000,
      );

      final scores = await scorer.rescoreCandidates(
        audioContext: audioContext,
        candidates: const [
          EntityCandidate(id: 'd1', canonicalName: 'Josh Moffett', type: EntityType.driver),
        ],
      );

      expect(scores, isEmpty);
    });
  });

  group('SpokenEntityResolver Orchestration & Deterministic Guarantees', () {
    test('Typed search delegates directly to DatabaseEntityResolver unchanged', () async {
      final repo = TestLookupRepo();
      final dbResolver = DatabaseEntityResolver(repository: repo);
      final spokenResolver = SpokenEntityResolver(
        repository: repo,
        baseResolver: dbResolver,
      );

      const typedQuery = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: ['Moffett'],
      );

      final dbResult = await dbResolver.resolve(typedQuery);
      final spokenResult = await spokenResolver.resolve(typedQuery);

      expect(spokenResult.requiresClarification, dbResult.requiresClarification);
      expect(spokenResult.resolvedQuery?.driverNames, dbResult.resolvedQuery?.driverNames);
      expect(spokenResult.resolvedQuery?.driverIds, dbResult.resolvedQuery?.driverIds);
      expect(spokenResult.resolutions.keys, dbResult.resolutions.keys);
    });

    test('resolveSpoken handles 1-best transcripts and preserves 0% false confident goal', () async {
      final repo = TestLookupRepo();
      final spokenResolver = SpokenEntityResolver(repository: repo);

      const parsedQuery = SearchQuery(
        intent: SearchIntent.searchRallies,
        rallyNames: ['Donegal'],
      );

      final speechResult = SpeechTranscriptionResult.textOnly(text: 'Donegal rally');
      final result = await spokenResolver.resolveSpoken(
        parsedQuery: parsedQuery,
        speechResult: speechResult,
      );

      expect(result.error, isNull);
      expect(result.resolvedQuery?.targetRallyNames, isNotEmpty);
    });
  });

  group('NaturalLanguageSearchService Spoken Execution & Lifecycle', () {
    test('searchSpoken disposes SpokenAudioContext in finally block on success', () async {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_leak_${DateTime.now().millisecondsSinceEpoch}.m4a');
      tempFile.writeAsBytesSync([10, 20, 30]);
      expect(tempFile.existsSync(), isTrue);

      final audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList([10, 20, 30]),
        durationMs: 1500,
        localFilePath: tempFile.path,
      );

      final speechResult = SpeechTranscriptionResult(
        text: 'rallies in 2025',
        language: SupportedLanguages.english,
        audioContext: audioContext,
      );

      final repo = TestLookupRepo();
      final spokenResolver = SpokenEntityResolver(repository: repo);
      final parser = MockLlmQueryParser(
        customMappings: {
          'rallies in 2025': const SearchQuery(
            intent: SearchIntent.searchRallies,
            years: [2025],
          ),
        },
      );

      final service = NaturalLanguageSearchService(
        parser: parser,
        entityResolver: spokenResolver,
        repository: TestSearchRepo(),
      );

      expect(audioContext.isDisposed, isFalse);
      final searchResult = await service.searchSpoken(speechResult);

      // Verify search executed and audio context was deterministically disposed
      expect(searchResult.isSuccess, isTrue);
      expect(audioContext.isDisposed, isTrue);
      expect(tempFile.existsSync(), isFalse);
    });

    test('searchSpoken disposes SpokenAudioContext in finally block on error', () async {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_leak_err_${DateTime.now().millisecondsSinceEpoch}.m4a');
      tempFile.writeAsBytesSync([10, 20, 30]);

      final audioContext = SpokenAudioContext(
        bytes: Uint8List.fromList([10, 20, 30]),
        durationMs: 1500,
        localFilePath: tempFile.path,
      );

      final speechResult = SpeechTranscriptionResult(
        text: '', // Empty query triggers early failure
        language: SupportedLanguages.english,
        audioContext: audioContext,
      );

      final repo = TestLookupRepo();
      final spokenResolver = SpokenEntityResolver(repository: repo);
      final parser = MockLlmQueryParser();

      final service = NaturalLanguageSearchService(
        parser: parser,
        entityResolver: spokenResolver,
        repository: TestSearchRepo(),
      );

      final searchResult = await service.searchSpoken(speechResult);
      expect(searchResult.isSuccess, isFalse);
      expect(audioContext.isDisposed, isTrue);
      expect(tempFile.existsSync(), isFalse);
    });
  });
}
