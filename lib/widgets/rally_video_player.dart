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

  /// When true, playback is gated: the video is discoverable from offline
  /// metadata but streaming is unavailable. The player shows the rally-themed
  /// "stream's off-stage" state instead of attempting a network load.
  final bool offline;

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
    this.offline = false,
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
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.initialStartTime != widget.initialStartTime ||
        oldWidget.initialEndTime != widget.initialEndTime ||
        oldWidget.initialAction != widget.initialAction) {
      _currentUrl = widget.videoUrl;
      _activeAction = widget.initialAction;
      _actionEndTime = widget.initialAction?.endTime ?? widget.initialEndTime;
      _initializePlayer(
        seekToSeconds: widget.initialAction?.startTime ?? widget.initialStartTime,
        autoPlay: widget.autoPlay || widget.initialAction != null,
      );
    }
  }

  Future<void> _initializePlayer({double? seekToSeconds, bool autoPlay = false}) async {
    if (_isLoading) return;

    // Offline: never attempt a network stream. Playback is gated.
    if (widget.offline) {
      setState(() {
        _hasError = true;
        _errorMessage = "You're offline, so the video can't play right now.";
      });
      return;
    }

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
              initialStartTime: widget.initialStartTime,
              initialEndTime: _actionEndTime,
            ),
          ),
        ),
      ),
    );
  }

  void _playerListener() {
    if (!mounted || _controller == null || !_isInitialized) return;

    final clipStart = _activeAction?.startTime ?? widget.initialStartTime;
    final clipEnd = _activeAction?.endTime ?? _actionEndTime;

    // Check if a clip segment boundary is active
    if (clipEnd != null && clipEnd > 0) {
      final currentMillis = _controller!.value.position.inMilliseconds;
      final startMillis = ((clipStart ?? 0.0) * 1000).toInt();
      final endMillis = (clipEnd * 1000).toInt();

      // Guard: prevent playing or seeking before clip start
      if (currentMillis < startMillis - 500) {
        _controller!.seekTo(Duration(milliseconds: startMillis));
      }

      // Automatically pause when position reaches or exceeds action/clip endTime
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

      final clipStart = _activeAction?.startTime ?? widget.initialStartTime ?? 0.0;
      final clipEnd = _activeAction?.endTime ?? _actionEndTime;

      // If active action or clip reached its end, replay from startTime
      if (clipEnd != null && clipEnd > 0) {
        final endMillis = (clipEnd * 1000).toInt();
        final startMillis = (clipStart * 1000).toInt();
        if (pos.inMilliseconds >= endMillis || pos.inMilliseconds < startMillis) {
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

            // Offline playback gate: metadata found, stream unavailable.
            if (widget.offline && !_isInitialized)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 34),
                      SizedBox(height: 8),
                      Text("Found the clip — but the stream's off-stage",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text("You're offline, so the video can't play right now.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),

            // Initial Play Button before load
            if (!widget.offline && !_isInitialized && !_isLoading && !_hasError)
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
                            : ((_actionEndTime != null && _actionEndTime! > 0)
                                ? 'Tap to Play Clip (${_formatDuration(Duration(milliseconds: (((widget.initialStartTime ?? 0.0) * 1000).toInt())))} → ${_formatDuration(Duration(milliseconds: ((_actionEndTime! * 1000).toInt())))})'
                                : 'Tap to Play Stream'),
                        style: TextStyle(
                          color: _activeAction != null ? Colors.amber : (_actionEndTime != null ? Colors.amber : Colors.white70),
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

    final clipStart = _activeAction?.startTime ?? widget.initialStartTime;
    final clipEnd = _activeAction?.endTime ?? _actionEndTime;
    final bool isClipMode = (clipEnd != null && clipEnd > 0) || (clipStart != null && clipStart > 0);

    final double segmentStart = clipStart ?? 0.0;
    final double segmentEnd = clipEnd ?? (duration.inMilliseconds / 1000.0);
    final double segmentDuration = (segmentEnd > segmentStart) ? (segmentEnd - segmentStart) : 0.0;
    final int segmentDurationMillis = (segmentDuration * 1000).toInt();

    final int currentRelativeMillis = isClipMode
        ? (position.inMilliseconds - (segmentStart * 1000).toInt()).clamp(0, segmentDurationMillis)
        : position.inMilliseconds;

    final int totalRelativeMillis = isClipMode
        ? segmentDurationMillis
        : duration.inMilliseconds;

    final isActionFinished = isClipMode &&
        clipEnd != null &&
        clipEnd > 0 &&
        position.inMilliseconds >= (clipEnd * 1000).toInt();

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
              // Top Bar with Action/Clip Pill or Title
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
                            ],
                          ),
                        ),
                      )
                    else if (_actionEndTime != null && _actionEndTime! > 0)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.movie_filter_rounded, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Clip (${_formatDuration(Duration(milliseconds: (((widget.initialStartTime ?? 0.0) * 1000).toInt())))} → ${_formatDuration(Duration(milliseconds: ((_actionEndTime! * 1000).toInt())))})',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                      color: (_activeAction != null || _actionEndTime != null) ? Colors.amber : Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),

              // Bottom Progress Bar & Timestamps (Restricted to clip duration)
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
                        activeTrackColor: (_activeAction != null || _actionEndTime != null) ? Colors.amber : theme.colorScheme.primary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: totalRelativeMillis > 0
                            ? currentRelativeMillis
                                .toDouble()
                                .clamp(0.0, totalRelativeMillis.toDouble())
                            : 0.0,
                        min: 0.0,
                        max: totalRelativeMillis > 0
                            ? totalRelativeMillis.toDouble()
                            : 1.0,
                        onChanged: (val) {
                          if (isClipMode) {
                            final targetMillis = (segmentStart * 1000).toInt() + val.toInt();
                            _controller?.seekTo(Duration(milliseconds: targetMillis));
                          } else {
                            _controller?.seekTo(Duration(milliseconds: val.toInt()));
                          }
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
                            _formatDuration(Duration(milliseconds: currentRelativeMillis)),
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
                            )
                          else if (_actionEndTime != null && _actionEndTime! > 0)
                            Flexible(
                              child: Text(
                                'Clip: ${_formatDuration(Duration(milliseconds: (((widget.initialStartTime ?? 0.0) * 1000).toInt())))} → ${_formatDuration(Duration(milliseconds: ((_actionEndTime! * 1000).toInt())))}',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            _formatDuration(Duration(milliseconds: totalRelativeMillis)),
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
