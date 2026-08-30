import 'package:flutter/material.dart';
import '../models/search_results.dart';
import '../theme/app_theme.dart';
import 'rally_card_shell.dart';

class DriverParticipationCard extends StatelessWidget {
  final RallyParticipationResult participation;
  final VoidCallback? onTap;

  const DriverParticipationCard({
    super.key,
    required this.participation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWin = participation.posOverall == 1;

    return RallyCardShell(
      onTap: onTap,
      edgeColor: isWin ? kRallyGold : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event header with trophy badge if winner
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participation.eventName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (participation.country != null && participation.country!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 4),
                              Text(
                                participation.city != null && participation.city!.isNotEmpty
                                    ? '${participation.city}, ${participation.country}'
                                    : participation.country!,
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Finishing rank badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isWin
                          ? Colors.amber.withValues(alpha: 0.2)
                          : (participation.posOverall != null && participation.posOverall! <= 3)
                              ? Colors.blue.withValues(alpha: 0.15)
                              : (isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isWin
                            ? Colors.amber
                            : (participation.posOverall != null && participation.posOverall! <= 3)
                                ? Colors.blue.shade300
                                : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      participation.finishPositionDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isWin
                            ? Colors.amber.shade800
                            : (participation.posOverall != null && participation.posOverall! <= 3)
                                ? const Color(0xFF1E88E5)
                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, thickness: 0.5),

              // Driver & Car details
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      participation.driverName.isNotEmpty ? participation.driverName[0] : 'D',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participation.driverName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (participation.make != null || participation.car != null)
                          Text(
                            [
                              if (participation.carNumber != null) '#${participation.carNumber}',
                              participation.make ?? participation.car,
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (participation.totalTime != null && participation.totalTime!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          Text(
                            formatRaceTime(participation.totalTime),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}
