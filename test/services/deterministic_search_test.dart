import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/models/video_action_search_query.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/video_action_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late VideoActionRepository repository;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    dbService = DatabaseService();
    repository = VideoActionRepository(dbService: dbService);
  });

  tearDownAll(() async {
    await dbService.close();
  });

  group('Deterministic Video Action Search Integration Tests', () {
    // 1. Search by action
    test('1. Search by action: actionType = "jump"', () async {
      const query = VideoActionSearchQuery(actionType: 'jump', limit: 10);
      final results = await repository.searchVideoActions(query);
      
      expect(results, isNotEmpty);
      for (final action in results) {
        expect(action.actionType, equals('jump'));
      }
    });

    // 2. Search by country
    test('2. Search by country: country = "at" and "Austria"', () async {
      const queryCode = VideoActionSearchQuery(country: 'at', limit: 10);
      final resultsCode = await repository.searchVideoActions(queryCode);

      const queryName = VideoActionSearchQuery(country: 'Austria', limit: 10);
      final resultsName = await repository.searchVideoActions(queryName);

      expect(resultsCode.length, equals(resultsName.length));
      if (resultsCode.isNotEmpty) {
        for (final action in resultsCode) {
          expect(
            action.eventCountry?.toLowerCase(),
            anyOf(equals('at'), contains('austria')),
          );
        }
      }
    });

    // 3. Search by action + country
    test('3. Search by action + country: jump + United Kingdom / gb', () async {
      const query = VideoActionSearchQuery(
        actionType: 'jump',
        country: 'United Kingdom',
        limit: 10,
      );
      final results = await repository.searchVideoActions(query);

      for (final action in results) {
        expect(action.actionType, equals('jump'));
        expect(
          action.eventCountry?.toLowerCase(),
          anyOf(equals('gb'), contains('united kingdom'), contains('scotland'), contains('wales')),
        );
      }
    });

    // 4. Search by event name (case-insensitive substring)
    test('4. Search by event name: partial "Trackrod"', () async {
      const query = VideoActionSearchQuery(
        eventName: 'trackrod',
        limit: 10,
      );
      final results = await repository.searchVideoActions(query);

      expect(results, isNotEmpty);
      for (final action in results) {
        expect(action.eventName?.toLowerCase(), contains('trackrod'));
      }
    });

    // 5. Search by stage name and stage number
    test('5. Search by stage: stageName = "Gale Rigg" and stageNumber = "3"', () async {
      const query = VideoActionSearchQuery(
        stageName: 'Gale Rigg',
        stageNumber: '3',
        limit: 10,
      );
      final results = await repository.searchVideoActions(query);

      expect(results, isNotEmpty);
      for (final action in results) {
        expect(action.stageName?.toLowerCase(), contains('gale rigg'));
      }
    });

    // 6. Multiple combined filters with AND logic
    test('6. Multiple filters combined with AND logic', () async {
      const query = VideoActionSearchQuery(
        actionType: 'start_line',
        country: 'United Kingdom',
        eventName: 'Trackrod',
        stageName: 'Gale Rigg',
        stageNumber: '3',
        limit: 10,
      );
      final results = await repository.searchVideoActions(query);

      expect(results, isNotEmpty);
      for (final action in results) {
        expect(action.actionType, equals('start_line'));
        expect(action.eventName?.toLowerCase(), contains('trackrod'));
        expect(action.stageName?.toLowerCase(), contains('gale rigg'));
      }
    });

    // 7. Pagination test (stable ordering, non-overlapping pages)
    test('7. Pagination: limit & offset work deterministically', () async {
      const queryPage1 = VideoActionSearchQuery(limit: 5, offset: 0);
      const queryPage2 = VideoActionSearchQuery(limit: 5, offset: 5);

      final page1 = await repository.searchVideoActions(queryPage1);
      final page2 = await repository.searchVideoActions(queryPage2);

      expect(page1.length, equals(5));
      expect(page2.length, equals(5));

      final page1Ids = page1.map((a) => a.id).toSet();
      final page2Ids = page2.map((a) => a.id).toSet();

      // Ensure no overlapping IDs between distinct pages
      expect(page1Ids.intersection(page2Ids), isEmpty);
    });

    // 8. Empty results handling
    test('8. Empty results for non-matching criteria returns empty list without error', () async {
      const query = VideoActionSearchQuery(
        eventName: 'NonexistentRallyEventxyz123',
      );
      final results = await repository.searchVideoActions(query);
      final count = await repository.countVideoActions(query);

      expect(results, isEmpty);
      expect(count, equals(0));
    });

    // 9. Unknown/invalid action type handled gracefully
    test('9. Invalid/unknown action type handled gracefully', () async {
      const query = VideoActionSearchQuery(
        actionType: 'unknown_flying_car_segment',
      );
      final results = await repository.searchVideoActions(query);
      expect(results, isA<List<VideoAction>>());
      expect(results, isEmpty);
    });

    // 10. Verify essential fields on all returned results
    test('10. Verify all returned results contain essential playback fields', () async {
      const query = VideoActionSearchQuery(limit: 20);
      final results = await repository.searchVideoActions(query);

      expect(results, isNotEmpty);
      for (final action in results) {
        expect(action.id, isPositive);
        expect(action.videoId, isPositive);
        expect(action.videoUrl, isNotNull);
        expect(action.videoUrl, isNotEmpty);
        expect(action.actionType, isNotEmpty);
        expect(action.startTime, greaterThanOrEqualTo(0.0));
        expect(action.endTime, greaterThan(action.startTime));
        expect(action.duration, greaterThan(0.0));
      }
    });

    // 11. Verify VideoAction model validity for playback
    test('11. Returned VideoAction model has formatted helper getters for UI/Player', () async {
      const query = VideoActionSearchQuery(actionType: 'jump', limit: 1);
      final results = await repository.searchVideoActions(query);

      expect(results, isNotEmpty);
      final action = results.first;

      expect(action.formattedDuration, isNotEmpty);
      expect(action.formattedTimeRange, contains('→'));
      expect(action.locationOrStageDescription, isNotEmpty);
      expect(action.title, equals('Jump'));
    });
  });
}
