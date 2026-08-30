import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_rally_search/l10n/generated/app_localizations.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/python_search_api_client.dart';
import 'package:ai_rally_search/services/search_repository.dart';

/// Counts repository (DB) calls so tests can assert special queries never hit
/// the database. Returns a rally result for any deterministic search.
class CountingRepo implements ISearchRepository {
  int searchCallCount = 0;

  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    searchCallCount++;
    return SearchResponse<RallySearchResult>(
      intent: SearchIntent.searchRallies,
      results: [
        RallySearchResult(
          eventId: 'e-1',
          eventName: 'Rally Ireland 2026',
          country: 'Ireland',
          stagesCount: 10,
          startDate: DateTime(2026, 6, 1),
        ),
      ],
      totalCount: 1,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Special-query categories and their intended (recovered) copy.
const Map<String, String> kSpecialCopy = {
  'weather':
      "Hopefully sideways — that makes rallying more interesting. I'm better with stages than forecasts though.",
  'greeting': 'Hello! Ready to find a rally, driver, stage, result or video?',
  'thanks': 'Any time, navigator. See you at the next stage.',
  'identity':
      "I'm AI Rally Search — your navigator for rallies, drivers, stages, results and videos.",
  'capabilities':
      'I can find rallies, drivers, stages, results and rally videos. Try asking for a winner, event or year.',
  'joke': 'Why did the rally driver bring a pencil? To draw the perfect racing line.',
  'alive':
      "Not alive, but the search engine is running. Give me a rally query and we'll hit the stage.",
  'rallyOpinion':
      "That's how arguments start in a service park. I can show you wins and results and let you decide.",
};

/// Mock backend that returns a special response for phrases mapped in
/// [specialByQuery], echoing the incoming session (Python preserves context on
/// special turns), and a normal rally result otherwise.
PythonSearchApiClient mockClient(Map<String, String> specialByQuery) {
  return PythonSearchApiClient(
    baseUrl: Uri.parse('https://api.test'),
    httpClient: MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final rid = body['requestId'] as int? ?? 1;
      final incomingSession = body['session'] as Map<String, dynamic>?;
      final query = (body['query'] as String? ?? '').trim().toLowerCase();
      final category = specialByQuery[query];

      final session = incomingSession ??
          {
            'activeQuery': const SearchQuery(intent: SearchIntent.searchRallies)
                .toJson(),
            'referents': {},
            'history': [],
            'inheritedFields': [],
            'currentRefinementFields': [],
            'activeRequestId': rid,
          };

      final Map<String, dynamic> result;
      if (category != null) {
        result = {
          'specialResponseCategory': category,
          'friendlyMessage': kSpecialCopy[category],
          'referents': {},
        };
      } else {
        result = {
          'parsedQuery': const SearchQuery(
            intent: SearchIntent.searchRallies,
            countries: ['France'],
          ).toJson(),
          'searchResponse': {
            'intent': 'SEARCH_RALLIES',
            'results': [
              {
                'event_id': 'e-2',
                'event_name': 'Rally France 2026',
                'country': 'France',
                'stages_count': 8,
              }
            ],
            'totalCount': 1,
          },
          'referents': {},
        };
      }

      // Encode as UTF-8 bytes so em-dashes/accents round-trip (http.Response's
      // String constructor defaults to latin1). The real backend sends UTF-8.
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({'requestId': rid, 'session': session, 'result': result}),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

Widget _app(GeneralSearchScreen screen) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    );

Future<void> _submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byKey(const Key('submit_search_button')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => dotenv.loadFromString(envString: 'X=1'));

  for (final entry in kSpecialCopy.entries) {
    final category = entry.key;
    final copy = entry.value;
    testWidgets('$category special query shows its response, no DB, no zero-results', (tester) async {
      final repo = CountingRepo();
      await tester.pumpWidget(_app(GeneralSearchScreen(
        repository: repo,
        pythonApiClient: mockClient({'q': category}),
      )));
      await tester.pumpAndSettle();

      await _submit(tester, 'q');

      // Intended playful copy is shown, in the lightweight special card.
      expect(find.text(copy), findsOneWidget);
      expect(find.byKey(const Key('special_response_card')), findsOneWidget);
      // Not treated as a normal/failed search.
      expect(repo.searchCallCount, 0); // never hits the database
      expect(find.textContaining('No rallies found'), findsNothing);
      expect(find.text("We couldn't turn that into a search"), findsNothing);
      expect(find.text('Search is temporarily unavailable'), findsNothing);
      // No interpretation summary / result count for an easter egg.
      expect(find.textContaining('Found '), findsNothing);
    });
  }

  testWidgets('special query preserves the active rally conversation context', (tester) async {
    final repo = CountingRepo();
    await tester.pumpWidget(_app(GeneralSearchScreen(
      repository: repo,
      pythonApiClient: mockClient({'weather': 'weather'}),
      initialQuery: const SearchQuery(
        intent: SearchIntent.searchRallies,
        countries: ['Ireland'],
      ),
    )));
    await tester.pumpAndSettle();
    expect(repo.searchCallCount, 1); // the initial rally search

    await _submit(tester, 'weather');

    // Easter egg shown, and the rally context chip is still present.
    expect(find.textContaining('Hopefully sideways'), findsOneWidget);
    expect(find.text('Ireland'), findsWidgets);
    // The weather turn did not run another DB search.
    expect(repo.searchCallCount, 1);
  });

  testWidgets('special response is cleared when the next normal search runs', (tester) async {
    final repo = CountingRepo();
    await tester.pumpWidget(_app(GeneralSearchScreen(
      repository: repo,
      pythonApiClient: mockClient({'weather': 'weather'}),
    )));
    await tester.pumpAndSettle();

    await _submit(tester, 'weather');
    expect(find.byKey(const Key('special_response_card')), findsOneWidget);

    // A subsequent normal query returns results and clears the easter egg.
    await _submit(tester, 'rallies in france');
    expect(find.byKey(const Key('special_response_card')), findsNothing);
    expect(find.text('Rally France 2026'), findsOneWidget);
  });
}
