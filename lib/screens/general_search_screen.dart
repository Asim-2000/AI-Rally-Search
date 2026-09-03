import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/conversational_search_session.dart';
import '../models/entity_candidate.dart';
import '../models/pending_clarification.dart';
import '../models/result_referent_context.dart';
import '../models/search_intent.dart';
import '../models/search_query.dart';
import '../models/search_results.dart';
import '../models/supported_language.dart';
import '../models/video_action.dart';
import '../models/speech/speech_transcription_result.dart';
import '../services/llm/follow_up_suggestion_engine.dart';
import '../services/llm/llm_query_parser.dart';
import '../services/llm/natural_language_search_service.dart';
import '../services/llm/query_output_validator.dart';
import '../services/search_repository.dart';
import '../services/python_search_api_client.dart';
import '../services/friendly_response_service.dart';
import '../services/offline/offline_messaging.dart';
import '../services/offline/offline_search_engine.dart';
import '../services/latency/latency_policy.dart';
import '../services/latency/search_latency_coordinator.dart';
import '../services/latency/search_telemetry.dart';
import '../services/offline/offline_snapshot_sync.dart';
import '../widgets/offline_banner.dart';
import '../widgets/action_player_modal.dart';
import '../widgets/active_context_chips_bar.dart';
import '../widgets/advanced_filters_sheet.dart';
import '../widgets/clarification_card.dart';
import '../widgets/driver_participation_card.dart';
import '../widgets/driver_wins_leaderboard.dart';
import '../widgets/rally_leaderboard.dart';
import '../widgets/rally_result_card.dart';
import '../widgets/suggested_follow_ups_bar.dart';
import '../widgets/uploader_leaderboard.dart';
import '../widgets/video_action_card.dart';
import '../widgets/video_result_card.dart';
import '../widgets/voice_search_button.dart';
import '../services/speech/speech_to_text_service.dart';
import '../services/speech/speech_service_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/results_skeleton.dart';

/// Rally-toned loading copy for a search whose intent is not yet known.
const String _kCheckingTimingSheets = 'Checking the timing sheets...';

/// One completed authoritative online turn, held so it can be applied now or
/// offered for later promotion without re-issuing the request.
class _OnlineTurn {
  final NaturalLanguageSearchResult result;
  final SearchConversationSession? session;

  /// The generation the backend echoed back, when it echoes one.
  final int? echoedRequestId;
  final int? networkRoundtripMs;
  final String? transcript;

  const _OnlineTurn({
    required this.result,
    this.session,
    this.echoedRequestId,
    this.networkRoundtripMs,
    this.transcript,
  });
}

/// User-facing category of a results-area failure. Presentation only — the
/// underlying exception/state is unchanged; this only selects friendly copy.
enum _SearchErrorKind {
  /// Backend/network could not be reached.
  service,

  /// The query could not be understood / turned into a search.
  understanding,
}

/// Phase 5E Continuous Conversational Search Screen.
///
/// Features:
/// - Single prominent continuous search field supporting typed queries, voice transcripts,
///   follow-ups, and refinements.
/// - Active search context visible as compact, multi-value chips below search bar.
/// - Clear distinction between inherited conversational context and current turn refinements.
/// - Separate [ResultReferentContext] tracking database-derived referents (winners, rallies, drivers).
/// - Inline disambiguation & clarification UI preserving resolved context.
/// - Deterministic interpretation feedback and follow-up suggestion chips.
/// - Advanced manual filters available via modal bottom sheet, synchronized bi-directionally.
class GeneralSearchScreen extends StatefulWidget {
  final SearchQuery? initialQuery;
  final ISearchRepository? repository;
  final NaturalLanguageSearchService? nlSearchService;
  final LlmQueryParser? llmParser;
  final ISpeechToTextService? speechService;
  final ISpeechToTextService? nativeSpeechService;
  final ISpeechToTextService? cloudSpeechService;
  final PythonSearchApiClient? pythonApiClient;

  /// Offline search stack (optional). When supplied (production, via main.dart),
  /// the screen applies NETWORK_FIRST_WITH_LOCAL_FALLBACK and offline messaging.
  /// When null (most tests), behaviour is exactly the online-only path.
  final OfflineSearchEngine? offlineEngine;
  final OfflineSnapshotSync? offlineSync;
  final ConnectivityProbe? connectivityProbe;

  /// The single latency/fallback policy. Tests inject short budgets; there is
  /// no second place in the app where these numbers are defined.
  final LatencyPolicy latencyPolicy;

  /// Optional sink for client latency records. Defaults to discarding them, so
  /// instrumentation costs nothing unless deliberately enabled.
  final SearchTelemetrySink? telemetrySink;

  const GeneralSearchScreen({
    super.key,
    this.initialQuery,
    this.repository,
    this.nlSearchService,
    this.llmParser,
    this.speechService,
    this.nativeSpeechService,
    this.cloudSpeechService,
    this.pythonApiClient,
    this.offlineEngine,
    this.offlineSync,
    this.connectivityProbe,
    this.latencyPolicy = LatencyPolicy.standard,
    this.telemetrySink,
  });

  @override
  State<GeneralSearchScreen> createState() => _GeneralSearchScreenState();
}

class _GeneralSearchScreenState extends State<GeneralSearchScreen> {
  // Python FastAPI is authoritative. `_repository` is a Python-backed
  // repository in production, or a caller-injected fake in tests; it is null
  // only when the backend is unconfigured (a clean error is shown then).
  late final ISearchRepository? _repository;
  // Legacy in-app NL search is retained ONLY as a test seam and is never
  // constructed in production.
  late final NaturalLanguageSearchService? _nlSearchService;
  late final ISpeechToTextService _nativeSpeechService;
  late final ISpeechToTextService _cloudSpeechService;
  PythonSearchApiClient? _pythonApiClient;
  late final bool _usePythonBackend;

  // Selected language for speech and query understanding
  SupportedLanguage _selectedLanguage = SupportedLanguages.defaultLanguage;

  // Single continuous search field controller
  final TextEditingController _searchController = TextEditingController();

  // Dual STT tracking state for user testing and edit-detection
  String? _sttSource; // 'NATIVE' or 'CLOUD'
  String? _sttProvider; // 'OS_NATIVE' or 'OPENAI'
  String? _sttModel;
  double? _sttLatencyMs;
  String? _sttRawTranscript;
  int _voiceGeneration = 0;
  Map<String, dynamic>? _lastVoiceTelemetry;

  Map<String, dynamic>? get lastVoiceTelemetry => _lastVoiceTelemetry;
  String? get currentSttSource => _sttSource;

  // Core Conversational Search Session
  SearchConversationSession _session = SearchConversationSession.initial;

  // Search & Clarification state
  String? _clarificationQuestion;
  List<EntityCandidate> _clarificationCandidates = [];
  PendingClarification? _pendingClarification;
  NaturalLanguageSearchResult? _lastNlResult;

  // Pagination state
  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;

  // Whether the user has run at least one search this session. Until then the
  // screen shows the first-launch hero (title + examples) instead of results.
  // No backend search is performed automatically on launch.
  bool _hasSearched = false;

  bool _isLoading = false;
  String _loadingStatus = 'Searching…';
  String? _errorMessage;
  _SearchErrorKind _errorKind = _SearchErrorKind.service;
  String? _specialMessage;
  String? _emptyResultsMessage;
  SearchResponse<dynamic>? _searchResponse;

