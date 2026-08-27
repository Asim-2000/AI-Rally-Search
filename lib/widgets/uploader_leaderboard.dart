import 'package:flutter/material.dart';
import '../models/search_results.dart';

class UploaderLeaderboard extends StatelessWidget {
  final List<UploaderSearchResult> uploaders;
  final String? rallyName;

  const UploaderLeaderboard({
    super.key,
    required this.uploaders,
    this.rallyName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = rallyName != null ? 'Top Uploaders — $rallyName' : 'Top Community Uploaders';

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
                    ? [const Color(0xFF065F46), const Color(0xFF1E293B)]
                    : [const Color(0xFF059669), const Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.video_library_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Ranked by Video Upload Count',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('RANK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                Expanded(child: Text('UPLOADER / CONTRIBUTOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                SizedBox(width: 80, child: Text('UPLOADS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
              ],
            ),
          ),

          // List rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: uploaders.length,
            separatorBuilder: (ctx, idx) => Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            itemBuilder: (ctx, idx) {
              final up = uploaders[idx];
              final rank = idx + 1;
              return Container(
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
                            radius: 14,
                            backgroundColor: theme.colorScheme.secondaryContainer,
                            backgroundImage: up.profilePicture != null && up.profilePicture!.startsWith('http')
                                ? NetworkImage(up.profilePicture!)
                                : null,
                            child: up.profilePicture == null || !up.profilePicture!.startsWith('http')
                                ? Text(
                                    up.uploaderName.isNotEmpty ? up.uploaderName[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSecondaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              up.uploaderName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF27272A) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${up.uploadCount} vids',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
