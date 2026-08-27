import 'package:flutter/material.dart';
import '../services/llm/follow_up_suggestion_engine.dart';

/// Horizontal bar displaying 2–4 deterministic contextual follow-up suggestions.
class SuggestedFollowUpsBar extends StatelessWidget {
  final List<FollowUpSuggestion> suggestions;
  final ValueChanged<FollowUpSuggestion> onSuggestionSelected;

  const SuggestedFollowUpsBar({
    super.key,
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Suggested Follow-ups',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: suggestions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    avatar: s.icon != null
                        ? Icon(s.icon, size: 15, color: theme.colorScheme.primary)
                        : null,
                    label: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    backgroundColor: isDark ? Colors.white10 : Colors.white,
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () => onSuggestionSelected(s),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
