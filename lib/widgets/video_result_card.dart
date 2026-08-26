import 'package:flutter/material.dart';
import '../models/search_results.dart';
import '../models/video_action.dart';
import 'action_player_modal.dart';

class VideoResultCard extends StatelessWidget {
  final VideoSearchResult video;
  final Function(VideoSearchResult)? onPlay;

  const VideoResultCard({
    super.key,
    required this.video,
    this.onPlay,
  });

  void _handlePlay(BuildContext context) {
    if (onPlay != null) {
      onPlay!(video);
      return;
    }

    if (video.videoUrl != null && video.videoUrl!.isNotEmpty) {
      // Create VideoAction adapter to use existing ActionPlayerModal
      final actionAdapter = VideoAction(
        id: video.videoId,
        videoId: video.videoId,
        streamId: video.streamId,
        actionType: 'driver_feature',
        title: video.driverName != null ? 'Feature: ${video.driverName}' : 'Rally Video',
        startTime: 0.0,
        endTime: video.videoLengthSeconds ?? 60.0,
        duration: video.videoLengthSeconds ?? 60.0,
        thumbnailUrl: video.thumbnailUrl,
        videoUrl: video.videoUrl,
        eventName: video.eventName,
        stageName: video.stageName,
        stageNumber: video.stageNumber,
      );

      ActionPlayerModal.show(context, actionAdapter);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video stream URL is not available for this recording.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handlePlay(context),
        child: Row(
          children: [
            // Thumbnail container with play button
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 130,
                  height: 95,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  child: video.thumbnailUrl != null
                      ? Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _buildPlaceholder(isDark),
                        )
                      : _buildPlaceholder(isDark),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (video.videoLengthSeconds != null && video.videoLengthSeconds! > 0)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.formattedLength,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),

            // Video info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (video.eventName != null && video.eventName!.isNotEmpty)
                      Text(
                        video.eventName!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      video.stageName != null
                          ? '${video.stageNumber != null ? "SS${video.stageNumber}: " : ""}${video.stageName}'
                          : 'Full Stage Recording',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (video.driverName != null && video.driverName!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              video.driverName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Icon(
        Icons.videocam_rounded,
        size: 32,
        color: isDark ? Colors.white30 : Colors.grey.shade400,
      ),
    );
  }
}
