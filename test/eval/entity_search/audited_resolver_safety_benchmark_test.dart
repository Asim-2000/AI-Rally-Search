// ignore_for_file: avoid_print
@Tags(['live-db', 'benchmark'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/services/database_service.dart';
import 'package:ai_rally_search/services/entity_search/entity_search_lookup_adapter.dart';
import 'package:ai_rally_search/services/entity_search/in_memory_entity_search_service.dart';
import 'package:ai_rally_search/services/entity_search/mysql_entity_search_data_source.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/database_entity_resolver.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_lookup_repository.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/phonetic_matching_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'NEW retrieval plus existing resolver: audited 168-query safety suite',
    () async {
      await dotenv.load(fileName: '.env');
      final db = DatabaseService();
      final service = InMemoryEntitySearchService(
        dataSource: MySqlEntitySearchDataSource(database: db),
      );
      await service.rebuild();
      final old = DatabaseEntityLookupRepository(dbService: db);
      final resolver = DatabaseEntityResolver(
        repository: EntitySearchLookupAdapter(
          searchService: service,
          cityFallback: old,
        ),
      );
      final positives = _positives;
      final negatives = _negatives;
      expect(positives.length, 62);
      expect(negatives.length, 106);

      var correctConfident = 0,
          wrongPositiveConfident = 0,
          positiveClarification = 0,
          positiveNoMatch = 0;
      var negativeWrongConfident = 0,
          negativeClarification = 0,
          negativeRejection = 0;
      final positiveDetails = <Map<String, Object?>>[];
      final negativeDetails = <Map<String, Object?>>[];

      for (final item in positives) {
        final result = await resolver.resolve(_query(item.input, item.type));
        final resolved = result.resolutions.values
            .where((r) => r.isResolved)
            .firstOrNull
            ?.resolvedCandidate
            ?.canonicalName;
        final correct =
            resolved != null && _sameTarget(resolved, item.canonical);
        if (correct) {
          correctConfident++;
        } else if (resolved != null) {
          wrongPositiveConfident++;
        } else if (result.requiresClarification) {
          positiveClarification++;
        } else {
          positiveNoMatch++;
        }
        positiveDetails.add({
          'input': item.input,
          'canonical': item.canonical,
          'type': item.type.name,
          'resolved': resolved,
          'correct': correct,
          'clarification': result.requiresClarification,
          'error': result.error,
        });
      }
      for (final item in negatives) {
        final result = await resolver.resolve(_query(item.input, item.type));
        final resolved = result.resolutions.values
            .where((r) => r.isResolved)
            .firstOrNull
            ?.resolvedCandidate
            ?.canonicalName;
        if (resolved != null) {
          negativeWrongConfident++;
        } else if (result.requiresClarification) {
          negativeClarification++;
        } else {
          negativeRejection++;
        }
        negativeDetails.add({
          'input': item.input,
          'type': item.type.name,
          'resolved': resolved,
          'clarification': result.requiresClarification,
          'error': result.error,
        });
      }
      final report = {
        'totalQueries': positives.length + negatives.length,
        'positive': {
          'queries': positives.length,
          'correctConfident': correctConfident,
          'wrongConfident': wrongPositiveConfident,
          'clarification': positiveClarification,
          'noMatch': positiveNoMatch,
          'details': positiveDetails,
        },
        'negativeConfusable': {
          'queries': negatives.length,
          'wrongConfident': negativeWrongConfident,
          'clarification': negativeClarification,
          'rejection': negativeRejection,
          'details': negativeDetails,
        },
        'falseConfidentAutoResolution':
            wrongPositiveConfident + negativeWrongConfident,
      };
      const path =
          'test/eval/entity_search/audited_resolver_safety_report.json';
      await File(path)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      print(
        const JsonEncoder.withIndent('  ').convert({
          'totalQueries': report['totalQueries'],
          'positive': {
            for (final e in (report['positive'] as Map).entries)
              if (e.key != 'details') e.key: e.value,
          },
          'negativeConfusable': {
            for (final e in (report['negativeConfusable'] as Map).entries)
              if (e.key != 'details') e.key: e.value,
          },
          'falseConfidentAutoResolution':
              report['falseConfidentAutoResolution'],
        }),
      );
      await db.close();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

typedef _Case = ({String canonical, String input, EntityType type});
typedef _Negative = ({String input, EntityType type});

SearchQuery _query(String input, EntityType type) => SearchQuery(
  intent: type == EntityType.driver
      ? SearchIntent.searchDriverVideos
      : type == EntityType.rally
      ? SearchIntent.searchRallies
      : SearchIntent.searchVideoActions,
  driverNames: type == EntityType.driver ? [input] : const [],
  rallyNames: type == EntityType.rally ? [input] : const [],
  stageNames: type == EntityType.stage ? [input] : const [],
  personRole: PersonRole.any,
);

bool _sameTarget(String actual, String expected) {
  final a = PhoneticMatchingHelper.collapseSpaces(
    PhoneticMatchingHelper.stripDescriptors(actual),
  );
  final e = PhoneticMatchingHelper.collapseSpaces(
    PhoneticMatchingHelper.stripDescriptors(expected),
  );
  return a == e || a.contains(e) || e.contains(a);
}

const _positives = <_Case>[
  (canonical: 'Rally Alūksne 2026', input: 'aluksnay', type: EntityType.rally),
  (
    canonical: 'Rally Alūksne 2026',
    input: 'a looks nay',
    type: EntityType.rally,
  ),
  (canonical: 'Rally Alūksne 2026', input: 'alux new', type: EntityType.rally),
  (canonical: 'Rally Alūksne 2026', input: 'eluksne', type: EntityType.rally),
  (canonical: 'Rally Alūksne 2026', input: 'aluknse', type: EntityType.rally),
  (canonical: 'Rally Alūksne 2026', input: 'aluksney', type: EntityType.rally),
  (canonical: 'Paweł Molgo', input: 'pawel malgo', type: EntityType.driver),
  (canonical: 'Shea Breen', input: 'shea brain', type: EntityType.driver),
  (
    canonical: 'Donegal International Rally',
    input: 'donny gall rally',
    type: EntityType.rally,
  ),
  (
    canonical: 'Woodstoxx Kemmelberg 1',
    input: 'kemel berg',
    type: EntityType.stage,
  ),
  (
    canonical: 'Duszniki - Zieleniec 2',
    input: 'dushniki',
    type: EntityType.stage,
  ),
  (
    canonical: '6 Uren van Kortrijk 2024',
    input: 'kortrik',
    type: EntityType.rally,
  ),
  (
    canonical: 'Rali Serras de Fafe 2025',
    input: 'Serras de Fafe',
    type: EntityType.rally,
  ),
  (
    canonical: '7bet Rally Lazdijai 2025',
    input: 'lazdiai',
    type: EntityType.rally,
  ),
  (
    canonical: "Rali Terras d'Aboboreira 2026",
    input: 'aboborera',
    type: EntityType.rally,
  ),
  (
    canonical: 'Polski Rajd Legend 2026',
    input: 'Polski Raid Legend',
    type: EntityType.rally,
  ),
  (
    canonical: 'Rally Vranov 2026',
    input: 'Rally Vranow',
    type: EntityType.rally,
  ),
  (
    canonical: 'OBM Land der 1000 Hügel Rallye 2026',
    input: '1000 Hugel Rallye',
    type: EntityType.rally,
  ),
  (
    canonical: 'Rallijsprints Cesavine 2026',
    input: 'Cesavine',
    type: EntityType.rally,
  ),
  (
    canonical: 'Rallye Régional des Ardennes 2025',
    input: 'Regional des Ardennes',
    type: EntityType.rally,
  ),
  (
    canonical: 'Century 21 Portugal Rally Series - Castelo Branco 2025',
    input: 'Castelo Branco 2025',
    type: EntityType.rally,
  ),
  (
    canonical: 'Assess Ireland International Rally of the Lakes 2026',
    input: 'Rally of the Lakes',
    type: EntityType.rally,
  ),
  (
    canonical: 'Clonakilty Park Hotel West Cork Rally 2026',
    input: 'West Cork Rally',
    type: EntityType.rally,
  ),
  (
    canonical: 'Samsonas Rally Fivemiletown 2026',
    input: 'Fivemiletown Rally',
    type: EntityType.rally,
  ),
  (
    canonical: 'Modern Tyres Ulster Rally 2025',
    input: 'Ulster Rally 2025',
    type: EntityType.rally,
  ),
  (
    canonical: "Raven's Rock Stages Rally 2025",
    input: 'Ravens Rock Stages',
    type: EntityType.rally,
  ),
  (
    canonical: 'Birr Stages Rally 2026',
    input: 'Birr Stages 2026',
    type: EntityType.rally,
  ),
  (
    canonical: 'Fastnet Stages Rally 2025',
    input: 'Fastnet Stages 2025',
    type: EntityType.rally,
  ),
  (
    canonical: 'HK Cavan Stages Rally 2025',
    input: 'Cavan Stages 2025',
    type: EntityType.rally,
  ),
  (
    canonical: 'Jon-Gunnar Støten',
    input: 'Jon Gunnar Stoten',
    type: EntityType.driver,
  ),
  (
    canonical: 'Michal Babička',
    input: 'Michal Babicka',
    type: EntityType.driver,
  ),
  (canonical: 'Adam Zelík', input: 'Adam Zelik', type: EntityType.driver),
  (
    canonical: 'Věroslav Cvrček',
    input: 'Veroslav Cvrcek',
    type: EntityType.driver,
  ),
  (
    canonical: 'Piotr Krotoszyński',
    input: 'Piotr Krotoszynski',
    type: EntityType.driver,
  ),
  (canonical: 'Hervé Emeriau', input: 'Herve Emerio', type: EntityType.driver),
  (canonical: 'José Paula', input: 'Jose Pawla', type: EntityType.driver),
  (
    canonical: 'Sergio Ramón Arrom',
    input: 'Sergio Ramon',
    type: EntityType.driver,
  ),
  (
    canonical: 'Raphaël Czwartkowski',
    input: 'Raphael Czwartkovski',
    type: EntityType.driver,
  ),
  (canonical: 'Vítor Matias', input: 'Vitor Mathias', type: EntityType.driver),
  (
    canonical: "Stephen O'Connor",
    input: 'Steven OConnor',
    type: EntityType.driver,
  ),
  (
    canonical: "Diarmuid O'Toole",
    input: 'Dermot OToole',
    type: EntityType.driver,
  ),
  (
    canonical: 'Tanja Zingelmann-Hartjen',
    input: 'Tanja Zingelmann',
    type: EntityType.driver,
  ),
  (
    canonical: 'Nenad Lončarič',
    input: 'Nenad Loncarich',
    type: EntityType.driver,
  ),
  (
    canonical: 'Matej Bogović',
    input: 'Matej Bogovich',
    type: EntityType.driver,
  ),
  (canonical: 'Andrej Medić', input: 'Andrej Medich', type: EntityType.driver),
  (
    canonical: 'John Shanahan jnr.',
    input: 'John Shanahan Jr',
    type: EntityType.driver,
  ),
  (canonical: 'Max Freeman', input: 'Max Frieman', type: EntityType.driver),
  (canonical: 'Jan-Erik Mäll', input: 'Jan Erik Mall', type: EntityType.driver),
  (
    canonical: 'Catharina Schmidt',
    input: 'Katarina Schmidt',
    type: EntityType.driver,
  ),
  (canonical: 'Paweł Molgo', input: 'Pawel Molgo', type: EntityType.driver),
  (canonical: 'Shea Breen', input: 'Shea Breen', type: EntityType.driver),
  (canonical: 'Jon-Gunnar Støten', input: 'Stoten', type: EntityType.driver),
  (canonical: 'Věroslav Cvrček', input: 'Cvrcek', type: EntityType.driver),
  (
    canonical: 'Woodstoxx Kemmelberg 1',
    input: 'Kemmelberg 1',
    type: EntityType.stage,
  ),
  (
    canonical: 'Duszniki - Zieleniec 2',
    input: 'Duszniki Zieleniec',
    type: EntityType.stage,
  ),
  (canonical: 'Seixoso 2', input: 'Seiksozo', type: EntityType.stage),
  (canonical: 'Drumhallagh 2', input: 'Drumhalagh', type: EntityType.stage),
  (canonical: 'Dikkebus 1', input: 'Dikebus', type: EntityType.stage),
  (
    canonical: 'Fafe 2Powerstage',
    input: 'Fafe Powerstage',
    type: EntityType.stage,
  ),
  (canonical: 'Knockalla 2', input: 'Knokalla', type: EntityType.stage),
  (canonical: 'Dunworley 2', input: 'Dunworly', type: EntityType.stage),
  (canonical: 'Kellymount 1', input: 'Kelley Mount 1', type: EntityType.stage),
];

final _negatives = <_Negative>[
  for (final name in [
    'Josh Smith',
    'Sam Williams',
    "Keith O'Connor",
    'Craig McErlean',
    'Callum Breen',
    'Paul Moffett',
    'David Cronin',
    'Michael Devine',
    'Mark Freeman',
    'John Breen',
    'Brain',
    'Breenan',
    'Moffitt',
    'Moffat',
    'Cronan',
    'Devaney',
    'Molgow',
    'Stotenberg',
    'Zelinski',
    'Babic',
  ])
    (input: name, type: EntityType.driver),
  for (final name in [
    'Rally of the Mountains',
    'International Stages',
    'West Coast Rally',
    'Cork 25 Stages',
    'Donegal 1972',
    'Galway 1981',
    'Lakes Rally 1990',
    'Ulster Stages 1965',
    'Aluksne 1999',
    'Fafe Classic 1985',
  ])
    (input: name, type: EntityType.rally),
  for (final name in [
    'Super Stage 1',
    'Powerstage Final',
    'Mountain Pass 2',
    'Forest Stage 3',
    'Sprint Stage 1',
    'Town Stage 2',
  ])
    (input: name, type: EntityType.stage),
  for (var i = 1; i <= 70; i++)
    (
      input: 'FictionalEntity$i PseudoName',
      type: i.isEven ? EntityType.driver : EntityType.rally,
    ),
];
