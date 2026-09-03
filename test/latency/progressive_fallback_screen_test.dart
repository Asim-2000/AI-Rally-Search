import 'dart:async';
import 'dart:io';

import 'package:ai_rally_search/l10n/generated/app_localizations.dart';
import 'package:ai_rally_search/models/entity_candidate.dart';
import 'package:ai_rally_search/models/search_intent.dart';
import 'package:ai_rally_search/models/search_query.dart';
import 'package:ai_rally_search/models/search_results.dart';
import 'package:ai_rally_search/models/video_action.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/latency/latency_policy.dart';
import 'package:ai_rally_search/services/latency/search_latency_coordinator.dart';
import 'package:ai_rally_search/services/latency/search_telemetry.dart';
import 'package:ai_rally_search/services/llm/entity_resolution/entity_resolver.dart';
import 'package:ai_rally_search/services/llm/llm_provider_config.dart';
import 'package:ai_rally_search/services/llm/llm_query_parser.dart';
import 'package:ai_rally_search/services/llm/natural_language_search_service.dart';
import 'package:ai_rally_search/services/llm/query_parse_result.dart';
import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/search_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'latency_test_fixtures.dart';

/// A parser whose completion the test controls, so the online turn can be made
/// to land on either side of the fallback budget.
class _ControlledParser implements LlmQueryParser {
  final Map<String, Completer<QueryParseResult>> _pending = {};
  int calls = 0;

  @override
  LlmProvider get provider => LlmProvider.mock;

  @override
  Future<QueryParseResult> parse(String userQuery, {SearchContext? context}) {
    calls++;
    return (_pending[userQuery] ??= Completer<QueryParseResult>()).future;
  }

  bool get isWaiting => _pending.values.any((c) => !c.isCompleted);

  /// Resolves the pending call for [text].
  ///
  /// The service normalizes a query before parsing it ("rallies in ireland"
  /// arrives as "rallies in Ireland"), so tests are matched case-insensitively
  /// against what the parser actually received rather than against the raw
  /// text the test typed.
  Completer<QueryParseResult> _pendingFor(String text) {
    final key = _pending.keys.firstWhere(
      (k) => k.toLowerCase() == text.toLowerCase(),
      orElse: () => throw StateError(
        'the parser was never called for "$text"; saw ${_pending.keys.toList()}',
      ),
    );
    return _pending[key]!;
  }

  void completeWith(String text, SearchQuery query) {
    _pendingFor(text).complete(QueryParseResult(query: query));
  }

  void failWith(String text, Object error) {
    _pendingFor(text).completeError(error);
  }

  void clarify(String text, String question) {
    _pendingFor(text).complete(
      QueryParseResult(requiresClarification: true, clarificationQuestion: question),
    );
  }
}

class _PassThroughResolver implements EntityResolver {
  @override
  Future<EntityResolutionResult> resolve(
    SearchQuery query, {
    SearchContext? context,
  }) async =>
      EntityResolutionResult.success(parsedQuery: query, resolvedQuery: query);
}

/// Returns an online-only result that is visibly distinct from anything in the
/// local snapshot, so a swap between the two is unmistakable on screen.
class _OnlineOnlyRepository implements ISearchRepository {
  @override
  Future<SearchResponse<dynamic>> search(SearchQuery query) async {
    return SearchResponse<RallySearchResult>(
      intent: SearchIntent.searchRallies,
      results: const [
        RallySearchResult(
          eventId: 'online-1',
          eventName: 'HQ Authoritative Rally 2026',
          country: 'Ireland',
          city: 'Cork',
          stagesCount: 9,
        ),
      ],
      totalCount: 1,
      hasMore: false,
      limit: query.limit,
      offset: query.offset,
    );
  }

  Future<SearchResponse<T>> _t<T>(SearchQuery q) async =>
      SearchResponse<T>(
        intent: SearchIntent.searchRallies,
        results: (await search(q)).results.cast<T>(),
        totalCount: 1,
        hasMore: false,
        limit: q.limit,
        offset: q.offset,
      );

