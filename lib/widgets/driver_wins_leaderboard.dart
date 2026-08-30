import 'package:flutter/material.dart';
import '../models/search_results.dart';
import 'leaderboard_scaffold.dart';

class DriverWinsLeaderboard extends StatelessWidget {
  final List<DriverWinResult> drivers;
  final Function(DriverWinResult)? onDriverTap;

  const DriverWinsLeaderboard({
    super.key,
    required this.drivers,
    this.onDriverTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LeaderboardScaffold(
      icon: Icons.emoji_events_rounded,
      title: 'Most Rally Wins',
      subtitle: 'Ranked by career 1st-place finishes',
      countLabel: '${drivers.length} drivers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('RANK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                Expanded(child: Text('DRIVER & DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                SizedBox(width: 80, child: Text('CAREER WINS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              ],
            ),
          ),

          // List rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: drivers.length,
            separatorBuilder: (ctx, idx) => Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            itemBuilder: (ctx, idx) {
              final d = drivers[idx];
              final rank = idx + 1;

              return InkWell(
                onTap: onDriverTap != null ? () => onDriverTap!(d) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          rank == 1 ? '🥇' : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '#$rank')),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: rank <= 3 ? 16 : 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              backgroundImage: d.profilePicture != null
                                  ? NetworkImage(d.profilePicture!)
                                  : null,
                              child: d.profilePicture == null
                                  ? Text(
                                      d.driverName.isNotEmpty ? d.driverName[0] : 'D',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.driverName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (d.country != null && d.country!.isNotEmpty)
                                    Text(
                                      d.country!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: Text(
                            '🏆 ${d.winCount} ${d.winCount == 1 ? "win" : "wins"}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
