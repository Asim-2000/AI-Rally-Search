// ignore_for_file: avoid_print
@Tags(['live-db', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/controlled_fallback_entity_resolver.dart';
import 'package:ai_rally_search/services/entity_search/entity_candidate_generator.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_lookup_adapter.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_models.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart Shared Fixture Benchmark Runner', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();
    final dataSource = MySqlEntitySearchDataSource(database: db);
    final entities = await dataSource.loadEntities();

    final indexedService = InMemoryEntitySearchService.fromEntities(entities);
    final fullScanService = InMemoryEntitySearchService.fromEntities(
      entities,
      candidateGenerator: FullScanCandidateGenerator(),
    );

    final oldRepo = DatabaseEntityLookupRepository(dbService: db);
    final metrics = EntitySearchFallbackMetrics();
    final adapter = EntitySearchLookupAdapter(
      searchService: indexedService,
      cityFallback: oldRepo,
      metrics: metrics,
    );
    final resolver = DatabaseEntityResolver(repository: adapter);
    final fallbackResolver = ControlledFallbackEntityResolver(
      legacyResolver: DatabaseEntityResolver(repository: oldRepo),
      entitySearchResolver: resolver,
      config: const EntitySearchFallbackConfig(
        mode: EntitySearchFallbackMode.fallback,
      ),
      metrics: metrics,
    );

    SearchEntityType parseEntityType(String typeStr) {
      switch (typeStr.toLowerCase()) {
        case 'rally':
          return SearchEntityType.rally;
        case 'person':
        case 'driver':
        case 'co_driver':
          return SearchEntityType.person;
        case 'stage':
          return SearchEntityType.stage;
        case 'uploader':
          return SearchEntityType.uploader;
        default:
          return SearchEntityType.person;
      }
    }

    PersonRole parsePersonRole(String? roleStr) {
      if (roleStr == null) return PersonRole.any;
      switch (roleStr.toLowerCase()) {
        case 'driver':
          return PersonRole.driver;
        case 'co_driver':
        case 'codriver':
          return PersonRole.coDriver;
        default:
          return PersonRole.any;
      }
    }

    // =========================================================================
    // 1. RUN 803 SUITE
    // =========================================================================
    final file803 = File('test/eval/entity_search/frozen_803_cases.json');
    expect(file803.existsSync(), isTrue);
    final cases803 = json.decode(file803.readAsStringSync()) as List<dynamic>;
    expect(cases803.length, 803);

    final results803 = <Map<String, dynamic>>[];
    var r1Count803 = 0, r5Count803 = 0, r10Count803 = 0;
    var reciprocalSum803 = 0.0;
    var escapes803 = 0;

    for (final rawCase in cases803) {
      final c = rawCase as Map<String, dynamic>;
      final caseId = c['caseId'] as String;
      final targetId = c['targetCanonicalId'] as String;
      final targetName = c['targetCanonicalName'] as String;
      final type = parseEntityType(c['entityType'] as String);
      final role = parsePersonRole(c['personRole'] as String?);
      final input = c['input'] as String;

      final req = EntitySearchRequest(
        rawMention: input,
        entityType: type,
        personRole: role,
        limit: 10,
      );

      final generated = indexedService.candidateGenerator.generate(req);
      final candidates = await indexedService.search(req);
      final stats = indexedService.lastQueryStats;

      final poolSize = generated.canonicalIds.length;
      final targetPresent = generated.canonicalIds.contains(targetId);
      final isEscape = stats?.usedFullScanEscape ?? false;
      if (isEscape) escapes803++;

      int? targetRank;
      for (var i = 0; i < candidates.length; i++) {
        if (candidates[i].canonicalId == targetId) {
          targetRank = i + 1;
          break;
        }
      }

      if (targetRank == 1) {
        r1Count803++;
        r5Count803++;
        r10Count803++;
        reciprocalSum803 += 1.0;
      } else if (targetRank != null && targetRank <= 5) {
        r5Count803++;
        r10Count803++;
        reciprocalSum803 += 1.0 / targetRank;
      } else if (targetRank != null && targetRank <= 10) {
        r10Count803++;
        reciprocalSum803 += 1.0 / targetRank;
      }

      final topScore = candidates.isNotEmpty ? candidates.first.score : 0.0;
      final secondScore = candidates.length > 1 ? candidates[1].score : 0.0;
      final scoreGap = candidates.isNotEmpty ? topScore - secondScore : 0.0;

      // Deterministic Resolver evaluation
      final query = type == SearchEntityType.person
          ? SearchQuery(
              intent: SearchIntent.searchDriverVideos,
              driverNames: [input],
              personRole: role,
            )
          : type == SearchEntityType.rally
          ? SearchQuery(
              intent: SearchIntent.searchRallies,
              rallyNames: [input],
            )
          : SearchQuery(
              intent: SearchIntent.searchVideoActions,
              stageNames: [input],
            );

      final resResult = await resolver.resolve(query);
      final primaryRes = resResult.resolutions.values.firstOrNull;

      String resolverOutcome;
      String? selectedCanonicalId;
      String resolverReason;

      if (primaryRes == null || !primaryRes.isResolved && !primaryRes.isAmbiguous) {
        resolverOutcome = 'NO_MATCH';
        resolverReason = primaryRes?.strategy ?? 'no_resolution';
      } else if (primaryRes.isAmbiguous || resResult.requiresClarification) {
        resolverOutcome = 'CLARIFICATION';
        resolverReason = primaryRes.strategy;
      } else {
        resolverOutcome = 'RESOLVED';
        selectedCanonicalId = primaryRes.resolvedCandidate?.id;
        resolverReason = primaryRes.strategy;
      }

      results803.add({
        'caseId': caseId,
        'expectedCanonicalId': targetId,
        'expectedCanonicalName': targetName,
        'entityType': c['entityType'],
        'personRole': c['personRole'],
        'input': input,
        'candidatePoolSize': poolSize,
        'targetPresent': targetPresent,
        'targetRank': targetRank,
        'topCandidates': candidates.map((cand) => cand.canonicalId).toList(),
        'resolverOutcome': resolverOutcome,
        'selectedCanonicalId': selectedCanonicalId,
        'resolverReason': resolverReason,
        'topScore': topScore,
        'scoreGap': scoreGap,
        'fullScanEscape': isEscape,
        'escapeReason': isEscape ? 'insufficient_candidates' : null,
      });
    }

    final summary803 = {
      'cases': cases803.length,
      'recallAt1': r1Count803 / cases803.length,
      'recallAt5': r5Count803 / cases803.length,
      'recallAt10': r10Count803 / cases803.length,
      'mrr': reciprocalSum803 / cases803.length,
      'fullScanEscapes': escapes803,
      'results': results803,
    };
    File('test/eval/entity_search/dart_803_results.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(summary803),
    );
    print('Dart 803: R@1=${summary803['recallAt1']} MRR=${summary803['mrr']} escapes=$escapes803');

    // =========================================================================
    // 2. RUN PERSON_FROZEN_1101 SUITE
    // =========================================================================
    final file1101 = File('test/eval/entity_search/frozen_1101_person_cases.json');
    expect(file1101.existsSync(), isTrue);
    final cases1101 = json.decode(file1101.readAsStringSync()) as List<dynamic>;
    expect(cases1101.length, 1101);

    final results1101 = <Map<String, dynamic>>[];
    var r1Count1101 = 0, r5Count1101 = 0, r10Count1101 = 0;
    var reciprocalSum1101 = 0.0;
    var escapes1101 = 0;

    final groupMetrics = <String, Map<String, dynamic>>{
      'ACCOUNT_BACKED': {'cases': 0, 'r1': 0, 'r5': 0, 'r10': 0, 'mrr': 0.0},
      'NULL_DRIVER': {'cases': 0, 'r1': 0, 'r5': 0, 'r10': 0, 'mrr': 0.0},
      'NULL_CODRIVER': {'cases': 0, 'r1': 0, 'r5': 0, 'r10': 0, 'mrr': 0.0},
    };

    for (final rawCase in cases1101) {
      final c = rawCase as Map<String, dynamic>;
      final caseId = c['caseId'] as String;
      final group = c['group'] as String;
      final targetId = c['targetCanonicalId'] as String;
      final targetName = c['targetCanonicalName'] as String;
      final role = parsePersonRole(c['personRole'] as String?);
      final input = c['input'] as String;

      final req = EntitySearchRequest(
        rawMention: input,
        entityType: SearchEntityType.person,
        personRole: role,
        limit: 10,
      );

      final generated = indexedService.candidateGenerator.generate(req);
      final candidates = await indexedService.search(req);
      final stats = indexedService.lastQueryStats;

      final poolSize = generated.canonicalIds.length;
      final targetPresent = generated.canonicalIds.contains(targetId);
      final isEscape = stats?.usedFullScanEscape ?? false;
      if (isEscape) escapes1101++;

      int? targetRank;
      for (var i = 0; i < candidates.length; i++) {
        if (candidates[i].canonicalId == targetId) {
          targetRank = i + 1;
          break;
        }
      }

      final gm = groupMetrics[group]!;
      gm['cases'] = (gm['cases'] as int) + 1;

      if (targetRank == 1) {
        r1Count1101++;
        r5Count1101++;
        r10Count1101++;
        reciprocalSum1101 += 1.0;
        gm['r1'] = (gm['r1'] as int) + 1;
        gm['r5'] = (gm['r5'] as int) + 1;
        gm['r10'] = (gm['r10'] as int) + 1;
        gm['mrr'] = (gm['mrr'] as double) + 1.0;
      } else if (targetRank != null && targetRank <= 5) {
        r5Count1101++;
        r10Count1101++;
        reciprocalSum1101 += 1.0 / targetRank;
        gm['r5'] = (gm['r5'] as int) + 1;
        gm['r10'] = (gm['r10'] as int) + 1;
        gm['mrr'] = (gm['mrr'] as double) + 1.0 / targetRank;
      } else if (targetRank != null && targetRank <= 10) {
        r10Count1101++;
        reciprocalSum1101 += 1.0 / targetRank;
        gm['r10'] = (gm['r10'] as int) + 1;
        gm['mrr'] = (gm['mrr'] as double) + 1.0 / targetRank;
      }

      final topScore = candidates.isNotEmpty ? candidates.first.score : 0.0;
      final secondScore = candidates.length > 1 ? candidates[1].score : 0.0;
      final scoreGap = candidates.isNotEmpty ? topScore - secondScore : 0.0;

      final query = SearchQuery(
        intent: SearchIntent.searchDriverVideos,
        driverNames: [input],
        personRole: role,
      );

      final resResult = await resolver.resolve(query);
      final primaryRes = resResult.resolutions.values.firstOrNull;

      String resolverOutcome;
      String? selectedCanonicalId;
      String resolverReason;

      if (primaryRes == null || !primaryRes.isResolved && !primaryRes.isAmbiguous) {
        resolverOutcome = 'NO_MATCH';
        resolverReason = primaryRes?.strategy ?? 'no_resolution';
      } else if (primaryRes.isAmbiguous || resResult.requiresClarification) {
        resolverOutcome = 'CLARIFICATION';
        resolverReason = primaryRes.strategy;
      } else {
        resolverOutcome = 'RESOLVED';
        selectedCanonicalId = primaryRes.resolvedCandidate?.id;
        resolverReason = primaryRes.strategy;
      }

      results1101.add({
        'caseId': caseId,
        'group': group,
        'expectedCanonicalId': targetId,
        'expectedCanonicalName': targetName,
        'entityType': 'person',
        'personRole': c['personRole'],
        'input': input,
        'candidatePoolSize': poolSize,
        'targetPresent': targetPresent,
        'targetRank': targetRank,
        'topCandidates': candidates.map((cand) => cand.canonicalId).toList(),
        'resolverOutcome': resolverOutcome,
        'selectedCanonicalId': selectedCanonicalId,
        'resolverReason': resolverReason,
        'topScore': topScore,
        'scoreGap': scoreGap,
        'fullScanEscape': isEscape,
        'escapeReason': isEscape ? 'insufficient_candidates' : null,
      });
    }

    final summary1101 = {
      'cases': cases1101.length,
      'recallAt1': r1Count1101 / cases1101.length,
      'recallAt5': r5Count1101 / cases1101.length,
      'recallAt10': r10Count1101 / cases1101.length,
      'mrr': reciprocalSum1101 / cases1101.length,
      'byGroup': {
        for (final entry in groupMetrics.entries)
          entry.key: {
            'cases': entry.value['cases'],
            'recallAt1': (entry.value['r1'] as int) / (entry.value['cases'] as int),
            'recallAt5': (entry.value['r5'] as int) / (entry.value['cases'] as int),
            'recallAt10': (entry.value['r10'] as int) / (entry.value['cases'] as int),
            'mrr': (entry.value['mrr'] as double) / (entry.value['cases'] as int),
          },
      },
      'results': results1101,
    };
    File('test/eval/entity_search/dart_1101_person_results.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(summary1101),
    );
    print('Dart 1101: R@1=${summary1101['recallAt1']} MRR=${summary1101['mrr']}');

    // =========================================================================
    // 3. RUN 168 SAFETY SUITE
    // =========================================================================
    final file168 = File('test/eval/entity_search/frozen_168_safety_cases.json');
    expect(file168.existsSync(), isTrue);
    final cases168 = json.decode(file168.readAsStringSync()) as List<dynamic>;
    expect(cases168.length, 168);

    final results168 = <Map<String, dynamic>>[];
    var correctConfident168 = 0;
    var wrongPositiveConfident168 = 0;
    var positiveClarification168 = 0;
    var positiveNoMatch168 = 0;
    var negativeWrongConfident168 = 0;
    var negativeClarification168 = 0;
    var negativeRejection168 = 0;

    for (final rawCase in cases168) {
      final c = rawCase as Map<String, dynamic>;
      final caseId = c['caseId'] as String;
      final category = c['category'] as String;
      final input = c['input'] as String;
      final expectedName = c['expectedCanonicalName'] as String?;
      final type = parseEntityType(c['entityType'] as String);
      final role = parsePersonRole(c['personRole'] as String?);

      final query = type == SearchEntityType.person
          ? SearchQuery(
              intent: SearchIntent.searchDriverVideos,
              driverNames: [input],
              personRole: role,
            )
          : type == SearchEntityType.rally
          ? SearchQuery(
              intent: SearchIntent.searchRallies,
              rallyNames: [input],
            )
          : SearchQuery(
              intent: SearchIntent.searchVideoActions,
              stageNames: [input],
            );

      final result = await fallbackResolver.resolve(query);
      final primary = result.resolutions.values.firstOrNull;
      final resolvedName = primary?.resolvedCandidate?.canonicalName;
      final isClarification = result.requiresClarification || (primary?.isAmbiguous ?? false);
      final isResolved = primary != null && primary.isResolved && resolvedName != null;

      String outcome;
      if (isResolved) {
        outcome = 'RESOLVED';
      } else if (isClarification) {
        outcome = 'CLARIFICATION';
      } else {
        outcome = 'NO_MATCH';
      }

      if (category == 'positive') {
        final sameTarget = resolvedName != null &&
            expectedName != null &&
            (PhoneticMatchingHelper.normalize(resolvedName) == PhoneticMatchingHelper.normalize(expectedName) ||
                resolvedName.contains(expectedName) ||
                expectedName.contains(resolvedName));

        if (isResolved && sameTarget) {
          correctConfident168++;
        } else if (isResolved) {
          wrongPositiveConfident168++;
        } else if (isClarification) {
          positiveClarification168++;
        } else {
          positiveNoMatch168++;
        }
      } else {
        if (isResolved) {
          negativeWrongConfident168++;
        } else if (isClarification) {
          negativeClarification168++;
        } else {
          negativeRejection168++;
        }
      }

      results168.add({
        'caseId': caseId,
        'category': category,
        'input': input,
        'expectedCanonicalName': expectedName,
        'entityType': c['entityType'],
        'personRole': c['personRole'],
        'resolverOutcome': outcome,
        'selectedCanonicalName': resolvedName,
        'selectedCanonicalId': primary?.resolvedCandidate?.id,
        'resolverReason': primary?.strategy,
        'requiresClarification': isClarification,
      });
    }

    final summary168 = {
      'totalQueries': cases168.length,
      'positive': {
        'queries': 62,
        'correctConfident': correctConfident168,
        'wrongConfident': wrongPositiveConfident168,
        'clarification': positiveClarification168,
        'noMatch': positiveNoMatch168,
      },
      'negativeConfusable': {
        'queries': 106,
        'wrongConfident': negativeWrongConfident168,
        'clarification': negativeClarification168,
        'rejection': negativeRejection168,
      },
      'falseConfidentAutoResolution': wrongPositiveConfident168 + negativeWrongConfident168,
      'results': results168,
    };
    File('test/eval/entity_search/dart_168_safety_results.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(summary168),
    );
    print('Dart 168: falseConfident=${summary168['falseConfidentAutoResolution']}');

    // =========================================================================
    // 4. RUN KNOWN TRANSCRIPTS SUITE
    // =========================================================================
    final fileTranscripts = File('test/eval/entity_search/frozen_known_transcripts_cases.json');
    expect(fileTranscripts.existsSync(), isTrue);
    final casesTranscripts = json.decode(fileTranscripts.readAsStringSync()) as List<dynamic>;
    expect(casesTranscripts.length, 12);

    final resultsTranscripts = <Map<String, dynamic>>[];
    for (final rawCase in casesTranscripts) {
      final c = rawCase as Map<String, dynamic>;
      final caseId = c['caseId'] as String;
      final input = c['input'] as String;
      final expectedName = c['expectedCanonicalName'] as String;
      final type = parseEntityType(c['entityType'] as String);
      final role = parsePersonRole(c['personRole'] as String?);

      final req = EntitySearchRequest(
        rawMention: input,
        entityType: type,
        personRole: role,
        limit: 10,
      );

      final generated = indexedService.candidateGenerator.generate(req);
      final candidates = await indexedService.search(req);
      final stats = indexedService.lastQueryStats;

      final poolSize = generated.canonicalIds.length;
      final isEscape = stats?.usedFullScanEscape ?? false;

      int? targetRank;
      for (var i = 0; i < candidates.length; i++) {
        if (candidates[i].canonicalName == expectedName ||
            PhoneticMatchingHelper.normalize(candidates[i].canonicalName) == PhoneticMatchingHelper.normalize(expectedName)) {
          targetRank = i + 1;
          break;
        }
      }

      final query = type == SearchEntityType.person
          ? SearchQuery(
              intent: SearchIntent.searchDriverVideos,
              driverNames: [input],
              personRole: role,
            )
          : type == SearchEntityType.rally
          ? SearchQuery(
              intent: SearchIntent.searchRallies,
              rallyNames: [input],
            )
          : SearchQuery(
              intent: SearchIntent.searchVideoActions,
              stageNames: [input],
            );

      final resResult = await resolver.resolve(query);
      final primaryRes = resResult.resolutions.values.firstOrNull;

      String resolverOutcome;
      String? selectedName;
      if (primaryRes != null && primaryRes.isResolved && primaryRes.resolvedCandidate != null) {
        resolverOutcome = 'RESOLVED';
        selectedName = primaryRes.resolvedCandidate!.canonicalName;
      } else if (resResult.requiresClarification || (primaryRes?.isAmbiguous ?? false)) {
        resolverOutcome = 'CLARIFICATION';
      } else {
        resolverOutcome = 'NO_MATCH';
      }

      resultsTranscripts.add({
        'caseId': caseId,
        'input': input,
        'expectedCanonicalName': expectedName,
        'entityType': c['entityType'],
        'personRole': c['personRole'],
        'candidatePoolSize': poolSize,
        'targetPresent': targetRank != null,
        'targetRank': targetRank,
        'topCandidateName': candidates.isNotEmpty ? candidates.first.canonicalName : null,
        'topCandidateScore': candidates.isNotEmpty ? candidates.first.score : 0.0,
        'resolverOutcome': resolverOutcome,
        'resolverReason': primaryRes?.strategy,
        'selectedCanonicalName': selectedName,
        'fullScanEscape': isEscape,
      });
    }

    File('test/eval/entity_search/dart_known_transcripts_results.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(resultsTranscripts),
    );
    print('Dart Known Transcripts complete: 12 cases.');
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 15)));
}
