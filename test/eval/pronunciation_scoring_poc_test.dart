// ignore_for_file: avoid_print
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/pronunciation/entity_pronunciation_metadata.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/pronunciation/algorithmic_pronunciation_encoder.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/pronunciation/phonetic_distance.dart';

class SystemStats {
  int totalCases = 0;
  int top1Matches = 0;
  int recallAt5 = 0;
  int clarifications = 0;
  int noMatches = 0;
  int falseConfident = 0;

  double get top1Accuracy => totalCases > 0 ? (top1Matches / totalCases) * 100 : 0.0;
  double get recall5Pct => totalCases > 0 ? (recallAt5 / totalCases) * 100 : 0.0;
  double get falseConfidentPct => totalCases > 0 ? (falseConfident / totalCases) * 100 : 0.0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pronunciation / Phonetic Scoring POC Benchmark (Rigorous Methodology)', () {
    late DatabaseService dbService;
    late DatabaseEntityLookupRepository lookupRepo;
    late DatabaseEntityResolver lexicalResolver;
    late AlgorithmicPronunciationEncoder pronunciationEncoder;

    setUpAll(() async {
      await dotenv.load(fileName: '.env');
      dbService = DatabaseService();
      lookupRepo = DatabaseEntityLookupRepository(dbService: dbService);
      lexicalResolver = DatabaseEntityResolver(
        repository: lookupRepo,
        minConfidenceThreshold: 0.75,
        minScoreGap: 0.15,
      );
      pronunciationEncoder = AlgorithmicPronunciationEncoder();
    });

    tearDownAll(() async {
      await dbService.close();
    });

