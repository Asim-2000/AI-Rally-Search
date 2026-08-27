// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/providers/mock_query_parser.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Generalized STT Entity Resolution & Recovery Test Suite', () {
    late DatabaseService dbService;
    late DatabaseEntityLookupRepository lookupRepo;
    late DatabaseEntityResolver resolver;

    setUpAll(() async {
      await dotenv.load(fileName: '.env');
      dbService = DatabaseService();
      lookupRepo = DatabaseEntityLookupRepository(dbService: dbService);
      resolver = DatabaseEntityResolver(
        repository: lookupRepo,
        minConfidenceThreshold: 0.75,
        minScoreGap: 0.15,
      );
    });

    tearDownAll(() async {
      await dbService.close();
    });

    group('1. Alūksne Voice STT Perturbations', () {
      final aluksneVariants = [
        'alux new',
        'eluksne',
        'aluknse',
        'aluxne',
      ];

      for (final variant in aluksneVariants) {
        test('Variant "$variant" retrieves Rally Alūksne in Recall@5 and auto-resolves or suggests correctly', () async {
          final candidates = await lookupRepo.lookupRallies(variant, limit: 5);
          expect(candidates, isNotEmpty);
          final hasCanonical = candidates.any((c) => c.canonicalName.contains('Alūksne'));
          expect(hasCanonical, isTrue, reason: 'Rally Alūksne must appear in Recall@5 for "$variant"');

          final query = SearchQuery(
            intent: SearchIntent.searchVideoActions,
            actionTypes: const ['action'],
            rallyNames: [variant],
          );

          final result = await resolver.resolve(query);
          if (result.requiresClarification) {
            expect(result.candidates.any((c) => c.canonicalName.contains('Alūksne')), isTrue);
          } else {
            expect(result.resolvedQuery?.targetRallyName, contains('Alūksne'));
          }
        });
      }
    });

    group('2. Generalized Space-Boundary and Acoustic Entities', () {
      test('Moonraker word-boundary join ("moon raker")', () async {
        final candidates = await lookupRepo.lookupRallies('moon raker', limit: 5);
        expect(candidates.any((c) => c.canonicalName.contains('Moonraker')), isTrue);

        final query = SearchQuery(
          intent: SearchIntent.searchVideoActions,
          actionTypes: const ['jump'],
          rallyNames: const ['moon raker'],
        );
        final result = await resolver.resolve(query);
        final resolvedOrCandidate = result.requiresClarification
            ? result.candidates.first.canonicalName
            : (result.resolvedQuery?.targetRallyName ?? '');
        expect(resolvedOrCandidate, contains('Moonraker'));
      });

      test('Donegal word-boundary join ("done gal")', () async {
        final candidates = await lookupRepo.lookupRallies('done gal', limit: 5);
        expect(candidates.any((c) => c.canonicalName.contains('Donegal')), isTrue);

        final query = SearchQuery(
          intent: SearchIntent.searchRallies,
          rallyNames: const ['done gal'],
        );
        final result = await resolver.resolve(query);
        final resolvedOrCandidate = result.requiresClarification
            ? result.candidates.first.canonicalName
            : (result.resolvedQuery?.targetRallyName ?? '');
        expect(resolvedOrCandidate, contains('Donegal'));
      });

      test('Kemmelberg word-boundary and acoustic ("kemel berg")', () async {
        final candidates = await lookupRepo.lookupStages('kemel berg', limit: 5);
        expect(candidates.any((c) => c.canonicalName.contains('Kemmelberg')), isTrue);

        final query = SearchQuery(
          intent: SearchIntent.searchVideoActions,
          stageNames: const ['kemel berg'],
        );
        final result = await resolver.resolve(query);
        final resolvedOrCandidate = result.requiresClarification
            ? result.candidates.first.canonicalName
            : (result.resolvedQuery?.stageNames.first ?? '');
        expect(resolvedOrCandidate, contains('Kemmelberg'));
      });

      test('Duszniki acoustic distortion ("dushniki")', () async {
        final candidates = await lookupRepo.lookupStages('dushniki', limit: 5);
        expect(candidates.any((c) => c.canonicalName.contains('Duszniki')), isTrue);

        final query = SearchQuery(
          intent: SearchIntent.searchVideoActions,
          stageNames: const ['dushniki'],
        );
        final result = await resolver.resolve(query);
        final resolvedOrCandidate = result.requiresClarification
            ? result.candidates.first.canonicalName
            : (result.resolvedQuery?.stageNames.first ?? '');
        expect(resolvedOrCandidate, contains('Duszniki'));
      });

      test('Shea Breen vowel acoustic distortion ("Shea Brean")', () async {
        final candidates = await lookupRepo.lookupDrivers('Shea Brean', limit: 15);
        expect(candidates.any((c) => c.canonicalName == 'Shea Breen'), isTrue);

        final query = SearchQuery(
          intent: SearchIntent.searchDriverVideos,
          driverNames: const ['Shea Brean'],
        );
        final result = await resolver.resolve(query);
        final resolvedOrCandidate = result.requiresClarification
            ? result.candidates.first.canonicalName
            : (result.resolvedQuery?.driverName ?? '');
        expect(resolvedOrCandidate, equals('Shea Breen'));
      });

      test('Jon-Gunnar Støten diacritic/hyphen variant ("Jon Gunnar Stoten")', () async {
        final candidates = await lookupRepo.lookupDrivers('Jon Gunnar Stoten', limit: 5);
        expect(candidates.any((c) => c.canonicalName == 'Jon-Gunnar Støten'), isTrue);

        final query = SearchQuery(
          intent: SearchIntent.searchDriverVideos,
          driverNames: const ['Jon Gunnar Stoten'],
        );
        final result = await resolver.resolve(query);
        final resolvedOrCandidate = result.requiresClarification
            ? result.candidates.first.canonicalName
            : (result.resolvedQuery?.driverName ?? '');
        expect(resolvedOrCandidate, equals('Jon-Gunnar Støten'));
      });
    });

    group('3. Entity-Required Intents & Zero-Result Distinctions', () {
      test('Condition A: Unidentifiable entity fails or clarifies without running raw un-resolved query', () async {
        final query = SearchQuery(
          intent: SearchIntent.searchVideoActions,
          actionTypes: const ['jump'],
          rallyNames: const ['zzqxxjjkww'],
        );

        final result = await resolver.resolve(query);
        expect(result.isSuccess, isFalse);
        if (result.requiresClarification) {
          expect(result.candidates, isNotEmpty);
        } else {
          expect(result.error, contains('We couldn\'t confidently identify that rally'));
        }
        expect(result.resolvedQuery?.targetRallyName, isNull);
      });

      test('Condition B: Confidently resolved entity with 0 videos in DB produces clean search response', () async {
        final query = SearchQuery(
          intent: SearchIntent.searchVideoActions,
          actionTypes: const ['crash'],
          rallyNames: const ['Rally Alūksne 2026'],
        );

        final result = await resolver.resolve(query);
        expect(result.isSuccess, isTrue);
        expect(result.resolvedQuery?.targetRallyName, contains('Alūksne'));
      });

      test('Adversarial Negatives: Unrelated queries do NOT falsely auto-resolve', () async {
        final negativeQueries = [
          'Craig Nonexistentperson',
          'Rally Fakeplacenamexyz',
          'Completely Unrelated Noise',
        ];

        for (final neg in negativeQueries) {
          final query = SearchQuery(
            intent: SearchIntent.searchDriverVideos,
            driverNames: [neg],
          );
          final result = await resolver.resolve(query);
          expect(result.resolvedQuery?.driverName == 'Craig Breen', isFalse);
          expect(result.resolvedQuery?.driverName == 'Josh Moffett', isFalse);
          if (result.isSuccess) {
            expect(result.resolvedQuery?.driverName, isNot(contains('Breen')));
          }
        }
      });
    });

    group('4. End-to-End Natural Language Flow', () {
      test('Full query "rally alux new videos" resolves to Rally Alūksne', () async {
        final mockParser = MockLlmQueryParser();
        final nlService = NaturalLanguageSearchService(
          parser: mockParser,
          entityResolver: resolver,
        );

        final nlResult = await nlService.search('rally alux new videos');
        if (nlResult.requiresClarification) {
          expect(nlResult.candidates.any((c) => c.canonicalName.contains('Alūksne')), isTrue);
        } else {
          expect(nlResult.resolvedQuery?.targetRallyName, contains('Alūksne'));
        }
      });
    });
  });
}
