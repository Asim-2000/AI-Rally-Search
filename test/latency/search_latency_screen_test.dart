import 'dart:convert';
import 'dart:io';

import 'package:ai_rally_search/l10n/generated/app_localizations.dart';
import 'package:ai_rally_search/screens/general_search_screen.dart';
import 'package:ai_rally_search/services/latency/latency_policy.dart';
import 'package:ai_rally_search/services/latency/search_latency_coordinator.dart';
import 'package:ai_rally_search/services/latency/search_telemetry.dart';
import 'package:ai_rally_search/services/offline/offline_database.dart';
import 'package:ai_rally_search/services/offline/offline_search_engine.dart';
import 'package:ai_rally_search/services/python_search_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The screen-level contract for the 4-second progressive fallback.
///
/// These drive the real widget through a real [PythonSearchApiClient] backed by
/// a scripted transport, so the trace-id header, the decode path and the
/// coordinator all take part rather than being stubbed out.

class _Probe implements ConnectivityProbe {
  bool online;
  _Probe(this.online);
  @override
  Future<bool> isOnline() async => online;
}

Map<String, dynamic> _snapshot() => {
      'schema_version': 1,
      'data_version': 'v1',
      'snapshot_id': '1-v1-core',
      'segment': 'core',
      'generated_at': '2026-08-30T00:00:00Z',
      'rallies': <Map<String, Object?>>[
        {
          'event_id': 'ev1',
          'event_name': 'Rally Alpha 2025',
          'country': 'Ireland',
          'city': 'Cork',
          'year': 2025,
          'start_date': '2025-05-01',
          'end_date': null,
          'status': null,
          'stages_count': 3,
        },
      ],
      'people': const [],
      'stages': const [],
      'participation': const [],
      'final_results': const [],
      'driver_wins': const [],
      'uploader_stats': const [],
      'video_meta': const [],
      'video_actions': const [],
    };

/// A backend conversation response naming one rally, so an online render is
/// visually distinguishable from the local one.
String _onlineBody(String rallyName, {int requestId = 1}) => jsonEncode({
      'requestId': requestId,
      'traceId': 'server-echo',
      'session': {
        'activeQuery': {'intent': 'SEARCH_RALLIES'},
        'referents': <String, Object?>{},
        'history': const [],
        'inheritedFields': const [],
        'currentRefinementFields': const [],
        'activeRequestId': requestId,
      },
      'result': {
        'parsedQuery': {'intent': 'SEARCH_RALLIES'},
        'resolvedQuery': {'intent': 'SEARCH_RALLIES'},
        'requiresClarification': false,
        'searchResponse': {
          'intent': 'SEARCH_RALLIES',
          'results': [
            {'kind': 'rally', 'event_id': 'online-1', 'event_name': rallyName},
          ],
          'total_count': 1,
          'has_more': false,
          'limit': 20,
          'offset': 0,
        },
      },
    });

String _clarificationBody({int requestId = 1}) => jsonEncode({
      'requestId': requestId,
      'traceId': 'server-echo',
      'session': {
        'activeQuery': {'intent': 'SEARCH_RALLIES'},
        'referents': <String, Object?>{},
        'history': const [],
        'inheritedFields': const [],
        'currentRefinementFields': const [],
        'activeRequestId': requestId,
      },
      'result': {
        'parsedQuery': {'intent': 'SEARCH_RALLIES'},
        'requiresClarification': true,
        'clarificationQuestion': 'Which Donegal rally did you mean?',
        'candidates': const [],
      },
    });

/// A transport whose responses are scripted per call: each entry gives a delay
/// and either a body or an error.
class _ScriptedTransport {
  final List<Duration> delays;
  final List<String?> bodies;
  final List<Object?> errors;
  final List<String?> seenTraceIds = [];
  int calls = 0;

  _ScriptedTransport({
    required this.delays,
    required this.bodies,
    List<Object?>? errors,
  }) : errors = errors ?? List<Object?>.filled(bodies.length, null);

