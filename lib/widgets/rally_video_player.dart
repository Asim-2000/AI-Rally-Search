import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_action.dart';

class RallyVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;
  final double aspectRatio;
  final String? videoTitle;
  final VideoAction? initialAction;
  final double? initialStartTime;
  final double? initialEndTime;
  final VoidCallback? onActionCompleted;

  const RallyVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.aspectRatio = 16 / 9,
    this.videoTitle,
    this.initialAction,
    this.initialStartTime,
    this.initialEndTime,
    this.onActionCompleted,
  });

  @override
  State<RallyVideoPlayer> createState() => RallyVideoPlayerState();
}

class RallyVideoPlayerState extends State<RallyVideoPlayer> {
  VideoPlayerController? _controller;
  String? _currentUrl;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isMuted = false;
  bool _showOverlay = true;

  // Active Action Segment State
  VideoAction? _activeAction;
  double? _actionEndTime;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.videoUrl;
    if (widget.initialAction != null) {
      _activeAction = widget.initialAction;
      _actionEndTime = widget.initialAction!.endTime;
    } else if (widget.initialEndTime != null) {
      _actionEndTime = widget.initialEndTime;
    }

    if (widget.autoPlay || widget.initialAction != null || widget.initialStartTime != null) {
      _initializePlayer(
        seekToSeconds: widget.initialAction?.startTime ?? widget.initialStartTime,
        autoPlay: widget.autoPlay || widget.initialAction != null,
      );
    }
  }

  @override
  void didUpdateWidget(covariant RallyVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _currentUrl = widget.videoUrl;
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer({double? seekToSeconds, bool autoPlay = false}) async {
    if (_isLoading) return;

    final targetUrl = _activeAction?.videoUrl ?? _currentUrl ?? widget.videoUrl;
    if (targetUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video URL provided';
      });
      return;
    }

    if (_controller != null) {
      _controller!.removeListener(_playerListener);
      await _controller!.dispose();
      _controller = null;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _currentUrl = targetUrl;
    });

    try {
      final uri = Uri.parse(targetUrl);
      _controller = VideoPlayerController.networkUrl(uri);

      await _controller!.initialize();
      _controller!.addListener(_playerListener);

      if (seekToSeconds != null && seekToSeconds > 0) {
        await _controller!.seekTo(Duration(milliseconds: (seekToSeconds * 1000).toInt()));
      }

      if (autoPlay) {
        await _controller!.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Reusable method to play a specific action moment inside the source video
  Future<void> playAction(VideoAction action) async {
    _activeAction = action;
    _actionEndTime = action.endTime;

    final targetUrl = (action.videoUrl != null && action.videoUrl!.isNotEmpty)
        ? action.videoUrl!
        : (_currentUrl ?? widget.videoUrl);

    // If controller is not initialized or points to a different URL
    if (!_isInitialized || _controller == null || _currentUrl != targetUrl) {
      _currentUrl = targetUrl;
      await _initializePlayer(
        seekToSeconds: action.startTime,
        autoPlay: true,
      );
      return;
    }

    // Video is already initialized for this URL: seek directly to action start and play
    try {
      final startMillis = (action.startTime * 1000).toInt().clamp(0, _controller!.value.duration.inMilliseconds);
      await _controller!.seekTo(Duration(milliseconds: startMillis));
      await _controller!.play();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to seek action: $e';
        });
      }
    }
  }

  /// Plays the full source video from the beginning without action bounds
  void playFullVideo() {
    setState(() {
      _activeAction = null;
      _actionEndTime = null;
    });
    if (_controller != null && _isInitialized) {
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    } else {
      _initializePlayer(autoPlay: true);
    }
  }

  void _playerListener() {
    if (!mounted || _controller == null || !_isInitialized) return;

    // Check if an action segment boundary is active
    if (_activeAction != null && _actionEndTime != null && _actionEndTime! > 0) {
      final currentMillis = _controller!.value.position.inMilliseconds;
      final endMillis = (_actionEndTime! * 1000).toInt();

      // Automatically pause when position reaches or exceeds action endTime
      if (_controller!.value.isPlaying && currentMillis >= endMillis) {
        _controller!.pause();
        widget.onActionCompleted?.call();
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) {
      _initializePlayer(
        seekToSeconds: _activeAction?.startTime ?? widget.initialStartTime,
        autoPlay: true,
      );
      return;
    }

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      final pos = _controller!.value.position;
      final dur = _controller!.value.duration;

      // If active action reached its end, replay the action from startTime
      if (_activeAction != null && _actionEndTime != null) {
        final endMillis = (_actionEndTime! * 1000).toInt();
        if (pos.inMilliseconds >= endMillis) {
          final startMillis = (_activeAction!.startTime * 1000).toInt();
          _controller!.seekTo(Duration(milliseconds: startMillis));
        }
      } else if (pos >= dur && dur > Duration.zero) {
        _controller!.seekTo(Duration.zero);
      }
      _controller!.play();
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              _activeAction != null
                  ? '${_activeAction!.title} (${_activeAction!.formattedTimeRange})'
                  : (widget.videoTitle ?? 'Video Player'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          body: Center(
            child: RallyVideoPlayer(
              videoUrl: _currentUrl ?? widget.videoUrl,
              autoPlay: true,
              aspectRatio: 16 / 9,
              videoTitle: widget.videoTitle,
              initialAction: _activeAction,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Surface or Placeholder
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio > 0
                      ? _controller!.value.aspectRatio
                      : widget.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              _buildPlaceholder(context),

            // Loading Indicator
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // Error Overlay
            if (_hasError) _buildErrorOverlay(context),

            // Interactive Controls Overlay
            if (_isInitialized && !_hasError && widget.showControls)
              _buildControlsOverlay(theme),

            // Initial Play Button before load
            if (!_isInitialized && !_isLoading && !_hasError)
              Center(
                child: InkWell(
                  onTap: () => _initializePlayer(
                    seekToSeconds: _activeAction?.startTime ?? widget.initialStartTime,
                    autoPlay: true,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: const Color(0xFF14141E),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background icon
          Opacity(
            opacity: 0.08,
            child: Icon(
              _activeAction != null ? Icons.bolt_rounded : Icons.videocam_rounded,
              size: 100,
              color: Colors.white,
            ),
          ),
          Positioned(
            bottom: 12,
            left: 14,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _activeAction != null ? Icons.bolt_rounded : Icons.ondemand_video_rounded,
                        color: _activeAction != null ? Colors.amber : Colors.white70,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _activeAction != null
                            ? 'Tap to Play Action (${_activeAction!.formattedTimeRange})'
                            : 'Tap to Play Stream',
                        style: TextStyle(
                          color: _activeAction != null ? Colors.amber : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            const Text(
              'Unable to stream video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage ?? 'Network or codec issue',
              style: const TextStyle(color: Colors.white60, fontSize: 10),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _initializePlayer(
                seekToSeconds: _activeAction?.startTime ?? widget.initialStartTime,
                autoPlay: true,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Retry', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(80, 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(ThemeData theme) {
    final isPlaying = _controller!.value.isPlaying;
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    final isActionFinished = _activeAction != null &&
        _actionEndTime != null &&
        position.inMilliseconds >= (_actionEndTime! * 1000).toInt();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _showOverlay = !_showOverlay;
        });
      },
      child: AnimatedOpacity(
        opacity: _showOverlay || !isPlaying ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.8),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar with Action Pill or Title
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_activeAction != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${_activeAction!.title} (${_activeAction!.formattedTimeRange})',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: playFullVideo,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Full',
                                    style: TextStyle(color: Colors.white70, fontSize: 9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (widget.videoTitle != null)
                      Flexible(
                        child: Text(
                          widget.videoTitle!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        // Mute button
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _toggleMute,
                          tooltip: _isMuted ? 'Unmute' : 'Mute',
                          visualDensity: VisualDensity.compact,
                        ),
                        // Fullscreen button
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _openFullscreen(context),
                          tooltip: 'Fullscreen',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Center Play/Pause / Replay Button
              Center(
                child: InkWell(
                  onTap: _togglePlayPause,
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : (isActionFinished || (position >= duration && duration > Duration.zero)
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded),
                      color: _activeAction != null ? Colors.amber : Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),

              // Bottom Progress Bar & Timestamps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Video Progress Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: _activeAction != null ? Colors.amber : theme.colorScheme.primary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds
                                .toDouble()
                                .clamp(0.0, duration.inMilliseconds.toDouble())
                            : 0.0,
                        min: 0.0,
                        max: duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1.0,
                        onChanged: (val) {
                          _controller?.seekTo(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),

                    // Timestamp indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (_activeAction != null)
                            Flexible(
                              child: Text(
                                'Action: ${_activeAction!.formattedTimeRange}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
