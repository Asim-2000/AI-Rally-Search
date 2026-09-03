import 'dart:async';

import 'package:clock/clock.dart';

import '../offline/offline_search_engine.dart';
import 'latency_policy.dart';
import 'search_telemetry.dart';

/// Reachability signal. Abstracted so the policy is testable without a device.
abstract class ConnectivityProbe {
  Future<bool> isOnline();
}

/// What the coordinator concluded at one point in a search's life.
///
/// A single search can produce more than one event: a fallback followed later
/// by an offer of the authoritative result. Each event is tagged with the
/// generation it belongs to so a late event from an abandoned search can be
/// discarded by the listener rather than applied.
enum SearchStage {
  /// Authoritative online result, within budget. Apply it.
  online,

  /// Device known-offline, answered from the local snapshot. Apply it.
  offlineImmediate,

  /// Budget elapsed with a valid local result available. Apply it and label it
  /// as saved data. The online request is still running.
  offlineFallback,

  /// Online failed and a valid local result exists. Apply it and label it.
  offlineAfterOnlineFailure,

  /// A late authoritative result arrived after a fallback was shown.
  /// DO NOT apply it — offer it. Only a deliberate user action promotes it.
  lateOnlineAvailable,

  /// Online failed after a fallback was already shown. Keep the local result
  /// on screen; only the labelling changes.
  lateOnlineFailed,

  /// Online failed and no safe local answer exists. Surface the error.
  onlineFailed,
}

/// One emission from [SearchLatencyCoordinator.run].
class SearchEvent<O> {
  final int generation;
  final SearchStage stage;

  /// Present for [SearchStage.online] and [SearchStage.lateOnlineAvailable].
  final O? online;

  /// Present for the three offline stages.
  final OfflineSearchOutcome? offline;

  /// Present for the failure stages.
  final Object? error;

  /// Elapsed ms from dispatch to this event.
  final int elapsedMs;

  /// Connectivity as observed at dispatch. Reported here so a caller never
  /// needs a probe of its own: two probes per search meant two serialized
  /// awaits before the online request could even start.
  final ConnectivityState connectivity;

  const SearchEvent({
    required this.generation,
    required this.stage,
    required this.elapsedMs,
    this.connectivity = ConnectivityState.unknown,
    this.online,
    this.offline,
    this.error,
  });

  /// Whether this event replaces what is on screen. `lateOnlineAvailable` is
  /// deliberately excluded: a late authoritative result is offered, never
  /// swapped in behind the user's back.
  bool get isTerminalRender =>
      stage == SearchStage.online ||
      stage == SearchStage.offlineImmediate ||
      stage == SearchStage.offlineFallback ||
      stage == SearchStage.offlineAfterOnlineFailure ||
      stage == SearchStage.onlineFailed;

  SearchResultSource get source => switch (stage) {
        SearchStage.online => SearchResultSource.online,
        SearchStage.offlineImmediate => SearchResultSource.offline,
        SearchStage.offlineFallback ||
        SearchStage.offlineAfterOnlineFailure =>
          SearchResultSource.offlineFallback,
        _ => SearchResultSource.online,
      };
}

/// Progressive online-first search with a bounded local fallback.
///
/// The shape, in one place:
///
/// * Known offline           -> local immediately, no online attempt.
/// * Online / unknown        -> start online now; in parallel prepare the local
///                              answer when the query is safely answerable
///                              locally; give online [LatencyPolicy.onlineResultBudget].
/// * Online wins the budget  -> show online.
/// * Budget elapses + local  -> show local, labelled; the online request keeps
///                              running and its late result is *offered*.
/// * Budget elapses, no safe local answer -> keep waiting to the overall
///                              timeout. Never fabricate a local result.
///
/// Online stays authoritative throughout: it is never cancelled by a fallback,
/// and a local result is never silently replaced.
class SearchLatencyCoordinator<O> {
  final ConnectivityProbe? connectivity;
  final OfflineSearchEngine? engine;
  final LatencyPolicy policy;

  const SearchLatencyCoordinator({
    required this.connectivity,
    required this.engine,
    this.policy = LatencyPolicy.standard,
  });

