// ignore_for_file: avoid_print
@Tags(['live-db', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/entity_search/controlled_fallback_entity_resolver.dart';
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
  test('known real-device top five', () async {
    await dotenv.load(fileName: '.env');
    final db = DatabaseService();
    final source = MySqlEntitySearchDataSource(database: db);
    final allEntities = await source.loadEntities();
    final service = InMemoryEntitySearchService.fromEntities(allEntities);
    final old = DatabaseEntityLookupRepository(dbService: db);
    final legacyResolver = DatabaseEntityResolver(repository: old);
    final integrated = ControlledFallbackEntityResolver(
      legacyResolver: legacyResolver,
      entitySearchResolver: DatabaseEntityResolver(
        repository: EntitySearchLookupAdapter(
          searchService: service,
          cityFallback: old,
        ),
      ),
      config: const EntitySearchFallbackConfig(
        mode: EntitySearchFallbackMode.fallback,
      ),
    );
    const cases = <(String, SearchEntityType, String)>[
      ('aluksni', SearchEntityType.rally, 'aluksne'),
      ('aluksnay', SearchEntityType.rally, 'aluksne'),
      ('aluksney', SearchEntityType.rally, 'aluksne'),
      ('alux new', SearchEntityType.rally, 'aluksne'),
      ('a looks nay', SearchEntityType.rally, 'aluksne'),
      ('eluksne', SearchEntityType.rally, 'aluksne'),
      ('aluknse', SearchEntityType.rally, 'aluksne'),
      ('pawel malgo', SearchEntityType.person, 'pawel molgo'),
      ('shea brain', SearchEntityType.person, 'shea breen'),
      ('donny gall', SearchEntityType.rally, 'donegal'),
      ('kemel berg', SearchEntityType.stage, 'kemmelberg'),
      ('dushniki', SearchEntityType.stage, 'duszniki'),
    ];
    final results = <Map<String, Object?>>[];
    for (final item in cases) {
      final request = EntitySearchRequest(
        rawMention: item.$1,
        entityType: item.$2,
        limit: 5,
      );
      final generated = service.candidateGenerator.generate(request);
      final candidates = await service.search(request);
      final generationStats = service.lastQueryStats!;
      final targetIds = allEntities
          .where(
            (entity) =>
                entity.entityType == item.$2 &&
                PhoneticMatchingHelper.normalize(entity.canonicalName)
                    .contains(item.$3),
          )
          .map((entity) => entity.canonicalId)
          .toSet();
      final query = _query(item.$1, item.$2);
      final legacy = await legacyResolver.resolve(query);
      final finalResult = await integrated.resolveControlled(
        query,
        voice: true,
      );
      final targetRank = candidates.indexWhere(
        (candidate) =>
            PhoneticMatchingHelper.normalize(candidate.canonicalName)
                .contains(item.$3),
      );
      final resolved = finalResult.resolutions.values
          .where((r) => r.isResolved)
          .map((r) => r.resolvedCandidate?.canonicalName)
          .whereType<String>()
          .firstOrNull;
      results.add({
        'input': item.$1,
        'type': item.$2.name,
        'legacyOutcome': _outcome(legacy),
        'newCandidateRank': targetRank < 0 ? null : targetRank + 1,
        'candidatePoolSize': generationStats.generatedCandidatePool,
        'fullUniverseSize': generationStats.fullUniverseSize,
        'fullScanEscape': generationStats.usedFullScanEscape,
        'canonicalTargetPresentInGeneratedPool': generated.canonicalIds.any(
          targetIds.contains,
        ),
        'finalResolverOutcome': _outcome(finalResult),
        'resolvedCanonicalName': resolved,
        'userVisibleBehavior': finalResult.requiresClarification
            ? finalResult.clarificationQuestion
            : resolved != null
            ? 'execute canonical result'
            : 'no match',
        'top5': candidates
            .map(
              (c) => {
                'id': c.canonicalId,
                'name': c.canonicalName,
                'score': c.score,
                'matchedSearchableName': c.metadata['matchedSearchableName'],
                'signals': c.signals.toMap(),
              },
            )
            .toList(),
      });
    }
    const path = 'test/eval/entity_search/known_real_device_report.json';
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    final diagnostics = <Map<String, Object?>>[];
    for (final item in const <(String, String)>[
      ('pawel malgo', 'Paweł Molgo'),
      ('shea brain', 'Shea Breen'),
    ]) {
      final expected = PhoneticMatchingHelper.normalize(item.$2);
      final matchingAccounts = allEntities.where((entity) {
        if (entity.entityType != SearchEntityType.person) return false;
        final names = <String>[
          entity.canonicalName,
          ..._searchableNames(entity.metadata['searchableNames']),
        ];
        return names.any(
          (name) => PhoneticMatchingHelper.normalize(name) == expected,
        );
      }).toList();
      final ranked = await service.search(
        EntitySearchRequest(
          rawMention: item.$1,
          entityType: SearchEntityType.person,
          limit: allEntities.length,
        ),
      );
      final accountIds = matchingAccounts.map((e) => e.canonicalId).toSet();
      final rank = ranked.indexWhere((c) => accountIds.contains(c.canonicalId));
      final matched = rank < 0 ? null : ranked[rank];
      diagnostics.add({
        'input': item.$1,
        'expectedCanonicalName': item.$2,
        'queryNormalized': PhoneticMatchingHelper.normalize(item.$1),
        'entityExists': matchingAccounts.isNotEmpty,
        'matchingAccounts': matchingAccounts
            .map(
              (entity) => {
                'canonicalId': entity.canonicalId,
                'canonicalDisplayName': entity.canonicalName,
                'canonicalNormalized': PhoneticMatchingHelper.normalize(
                  entity.canonicalName,
                ),
                'searchableNames': _searchableNames(
                  entity.metadata['searchableNames'],
                ),
                'normalizedSearchableNames': _searchableNames(
                  entity.metadata['searchableNames'],
                ).map(PhoneticMatchingHelper.normalize).toList(),
              },
            )
            .toList(),
        'rank': rank < 0 ? null : rank + 1,
        'score': matched?.score,
        'signals': matched?.signals.toMap(),
        'strongestCompetitors': ranked
            .take(5)
            .map(
              (candidate) => {
                'canonicalId': candidate.canonicalId,
                'canonicalName': candidate.canonicalName,
                'score': candidate.score,
                'signals': candidate.signals.toMap(),
              },
            )
            .toList(),
      });
    }
    const diagnosticPath =
        'test/eval/entity_search/known_person_failure_diagnostic.json';
    await File(diagnosticPath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(diagnostics));
    print(const JsonEncoder.withIndent('  ').convert(results));
    await db.close();
  });
}

List<String> _searchableNames(Object? value) => switch (value) {
  List values => values.map((value) => value.toString()).toList(),
  Set values => values.map((value) => value.toString()).toList(),
  String value => [value],
  _ => const [],
};

SearchQuery _query(String mention, SearchEntityType type) => SearchQuery(
  intent: type == SearchEntityType.person
      ? SearchIntent.searchDriverVideos
      : type == SearchEntityType.stage
      ? SearchIntent.searchVideoActions
      : SearchIntent.searchRallies,
  driverNames: type == SearchEntityType.person ? [mention] : const [],
  rallyNames: type == SearchEntityType.rally ? [mention] : const [],
  stageNames: type == SearchEntityType.stage ? [mention] : const [],
);

String _outcome(dynamic result) {
  if (result.requiresClarification == true) return 'clarification';
  if (result.error != null) return 'no_match';
  if ((result.resolutions as Map).values.any((r) => r.isResolved == true)) {
    return 'resolved';
  }
  return 'no_match';
}
