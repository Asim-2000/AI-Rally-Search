import 'package:flutter/material.dart';
import '../models/video_action.dart';

class VideoActionCard extends StatelessWidget {
  final VideoAction action;
  final ValueChanged<VideoAction>? onPlay;
  final bool isCompact;

  const VideoActionCard({
    super.key,
    required this.action,
    this.onPlay,
    this.isCompact = false,
  });

  Color _getActionColor(String type) {
    switch (type.toLowerCase()) {
      case 'jump':
        return Colors.amber.shade700;
      case 'drift':
        return Colors.deepPurple;
      case 'crash':
        return Colors.red.shade700;
      case 'spin':
        return Colors.orange.shade800;
      case 'start_line':
        return Colors.teal;
      case 'near_miss':
        return Colors.blueAccent;
      case 'offroad':
        return Colors.brown;
      case 'mechanical_failure':
        return Colors.grey.shade800;
      default:
        return const Color(0xFF1E88E5);
    }
  }

  IconData _getActionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'jump':
        return Icons.flight_takeoff_rounded;
      case 'drift':
        return Icons.turn_sharp_right_rounded;
      case 'crash':
        return Icons.warning_amber_rounded;
      case 'spin':
        return Icons.rotate_right_rounded;
      case 'start_line':
        return Icons.flag_rounded;
      case 'near_miss':
        return Icons.bolt_rounded;
      case 'offroad':
        return Icons.terrain_rounded;
      case 'mechanical_failure':
        return Icons.build_rounded;
      default:
        return Icons.play_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final actionColor = _getActionColor(action.actionType);

    if (isCompact) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Play icon
            InkWell(
              onTap: () => onPlay?.call(action),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: actionColor, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          action.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: actionColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        action.formattedTimeRange,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                  if (action.locationOrStageDescription != 'Full Stream Segment') ...[
                    const SizedBox(height: 2),
                    Text(
                      action.locationOrStageDescription,
                      style: TextStyle(fontSize: 10, color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Duration badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                action.formattedDuration,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: () => onPlay?.call(action),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail / Icon Surface
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 90,
                  height: 60,
                  color: const Color(0xFF14141E),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (action.thumbnailUrl != null && action.thumbnailUrl!.isNotEmpty)
                        Image.network(
                          action.thumbnailUrl!,
                          fit: BoxFit.cover,
                          width: 90,
                          height: 60,
                          errorBuilder: (_, __, ___) => _buildFallbackThumbnail(actionColor),
                        )
                      else
                        _buildFallbackThumbnail(actionColor),
                      // Play Overlay Icon
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      // Duration badge on thumbnail
                      Positioned(
                        bottom: 3,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            action.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Action Content Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: actionColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getActionIcon(action.actionType),
                                size: 12,
                                color: actionColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                action.title,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: actionColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          action.formattedTimeRange,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.locationOrStageDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action Arrow / Play Trigger
              IconButton(
                icon: Icon(
                  Icons.play_circle_filled_rounded,
                  color: actionColor,
                  size: 28,
                ),
                onPressed: () => onPlay?.call(action),
                tooltip: 'Play ${action.title}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(Color actionColor) {
    return Container(
      color: const Color(0xFF181824),
      child: Center(
        child: Icon(
          _getActionIcon(action.actionType),
          color: actionColor.withValues(alpha: 0.5),
          size: 28,
        ),
      ),
    );
  }
}
