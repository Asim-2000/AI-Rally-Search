import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/rally_stream.dart';

void main() {
  group('RallyStream Model Tests', () {
    test('parses from database map with clipStartTime and clipDuration', () {
      final map = {
        'id': 85989,
        'video_id': 181564,
        'clip_duration': 7.17,
        'video_type': 'sendObs',
        'on_demand_url': 'https://stream.example.com/manifest.m3u8',
        'created_at': '2026-03-01 14:30:00',
        'updated_at': '2026-03-01 14:35:00',
        'clip_start_time': 7496.678,
        'clip_status': 'complete',
        'download_counter': 12,
        'share_counter': 5,
      };

      final stream = RallyStream.fromMap(map);

      expect(stream.id, 85989);
      expect(stream.videoId, 181564);
      expect(stream.clipDuration, closeTo(7.17, 0.001));
      expect(stream.clipStartTime, closeTo(7496.678, 0.001));
      expect(stream.videoType, 'sendObs');
      expect(stream.clipStatus, 'complete');
      expect(stream.formattedDuration, '7.2s');
      expect(stream.formattedClipRange, '2:04:56 → 2:05:03');
    });

    test('handles formattedClipRange when clipStartTime is 0 or clipDuration is not specified', () {
      final stream1 = RallyStream(
        id: 1,
        clipStartTime: 0.0,
        clipDuration: 30.0,
      );
      expect(stream1.formattedClipRange, '00:00 → 00:30');

      final stream2 = RallyStream(
        id: 2,
        clipStartTime: 120.0,
        clipDuration: null,
      );
      expect(stream2.formattedClipRange, '02:00 → End');
    });
  });
}