  // Offline / connectivity state.
  OfflineSearchEngine? _offlineEngine;
  OfflineSnapshotSync? _offlineSync;
  ConnectivityProbe? _connectivityProbe;
  OfflineUxState _offlineState = OfflineUxState.online;
  Duration? _offlineAge;
  late final SearchLatencyCoordinator<_OnlineTurn> _coordinator;
  late final SearchTelemetrySink _telemetrySink;
  StreamSubscription<SearchEvent<_OnlineTurn>>? _searchSubscription;

  /// A late authoritative result waiting behind an explicit "show latest"
  /// action. Held, never applied on its own.
  _OnlineTurn? _pendingOnlineTurn;
  String? _pendingOnlineQueryText;
  int? _pendingOnlineGeneration;
  bool get _hasPendingOnlineResult => _pendingOnlineTurn != null;
  bool get _offlineActive => _offlineState != OfflineUxState.online;
  static const OfflineMessagingService _offlineMessaging = OfflineMessagingService();

  @override
  void initState() {
    super.initState();
    _offlineEngine = widget.offlineEngine;
    _offlineSync = widget.offlineSync;
    _connectivityProbe = widget.connectivityProbe;
    _telemetrySink = widget.telemetrySink ?? const NullSearchTelemetrySink();
    _coordinator = SearchLatencyCoordinator<_OnlineTurn>(
      connectivity: _connectivityProbe,
      engine: _offlineEngine,
      policy: widget.latencyPolicy,
    );
    final backendConfig = SearchBackendConfig.fromEnvironment();
    // Python FastAPI is the sole authoritative search backend. There is no
    // runtime legacy switch and no silent in-app Dart fallback: when the Python
    // backend is unreachable/unconfigured the UI shows a clean error instead of
    // executing the legacy engine.
    _pythonApiClient = widget.pythonApiClient ?? backendConfig.tryCreateClient();
    _usePythonBackend = _pythonApiClient != null;
    _repository =
        widget.repository ??
        (_pythonApiClient != null
            ? PythonSearchRepository(_pythonApiClient!)
            : null);
    // Legacy in-app NL search is a test-only seam; production is Python-only.
    _nlSearchService = widget.nlSearchService;
    _nativeSpeechService = widget.nativeSpeechService ??
        widget.speechService ??
        SpeechServiceFactory.createNative();
    _cloudSpeechService = widget.cloudSpeechService ??
        SpeechServiceFactory.createCloud(pythonApiClient: _pythonApiClient);

    _searchController.addListener(_onSearchControllerChanged);

    // Search-first: do NOT auto-search on launch. Only run an initial search
    // when an explicit initialQuery is supplied (e.g. deep link / test seam);
    // otherwise the first-launch hero is shown until the user searches.
    if (widget.initialQuery != null) {
      _session = _session.copyWith(activeQuery: widget.initialQuery!);
      _executeDeterministicSearch(resetPage: true);
    }
  }

  void _onSearchControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Stops delivery of any in-flight search event. The online request itself
    // is left to complete rather than being torn down mid-flight; its result
    // is simply never applied.
    _searchSubscription?.cancel();
    _searchSubscription = null;
    _discardPendingOnline();
    _searchController.removeListener(_onSearchControllerChanged);
    _nativeSpeechService.dispose();
    _cloudSpeechService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleVoiceTranscriptReceived({
    required String transcript,
    required String source,
    required int generation,
    SpeechTranscriptionResult? detailed,
  }) {
    if (generation != _voiceGeneration) {
      // Stale transcript from previous voice turn -> discard
      return;
    }
    setState(() {
      _sttSource = source;
      _sttProvider = detailed?.provider ??
          (source == 'NATIVE' ? 'OS_NATIVE' : 'OPENAI');
      _sttModel = detailed?.model ??
          (source == 'NATIVE' ? 'NATIVE_DEVICE_STT' : 'gpt-transcribe');
      _sttLatencyMs = detailed?.latencyMs;
      _sttRawTranscript = transcript;
      _searchController.value = TextEditingValue(
        text: transcript,
        selection: TextSelection.collapsed(
          offset: transcript.length,
        ),
      );
    });
    // This screen submits the editable transcript as typed text, so it never
    // forwards captured audio to a downstream search request.
    detailed?.disposeAudio();
  }

  // ===========================================================================
  // CONTINUOUS CONVERSATIONAL SEARCH EXECUTION
  // ===========================================================================

  Future<void> _executeNaturalLanguageSearch({
    SpeechTranscriptionResult? spokenResult,
  }) async {
    final queryText = (spokenResult?.text ?? _searchController.text).trim();
    if (queryText.isEmpty &&
        !(_usePythonBackend && spokenResult?.audioContext != null)) {
      return;
    }

    final requestSession = _session;
    final nextRequestId = _session.activeRequestId + 1;
    // Opaque correlation id, sent as X-Request-Id and echoed by the backend
    // into its structured timing line. Never contains query text.
    final traceId = newRequestId();
    if (_sttSource != null) {
      final wasEdited = _sttRawTranscript != null &&
          _sttRawTranscript!.trim().toLowerCase() != queryText.toLowerCase();
      _lastVoiceTelemetry = {
        'sttMethod': _sttSource,
        'sttProvider': _sttProvider,
        'sttModel': _sttModel,
        'locale': _selectedLanguage.localeCode,
        'transcriptionLatencyMs': _sttLatencyMs,
        'rawTranscript': _sttRawTranscript,
        'submittedTranscript': queryText,
        'wasEditedBeforeSubmit': wasEdited,
      };
    }

    // Dropping any offer from the previous search before the new one starts is
    // what stops a stale "show latest" from promoting a result belonging to an
    // abandoned query.
    _discardPendingOnline();
    setState(() {
      if (queryText.isNotEmpty) _searchController.text = queryText;
      _hasSearched = true;
      _session = _session.copyWith(activeRequestId: nextRequestId);
      _isLoading = true;
      _loadingStatus = _kCheckingTimingSheets;
      _errorMessage = null;
      _specialMessage = null;
      _emptyResultsMessage = null;
      _clarificationQuestion = null;
      _clarificationCandidates = [];
      _pendingClarification = null;
      _currentPage = 1;
    });

    final dispatchedAt = clock.now();

    // The authoritative online turn. Whichever transport applies, the
    // coordinator sees one future; it is started immediately and is never
    // cancelled by a fallback.
    Future<_OnlineTurn> runOnline() async {
      final searchContext = SearchContext(
        currentYear: DateTime.now().year,
        locale: _selectedLanguage.localeCode,
        languageCode: _selectedLanguage.languageCode,
        referents: requestSession.referents,
        previousQuery: requestSession.activeQuery,
      );

      if (_pythonApiClient != null && spokenResult?.audioContext != null) {
        final audio = spokenResult!.audioContext!;
        final response = await _pythonApiClient!.voice(
          audioBytes: audio.bytes,
          filename: 'query.${audio.format}',
          session: requestSession,
          language: _selectedLanguage.languageCode,
          requestId: nextRequestId,
          editedTranscript: queryText.isEmpty ? null : queryText,
          traceId: traceId,
        );
        return _OnlineTurn(
          result: response.result,
          session: response.session,
          echoedRequestId: response.requestId,
          networkRoundtripMs: response.networkRoundtripMs,
          transcript: response.transcription?.text.trim(),
        );
      }
      if (_pythonApiClient != null) {
        final response = await _pythonApiClient!.conversation(
          query: queryText,
          session: requestSession,
          language: _selectedLanguage.languageCode,
          requestId: nextRequestId,
          traceId: traceId,
        );
        return _OnlineTurn(
          result: response.result,
          session: response.session,
          echoedRequestId: response.requestId,
          networkRoundtripMs: response.networkRoundtripMs,
        );
      }
      if (_nlSearchService != null) {
        // Test-only injected in-app search path.
        final result = spokenResult != null
            ? await _nlSearchService.searchSpoken(
                spokenResult,
                context: searchContext,
              )
            : await _nlSearchService.search(queryText, context: searchContext);
        return _OnlineTurn(result: result);
      }
      // No backend configured: surface a clean error instead of any legacy
      // fallback.
      throw const PythonApiException(
        'config',
        'Search backend is not configured (PYTHON_BACKEND_BASE_URL missing).',
      );
    }

    // Detach from the previous search without awaiting: cancelling is only
    // about stopping delivery, and awaiting it would delay dispatching the new
    // query behind the old one's teardown. The generation guard, not the
    // cancel, is what keeps a stale event from being applied.
    unawaited(_searchSubscription?.cancel() ?? Future<void>.value());
    _searchSubscription = _coordinator
        .run(
          generation: nextRequestId,
          rawText: queryText,
          online: runOnline,
          limit: _pageSize,
        )
        .listen(
          (event) => unawaited(
            _handleSearchEvent(
              event: event,
              queryText: queryText,
              traceId: traceId,
              dispatchedAt: dispatchedAt,
            ),
          ),
          onDone: () {
            if (_usePythonBackend && spokenResult?.audioContext != null) {
              spokenResult!.disposeAudio();
            }
          },
        );
  }

