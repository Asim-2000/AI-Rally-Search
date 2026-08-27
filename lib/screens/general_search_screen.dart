import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/conversational_search_session.dart';
import '../models/entity_candidate.dart';
import '../models/result_referent_context.dart';
import '../models/search_intent.dart';
import '../models/search_query.dart';
import '../models/search_results.dart';
import '../models/supported_language.dart';
import '../models/video_action.dart';
import '../models/speech/speech_transcription_result.dart';
import '../services/llm/entity_resolution/database_entity_resolver.dart';
import '../services/llm/entity_resolution/spoken_entity_resolver.dart';
import '../services/llm/entity_resolution/entity_lookup_repository.dart';
import '../services/llm/follow_up_suggestion_engine.dart';
import '../services/llm/llm_query_parser.dart';
import '../services/llm/llm_query_parser_factory.dart';
import '../services/llm/natural_language_search_service.dart';
import '../services/llm/query_output_validator.dart';
import '../services/search_repository.dart';
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

  const GeneralSearchScreen({
    super.key,
    this.initialQuery,
    this.repository,
    this.nlSearchService,
    this.llmParser,
    this.speechService,
  });

  @override
  State<GeneralSearchScreen> createState() => _GeneralSearchScreenState();
}

class _GeneralSearchScreenState extends State<GeneralSearchScreen> {
  late final ISearchRepository _repository;
  late final NaturalLanguageSearchService _nlSearchService;
  late final ISpeechToTextService _speechService;

  // Selected language for speech and query understanding
  SupportedLanguage _selectedLanguage = SupportedLanguages.defaultLanguage;

  // Single continuous search field controller
  final TextEditingController _searchController = TextEditingController();

  // Core Conversational Search Session
  SearchConversationSession _session = SearchConversationSession.initial;

  // Search & Clarification state
  String? _interpretedSummary;
  String? _clarificationQuestion;
  List<EntityCandidate> _clarificationCandidates = [];
  NaturalLanguageSearchResult? _lastNlResult;

  // Pagination state
  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;

  bool _isLoading = false;
  String _loadingStatus = 'Searching...';
  String? _errorMessage;
  SearchResponse<dynamic>? _searchResponse;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SearchRepository();
    final parser = widget.llmParser ?? LlmQueryParserFactory.create();
    final lookupRepo = DatabaseEntityLookupRepository();
    final resolver = SpokenEntityResolver(repository: lookupRepo);
    _nlSearchService = widget.nlSearchService ??
        NaturalLanguageSearchService(
          parser: parser,
          entityResolver: resolver,
          repository: _repository,
        );
    _speechService = widget.speechService ?? SpeechServiceFactory.create();

