/// The single authoritative latency / offline-fallback policy.
///
/// Every timeout, budget and fallback switch that affects search behaviour is
/// declared here. Nothing else in the app may define a competing budget: the
/// previous code had a 4-second budget inside `OfflineSearchRouter` that the
/// search screen never used, alongside a separate hand-rolled offline path in
/// the screen itself, so the documented behaviour and the shipped behaviour
/// disagreed. One policy object removes that class of drift.
class LatencyPolicy {
  /// How long the authoritative online request gets to answer before a valid
  /// local result is surfaced in its place.
  ///
  /// Measured p95 of the warm online path is ~2.3 s, so 4 s leaves real
  /// headroom and only trips on genuinely degraded requests.
  final Duration onlineResultBudget;

  /// The hard ceiling on one online request. Unchanged from the previous
  /// client behaviour (`SearchBackendConfig.typedTimeout`) so this
  /// consolidation does not quietly alter when a request is abandoned.
  final Duration overallOnlineTimeout;

  /// Voice requests carry an upload and a transcription step, so they keep a
  /// longer ceiling.
  final Duration overallVoiceTimeout;

  /// When connectivity is known-absent, skip the online attempt entirely
  /// rather than burning the budget on a request that cannot succeed.
  final bool knownOfflineImmediateFallback;

  /// After a fallback the online request keeps running. It is never cancelled
  /// by the fallback itself, and its late result is offered, never applied.
  final bool keepOnlineRunningAfterFallback;

  /// A local snapshot older than this is still used, but is labelled as saved
  /// data of a stated age.
  final Duration snapshotStaleAfter;

  const LatencyPolicy({
    this.onlineResultBudget = const Duration(milliseconds: 4000),
    this.overallOnlineTimeout = const Duration(seconds: 35),
    this.overallVoiceTimeout = const Duration(seconds: 75),
    this.knownOfflineImmediateFallback = true,
    this.keepOnlineRunningAfterFallback = true,
    this.snapshotStaleAfter = const Duration(hours: 12),
  });

  /// The production policy. Tests construct their own with short budgets.
  static const LatencyPolicy standard = LatencyPolicy();

  LatencyPolicy copyWith({
    Duration? onlineResultBudget,
    Duration? overallOnlineTimeout,
    Duration? overallVoiceTimeout,
    bool? knownOfflineImmediateFallback,
    bool? keepOnlineRunningAfterFallback,
    Duration? snapshotStaleAfter,
  }) {
    return LatencyPolicy(
      onlineResultBudget: onlineResultBudget ?? this.onlineResultBudget,
      overallOnlineTimeout: overallOnlineTimeout ?? this.overallOnlineTimeout,
      overallVoiceTimeout: overallVoiceTimeout ?? this.overallVoiceTimeout,
      knownOfflineImmediateFallback:
          knownOfflineImmediateFallback ?? this.knownOfflineImmediateFallback,
      keepOnlineRunningAfterFallback:
          keepOnlineRunningAfterFallback ?? this.keepOnlineRunningAfterFallback,
      snapshotStaleAfter: snapshotStaleAfter ?? this.snapshotStaleAfter,
    );
  }

  @override
  String toString() =>
      'LatencyPolicy(onlineResultBudgetMs=${onlineResultBudget.inMilliseconds}, '
      'overallOnlineTimeoutMs=${overallOnlineTimeout.inMilliseconds}, '
      'knownOfflineImmediateFallback=$knownOfflineImmediateFallback, '
      'keepOnlineRunningAfterFallback=$keepOnlineRunningAfterFallback)';
}
