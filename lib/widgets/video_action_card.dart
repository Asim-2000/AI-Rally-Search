import 'package:flutter/material.dart';
import '../models/video_action.dart';
import '../theme/app_theme.dart';
import 'rally_card_shell.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visual = RallyActionVisual.forType(action.actionType, isDark: isDark);
    final actionColor = visual.color;

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
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
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

    return RallyCardShell(
      onTap: () => onPlay?.call(action),
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
                          errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(visual),
                        )
                      else
                        _buildFallbackThumbnail(visual),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                              visual.icon,
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
    );
  }

  Widget _buildFallbackThumbnail(RallyActionVisual visual) {
    return Container(
      color: const Color(0xFF181824),
      child: Center(
        child: Icon(
          visual.icon,
          color: visual.color.withValues(alpha: 0.6),
          size: 28,
        ),
      ),
    );
  }
}
