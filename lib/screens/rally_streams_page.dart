import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rally_stream.dart';
import '../models/video_action.dart';
import '../services/database_service.dart';
import '../services/video_action_repository.dart';
import '../widgets/rally_video_player.dart';
import '../widgets/video_action_card.dart';
import '../widgets/action_player_modal.dart';
import 'general_search_screen.dart';
import 'video_action_search_screen.dart';

class RallyStreamsPage extends StatefulWidget {
  const RallyStreamsPage({super.key});

  @override
  State<RallyStreamsPage> createState() => _RallyStreamsPageState();
}

class _RallyStreamsPageState extends State<RallyStreamsPage> {
  final DatabaseService _dbService = DatabaseService();
  final VideoActionRepository _actionRepo = VideoActionRepository();

  List<RallyStream> _streams = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Pagination state - Default limit is 10
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalCount = 0;

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedVideoType = 'ALL';
  String _selectedClipStatus = 'ALL';
  String _sortBy = 'id';
  bool _sortAscending = false;

  final List<String> _videoTypes = [
    'ALL',
    'sendObs',
    'startFirstVideo',
    'nonLive',
  ];

  final List<String> _clipStatuses = [
    'ALL',
    'complete',
    'live',
  ];

  @override
  void initState() {
    super.initState();
    _fetchStreams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStreams({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offset = (_currentPage - 1) * _pageSize;

      final total = await _dbService.getRallyStreamsCount(
        searchQuery: _searchQuery,
        videoType: _selectedVideoType,
        clipStatus: _selectedClipStatus,
      );

      final rows = await _dbService.getRallyStreams(
        limit: _pageSize,
        offset: offset,
        searchQuery: _searchQuery,
        videoType: _selectedVideoType,
        clipStatus: _selectedClipStatus,
        sortBy: _sortBy,
        sortAscending: _sortAscending,
      );

      final streams = rows.map((r) => RallyStream.fromMap(r)).toList();

      if (mounted) {
        setState(() {
          _streams = streams;
          _totalCount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 999999);

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() {
      _currentPage = page;
    });
    _fetchStreams();
  }

  void _showJumpToPageDialog() {
    final textController = TextEditingController(text: _currentPage.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Jump to Page'),
          content: TextField(
            controller: textController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter page (1 - $_totalPages)',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(textController.text.trim());
                if (page != null && page >= 1 && page <= _totalPages) {
                  Navigator.pop(ctx);
                  _goToPage(page);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.play_circle_filled_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rally Streams',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _totalCount > 0
                        ? '$_totalCount playable streams in database'
                        : 'Database Video Player Registry',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const GeneralSearchScreen(),
                ),
              );
            },
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('General Search'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const VideoActionSearchScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Moments'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh',
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : () => _fetchStreams(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header
          _buildFilterBar(context),

          // Main Content
          Expanded(
            child: _buildBody(context),
          ),

          // Pagination Bottom Bar
          _buildPaginationBar(context),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box & Action Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Stream ID, Video ID, or URL...',
                    hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _fetchStreams(resetPage: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF252525) : const Color(0xFFF1F4F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                    _fetchStreams(resetPage: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() {
                    _searchQuery = _searchController.text;
                  });
                  _fetchStreams(resetPage: true);
                },
                icon: const Icon(Icons.filter_list_rounded, size: 18),
                label: const Text('Filter'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Video Type Dropdown
                _buildFilterChipDropdown(
                  label: 'Type: ${_selectedVideoType == 'ALL' ? 'All Types' : _selectedVideoType}',
                  icon: Icons.category_rounded,
                  items: _videoTypes,
                  selectedItem: _selectedVideoType,
                  onChanged: (val) {
                    if (val != null && val != _selectedVideoType) {
                      setState(() {
                        _selectedVideoType = val;
                      });
                      _fetchStreams(resetPage: true);
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Status Dropdown
                _buildFilterChipDropdown(
                  label: 'Status: ${_selectedClipStatus == 'ALL' ? 'All Statuses' : _selectedClipStatus}',
                  icon: Icons.flag_rounded,
                  items: _clipStatuses,
                  selectedItem: _selectedClipStatus,
                  onChanged: (val) {
                    if (val != null && val != _selectedClipStatus) {
                      setState(() {
                        _selectedClipStatus = val;
                      });
                      _fetchStreams(resetPage: true);
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Sort Dropdown
                _buildSortDropdown(context),

                if (_searchQuery.isNotEmpty ||
                    _selectedVideoType != 'ALL' ||
                    _selectedClipStatus != 'ALL' ||
                    _sortBy != 'id' ||
                    _sortAscending != false) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedVideoType = 'ALL';
                        _selectedClipStatus = 'ALL';
                        _sortBy = 'id';
                        _sortAscending = false;
                      });
                      _fetchStreams(resetPage: true);
                    },
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipDropdown({
    required String label,
    required IconData icon,
    required List<String> items,
    required String selectedItem,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selectedItem != 'ALL'
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedItem,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          items: items.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: selectedItem == type ? theme.colorScheme.primary : theme.hintColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    type == 'ALL' ? 'All' : type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selectedItem == type ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: '$_sortBy:$_sortAscending',
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          items: const [
            DropdownMenuItem(
              value: 'id:false',
              child: Text('Newest ID First', style: TextStyle(fontSize: 12)),
            ),
            DropdownMenuItem(
              value: 'id:true',
              child: Text('Oldest ID First', style: TextStyle(fontSize: 12)),
            ),
            DropdownMenuItem(
              value: 'clip_duration:false',
              child: Text('Longest Duration', style: TextStyle(fontSize: 12)),
            ),
            DropdownMenuItem(
              value: 'clip_duration:true',
              child: Text('Shortest Duration', style: TextStyle(fontSize: 12)),
            ),
            DropdownMenuItem(
              value: 'share_counter:false',
              child: Text('Most Shares', style: TextStyle(fontSize: 12)),
            ),
            DropdownMenuItem(
              value: 'download_counter:false',
              child: Text('Most Downloads', style: TextStyle(fontSize: 12)),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              final parts = val.split(':');
              setState(() {
                _sortBy = parts[0];
                _sortAscending = parts[1] == 'true';
              });
              _fetchStreams(resetPage: true);
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _streams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading playable streams from database...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _streams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load rally streams',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _fetchStreams(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_streams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            const Text(
              'No streams found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search query or filters',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchStreams(),
      child: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _streams.length,
            itemBuilder: (context, index) {
              final stream = _streams[index];
              return _buildStreamCard(context, stream);
            },
          ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStreamCard(BuildContext context, RallyStream stream) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final typeColor = _getVideoTypeColor(stream.videoType);
    final statusColor = _getStatusColor(stream.clipStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Stream ID, Video ID, Video Type, and Status
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Left group: Stream ID & Video ID
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stream ID Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag_rounded, size: 14, color: theme.colorScheme.primary),
                          Text(
                            '${stream.id}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Video ID Badge
                    if (stream.videoId != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Video #${stream.videoId}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Right group: Video Type & Status Chips
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Video Type Chip
                    if (stream.videoType != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          stream.videoType!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Clip Status Chip
                    if (stream.clipStatus != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              stream.clipStatus!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Embedded Playable Video Player
            if (stream.onDemandUrl != null && stream.onDemandUrl!.isNotEmpty) ...[
              RallyVideoPlayer(
                key: ValueKey('player_${stream.id}_${stream.onDemandUrl}_${stream.clipStartTime}_${stream.clipDuration}'),
                videoUrl: stream.onDemandUrl!,
                videoTitle: 'Stream #${stream.id} • Video #${stream.videoId ?? 'N/A'}',
                initialStartTime: stream.clipStartTime,
                initialEndTime: (stream.clipDuration != null && stream.clipDuration! > 0)
                    ? ((stream.clipStartTime ?? 0.0) + stream.clipDuration!)
                    : null,
                autoPlay: false,
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off_rounded, color: theme.hintColor),
                    const SizedBox(width: 8),
                    Text(
                      'No video stream available for this entry',
                      style: TextStyle(color: theme.hintColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Metadata Info: Duration, Clip Window, Start Time, Created At, Counters
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildMetaInfo(
                  icon: Icons.timer_outlined,
                  label: 'Clip Duration',
                  value: stream.formattedDuration,
                ),
                _buildMetaInfo(
                  icon: Icons.timelapse_rounded,
                  label: 'Clip Window',
                  value: stream.formattedClipRange,
                ),
                if (stream.clipStartTime != null && stream.clipStartTime! > 0)
                  _buildMetaInfo(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Start Offset',
                    value: '${stream.clipStartTime!.toStringAsFixed(1)}s',
                  ),
                _buildMetaInfo(
                  icon: Icons.calendar_today_outlined,
                  label: 'Created',
                  value: stream.formattedDate,
                ),
                _buildMetaInfo(
                  icon: Icons.share_outlined,
                  label: 'Shares',
                  value: '${stream.shareCounter}',
                ),
                _buildMetaInfo(
                  icon: Icons.download_outlined,
                  label: 'Downloads',
                  value: '${stream.downloadCounter}',
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Actions Row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (stream.onDemandUrl != null && stream.onDemandUrl!.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: stream.onDemandUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stream URL copied to clipboard!'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 13, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Text(
                            'Copy Link',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stream.videoId != null) ...[
                      TextButton.icon(
                        onPressed: () => _showStreamDetailsModal(context, stream, initialTab: 1),
                        icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                        label: const Text('Moments', style: TextStyle(fontSize: 12, color: Colors.amber)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    TextButton.icon(
                      onPressed: () => _showStreamDetailsModal(context, stream),
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      label: const Text('Stream Details', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.hintColor),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPaginationBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final startItem = _totalCount == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endItem = (_currentPage * _pageSize).clamp(0, _totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Summary Row: Summary Text & Per-Page Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Showing $startItem–$endItem of $_totalCount streams',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.hintColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Per page:',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _pageSize,
                        isDense: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        items: const [
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _pageSize) {
                            setState(() {
                              _pageSize = val;
                            });
                            _fetchStreams(resetPage: true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Bottom Navigation Row: Centered Pagination Controls
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // First Page Button
                  IconButton(
                    icon: const Icon(Icons.first_page_rounded, size: 20),
                    tooltip: 'First Page',
                    onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                    visualDensity: VisualDensity.compact,
                  ),

                  // Previous Page Button
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    tooltip: 'Previous Page',
                    onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                    visualDensity: VisualDensity.compact,
                  ),

                  const SizedBox(width: 4),

                  // Page Number Button (Clickable to jump)
                  InkWell(
                    onTap: _totalPages > 1 ? _showJumpToPageDialog : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEDF2F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $_currentPage of $_totalPages',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Next Page Button
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    tooltip: 'Next Page',
                    onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
                    visualDensity: VisualDensity.compact,
                  ),

                  // Last Page Button
                  IconButton(
                    icon: const Icon(Icons.last_page_rounded, size: 20),
                    tooltip: 'Last Page',
                    onPressed: _currentPage < _totalPages ? () => _goToPage(_totalPages) : null,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getVideoTypeColor(String? type) {
    switch (type) {
      case 'sendObs':
        return Colors.indigo;
      case 'startFirstVideo':
        return Colors.teal;
      case 'instantReplay':
        return Colors.deepOrange;
      case 'nonLive':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'complete':
        return Colors.green;
      case 'live':
        return Colors.blue;
      case 'failed':
      case 'error':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _showStreamDetailsModal(BuildContext context, RallyStream stream, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          initialIndex: initialTab,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF1E88E5), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Stream #${stream.id} Details',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Full Stream Info'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('Detected Moments'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Full Stream Details
                      ListView(
                        children: [
                          if (stream.onDemandUrl != null && stream.onDemandUrl!.isNotEmpty) ...[
                            RallyVideoPlayer(
                              videoUrl: stream.onDemandUrl!,
                              videoTitle: 'Stream #${stream.id}',
                              initialStartTime: stream.clipStartTime,
                              initialEndTime: (stream.clipDuration != null && stream.clipDuration! > 0)
                                  ? ((stream.clipStartTime ?? 0.0) + stream.clipDuration!)
                                  : null,
                              autoPlay: true,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildDetailItem('ID', '${stream.id}'),
                          _buildDetailItem('Video ID', stream.videoId?.toString() ?? 'N/A'),
                          _buildDetailItem('Video Type', stream.videoType ?? 'N/A'),
                          _buildDetailItem('Clip Status', stream.clipStatus ?? 'N/A'),
                          _buildDetailItem('Clip Window', stream.formattedClipRange),
                          _buildDetailItem('Clip Duration', '${stream.clipDuration ?? 0} seconds (${stream.formattedDuration})'),
                          _buildDetailItem('Clip Start Time', '${stream.clipStartTime ?? 0} seconds'),
                          _buildDetailItem('Created At', stream.formattedDate),
                          _buildDetailItem('Updated At', stream.updatedAt?.toString() ?? 'N/A'),
                          _buildDetailItem('Download Counter', '${stream.downloadCounter}'),
                          _buildDetailItem('Share Counter', '${stream.shareCounter}'),
                          _buildDetailItem('On Demand URL', stream.onDemandUrl ?? 'N/A', isUrl: true),
                        ],
                      ),

                      // Tab 2: Detected Moments / Video Actions
                      FutureBuilder<List<VideoAction>>(
                        future: stream.videoId != null
                            ? _actionRepo.getVideoActionsForVideo(
                                stream.videoId!,
                                defaultVideoUrl: stream.onDemandUrl,
                                defaultStreamId: stream.id,
                                defaultClipStartTime: stream.clipStartTime,
                                defaultClipDuration: stream.clipDuration,
                              )
                            : Future.value(<VideoAction>[]),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text('Loading detected action moments...'),
                                ],
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading moments: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          final actions = snapshot.data ?? [];
                          if (actions.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.bolt_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No action moments detected for this video yet',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Actions will appear here when detected for Video #${stream.videoId}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: actions.length,
                            itemBuilder: (context, index) {
                              final action = actions[index];
                              return VideoActionCard(
                                action: action,
                                onPlay: (act) {
                                  ActionPlayerModal.show(context, act);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String title, String value, {bool isUrl = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 14,
              fontFamily: isUrl ? 'monospace' : null,
              color: isUrl ? const Color(0xFF1E88E5) : null,
            ),
          ),
        ],
      ),
    );
  }
}
