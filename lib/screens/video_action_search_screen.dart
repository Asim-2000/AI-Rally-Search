import 'package:flutter/material.dart';
import '../models/video_action.dart';
import '../models/video_action_search_query.dart';
import '../services/video_action_repository.dart';
import '../widgets/action_player_modal.dart';
import '../widgets/video_action_card.dart';

class VideoActionSearchScreen extends StatefulWidget {
  final VideoActionSearchQuery? initialQuery;

  const VideoActionSearchScreen({super.key, this.initialQuery});

  @override
  State<VideoActionSearchScreen> createState() => _VideoActionSearchScreenState();
}

class _VideoActionSearchScreenState extends State<VideoActionSearchScreen> {
  final VideoActionRepository _repository = VideoActionRepository();

  // Search input controllers
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _stageNameController = TextEditingController();
  final TextEditingController _stageNumberController = TextEditingController();

  String _selectedActionType = 'ALL';
  String _selectedCountry = 'ALL';

  // Pagination state
  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;

  bool _isLoading = false;
  String? _errorMessage;
  List<VideoAction> _actions = [];

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
    {'label': 'Austria (AT)', 'value': 'Austria'},
    {'label': 'United Kingdom (GB / UK)', 'value': 'United Kingdom'},
    {'label': 'Ireland (IE)', 'value': 'Ireland'},
    {'label': 'Portugal (PT)', 'value': 'Portugal'},
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

  bool _showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      final q = widget.initialQuery!;
      if (q.actionType != null) {
        _selectedActionType = _formatActionName(q.actionType!);
      }
      if (q.country != null) {
        _selectedCountry = q.country!;
      }
      if (q.eventName != null) {
        _keywordController.text = q.eventName!;
      }
      if (q.stageName != null) {
        _stageNameController.text = q.stageName!;
      }
      if (q.stageNumber != null) {
        _stageNumberController.text = q.stageNumber!;
      }
    }
    _executeSearch(resetPage: true);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _stageNameController.dispose();
    _stageNumberController.dispose();
    super.dispose();
  }

  String _formatActionName(String raw) {
    for (final opt in _actionOptions) {
      if (opt.toLowerCase() == raw.toLowerCase() ||
          '${opt.toLowerCase()}_segments' == raw.toLowerCase()) {
        return opt;
      }
    }
    return raw;
  }

  VideoActionSearchQuery _buildCurrentQuery({int page = 1}) {
    final offset = (page - 1) * _pageSize;
    final rawAction = _selectedActionType == 'ALL' ? null : _selectedActionType.toLowerCase();
    final rawCountry = _selectedCountry == 'ALL' ? null : _selectedCountry;
    final rawEvent = _keywordController.text.trim().isEmpty ? null : _keywordController.text.trim();
    final rawStageName = _stageNameController.text.trim().isEmpty ? null : _stageNameController.text.trim();
    final rawStageNum = _stageNumberController.text.trim().isEmpty ? null : _stageNumberController.text.trim();

    return VideoActionSearchQuery(
      actionType: rawAction,
      country: rawCountry,
      eventName: rawEvent,
      stageName: rawStageName,
      stageNumber: rawStageNum,
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
      final count = await _repository.countVideoActions(query);
      final results = await _repository.searchVideoActions(query);

      if (mounted) {
        setState(() {
          _totalCount = count;
          _actions = results;
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
      _keywordController.clear();
      _stageNameController.clear();
      _stageNumberController.clear();
      _selectedActionType = 'ALL';
      _selectedCountry = 'ALL';
    });
    _executeSearch(resetPage: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalPages = (_totalCount / _pageSize).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.manage_search_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Action Moments Search',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear All Filters',
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
          // Filter card
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
                // Keyword / Event Name Search
                TextField(
                  controller: _keywordController,
                  decoration: InputDecoration(
                    hintText: 'Search by Rally Event (e.g. Trackrod, OBM Land)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _keywordController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _keywordController.clear();
                              _executeSearch(resetPage: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _executeSearch(resetPage: true),
                ),
                const SizedBox(height: 10),

                // Action type & Country dropdowns
                Row(
                  children: [
                    // Action dropdown
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        value: _selectedActionType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Action Type',
                          prefixIcon: const Icon(Icons.bolt_rounded, size: 20),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        items: _actionOptions.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type == 'ALL' ? 'All Actions' : type,
                              style: TextStyle(
                                fontWeight: type == 'ALL' ? FontWeight.normal : FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                    const SizedBox(width: 8),

                    // Country dropdown
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Country / Location',
                          prefixIcon: const Icon(Icons.public_rounded, size: 20),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        items: _countryOptions.map((country) {
                          return DropdownMenuItem(
                            value: country['value'],
                            child: Text(
                              country['label']!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
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
                  ],
                ),

                // Advanced filters expander
                if (_showAdvancedFilters) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _stageNameController,
                          decoration: InputDecoration(
                            labelText: 'Stage Name (e.g. Gale Rigg)',
                            prefixIcon: const Icon(Icons.map_rounded, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _executeSearch(resetPage: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _stageNumberController,
                          decoration: InputDecoration(
                            labelText: 'Stage # (e.g. 3)',
                            prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _executeSearch(resetPage: true),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _showAdvancedFilters
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showAdvancedFilters ? 'Less Filters' : 'Stage Filters',
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results count bar
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
                        const TextSpan(text: ' action moments'),
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

          // Search results
          Expanded(
            child: _buildResultsView(context),
          ),

          // Pagination controls footer
          if (_totalCount > _pageSize) _buildPaginationFooter(totalPages),
        ],
      ),
    );
  }

  Widget _buildResultsView(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching action moments...'),
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

    if (_actions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'No action moments found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try broadening your search filters or resetting all filters.',
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

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _actions.length,
      itemBuilder: (context, index) {
        final action = _actions[index];
        return VideoActionCard(
          action: action,
          onPlay: (act) => ActionPlayerModal.show(context, act),
        );
      },
    );
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
