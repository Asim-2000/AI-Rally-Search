import 'dart:convert';
import 'dart:io';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Positive = ({String canonical, String input, EntityType type});
typedef _Negative = ({String input, EntityType type});

void main() {
  test('export frozen 168 safety cases', () {
    // 62 Positives
    final positives = <_Positive>[
      (canonical: 'Rally Alūksne 2026', input: 'Aluksne Rally', type: EntityType.rally),
      (canonical: 'Rally Alūksne 2026', input: 'Aluksnay', type: EntityType.rally),
      (canonical: 'Rally Alūksne 2026', input: 'Aluksney', type: EntityType.rally),
      (canonical: 'Rally Alūksne 2026', input: 'Alux new', type: EntityType.rally),
      (canonical: 'Rally Alūksne 2026', input: 'a looks nay', type: EntityType.rally),
      (canonical: 'Rally Alūksne 2026', input: 'Eluksne', type: EntityType.rally),
      (canonical: 'Rally Alūksne 2026', input: 'Aluknse', type: EntityType.rally),
      (canonical: 'Rally Sweden 2026', input: 'Rally Sweeden', type: EntityType.rally),
      (canonical: 'Rally Sweden 2026', input: 'Sweden Rally 2026', type: EntityType.rally),
      (canonical: 'Rally Sweden 2026', input: 'Sveden Rally', type: EntityType.rally),
      (canonical: 'Rally Islas Canarias 2025', input: 'Islas Canarias 2025', type: EntityType.rally),
      (canonical: 'Rally Islas Canarias 2025', input: 'Canarias Rally', type: EntityType.rally),
      (canonical: 'Rally Islas Canarias 2025', input: 'Canary Islands Rally', type: EntityType.rally),
      (canonical: 'Rally Islas Canarias 2025', input: 'Gran Canaria 2025', type: EntityType.rally),
      (canonical: 'Rali Ceredigion 2025', input: 'Ceredigion Rally', type: EntityType.rally),
      (canonical: 'Rali Ceredigion 2025', input: 'Rali Ceredigion', type: EntityType.rally),
      (canonical: 'Rali Ceredigion 2025', input: 'Cardigan Rally', type: EntityType.rally),
      (canonical: 'Rali Ceredigion 2025', input: 'Ceredigeon 2025', type: EntityType.rally),
      (canonical: 'Rali Serras de Fafe 2025', input: 'Fafe Rally', type: EntityType.rally),
      (canonical: 'Rali Serras de Fafe 2025', input: 'Serras de Fafe 2025', type: EntityType.rally),
      (canonical: 'Rali Serras de Fafe 2025', input: 'Fafe 2025', type: EntityType.rally),
      (canonical: 'Rali Serras de Fafe 2025', input: 'Serras de Fafe', type: EntityType.rally),
      (canonical: 'Donegal test rally 15th', input: 'Donegal test rally', type: EntityType.rally),
      (canonical: 'Donegal test rally 15th', input: 'Donegal test 15th', type: EntityType.rally),
      (canonical: 'Donegal test rally 15th', input: 'Donny gall', type: EntityType.rally),
      (canonical: 'Donegal test rally 15th', input: 'Donegal test', type: EntityType.rally),
      (canonical: 'Mid Ulster Forestry Rally 2025', input: 'Mid Ulster Rally', type: EntityType.rally),
      (canonical: 'Mid Ulster Forestry Rally 2025', input: 'Mid Ulster 2025', type: EntityType.rally),
      (canonical: 'Mid Ulster Forestry Rally 2025', input: 'Mid-Ulster Forestry', type: EntityType.rally),
      (canonical: 'Clonakilty Park Hotel West Cork Rally 2026', input: 'West Cork Rally 2026', type: EntityType.rally),
      (canonical: 'Clonakilty Park Hotel West Cork Rally 2026', input: 'West Cork Rally', type: EntityType.rally),
      (canonical: 'Samsonas Rally Fivemiletown 2026', input: 'Fivemiletown Rally', type: EntityType.rally),
      (canonical: 'Modern Tyres Ulster Rally 2025', input: 'Ulster Rally 2025', type: EntityType.rally),
      (canonical: "Raven's Rock Stages Rally 2025", input: 'Ravens Rock Stages', type: EntityType.rally),
      (canonical: 'Birr Stages Rally 2026', input: 'Birr Stages 2026', type: EntityType.rally),
      (canonical: 'Fastnet Stages Rally 2025', input: 'Fastnet Stages 2025', type: EntityType.rally),
      (canonical: 'HK Cavan Stages Rally 2025', input: 'Cavan Stages 2025', type: EntityType.rally),
      (canonical: 'Jon-Gunnar Støten', input: 'Jon Gunnar Stoten', type: EntityType.driver),
      (canonical: 'Michal Babička', input: 'Michal Babicka', type: EntityType.driver),
      (canonical: 'Adam Zelík', input: 'Adam Zelik', type: EntityType.driver),
      (canonical: 'Věroslav Cvrček', input: 'Veroslav Cvrcek', type: EntityType.driver),
      (canonical: 'Piotr Krotoszyński', input: 'Piotr Krotoszynski', type: EntityType.driver),
      (canonical: 'Hervé Emeriau', input: 'Herve Emerio', type: EntityType.driver),
      (canonical: 'José Paula', input: 'Jose Pawla', type: EntityType.driver),
      (canonical: 'Sergio Ramón Arrom', input: 'Sergio Ramon', type: EntityType.driver),
      (canonical: 'Tanja Zingelmann', input: 'Tanya Zingelman', type: EntityType.driver),
      (canonical: 'Tanja Zingelmann', input: 'Tanja Zingelmann', type: EntityType.driver),
      (canonical: 'Nenad Lončarič', input: 'Nenad Loncarich', type: EntityType.driver),
      (canonical: 'Matej Bogović', input: 'Matej Bogovich', type: EntityType.driver),
      (canonical: 'Andrej Medić', input: 'Andrej Medich', type: EntityType.driver),
      (canonical: 'John Shanahan jnr.', input: 'John Shanahan Jr', type: EntityType.driver),
      (canonical: 'Max Freeman', input: 'Max Frieman', type: EntityType.driver),
      (canonical: 'Jan-Erik Mäll', input: 'Jan Erik Mall', type: EntityType.driver),
      (canonical: 'Catharina Schmidt', input: 'Katarina Schmidt', type: EntityType.driver),
      (canonical: 'Paweł Molgo', input: 'Pawel Molgo', type: EntityType.driver),
      (canonical: 'Shea Breen', input: 'Shea Breen', type: EntityType.driver),
      (canonical: 'Jon-Gunnar Støten', input: 'Stoten', type: EntityType.driver),
      (canonical: 'Věroslav Cvrček', input: 'Cvrcek', type: EntityType.driver),
      (canonical: 'Woodstoxx Kemmelberg 1', input: 'Kemmelberg 1', type: EntityType.stage),
      (canonical: 'Duszniki - Zieleniec 2', input: 'Duszniki Zieleniec', type: EntityType.stage),
      (canonical: 'Seixoso 2', input: 'Seiksozo', type: EntityType.stage),
      (canonical: 'Drumhallagh 2', input: 'Drumhalagh', type: EntityType.stage),
      (canonical: 'Dikkebus 1', input: 'Dikebus', type: EntityType.stage),
      (canonical: 'Fafe 2Powerstage', input: 'Fafe Powerstage', type: EntityType.stage),
      (canonical: 'Knockalla 2', input: 'Knokalla', type: EntityType.stage),
      (canonical: 'Dunworley 2', input: 'Dunworly', type: EntityType.stage),
      (canonical: 'Kellymount 1', input: 'Kelley Mount 1', type: EntityType.stage),
    ];

    // 106 Negatives
    final negatives = <_Negative>[
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

    final cases = <Map<String, dynamic>>[];
    var idx = 1;
    for (final p in positives) {
      cases.add({
        'caseId': 'safety_${idx++}',
        'category': 'positive',
        'input': p.input,
        'expectedCanonicalName': p.canonical,
        'entityType': p.type.name,
        'personRole': p.type == EntityType.driver ? 'driver' : null,
      });
    }
    for (final n in negatives) {
      cases.add({
        'caseId': 'safety_${idx++}',
        'category': 'negative_confusable',
        'input': n.input,
        'expectedCanonicalName': null,
        'entityType': n.type.name,
        'personRole': n.type == EntityType.driver ? 'driver' : null,
      });
    }

    expect(cases.length, 168);
    File('test/eval/entity_search/frozen_168_safety_cases.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(cases),
    );
    print('Exported ${cases.length} frozen safety cases.');
  });
}
