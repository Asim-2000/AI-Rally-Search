import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/video_action.dart';

void main() {
  group('VideoAction Model Tests', () {
    test('parses from database map with time string format', () {
      final map = {
        'id': 19368,
        'video_id': 138458,
        'stream_id': 47951,
        'action_type_id': 5187,
        'action_name': 'drift_segments',
        'start_action': '00:00:07.400',
        'end_action': '00:00:08.300',
        'points': 85.5,
        'thumbnail_url': 'https://assets.example.com/thumb.jpg',
        'on_demand_url': 'https://stream.example.com/video.m3u8',
        'stage_name': 'St. Peter 2',
        'stage_number': '3',
        'event_name': 'OBM Land der 1000 Hügel Rallye 2026',
        'event_country': 'at',
      };

      final action = VideoAction.fromMap(map);

      expect(action.id, 19368);
      expect(action.videoId, 138458);
      expect(action.streamId, 47951);
      expect(action.actionType, 'drift');
      expect(action.title, 'Drift');
      expect(action.startTime, closeTo(7.4, 0.001));
      expect(action.endTime, closeTo(8.3, 0.001));
      expect(action.duration, closeTo(0.9, 0.001));
      expect(action.thumbnailUrl, 'https://assets.example.com/thumb.jpg');
      expect(action.videoUrl, 'https://stream.example.com/video.m3u8');
      expect(action.stageName, 'St. Peter 2');
      expect(action.stageNumber, '3');
      expect(action.eventName, 'OBM Land der 1000 Hügel Rallye 2026');
      expect(action.eventCountry, 'at');
      expect(action.points, 85.5);
      expect(action.formattedDuration, '0.9s');
      expect(action.formattedTimeRange, '00:07 → 00:08');
      expect(action.locationOrStageDescription, 'OBM Land der 1000 Hügel Rallye 2026 • SS3: St. Peter 2');
    });

    test('normalizes action type names correctly', () {
      final jumpMap = {
        'id': 1,
        'video_id': 100,
        'action_name': 'jump_segments',
        'start_action': '00:01:02.000',
        'end_action': '00:01:08.000',
      };
      final jumpAction = VideoAction.fromMap(jumpMap);
      expect(jumpAction.actionType, 'jump');
      expect(jumpAction.title, 'Jump');
      expect(jumpAction.startTime, 62.0);
      expect(jumpAction.endTime, 68.0);
      expect(jumpAction.duration, 6.0);
      expect(jumpAction.formattedDuration, '6.0s');
      expect(jumpAction.formattedTimeRange, '01:02 → 01:08');
    });

    test('handles fallback thumbnail and default stream video url', () {
      final map = {
        'id': 2,
        'video_id': 200,
        'action_name': 'crash_segments',
        'start_action': 15.0,
        'end_action': 22.5,
      };

      final action = VideoAction.fromMap(
        map,
        defaultVideoUrl: 'https://stream.example.com/fallback.m3u8',
        defaultStreamId: 999,
      );

      expect(action.id, 2);
      expect(action.videoId, 200);
      expect(action.streamId, 999);
      expect(action.videoUrl, 'https://stream.example.com/fallback.m3u8');
      expect(action.thumbnailUrl, null);
      expect(action.actionType, 'crash');
      expect(action.title, 'Crash');
      expect(action.duration, 7.5);
    });
  });
}
