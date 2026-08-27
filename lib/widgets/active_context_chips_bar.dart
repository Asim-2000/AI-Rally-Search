import 'package:flutter/material.dart';
import '../models/conversational_search_session.dart';
import '../models/search_query.dart';

/// Renders the compact active search context and refinement filter chips.
///
/// Features:
/// - Distinguishes between inherited conversational context and current query refinements.
/// - Supports multi-value chips (e.g., multiple countries, multiple years, multiple drivers).
/// - Tapping `×` on a chip deterministically removes that specific filter without an LLM call.
/// - Includes breadcrumb navigation to jump back to an earlier search turn.
class ActiveContextChipsBar extends StatelessWidget {
  final SearchConversationSession session;
  final void Function(String field, dynamic value) onRemoveFilter;
  final void Function(int historyIndex)? onRollbackHistory;
  final VoidCallback? onClearAll;

  const ActiveContextChipsBar({
    super.key,
    required this.session,
    required this.onRemoveFilter,
    this.onRollbackHistory,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final query = session.activeQuery;

    // Collect individual filter chips from query
    final chips = <_FilterChipItem>[];

    // Rally chips
    for (final r in query.rallyNames) {
      final isRefinement = session.currentRefinementFields.contains('rally') ||
          session.currentRefinementFields.contains('rallyNames');
      chips.add(_FilterChipItem(
        field: 'rally',
        value: r,
        label: r,
        icon: Icons.flag_rounded,
        isRefinement: isRefinement,
      ));
    }

    // Driver chips
    for (final d in query.driverNames) {
      final isRefinement = session.currentRefinementFields.contains('driver') ||
          session.currentRefinementFields.contains('driverNames');
      chips.add(_FilterChipItem(
        field: 'driver',
        value: d,
        label: d,
        icon: Icons.person_rounded,
        isRefinement: isRefinement,
      ));
    }

    // Country chips
    for (final c in query.countries) {
      if (c.toUpperCase() == 'ALL') continue;
      final isRefinement = session.currentRefinementFields.contains('country') ||
          session.currentRefinementFields.contains('countries');
      chips.add(_FilterChipItem(
        field: 'country',
        value: c,
        label: c,
        icon: Icons.public_rounded,
        isRefinement: isRefinement,
      ));
    }

    // Year chips
    for (final yr in query.years) {
      final isRefinement = session.currentRefinementFields.contains('year') ||
          session.currentRefinementFields.contains('years');
      chips.add(_FilterChipItem(
        field: 'year',
        value: yr,
        label: '$yr',
        icon: Icons.calendar_month_rounded,
        isRefinement: isRefinement,
      ));
    }

    // Action type chips
    for (final act in query.actionTypes) {
      if (act.toUpperCase() == 'ALL') continue;
      final isRefinement = session.currentRefinementFields.contains('action') ||
          session.currentRefinementFields.contains('actionTypes');
      final capLabel = act.isNotEmpty ? (act[0].toUpperCase() + act.substring(1)) : act;
      chips.add(_FilterChipItem(
        field: 'action',
        value: act,
        label: capLabel,
        icon: Icons.bolt_rounded,
        isRefinement: isRefinement,
      ));
    }

    // City chips
    for (final city in query.cities) {
      final isRefinement = session.currentRefinementFields.contains('city') ||
          session.currentRefinementFields.contains('cities');
      chips.add(_FilterChipItem(
        field: 'city',
        value: city,
        label: city,
        icon: Icons.location_city_rounded,
        isRefinement: isRefinement,
      ));
    }

    if (chips.isEmpty && session.history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb history trail if multiple turns exist
          if (session.history.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  ...session.history.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final snapshot = entry.value;
                    final isCurrent = idx == session.history.length - 1;
                    return InkWell(
                      onTap: isCurrent ? null : () => onRollbackHistory?.call(idx),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              snapshot.title,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : (isDark ? Colors.white70 : Colors.black54),
                                decoration: isCurrent ? TextDecoration.none : TextDecoration.underline,
                              ),
                            ),
                            if (idx < session.history.length - 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('›', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Active filter chips
          if (chips.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...chips.map((item) {
                    final chipColor = item.isRefinement
                        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                        : (isDark ? Colors.white12 : Colors.grey.shade200);

                    final borderColor = item.isRefinement
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : (isDark ? Colors.white24 : Colors.grey.shade300);

                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: chipColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: borderColor, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 14,
                                color: item.isRefinement
                                    ? theme.colorScheme.primary
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: item.isRefinement ? FontWeight.w600 : FontWeight.normal,
                                  color: item.isRefinement
                                      ? theme.colorScheme.primary
                                      : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => onRemoveFilter(item.field, item.value),
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.all(2.0),
                                  child: Icon(Icons.close_rounded, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (onClearAll != null)
                    InkWell(
                      onTap: onClearAll,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'Clear all',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.redAccent.shade200,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChipItem {
  final String field;
  final dynamic value;
  final String label;
  final IconData icon;
  final bool isRefinement;

  const _FilterChipItem({
    required this.field,
    required this.value,
    required this.label,
    required this.icon,
    this.isRefinement = false,
  });
}
