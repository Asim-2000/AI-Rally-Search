import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';

void main() {
  test('getRallyStreams excludes instantReplay video type rows', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();

    final streams = await db.getRallyStreams(limit: 50);
    expect(streams, isNotEmpty);

    for (final stream in streams) {
      final videoType = stream['video_type']?.toString();
      expect(videoType, isNot(equals('instantReplay')));
    }

    await db.close();
  });
}
