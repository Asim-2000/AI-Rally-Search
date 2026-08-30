import 'dart:async';

import 'offline_messaging.dart';
import 'offline_search_engine.dart';

/// Reachability signal. Abstracted so the policy is testable without a device.
abstract class ConnectivityProbe {
  Future<bool> isOnline();
}

/// How a routed search was answered.
enum RouteMode {
  onlineAuthoritative,
  offlineLocal, // device plainly offline
  lowBandwidthLocal, // online attempted, budget elapsed -> local shown, online still running
  backendUnreachableLocal, // online attempted and failed -> local
}

class RouteResult<O> {
  final RouteMode mode;
  final O? online;
  final OfflineSearchOutcome? offline;

  /// When [mode] is [RouteMode.lowBandwidthLocal], the still-running online
  /// request. The caller must NOT swap silently — offer an explicit
  /// "HQ answered — show latest" affordance when it completes.
  final Future<O>? pendingOnline;
  final OfflineUxState uxState;

  const RouteResult({
    required this.mode,
    this.online,
    this.offline,
    this.pendingOnline,
    required this.uxState,
  });
}

/// NETWORK_FIRST_WITH_LOCAL_FALLBACK.
///
/// Accuracy > latency: the authoritative online pipeline is tried first when the
/// device looks reachable, within a bounded, bandwidth-aware fallback budget. On
/// a plainly-offline device the online attempt is skipped entirely. A local
/// result never gets silently replaced by a late online result — promotion is
/// only ever offered via an explicit affordance.
///
/// The budget numbers are deliberately conservative and tunable; the shape is
/// fixed, the numbers are not.
class OfflineSearchRouter<O> {
  final ConnectivityProbe connectivity;
  final OfflineSearchEngine engine;

  /// Bandwidth-aware fallback budget — materially shorter than the full request
  /// timeout (35 s). When it elapses without an online answer, the local result
  /// is surfaced immediately while the online request keeps running.
  final Duration fallbackBudget;

  const OfflineSearchRouter({
    required this.connectivity,
    required this.engine,
    this.fallbackBudget = const Duration(seconds: 4),
  });

  /// Routes one query. [online] performs the authoritative online search;
  /// [rawText] is used for the local fallback.
  Future<RouteResult<O>> route({
    required String rawText,
    required Future<O> Function() online,
    int limit = 20,
    int offset = 0,
  }) async {
    Future<OfflineSearchOutcome> local() => engine.search(rawText, limit: limit, offset: offset);

    // A. Plainly offline -> local immediately (no wasted wait).
    final online0 = await connectivity.isOnline();
    if (!online0) {
      final outcome = await local();
      return RouteResult<O>(
        mode: RouteMode.offlineLocal,
        offline: outcome,
        uxState: _stateForOffline(outcome),
      );
    }

    // B/C. Try online within the bandwidth-aware budget.
    final onlineFuture = online();
    try {
      final result = await onlineFuture.timeout(fallbackBudget);
      return RouteResult<O>(mode: RouteMode.onlineAuthoritative, online: result, uxState: OfflineUxState.online);
    } on TimeoutException {
      // Budget elapsed: surface local now, keep online running for promotion.
      final outcome = await local();
      // Prevent an unhandled error if the still-running request later fails.
      final guarded = onlineFuture.catchError((Object e) => throw e);
      return RouteResult<O>(
        mode: RouteMode.lowBandwidthLocal,
        offline: outcome,
        pendingOnline: guarded,
        uxState: OfflineUxState.lowBandwidthLocalFallback,
      );
    } catch (_) {
      // Backend error / network drop -> deterministic local fallback.
      final outcome = await local();
      return RouteResult<O>(
        mode: RouteMode.backendUnreachableLocal,
        offline: outcome,
        uxState: OfflineUxState.backendUnreachableLocalAvailable,
      );
    }
  }

  OfflineUxState _stateForOffline(OfflineSearchOutcome outcome) {
    switch (outcome.kind) {
      case OfflineOutcomeKind.clarification:
        return OfflineUxState.offlineAmbiguity;
      case OfflineOutcomeKind.noMatch:
        return OfflineUxState.offlineSafeNoMatch;
      case OfflineOutcomeKind.unsupported:
        return OfflineUxState.offlineQueryUnsupported;
      case OfflineOutcomeKind.special:
      case OfflineOutcomeKind.results:
        return OfflineUxState.offlineLocalResults;
    }
  }
}
