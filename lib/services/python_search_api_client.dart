import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/conversational_search_session.dart';
import '../models/entity_candidate.dart';
import '../models/result_referent_context.dart';
import '../models/search_intent.dart';
import '../models/search_query.dart';
import '../models/search_results.dart';
import '../models/speech/speech_transcription_result.dart';
import '../models/speech/spoken_word_timestamp.dart';
import '../models/speech/transcript_hypothesis.dart';
import '../models/supported_language.dart';
import '../models/video_action.dart';
import 'search_repository.dart';
import 'friendly_response_service.dart';
import 'latency/latency_policy.dart';
import 'llm/natural_language_search_service.dart';
import 'llm/query_parse_result.dart';

/// Configuration for the Python FastAPI backend, which is the sole
/// authoritative search backend. There is deliberately no legacy/python runtime
/// switch: the only configuration is the backend origin URL. When it is absent
/// the app surfaces a clean error rather than falling back to any in-app engine.
class SearchBackendConfig {
  final Uri? pythonBaseUrl;
  final Duration typedTimeout;
  final Duration voiceTimeout;
  final Map<String, String> headers;

  /// Timeouts come from [LatencyPolicy] rather than being declared here, so
  /// the client and the fallback coordinator can never disagree about how long
  /// an online request is allowed to take.
  SearchBackendConfig({
    this.pythonBaseUrl,
    LatencyPolicy policy = LatencyPolicy.standard,
    Duration? typedTimeout,
    Duration? voiceTimeout,
    this.headers = const {},
  })  : typedTimeout = typedTimeout ?? policy.overallOnlineTimeout,
        voiceTimeout = voiceTimeout ?? policy.overallVoiceTimeout;

  factory SearchBackendConfig.fromEnvironment() {
    final url = dotenv.isInitialized
        ? dotenv.env['PYTHON_BACKEND_BASE_URL']?.trim()
        : null;
    return SearchBackendConfig(
      pythonBaseUrl: (url == null || url.isEmpty) ? null : Uri.parse(url),
    );
  }

  bool get hasPythonBackend => pythonBaseUrl != null;

  /// Builds a client when a backend URL is configured, otherwise returns null
  /// so the caller can present a clean configuration error.
  PythonSearchApiClient? tryCreateClient({http.Client? httpClient}) {
    final base = pythonBaseUrl;
    if (base == null) return null;
    return PythonSearchApiClient(
      baseUrl: base,
      httpClient: httpClient,
      typedTimeout: typedTimeout,
      voiceTimeout: voiceTimeout,
      headers: headers,
    );
  }
}

class PythonApiException implements Exception {
  final String category;
  final int? statusCode;
  final String telemetryDetail;
  const PythonApiException(
    this.category,
    this.telemetryDetail, {
    this.statusCode,
  });

  String get friendlyMessage {
    switch (category) {
      case 'timeout':
        return const FriendlyResponseService().responseFor(
          FriendlyResponseCategory.timeout,
        );
      case 'network':
        return const FriendlyResponseService().responseFor(
          FriendlyResponseCategory.networkError,
        );
      case 'parse':
        return const FriendlyResponseService().responseFor(
          FriendlyResponseCategory.parseFailure,
        );
      default:
        return const FriendlyResponseService().responseFor(
          FriendlyResponseCategory.serverError,
        );
    }
  }

  @override
  String toString() => 'PythonApiException($category, status=$statusCode)';
}

class PythonConversationResponse {
  final SearchConversationSession session;
  final NaturalLanguageSearchResult result;

  /// The client's session generation counter, echoed by the backend. Used to
  /// reject a response that belongs to a superseded search.
  final int? requestId;

  /// The end-to-end correlation id (`X-Request-Id`). Joins this response to
  /// the backend's structured timing line for the same request.
  final String? traceId;

  /// Measured wall time of the HTTP call, for client-side latency records.
  final int? networkRoundtripMs;

  /// Backend phase breakdown, present only when the backend runs with debug
  /// timings enabled. Never shown to users.
  final Map<String, dynamic>? backendTimings;

  final SpeechTranscriptionResult? transcription;
  final Map<String, dynamic> telemetry;
  const PythonConversationResponse({
    required this.session,
    required this.result,
    this.requestId,
    this.traceId,
    this.networkRoundtripMs,
    this.backendTimings,
    this.transcription,
    this.telemetry = const {},
  });
}