  /// Applies one coordinator event.
  ///
  /// Two guards run before anything is rendered: the widget must still be
  /// mounted, and the event's generation must still be the active one. Between
  /// them they cover a disposed screen and a superseded query — a late result
  /// for query A can never overwrite query B.
  Future<void> _handleSearchEvent({
    required SearchEvent<_OnlineTurn> event,
    required String queryText,
    required String traceId,
    required DateTime dispatchedAt,
  }) async {
    if (!mounted || _session.activeRequestId != event.generation) return;
    final connectivity = event.connectivity;

    switch (event.stage) {
      case SearchStage.online:
        await _applyOnlineTurn(event.online!, queryText, event.generation);
        _recordSearchTelemetry(
          traceId: traceId,
          dispatchedAt: dispatchedAt,
          connectivity: connectivity,
          source: SearchResultSource.online,
          networkRoundtripMs: event.online!.networkRoundtripMs,
          timeToFirstResultMs: event.elapsedMs,
        );

      case SearchStage.offlineImmediate:
        _renderOfflineOutcome(
          event.offline!,
          OfflineUxState.offlineLocalResults,
          event.generation,
        );
        _recordSearchTelemetry(
          traceId: traceId,
          dispatchedAt: dispatchedAt,
          connectivity: connectivity,
          source: SearchResultSource.offline,
          localParserCouldAnswer: true,
          timeToFirstResultMs: event.elapsedMs,
        );

      case SearchStage.offlineFallback:
        _renderOfflineOutcome(
          event.offline!,
          OfflineUxState.lowBandwidthLocalFallback,
          event.generation,
        );
        _recordSearchTelemetry(
          traceId: traceId,
          dispatchedAt: dispatchedAt,
          connectivity: connectivity,
          source: SearchResultSource.offlineFallback,
          localParserCouldAnswer: true,
          fallbackTriggerMs: event.elapsedMs,
          timeToFirstResultMs: event.elapsedMs,
        );

      case SearchStage.offlineAfterOnlineFailure:
        _renderOfflineOutcome(
          event.offline!,
          OfflineUxState.backendUnreachableLocalAvailable,
          event.generation,
        );
        _recordSearchTelemetry(
          traceId: traceId,
          dispatchedAt: dispatchedAt,
          connectivity: connectivity,
          source: SearchResultSource.offlineFallback,
          localParserCouldAnswer: true,
          fallbackTriggerMs: event.elapsedMs,
          timeToFirstResultMs: event.elapsedMs,
        );

      case SearchStage.lateOnlineAvailable:
        final turn = event.online!;
        if (!_isOfferableOnlineTurn(turn)) {
          // The request completed, but with an error rather than an answer.
          // Offering "fresh results" that are actually a failure would be a
          // worse trade than the saved data already on screen, so this is
          // treated exactly like a late failure.
          setState(() {
            _pendingOnlineTurn = null;
            _offlineState = OfflineUxState.backendUnreachableLocalAvailable;
          });
          return;
        }
        // The authoritative answer is ready, but saved data is on screen.
        // Offer it; never swap it in.
        setState(() {
          _pendingOnlineTurn = turn;
          _pendingOnlineQueryText = queryText;
          _pendingOnlineGeneration = event.generation;
        });

      case SearchStage.lateOnlineFailed:
        // Local data stays exactly as it is; only the label changes.
        setState(() {
          _pendingOnlineTurn = null;
          _offlineState = OfflineUxState.backendUnreachableLocalAvailable;
        });

      case SearchStage.onlineFailed:
        await _renderSearchFailure(event.error, connectivity, event.generation);
        _recordSearchTelemetry(
          traceId: traceId,
          dispatchedAt: dispatchedAt,
          connectivity: connectivity,
          source: SearchResultSource.online,
        );
    }
  }

  /// Promotes the offered authoritative result. Only ever reached by an
  /// explicit user tap on "show latest".
  Future<void> _showLatestOnlineResult() async {
    final turn = _pendingOnlineTurn;
    final queryText = _pendingOnlineQueryText;
    final generation = _pendingOnlineGeneration;
    // Clearing first makes repeated taps idempotent: the second tap finds no
    // pending turn and does nothing.
    _discardPendingOnline();
    if (turn == null || queryText == null || generation == null) return;
    if (!mounted || _session.activeRequestId != generation) return;
    setState(() {
      _offlineState = OfflineUxState.online;
      _offlineAge = null;
    });
    await _applyOnlineTurn(turn, queryText, generation);
  }

  /// Whether a late online turn is worth offering in place of saved data.
  ///
  /// A clarification or a special response is a real authoritative outcome and
  /// is offered; a parse or backend error is not.
  static bool _isOfferableOnlineTurn(_OnlineTurn turn) {
    final result = turn.result;
    if (result.isSpecialResponse || result.requiresClarification) return true;
    return result.isSuccess && result.query != null;
  }

  void _discardPendingOnline() {
    _pendingOnlineTurn = null;
    _pendingOnlineQueryText = null;
    _pendingOnlineGeneration = null;
  }

  void _recordSearchTelemetry({
    required String traceId,
    required DateTime dispatchedAt,
    required ConnectivityState connectivity,
    required SearchResultSource source,
    int? networkRoundtripMs,
    int? timeToFirstResultMs,
    int? fallbackTriggerMs,
    bool localParserCouldAnswer = false,
  }) {
    _telemetrySink.record(
      SearchTelemetry(
        requestId: traceId,
        totalClientMs: clock.now().difference(dispatchedAt).inMilliseconds,
        resultSource: source,
        connectivity: connectivity,
        fallbackTriggered: fallbackTriggerMs != null,
        fallbackTriggerMs: fallbackTriggerMs,
        networkRoundtripMs: networkRoundtripMs,
        timeToFirstResultMs: timeToFirstResultMs,
        localParserCouldAnswer: localParserCouldAnswer,
        lateOnlineOffered: _pendingOnlineTurn != null,
      ),
    );
  }