  @override
  Future<SearchResponse<RallySearchResult>> searchRallies(SearchQuery q) => _t(q);
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverRallies(SearchQuery q) => _t(q);
  @override
  Future<SearchResponse<RallyParticipationResult>> searchDriverWins(SearchQuery q) => _t(q);
  @override
  Future<SearchResponse<RallyResult>> getRallyResults(SearchQuery q) => _t(q);
  @override
  Future<SearchResponse<RallyResult>> getRallyTopFinishers(SearchQuery q) => _t(q);
  @override
  Future<SearchResponse<VideoAction>> searchVideoActions(SearchQuery q) => _t(q);
  @override
  Future<SearchResponse<VideoSearchResult>> searchDriverVideos(SearchQuery q) => _t(q);
  @override
  Future<SearchResponse<UploaderSearchResult>> getTopUploaders(SearchQuery q) => _t(q);
  @override
  Future<SearchResponse<DriverWinResult>> getTopDriversByWins(SearchQuery q) => _t(q);
}

class _Probe implements ConnectivityProbe {
  final bool online;
  const _Probe(this.online);
  @override
  Future<bool> isOnline() async => online;
}

const _budget = Duration(milliseconds: 200);
const _query = 'rallies in ireland';
const _onlineQuery = SearchQuery(
  intent: SearchIntent.searchRallies,
  countries: ['Ireland'],
);

