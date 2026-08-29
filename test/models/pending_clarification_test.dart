import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/pending_clarification.dart';
import 'package:ai_rally_search/models/result_referent_context.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';

void main() {
  const person = EntityCandidate(
    id: 'person-carlos-martins',
    type: EntityType.driver,
    canonicalName: 'Carlos Martins',
  );

  test('person selection preserves rally and video action filters', () {
    const pending = PendingClarification(
      query: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: ['jump'],
        rallyNames: ['Rally Ireland'],
        driverNames: ['karl martin'],
        years: [2025],
        countries: ['Ireland'],
      ),
      referents: ResultReferentContext.empty,
      requestId: 4,
    );

    final selected = pending.select(person, currentRequestId: 4)!;

    expect(selected.query.intent, SearchIntent.searchVideoActions);
    expect(selected.query.actionTypes, ['jump']);
    expect(selected.query.rallyNames, ['Rally Ireland']);
    expect(selected.query.years, [2025]);
    expect(selected.query.countries, ['Ireland']);
    expect(selected.query.driverNames, ['Carlos Martins']);
    expect(selected.query.driverIds, ['person-carlos-martins']);
  });

  test('rally selection preserves person and action filters', () {
    const pending = PendingClarification(
      query: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: ['jump'],
        rallyNames: ['donegl'],
        driverNames: ['Carlos Martins'],
        driverIds: ['person-carlos-martins'],
      ),
      referents: ResultReferentContext.empty,
      requestId: 2,
    );
    const rally = EntityCandidate(
      id: 'event-donegal-2025',
      type: EntityType.rally,
      canonicalName: 'Donegal International Rally 2025',
      metadata: {'year': 2025},
    );

    final selected = pending.select(rally, currentRequestId: 2)!.query;

    expect(selected.intent, SearchIntent.searchVideoActions);
    expect(selected.actionTypes, ['jump']);
    expect(selected.driverIds, ['person-carlos-martins']);
    expect(selected.rallyNames, ['Donegal International Rally 2025']);
  });

  test('stage selection preserves rally context', () {
    const pending = PendingClarification(
      query: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        rallyNames: ['Rally Ireland'],
        stageNames: ['forest stage'],
      ),
      referents: ResultReferentContext(activeRally: 'Rally Ireland'),
      requestId: 7,
    );
    const stage = EntityCandidate(
      id: 'stage-3',
      type: EntityType.stage,
      canonicalName: 'SS3',
      metadata: {'stageNumber': '3'},
    );

    final selected = pending.select(stage, currentRequestId: 7)!;

    expect(selected.query.rallyNames, ['Rally Ireland']);
    expect(selected.query.stageNames, ['SS3']);
    expect(selected.referents.activeRally, 'Rally Ireland');
    expect(selected.referents.activeStageNumber, '3');
  });

  test('selection preserves inherited conversation referents', () {
    const pending = PendingClarification(
      query: SearchQuery(
        intent: SearchIntent.searchVideoActions,
        actionTypes: ['jump'],
        rallyNames: ['Inherited Rally'],
      ),
      referents: ResultReferentContext(
        activeRally: 'Inherited Rally',
        activeRallyId: 'event-inherited',
        lastWinner: 'Previous Winner',
      ),
      requestId: 9,
    );

    final selected = pending.select(person, currentRequestId: 9)!;

    expect(selected.referents.activeRallyId, 'event-inherited');
    expect(selected.referents.lastWinner, 'Previous Winner');
    expect(selected.query.rallyNames, ['Inherited Rally']);
  });

  test('stale selection cannot overwrite a newer generation', () {
    const pending = PendingClarification(
      query: SearchQuery(intent: SearchIntent.searchVideoActions),
      referents: ResultReferentContext.empty,
      requestId: 3,
    );

    expect(pending.select(person, currentRequestId: 4), isNull);
  });
}
