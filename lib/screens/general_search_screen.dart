import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/entity_candidate.dart';

import '../models/search_intent.dart';
import '../models/search_query.dart';
import '../models/search_results.dart';
import '../models/supported_language.dart';
import '../models/video_action.dart';
import '../services/llm/entity_resolution/database_entity_resolver.dart';
import '../services/llm/entity_resolution/entity_lookup_repository.dart';
import '../services/llm/llm_provider_config.dart';
import '../services/llm/llm_query_parser.dart';
import '../services/llm/llm_query_parser_factory.dart';
import '../services/llm/natural_language_search_service.dart';
import '../services/llm/query_output_validator.dart';
import '../services/search_repository.dart';
import '../widgets/action_player_modal.dart';
import '../widgets/driver_participation_card.dart';
import '../widgets/driver_wins_leaderboard.dart';
import '../widgets/rally_leaderboard.dart';
import '../widgets/rally_result_card.dart';
import '../widgets/uploader_leaderboard.dart';
import '../widgets/video_action_card.dart';
import '../widgets/video_result_card.dart';
import '../widgets/voice_search_button.dart';
import '../models/voice_state.dart';
import '../services/speech/speech_to_text_service.dart';
import '../services/speech/speech_service_factory.dart';

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

  // Selected application / query language
  SupportedLanguage _selectedLanguage = SupportedLanguages.defaultLanguage;

  // Search input controllers
  final TextEditingController _nlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Natural language state
  String? _interpretedSummary;
  String? _clarificationQuestion;
  List<EntityCandidate> _clarificationCandidates = [];
  bool _isNlMode = false;
  String? _lastExecutedNlQuery;
  NaturalLanguageSearchResult? _lastNlResult;


  SearchIntent _selectedIntent = SearchIntent.searchRallies;
  String _selectedCountry = 'ALL';
  String _selectedActionType = 'ALL';
  int? _selectedYear;

  // Pagination state
  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;

  bool _isLoading = false;
  String? _errorMessage;
  SearchResponse<dynamic>? _searchResponse;

  final List<Map<String, dynamic>> _intentOptions = [
    {
      'intent': SearchIntent.searchRallies,
      'label': 'Search Rallies',
      'icon': Icons.flag_rounded,
      'hint': 'Search rallies by name, country, city, or year...',
    },
    {
      'intent': SearchIntent.searchDriverRallies,
      'label': 'Driver Rallies',
      'icon': Icons.directions_car_rounded,
      'hint': 'Search rallies a driver participated in...',
    },
    {
      'intent': SearchIntent.searchDriverWins,
      'label': 'Driver Wins',
      'icon': Icons.emoji_events_rounded,
      'hint': 'Search rallies won by a driver...',
    },
    {
      'intent': SearchIntent.getRallyTopFinishers,
      'label': 'Rally Top Finishers',
      'icon': Icons.leaderboard_rounded,
      'hint': 'Rally name (e.g. Moonraker, Donegal)...',
    },
    {
      'intent': SearchIntent.getRallyResults,
      'label': 'Rally Winner',
      'icon': Icons.military_tech_rounded,
      'hint': 'Rally name for 1st place winner...',
    },
    {
      'intent': SearchIntent.searchVideoActions,
      'label': 'Action Highlights',
      'icon': Icons.bolt_rounded,
      'hint': 'Filter jumps, drifts, crashes in rallies...',
    },
    {
      'intent': SearchIntent.searchDriverVideos,
      'label': 'Driver Videos',
      'icon': Icons.videocam_rounded,
      'hint': 'Find videos featuring a specific driver...',
    },
    {
      'intent': SearchIntent.getTopUploaders,
      'label': 'Top Uploaders',
      'icon': Icons.cloud_upload_rounded,
      'hint': 'Filter top uploaders by rally or global...',
    },
    {
      'intent': SearchIntent.getTopDriversByWins,
      'label': 'Most Wins',
      'icon': Icons.workspace_premium_rounded,
      'hint': 'Rank drivers by total career victories...',
    },
  ];

  final List<String> _actionOptions = [
    'ALL',
    'Jump',
    'Drift',
    'Crash',
    'Spin',
    'Start Line',
    'Near Miss',
    'Mechanical Failure',
    'Offroad',
    'Stuck',
  ];

  final List<Map<String, String>> _countryOptions = [
    {'label': 'All Countries', 'value': 'ALL'},
    {'label': 'Ireland (IE)', 'value': 'Ireland'},
    {'label': 'United Kingdom (UK / GB)', 'value': 'United Kingdom'},
    {'label': 'Portugal (PT)', 'value': 'Portugal'},
    {'label': 'Austria (AT)', 'value': 'Austria'},
    {'label': 'France (FR)', 'value': 'France'},
    {'label': 'Norway (NO)', 'value': 'Norway'},
    {'label': 'Poland (PL)', 'value': 'Poland'},
    {'label': 'Belgium (BE)', 'value': 'Belgium'},
    {'label': 'Spain (ES)', 'value': 'Spain'},
    {'label': 'Italy (IT)', 'value': 'Italy'},
    {'label': 'Latvia (LV)', 'value': 'Latvia'},
    {'label': 'Czech Republic (CZ)', 'value': 'Czech Republic'},
    {'label': 'Germany (DE)', 'value': 'Germany'},
    {'label': 'Kenya (KE)', 'value': 'Kenya'},
    {'label': 'Croatia (HR)', 'value': 'Croatia'},
    {'label': 'Netherlands (NL)', 'value': 'Netherlands'},
    {'label': 'New Zealand (NZ)', 'value': 'New Zealand'},
    {'label': 'Lithuania (LT)', 'value': 'Lithuania'},
    {'label': 'Slovakia (SK)', 'value': 'Slovakia'},
    {'label': 'Qatar (QA)', 'value': 'Qatar'},
    {'label': 'Pakistan (PK)', 'value': 'Pakistan'},
    {'label': 'Barbados (BB)', 'value': 'Barbados'},
  ];

  final List<int?> _yearOptions = [
    null,
    2026,
    2025,
    2024,
    2023,
  ];

  bool _showExtraFilters = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SearchRepository();
    final parser = widget.llmParser ?? LlmQueryParserFactory.create();
    final lookupRepo = DatabaseEntityLookupRepository();
    final resolver = DatabaseEntityResolver(repository: lookupRepo);
    _nlSearchService = widget.nlSearchService ??
        NaturalLanguageSearchService(
          parser: parser,
          entityResolver: resolver,
          repository: _repository,
        );
    _speechService = widget.speechService ?? SpeechServiceFactory.create();

    if (widget.initialQuery != null) {
      final q = widget.initialQuery!;
      _selectedIntent = q.intent;
      if (q.country != null) _selectedCountry = q.country!;
      if (q.city != null) _cityController.text = q.city!;
      if (q.year != null) _selectedYear = q.year;
      if (q.driverName != null) _driverController.text = q.driverName!;
      if (q.actionType != null) _selectedActionType = q.actionType!;
      if (q.targetRallyName != null) _searchController.text = q.targetRallyName!;
    }
    _executeSearch(resetPage: true);
  }

  @override
  void dispose() {
    _speechService.dispose();
    _nlController.dispose();
    _searchController.dispose();
    _driverController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _executeNaturalLanguageSearch() async {
    final queryText = _nlController.text.trim();
    if (queryText.isEmpty) return;

    // Prevent duplicate simultaneous requests
    if (_isLoading && _lastExecutedNlQuery == queryText) return;
    _lastExecutedNlQuery = queryText;

    setState(() {
      _isLoading = true;
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
      );
      final result = await _nlSearchService.search(queryText, context: searchContext);

      if (mounted) {
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

        // Apply parsed query to filter controls so UI reflects what was understood
        final q = result.query!;
        _selectedIntent = q.intent;
        _searchController.text = q.targetRallyName ?? '';
        _driverController.text = q.driverName ?? '';
        _cityController.text = q.city ?? '';

        String resolvedCountry = 'ALL';
        if (q.country != null) {
          final match = _countryOptions.firstWhere(
            (c) => c['value']!.toLowerCase() == q.country!.toLowerCase() ||
                   c['label']!.toLowerCase().contains(q.country!.toLowerCase()),
            orElse: () => {'value': 'ALL'},
          );
          resolvedCountry = match['value']!;
        }
        _selectedCountry = resolvedCountry;

        _selectedActionType = q.actionType != null
            ? (q.actionType![0].toUpperCase() + q.actionType!.substring(1))
            : 'ALL';
        _selectedYear = q.year;

        final l10n = AppLocalizations.of(context);
        final localizedSummary = _buildLocalizedInterpretedSummary(q, l10n);

        setState(() {
          _searchResponse = result.searchResponse;
          _totalCount = result.totalCount;
          _interpretedSummary = localizedSummary;
          _lastNlResult = result;
          _clarificationQuestion = null;
          _clarificationCandidates = [];
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Natural language search failed: $e';
          _clarificationCandidates = [];
          _interpretedSummary = null;
          _isLoading = false;
        });
      }
    }
  }

  String _buildLocalizedInterpretedSummary(SearchQuery query, AppLocalizations? l10n) {
    if (l10n == null) {
      return QueryOutputValidator.generateInterpretedSummary(query);
    }
    final parts = <String>[];

    // Localized intent headline
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
        if (query.actionType != null) {
          final localizedAction = _getLocalizedActionName(query.actionType!, l10n);
          parts.add('${l10n.intentSearchVideoActions} ($localizedAction)');
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
    if (query.driverName != null) filters.add('${l10n.filterDriver}: ${query.driverName}');
    if (query.targetRallyName != null) filters.add('${l10n.filterRally}: ${query.targetRallyName}');
    if (query.country != null) filters.add('${l10n.filterCountry}: ${query.country}');
    if (query.city != null) filters.add('${l10n.filterCity}: ${query.city}');
    if (query.stageName != null) filters.add('${l10n.filterStage}: ${query.stageName}');
    if (query.year != null) filters.add('${l10n.filterYear}: ${query.year}');

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

  void _onSelectCandidate(EntityCandidate candidate) {
    setState(() {
      _clarificationQuestion = null;
      _clarificationCandidates = [];

      switch (candidate.type) {
        case EntityType.rally:
          _searchController.text = candidate.canonicalName;
          final year = candidate.metadata?['year'] as int?;
          if (year != null) _selectedYear = year;
          break;
        case EntityType.driver:
          _driverController.text = candidate.canonicalName;
          break;
        case EntityType.stage:
          // Stage resolved
          break;
        case EntityType.city:
          _cityController.text = candidate.canonicalName;
          break;
        case EntityType.uploader:
          _searchController.text = candidate.canonicalName;
          break;
      }
    });
    _executeSearch(resetPage: true);
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

              // Entity Resolution Comparison (Parsed vs Resolved)
              if (result.parsedQuery != null || result.resolvedQuery != null) ...[
                const Text('🏷️ Entity Resolution (Parsed vs Resolved)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                      if (result.parsedQuery?.targetRallyName != null || result.resolvedQuery?.targetRallyName != null) ...[
                        Text(
                          'Rally: "${result.parsedQuery?.targetRallyName ?? ''}" → "${result.resolvedQuery?.targetRallyName ?? ''}"',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                      if (result.parsedQuery?.driverName != null || result.resolvedQuery?.driverName != null) ...[
                        Text(
                          'Driver: "${result.parsedQuery?.driverName ?? ''}" → "${result.resolvedQuery?.driverName ?? ''}" (ID: ${result.resolvedQuery?.driverId ?? 'none'})',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                      if (result.parsedQuery?.stageName != null || result.resolvedQuery?.stageName != null) ...[
                        Text(
                          'Stage: "${result.parsedQuery?.stageName ?? ''}" → "${result.resolvedQuery?.stageName ?? ''}"',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                      if (result.parsedQuery?.city != null || result.resolvedQuery?.city != null) ...[
                        Text(
                          'City: "${result.parsedQuery?.city ?? ''}" → "${result.resolvedQuery?.city ?? ''}"',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Pillar 3: Correctness Checks
              const Text('🛡️ Structural Correctness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              _buildCorrectnessItem('Schema Valid JSON', true),
              _buildCorrectnessItem('Intent Enum Valid', result.query != null),
              _buildCorrectnessItem('Canonical Action Filter', result.query?.actionType == null || result.query!.actionType!.isNotEmpty),
              _buildCorrectnessItem('Database Execution Safe', result.error == null),
              const SizedBox(height: 12),

              // Structured SearchQuery
              if (result.query != null) ...[
                const Text('🔍 Structured Query JSON (Resolved)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildCorrectnessItem(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: isValid ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  SearchQuery _buildCurrentQuery({int page = 1}) {
    final offset = (page - 1) * _pageSize;
    final rawSearch = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
    final rawDriver = _driverController.text.trim().isEmpty ? null : _driverController.text.trim();
    final rawCity = _cityController.text.trim().isEmpty ? null : _cityController.text.trim();
    final rawCountry = _selectedCountry == 'ALL' ? null : _selectedCountry;
    final rawAction = _selectedActionType == 'ALL' ? null : _selectedActionType.toLowerCase();

    return SearchQuery(
      intent: _selectedIntent,
      rallyName: rawSearch,
      eventName: rawSearch,
      driverName: rawDriver,
      city: rawCity,
      country: rawCountry,
      actionType: rawAction,
      year: _selectedYear,
      limit: _pageSize,
      offset: offset,
    );
  }

  Future<void> _executeSearch({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = _buildCurrentQuery(page: _currentPage);
      final response = await _repository.search(query);

      if (mounted) {
        setState(() {
          _searchResponse = response;
          _totalCount = response.totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Search failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _nlController.clear();
      _searchController.clear();
      _driverController.clear();
      _cityController.clear();
      _selectedCountry = 'ALL';
      _selectedActionType = 'ALL';
      _selectedYear = null;
      _interpretedSummary = null;
      _clarificationQuestion = null;
      _lastExecutedNlQuery = null;
    });
    _executeSearch(resetPage: true);
  }

  Map<String, dynamic> get _currentIntentConfig {
    return _intentOptions.firstWhere(
      (opt) => opt['intent'] == _selectedIntent,
      orElse: () => _intentOptions.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalPages = (_totalCount / _pageSize).ceil();
    final intentConfig = _currentIntentConfig;

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
          IconButton(
            tooltip: 'Clear Filters',
            icon: const Icon(Icons.filter_alt_off_rounded),
            onPressed: _clearFilters,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _executeSearch(),
          ),
        ],

      ),
      body: Column(
        children: [
          // Filter Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Natural Language AI Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nlController,
                        textDirection: _selectedLanguage.isRtl ? TextDirection.rtl : TextDirection.ltr,
                        textAlign: _selectedLanguage.isRtl ? TextAlign.right : TextAlign.left,
                        decoration: InputDecoration(
                          hintText: 'Ask in plain English (e.g. "Show jumps featuring Moffett in 2025")...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF1E88E5), size: 20),
                          suffixIcon: _nlController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _nlController.clear();
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
                      onTranscriptReceived: (transcript) {
                        setState(() {
                          _nlController.text = transcript;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _executeNaturalLanguageSearch,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('AI Search'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Intent Selector (Dropdown)
                DropdownButtonFormField<SearchIntent>(
                  value: _selectedIntent,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Search Query Intent',
                    prefixIcon: Icon(intentConfig['icon'] as IconData, size: 20, color: theme.colorScheme.primary),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
                  items: _intentOptions.map((opt) {
                    return DropdownMenuItem<SearchIntent>(
                      value: opt['intent'] as SearchIntent,
                      child: Row(
                        children: [
                          Icon(opt['icon'] as IconData, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              opt['label'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedIntent = val);
                      _executeSearch(resetPage: true);
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Primary Search / Rally input
                if (_selectedIntent != SearchIntent.getTopDriversByWins)
                  TextField(
                    controller: _selectedIntent == SearchIntent.searchDriverRallies ||
                            _selectedIntent == SearchIntent.searchDriverWins ||
                            _selectedIntent == SearchIntent.searchDriverVideos
                        ? _driverController
                        : _searchController,
                    decoration: InputDecoration(
                      hintText: intentConfig['hint'] as String,
                      prefixIcon: Icon(
                        _selectedIntent == SearchIntent.searchDriverRallies ||
                                _selectedIntent == SearchIntent.searchDriverWins ||
                                _selectedIntent == SearchIntent.searchDriverVideos
                            ? Icons.person_rounded
                            : Icons.search_rounded,
                      ),
                      suffixIcon: (_selectedIntent == SearchIntent.searchDriverRallies ||
                                  _selectedIntent == SearchIntent.searchDriverWins ||
                                  _selectedIntent == SearchIntent.searchDriverVideos
                              ? _driverController.text.isNotEmpty
                              : _searchController.text.isNotEmpty)
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                if (_selectedIntent == SearchIntent.searchDriverRallies ||
                                    _selectedIntent == SearchIntent.searchDriverWins ||
                                    _selectedIntent == SearchIntent.searchDriverVideos) {
                                  _driverController.clear();
                                } else {
                                  _searchController.clear();
                                }
                                _executeSearch(resetPage: true);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      ),
                    ),
                    onSubmitted: (_) => _executeSearch(resetPage: true),
                  ),

                // Contextual Filter Row (Country, Year, Action Type)
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Country filter
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Country',
                          prefixIcon: const Icon(Icons.public_rounded, size: 18),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                        ),
                        items: _countryOptions.map((c) {
                          return DropdownMenuItem(
                            value: c['value'],
                            child: Text(
                              c['label']!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCountry = val);
                            _executeSearch(resetPage: true);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Year Filter
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<int?>(
                        value: _selectedYear,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Year',
                          prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                        ),
                        items: _yearOptions.map((yr) {
                          return DropdownMenuItem(
                            value: yr,
                            child: Text(
                              yr == null ? 'All Years' : '$yr',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedYear = val);
                          _executeSearch(resetPage: true);
                        },
                      ),
                    ),

                    // Action Type (if Video Actions selected)
                    if (_selectedIntent == SearchIntent.searchVideoActions) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          value: _selectedActionType,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Action',
                            prefixIcon: const Icon(Icons.bolt_rounded, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                          ),
                          items: _actionOptions.map((act) {
                            return DropdownMenuItem(
                              value: act,
                              child: Text(act, style: const TextStyle(fontSize: 12.5)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedActionType = val);
                              _executeSearch(resetPage: true);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),

                // City filter expander
                if (_showExtraFilters) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: 'City (e.g. Letterkenny, Fafe, Newtown)',
                      prefixIcon: const Icon(Icons.location_city_rounded, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      ),
                    ),
                    onSubmitted: (_) => _executeSearch(resetPage: true),
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showExtraFilters = !_showExtraFilters),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _showExtraFilters ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showExtraFilters ? 'Fewer Filters' : 'City Filter',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _executeSearch(resetPage: true),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Clarification Question Banner & Candidate Selection
          if (_clarificationQuestion != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.help_outline_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Clarification Needed',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _clarificationQuestion!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _clarificationQuestion = null;
                          _clarificationCandidates = [];
                        }),
                      ),
                    ],
                  ),
                  if (_clarificationCandidates.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Suggested options:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _clarificationCandidates.map((candidate) {
                        final typeIcon = candidate.type == EntityType.driver
                            ? Icons.person_rounded
                            : (candidate.type == EntityType.rally
                                ? Icons.flag_rounded
                                : (candidate.type == EntityType.stage
                                    ? Icons.alt_route_rounded
                                    : Icons.location_city_rounded));
                        return ActionChip(
                          avatar: Icon(typeIcon, size: 16, color: theme.colorScheme.primary),
                          label: Text(
                            candidate.subtitle != null
                                ? '${candidate.canonicalName} (${candidate.subtitle})'
                                : candidate.canonicalName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => _onSelectCandidate(candidate),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

          // Interpreted Query Banner
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
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() => _interpretedSummary = null),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16),
                    ),
                  ),
                ],
              ),
            ),

          // Count bar
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
                        TextSpan(text: ' ${_resultTypeLabel(_selectedIntent)}'),
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

          // Dynamic Result View Dispatcher
          Expanded(
            child: _buildDynamicResultsView(context),
          ),

          // Pagination Footer
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Executing deterministic search...'),
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
                onPressed: () => _executeSearch(),
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
                'Try broadening your search query or resetting filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Reset Filters'),
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
              // Drilldown to top finishers
              setState(() {
                _selectedIntent = SearchIntent.getRallyTopFinishers;
                _searchController.text = rallies[idx].eventName;
              });
              _executeSearch(resetPage: true);
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
            rallyName: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
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
            rallyName: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
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
                _selectedIntent = SearchIntent.searchDriverWins;
                _driverController.text = d.driverName;
              });
              _executeSearch(resetPage: true);
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
                      _executeSearch();
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
                      _executeSearch();
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
