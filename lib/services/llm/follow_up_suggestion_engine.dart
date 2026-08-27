import 'package:flutter/material.dart';
import '../../models/conversational_search_session.dart';
import '../../models/search_intent.dart';
import '../../models/search_query.dart';
import '../../models/search_results.dart';

/// Represents a deterministic follow-up action or natural language suggestion.
class FollowUpSuggestion {
  final String label;
  final IconData? icon;
  final String? queryText;
  final SearchQuery? targetQuery;

  const FollowUpSuggestion({
    required this.label,
    this.icon,
    this.queryText,
    this.targetQuery,
  });
}

/// Generates 2–4 contextual suggestions deterministically from result type,
/// active intent, and conversational referents (no LLM call required).
class FollowUpSuggestionEngine {
  const FollowUpSuggestionEngine._();

  static List<FollowUpSuggestion> generate(
    SearchConversationSession session, {
    SearchResponse<dynamic>? response,
  }) {
    final suggestions = <FollowUpSuggestion>[];
    final q = session.activeQuery;
    final referents = session.referents;
    final activeRally = referents.activeRally ?? q.targetRallyName;
    final activeDriver = referents.activeDriver ?? referents.lastWinner ?? q.driverName;

    switch (q.intent) {
      case SearchIntent.searchRallies:
        if (activeRally != null && activeRally.isNotEmpty) {
          suggestions.add(
            FollowUpSuggestion(
              label: 'Who won it?',
              icon: Icons.military_tech_rounded,
              queryText: 'Who won $activeRally?',
              targetQuery: q.copyWith(
                intent: SearchIntent.getRallyResults,
                rallyName: activeRally,
              ),
            ),
          );
          suggestions.add(
            FollowUpSuggestion(
              label: 'Show highlights',
              icon: Icons.bolt_rounded,
              queryText: 'Show action highlights from $activeRally',
              targetQuery: q.copyWith(
                intent: SearchIntent.searchVideoActions,
                rallyName: activeRally,
              ),
            ),
          );
          suggestions.add(
            FollowUpSuggestion(
              label: 'Top finishers',
              icon: Icons.leaderboard_rounded,
              queryText: 'Top finishers in $activeRally',
              targetQuery: q.copyWith(
                intent: SearchIntent.getRallyTopFinishers,
                rallyName: activeRally,
              ),
            ),
          );
        } else {
          suggestions.add(
            const FollowUpSuggestion(
              label: 'Show 2025 rallies',
              icon: Icons.calendar_month_rounded,
              queryText: 'Show rallies in 2025',
            ),
          );
          suggestions.add(
            const FollowUpSuggestion(
              label: 'Rallies in Ireland',
              icon: Icons.public_rounded,
              queryText: 'Show rallies in Ireland',
            ),
          );
        }
        break;

      case SearchIntent.getRallyResults:
      case SearchIntent.getRallyTopFinishers:
        if (activeDriver != null && activeDriver.isNotEmpty) {
          suggestions.add(
            FollowUpSuggestion(
              label: 'Videos of him',
              icon: Icons.videocam_rounded,
              queryText: 'Show videos of $activeDriver',
              targetQuery: q.copyWith(
                intent: SearchIntent.searchDriverVideos,
                driverName: activeDriver,
              ),
            ),
          );
          suggestions.add(
            FollowUpSuggestion(
              label: 'Driver wins',
              icon: Icons.emoji_events_rounded,
              queryText: 'Rallies won by $activeDriver',
              targetQuery: q.copyWith(
                intent: SearchIntent.searchDriverWins,
                driverName: activeDriver,
              ),
            ),
          );
        }
        if (activeRally != null && activeRally.isNotEmpty) {
          suggestions.add(
            FollowUpSuggestion(
              label: 'Action clips',
              icon: Icons.bolt_rounded,
              queryText: 'Show jumps and action in $activeRally',
              targetQuery: q.copyWith(
                intent: SearchIntent.searchVideoActions,
                rallyName: activeRally,
              ),
            ),
          );
        }
        break;

      case SearchIntent.searchDriverRallies:
      case SearchIntent.searchDriverWins:
      case SearchIntent.searchDriverVideos:
        if (activeDriver != null && activeDriver.isNotEmpty) {
          if (q.intent != SearchIntent.searchDriverWins) {
            suggestions.add(
              FollowUpSuggestion(
                label: 'Show wins',
                icon: Icons.emoji_events_rounded,
                queryText: 'Career wins for $activeDriver',
                targetQuery: q.copyWith(
                  intent: SearchIntent.searchDriverWins,
                  driverName: activeDriver,
                ),
              ),
            );
          }
          if (q.intent != SearchIntent.searchDriverVideos) {
            suggestions.add(
              FollowUpSuggestion(
                label: 'Show videos',
                icon: Icons.videocam_rounded,
                queryText: 'Videos featuring $activeDriver',
                targetQuery: q.copyWith(
                  intent: SearchIntent.searchDriverVideos,
                  driverName: activeDriver,
                ),
              ),
            );
          }
          suggestions.add(
            FollowUpSuggestion(
              label: 'Show jumps',
              icon: Icons.bolt_rounded,
              queryText: 'Show jumps featuring $activeDriver',
              targetQuery: q.copyWith(
                intent: SearchIntent.searchVideoActions,
                driverName: activeDriver,
                actionTypes: ['jump'],
              ),
            ),
          );
        }
        break;

      case SearchIntent.searchVideoActions:
        final actions = q.actionTypes.map((a) => a.toLowerCase()).toList();
        if (actions.contains('jump') && !actions.contains('drift')) {
          suggestions.add(
            const FollowUpSuggestion(
              label: '+ Add drifts',
              icon: Icons.add_circle_outline_rounded,
              queryText: 'also drifts',
            ),
          );
        } else if (actions.contains('drift') && !actions.contains('jump')) {
          suggestions.add(
            const FollowUpSuggestion(
              label: '+ Add jumps',
              icon: Icons.add_circle_outline_rounded,
              queryText: 'also jumps',
            ),
          );
        }
        if (!actions.contains('crash')) {
          suggestions.add(
            const FollowUpSuggestion(
              label: '+ Add crashes',
              icon: Icons.add_circle_outline_rounded,
              queryText: 'also crashes',
            ),
          );
        }
        if (activeDriver != null && activeDriver.isNotEmpty) {
          suggestions.add(
            FollowUpSuggestion(
              label: 'Same driver',
              icon: Icons.person_rounded,
              queryText: 'Show all videos of $activeDriver',
              targetQuery: q.copyWith(
                intent: SearchIntent.searchDriverVideos,
                driverName: activeDriver,
              ),
            ),
          );
        }
        if (activeRally != null && activeRally.isNotEmpty) {
          suggestions.add(
            FollowUpSuggestion(
              label: 'Who won rally?',
              icon: Icons.military_tech_rounded,
              queryText: 'Who won $activeRally?',
              targetQuery: q.copyWith(
                intent: SearchIntent.getRallyResults,
                rallyName: activeRally,
              ),
            ),
          );
        }
        break;

      case SearchIntent.getTopUploaders:
      case SearchIntent.getTopDriversByWins:
        suggestions.add(
          const FollowUpSuggestion(
            label: 'Search 2025 Rallies',
            icon: Icons.flag_rounded,
            queryText: 'Show rallies in 2025',
          ),
        );
        suggestions.add(
          const FollowUpSuggestion(
            label: 'Action Highlights',
            icon: Icons.bolt_rounded,
            queryText: 'Show jump highlights',
          ),
        );
        break;
    }

    return suggestions.take(4).toList();
  }
}