  Future<void> _renderSearchFailure(
    Object? error,
    ConnectivityState connectivity,
    int generation,
  ) async {
    // A plainly-offline device with no snapshot is a different product state
    // from a backend failure, and gets its own "sync now" affordance.
    if (connectivity == ConnectivityState.offline && _offlineEngine != null) {
      var hasSnapshot = false;
      try {
        hasSnapshot = await _offlineEngine!.database.hasSnapshot();
      } catch (_) {
        hasSnapshot = false;
      }
      if (!mounted || _session.activeRequestId != generation) return;
      if (!hasSnapshot) {
        setState(() {
          _isLoading = false;
          _searchResponse = null;
          _totalCount = 0;
          _errorMessage = null;
          _offlineState = OfflineUxState.noLocalSnapshot;
          _offlineAge = null;
        });
        return;
      }
    }
    if (!mounted || _session.activeRequestId != generation) return;
    setState(() {
      _errorKind = _SearchErrorKind.service;
      _errorMessage = error is PythonApiException
          ? error.friendlyMessage
          : const FriendlyResponseService().responseFor(
              FriendlyResponseCategory.serverError,
            );
      _clarificationCandidates = [];
      _isLoading = false;
    });
  }

  /// Renders one authoritative online turn onto shared result state.
  ///
  /// Shared by the in-budget path and by "show latest", so a promoted late
  /// result is applied through exactly the same code as a fast one.
  Future<void> _applyOnlineTurn(
    _OnlineTurn turn,
    String queryText,
    int generation,
  ) async {
    final result = turn.result;
    final backendSession = turn.session;
    if (turn.echoedRequestId != null && turn.echoedRequestId != generation) {
      return;
    }
    if (!mounted || _session.activeRequestId != generation) return;
    if (turn.transcript != null && turn.transcript!.isNotEmpty) {
      _searchController.text = turn.transcript!;
    }

    if (result.isSpecialResponse) {
      // Easter-egg / personality response: show only the playful message.
      // No DB results, no zero-results state, no clarification, no stale
      // pagination. The rally conversation context (referents/active query)
      // from any prior search is intentionally preserved.
      setState(() {
        if (backendSession != null) _session = backendSession;
        _isLoading = false;
        _specialMessage = result.friendlyMessage;
        _searchResponse = null;
        _totalCount = 0;
        _clarificationQuestion = null;
        _clarificationCandidates = [];
        _pendingClarification = null;
        _errorMessage = null;
        _emptyResultsMessage = null;
        _offlineState = OfflineUxState.online;
        _offlineAge = null;
      });
      return;
    }

    if (result.requiresClarification) {
      setState(() {
        if (backendSession != null) _session = backendSession;
        _isLoading = false;
        _clarificationQuestion = result.clarificationQuestion;
        _clarificationCandidates = result.candidates;
        final pendingQuery = result.parsedQuery ?? result.query;
        _pendingClarification = pendingQuery == null
            ? null
            : PendingClarification(
                query: pendingQuery,
                referents: result.referents,
                requestId: generation,
              );
        _offlineState = OfflineUxState.online;
        _offlineAge = null;
      });
      return;
    }

    if (!result.isSuccess || result.query == null) {
      setState(() {
        if (backendSession != null) _session = backendSession;
        _isLoading = false;
        _errorKind = _SearchErrorKind.understanding;
        _errorMessage = result.friendlyMessage ?? 'Query parsing failed';
        _clarificationCandidates = [];
        _offlineState = OfflineUxState.online;
        _offlineAge = null;
      });
      return;
    }

    final parsedQuery = result.query!;
    final l10n = AppLocalizations.of(context);
    final localizedSummary = _buildLocalizedInterpretedSummary(
      parsedQuery,
      l10n,
    );

    // Determine which fields were inherited vs refined in this turn
    final inherited = <String>{};
    final refinements = <String>{};

    if (parsedQuery.rallyNames.isNotEmpty) {
      if (_session.activeQuery.rallyNames.isNotEmpty &&
          _session.activeQuery.rallyNames.first ==
              parsedQuery.rallyNames.first) {
        inherited.add('rally');
      } else {
        refinements.add('rally');
      }
    }
    if (parsedQuery.driverNames.isNotEmpty) {
      if (_session.activeQuery.driverNames.isNotEmpty &&
          _session.activeQuery.driverNames.first ==
              parsedQuery.driverNames.first) {
        inherited.add('driver');
      } else {
        refinements.add('driver');
      }
    }
    if (parsedQuery.actionTypes.isNotEmpty) {
      refinements.add('action');
    }
    if (parsedQuery.countries.isNotEmpty) {
      if (_session.activeQuery.countries.isNotEmpty &&
          _session.activeQuery.countries.first == parsedQuery.countries.first) {
        inherited.add('country');
      } else {
        refinements.add('country');
      }
    }
    if (parsedQuery.years.isNotEmpty) {
      if (_session.activeQuery.years.isNotEmpty &&
          _session.activeQuery.years.first == parsedQuery.years.first) {
        inherited.add('year');
      } else {
        refinements.add('year');
      }
    }

    final updatedSession =
        backendSession ??
        _session.recordTurn(
          query: parsedQuery,
          referents: result.referents,
          title: queryText,
          response: result.searchResponse,
          interpretedSummary: localizedSummary,
          inherited: inherited,
          refinements: refinements,
        );

    setState(() {
      _session = updatedSession;
      _searchResponse = result.searchResponse;
      _totalCount = result.totalCount;
      _lastNlResult = result;
      _clarificationQuestion = null;
      _clarificationCandidates = [];
      _pendingClarification = null;
      _errorMessage = null;
      _specialMessage = null;
      _emptyResultsMessage = result.friendlyMessage;
      _isLoading = false;
      // Authoritative online answer: clear any offline chrome.
      _offlineState = OfflineUxState.online;
      _offlineAge = null;
    });
    // Opportunistic, non-blocking refresh of the offline snapshot.
    unawaited(_offlineSync?.maybeSync() ?? Future.value());
  }
  Future<void> _executeDeterministicSearch({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }

    final nextRequestId = _session.activeRequestId + 1;
    setState(() {
      _hasSearched = true;
      _session = _session.copyWith(activeRequestId: nextRequestId);
      _isLoading = true;
      _loadingStatus = _loadingCopyForIntent(_session.activeQuery.intent);
      _errorMessage = null;
      _specialMessage = null;
      _emptyResultsMessage = null;
    });

    // Offline / low-bandwidth: execute the resolved query over the local
    // snapshot (pagination and clarification selections included).
    if (_offlineEngine != null && (_offlineActive || await _isPlainlyOffline())) {
      await _executeDeterministicOffline(nextRequestId);
      return;
    }

    final repository = _repository;
    if (repository == null) {
      if (!mounted || _session.activeRequestId != nextRequestId) return;
      setState(() {
        _errorKind = _SearchErrorKind.service;
        _errorMessage = const FriendlyResponseService().responseFor(
          FriendlyResponseCategory.serverError,
        );
        _isLoading = false;
      });
      return;
    }

    try {
      final offset = (_currentPage - 1) * _pageSize;
      final queryToExecute = _session.activeQuery.copyWith(
        limit: _pageSize,
        offset: offset,
      );

      final response = await repository.search(queryToExecute);

      if (!mounted || _session.activeRequestId != nextRequestId) return;

      // Authoritative online answer: drop any offline chrome.
      _offlineState = OfflineUxState.online;
      _offlineAge = null;

      final updatedReferents = ResultReferentContext.fromSearchResponse(
        response,
        previous: _session.referents,
        queryRally: queryToExecute.targetRallyName,
        queryDriver: queryToExecute.driverName,
        queryRallies: queryToExecute.targetRallyNames,
        queryDrivers: queryToExecute.driverNames,
      );

      setState(() {
        _session = _session.copyWith(
          activeQuery: queryToExecute,
          referents: updatedReferents,
        );
        _searchResponse = response;
        _totalCount = response.totalCount;
        _emptyResultsMessage = response.totalCount == 0
            ? const FriendlyResponseService().responseFor(
                FriendlyResponseCategory.noResults,
              )
            : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || _session.activeRequestId != nextRequestId) return;
      setState(() {
        _errorKind = _SearchErrorKind.service;
        _errorMessage = const FriendlyResponseService().responseFor(
          FriendlyResponseCategory.serverError,
        );
        _isLoading = false;
      });
    }
  }

  // ===========================================================================
  // OFFLINE FALLBACK
  // ===========================================================================

  /// Connectivity for the deterministic (pagination / clarification) path.
  /// Reads through the coordinator so the whole screen has one notion of
  /// "known offline" rather than two probes that can disagree.
  Future<bool> _isPlainlyOffline() async =>
      await _coordinator.observedConnectivity() == ConnectivityState.offline;

  Future<Duration?> _snapshotAge() async {
    final last = await _offlineEngine?.database.lastSyncUtc();
    if (last == null) return null;
    return DateTime.now().toUtc().difference(last);
  }

  /// A snapshot older than this is still used, but is labelled with its age.
  /// The value comes from the single latency policy.
  Duration get _staleThreshold => widget.latencyPolicy.snapshotStaleAfter;

  /// Maps an offline outcome the coordinator already computed onto the shared
  /// result / clarification / special / error state, plus the product-tone
  /// offline banner state.
  ///
  /// Render-only: the offline pipeline is executed once, by the coordinator,
  /// so a fallback never re-runs the local search just to display it.
  Future<void> _renderOfflineOutcome(
    OfflineSearchOutcome outcome,
    OfflineUxState baseState,
    int generation,
  ) async {
    final age = await _snapshotAge();
    if (!mounted || _session.activeRequestId != generation) return;
    setState(() {
      _isLoading = false;
      _hasSearched = true;
      _clarificationQuestion = null;
      _clarificationCandidates = [];
      _pendingClarification = null;
      _errorMessage = null;
      _specialMessage = null;
      _emptyResultsMessage = null;
      _searchResponse = null;
      _totalCount = 0;
      _offlineAge = age;
      switch (outcome.kind) {
        case OfflineOutcomeKind.results:
          _session = _session.copyWith(activeQuery: outcome.query!);
          _searchResponse = outcome.response;
          _totalCount = outcome.response!.totalCount;
          final stale = age != null && age > _staleThreshold;
          _offlineState = stale ? OfflineUxState.offlineStaleResults : baseState;
          if (_totalCount == 0) {
            _offlineState = OfflineUxState.offlineSafeNoMatch;
            _emptyResultsMessage =
                const FriendlyResponseService().responseFor(FriendlyResponseCategory.noResults);
          }
          break;
        case OfflineOutcomeKind.clarification:
          _offlineState = OfflineUxState.offlineAmbiguity;
          _clarificationQuestion = outcome.clarificationQuestion;
          _clarificationCandidates = outcome.candidates;
          _pendingClarification = PendingClarification(
            query: SearchQuery(intent: outcome.intent ?? SearchIntent.searchRallies),
            referents: _session.referents,
            requestId: _session.activeRequestId,
          );
          break;
        case OfflineOutcomeKind.special:
          _offlineState = baseState;
          _specialMessage =
              const FriendlyResponseService().responseFor(outcome.specialCategory!);
          break;
        case OfflineOutcomeKind.noMatch:
          _offlineState = OfflineUxState.offlineSafeNoMatch;
          _emptyResultsMessage =
              const FriendlyResponseService().responseFor(FriendlyResponseCategory.noResults);
          break;
        case OfflineOutcomeKind.unsupported:
          _offlineState = OfflineUxState.offlineQueryUnsupported;
          _errorKind = _SearchErrorKind.service;
          _errorMessage =
              _offlineMessaging.messageFor(OfflineUxState.offlineQueryUnsupported).explanation;
          break;
      }
    });
  }

  /// Offline execution of an already-resolved active query (pagination / a
  /// chosen clarification candidate).
  Future<void> _executeDeterministicOffline(int requestId) async {
    final engine = _offlineEngine;
    if (engine == null) return;
    if (!await engine.database.hasSnapshot()) {
      if (!mounted || _session.activeRequestId != requestId) return;
      setState(() {
        _isLoading = false;
        _offlineState = OfflineUxState.noLocalSnapshot;
      });
      return;
    }
    final age = await _snapshotAge();
    final offset = (_currentPage - 1) * _pageSize;
    final queryToExecute = _session.activeQuery.copyWith(limit: _pageSize, offset: offset);
    SearchResponse<dynamic> response;
    try {
      response = await engine.execute(queryToExecute);
    } catch (_) {
      if (!mounted || _session.activeRequestId != requestId) return;
      setState(() {
        _isLoading = false;
        _offlineState = OfflineUxState.offlineSafeNoMatch;
        _emptyResultsMessage =
            const FriendlyResponseService().responseFor(FriendlyResponseCategory.noResults);
      });
      return;
    }
    if (!mounted || _session.activeRequestId != requestId) return;
    final updatedReferents = ResultReferentContext.fromSearchResponse(
      response,
      previous: _session.referents,
      queryRally: queryToExecute.targetRallyName,
      queryDriver: queryToExecute.driverName,
      queryRallies: queryToExecute.targetRallyNames,
      queryDrivers: queryToExecute.driverNames,
    );
    final stale = age != null && age > _staleThreshold;
    setState(() {
      _session = _session.copyWith(activeQuery: queryToExecute, referents: updatedReferents);
      _searchResponse = response;
      _totalCount = response.totalCount;
      _offlineAge = age;
      _offlineState = stale ? OfflineUxState.offlineStaleResults : OfflineUxState.offlineLocalResults;
      _emptyResultsMessage = response.totalCount == 0
          ? const FriendlyResponseService().responseFor(FriendlyResponseCategory.noResults)
          : null;
      _isLoading = false;
    });
  }

  /// Video discovery works offline; playback is gated (network-only).
  void _showPlaybackGated(BuildContext context) {
    final msg = _offlineMessaging.messageFor(OfflineUxState.videoPlaybackUnavailable);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${msg.headline} ${msg.explanation}'), duration: const Duration(seconds: 3)),
    );
  }

