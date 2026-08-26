import 'package:flutter/material.dart';
import '../models/search_results.dart';

class RallyLeaderboard extends StatelessWidget {
  final List<RallyResult> results;
  final String? rallyName;
  final Function(RallyResult)? onResultTap;

  const RallyLeaderboard({
    super.key,
    required this.results,
    this.rallyName,
    this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final headerTitle = rallyName ?? (results.isNotEmpty ? results.first.eventName : 'Rally Leaderboard');

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                    : [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.leaderboard_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Official Overall Classification',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${results.length} finishers',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
            child: const Row(
              children: [
                SizedBox(width: 36, child: Text('POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                SizedBox(width: 44, child: Text('NO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                Expanded(child: Text('DRIVER / CREW / CAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                SizedBox(width: 70, child: Text('TIME', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              ],
            ),
          ),

          // List of finishers
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            separatorBuilder: (ctx, idx) => Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            itemBuilder: (ctx, idx) {
              final res = results[idx];
              return _buildFinisherRow(context, res, idx, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinisherRow(BuildContext context, RallyResult res, int index, bool isDark) {
    final isTop3 = res.posOverall <= 3;
    Color rankColor;
    Widget rankWidget;

    if (res.posOverall == 1) {
      rankColor = Colors.amber;
      rankWidget = const Text('🥇', style: TextStyle(fontSize: 16));
    } else if (res.posOverall == 2) {
      rankColor = Colors.grey.shade400;
      rankWidget = const Text('🥈', style: TextStyle(fontSize: 16));
    } else if (res.posOverall == 3) {
      rankColor = Colors.brown.shade300;
      rankWidget = const Text('🥉', style: TextStyle(fontSize: 16));
    } else {
      rankColor = Colors.grey;
      rankWidget = Text(
        '${res.posOverall}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      );
    }

    return InkWell(
      onTap: onResultTap != null ? () => onResultTap!(res) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: res.posOverall == 1
            ? (isDark ? Colors.amber.withValues(alpha: 0.05) : Colors.amber.withValues(alpha: 0.08))
            : Colors.transparent,
        child: Row(
          children: [
            // Pos Badge
            SizedBox(
              width: 36,
              child: rankWidget,
            ),

            // Car Number
            SizedBox(
              width: 44,
              child: res.carNumber != null && res.carNumber!.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${res.carNumber}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Driver & Crew
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.driverName,
                      style: TextStyle(
                        fontWeight: isTop3 ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (res.crew != null && res.crew!.isNotEmpty && res.crew != res.driverName)
                      Text(
                        res.crew!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (res.make != null && res.make!.isNotEmpty)
                      Text(
                        res.make!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),

            // Time & Diff
            SizedBox(
              width: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    res.totalTime != null ? '${res.totalTime}s' : '--',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: res.posOverall == 1 ? Colors.amber.shade700 : null,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  if (res.diffLeader != null && res.diffLeader!.isNotEmpty && res.posOverall > 1)
                    Text(
                      '+${res.diffLeader}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.redAccent,
                      ),
                      textAlign: TextAlign.right,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
