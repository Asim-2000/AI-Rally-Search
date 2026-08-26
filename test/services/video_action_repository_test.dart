import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/video_action_repository.dart';

void main() {
  test('VideoActionRepository fetches and parses live actions from database', () async {
    await dotenv.load(fileName: '.env');
    final repo = VideoActionRepository();

    final recentActions = await repo.getRecentVideoActions(limit: 5);
    expect(recentActions, isA<List>());
    print('Recent Actions Count: ${recentActions.length}');

    if (recentActions.isNotEmpty) {
      final first = recentActions.first;
      print('First Action: ${first.title} (${first.actionType}), Range: ${first.formattedTimeRange}, Duration: ${first.formattedDuration}, Video #${first.videoId}, URL: ${first.videoUrl}');
      expect(first.id, greaterThan(0));
      expect(first.videoId, greaterThan(0));
      expect(first.actionType.isNotEmpty, true);
      expect(first.startTime, greaterThanOrEqualTo(0));
      expect(first.endTime, greaterThanOrEqualTo(first.startTime));
    }

    await DatabaseService().close();
  });
}
