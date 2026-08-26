import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/video_action_search_query.dart';

void main() {
  group('VideoActionSearchQuery Model & Normalization Tests', () {
    test('Normalizes standard action names to database representations', () {
      expect(VideoActionSearchQuery.normalizeActionType('jump'), equals('jump_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('jumps'), equals('jump_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('drift'), equals('drift_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('crash'), equals('crash_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('spin'), equals('spin_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('start line'), equals('start_line_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('start_line'), equals('start_line_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('near miss'), equals('near_miss_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('mechanical failure'), equals('mechanical_failure_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('offroad'), equals('offroad_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('stuck'), equals('stuck_segments'));
    });

    test('Preserves already suffixed action names', () {
      expect(VideoActionSearchQuery.normalizeActionType('jump_segments'), equals('jump_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('drift_segments'), equals('drift_segments'));
      expect(VideoActionSearchQuery.normalizeActionType('custom_segments'), equals('custom_segments'));
    });

    test('Returns null for ALL or empty action types', () {
      expect(VideoActionSearchQuery.normalizeActionType(null), isNull);
      expect(VideoActionSearchQuery.normalizeActionType(''), isNull);
      expect(VideoActionSearchQuery.normalizeActionType('ALL'), isNull);
      expect(VideoActionSearchQuery.normalizeActionType('All Actions'), isNull);
    });

    test('Resolves country aliases bidirectionally', () {
      final austriaAliases = VideoActionSearchQuery.resolveCountryAliases('Austria');
      expect(austriaAliases, contains('at'));
      expect(austriaAliases, contains('austria'));

      final atAliases = VideoActionSearchQuery.resolveCountryAliases('at');
      expect(atAliases, contains('at'));
      expect(atAliases, contains('austria'));

      final ukAliases = VideoActionSearchQuery.resolveCountryAliases('United Kingdom');
      expect(ukAliases, contains('gb'));
      expect(ukAliases, contains('uk'));
      expect(ukAliases, contains('united kingdom'));

      final gbAliases = VideoActionSearchQuery.resolveCountryAliases('gb');
      expect(gbAliases, contains('gb'));
      expect(gbAliases, contains('united kingdom'));
    });

    test('Resolves empty/null countries properly', () {
      expect(VideoActionSearchQuery.resolveCountryAliases(null), isEmpty);
      expect(VideoActionSearchQuery.resolveCountryAliases(''), isEmpty);
      expect(VideoActionSearchQuery.resolveCountryAliases('ALL'), isEmpty);
    });

    test('Query properties and resolved lists work properly', () {
      const query = VideoActionSearchQuery(
        actionType: 'jump',
        country: 'Austria',
        eventName: 'OBM Land',
        stageName: 'St. Peter',
        stageNumber: '3',
        limit: 10,
        offset: 5,
      );

      expect(query.resolvedActionTypes, equals(['jump_segments']));
      expect(query.resolvedCountryAliases, contains('at'));
      expect(query.resolvedCountryAliases, contains('austria'));
      expect(query.isEmpty, isFalse);
      expect(query.limit, equals(10));
      expect(query.offset, equals(5));

      final copy = query.copyWith(limit: 25, offset: 0);
      expect(copy.limit, equals(25));
      expect(copy.offset, equals(0));
      expect(copy.actionType, equals('jump'));
    });

    test('Supports multi-action query resolution', () {
      const query = VideoActionSearchQuery(
        actionTypes: ['jump', 'drift', 'crash'],
      );

      expect(
        query.resolvedActionTypes,
        containsAll(['jump_segments', 'drift_segments', 'crash_segments']),
      );
    });
  });
}