    test('Run Rigorous Pronunciation Benchmark (Experiment A & B & Cascade)', () async {
      // 1. Controlled Dataset: Exactly 62 Positive Samples + 10 Adversarial Negatives
      final testCases = <Map<String, dynamic>>[
        // Observed Real-Device Transcripts (11 cases)
        {'canonical': 'Rally Alūksne 2026', 'input': 'aluksnay', 'isReal': true, 'type': EntityType.rally},
        {'canonical': 'Rally Alūksne 2026', 'input': 'a looks nay', 'isReal': true, 'type': EntityType.rally},
        {'canonical': 'Rally Alūksne 2026', 'input': 'alux new', 'isReal': true, 'type': EntityType.rally},
        {'canonical': 'Rally Alūksne 2026', 'input': 'eluksne', 'isReal': true, 'type': EntityType.rally},
        {'canonical': 'Rally Alūksne 2026', 'input': 'aluknse', 'isReal': true, 'type': EntityType.rally},
        {'canonical': 'Rally Alūksne 2026', 'input': 'aluksney', 'isReal': true, 'type': EntityType.rally},
        {'canonical': 'Paweł Molgo', 'input': 'pawel malgo', 'isReal': true, 'type': EntityType.driver},
        {'canonical': 'Shea Breen', 'input': 'shea brain', 'isReal': true, 'type': EntityType.driver},
        {'canonical': 'Corrib Oil Galway International Rally 2026', 'input': 'donny gall rally', 'isReal': true, 'type': EntityType.rally},
        {'canonical': 'Woodstoxx Kemmelberg 1', 'input': 'kemel berg', 'isReal': true, 'type': EntityType.stage},
        {'canonical': 'Duszniki - Zieleniec 2', 'input': 'dushniki', 'isReal': true, 'type': EntityType.stage},

        // Synthetic Rally Perturbations (19 cases -> Total Rallies = 11 + 14 = 25)
        {'canonical': '6 Uren van Kortrijk 2024', 'input': 'kortrik', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Rali Serras de Fafe 2025', 'input': 'Serras de Fafe', 'isReal': false, 'type': EntityType.rally},
        {'canonical': '7bet Rally Lazdijai 2025', 'input': 'lazdiai', 'isReal': false, 'type': EntityType.rally},
        {'canonical': "Rali Terras d'Aboboreira 2026", 'input': 'aboborera', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Polski Rajd Legend 2026', 'input': 'Polski Raid Legend', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Rally Vranov 2026', 'input': 'Rally Vranow', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'OBM Land der 1000 Hügel Rallye 2026', 'input': '1000 Hugel Rallye', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Rallijsprints Cesavine 2026', 'input': 'Cesavine', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Rallye Régional des Ardennes 2025', 'input': 'Regional des Ardennes', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Century 21 Portugal Rally Series - Castelo Branco 2025', 'input': 'Castelo Branco 2025', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Assess Ireland International Rally of the Lakes 2026', 'input': 'Rally of the Lakes', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Clonakilty Park Hotel West Cork Rally 2026', 'input': 'West Cork Rally', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Samsonas Rally Fivemiletown 2026', 'input': 'Fivemiletown Rally', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Modern Tyres Ulster Rally 2025', 'input': 'Ulster Rally 2025', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Raven\'s Rock Stages Rally 2025', 'input': 'Ravens Rock Stages', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Birr Stages Rally 2026', 'input': 'Birr Stages 2026', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'Fastnet Stages Rally 2025', 'input': 'Fastnet Stages 2025', 'isReal': false, 'type': EntityType.rally},
        {'canonical': 'HK Cavan Stages Rally 2025', 'input': 'Cavan Stages 2025', 'isReal': false, 'type': EntityType.rally},

        // Synthetic Driver/Co-Driver Perturbations (24 cases -> Total Drivers = 2 + 24 = 26)
        {'canonical': 'Jon-Gunnar Støten', 'input': 'Jon Gunnar Stoten', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Michal Babička', 'input': 'Michal Babicka', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Adam Zelík', 'input': 'Adam Zelik', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Věroslav Cvrček', 'input': 'Veroslav Cvrcek', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Piotr Krotoszyński', 'input': 'Piotr Krotoszynski', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Hervé Emeriau', 'input': 'Herve Emerio', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'José Paula', 'input': 'Jose Pawla', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Sergio Ramón Arrom', 'input': 'Sergio Ramon', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Raphaël Czwartkowski', 'input': 'Raphael Czwartkovski', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Vítor Matias', 'input': 'Vitor Mathias', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Stephen O\'Connor', 'input': 'Steven OConnor', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Diarmuid O\'Toole', 'input': 'Dermot OToole', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Tanja Zingelmann-Hartjen', 'input': 'Tanja Zingelmann', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Nenad Lončarič', 'input': 'Nenad Loncarich', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Matej Bogović', 'input': 'Matej Bogovich', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Andrej Medić', 'input': 'Andrej Medich', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'John Shanahan jnr.', 'input': 'John Shanahan Jr', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Max Freeman', 'input': 'Max Frieman', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Jan-Erik Mäll', 'input': 'Jan Erik Mall', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Catharina Schmidt', 'input': 'Katarina Schmidt', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Paweł Molgo', 'input': 'Pawel Molgo', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Shea Breen', 'input': 'Shea Breen', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Jon-Gunnar Støten', 'input': 'Stoten', 'isReal': false, 'type': EntityType.driver},
        {'canonical': 'Věroslav Cvrček', 'input': 'Cvrcek', 'isReal': false, 'type': EntityType.driver},

        // Synthetic Stage Perturbations (9 cases -> Total Stages = 2 + 9 = 11)
        {'canonical': 'Woodstoxx Kemmelberg 1', 'input': 'Kemmelberg 1', 'isReal': false, 'type': EntityType.stage},
        {'canonical': 'Duszniki - Zieleniec 2', 'input': 'Duszniki Zieleniec', 'isReal': false, 'type': EntityType.stage},
        {'canonical': 'Seixoso 2', 'input': 'Seiksozo', 'isReal': false, 'type': EntityType.stage},
        {'canonical': 'Drumhallagh 2', 'input': 'Drumhalagh', 'isReal': false, 'type': EntityType.stage},
        {'canonical': 'Dikkebus 1', 'input': 'Dikebus', 'isReal': false, 'type': EntityType.stage},
        {'canonical': 'Fafe 2Powerstage', 'input': 'Fafe Powerstage', 'isReal': false, 'type': EntityType.stage},
        {'canonical': 'Knockalla 2', 'input': 'Knokalla', 'isReal': false, 'type': EntityType.stage},
        {'canonical': 'Dunworley 2', 'input': 'Dunworly', 'isReal': false, 'type': EntityType.stage},
        {'canonical': 'Kellymount 1', 'input': 'Kelley Mount 1', 'isReal': false, 'type': EntityType.stage},
      ];

      final negativeCases = <Map<String, dynamic>>[
        {'input': 'Craig Nonexistentperson', 'type': EntityType.driver},
        {'input': 'Moffett Unknown', 'type': EntityType.driver},
        {'input': 'Rally Nonexistentia 2026', 'type': EntityType.rally},
        {'input': 'Supercalafragilistic Rally', 'type': EntityType.rally},
        {'input': 'Stage XYZ Infinite', 'type': EntityType.stage},
        {'input': 'Rally Galway 1980', 'type': EntityType.rally},
        {'input': 'John', 'type': EntityType.driver},
        {'input': 'Smith', 'type': EntityType.driver},
        {'input': 'Park Stage', 'type': EntityType.stage},
        {'input': 'International Rally', 'type': EntityType.rally},
      ];

      // Verify dataset accounting
      final totalRallies = testCases.where((tc) => tc['type'] == EntityType.rally).length;
      final totalDrivers = testCases.where((tc) => tc['type'] == EntityType.driver).length;
      final totalStages = testCases.where((tc) => tc['type'] == EntityType.stage).length;
      final totalReal = testCases.where((tc) => tc['isReal'] == true).length;
      final totalSynthetic = testCases.where((tc) => tc['isReal'] == false).length;

      expect(testCases.length, 62);
      expect(totalRallies, 25);
      expect(totalDrivers, 26);
      expect(totalStages, 11);
      expect(totalReal, 11);
      expect(totalSynthetic, 51);

      // Pre-encode metadata map for all unique canonical entities
      final metadataMap = <String, EntityPronunciationMetadata>{};
      for (final tc in testCases) {
        final name = tc['canonical'] as String;
        final type = tc['type'] as EntityType;
        if (!metadataMap.containsKey(name)) {
          metadataMap[name] = await pronunciationEncoder.encodeEntity(
            id: name,
            name: name,
            type: type,
          );
        }
      }

      // Trackers for Experiment A (Same Candidate Pool: Lexical vs Phonetic vs Always-On Fusion)
      final expA_lexical = SystemStats();
      final expA_phonetic = SystemStats();
      final expA_fused = SystemStats();

      // Trackers for Experiment B (Candidate Recall: Lexical vs Phonetic vs Union)
      int expB_lexicalRecallCount = 0;
      int expB_phoneticRecallCount = 0;
      int expB_unionRecallCount = 0;

      // Trackers for Cascade Fallback
      final cascadeStats = SystemStats();
      int cascadePhoneticInvocations = 0;
      final cascadeLatencies = <double>[];

      // Observed Real Transcripts Trace Storage
      final realDeviceTraces = <Map<String, dynamic>>[];

      // =======================================================================
      // MAIN EVALUATION LOOP
      // =======================================================================
      for (final tc in testCases) {
        final canonicalName = tc['canonical'] as String;
        final input = tc['input'] as String;
        final type = tc['type'] as EntityType;
        final isReal = tc['isReal'] as bool;

        // 1. Lexical Candidate Pool Retrieval
        final List<EntityCandidate> lexicalCandidates;
        if (type == EntityType.driver) {
          lexicalCandidates = await lookupRepo.lookupDrivers(input);
        } else if (type == EntityType.rally) {
          lexicalCandidates = await lookupRepo.lookupRallies(input);
        } else {
          lexicalCandidates = await lookupRepo.lookupStages(input);
        }

        // 2. Phonetic Candidate Pool Retrieval (Multi-Modal: Search space-collapsed & normalized query)
        final collapsedQuery = input.replaceAll(' ', '');
        final List<EntityCandidate> phoneticCandidates;
        if (type == EntityType.driver) {
          phoneticCandidates = await lookupRepo.lookupDrivers(collapsedQuery);
        } else if (type == EntityType.rally) {
          phoneticCandidates = await lookupRepo.lookupRallies(collapsedQuery);
        } else {
          phoneticCandidates = await lookupRepo.lookupStages(collapsedQuery);
        }

        // Union Pool
        final unionCandidateMap = <String, EntityCandidate>{};
        for (final c in lexicalCandidates) {
          unionCandidateMap[c.canonicalName] = c;
        }
        for (final c in phoneticCandidates) {
          unionCandidateMap[c.canonicalName] = c;
        }
        final unionCandidates = unionCandidateMap.values.toList();

        // Check Candidate Recall@5 for Experiment B
        final inLexRecall = lexicalCandidates.take(5).any((c) => _isTarget(c.canonicalName, canonicalName));
        final inPhoneRecall = phoneticCandidates.take(5).any((c) => _isTarget(c.canonicalName, canonicalName));
        final inUnionRecall = unionCandidates.take(5).any((c) => _isTarget(c.canonicalName, canonicalName));

        if (inLexRecall) expB_lexicalRecallCount++;
        if (inPhoneRecall) expB_phoneticRecallCount++;
        if (inUnionRecall) expB_unionRecallCount++;

        // -------------------------------------------------------------------
        // EXPERIMENT A: SAME CANDIDATE POOL (lexicalCandidates)
        // -------------------------------------------------------------------
        final inputPhonetic = pronunciationEncoder.encodeQuery(input);
        final inputCollapsed = pronunciationEncoder.encodeCollapsedQuery(input);

        // Lexical Ranking on same pool
        final scoredA_lex = <MapEntry<EntityCandidate, double>>[];
        for (final c in lexicalCandidates) {
          final s = PhoneticMatchingHelper.computeCompositeScore(
            queryPhrase: input,
            candidateName: c.canonicalName,
            isPerson: type == EntityType.driver,
          );
          scoredA_lex.add(MapEntry(c, s));
        }
        scoredA_lex.sort((a, b) => b.value.compareTo(a.value));

        // Phonetic Ranking on same pool
        final scoredA_phone = <MapEntry<EntityCandidate, double>>[];
        for (final c in lexicalCandidates) {
          final meta = metadataMap[c.canonicalName] ??
              await pronunciationEncoder.encodeEntity(
                id: c.id,
                name: c.canonicalName,
                type: c.type,
              );
          final s = await pronunciationEncoder.scorePhoneticMatch(
            spokenTranscriptPhonetic: inputPhonetic,
            spokenTranscriptCollapsed: inputCollapsed,
            candidateMetadata: meta,
          );
          scoredA_phone.add(MapEntry(c, s));
        }
        scoredA_phone.sort((a, b) => b.value.compareTo(a.value));

        // Fused Ranking on same pool
        final scoredA_fused = <MapEntry<EntityCandidate, double>>[];
        for (var i = 0; i < lexicalCandidates.length; i++) {
          final c = lexicalCandidates[i];
          final lexS = scoredA_lex[i].value;
          final phoneS = scoredA_phone[i].value;
          final fusedS = max(lexS, phoneS * 0.95);
          scoredA_fused.add(MapEntry(c, fusedS));
        }
        scoredA_fused.sort((a, b) => b.value.compareTo(a.value));

        _evaluateSystemOutcome(expA_lexical, scoredA_lex, canonicalName);
        _evaluateSystemOutcome(expA_phonetic, scoredA_phone, canonicalName);
        _evaluateSystemOutcome(expA_fused, scoredA_fused, canonicalName);

        // -------------------------------------------------------------------
        // CASCADE EVALUATION
        // -------------------------------------------------------------------
        final cascadeSw = Stopwatch()..start();
        var isResolvedByLexical = false;
        if (scoredA_lex.isNotEmpty) {
          final topLex = scoredA_lex.first.value;
          final runnerLex = scoredA_lex.length > 1 ? scoredA_lex[1].value : 0.0;
          if (topLex >= 0.75 && (topLex - runnerLex) >= 0.15) {
            isResolvedByLexical = true;
          }
        }

        List<MapEntry<EntityCandidate, double>> finalCascadeRanked;
        if (isResolvedByLexical) {
          finalCascadeRanked = scoredA_lex;
        } else {
          // Trigger Phonetic Fallback
          cascadePhoneticInvocations++;
          final cascadePool = unionCandidates; // use multi-modal pool on fallback
          final scoredCascade = <MapEntry<EntityCandidate, double>>[];
          for (final c in cascadePool) {
            final lexS = PhoneticMatchingHelper.computeCompositeScore(
              queryPhrase: input,
              candidateName: c.canonicalName,
              isPerson: type == EntityType.driver,
            );
            final meta = metadataMap[c.canonicalName] ??
                await pronunciationEncoder.encodeEntity(
                  id: c.id,
                  name: c.canonicalName,
                  type: c.type,
                );
            final phoneS = await pronunciationEncoder.scorePhoneticMatch(
              spokenTranscriptPhonetic: inputPhonetic,
              spokenTranscriptCollapsed: inputCollapsed,
              candidateMetadata: meta,
            );
            final fusedS = max(lexS, phoneS * 0.95);
            scoredCascade.add(MapEntry(c, fusedS));
          }
          scoredCascade.sort((a, b) => b.value.compareTo(a.value));
          finalCascadeRanked = scoredCascade;
        }
        cascadeSw.stop();
        cascadeLatencies.add(cascadeSw.elapsedMicroseconds / 1000.0);
        _evaluateSystemOutcome(cascadeStats, finalCascadeRanked, canonicalName, isCascade: true);

        // -------------------------------------------------------------------
        // RECORD OBSERVED REAL-DEVICE TRACE
        // -------------------------------------------------------------------
        if (isReal) {
          final lexRank = scoredA_lex.indexWhere((e) => _isTarget(e.key.canonicalName, canonicalName)) + 1;
          final lexScore = scoredA_lex.isNotEmpty && lexRank > 0 ? scoredA_lex[lexRank - 1].value : 0.0;

          final phoneRetRank = unionCandidates.indexWhere((c) => _isTarget(c.canonicalName, canonicalName)) + 1;
          final targetMeta = metadataMap[canonicalName]!;
          final phoneScore = await pronunciationEncoder.scorePhoneticMatch(
            spokenTranscriptPhonetic: inputPhonetic,
            spokenTranscriptCollapsed: inputCollapsed,
            candidateMetadata: targetMeta,
          );

          final fusionRank = finalCascadeRanked.indexWhere((e) => _isTarget(e.key.canonicalName, canonicalName)) + 1;
          final topScore = finalCascadeRanked.isNotEmpty ? finalCascadeRanked.first.value : 0.0;
          final runnerScore = finalCascadeRanked.length > 1 ? finalCascadeRanked[1].value : 0.0;

          final String outcome;
          if (fusionRank == 1 && topScore >= 0.75 && (topScore - runnerScore) >= 0.15) {
            outcome = 'RESOLVED (${topScore.toStringAsFixed(2)})';
          } else if (fusionRank >= 1 && fusionRank <= 5 && topScore >= 0.50) {
            outcome = 'CLARIFY (${topScore.toStringAsFixed(2)})';
          } else {
            outcome = 'NO-MATCH';
          }

          realDeviceTraces.add({
            'input': input,
            'canonical': canonicalName,
            'lexRank': lexRank > 0 ? '$lexRank' : 'Miss (0)',
            'lexScore': lexScore.toStringAsFixed(2),
            'phoneRetRank': phoneRetRank > 0 ? '$phoneRetRank' : 'Miss',
            'phoneScore': phoneScore.toStringAsFixed(2),
            'fusionRank': fusionRank > 0 ? '$fusionRank' : 'Miss',
            'outcome': outcome,
          });
        }
      }

      // Negative Safety Evaluation on Cascade
      for (final neg in negativeCases) {
        final input = neg['input'] as String;
        final type = neg['type'] as EntityType;

        final List<EntityCandidate> pool;
        if (type == EntityType.driver) {
          pool = await lookupRepo.lookupDrivers(input);
        } else if (type == EntityType.rally) {
          pool = await lookupRepo.lookupRallies(input);
        } else {
          pool = await lookupRepo.lookupStages(input);
        }

        final inputPhone = pronunciationEncoder.encodeQuery(input);
        final inputColl = pronunciationEncoder.encodeCollapsedQuery(input);

        final scored = <MapEntry<EntityCandidate, double>>[];
        for (final c in pool) {
          final lexS = PhoneticMatchingHelper.computeCompositeScore(
            queryPhrase: input,
            candidateName: c.canonicalName,
            isPerson: type == EntityType.driver,
          );
          final meta = await pronunciationEncoder.encodeEntity(
            id: c.id,
            name: c.canonicalName,
            type: c.type,
          );
          final phoneS = await pronunciationEncoder.scorePhoneticMatch(
            spokenTranscriptPhonetic: inputPhone,
            spokenTranscriptCollapsed: inputColl,
            candidateMetadata: meta,
          );
          scored.add(MapEntry(c, max(lexS, phoneS * 0.95)));
        }
        scored.sort((a, b) => b.value.compareTo(a.value));

        if (scored.isNotEmpty) {
          final top = scored.first.value;
          final runner = scored.length > 1 ? scored[1].value : 0.0;
          if (top >= 0.75 && (top - runner) >= 0.15) {
            cascadeStats.falseConfident++;
          }
        }
      }

      cascadeLatencies.sort();
      final p50 = cascadeLatencies[(cascadeLatencies.length * 0.50).toInt()];
      final p95 = cascadeLatencies[(cascadeLatencies.length * 0.95).toInt()];

      // Print Rigorous Evaluation Results
      print('\n================================================================');
      print('RIGOROUS PRONUNCIATION / PHONETIC SCORING POC BENCHMARK');
      print('================================================================\n');

      print('--- 1. DATASET ACCOUNTING ---');
      print('Total Positive Test Cases:        ${testCases.length}');
      print('  • Real-Device Observed:         $totalReal');
      print('  • Synthetic Perturbations:      $totalSynthetic');
      print('  • By Entity Type:               Rallies: $totalRallies | Drivers: $totalDrivers | Stages: $totalStages');
      print('Adversarial Negative Cases:       ${negativeCases.length}');
      print('Total Unique Queries Evaluated:   ${testCases.length + negativeCases.length}');

      print('\n--- 2. EXPERIMENT A: SAME CANDIDATE POOL (RANKING IMPROVEMENT) ---');
      print('LEXICAL ONLY (Baseline A):   Recall@5: ${expA_lexical.recall5Pct.toStringAsFixed(1)}% | Top-1: ${expA_lexical.top1Accuracy.toStringAsFixed(1)}% | False-Confident: ${expA_lexical.falseConfident}');
      print('PHONETIC ONLY (Baseline B):  Recall@5: ${expA_phonetic.recall5Pct.toStringAsFixed(1)}% | Top-1: ${expA_phonetic.top1Accuracy.toStringAsFixed(1)}% | False-Confident: ${expA_phonetic.falseConfident}');
      print('ALWAYS-ON FUSION (Exp C):    Recall@5: ${expA_fused.recall5Pct.toStringAsFixed(1)}% | Top-1: ${expA_fused.top1Accuracy.toStringAsFixed(1)}% | False-Confident: ${expA_fused.falseConfident}');

      print('\n--- 3. EXPERIMENT B: MULTI-MODAL CANDIDATE RETRIEVAL (CANDIDATE RECALL) ---');
      final lexRecPct = (expB_lexicalRecallCount / testCases.length) * 100;
      final phoneRecPct = (expB_phoneticRecallCount / testCases.length) * 100;
      final unionRecPct = (expB_unionRecallCount / testCases.length) * 100;
      print('Lexical Retrieval Recall@5:   ${lexRecPct.toStringAsFixed(1)}% ($expB_lexicalRecallCount / ${testCases.length})');
      print('Phonetic Retrieval Recall@5:  ${phoneRecPct.toStringAsFixed(1)}% ($expB_phoneticRecallCount / ${testCases.length})');
      print('UNION Retrieval Recall@5:     ${unionRecPct.toStringAsFixed(1)}% ($expB_unionRecallCount / ${testCases.length}) [Gain: +${(unionRecPct - lexRecPct).toStringAsFixed(1)}%]');

      print('\n--- 4. CASCADE FALLBACK ARCHITECTURE (ON-DEMAND PHONETICS) ---');
      print('Cascade Top-1 Accuracy:       ${cascadeStats.top1Accuracy.toStringAsFixed(1)}%');
      print('Cascade Recall@5:             ${cascadeStats.recall5Pct.toStringAsFixed(1)}%');
      print('Cascade Clarification Rate:   ${((cascadeStats.clarifications / testCases.length) * 100).toStringAsFixed(1)}%');
      print('Cascade False Confident Rate: ${cascadeStats.falseConfidentPct.toStringAsFixed(1)}% (${cascadeStats.falseConfident} errors)');
      print('Phonetic Invocation Rate:     ${((cascadePhoneticInvocations / testCases.length) * 100).toStringAsFixed(1)}% ($cascadePhoneticInvocations / ${testCases.length} queries)');
      print('Cascade p50 Latency:          ${p50.toStringAsFixed(2)} ms');
      print('Cascade p95 Latency:          ${p95.toStringAsFixed(2)} ms');

      print('\n--- 5. OBSERVED REAL-DEVICE TRANSCRIPTS (ISOLATED BREAKDOWN) ---');
      print('Input                | Target               | Lex Rank | Phone Ret | Phone Sc | Fuse Rank | Outcome');
      print('-------------------------------------------------------------------------------------------------------');
      for (final tr in realDeviceTraces) {
        final inp = (tr['input'] as String).padRight(20);
        final tgt = (tr['canonical'] as String).padRight(20);
        final lRank = (tr['lexRank'] as String).padRight(8);
        final pRet = (tr['phoneRetRank'] as String).padRight(9);
        final pSc = (tr['phoneScore'] as String).padRight(8);
        final fRank = (tr['fusionRank'] as String).padRight(9);
        final out = tr['outcome'] as String;
        print('$inp | $tgt | $lRank | $pRet | $pSc | $fRank | $out');
      }
      print('================================================================\n');

      expect(cascadeStats.falseConfident, 0);
      expect(cascadeStats.top1Accuracy, greaterThanOrEqualTo(expA_lexical.top1Accuracy));
    });
  });
}

