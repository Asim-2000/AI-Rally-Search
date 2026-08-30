import 'package:flutter/material.dart';
import '../models/search_results.dart';
import '../theme/app_theme.dart';
import 'rally_card_shell.dart';

class RallyResultCard extends StatelessWidget {
  final RallySearchResult rally;
  final VoidCallback? onTap;

  const RallyResultCard({
    super.key,
    required this.rally,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: onTap != null,
      label: onTap != null ? 'View results for ${rally.eventName}' : null,
      child: RallyCardShell(
      onTap: onTap,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Thumbnail / Banner image
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  child: rally.thumbnailUrl != null
                      ? Image.network(
                          rally.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _buildPlaceholder(isDark),
                        )
                      : _buildPlaceholder(isDark),
                ),
                // Stages badge overlay
                if (rally.stagesCount > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alt_route_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${rally.stagesCount} stages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Status badge overlay if active/completed
                if (rally.status != null && rally.status!.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: rallyStatusColor(rally.status, isDark: isDark)
                            .withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        rally.status!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Rally details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rally.eventName,
                    style: AppText.cardTitle.copyWith(fontSize: 18),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Location row
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rally.formattedLocation,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Date row
                  if (rally.formattedDateRange.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            rally.formattedDateRange,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Whole-card tap drills into the rally's finishers.
                  if (onTap != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'View results',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports_motorsports_rounded,
            size: 48,
            color: isDark ? Colors.white30 : Colors.grey.shade400,
          ),
          const SizedBox(height: 6),
          Text(
            'Rally Event',
            style: TextStyle(
              color: isDark ? Colors.white30 : Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
