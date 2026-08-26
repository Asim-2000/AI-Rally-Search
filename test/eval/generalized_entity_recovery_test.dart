import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/transliteration_helper.dart';

extension EntityResolutionResultExt on EntityResolutionResult {
  EntityCandidate? get resolvedDriverCandidate => resolutions['driver']?.resolvedCandidate;
  EntityCandidate? get resolvedRallyCandidate => resolutions['rally']?.resolvedCandidate;
  EntityCandidate? get resolvedStageCandidate => resolutions['stage']?.resolvedCandidate;
}

/// In-memory mock database entity lookup repository populated with 25+ real unseen motorsport entities.
class MockUnseenEntityRepository implements IEntityLookupRepository {
  final List<EntityCandidate> drivers = [
    const EntityCandidate(id: 'drv-01', type: EntityType.driver, canonicalName: 'Craig Breen', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-02', type: EntityType.driver, canonicalName: 'Keith Cronin', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-03', type: EntityType.driver, canonicalName: 'Alastair Fisher', subtitle: 'GBR'),
    const EntityCandidate(id: 'drv-04', type: EntityType.driver, canonicalName: 'Callum Devine', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-05', type: EntityType.driver, canonicalName: 'Garry Jennings', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-06', type: EntityType.driver, canonicalName: 'Donagh Kelly', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-07', type: EntityType.driver, canonicalName: 'Declan Boyle', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-08', type: EntityType.driver, canonicalName: 'Adrian Hetherington', subtitle: 'GBR'),
    const EntityCandidate(id: 'drv-09', type: EntityType.driver, canonicalName: 'Enda McCormack', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-10', type: EntityType.driver, canonicalName: 'Jonathan Pringle', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-11', type: EntityType.driver, canonicalName: 'Craig MacWilliam', subtitle: 'GBR'),
    const EntityCandidate(id: 'drv-12', type: EntityType.driver, canonicalName: 'Josh Moffett', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-13', type: EntityType.driver, canonicalName: 'Sam Moffett', subtitle: 'IRL'),
    const EntityCandidate(id: 'drv-14', type: EntityType.driver, canonicalName: 'Richard Moffett', subtitle: 'IRL'),
  ];

  final List<EntityCandidate> rallies = [
    const EntityCandidate(id: 'ral-01', type: EntityType.rally, canonicalName: 'West Cork Rally', metadata: {'year': 2025, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-02', type: EntityType.rally, canonicalName: 'Mid Ulster Stages Rally', metadata: {'year': 2025, 'country': 'United Kingdom'}),
    const EntityCandidate(id: 'ral-03', type: EntityType.rally, canonicalName: 'Kerry Winter Stages Rally', metadata: {'year': 2025, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-04', type: EntityType.rally, canonicalName: 'Clare Stages Rally', metadata: {'year': 2025, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-05', type: EntityType.rally, canonicalName: 'Sligo Stages Rally', metadata: {'year': 2025, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-06', type: EntityType.rally, canonicalName: 'Limerick Forest Rally', metadata: {'year': 2025, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-07', type: EntityType.rally, canonicalName: 'Monaghan Stages Rally', metadata: {'year': 2025, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-08', type: EntityType.rally, canonicalName: 'Cavan Stages Rally', metadata: {'year': 2025, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-09', type: EntityType.rally, canonicalName: 'Moonraker Forestry Rally 2024', metadata: {'year': 2024, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-10', type: EntityType.rally, canonicalName: 'Moonraker Forestry Rally 2025', metadata: {'year': 2025, 'country': 'Ireland'}),
    const EntityCandidate(id: 'ral-11', type: EntityType.rally, canonicalName: 'Moonraker Forestry Rally 2026', metadata: {'year': 2026, 'country': 'Ireland'}),
  ];

  final List<EntityCandidate> stages = [
    const EntityCandidate(id: 'stg-01', type: EntityType.stage, canonicalName: 'Ring Stage', metadata: {'stageNumber': '1', 'eventName': 'West Cork Rally'}),
    const EntityCandidate(id: 'stg-02', type: EntityType.stage, canonicalName: 'Ardfield Stage', metadata: {'stageNumber': '2', 'eventName': 'West Cork Rally'}),
    const EntityCandidate(id: 'stg-03', type: EntityType.stage, canonicalName: 'Banaghar Stage', metadata: {'stageNumber': '3', 'eventName': 'Mid Ulster Stages Rally'}),
    const EntityCandidate(id: 'stg-04', type: EntityType.stage, canonicalName: 'Moll\'s Gap', metadata: {'stageNumber': '1', 'eventName': 'Killarney Historic Stages'}),
  ];

  @override
  Future<List<EntityCandidate>> lookupDrivers(String phrase, {String? eventId, String? eventName, int? year, int limit = 15}) async {
    final queryNorm = PhoneticMatchingHelper.normalize(phrase);
    final queryCollapsed = PhoneticMatchingHelper.collapseSpaces(phrase);
    final isAr = TransliterationHelper.isArabicOrUrdu(phrase);
    final translits = isAr ? TransliterationHelper.transliterateToLatin(phrase) : <String>[];

    final matches = <EntityCandidate>[];
    for (final d in drivers) {
      final candNorm = PhoneticMatchingHelper.normalize(d.canonicalName);
      final candCollapsed = PhoneticMatchingHelper.collapseSpaces(d.canonicalName);

      bool plausible = candNorm.contains(queryNorm) ||
          queryNorm.contains(candNorm) ||
          candCollapsed.contains(queryCollapsed) ||
          queryCollapsed.contains(candCollapsed);

      if (!plausible && isAr) {
        for (final t in translits) {
          final tNorm = PhoneticMatchingHelper.normalize(t);
          if (candNorm.contains(tNorm) ||
              tNorm.contains(candNorm) ||
              PhoneticMatchingHelper.jaroWinkler(candNorm, tNorm) >= 0.70 ||
              PhoneticMatchingHelper.normalizedLevenshtein(candNorm, tNorm) >= 0.70) {
            plausible = true;
            break;
          }
        }
      }

      if (!plausible) {
        final words = queryNorm.split(' ');
        for (final w in words) {
          if (w.length >= 3 && candNorm.contains(w)) plausible = true;
        }
        if (PhoneticMatchingHelper.jaroWinkler(queryNorm, candNorm) >= 0.70) {
          plausible = true;
        }
      }

      if (plausible) {
        matches.add(d);
      }
    }
    return matches.take(limit).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupRallies(String phrase, {int? year, String? country, String? city, int limit = 15}) async {
    final queryNorm = PhoneticMatchingHelper.normalize(phrase);
    final queryCollapsed = PhoneticMatchingHelper.collapseSpaces(phrase);
    final isAr = TransliterationHelper.isArabicOrUrdu(phrase);
    final translits = isAr ? TransliterationHelper.transliterateToLatin(phrase) : <String>[];

    final matches = <EntityCandidate>[];
    for (final r in rallies) {
      final candNorm = PhoneticMatchingHelper.normalize(r.canonicalName);
      final candCollapsed = PhoneticMatchingHelper.collapseSpaces(r.canonicalName);

      bool plausible = candNorm.contains(queryNorm) ||
          queryNorm.contains(candNorm) ||
          candCollapsed.contains(queryCollapsed) ||
          queryCollapsed.contains(candCollapsed);

      if (!plausible && isAr) {
        for (final t in translits) {
          final tNorm = PhoneticMatchingHelper.normalize(t);
          final tCore = PhoneticMatchingHelper.stripDescriptors(tNorm);
          final cCore = PhoneticMatchingHelper.stripDescriptors(candNorm);
          if (candNorm.contains(tNorm) ||
              tNorm.contains(candNorm) ||
              (tCore.isNotEmpty && cCore.contains(tCore)) ||
              PhoneticMatchingHelper.jaroWinkler(candNorm, tNorm) >= 0.65) {
            plausible = true;
            break;
          }
        }
      }

      if (!plausible) {
        final words = queryNorm.split(' ');
        for (final w in words) {
          if (w.length >= 3 && candNorm.contains(w)) plausible = true;
        }
        if (PhoneticMatchingHelper.jaroWinkler(queryNorm, candNorm) >= 0.65) {
          plausible = true;
        }
      }

      if (plausible) {
        matches.add(r);
      }
    }
    return matches.take(limit).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupStages(String phrase, {String? eventId, String? eventName, int limit = 15}) async {
    final queryNorm = PhoneticMatchingHelper.normalize(phrase);
    return stages.where((s) {
      final candNorm = PhoneticMatchingHelper.normalize(s.canonicalName);
      return candNorm.contains(queryNorm) ||
          queryNorm.contains(candNorm) ||
          PhoneticMatchingHelper.jaroWinkler(queryNorm, candNorm) >= 0.70;
    }).take(limit).toList();
  }

  @override
  Future<List<EntityCandidate>> lookupCities(String phrase, {String? country, int limit = 15}) async => [];

  @override
  Future<List<EntityCandidate>> lookupUploaders(String phrase, {int limit = 15}) async => [];
}

void main() {
  group('Phase 5B.2 — 20+ Unseen Entity Generalization Test Suite', () {
    late DatabaseEntityResolver resolver;
    late MockUnseenEntityRepository repository;

    setUp(() {
      repository = MockUnseenEntityRepository();
      resolver = DatabaseEntityResolver(
        repository: repository,
        minConfidenceThreshold: 0.75,
        minScoreGap: 0.15,
      );
    });

    test('Test 1: Unseen Driver Vowel Substitution (Craig Brean -> Craig Breen)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Craig Brean');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-01'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Craig Breen'));
      expect(res.resolvedDriverCandidate!.score >= 0.85, isTrue);
    });

    test('Test 2: Unseen Driver Consonant / Spelling Variant (Keith Cronan -> Keith Cronin)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Keith Cronan');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-02'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Keith Cronin'));
    });

    test('Test 3: Unseen Driver Phonetic Variant (Alister Fisher -> Alastair Fisher)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Alister Fisher');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-03'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Alastair Fisher'));
    });

