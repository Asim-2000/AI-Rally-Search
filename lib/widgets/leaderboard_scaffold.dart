import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared container + header for the ranking widgets (finishers, driver wins,
/// uploaders). Replaces the three divergent full-bleed gradients with one
/// restrained, accent-tinted header so the leaderboards read as one system.
///
/// The caller supplies its own table header row and rows as [child]; this
/// scaffold owns only the outer shell and the title header.
class LeaderboardScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Short count label shown as a pill on the right (e.g. "12 finishers").
  final String? countLabel;
  final Widget child;

  const LeaderboardScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Restrained accent-tinted header (no gradient).
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: isDark ? 0.16 : 0.10),
              border: Border(
                bottom: BorderSide(color: palette.border),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: palette.accent, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (countLabel != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Text(
                      countLabel!,
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
