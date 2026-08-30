import 'package:flutter/material.dart';
import '../models/entity_candidate.dart';
import '../theme/app_theme.dart';

/// Inline clarification presented as a helpful question with comfortably
/// tappable candidate rows. Presentation only — selection still flows through
/// [onCandidateSelected], preserving the pending parsed query and canonical-ID
/// behaviour unchanged.
class ClarificationCard extends StatelessWidget {
  final String question;
  final List<EntityCandidate> candidates;
  final ValueChanged<EntityCandidate> onCandidateSelected;
  final VoidCallback? onDismiss;

  const ClarificationCard({
    super.key,
    required this.question,
    required this.candidates,
    required this.onCandidateSelected,
    this.onDismiss,
  });

  /// Contextual title derived from the candidate type when they agree,
  /// otherwise the backend-provided question.
  String get _title {
    if (candidates.isEmpty) return question;
    final types = candidates.map((c) => c.type).toSet();
    if (types.length != 1) return question;
    switch (types.first) {
      case EntityType.driver:
        return 'Which driver did you mean?';
      case EntityType.rally:
        return 'Which rally did you mean?';
      case EntityType.stage:
        return 'Which stage did you mean?';
      case EntityType.city:
        return 'Which location did you mean?';
      case EntityType.uploader:
        return 'Which uploader did you mean?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded,
                    color: palette.accent, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: palette.primaryText,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onDismiss,
                  ),
              ],
            ),
          ),
          ...candidates.map((c) => _candidateRow(context, palette, c)),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }

  Widget _candidateRow(
    BuildContext context,
    AppPalette palette,
    EntityCandidate candidate,
  ) {
    final subtitle = candidate.subtitle;
    return Semantics(
      button: true,
      label: subtitle != null
          ? '${candidate.canonicalName}, $subtitle'
          : candidate.canonicalName,
      child: InkWell(
        onTap: () => onCandidateSelected(candidate),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: Row(
            children: [
              Icon(_iconFor(candidate.type), size: 20, color: palette.accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.canonicalName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.primaryText,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: palette.secondaryText),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(EntityType type) {
    switch (type) {
      case EntityType.driver:
        return Icons.person_rounded;
      case EntityType.rally:
        return Icons.flag_rounded;
      case EntityType.stage:
        return Icons.alt_route_rounded;
      case EntityType.city:
        return Icons.location_city_rounded;
      case EntityType.uploader:
        return Icons.cloud_upload_rounded;
    }
  }
}