  /// Contextual, non-technical loading copy derived from the (known) intent of
  /// a deterministic search. Never exposes pipeline internals.
  String _loadingCopyForIntent(SearchIntent intent) {
    switch (intent) {
      case SearchIntent.searchRallies:
        return 'Searching rallies…';
      case SearchIntent.searchDriverRallies:
      case SearchIntent.searchDriverWins:
        return 'Finding rally participations…';
      case SearchIntent.getRallyResults:
      case SearchIntent.getRallyTopFinishers:
        return 'Loading results…';
      case SearchIntent.searchVideoActions:
        return 'Finding highlights…';
      case SearchIntent.searchDriverVideos:
        return 'Finding videos…';
      case SearchIntent.getTopUploaders:
        return 'Ranking uploaders…';
      case SearchIntent.getTopDriversByWins:
        return 'Ranking drivers…';
    }
  }

  void _handleRemoveFilter(String field, dynamic value) {
    setState(() {
      _session = _session.removeFilter(field: field, value: value);
    });
    _executeDeterministicSearch(resetPage: true);
  }

  void _handleRollbackHistory(int historyIndex) {
    setState(() {
      _session = _session.rollbackTo(historyIndex);
    });
    _executeDeterministicSearch(resetPage: true);
  }

  void _handleClearAll() {
    unawaited(_nativeSpeechService.cancelListening());
    unawaited(_cloudSpeechService.cancelListening());
    setState(() {
      _searchController.clear();
      _sttSource = null;
      _sttRawTranscript = null;
      _voiceGeneration++;
      _session = _session.clearAll();
      _clarificationQuestion = null;
      _clarificationCandidates = [];
      _pendingClarification = null;
      _lastNlResult = null;
    });
    _executeDeterministicSearch(resetPage: true);
  }