void main() {
  setUpAll(sqfliteFfiInit);

  late _ControlledParser parser;
  late InMemorySearchTelemetrySink telemetry;

  setUp(() {
    parser = _ControlledParser();
    telemetry = InMemorySearchTelemetrySink();
  });

  Future<Widget> app({
    bool online = true,
    bool withSnapshot = true,
    Duration budget = _budget,
    Key? key,
  }) async {
    // The shared in-memory path keeps its contents within an isolate, so the
    // empty-snapshot case needs a file of its own to genuinely have none.
    final OfflineDatabase db;
    if (withSnapshot) {
      db = await OfflineDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
      await db.importSnapshot(irelandSnapshot());
    } else {
      // Synchronous file work: real async I/O never completes inside a widget
      // test's fake-async zone.
      final dir = Directory.systemTemp.createTempSync('rally_no_snapshot');
      addTearDown(() => dir.deleteSync(recursive: true));
      db = await OfflineDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: '${dir.path}/empty.db',
      );
    }
    final engine = await offlineEngine(db);
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GeneralSearchScreen(
        key: key,
        offlineEngine: engine,
        connectivityProbe: _Probe(online),
        telemetrySink: telemetry,
        latencyPolicy: LatencyPolicy(
          onlineResultBudget: budget,
          overallOnlineTimeout: const Duration(seconds: 5),
        ),
        nlSearchService: NaturalLanguageSearchService(
          parser: parser,
          entityResolver: _PassThroughResolver(),
          repository: _OnlineOnlyRepository(),
        ),
      ),
    );
  }

  Future<void> submit(WidgetTester tester, [String text = _query]) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  /// Advances time in slices so timers, futures and rebuilds all settle.
  Future<void> settle(WidgetTester tester,
      {Duration by = const Duration(milliseconds: 60), int times = 6}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(by);
    }
  }

  testWidgets('1. online result inside the budget is shown as the online result',
      (tester) async {
    await tester.pumpWidget(await app());
    await settle(tester, times: 2);
    await submit(tester);

    parser.completeWith(_query, _onlineQuery);
    await settle(tester, by: const Duration(milliseconds: 20), times: 4);

    expect(find.text('HQ Authoritative Rally 2026'), findsOneWidget);
    expect(find.textContaining('Taking the service road'), findsNothing);
    expect(telemetry.records.single.resultSource, SearchResultSource.online);
    expect(telemetry.records.single.fallbackTriggered, isFalse);
  });

  testWidgets('2. online past the budget with a valid local result falls back',
      (tester) async {
    await tester.pumpWidget(await app());
    await settle(tester, times: 2);
    await submit(tester);
    await settle(tester);

    expect(find.textContaining('Taking the service road'), findsOneWidget);
    expect(find.text('Rally Alpha 2025'), findsOneWidget);
    expect(find.text('HQ Authoritative Rally 2026'), findsNothing);

    final record = telemetry.records.single;
    expect(record.resultSource, SearchResultSource.offlineFallback);
    expect(record.fallbackTriggered, isTrue);
    expect(record.fallbackTriggerMs, greaterThanOrEqualTo(_budget.inMilliseconds));
    expect(record.localParserCouldAnswer, isTrue);
    expect(record.requestId, isNotEmpty);

    // The online request is still running: it was never cancelled.
    expect(parser.isWaiting, isTrue);
  });

  testWidgets('3. online just before the budget produces no fallback',
      (tester) async {
    await tester.pumpWidget(await app(budget: const Duration(seconds: 2)));
    await settle(tester, times: 2);
    await submit(tester);
    await tester.pump(const Duration(milliseconds: 900));

    parser.completeWith(_query, _onlineQuery);
    await settle(tester, by: const Duration(milliseconds: 40), times: 4);

    expect(find.text('HQ Authoritative Rally 2026'), findsOneWidget);
    expect(find.textContaining('Taking the service road'), findsNothing);
    expect(find.textContaining('HQ has fresh results'), findsNothing);
  });

  testWidgets(
      '4. online just after the budget keeps local and offers the fresh result',
      (tester) async {
    await tester.pumpWidget(await app());
    await settle(tester, times: 2);
    await submit(tester);
    await settle(tester);

    expect(find.text('Rally Alpha 2025'), findsOneWidget);

    parser.completeWith(_query, _onlineQuery);
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);

    // Offered, not applied: the local result is still the one on screen.
    expect(find.textContaining('HQ has fresh results'), findsOneWidget);
    expect(find.text('Show latest'), findsOneWidget);
    expect(find.text('Rally Alpha 2025'), findsOneWidget);
    expect(find.text('HQ Authoritative Rally 2026'), findsNothing);
  });

  testWidgets('5. tapping "show latest" replaces local with the online result',
      (tester) async {
    await tester.pumpWidget(await app());
    await settle(tester, times: 2);
    await submit(tester);
    await settle(tester);
    parser.completeWith(_query, _onlineQuery);
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);

    await tester.tap(find.text('Show latest'));
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);

    expect(find.text('HQ Authoritative Rally 2026'), findsOneWidget);
    expect(find.text('Rally Alpha 2025'), findsNothing);
    expect(find.textContaining('HQ has fresh results'), findsNothing);
    expect(find.textContaining('Taking the service road'), findsNothing);
  });

  testWidgets('5b. repeated "show latest" taps are idempotent', (tester) async {
    await tester.pumpWidget(await app());
    await settle(tester, times: 2);
    await submit(tester);
    await settle(tester);
    parser.completeWith(_query, _onlineQuery);
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);

    // Two taps in the same frame, before any rebuild can remove the button.
    final button = find.text('Show latest');
    await tester.tap(button, warnIfMissed: false);
    await tester.tap(button, warnIfMissed: false);
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);

    expect(find.text('HQ Authoritative Rally 2026'), findsOneWidget);
    expect(find.textContaining('HQ has fresh results'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('6. online failing after the fallback keeps the local result',
      (tester) async {
    await tester.pumpWidget(await app());
    await settle(tester, times: 2);
    await submit(tester);
    await settle(tester);

    parser.failWith(_query, StateError('backend down'));
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);

    expect(find.text('Rally Alpha 2025'), findsOneWidget);
    expect(find.textContaining("can't reach HQ"), findsOneWidget);
    expect(find.textContaining('HQ has fresh results'), findsNothing);
  });

  testWidgets('7. known offline answers locally without waiting for the budget',
      (tester) async {
    await tester.pumpWidget(await app(online: false));
    await settle(tester, times: 2);
    await submit(tester);
    await settle(tester, by: const Duration(milliseconds: 20), times: 5);

    expect(find.text('Rally Alpha 2025'), findsOneWidget);
    // The online path was never entered.
    expect(parser.calls, 0);
    expect(telemetry.records.single.resultSource, SearchResultSource.offline);
  });

  testWidgets(
      '8. a query the local parser cannot answer produces no local fallback',
      (tester) async {
    await tester.pumpWidget(await app());
    await settle(tester, times: 2);
    await submit(tester, 'rallies in norwhere');
    await settle(tester, times: 8);

    // Past the budget, still waiting for the authoritative answer.
    expect(find.textContaining('Taking the service road'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    parser.completeWith('rallies in norwhere', _onlineQuery);
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);
    expect(find.text('HQ Authoritative Rally 2026'), findsOneWidget);
  });

  testWidgets('9. a clarification from the backend is preserved, not replaced',
      (tester) async {
    await tester.pumpWidget(await app(budget: const Duration(seconds: 2)));
    await settle(tester, times: 2);
    await submit(tester);

    parser.clarify(_query, 'Which rally do you mean?');
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);

    expect(find.text('Which rally do you mean?'), findsOneWidget);
    expect(find.text('Rally Alpha 2025'), findsNothing);
  });

  testWidgets('11. a missing local snapshot degrades to the sync prompt',
      (tester) async {
    // Opening a file-backed database is real I/O, so it runs outside the
    // test's fake-async zone.
    final widget = (await tester.runAsync(
      () => app(online: false, withSnapshot: false),
    ))!;
    await tester.pumpWidget(widget);
    await settle(tester, times: 2);
    await submit(tester);
    await settle(tester);

    expect(find.textContaining("haven't packed the service notes"), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('12. leaving the screen mid-request causes no post-dispose update',
      (tester) async {
    await tester.pumpWidget(await app());
    await settle(tester, times: 2);
    await submit(tester);
    await settle(tester);

    // Tear the screen down while the online request is still in flight.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    parser.completeWith(_query, _onlineQuery);
    await settle(tester, by: const Duration(milliseconds: 60), times: 8);

    expect(tester.takeException(), isNull);
  });

  testWidgets('13. a late result for query A cannot overwrite query B',
      (tester) async {
    await tester.pumpWidget(await app(budget: const Duration(seconds: 3)));
    await settle(tester, times: 2);

    await submit(tester, 'rallies in ireland');
    await tester.pump(const Duration(milliseconds: 50));
    await submit(tester, 'rallies in portugal');
    await tester.pump(const Duration(milliseconds: 50));

    // B answers first.
    parser.completeWith(
      'rallies in portugal',
      const SearchQuery(intent: SearchIntent.searchRallies, countries: ['Portugal']),
    );
    await settle(tester, by: const Duration(milliseconds: 40), times: 5);
    expect(find.text('HQ Authoritative Rally 2026'), findsOneWidget);
    final afterB = tester.widget<TextField>(find.byType(TextField).first);
    expect(afterB.controller!.text, 'rallies in portugal');

    // A answers late; it belongs to a superseded generation and is dropped.
    parser.completeWith('rallies in ireland', _onlineQuery);
    await settle(tester, by: const Duration(milliseconds: 40), times: 6);

    expect(find.textContaining('HQ has fresh results'), findsNothing);
    expect(find.textContaining('Taking the service road'), findsNothing);
    final afterA = tester.widget<TextField>(find.byType(TextField).first);
    expect(afterA.controller!.text, 'rallies in portugal');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '14. local and online landing together resolves deterministically to online',
      (tester) async {
    for (var i = 0; i < 5; i++) {
      parser = _ControlledParser();
      telemetry = InMemorySearchTelemetrySink();
      // A distinct key per iteration forces a fresh State, so the screen picks
      // up this iteration's parser instead of reusing the first one.
      await tester.pumpWidget(
        await app(budget: const Duration(seconds: 1), key: ValueKey(i)),
      );
      await settle(tester, times: 2);
      await submit(tester);
      // Complete online in the same turn the local search resolves in.
      parser.completeWith(_query, _onlineQuery);
      await settle(tester, by: const Duration(milliseconds: 30), times: 6);

      expect(find.text('HQ Authoritative Rally 2026'), findsOneWidget,
          reason: 'iteration $i');
      expect(find.textContaining('Taking the service road'), findsNothing,
          reason: 'iteration $i');
    }
  });
}