  http.Client get client => MockClient((request) async {
        final index = calls++;
        seenTraceIds.add(request.headers[PythonSearchApiClient.requestIdHeader]);
        await Future<void>.delayed(delays[index]);
        final error = errors[index];
        if (error != null) throw error;
        return http.Response(
          bodies[index]!,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
}

Future<OfflineSearchEngine> _localEngine() async {
  final db = await OfflineDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
  await db.importSnapshot(_snapshot());
  return OfflineSearchEngine.create(db);
}

Future<OfflineSearchEngine> _emptyEngine() async {
  // `inMemoryDatabasePath` is shared within an isolate, so a genuinely empty
  // store needs its own file.
  // Created and cleaned up synchronously: real async file I/O inside a widget
  // test's fake-async zone never completes.
  final dir = Directory.systemTemp.createTempSync('rally_latency_empty');
  addTearDown(() => dir.deleteSync(recursive: true));
  final db = await OfflineDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: '${dir.path}/empty.db',
  );
  return OfflineSearchEngine.create(db);
}

const _policy = LatencyPolicy(
  onlineResultBudget: Duration(milliseconds: 4000),
  overallOnlineTimeout: Duration(seconds: 20),
);

Widget _app({
  required OfflineSearchEngine engine,
  required http.Client transport,
  bool online = true,
  SearchTelemetrySink? sink,
  LatencyPolicy policy = _policy,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: GeneralSearchScreen(
      offlineEngine: engine,
      connectivityProbe: _Probe(online),
      latencyPolicy: policy,
      telemetrySink: sink,
      pythonApiClient: PythonSearchApiClient(
        baseUrl: Uri.parse('https://backend.test/'),
        httpClient: transport,
        policy: policy,
      ),
    ),
  );
}

Future<void> _submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).first, query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

/// Advances the fake clock in small steps so pending timers and the sqflite
/// microtask work both get a chance to run.
Future<void> _settle(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('online answering inside the budget renders the online result',
      (tester) async {
    final sink = InMemorySearchTelemetrySink();
    final transport = _ScriptedTransport(
      delays: [const Duration(milliseconds: 500)],
      bodies: [_onlineBody('HQ Rally')],
    );
    await tester.pumpWidget(await _localEngine().then(
        (e) => _app(engine: e, transport: transport.client, sink: sink)));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(seconds: 2));

    expect(find.text('HQ Rally'), findsOneWidget);
    expect(find.byKey(const Key('freshResultsBanner')), findsNothing);
    expect(sink.records.single.resultSource, SearchResultSource.online);
    expect(sink.records.single.fallbackTriggered, isFalse);
  });