  void _onSelectCandidate(EntityCandidate candidate) {
    final selection = _pendingClarification?.select(
      candidate,
      currentRequestId: _session.activeRequestId,
    );
    if (selection == null) return;
    setState(() {
      _clarificationQuestion = null;
      _clarificationCandidates = [];
      _pendingClarification = null;
      _session = _session.copyWith(
        activeQuery: selection.query,
        referents: selection.referents,
      );
    });
    _executeDeterministicSearch(resetPage: true);
  }

  IconData _getCandidateIcon(EntityType type) {
    switch (type) {
      case EntityType.driver:
        return Icons.person_rounded;
      case EntityType.rally:
        return Icons.flag_rounded;
      case EntityType.stage:
        return Icons.alt_route_rounded;
      case EntityType.city:
        return Icons.location_city_rounded;
      case EntityType.uploader:
        return Icons.cloud_upload_rounded;
    }
  }

  void _handleSuggestionSelected(FollowUpSuggestion suggestion) {
    if (suggestion.targetQuery != null) {
      setState(() {
        _session = _session.copyWith(activeQuery: suggestion.targetQuery!);
      });
      _executeDeterministicSearch(resetPage: true);
    } else if (suggestion.queryText != null) {
      _searchController.text = suggestion.queryText!;
      _executeNaturalLanguageSearch();
    }
  }

  void _openAdvancedFilters() {
    AdvancedFiltersSheet.show(
      context,
      session: _session,
      onApply: (updatedQuery) {
        setState(() {
          _session = _session.copyWith(activeQuery: updatedQuery);
        });
        _executeDeterministicSearch(resetPage: true);
      },
    );
  }

  String _buildLocalizedInterpretedSummary(
    SearchQuery query,
    AppLocalizations? l10n,
  ) {
    if (l10n == null) {
      return QueryOutputValidator.generateInterpretedSummary(query);
    }
    final parts = <String>[];

    switch (query.intent) {
      case SearchIntent.searchRallies:
        parts.add(l10n.intentSearchRallies);
        break;
      case SearchIntent.searchDriverRallies:
        parts.add(l10n.intentSearchDriverRallies);
        break;
      case SearchIntent.searchDriverWins:
        parts.add(l10n.intentSearchDriverWins);
        break;
      case SearchIntent.getRallyResults:
        parts.add(l10n.intentGetRallyResults);
        break;
      case SearchIntent.getRallyTopFinishers:
        parts.add(l10n.intentGetRallyTopFinishers);
        break;
      case SearchIntent.searchVideoActions:
        if (query.actionTypes.isNotEmpty) {
          final actionsStr = query.actionTypes
              .map((a) => _getLocalizedActionName(a, l10n))
              .join(', ');
          parts.add('${l10n.intentSearchVideoActions} ($actionsStr)');
        } else {
          parts.add(l10n.intentSearchVideoActions);
        }
        break;
      case SearchIntent.searchDriverVideos:
        parts.add(l10n.intentSearchDriverVideos);
        break;
      case SearchIntent.getTopUploaders:
        parts.add(l10n.intentGetTopUploaders);
        break;
      case SearchIntent.getTopDriversByWins:
        parts.add(l10n.intentGetTopDriversByWins);
        break;
    }

    final filters = <String>[];
    if (query.driverNames.isNotEmpty) {
      filters.add('${l10n.filterDriver}: ${query.driverNames.join(', ')}');
    }
    if (query.rallyNames.isNotEmpty) {
      filters.add('${l10n.filterRally}: ${query.rallyNames.join(', ')}');
    }
    if (query.countries.isNotEmpty) {
      filters.add('${l10n.filterCountry}: ${query.countries.join(', ')}');
    }
    if (query.cities.isNotEmpty) {
      filters.add('${l10n.filterCity}: ${query.cities.join(', ')}');
    }
    if (query.stageNames.isNotEmpty) {
      filters.add('${l10n.filterStage}: ${query.stageNames.join(', ')}');
    }
    if (query.years.isNotEmpty) {
      filters.add('${l10n.filterYear}: ${query.years.join(', ')}');
    }

    if (filters.isEmpty) {
      return parts.join();
    }
    return '${parts.join()} | ${filters.join(' | ')}';
  }

