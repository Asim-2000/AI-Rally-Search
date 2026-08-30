import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/widgets/clarification_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('uses a contextual title derived from candidate type', (
    tester,
  ) async {
    await tester.pumpWidget(host(ClarificationCard(
      question: 'Which person do you mean?',
      candidates: const [
        EntityCandidate(
          id: 'p1',
          type: EntityType.driver,
          canonicalName: 'Carlos Martins',
        ),
        EntityCandidate(
          id: 'p2',
          type: EntityType.driver,
          canonicalName: 'Craig Martin',
        ),
      ],
      onCandidateSelected: (_) {},
    )));

    expect(find.text('Which driver did you mean?'), findsOneWidget);
    // Generic wording is gone.
    expect(find.text('Clarification Needed'), findsNothing);
  });

  testWidgets('shows the discriminator subtitle on its own line', (
    tester,
  ) async {
    await tester.pumpWidget(host(ClarificationCard(
      question: 'Which rally do you mean?',
      candidates: const [
        EntityCandidate(
          id: 'r1',
          type: EntityType.rally,
          canonicalName: 'Donegal International Rally',
          subtitle: '2026 · Ireland',
        ),
      ],
      onCandidateSelected: (_) {},
    )));

    expect(find.text('Which rally did you mean?'), findsOneWidget);
    expect(find.text('Donegal International Rally'), findsOneWidget);
    // Discriminator is a separate line, not parenthesised into the name.
    expect(find.text('2026 · Ireland'), findsOneWidget);
    expect(
      find.text('Donegal International Rally (2026 · Ireland)'),
      findsNothing,
    );
  });

  testWidgets('tapping a candidate row invokes the selection callback', (
    tester,
  ) async {
    EntityCandidate? selected;
    await tester.pumpWidget(host(ClarificationCard(
      question: 'Which driver do you mean?',
      candidates: const [
        EntityCandidate(
          id: 'p1',
          type: EntityType.driver,
          canonicalName: 'Carlos Martins',
        ),
      ],
      onCandidateSelected: (c) => selected = c,
    )));

    await tester.tap(find.text('Carlos Martins'));
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.id, 'p1');
  });
}