    if (widget.initialQuery != null) {
      _session = _session.copyWith(
        activeQuery: widget.initialQuery!,
      );
      _executeDeterministicSearch(resetPage: true);
    } else {
      _executeDeterministicSearch(resetPage: true);
    }
  }

  @override
  void dispose() {
    _speechService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // CONTINUOUS CONVERSATIONAL SEARCH EXECUTION
  // ===========================================================================

  Future<void> _executeNaturalLanguageSearch({SpeechTranscriptionResult? spokenResult}) async {
    final queryText = (spokenResult?.text ?? _searchController.text).trim();
    if (queryText.isEmpty) return;

    final nextRequestId = _session.activeRequestId + 1;
    setState(() {
      _searchController.text = queryText;
      _session = _session.copyWith(activeRequestId: nextRequestId);
      _isLoading = true;
      _loadingStatus = 'Understanding your search...';
      _errorMessage = null;
      _clarificationQuestion = null;
      _clarificationCandidates = [];
      _currentPage = 1;
    });

    try {
      final searchContext = SearchContext(
        currentYear: DateTime.now().year,
        locale: _selectedLanguage.localeCode,
        languageCode: _selectedLanguage.languageCode,
        referents: _session.referents,
        previousQuery: _session.activeQuery,
      );

      final NaturalLanguageSearchResult result;
      if (spokenResult != null) {
        result = await _nlSearchService.searchSpoken(spokenResult, context: searchContext);
      } else {
        result = await _nlSearchService.search(queryText, context: searchContext);
      }

      if (!mounted || _session.activeRequestId != nextRequestId) return;

      if (result.requiresClarification) {
        setState(() {
          _isLoading = false;
          _clarificationQuestion = result.clarificationQuestion;
          _clarificationCandidates = result.candidates;
          _interpretedSummary = null;
        });
        return;
      }

      if (!result.isSuccess || result.query == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = result.error ?? 'Query parsing failed';
          _clarificationCandidates = [];
          _interpretedSummary = null;
        });
        return;
      }

      final parsedQuery = result.query!;
      final l10n = AppLocalizations.of(context);
      final localizedSummary = _buildLocalizedInterpretedSummary(parsedQuery, l10n);

      // Determine which fields were inherited vs refined in this turn
      final inherited = <String>{};
      final refinements = <String>{};

      if (parsedQuery.rallyNames.isNotEmpty) {
        if (_session.activeQuery.rallyNames.isNotEmpty &&
            _session.activeQuery.rallyNames.first == parsedQuery.rallyNames.first) {
          inherited.add('rally');
        } else {
          refinements.add('rally');
        }
      }
      if (parsedQuery.driverNames.isNotEmpty) {
        if (_session.activeQuery.driverNames.isNotEmpty &&
            _session.activeQuery.driverNames.first == parsedQuery.driverNames.first) {
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

      final updatedSession = _session.recordTurn(
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
        _interpretedSummary = localizedSummary;
        _lastNlResult = result;
        _clarificationQuestion = null;
        _clarificationCandidates = [];
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || _session.activeRequestId != nextRequestId) return;
      setState(() {
        _errorMessage = 'Natural language search failed: $e';
        _clarificationCandidates = [];
        _interpretedSummary = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _executeDeterministicSearch({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }

    final nextRequestId = _session.activeRequestId + 1;
    setState(() {
      _session = _session.copyWith(activeRequestId: nextRequestId);
      _isLoading = true;
      _loadingStatus = 'Searching database...';
      _errorMessage = null;
    });

    try {
      final offset = (_currentPage - 1) * _pageSize;
      final queryToExecute = _session.activeQuery.copyWith(
        limit: _pageSize,
        offset: offset,
      );

      final response = await _repository.search(queryToExecute);

      if (!mounted || _session.activeRequestId != nextRequestId) return;

      final updatedReferents = ResultReferentContext.fromSearchResponse(
        response,
        previous: _session.referents,
        queryRally: queryToExecute.targetRallyName,
        queryDriver: queryToExecute.driverName,
        queryRallies: queryToExecute.targetRallyNames,
        queryDrivers: queryToExecute.driverNames,
      );

      final l10n = AppLocalizations.of(context);
      final summary = _buildLocalizedInterpretedSummary(queryToExecute, l10n);

      setState(() {
        _session = _session.copyWith(
          activeQuery: queryToExecute,
          referents: updatedReferents,
        );
        _searchResponse = response;
        _totalCount = response.totalCount;
        _interpretedSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || _session.activeRequestId != nextRequestId) return;
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isLoading = false;
      });
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
    setState(() {
      _searchController.clear();
      _session = _session.clearAll();
      _interpretedSummary = null;
      _clarificationQuestion = null;
      _clarificationCandidates = [];
      _lastNlResult = null;
    });
    _executeDeterministicSearch(resetPage: true);
  }

  void _onSelectCandidate(EntityCandidate candidate) {
    setState(() {
      _clarificationQuestion = null;
      _clarificationCandidates = [];

      SearchQuery updated = _session.activeQuery;
      ResultReferentContext referents = _session.referents;

      switch (candidate.type) {
        case EntityType.rally:
          final yr = candidate.metadata?['year'] as int?;
          updated = updated.copyWith(
            rallyNames: [candidate.canonicalName],
            years: yr != null ? [yr] : updated.years,
          );
          referents = referents.copyWith(
            activeRally: candidate.canonicalName,
            activeRallies: [candidate.canonicalName],
          );
          break;
        case EntityType.driver:
          final driverId = candidate.id;
          updated = updated.copyWith(
            driverNames: [candidate.canonicalName],
            driverIds: driverId.isNotEmpty ? [driverId] : updated.driverIds,
          );
          referents = referents.copyWith(
            activeDriver: candidate.canonicalName,
            activeDriverId: driverId,
            activeDrivers: [candidate.canonicalName],
          );
          break;
        case EntityType.city:
          updated = updated.copyWith(cities: [candidate.canonicalName]);
          break;
        case EntityType.stage:
          updated = updated.copyWith(stageNames: [candidate.canonicalName]);
          break;
        case EntityType.uploader:
          updated = updated.copyWith(uploaders: [candidate.canonicalName]);
          break;
      }

      _session = _session.copyWith(
        activeQuery: updated,
        referents: referents,
      );
    });
    _executeDeterministicSearch(resetPage: true);
  }

  void _handleSuggestionSelected(FollowUpSuggestion suggestion) {
    if (suggestion.targetQuery != null) {
      setState(() {
        _session = _session.copyWith(
          activeQuery: suggestion.targetQuery!,
        );
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

  String _buildLocalizedInterpretedSummary(SearchQuery query, AppLocalizations? l10n) {
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
          final actionsStr = query.actionTypes.map((a) => _getLocalizedActionName(a, l10n)).join(', ');
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
    if (query.driverNames.isNotEmpty) filters.add('${l10n.filterDriver}: ${query.driverNames.join(', ')}');
    if (query.rallyNames.isNotEmpty) filters.add('${l10n.filterRally}: ${query.rallyNames.join(', ')}');
    if (query.countries.isNotEmpty) filters.add('${l10n.filterCountry}: ${query.countries.join(', ')}');
    if (query.cities.isNotEmpty) filters.add('${l10n.filterCity}: ${query.cities.join(', ')}');
    if (query.stageNames.isNotEmpty) filters.add('${l10n.filterStage}: ${query.stageNames.join(', ')}');
    if (query.years.isNotEmpty) filters.add('${l10n.filterYear}: ${query.years.join(', ')}');

    if (filters.isEmpty) {
      return parts.join();
    }
    return '${parts.join()} | ${filters.join(' | ')}';
  }

  String _getLocalizedActionName(String actionType, AppLocalizations l10n) {
    switch (actionType.toLowerCase()) {
      case 'jump': return l10n.actionJump;
      case 'drift': return l10n.actionDrift;
      case 'crash': return l10n.actionCrash;
      case 'spin': return l10n.actionSpin;
      case 'donut': return l10n.actionDonut;
      case 'hairpin': return l10n.actionHairpin;
      case 'water splash': return l10n.actionWaterSplash;
      case 'start line': return l10n.actionStartLine;
      case 'near miss': return l10n.actionNearMiss;
      case 'mechanical failure': return l10n.actionMechanicalFailure;
      case 'offroad': return l10n.actionOffroad;
      case 'stuck': return l10n.actionStuck;
      default: return actionType;
    }
  }

  void _showTelemetryDialog(BuildContext context, NaturalLanguageSearchResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parseResult = result.parseResult;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.analytics_outlined, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text(
              'AI Query Telemetry & Evaluation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Provider & Model
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hub_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Provider: ${parseResult.provider?.name.toUpperCase() ?? 'UNKNOWN'} (${parseResult.model ?? 'default'})',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Pillar 1: Cost
              const Text('💰 Cost & Token Usage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prompt Tokens:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text('${parseResult.promptTokens ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Completion Tokens:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text('${parseResult.completionTokens ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated USD Cost:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(parseResult.formattedCost, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),

              // Pillar 2: Latency
              const Text('⏱️ Latency Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LLM Parse Time:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text('${result.parseLatencyMs} ms', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Entity Resolution Time:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text('${result.entityResolutionLatencyMs} ms', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Database Execution Time:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text('${result.dbLatencyMs} ms', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total End-to-End Latency:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text('${result.totalLatencyMs} ms', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),

              // Referents Context
              const Text('🧠 Result-Derived Referent Context', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Rally: ${result.referents.activeRally ?? 'none'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    Text('Active Driver: ${result.referents.activeDriver ?? 'none'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    Text('Last Winner: ${result.referents.lastWinner ?? 'none'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Structured SearchQuery
              if (result.query != null) ...[
                const Text('🔍 Structured Query JSON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.query!.toMap().toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalPages = (_totalCount / _pageSize).ceil();
    final suggestions = FollowUpSuggestionEngine.generate(_session, response: _searchResponse);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'AI Rally Search',
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
                items: SupportedLanguages.all.map((lang) {
                  return DropdownMenuItem<SupportedLanguage>(
                    value: lang,
                    child: Text('${lang.nativeName} (${lang.languageCode.toUpperCase()})'),
                  );
                }).toList(),
                onChanged: (lang) {
                  if (lang != null) {
                    setState(() {
                      _selectedLanguage = lang;
                      if (_lastNlResult?.query != null) {
                        _interpretedSummary = _buildLocalizedInterpretedSummary(
                          _lastNlResult!.query!,
                          AppLocalizations.of(context),
                        );
                      }
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
          // 1. Prominent Continuous Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textDirection: _selectedLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: _selectedLanguage.isRtl ? TextAlign.right : TextAlign.left,
                    decoration: InputDecoration(
                      hintText: 'Search rallies, drivers, jumps, or ask a question...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF1E88E5), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _executeNaturalLanguageSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                VoiceSearchButton(
                  speechService: _speechService,
                  selectedLanguage: _selectedLanguage,
                  onResultDetailed: (speechResult) {
                    _executeNaturalLanguageSearch(spokenResult: speechResult);
                  },
                  onTranscriptReceived: (transcript) {
                    if (_searchController.text != transcript) {
                      _searchController.text = transcript;
                      _executeNaturalLanguageSearch();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _executeNaturalLanguageSearch,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Search'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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

          // 3. Inline Clarification Card (if disambiguation required)
          if (_clarificationQuestion != null)
            ClarificationCard(
              question: _clarificationQuestion!,
              candidates: _clarificationCandidates,
              onCandidateSelected: _onSelectCandidate,
              onDismiss: () => setState(() {
                _clarificationQuestion = null;
                _clarificationCandidates = [];
              }),
            ),

          // 4. Interpreted Natural-Language Feedback Bar + Telemetry
          if (_interpretedSummary != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _interpretedSummary!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_lastNlResult != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showTelemetryDialog(context, _lastNlResult!),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.analytics_outlined, size: 13, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${_lastNlResult!.totalLatencyMs > 0 ? "${_lastNlResult!.totalLatencyMs}ms" : _lastNlResult!.parseResult.formattedLatency} · ${_lastNlResult!.parseResult.formattedCost}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // 5. Results Count & Header Bar
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
                        TextSpan(text: ' ${_resultTypeLabel(_session.activeQuery.intent)}'),
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
          Expanded(
            child: _buildDynamicResultsView(context),
          ),

          // 7. Contextual Suggested Follow-ups
          if (!_isLoading && _searchResponse != null && _searchResponse!.results.isNotEmpty)
            SuggestedFollowUpsBar(
              suggestions: suggestions,
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

  Widget _buildDynamicResultsView(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadingStatus, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _executeDeterministicSearch(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResponse == null || _searchResponse!.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text('No search results found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Active search context is preserved. Try removing a filter or searching for another event.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _handleClearAll,
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('Reset Session'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _session = _session.copyWith(
                          activeQuery: const SearchQuery(intent: SearchIntent.searchRallies),
                        );
                      });
                      _executeDeterministicSearch(resetPage: true);
                    },
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Show All Rallies'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
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
          itemBuilder: (ctx, idx) => DriverParticipationCard(participation: parts[idx]),
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
            onPlay: (act) => ActionPlayerModal.show(ctx, act),
          ),
        );

      case SearchIntent.searchDriverVideos:
        final driverVids = resp.results.cast<VideoSearchResult>();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: driverVids.length,
          itemBuilder: (ctx, idx) => VideoResultCard(video: driverVids[idx]),
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
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: Text(
                'Page $_currentPage of $totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