  String _getLocalizedActionName(String actionType, AppLocalizations l10n) {
    switch (actionType.toLowerCase()) {
      case 'jump':
        return l10n.actionJump;
      case 'drift':
        return l10n.actionDrift;
      case 'crash':
        return l10n.actionCrash;
      case 'spin':
        return l10n.actionSpin;
      case 'donut':
        return l10n.actionDonut;
      case 'hairpin':
        return l10n.actionHairpin;
      case 'water splash':
        return l10n.actionWaterSplash;
      case 'start line':
        return l10n.actionStartLine;
      case 'near miss':
        return l10n.actionNearMiss;
      case 'mechanical failure':
        return l10n.actionMechanicalFailure;
      case 'offroad':
        return l10n.actionOffroad;
      case 'stuck':
        return l10n.actionStuck;
      default:
        return actionType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalPages = (_totalCount / _pageSize).ceil();
    final suggestions = FollowUpSuggestionEngine.generate(
      _session,
      response: _searchResponse,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.search_rounded, color: kRallyAccent),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Rally Search',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Language Selector Dropdown
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SupportedLanguage>(
                value: _selectedLanguage,
                icon: const Icon(Icons.language_rounded, size: 18),
                isDense: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                // Closed state shows only the compact language code so the app
                // bar never overflows on narrow phones; the open menu keeps the
                // full native names.
                selectedItemBuilder: (context) => SupportedLanguages.all
                    .map(
                      (lang) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(lang.languageCode.toUpperCase()),
                      ),
                    )
                    .toList(),
                items: SupportedLanguages.all.map((lang) {
                  return DropdownMenuItem<SupportedLanguage>(
                    value: lang,
                    child: Text(
                      '${lang.nativeName} (${lang.languageCode.toUpperCase()})',
                    ),
                  );
                }).toList(),
                onChanged: (lang) {
                  if (lang != null) {
                    unawaited(_nativeSpeechService.cancelListening());
                    unawaited(_cloudSpeechService.cancelListening());
                    setState(() {
                      _selectedLanguage = lang;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Advanced Filter Button
          IconButton(
            tooltip: 'Advanced Filters',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openAdvancedFilters,
          ),

          // Reset Session Button
          IconButton(
            tooltip: 'Reset Session',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _handleClearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Hero search field + two intentional voice modes.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full-width hero field (~56dp). Search icon prefix; clear +
                // inline submit appear only when there is text.
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 15),
                  textDirection: _selectedLanguage.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  textAlign: _selectedLanguage.isRtl
                      ? TextAlign.right
                      : TextAlign.left,
                  decoration: InputDecoration(
                    hintText: 'Search rallies, drivers, or moments',
                    hintStyle: const TextStyle(fontSize: 15),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: kRallyAccent,
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  unawaited(
                                      _nativeSpeechService.cancelListening());
                                  unawaited(
                                      _cloudSpeechService.cancelListening());
                                  setState(() {
                                    _searchController.clear();
                                    _sttSource = null;
                                    _sttRawTranscript = null;
                                    _voiceGeneration++;
                                    _session = _session.copyWith(
                                      activeRequestId:
                                          _session.activeRequestId + 1,
                                    );
                                    _isLoading = false;
                                  });
                                },
                              ),
                              IconButton(
                                key: const Key('submit_search_button'),
                                tooltip: 'Search',
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: kRallyAccent,
                                ),
                                onPressed: _executeNaturalLanguageSearch,
                              ),
                            ],
                          )
                        : null,
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F4F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      borderSide: const BorderSide(
                        color: kRallyAccent,
                        width: 1.5,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _executeNaturalLanguageSearch(),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Two voice modes presented as deliberate product choices.
                // Both remain fully operational and independent; neither falls
                // back to the other. Transcript is editable and never
                // auto-submitted.
                Row(
                  children: [
                    Expanded(
                      child: VoiceSearchButton(
                        key: const Key('cloud_voice_button'),
                        speechService: _cloudSpeechService,
                        selectedLanguage: _selectedLanguage,
                        showLabel: true,
                        label: 'Cloud voice',
                        tooltipPrefix: 'Cloud voice',
                        idleIcon: Icons.cloud_rounded,
                        onBeforeStart: () async {
                          setState(() {
                            _voiceGeneration++;
                          });
                          await _nativeSpeechService.cancelListening();
                        },
                        onTranscriptReceived: (transcript) {
                          _handleVoiceTranscriptReceived(
                            transcript: transcript,
                            source: 'CLOUD',
                            generation: _voiceGeneration,
                          );
                        },
                        onResultDetailed: (result) {
                          _handleVoiceTranscriptReceived(
                            transcript: result.text,
                            source: 'CLOUD',
                            generation: _voiceGeneration,
                            detailed: result,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: VoiceSearchButton(
                        key: const Key('native_voice_button'),
                        speechService: _nativeSpeechService,
                        selectedLanguage: _selectedLanguage,
                        showLabel: true,
                        label: 'On-device voice',
                        tooltipPrefix: 'On-device voice',
                        idleIcon: Icons.smartphone_rounded,
                        onBeforeStart: () async {
                          setState(() {
                            _voiceGeneration++;
                          });
                          await _cloudSpeechService.cancelListening();
                        },
                        onTranscriptReceived: (transcript) {
                          _handleVoiceTranscriptReceived(
                            transcript: transcript,
                            source: 'NATIVE',
                            generation: _voiceGeneration,
                          );
                        },
                        onResultDetailed: (result) {
                          _handleVoiceTranscriptReceived(
                            transcript: result.text,
                            source: 'NATIVE',
                            generation: _voiceGeneration,
                            detailed: result,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Active Search Context & Refinement Chips Bar
          ActiveContextChipsBar(
            session: _session,
            onRemoveFilter: _handleRemoveFilter,
            onRollbackHistory: _handleRollbackHistory,
            onClearAll: _handleClearAll,
          ),

          // 2b. Offline / connectivity banner (product-tone: headline +
          //     literal explanation). Never styles results as an error.
          if (_offlineActive)
            OfflineBanner(
              state: _offlineState,
              age: _offlineAge,
              actionLabel: _offlineState == OfflineUxState.noLocalSnapshot ? 'Sync now' : null,
              onAction: _offlineState == OfflineUxState.noLocalSnapshot
                  ? () => unawaited(_offlineSync?.sync() ?? Future.value())
                  : null,
            ),

          // 2c. A late authoritative result, offered rather than applied. The
          //     saved data stays on screen until the user taps through, so the
          //     result under their eyes never changes on its own.
          if (_hasPendingOnlineResult)
            OfflineBanner(
              key: const Key('freshResultsBanner'),
              state: OfflineUxState.lateOnlineResultAvailable,
              actionLabel: 'Show latest',
              onAction: () => unawaited(_showLatestOnlineResult()),
              onDismiss: () => setState(_discardPendingOnline),
            ),

          // 3. Inline Clarification Card (if disambiguation required)
          if (_clarificationQuestion != null)
            ClarificationCard(
              question: _clarificationQuestion!,
              candidates: _clarificationCandidates,
              onCandidateSelected: _onSelectCandidate,
              onDismiss: () => setState(() {
                _clarificationQuestion = null;
                _clarificationCandidates = [];
                _pendingClarification = null;
              }),
            ),

          // 4. Results summary line. The interpretation itself is shown as the
          //    removable chip bar above (ActiveContextChipsBar); no raw
          //    schema/intent/pipe string is exposed here. Shown only when there
          //    are results to describe.
          if (_searchResponse != null &&
              _searchResponse!.results.isNotEmpty &&
              !_isLoading)
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF141414) : Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      children: [
                        const TextSpan(text: 'Found '),
                        TextSpan(
                          text: '$_totalCount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' ${_resultTypeLabel(_session.activeQuery.intent)}',
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_totalCount > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 6. Dynamic Result View Dispatcher
          Expanded(child: _buildDynamicResultsView(context)),

          // 7. Contextual Suggested Follow-ups
          if (!_isLoading &&
              _searchResponse != null &&
              _searchResponse!.results.isNotEmpty)
            SuggestedFollowUpsBar(
              suggestions: suggestions.take(3).toList(),
              onSuggestionSelected: _handleSuggestionSelected,
            ),

          // 8. Pagination Footer
          if (_totalCount > _pageSize) _buildPaginationFooter(totalPages),
        ],
      ),
    );
  }

  String _resultTypeLabel(SearchIntent intent) {
    switch (intent) {
      case SearchIntent.searchRallies:
        return 'rallies';
      case SearchIntent.searchDriverRallies:
        return 'rally participations';
      case SearchIntent.searchDriverWins:
        return 'rally victories';
      case SearchIntent.getRallyResults:
      case SearchIntent.getRallyTopFinishers:
        return 'finisher results';
      case SearchIntent.searchVideoActions:
        return 'action moments';
      case SearchIntent.searchDriverVideos:
        return 'videos';
      case SearchIntent.getTopUploaders:
        return 'uploaders';
      case SearchIntent.getTopDriversByWins:
        return 'winning drivers';
    }
  }

  // Curated, non-overwhelming example queries for the first-launch state.
  static const List<String> _exampleQueries = [
    'Rallies in Ireland in 2025',
    "Show Max Freeman's rallies",
    'Jump highlights from Rally Alūksne',
    'Who won Rally Donegal?',
  ];

  void _runExampleQuery(String query) {
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _executeNaturalLanguageSearch();
  }

  Widget _buildFirstLaunchHero(BuildContext context) {
    final palette = AppPalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rally Search',
            style: AppText.screenTitle.copyWith(color: palette.primaryText),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Search rallies, drivers, and moments using natural language or voice.',
            style: AppText.body.copyWith(
              color: palette.secondaryText,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Try',
            style: AppText.label.copyWith(color: palette.secondaryText),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._exampleQueries.map(
            (q) => Semantics(
              button: true,
              label: 'Example search: $q',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.control),
                onTap: () => _runExampleQuery(q),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.north_east_rounded,
                        size: 16,
                        color: kRallyAccent,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          q,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Collects the active query's filters as removable chips (field/value/label)
  /// using the same deterministic removal path as [ActiveContextChipsBar].
  List<({String field, dynamic value, String label})> _activeFilters() {
    final q = _session.activeQuery;
    final out = <({String field, dynamic value, String label})>[];
    for (final r in q.rallyNames) {
      out.add((field: 'rally', value: r, label: r));
    }
    for (final d in q.driverNames) {
      out.add((field: 'driver', value: d, label: d));
    }
    for (final c in q.countries) {
      if (c.toUpperCase() == 'ALL') continue;
      out.add((field: 'country', value: c, label: c));
    }
    for (final y in q.years) {
      out.add((field: 'year', value: y, label: '$y'));
    }
    for (final a in q.actionTypes) {
      if (a.toUpperCase() == 'ALL') continue;
      final label = a.isNotEmpty ? '${a[0].toUpperCase()}${a.substring(1)}' : a;
      out.add((field: 'action', value: a, label: label));
    }
    for (final city in q.cities) {
      out.add((field: 'city', value: city, label: city));
    }
    return out;
  }

  Widget _removableFilterChip(
    AppPalette palette, {
    required String label,
    required VoidCallback onRemove,
  }) {
    return Semantics(
      button: true,
      label: 'Remove filter $label',
      child: Material(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.close_rounded, size: 15, color: palette.secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Lightweight inline easter-egg / personality response card. Search-first,
  /// not a chatbot: a small rally-themed card, no avatar/persona, no bubble.
  Widget _buildSpecialResponse(BuildContext context) {
    final palette = AppPalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        key: const Key('special_response_card'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏁', style: TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _specialMessage ?? '',
                  style: AppText.body.copyWith(
                    color: palette.primaryText,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final palette = AppPalette.of(context);
    final understanding = _errorKind == _SearchErrorKind.understanding;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              understanding
                  ? Icons.search_off_rounded
                  : Icons.cloud_off_rounded,
              size: 52,
              color: palette.secondaryText,
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                understanding
                    ? "We couldn't turn that into a search"
                    : 'Search is temporarily unavailable',
                textAlign: TextAlign.center,
                style: AppText.sectionTitle
                    .copyWith(fontSize: 17, color: palette.primaryText),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              understanding
                  ? 'Try rephrasing — for example, “rallies in Ireland in 2025”.'
                  : 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppText.metadata.copyWith(color: palette.secondaryText),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (understanding)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final q in _exampleQueries.take(2))
                    ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 12.5)),
                      onPressed: () => _runExampleQuery(q),
                    ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => _executeDeterministicSearch(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final palette = AppPalette.of(context);
    final filters = _activeFilters();
    final candidates = _lastNlResult?.candidates ?? const [];
    final resultLabel = _resultTypeLabel(_session.activeQuery.intent);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: palette.secondaryText),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                'No $resultLabel found',
                textAlign: TextAlign.center,
                style: AppText.sectionTitle
                    .copyWith(fontSize: 18, color: palette.primaryText),
              ),
            ),
            if (_emptyResultsMessage != null &&
                _emptyResultsMessage!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _emptyResultsMessage!,
                textAlign: TextAlign.center,
                style: AppText.metadata.copyWith(color: palette.secondaryText),
              ),
            ],
            if (filters.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Filters',
                style: AppText.label.copyWith(color: palette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final f in filters)
                    _removableFilterChip(
                      palette,
                      label: f.label,
                      onRemove: () => _handleRemoveFilter(f.field, f.value),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tap a filter to remove it and broaden your search.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: palette.secondaryText),
              ),
            ],
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Did you mean',
                style: AppText.label.copyWith(color: palette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final cand in candidates)
                    ActionChip(
                      avatar: Icon(_getCandidateIcon(cand.type),
                          size: 16, color: palette.accent),
                      label: Text(
                        cand.subtitle != null
                            ? '${cand.canonicalName} · ${cand.subtitle}'
                            : cand.canonicalName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => _onSelectCandidate(cand),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _handleClearAll,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Start over'),
                ),
                if (_session.activeQuery.intent != SearchIntent.searchRallies)
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _session = _session.copyWith(
                          activeQuery: const SearchQuery(
                            intent: SearchIntent.searchRallies,
                          ),
                        );
                      });
                      _executeDeterministicSearch(resetPage: true);
                    },
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: const Text('Search all rallies'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicResultsView(BuildContext context) {
    // First-launch hero: no automatic search runs on open, so until the user
    // searches we show the product title + example queries instead of results.
    if (!_hasSearched && !_isLoading) {
      return _buildFirstLaunchHero(context);
    }

    if (_isLoading) {
      return ResultsSkeleton(label: _loadingStatus);
    }

    if (_specialMessage != null) {
      return _buildSpecialResponse(context);
    }

    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    if (_searchResponse == null || _searchResponse!.results.isEmpty) {
      return _buildNoResultsState(context);
    }

    final resp = _searchResponse!;

    switch (resp.intent) {
      case SearchIntent.searchRallies:
        final rallies = resp.results.cast<RallySearchResult>();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rallies.length,
          itemBuilder: (ctx, idx) => RallyResultCard(
            rally: rallies[idx],
            onTap: () {
              // Drilldown to top finishers and set referent
              setState(() {
                _session = _session.copyWith(
                  activeQuery: _session.activeQuery.copyWith(
                    intent: SearchIntent.getRallyTopFinishers,
                    rallyName: rallies[idx].eventName,
                  ),
                  referents: _session.referents.copyWith(
                    activeRally: rallies[idx].eventName,
                    lastSelectedRally: rallies[idx].eventName,
                  ),
                );
              });
              _executeDeterministicSearch(resetPage: true);
            },
          ),
        );

      case SearchIntent.searchDriverRallies:
      case SearchIntent.searchDriverWins:
        final parts = resp.results.cast<RallyParticipationResult>();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: parts.length,
          itemBuilder: (ctx, idx) =>
              DriverParticipationCard(participation: parts[idx]),
        );

      case SearchIntent.getRallyResults:
      case SearchIntent.getRallyTopFinishers:
        final finishers = resp.results.cast<RallyResult>();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: RallyLeaderboard(
            results: finishers,
            rallyName: _session.activeQuery.targetRallyName,
          ),
        );

      case SearchIntent.searchVideoActions:
        final actions = resp.results.cast<VideoAction>();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: actions.length,
          itemBuilder: (ctx, idx) => VideoActionCard(
            action: actions[idx],
            onPlay: _offlineActive
                ? (act) => _showPlaybackGated(ctx)
                : (act) => ActionPlayerModal.show(ctx, act),
          ),
        );

      case SearchIntent.searchDriverVideos:
        final driverVids = resp.results.cast<VideoSearchResult>();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: driverVids.length,
          itemBuilder: (ctx, idx) => VideoResultCard(video: driverVids[idx], offline: _offlineActive),
        );

      case SearchIntent.getTopUploaders:
        final uploaders = resp.results.cast<UploaderSearchResult>();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: UploaderLeaderboard(
            uploaders: uploaders,
            rallyName: _session.activeQuery.targetRallyName,
          ),
        );

      case SearchIntent.getTopDriversByWins:
        final winningDrivers = resp.results.cast<DriverWinResult>();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: DriverWinsLeaderboard(
            drivers: winningDrivers,
            onDriverTap: (d) {
              // Drilldown to driver's won rallies
              setState(() {
                _session = _session.copyWith(
                  activeQuery: _session.activeQuery.copyWith(
                    intent: SearchIntent.searchDriverWins,
                    driverName: d.driverName,
                  ),
                  referents: _session.referents.copyWith(
                    activeDriver: d.driverName,
                    lastSelectedDriver: d.driverName,
                  ),
                );
              });
              _executeDeterministicSearch(resetPage: true);
            },
          ),
        );
    }
  }

  Widget _buildPaginationFooter(int totalPages) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _currentPage > 1 && !_isLoading
                  ? () {
                      setState(() => _currentPage--);
                      _executeDeterministicSearch();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              label: const Text('Prev'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: Text(
                'Page $_currentPage of $totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _currentPage < totalPages && !_isLoading
                  ? () {
                      setState(() => _currentPage++);
                      _executeDeterministicSearch();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: const Text('Next'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