class CloudTranscriptionResponse {
  final String transcript;
  final String provider;
  final String model;
  final String language;
  final double latencyMs;
  final double? uncalibratedConfidence;

  const CloudTranscriptionResponse({
    required this.transcript,
    required this.provider,
    required this.model,
    required this.language,
    required this.latencyMs,
    this.uncalibratedConfidence,
  });

  factory CloudTranscriptionResponse.fromJson(Map<String, dynamic> json) {
    return CloudTranscriptionResponse(
      transcript: '${json['transcript'] ?? ''}',
      provider: '${json['provider'] ?? ''}',
      model: '${json['model'] ?? ''}',
      language: '${json['language'] ?? 'en'}',
      latencyMs: (json['latencyMs'] as num?)?.toDouble() ?? 0.0,
      uncalibratedConfidence:
          (json['uncalibratedConfidence'] as num?)?.toDouble(),
    );
  }
}

class PythonSearchApiClient {
  /// End-to-end correlation header, matched by the backend timing middleware.
  static const String requestIdHeader = 'X-Request-Id';

  final Uri baseUrl;
  final http.Client _http;
  final Duration typedTimeout;
  final Duration voiceTimeout;
  final Map<String, String> headers;

  PythonSearchApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    LatencyPolicy policy = LatencyPolicy.standard,
    Duration? typedTimeout,
    Duration? voiceTimeout,
    this.headers = const {},
  })  : _http = httpClient ?? http.Client(),
        typedTimeout = typedTimeout ?? policy.overallOnlineTimeout,
        voiceTimeout = voiceTimeout ?? policy.overallVoiceTimeout;

  factory PythonSearchApiClient.fromConfig(
    SearchBackendConfig config, {
    http.Client? httpClient,
  }) {
    final base = config.pythonBaseUrl;
    if (base == null)
      throw const PythonApiException(
        'config',
        'PYTHON_BACKEND_BASE_URL is missing',
      );
    return PythonSearchApiClient(
      baseUrl: base,
      httpClient: httpClient,
      typedTimeout: config.typedTimeout,
      voiceTimeout: config.voiceTimeout,
      headers: config.headers,
    );
  }

  Future<CloudTranscriptionResponse> transcribe({
    required Uint8List audioBytes,
    required String filename,
    required String language,
  }) async {
    final uri = _uri('/v1/voice/transcribe', {
      'filename': filename,
      'language': language,
    });
    final response = await _send(
      () => _http
          .post(
            uri,
            headers: {...headers, 'Content-Type': 'application/octet-stream'},
            body: audioBytes,
          )
          .timeout(voiceTimeout),
    );
    final body = _decodeBody(response);
    return CloudTranscriptionResponse.fromJson(body);
  }

  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    final body = await _postJson('/v1/search', query.toJson(), typedTimeout);
    return _decodeSearchResponse(body);
  }

  Future<PythonConversationResponse> conversation({
    required String query,
    required SearchConversationSession session,
    required String language,
    required int requestId,
    String? traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final body = await _postJson(
      '/v1/conversation/search',
      {
        'query': query,
        'session': _sessionToJson(session),
        'language': language,
        'requestId': requestId,
      },
      typedTimeout,
      traceId: traceId,
    );
    stopwatch.stop();
    return _decodeConversation(
      body,
      networkRoundtripMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<PythonConversationResponse> voice({
    required Uint8List audioBytes,
    required String filename,
    required SearchConversationSession session,
    required String language,
    required int requestId,
    String? editedTranscript,
    String? traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final uri = _uri('/v1/voice/search', {
      'filename': filename,
      'language': language,
      'session': jsonEncode(_sessionToJson(session)),
      'requestId': '$requestId',
      if (editedTranscript?.trim().isNotEmpty == true)
        'editedTranscript': editedTranscript!.trim(),
    });
    final response = await _send(
      () => _http
          .post(
            uri,
            headers: {
              ...headers,
              'Content-Type': 'application/octet-stream',
              requestIdHeader: ?traceId,
            },
            body: audioBytes,
          )
          .timeout(voiceTimeout),
    );
    stopwatch.stop();
    final body = _decodeBody(response);
    final decoded = _decodeConversation(
      body,
      networkRoundtripMs: stopwatch.elapsedMilliseconds,
    );
    final raw = Map<String, dynamic>.from(
      body['transcription'] as Map? ?? const {},
    );
    final words = (raw['words'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (w) => SpokenWordTimestamp(
            word: '${w['word'] ?? ''}',
            startMs: _int(w['startMs']),
            endMs: _int(w['endMs']),
            confidence: _double(w['confidence']),
          ),
        )
        .toList();
    final hypotheses = (raw['hypotheses'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (h) => TranscriptHypothesis(
            text: '${h['text'] ?? ''}',
            confidence: _double(h['confidence']) ?? 0,
            logProb: _double(h['logProb']),
          ),
        )
        .toList();
    final transcription = SpeechTranscriptionResult(
      text: '${raw['text'] ?? ''}',
      language:
          SupportedLanguages.findByCode('${raw['language'] ?? language}') ??
          SupportedLanguages.defaultLanguage,
      words: words,
      hypotheses: hypotheses,
      durationMs: _int(raw['durationMs']),
      confidence: _double(raw['confidence']),
    );
    return PythonConversationResponse(
      session: decoded.session,
      result: decoded.result,
      requestId: decoded.requestId,
      traceId: decoded.traceId,
      networkRoundtripMs: decoded.networkRoundtripMs,
      backendTimings: decoded.backendTimings,
      transcription: transcription,
      telemetry: Map<String, dynamic>.from(
        body['telemetry'] as Map? ?? const {},
      ),
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
    Duration timeout, {
    String? traceId,
  }) async {
    final response = await _send(
      () => _http
          .post(
            _uri(path),
            headers: {
              ...headers,
              'Content-Type': 'application/json',
              // Correlation only: an opaque id the backend echoes into its
              // structured timing line. Carries no user or query content.
              requestIdHeader: ?traceId,
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout),
    );
    return _decodeBody(response);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() operation,
  ) async {
    try {
      return await operation();
    } on TimeoutException catch (e) {
      throw PythonApiException('timeout', '$e');
    } on http.ClientException catch (e) {
      throw PythonApiException('network', '$e');
    }
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (e) {
      throw PythonApiException(
        'malformed',
        '$e',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final category = response.statusCode == 422
          ? 'parse'
          : response.statusCode == 504
          ? 'timeout'
          : 'server';
      throw PythonApiException(
        category,
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      baseUrl.resolve(path).replace(queryParameters: query);

  PythonConversationResponse _decodeConversation(
    Map<String, dynamic> body, {
    int? networkRoundtripMs,
  }) {
    final resultMap = Map<String, dynamic>.from(
      body['result'] as Map? ?? const {},
    );
    final session = _sessionFromJson(
      Map<String, dynamic>.from(body['session'] as Map? ?? const {}),
    );
    final parsed = resultMap['parsedQuery'] is Map
        ? SearchQuery.fromJson(
            Map<String, dynamic>.from(resultMap['parsedQuery']),
          )
        : null;
    final resolved = resultMap['resolvedQuery'] is Map
        ? SearchQuery.fromJson(
            Map<String, dynamic>.from(resultMap['resolvedQuery']),
          )
        : parsed;
    final response = resultMap['searchResponse'] is Map
        ? _decodeSearchResponse(
            Map<String, dynamic>.from(resultMap['searchResponse']),
          )
        : null;
    final candidates = (resultMap['candidates'] as List? ?? const [])
        .whereType<Map>()
        .map((x) {
          final candidate = Map<String, dynamic>.from(x);
          candidate['canonicalName'] ??= candidate['canonical_name'];
          return EntityCandidate.fromMap(candidate);
        })
        .toList();
    final parse = QueryParseResult(
      query: parsed,
      requiresClarification: resultMap['requiresClarification'] == true,
      clarificationQuestion: resultMap['clarificationQuestion']?.toString(),
      error: resultMap['error']?.toString(),
      interpretedSummary: resultMap['interpretedSummary']?.toString(),
      latencyMs: _int(resultMap['parseLatencyMs']),
    );
    final special = _specialCategory(
      resultMap['specialResponseCategory']?.toString(),
    );
    final result = NaturalLanguageSearchResult(
      parseResult: parse,
      parsedQuery: parsed,
      resolvedQuery: resolved,
      searchResponse: response,
      requiresClarification: resultMap['requiresClarification'] == true,
      clarificationQuestion: resultMap['clarificationQuestion']?.toString(),
      candidates: candidates,
      error: resultMap['error']?.toString(),
      errorCode: _errorCode(resultMap['errorCode']?.toString()),
      friendlyMessage: resultMap['friendlyMessage']?.toString(),
      specialResponseCategory: special,
      interpretedSummary: resultMap['interpretedSummary']?.toString(),
      referents: _referentsFromJson(
        Map<String, dynamic>.from(resultMap['referents'] as Map? ?? const {}),
      ),
      entityResolutionLatencyMs: _int(resultMap['entityResolutionLatencyMs']),
      dbLatencyMs: _int(resultMap['dbLatencyMs']),
      totalLatencyMs: _int(resultMap['totalLatencyMs']),
    );
    return PythonConversationResponse(
      session: session,
      result: result,
      requestId: _nullableInt(body['requestId']),
      traceId: body['traceId']?.toString(),
      networkRoundtripMs: networkRoundtripMs,
      backendTimings: resultMap['timings'] is Map
          ? Map<String, dynamic>.from(resultMap['timings'] as Map)
          : null,
    );
  }

  SearchResponse<dynamic> _decodeSearchResponse(Map<String, dynamic> map) {
    final intent = SearchIntent.fromString('${map['intent']}');
    final rows = (map['results'] as List? ?? const []).whereType<Map>().map((
      raw,
    ) {
      final row = Map<String, dynamic>.from(raw);
      switch (intent) {
        case SearchIntent.searchRallies:
          return RallySearchResult.fromMap(row);
        case SearchIntent.searchDriverRallies:
        case SearchIntent.searchDriverWins:
          return RallyParticipationResult.fromMap(row);
        case SearchIntent.getRallyResults:
        case SearchIntent.getRallyTopFinishers:
          return RallyResult.fromMap(row);
        case SearchIntent.searchVideoActions:
          return VideoAction.fromMap(row);
        case SearchIntent.searchDriverVideos:
          return VideoSearchResult.fromMap(row);
        case SearchIntent.getTopUploaders:
          return UploaderSearchResult.fromMap(row);
        case SearchIntent.getTopDriversByWins:
          return DriverWinResult.fromMap(row);
      }
    }).toList();
    return SearchResponse<dynamic>(
      intent: intent,
      results: rows,
      totalCount: _int(map['total_count'] ?? map['totalCount']),
      hasMore: map['has_more'] == true || map['hasMore'] == true,
      limit: _int(map['limit']),
      offset: _int(map['offset']),
    );
  }

  Map<String, dynamic> _sessionToJson(SearchConversationSession s) => {
    'activeQuery': s.activeQuery.toJson(),
    'previousQuery': s.previousQuery?.toJson(),
    'referents': _referentsToJson(s.referents),
    'history': s.history
        .map(
          (h) => {
            'title': h.title,
            'query': h.query.toJson(),
            'referents': _referentsToJson(h.referents),
            'interpretedSummary': h.interpretedSummary,
            'timestamp': h.timestamp.toIso8601String(),
          },
        )
        .toList(),
    'inheritedFields': s.inheritedFields.toList(),
    'currentRefinementFields': s.currentRefinementFields.toList(),
    'activeRequestId': s.activeRequestId,
  };
  SearchConversationSession _sessionFromJson(Map<String, dynamic> m) =>
      SearchConversationSession(
        activeQuery: m['activeQuery'] is Map
            ? SearchQuery.fromJson(Map<String, dynamic>.from(m['activeQuery']))
            : const SearchQuery(intent: SearchIntent.searchRallies),
        previousQuery: m['previousQuery'] is Map
            ? SearchQuery.fromJson(
                Map<String, dynamic>.from(m['previousQuery']),
              )
            : null,
        referents: _referentsFromJson(
          Map<String, dynamic>.from(m['referents'] as Map? ?? const {}),
        ),
        history: (m['history'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (h) => SessionTurnSnapshot(
                title: '${h['title'] ?? ''}',
                query: SearchQuery.fromJson(
                  Map<String, dynamic>.from(h['query'] as Map),
                ),
                referents: _referentsFromJson(
                  Map<String, dynamic>.from(h['referents'] as Map? ?? const {}),
                ),
                interpretedSummary: h['interpretedSummary']?.toString(),
                timestamp:
                    DateTime.tryParse('${h['timestamp']}') ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              ),
            )
            .toList(),
        inheritedFields: Set<String>.from(
          m['inheritedFields'] as List? ?? const [],
        ),
        currentRefinementFields: Set<String>.from(
          m['currentRefinementFields'] as List? ?? const [],
        ),
        activeRequestId: _int(m['activeRequestId']),
      );
  Map<String, dynamic> _referentsToJson(ResultReferentContext r) => {
    'activeRally': r.activeRally,
    'activeRallyId': r.activeRallyId,
    'activeRallies': r.activeRallies,
    'activeDriver': r.activeDriver,
    'activeDriverId': r.activeDriverId,
    'activeDrivers': r.activeDrivers,
    'activePersonRole': r.activePersonRole?.toRoleString(),
    'activeStage': r.activeStage,
    'activeStageNumber': r.activeStageNumber,
    'lastWinner': r.lastWinner,
    'lastWinnerDriverId': r.lastWinnerDriverId,
    'lastSelectedDriver': r.lastSelectedDriver,
    'lastSelectedDriverId': r.lastSelectedDriverId,
    'lastSelectedRally': r.lastSelectedRally,
    'lastSelectedRallyId': r.lastSelectedRallyId,
    'metadata': r.metadata,
  };
  ResultReferentContext _referentsFromJson(
    Map<String, dynamic> m,
  ) => ResultReferentContext(
    activeRally: m['activeRally']?.toString(),
    activeRallyId: m['activeRallyId']?.toString(),
    activeRallies: List<String>.from(m['activeRallies'] as List? ?? const []),
    activeDriver: m['activeDriver']?.toString(),
    activeDriverId: m['activeDriverId']?.toString(),
    activeDrivers: List<String>.from(m['activeDrivers'] as List? ?? const []),
    activePersonRole: m['activePersonRole'] == null
        ? null
        : PersonRole.fromString('${m['activePersonRole']}'),
    activeStage: m['activeStage']?.toString(),
    activeStageNumber: m['activeStageNumber']?.toString(),
    lastWinner: m['lastWinner']?.toString(),
    lastWinnerDriverId: m['lastWinnerDriverId']?.toString(),
    lastSelectedDriver: m['lastSelectedDriver']?.toString(),
    lastSelectedDriverId: m['lastSelectedDriverId']?.toString(),
    lastSelectedRally: m['lastSelectedRally']?.toString(),
    lastSelectedRallyId: m['lastSelectedRallyId']?.toString(),
    metadata: Map<String, dynamic>.from(m['metadata'] as Map? ?? const {}),
  );
}

/// Adapts the provider-neutral Python search endpoint to the existing Flutter
/// repository contract so pagination and advanced filters keep their UI path.
class PythonSearchRepository implements ISearchRepository {
  final PythonSearchApiClient client;
  const PythonSearchRepository(this.client);

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) =>
      client.search(query);

  Future<SearchResponse<T>> _typed<T>(SearchQuery query) async {
    final response = await search(query);
    return SearchResponse<T>(
      intent: response.intent,
      results: response.results.cast<T>(),
      totalCount: response.totalCount,
      hasMore: response.hasMore,
      limit: response.limit,
      offset: response.offset,
    );
  }

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery query) =>
      _typed(query);
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(
    SearchQuery query,
  ) => _typed(query);
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(
    SearchQuery query,
  ) => _typed(query);
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery query) =>
      _typed(query);
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery query) =>
      _typed(query);
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery query) =>
      _typed(query);
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(
    SearchQuery query,
  ) => _typed(query);
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(
    SearchQuery query,
  ) => _typed(query);
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(
    SearchQuery query,
  ) => _typed(query);
}

int _int(dynamic v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
int? _nullableInt(dynamic v) => v == null ? null : _int(v);
double? _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
SearchErrorCode? _errorCode(String? value) {
  if (value == null) return null;
  for (final code in SearchErrorCode.values) {
    if (code.value == value) return code;
  }
  return SearchErrorCode.serverError;
}

FriendlyResponseCategory? _specialCategory(String? value) {
  if (value == null) return null;
  for (final category in FriendlyResponseCategory.values) {
    if (category.name.toLowerCase() == value.toLowerCase()) return category;
  }
  return null;
}
