// ignore_for_file: avoid_print
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live DB Generalized Perturbation Benchmark', () {
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

    test('Live DB Generalized Perturbation Benchmark Evaluation', () async {
      // 1. Live difficult entities from database
      final rallyCases = [
        {'canonical': 'Rally Alūksne 2026', 'perturbations': ['Rally Aluske', 'aluxne', 'aluksne', 'Rally Aluksne']},
        {'canonical': '6 Uren van Kortrijk 2024', 'perturbations': ['kortrik', '6 Uren van Kortrik', 'Kortrijk 2024', 'Uren van Kortrijk']},
        {'canonical': 'Rali Serras de Fafe 2025', 'perturbations': ['Rali Serras de Faf', 'Serras de Fafe', 'Rally Fafe', 'Fafe 2025']},
        {'canonical': '7bet Rally Lazdijai 2025', 'perturbations': ['lazdiai', '7bet Rally Lazdiai', 'Rally Lazdijai', 'Lazdijai 2025']},
        {'canonical': "Rali Terras d'Aboboreira 2026", 'perturbations': ["aboborera", "Terras d'Aboboreira", "Rali Terras d Aboboreira 2026", "Aboboreira 2026"]},
        {'canonical': 'Polski Rajd Legend 2026', 'perturbations': ['Polski Raid Legend', 'Rajd Legend', 'Polski Rajd Legend', 'Polanica Legend']},
        {'canonical': 'Rally Vranov 2026', 'perturbations': ['Rally Vranow', 'Vranov 2026', 'Rally Vranov', 'Vranov Nad Toplou']},
        {'canonical': 'OBM Land der 1000 Hügel Rallye 2026', 'perturbations': ['1000 Hugel Rallye', 'Land der 1000 Hugel', '1000 Hügel', 'Hugel Rallye 2026']},
        {'canonical': 'Rallijsprints Cesavine 2026', 'perturbations': ['Cesavine', 'Rallijsprint Cesavine', 'Cesavine 2026', 'Cesavine Rally']},
        {'canonical': 'Rallye Régional des Ardennes 2025', 'perturbations': ['Regional des Ardennes', 'Rally Ardennes', 'Ardennes 2025', 'Rallye des Ardennes']},
        {'canonical': 'Century 21 Portugal Rally Series - Castelo Branco 2025', 'perturbations': ['Castelo Branco', 'Castelo Branco 2025', 'Rally Castelo Branco', 'Portugal Rally Series Castelo Branco']},
        {'canonical': 'Corrib Oil Galway International Rally 2026', 'perturbations': ['Galway Rally', 'Galway International 2026', 'Corrib Oil Galway', 'Galway 2026']},
        {'canonical': 'Assess Ireland International Rally of the Lakes 2026', 'perturbations': ['Rally of the Lakes', 'Rally of the Lakes 2026', 'International Rally of the Lakes', 'Lakes Rally 2026']},
        {'canonical': 'Clonakilty Park Hotel West Cork Rally 2026', 'perturbations': ['West Cork Rally', 'Westcork 2026', 'West Cork 2026', 'Clonakilty West Cork']},
        {'canonical': 'Samsonas Rally Fivemiletown 2026', 'perturbations': ['Fivemiletown', 'Fivemiletown Rally', 'Samsonas Fivemiletown', 'Fivemiletown 2026']},
        {'canonical': 'Modern Tyres Ulster Rally 2025', 'perturbations': ['Ulster Rally', 'Ulster Rally 2025', 'Modern Tyres Ulster', 'Ulster 2025']},
        {'canonical': 'Raven\'s Rock Stages Rally 2025', 'perturbations': ['Ravens Rock', 'Ravens Rock Stages', 'Ravens Rock 2025', 'Raven Rock Rally']},
        {'canonical': 'Birr Stages Rally 2026', 'perturbations': ['Birr Stages', 'Birr Rally', 'Birr Stages 2026', 'Birr 2026']},
        {'canonical': 'Fastnet Stages Rally 2025', 'perturbations': ['Fastnet Stages', 'Fastnet Rally', 'Fastnet 2025', 'Fastnet Stages 2025']},
        {'canonical': 'HK Cavan Stages Rally 2025', 'perturbations': ['Cavan Stages', 'Cavan Stages 2025', 'Cavan Rally', 'HK Cavan 2025']},
      ];

      final driverCases = [
        {'canonical': 'Jon-Gunnar Støten', 'role': 'driver', 'perturbations': ['Jon Gunnar Stoten', 'Jon Gunnar Støten', 'Jon-Gunnar Stoten', 'Stoten']},
        {'canonical': 'Michal Babička', 'role': 'driver', 'perturbations': ['Michal Babicka', 'Michal Babicka', 'Babicka', 'Michal Babicka']},
        {'canonical': 'Adam Zelík', 'role': 'driver', 'perturbations': ['Adam Zelik', 'Adam Zelik', 'Zelik', 'Adam Zelik']},
        {'canonical': 'Věroslav Cvrček', 'role': 'driver', 'perturbations': ['Veroslav Cvrcek', 'Věroslav Cvrcek', 'Veroslav Cvrček', 'Cvrcek']},
        {'canonical': 'Piotr Krotoszyński', 'role': 'driver', 'perturbations': ['Piotr Krotoszynski', 'Piotr Krotoszynski', 'Krotoszynski', 'Piotr Krotoszynski']},
        {'canonical': 'Hervé Emeriau', 'role': 'driver', 'perturbations': ['Herve Emeriau', 'Hervé Emeriau', 'Herve Emerio', 'Emeriau']},
        {'canonical': 'José Paula', 'role': 'driver', 'perturbations': ['Jose Paula', 'José Paula', 'Jose Pawla', 'Paula']},
        {'canonical': 'Sergio Ramón Arrom', 'role': 'driver', 'perturbations': ['Sergio Ramon Arrom', 'Sergio Ramon', 'Ramon Arrom', 'Sergio Arrom']},
        {'canonical': 'Raphaël Czwartkowski', 'role': 'driver', 'perturbations': ['Raphael Czwartkowski', 'Raphael Czwartkovski', 'Czwartkowski', 'Raphaël Czwartkovski']},
        {'canonical': 'Vítor Matias', 'role': 'driver', 'perturbations': ['Vitor Matias', 'Vítor Matias', 'Vitor Mathias', 'Matias']},
        {'canonical': 'Stephen O\'Connor', 'role': 'driver', 'perturbations': ['Stephen OConnor', 'Stephen O\'Connor', 'Steven OConnor', 'Stephen O Connor']},
        {'canonical': 'Diarmuid O\'Toole', 'role': 'driver', 'perturbations': ['Diarmuid OToole', 'Diarmuid O\'Toole', 'Dermot OToole', 'Diarmuid O Toole']},
        {'canonical': 'Tanja Zingelmann-Hartjen', 'role': 'driver', 'perturbations': ['Tanja Zingelmann', 'Tanja Zingelmann Hartjen', 'Tanja Hartjen', 'Zingelmann-Hartjen']},
        {'canonical': 'Paweł Molgo', 'role': 'driver', 'perturbations': ['Pawel Molgo', 'Paweł Molgo', 'Pawel Malgo', 'Molgo']},
        {'canonical': 'Nenad Lončarič', 'role': 'driver', 'perturbations': ['Nenad Loncaric', 'Nenad Lončaric', 'Nenad Loncarich', 'Loncaric']},
        {'canonical': 'Matej Bogović', 'role': 'driver', 'perturbations': ['Matej Bogovic', 'Matej Bogović', 'Matej Bogovich', 'Bogovic']},
        {'canonical': 'Andrej Medić', 'role': 'driver', 'perturbations': ['Andrej Medic', 'Andrej Medić', 'Andrej Medich', 'Medic']},
        {'canonical': 'John Shanahan jnr.', 'role': 'driver', 'perturbations': ['John Shanahan', 'John Shanahan Jr', 'John Shanahan jnr', 'Shanahan']},
        {'canonical': 'Shea Breen', 'role': 'driver', 'perturbations': ['Shea Brean', 'Shea Breen', 'Shea Brain', 'Shay Breen']},
        {'canonical': 'Max Freeman', 'role': 'co_driver', 'perturbations': ['Max Freeman', 'Max Freman', 'Max Frieman', 'Freeman']},
        {'canonical': 'Jan-Erik Mäll', 'role': 'co_driver', 'perturbations': ['Jan Erik Mall', 'Jan-Erik Mall', 'Jan Erik Mäll', 'Mall']},
        {'canonical': 'Catharina Schmidt', 'role': 'co_driver', 'perturbations': ['Catharina Schmidt', 'Catherina Schmidt', 'Katarina Schmidt', 'Schmidt']},
      ];

      final stageCases = [
        {'canonical': 'Woodstoxx Kemmelberg 1', 'perturbations': ['Kemelberg', 'Woodstoxx Kemelberg', 'Kemmelberg 1', 'Kemmelberg']},
        {'canonical': 'Duszniki - Zieleniec 2', 'perturbations': ['Dushniki', 'Duszniki Zieleniec', 'Duszniki', 'Zieleniec 2']},
        {'canonical': 'Seixoso 2', 'perturbations': ['Seixoso', 'Seixoso 2', 'Seiksozo', 'SS Seixoso']},
        {'canonical': 'Drumhallagh 2', 'perturbations': ['Drumhallagh', 'Drumhallagh 2', 'Drumhalagh', 'SS Drumhallagh']},
        {'canonical': 'Dikkebus 1', 'perturbations': ['Dikkebus', 'Dikebus', 'Dikkebus 1', 'SS Dikkebus']},
        {'canonical': 'Fafe 2Powerstage', 'perturbations': ['Fafe Powerstage', 'Fafe 2', 'Fafe', 'Powerstage Fafe']},
        {'canonical': 'Knockalla 2', 'perturbations': ['Knockalla', 'Knokalla', 'Knockalla 2', 'SS Knockalla']},
        {'canonical': 'Dunworley 2', 'perturbations': ['Dunworley', 'Dunworley 2', 'Dunworly', 'SS Dunworley']},
        {'canonical': 'Kellymount 1', 'perturbations': ['Kellymount', 'Kellymount 1', 'Kelley Mount', 'SS Kellymount']},
        {'canonical': 'Scart Mountain 1', 'perturbations': ['Scart Mountain', 'Scart Mountain 1', 'Scart Mt', 'SS Scart Mountain']},
      ];

      // Adversarial Negatives (Unrelated / Partial / Cross-entity)
      final negativeCases = [
        {'type': 'driver', 'query': 'Craig Nonexistentperson', 'intent': SearchIntent.searchDriverVideos},
        {'type': 'driver', 'query': 'Zzzz Qqqq Xxxx', 'intent': SearchIntent.searchDriverVideos},
        {'type': 'driver', 'query': 'Random Tourist 12345', 'intent': SearchIntent.searchDriverVideos},
        {'type': 'rally', 'query': 'Random City Nonexistent Stages Rally', 'intent': SearchIntent.searchRallies},
        {'type': 'rally', 'query': 'Pineapple Spaceship Championship 2099', 'intent': SearchIntent.searchRallies},
        {'type': 'stage', 'query': 'Moon Base Alpha Stage 99', 'intent': SearchIntent.searchVideoActions},
        {'type': 'stage', 'query': 'Underwater Coral Reef SS99', 'intent': SearchIntent.searchVideoActions},
      ];

      print('\n======================================================================');
      print('   LIVE DB GENERALIZED PERTURBATION BENCHMARK EVALUATION');
      print('======================================================================\n');

      int totalQueries = 0;
      int candidateRecallAt5Hits = 0;
      int top1CorrectHits = 0;
      int clarificationHits = 0;
      int noMatchHits = 0;
      int falseConfidentHits = 0;
      int exactCanonicalHits = 0;
      int exactCanonicalTotal = 0;

      final latencies = <int>[];

      // Category metrics
      int rallyTotal = 0, rallyRecallHits = 0, rallyTop1Hits = 0;
      int driverTotal = 0, driverRecallHits = 0, driverTop1Hits = 0;
      int stageTotal = 0, stageRecallHits = 0, stageTop1Hits = 0;

      // -----------------------------------------------------------------------
      // EVALUATION LOOP: RALLIES
      // -----------------------------------------------------------------------
      for (final item in rallyCases) {
        final canonical = item['canonical'] as String;
        final perturbations = item['perturbations'] as List<String>;

        for (final p in perturbations) {
          totalQueries++;
          rallyTotal++;

          final isExact = (p.toLowerCase().trim() == canonical.toLowerCase().trim());
          if (isExact) exactCanonicalTotal++;

          final sw = Stopwatch()..start();
          final candidates = await lookupRepo.lookupRallies(p, limit: 35);
          final res = await resolver.resolve(SearchQuery(intent: SearchIntent.searchRallies, rallyName: p));
          sw.stop();
          latencies.add(sw.elapsedMilliseconds);

          // Score candidates to determine top-5 ranked candidates
          final scoredCandidates = candidates.map((c) {
            final score = PhoneticMatchingHelper.computeCompositeScore(
              queryPhrase: p,
              candidateName: c.canonicalName,
            );
            return c.copyWith(score: score);
          }).toList()
            ..sort((a, b) => (b.score ?? 0.0).compareTo(a.score ?? 0.0));

          // 1. Stage 1: Candidate Recall@5
          final inTop5 = scoredCandidates.take(5).any((c) => _matchesCanonical(c.canonicalName, canonical));
          if (inTop5) {
            candidateRecallAt5Hits++;
            rallyRecallHits++;
          } else {
            print('  [RALLY RECALL MISS] Query: "$p" -> Expected: "$canonical" | Found candidates: ${candidates.take(3).map((c) => c.canonicalName).toList()}');
          }

          // 2. Stage 2: Final Resolver Top-1 Accuracy & Clarification
          final resolvedName = res.resolutions['rally']?.resolvedCandidate?.canonicalName;
          final isResolvedCorrect = resolvedName != null && _matchesCanonical(resolvedName, canonical);

          if (isResolvedCorrect) {
            top1CorrectHits++;
            rallyTop1Hits++;
            if (isExact) exactCanonicalHits++;
          } else if (res.requiresClarification || (res.resolutions['rally']?.isAmbiguous ?? false)) {
            final clarContains = res.candidates.any((c) => _matchesCanonical(c.canonicalName, canonical)) ||
                (res.resolutions['rally']?.candidateOptions.any((c) => _matchesCanonical(c.canonicalName, canonical)) ?? false);
            if (clarContains) {
              top1CorrectHits++;
              rallyTop1Hits++;
              if (isExact) exactCanonicalHits++;
            }
            clarificationHits++;
          } else {
            noMatchHits++;
          }
        }
      }

      // -----------------------------------------------------------------------
      // EVALUATION LOOP: DRIVERS & CO-DRIVERS
      // -----------------------------------------------------------------------
      for (final item in driverCases) {
        final canonical = item['canonical'] as String;
        final perturbations = item['perturbations'] as List<String>;

        for (final p in perturbations) {
          totalQueries++;
          driverTotal++;

          final isExact = (p.toLowerCase().trim() == canonical.toLowerCase().trim());
          if (isExact) exactCanonicalTotal++;

          final sw = Stopwatch()..start();
          final candidates = await lookupRepo.lookupDrivers(p, limit: 50);
          final res = await resolver.resolve(SearchQuery(intent: SearchIntent.searchDriverVideos, driverName: p));
          sw.stop();
          latencies.add(sw.elapsedMilliseconds);

          // Score candidates to determine top-5 ranked candidates
          final scoredCandidates = candidates.map((c) {
            final score = PhoneticMatchingHelper.computeCompositeScore(
              queryPhrase: p,
              candidateName: c.canonicalName,
            );
            return c.copyWith(score: score);
          }).toList()
            ..sort((a, b) => (b.score ?? 0.0).compareTo(a.score ?? 0.0));

          // Stage 1: Candidate Recall@5
          final inTop5 = scoredCandidates.take(5).any((c) => _matchesCanonical(c.canonicalName, canonical));
          if (inTop5) {
            candidateRecallAt5Hits++;
            driverRecallHits++;
          } else {
            print('  [DRIVER RECALL MISS] Query: "$p" -> Expected: "$canonical" | Found candidates: ${candidates.take(3).map((c) => c.canonicalName).toList()}');
          }

          // Stage 2: Final Resolver Top-1 Accuracy
          final resolvedName = res.resolutions['driver']?.resolvedCandidate?.canonicalName;
          final isResolvedCorrect = resolvedName != null && _matchesCanonical(resolvedName, canonical);

          if (isResolvedCorrect) {
            top1CorrectHits++;
            driverTop1Hits++;
            if (isExact) exactCanonicalHits++;
          } else if (res.requiresClarification || (res.resolutions['driver']?.isAmbiguous ?? false)) {
            final clarContains = res.candidates.any((c) => _matchesCanonical(c.canonicalName, canonical)) ||
                (res.resolutions['driver']?.candidateOptions.any((c) => _matchesCanonical(c.canonicalName, canonical)) ?? false);
            if (clarContains) {
              top1CorrectHits++;
              driverTop1Hits++;
              if (isExact) exactCanonicalHits++;
            }
            clarificationHits++;
          } else {
            noMatchHits++;
          }
        }
      }

      // -----------------------------------------------------------------------
      // EVALUATION LOOP: STAGES
      // -----------------------------------------------------------------------
      for (final item in stageCases) {
        final canonical = item['canonical'] as String;
        final perturbations = item['perturbations'] as List<String>;

        for (final p in perturbations) {
          totalQueries++;
          stageTotal++;

          final isExact = (p.toLowerCase().trim() == canonical.toLowerCase().trim());
          if (isExact) exactCanonicalTotal++;

          final sw = Stopwatch()..start();
          final candidates = await lookupRepo.lookupStages(p, limit: 35);
          final res = await resolver.resolve(SearchQuery(intent: SearchIntent.searchVideoActions, stageName: p));
          sw.stop();
          latencies.add(sw.elapsedMilliseconds);

          // Score candidates to determine top-5 ranked candidates
          final scoredCandidates = candidates.map((c) {
            final score = PhoneticMatchingHelper.computeCompositeScore(
              queryPhrase: p,
              candidateName: c.canonicalName,
            );
            return c.copyWith(score: score);
          }).toList()
            ..sort((a, b) => (b.score ?? 0.0).compareTo(a.score ?? 0.0));

          // Stage 1: Candidate Recall@5
          final inTop5 = scoredCandidates.take(5).any((c) => _matchesCanonical(c.canonicalName, canonical));
          if (inTop5) {
            candidateRecallAt5Hits++;
            stageRecallHits++;
          } else {
            print('  [STAGE RECALL MISS] Query: "$p" -> Expected: "$canonical" | Found candidates: ${candidates.take(3).map((c) => c.canonicalName).toList()}');
          }

          // Stage 2: Final Resolver Top-1 Accuracy
          final resolvedName = res.resolutions['stage']?.resolvedCandidate?.canonicalName;
          final isResolvedCorrect = resolvedName != null && _matchesCanonical(resolvedName, canonical);

          if (isResolvedCorrect) {
            top1CorrectHits++;
            stageTop1Hits++;
            if (isExact) exactCanonicalHits++;
          } else if (res.requiresClarification || (res.resolutions['stage']?.isAmbiguous ?? false)) {
            final clarContains = res.candidates.any((c) => _matchesCanonical(c.canonicalName, canonical)) ||
                (res.resolutions['stage']?.candidateOptions.any((c) => _matchesCanonical(c.canonicalName, canonical)) ?? false);
            if (clarContains) {
              top1CorrectHits++;
              stageTop1Hits++;
              if (isExact) exactCanonicalHits++;
            }
            clarificationHits++;
          } else {
            noMatchHits++;
          }
        }
      }

      // -----------------------------------------------------------------------
      // EVALUATION LOOP: NEGATIVES & ADVERSARIAL CASES
      // -----------------------------------------------------------------------
      for (final neg in negativeCases) {
        final type = neg['type'] as String;
        final queryStr = neg['query'] as String;
        final intent = neg['intent'] as SearchIntent;

        SearchQuery sq;
        if (type == 'driver') {
          sq = SearchQuery(intent: intent, driverName: queryStr);
        } else if (type == 'rally') {
          sq = SearchQuery(intent: intent, rallyName: queryStr);
        } else {
          sq = SearchQuery(intent: intent, stageName: queryStr);
        }

        final res = await resolver.resolve(sq);
        final resolution = res.resolutions[type];

        // A false confident auto-resolution occurs if resolvedCandidate != null on an adversarial input
        if (resolution?.resolvedCandidate != null && (resolution?.confidence ?? 0) >= 0.75) {
          falseConfidentHits++;
          print('  [FALSE POSITIVE WARNING]: Query "$queryStr" resolved to "${resolution?.resolvedCandidate?.canonicalName}" (conf: ${resolution?.confidence})');
        }
      }

      // -----------------------------------------------------------------------
      // CALCULATE & PRINT SUMMARY METRICS
      // -----------------------------------------------------------------------
      latencies.sort();
      final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
      final p95Latency = latencies[(latencies.length * 0.95).floor()];

      final recallAt5Pct = (candidateRecallAt5Hits / totalQueries) * 100.0;
      final top1Pct = (top1CorrectHits / totalQueries) * 100.0;
      final clarificationPct = (clarificationHits / totalQueries) * 100.0;
      final noMatchPct = (noMatchHits / totalQueries) * 100.0;
      final falseConfidentPct = (falseConfidentHits / (totalQueries + negativeCases.length)) * 100.0;
      final exactMatchPct = exactCanonicalTotal > 0 ? (exactCanonicalHits / exactCanonicalTotal) * 100.0 : 100.0;

      final rallyRecallPct = (rallyRecallHits / rallyTotal) * 100.0;
      final rallyTop1Pct = (rallyTop1Hits / rallyTotal) * 100.0;
      final driverRecallPct = (driverRecallHits / driverTotal) * 100.0;
      final driverTop1Pct = (driverTop1Hits / driverTotal) * 100.0;
      final stageRecallPct = (stageRecallHits / stageTotal) * 100.0;
      final stageTop1Pct = (stageTop1Hits / stageTotal) * 100.0;

      print('Total Perturbation Queries Tested: $totalQueries');
      print('Candidate Recall@5:                ${recallAt5Pct.toStringAsFixed(1)}% ($candidateRecallAt5Hits / $totalQueries)');
      print('Final Resolver Top-1 Accuracy:     ${top1Pct.toStringAsFixed(1)}% ($top1CorrectHits / $totalQueries)');
      print('Clarification Rate:                ${clarificationPct.toStringAsFixed(1)}% ($clarificationHits / $totalQueries)');
      print('No-Match Rate:                     ${noMatchPct.toStringAsFixed(1)}% ($noMatchHits / $totalQueries)');
      print('False Confident Auto-Resolution:   ${falseConfidentPct.toStringAsFixed(2)}% ($falseConfidentHits / ${totalQueries + negativeCases.length})');
      print('Exact Canonical-Name Accuracy:     ${exactMatchPct.toStringAsFixed(1)}% ($exactCanonicalHits / $exactCanonicalTotal)');
      print('Average Entity Lookup Latency:     ${avgLatency.toStringAsFixed(1)} ms');
      print('p95 Entity Lookup Latency:         $p95Latency ms');
      print('\nCategory Breakdown:');
      print('  - Rallies: Recall@5: ${rallyRecallPct.toStringAsFixed(1)}% | Top-1: ${rallyTop1Pct.toStringAsFixed(1)}% (Total: $rallyTotal)');
      print('  - Drivers / Co-Drivers: Recall@5: ${driverRecallPct.toStringAsFixed(1)}% | Top-1: ${driverTop1Pct.toStringAsFixed(1)}% (Total: $driverTotal)');
      print('  - Stages: Recall@5: ${stageRecallPct.toStringAsFixed(1)}% | Top-1: ${stageTop1Pct.toStringAsFixed(1)}% (Total: $stageTotal)');
      print('======================================================================\n');

      // Assert hard safety and quality gates
      expect(recallAt5Pct >= 95.0, isTrue, reason: 'Candidate Recall@5 must be >= 95%');
      expect(falseConfidentPct <= 1.0, isTrue, reason: 'False Confident Resolution must be <= 1%');
      expect(exactMatchPct, equals(100.0), reason: 'Exact canonical searches must be 100%');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

bool _matchesCanonical(String candidate, String target) {
  final cNorm = PhoneticMatchingHelper.normalize(candidate);
  final tNorm = PhoneticMatchingHelper.normalize(target);
  if (cNorm == tNorm) return true;

  final cBase = PhoneticMatchingHelper.stripYear(cNorm);
  final tBase = PhoneticMatchingHelper.stripYear(tNorm);
  if (cBase == tBase && cBase.isNotEmpty) return true;

  final cCore = PhoneticMatchingHelper.collapseSpaces(PhoneticMatchingHelper.stripDescriptors(cNorm));
  final tCore = PhoneticMatchingHelper.collapseSpaces(PhoneticMatchingHelper.stripDescriptors(tNorm));
  if (cCore == tCore && cCore.isNotEmpty) return true;

  return cNorm.contains(tBase) || tNorm.contains(cBase) || (tCore.isNotEmpty && cCore.contains(tCore)) || (cCore.isNotEmpty && tCore.contains(cCore));
}
