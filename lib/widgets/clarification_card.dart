import 'package:flutter/material.dart';
import '../models/entity_candidate.dart';

/// Inline clarification card presenting disambiguation candidates while preserving
/// already-resolved context.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2000) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.shade700.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.help_outline_rounded, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clarification Needed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      question,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close_rounded, size: 16),
                  ),
                ),
            ],
          ),
          if (candidates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidates.map((candidate) {
                final icon = _getCandidateIcon(candidate.type);
                return ActionChip(
                  avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
                  label: Text(
                    candidate.subtitle != null
                        ? '${candidate.canonicalName} (${candidate.subtitle})'
                        : candidate.canonicalName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: isDark ? Colors.white12 : Colors.white,
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  onPressed: () => onCandidateSelected(candidate),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCandidateIcon(EntityType type) {
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