  /// A local outcome is only allowed to stand in for an authoritative answer
  /// when it is unambiguous.
  ///
  /// A local *clarification* is deliberately not accepted here: showing local
  /// disambiguation chips while the authoritative pipeline may be about to
  /// answer confidently is exactly the wrong-confidence trade the safety
  /// ordering forbids. When the device is plainly offline there is no
  /// authoritative alternative, so clarification is accepted there instead —
  /// see [_offlineAnswerable].
  static bool _fallbackAnswerable(OfflineSearchOutcome outcome) {
    switch (outcome.kind) {
      case OfflineOutcomeKind.results:
        return (outcome.response?.totalCount ?? 0) > 0;
      case OfflineOutcomeKind.special:
        return true;
      case OfflineOutcomeKind.clarification:
      case OfflineOutcomeKind.noMatch:
      case OfflineOutcomeKind.unsupported:
        return false;
    }
  }

  /// Whether a plainly-offline device has anything to show. Broader than
  /// [_fallbackAnswerable]: with no online path available, an honest
  /// clarification or safe no-match is the correct answer.
  static bool _offlineAnswerable(OfflineSearchOutcome outcome) =>
      outcome.kind != OfflineOutcomeKind.unsupported;

  /// Runs one search. [generation] identifies this dispatch; every event
  /// carries it back so the caller can drop results from superseded searches.
  ///
  /// The returned stream closes once no further events are possible. Cancelling
  /// the subscription stops delivery; it does not cancel the online request,
  /// which is allowed to complete (and be ignored) rather than leaving the
  /// backend with a half-abandoned call.
  Stream<SearchEvent<O>> run({
    required int generation,
    required String rawText,
    required Future<O> Function() online,
    int limit = 20,
    int offset = 0,
  }) {
    final controller = StreamController<SearchEvent<O>>();
    final startedAt = clock.now();
    // Completes when the listener detaches (the screen was disposed, or a newer
    // query superseded this one). Everything the coordinator still has running
    // stops at the next await, so no timer outlives the caller.
    final cancelled = Completer<void>();
    var closed = false;
    var observed = ConnectivityState.unknown;

    void emit(
      SearchStage stage, {
      O? online,
      OfflineSearchOutcome? offline,
      Object? error,
    }) {
      if (closed || controller.isClosed) return;
      controller.add(SearchEvent<O>(
        generation: generation,
        stage: stage,
        elapsedMs: clock.now().difference(startedAt).inMilliseconds,
        connectivity: observed,
        online: online,
        offline: offline,
        error: error,
      ));
    }

    void finish() {
      if (closed) return;
      closed = true;
      // Closing from inside an `add` is safe, but scheduling it keeps the
      // final event and the done signal in a predictable order for listeners.
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.close();
      });
    }

    controller.onCancel = () {
      if (!cancelled.isCompleted) cancelled.complete();
    };
    controller.onListen = () {
      unawaited(_drive(
        rawText: rawText,
        online: online,
        limit: limit,
        offset: offset,
        emit: emit,
        finish: finish,
        setConnectivity: (state) => observed = state,
        cancelled: cancelled.future,
        isCancelled: () => cancelled.isCompleted,
      ));
    };
    return controller.stream;
  }

  Future<void> _drive({
    required String rawText,
    required Future<O> Function() online,
    required int limit,
    required int offset,
    required void Function(SearchStage,
            {O? online, OfflineSearchOutcome? offline, Object? error})
        emit,
    required void Function() finish,
    required void Function(ConnectivityState) setConnectivity,
    required Future<void> cancelled,
    required bool Function() isCancelled,
  }) async {
    final localEngine = engine;

    /// Waits for the online request, the overall timeout, or cancellation —
    /// whichever comes first — leaving no timer behind in any of the three
    /// cases. `Future.timeout` would keep its timer alive for the full budget
    /// even after the caller has gone away.
    Future<bool> awaitOnlineOrTimeout(Future<void> online) async {
      final expired = Completer<void>();
      final timer = Timer(policy.overallOnlineTimeout, () {
        if (!expired.isCompleted) expired.complete();
      });
      try {
        await Future.any<void>([online, expired.future, cancelled]);
      } finally {
        timer.cancel();
      }
      return !expired.isCompleted;
    }

    Future<OfflineSearchOutcome?> runLocal() async {
      if (localEngine == null || rawText.trim().isEmpty) return null;
      try {
        if (!await localEngine.database.hasSnapshot()) return null;
        return await localEngine.search(rawText, limit: limit, offset: offset);
      } catch (_) {
        // A missing, corrupt or half-synced snapshot must never take down the
        // search: the online path stays authoritative and simply has no
        // fallback to offer.
        return null;
      }
    }

    // The single connectivity read for this search.
    final connectivity = await observedConnectivity();
    setConnectivity(connectivity);

    // A. Known offline -> answer locally now, do not wait on a request that
    // cannot succeed.
    if (policy.knownOfflineImmediateFallback &&
        connectivity == ConnectivityState.offline) {
      final outcome = await runLocal();
      if (outcome != null && _offlineAnswerable(outcome)) {
        emit(SearchStage.offlineImmediate, offline: outcome);
      } else {
        emit(SearchStage.onlineFailed,
            error: StateError('offline with no usable local answer'));
      }
      finish();
      return;
    }

    // B. Online or unknown connectivity: start the authoritative request
    // immediately, and prepare the local answer alongside it.
    final onlineFuture = online();
    // Attach a no-op handler now so a failure that lands after the budget can
    // never surface as an unhandled async error.
    var onlineSettled = false;
    Object? onlineError;
    O? onlineValue;
    final guardedOnline = onlineFuture.then<void>((value) {
      onlineSettled = true;
      onlineValue = value;
    }, onError: (Object error, StackTrace _) {
      onlineSettled = true;
      onlineError = error;
    });

    final localFuture = runLocal();

    final budgetElapsed = Completer<void>();
    final budgetTimer = Timer(policy.onlineResultBudget, () {
      if (!budgetElapsed.isCompleted) budgetElapsed.complete();
    });

    // Race the online request against the budget.
    await Future.any<void>([guardedOnline, budgetElapsed.future, cancelled]);
    budgetTimer.cancel();
    if (isCancelled()) {
      finish();
      return;
    }

    if (onlineSettled && onlineError == null) {
      // Online answered inside the budget. It wins even if the local result
      // was ready first — that is the deterministic rule for the
      // near-simultaneous case.
      emit(SearchStage.online, online: onlineValue);
      finish();
      return;
    }

    if (onlineSettled && onlineError != null) {
      // Online failed before the budget elapsed.
      final outcome = await localFuture;
      if (outcome != null && _fallbackAnswerable(outcome)) {
        emit(SearchStage.offlineAfterOnlineFailure, offline: outcome);
      } else {
        emit(SearchStage.onlineFailed, error: onlineError);
      }
      finish();
      return;
    }

    // Budget elapsed with the online request still in flight.
    final outcome = await localFuture;
    final canFallBack = outcome != null && _fallbackAnswerable(outcome);

    if (!canFallBack) {
      // E. No safe local answer: keep waiting for the authoritative result
      // under the normal overall timeout. Nothing is fabricated.
      final answered = await awaitOnlineOrTimeout(guardedOnline);
      if (isCancelled()) {
        finish();
        return;
      }
      if (!answered) {
        emit(
          SearchStage.onlineFailed,
          error: TimeoutException(
            'online search exceeded the overall timeout',
            policy.overallOnlineTimeout,
          ),
        );
      } else if (onlineError != null) {
        emit(SearchStage.onlineFailed, error: onlineError);
      } else {
        emit(SearchStage.online, online: onlineValue);
      }
      finish();
      return;
    }

    // C. Show the local result now, keep the online request running.
    emit(SearchStage.offlineFallback, offline: outcome);

    if (!policy.keepOnlineRunningAfterFallback) {
      finish();
      return;
    }

    final answered = await awaitOnlineOrTimeout(guardedOnline);
    if (isCancelled()) {
      finish();
      return;
    }
    if (!answered || onlineError != null) {
      // D. Online failed (or never arrived) after the fallback: the local
      // result stays exactly as it is.
      emit(SearchStage.lateOnlineFailed, error: onlineError);
    } else {
      // The authoritative result is ready but is only ever *offered*.
      emit(SearchStage.lateOnlineAvailable, online: onlineValue);
    }
    finish();
  }

  /// Reads the probe once. A probe that is absent or throwing yields
  /// [ConnectivityState.unknown], which is treated as "attempt online" — never
  /// as offline, so an unusable probe cannot suppress the authoritative path.
  Future<ConnectivityState> observedConnectivity() async {
    final probe = connectivity;
    if (probe == null) return ConnectivityState.unknown;
    try {
      return await probe.isOnline()
          ? ConnectivityState.online
          : ConnectivityState.offline;
    } catch (_) {
      return ConnectivityState.unknown;
    }
  }
}