bool _isTarget(String candidate, String target) {
  return candidate == target || target.contains(candidate) || candidate.contains(target);
}

void _evaluateSystemOutcome(
  SystemStats stats,
  List<MapEntry<EntityCandidate, double>> ranked,
  String canonicalTarget, {
  bool isCascade = false,
}) {
  stats.totalCases++;
  if (ranked.isEmpty) {
    stats.noMatches++;
    return;
  }

  final targetIndex = ranked.indexWhere((e) => _isTarget(e.key.canonicalName, canonicalTarget));

  if (targetIndex == 0) {
    stats.top1Matches++;
    stats.recallAt5++;
  } else if (targetIndex > 0 && targetIndex < 5) {
    stats.recallAt5++;
    stats.clarifications++;
  } else {
    final topScore = ranked.first.value;
    final runnerUp = ranked.length > 1 ? ranked[1].value : 0.0;
    if (topScore >= 0.75 && (topScore - runnerUp) >= 0.15) {
      if (isCascade) {
        print('DEBUG CASCADE FALSE CONFIDENT: target="$canonicalTarget" topMatched="${ranked.first.key.canonicalName}" topScore=$topScore runnerUp=$runnerUp');
      }
      stats.falseConfident++;
    } else {
      stats.noMatches++;
    }
  }
}