    test('Test 4: Unseen Driver Typo / Missing Letter (Calum Devine -> Callum Devine)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Calum Devine');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-04'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Callum Devine'));
    });

    test('Test 5: Unseen Driver Name Single Character Variation (Gary Jennings -> Garry Jennings)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Gary Jennings');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-05'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Garry Jennings'));
    });

    test('Test 6: Unseen Driver Acoustic STT Error (Donagh Kelli -> Donagh Kelly)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Donagh Kelli');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-06'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Donagh Kelly'));
    });

    test('Test 7: Unseen Driver Spelling Error (Declan Boil -> Declan Boyle)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Declan Boil');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-07'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Declan Boyle'));
    });

    test('Test 8: Unseen Driver Missing Middle Syllable (Adrian Hethergton -> Adrian Hetherington)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Adrian Hethergton');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-08'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Adrian Hetherington'));
    });

    test('Test 9: Unseen Driver Space / Casing Variant (Enda Mc Cormack -> Enda McCormack)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Enda Mc Cormack');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-09'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Enda McCormack'));
    });

    test('Test 10: Unseen Driver Phonetic Variant (Jhonathan Pringle -> Jonathan Pringle)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Jhonathan Pringle');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-10'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Jonathan Pringle'));
    });

    test('Test 11: Unseen Arabic Script Driver Transliteration (كريغ برين -> Craig Breen)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'كريغ برين');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-01'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Craig Breen'));
    });

    test('Test 12: Unseen Arabic Script Driver Transliteration (كيث كرونين -> Keith Cronin)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'كيث كرونين');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-02'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Keith Cronin'));
    });

    test('Test 13: Unseen Urdu Script Driver Transliteration (کالم ڈیوین -> Callum Devine)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'کالم ڈیوین');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedDriverCandidate?.id, equals('drv-04'));
      expect(res.resolvedDriverCandidate?.canonicalName, equals('Callum Devine'));
    });

    test('Test 14: Unseen Rally Word-Boundary Join (Westcork -> West Cork Rally)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchRallies, rallyName: 'Westcork');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedRallyCandidate?.id, equals('ral-01'));
      expect(res.resolvedRallyCandidate?.canonicalName, equals('West Cork Rally'));
    });

    test('Test 15: Unseen Rally Word-Boundary Join (Midulster -> Mid Ulster Stages Rally)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchRallies, rallyName: 'Midulster');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedRallyCandidate?.id, equals('ral-02'));
      expect(res.resolvedRallyCandidate?.canonicalName, equals('Mid Ulster Stages Rally'));
    });

    test('Test 16: Unseen Rally Typo (Clair Stages -> Clare Stages Rally)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchRallies, rallyName: 'Clair Stages');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedRallyCandidate?.id, equals('ral-04'));
      expect(res.resolvedRallyCandidate?.canonicalName, equals('Clare Stages Rally'));
    });

    test('Test 17: Unseen Rally Acoustic Variant (Slygo Stages -> Sligo Stages Rally)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchRallies, rallyName: 'Slygo Stages');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedRallyCandidate?.id, equals('ral-05'));
      expect(res.resolvedRallyCandidate?.canonicalName, equals('Sligo Stages Rally'));
    });

    test('Test 18: Unseen Rally Missing Letter (Limrick Forest -> Limerick Forest Rally)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchRallies, rallyName: 'Limrick Forest');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedRallyCandidate?.id, equals('ral-06'));
      expect(res.resolvedRallyCandidate?.canonicalName, equals('Limerick Forest Rally'));
    });

    test('Test 19: Unseen Rally Arabic Transliteration (رالي كيري -> Kerry Winter Stages Rally)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchRallies, rallyName: 'رالي كيري');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedRallyCandidate?.id, equals('ral-03'));
      expect(res.resolvedRallyCandidate?.canonicalName, equals('Kerry Winter Stages Rally'));
    });

    test('Test 20: Unseen Stage Exact Match (Ring Stage)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchVideoActions, stageName: 'Ring Stage');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedStageCandidate?.id, equals('stg-01'));
      expect(res.resolvedStageCandidate?.canonicalName, equals('Ring Stage'));
    });

    test('Test 21: Unseen Stage Typo (Ardfild -> Ardfield Stage)', () async {
      final query = const SearchQuery(intent: SearchIntent.searchVideoActions, stageName: 'Ardfild');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedStageCandidate?.id, equals('stg-02'));
      expect(res.resolvedStageCandidate?.canonicalName, equals('Ardfield Stage'));
    });
  });

  group('Phase 5B.2 — Negative & Safety Tests (Ambiguity & False-Positive Prevention)', () {
    late DatabaseEntityResolver resolver;
    late MockUnseenEntityRepository repository;

    setUp(() {
      repository = MockUnseenEntityRepository();
      resolver = DatabaseEntityResolver(
        repository: repository,
        minConfidenceThreshold: 0.75,
        minScoreGap: 0.15,
      );
    });

    test('Safety A: Ambiguous surname without first name ("Moffett") requires clarification', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Moffett');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isTrue);
      expect(res.candidates.length >= 2, isTrue);
      expect(res.candidates.any((c) => c.canonicalName == 'Josh Moffett'), isTrue);
      expect(res.candidates.any((c) => c.canonicalName == 'Sam Moffett'), isTrue);
    });

    test('Safety B: Ambiguous first name ("Craig") requires clarification', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Craig');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isTrue);
      expect(res.candidates.length >= 2, isTrue);
      expect(res.candidates.any((c) => c.canonicalName == 'Craig Breen'), isTrue);
      expect(res.candidates.any((c) => c.canonicalName == 'Craig MacWilliam'), isTrue);
    });

    test('Safety C: Multi-edition rally without year ("Moonraker") requires clarification', () async {
      final query = const SearchQuery(intent: SearchIntent.searchRallies, rallyName: 'Moonraker');
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isTrue);
      expect(res.candidates.length >= 2, isTrue);
    });

    test('Safety D: Multi-edition rally WITH year ("Moonraker" + 2025) resolves uniquely to 2025 edition', () async {
      final query = const SearchQuery(intent: SearchIntent.searchRallies, rallyName: 'Moonraker', year: 2025);
      final res = await resolver.resolve(query);

      expect(res.requiresClarification, isFalse);
      expect(res.resolvedRallyCandidate?.canonicalName, equals('Moonraker Forestry Rally 2025'));
      expect(res.resolvedRallyCandidate?.metadata?['year'], equals(2025));
    });

    test('Safety E: Completely unrelated entity produces no match', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Banana Pineapple Spaceship');
      final res = await resolver.resolve(query);

      expect(res.resolvedDriverCandidate, isNull);
    });

    test('Safety F: Low confidence candidate below minConfidenceThreshold produces no match or clarification', () async {
      final query = const SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: 'Xzibit');
      final res = await resolver.resolve(query);

      expect(res.resolvedDriverCandidate, isNull);
    });

    test('Safety G: Contextually relevant but lexically bad candidate must NOT resolve solely due to context', () async {
      final score = PhoneticMatchingHelper.computeCompositeScore(
        queryPhrase: 'Random Stranger',
        candidateName: 'Josh Moffett',
        queryYear: 2025,
        candidateYear: 2025,
        inContext: true,
      );

      // Must remain well below threshold (0.75) because lexical match is poor
      expect(score < 0.50, isTrue);
    });
  });
}