  testWidgets('online completing just before 4s does not trigger a fallback',
      (tester) async {
    final sink = InMemorySearchTelemetrySink();
    final transport = _ScriptedTransport(
      delays: [const Duration(milliseconds: 3800)],
      bodies: [_onlineBody('HQ Rally')],
    );
    await tester.pumpWidget(await _localEngine().then(
        (e) => _app(engine: e, transport: transport.client, sink: sink)));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(milliseconds: 3500));
    expect(find.text('HQ Rally'), findsNothing, reason: 'still in flight');

    await _settle(tester, const Duration(seconds: 1));
    expect(find.text('HQ Rally'), findsOneWidget);
    expect(sink.records.single.fallbackTriggered, isFalse);
    expect(sink.records.single.resultSource, SearchResultSource.online);
  });

  testWidgets(
      'online exceeding 4s shows saved data, then offers the late result',
      (tester) async {
    final sink = InMemorySearchTelemetrySink();
    final transport = _ScriptedTransport(
      delays: [const Duration(seconds: 8)],
      bodies: [_onlineBody('HQ Rally')],
    );
    await tester.pumpWidget(await _localEngine().then(
        (e) => _app(engine: e, transport: transport.client, sink: sink)));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(milliseconds: 4600));

    // The local answer is on screen and labelled as saved data.
    expect(find.text('Rally Alpha 2025'), findsOneWidget);
    expect(find.text('Taking the service road'), findsOneWidget);
    expect(sink.records.single.resultSource, SearchResultSource.offlineFallback);
    expect(sink.records.single.fallbackTriggered, isTrue);
    expect(sink.records.single.fallbackTriggerMs, greaterThanOrEqualTo(4000));

    // The authoritative result lands later and is offered, never applied.
    await _settle(tester, const Duration(seconds: 5));
    expect(find.byKey(const Key('freshResultsBanner')), findsOneWidget);
    expect(find.text('HQ has fresh results'), findsOneWidget);
    expect(find.text('Rally Alpha 2025'), findsOneWidget,
        reason: 'saved data must not be swapped out on its own');
    expect(find.text('HQ Rally'), findsNothing);
  });

  testWidgets('tapping "Show latest" promotes the authoritative result',
      (tester) async {
    final transport = _ScriptedTransport(
      delays: [const Duration(seconds: 8)],
      bodies: [_onlineBody('HQ Rally')],
    );
    await tester.pumpWidget(await _localEngine()
        .then((e) => _app(engine: e, transport: transport.client)));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(seconds: 10));
    expect(find.text('Show latest'), findsOneWidget);

    await tester.tap(find.text('Show latest'));
    await _settle(tester, const Duration(milliseconds: 600));

    expect(find.text('HQ Rally'), findsOneWidget);
    expect(find.text('Rally Alpha 2025'), findsNothing);
    expect(find.byKey(const Key('freshResultsBanner')), findsNothing);
  });

  testWidgets('repeated "Show latest" taps are idempotent', (tester) async {
    final transport = _ScriptedTransport(
      delays: [const Duration(seconds: 8)],
      bodies: [_onlineBody('HQ Rally')],
    );
    await tester.pumpWidget(await _localEngine()
        .then((e) => _app(engine: e, transport: transport.client)));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(seconds: 10));

    // Two taps in the same frame: the second finds nothing pending.
    await tester.tap(find.text('Show latest'), warnIfMissed: false);
    await tester.tap(find.text('Show latest'), warnIfMissed: false);
    await _settle(tester, const Duration(milliseconds: 600));

    expect(find.text('HQ Rally'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('online failing after a fallback leaves the saved data in place',
      (tester) async {
    final transport = _ScriptedTransport(
      delays: [const Duration(seconds: 8)],
      bodies: [null],
      errors: [http.ClientException('connection reset')],
    );
    await tester.pumpWidget(await _localEngine()
        .then((e) => _app(engine: e, transport: transport.client)));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(seconds: 10));

    expect(find.text('Rally Alpha 2025'), findsOneWidget);
    expect(find.byKey(const Key('freshResultsBanner')), findsNothing);
    expect(find.text("The pit crew can't reach HQ right now"), findsOneWidget);
  });

  testWidgets('a query the local parser cannot answer waits for the backend',
      (tester) async {
    final sink = InMemorySearchTelemetrySink();
    final transport = _ScriptedTransport(
      delays: [const Duration(seconds: 6)],
      bodies: [_onlineBody('HQ Rally')],
    );
    await tester.pumpWidget(await _localEngine().then(
        (e) => _app(engine: e, transport: transport.client, sink: sink)));
    await tester.pump();

    await _submit(tester, 'rallies in nowhereatall');
    await _settle(tester, const Duration(milliseconds: 5000));
    // Past the budget, but nothing local was fabricated.
    expect(find.text('Taking the service road'), findsNothing);
    expect(sink.records, isEmpty);

    await _settle(tester, const Duration(seconds: 2));
    expect(find.text('HQ Rally'), findsOneWidget);
    expect(sink.records.single.resultSource, SearchResultSource.online);
    expect(sink.records.single.localParserCouldAnswer, isFalse);
  });

  testWidgets('a slow clarification is still delivered as a clarification',
      (tester) async {
    final transport = _ScriptedTransport(
      delays: [const Duration(seconds: 6)],
      bodies: [_clarificationBody()],
    );
    // A query with no safe local answer, so the clarification is not pre-empted
    // by a fallback.
    await tester.pumpWidget(await _localEngine()
        .then((e) => _app(engine: e, transport: transport.client)));
    await tester.pump();

    await _submit(tester, 'rallies in nowhereatall');
    await _settle(tester, const Duration(seconds: 8));

    expect(find.text('Which Donegal rally did you mean?'), findsOneWidget);
  });

  testWidgets('a late response to query A cannot overwrite query B',
      (tester) async {
    final transport = _ScriptedTransport(
      delays: [const Duration(seconds: 6), const Duration(milliseconds: 300)],
      bodies: [
        _onlineBody('STALE Rally A', requestId: 1),
        _onlineBody('FRESH Rally B', requestId: 2),
      ],
    );
    await tester.pumpWidget(await _localEngine()
        .then((e) => _app(engine: e, transport: transport.client)));
    await tester.pump();

    await _submit(tester, 'rallies in nowhereatall');
    await tester.pump(const Duration(milliseconds: 200));
    await _submit(tester, 'rallies in stillnowhere');
    await _settle(tester, const Duration(seconds: 10));

    expect(transport.calls, 2);
    expect(find.text('FRESH Rally B'), findsOneWidget);
    expect(find.text('STALE Rally A'), findsNothing);
    expect(find.byKey(const Key('freshResultsBanner')), findsNothing);
  });

  testWidgets('leaving the screen mid-request does not update a disposed state',
      (tester) async {
    final transport = _ScriptedTransport(
      delays: [const Duration(seconds: 6)],
      bodies: [_onlineBody('HQ Rally')],
    );
    await tester.pumpWidget(await _localEngine()
        .then((e) => _app(engine: e, transport: transport.client)));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await tester.pump(const Duration(milliseconds: 200));

    // Replace the screen while the request is still in flight.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await _settle(tester, const Duration(seconds: 10));

    expect(tester.takeException(), isNull);
  });

  testWidgets('known offline answers from the snapshot without any request',
      (tester) async {
    final transport = _ScriptedTransport(
      delays: [Duration.zero],
      bodies: [_onlineBody('HQ Rally')],
    );
    final sink = InMemorySearchTelemetrySink();
    await tester.pumpWidget(await _localEngine().then((e) => _app(
          engine: e,
          transport: transport.client,
          online: false,
          sink: sink,
        )));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(seconds: 1));

    expect(transport.calls, 0);
    expect(find.text('Rally Alpha 2025'), findsOneWidget);
    expect(sink.records.single.resultSource, SearchResultSource.offline);
    expect(sink.records.single.connectivity, ConnectivityState.offline);
  });

  testWidgets('offline with no snapshot offers a sync instead of a result',
      (tester) async {
    final transport = _ScriptedTransport(
      delays: [Duration.zero],
      bodies: [_onlineBody('HQ Rally')],
    );
    // Opening a file-backed database is real I/O, which never completes inside
    // the test's fake-async zone — so it runs outside it.
    final engine = (await tester.runAsync(_emptyEngine))!;
    await tester.pumpWidget(_app(
      engine: engine,
      transport: transport.client,
      online: false,
    ));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(seconds: 1));

    expect(find.text("We haven't packed the service notes yet"), findsOneWidget);
    expect(transport.calls, 0);
  });

  testWidgets('the correlation id reaches the backend as X-Request-Id',
      (tester) async {
    final sink = InMemorySearchTelemetrySink();
    final transport = _ScriptedTransport(
      delays: [const Duration(milliseconds: 300)],
      bodies: [_onlineBody('HQ Rally')],
    );
    await tester.pumpWidget(await _localEngine().then(
        (e) => _app(engine: e, transport: transport.client, sink: sink)));
    await tester.pump();

    await _submit(tester, 'rallies in ireland in 2025');
    await _settle(tester, const Duration(seconds: 2));

    final sent = transport.seenTraceIds.single;
    expect(sent, isNotNull);
    expect(sent, matches(RegExp(r'^[0-9a-f]{32}$')));
    // The same id is what the client-side latency record is keyed by, so a
    // client record and a backend timing line join without either logging the
    // query text.
    expect(sink.records.single.requestId, sent);
  });
}
