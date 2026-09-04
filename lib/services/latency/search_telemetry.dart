import 'dart:math';

/// Where the result currently on screen came from.
enum SearchResultSource {
  /// Authoritative result from the backend.
  online,

  /// Device was known-offline; the local snapshot answered.
  offline,

  /// Online was tried, exceeded its budget (or failed), and the local snapshot
  /// answered in its place. The online request is still running or has failed.
  offlineFallback,
}

extension SearchResultSourceWire on SearchResultSource {
  String get wireName => switch (this) {
        SearchResultSource.online => 'online',
        SearchResultSource.offline => 'offline',
        SearchResultSource.offlineFallback => 'offline_fallback',
      };
}

/// Client-side connectivity as understood at dispatch time.
enum ConnectivityState { online, offline, unknown }

/// One search's client-side latency record.
///
/// Deliberately carries no query text, no result payload and no credentials —
/// only the correlation id, durations and small enum-like flags. The
/// `requestId` matches the `X-Request-Id` sent to the backend, so a client
/// record and a backend timing line can be joined without either side logging
/// user content.
class SearchTelemetry {
  final String requestId;
  final int totalClientMs;

  /// Wall time of the online HTTP call, when one was actually issued.
  final int? networkRoundtripMs;

  /// Time from dispatch to the first result rendered, whatever its source.
  final int? timeToFirstResultMs;

  final bool fallbackTriggered;

  /// Elapsed ms at which the fallback fired. Null when it did not.
  final int? fallbackTriggerMs;

  final SearchResultSource resultSource;
  final ConnectivityState connectivity;

  /// Whether the deterministic local parser produced a result it could stand
  /// behind for this query. False for ambiguous, unsupported or no-match
  /// queries, which must never be forced into a local answer.
  final bool localParserCouldAnswer;

  /// Set when a late online result arrived after a fallback and is waiting for
  /// the user to accept it.
  final bool lateOnlineOffered;

  const SearchTelemetry({
    required this.requestId,
    required this.totalClientMs,
    required this.resultSource,
    required this.connectivity,
    required this.fallbackTriggered,
    required this.localParserCouldAnswer,
    this.networkRoundtripMs,
    this.timeToFirstResultMs,
    this.fallbackTriggerMs,
    this.lateOnlineOffered = false,
  });

  Map<String, Object?> toJson() => {
        'request_id': requestId,
        'total_client_ms': totalClientMs,
        if (networkRoundtripMs != null) 'network_roundtrip_ms': networkRoundtripMs,
        if (timeToFirstResultMs != null) 'time_to_first_result_ms': timeToFirstResultMs,
        'fallback_triggered': fallbackTriggered,
        if (fallbackTriggerMs != null) 'fallback_trigger_ms': fallbackTriggerMs,
        'result_source': resultSource.wireName,
        'connectivity': connectivity.name,
        'local_parser_could_answer': localParserCouldAnswer,
        'late_online_offered': lateOnlineOffered,
      };
}

/// Generates the correlation id sent as `X-Request-Id`.
///
/// Opaque and derived only from time plus randomness — it carries nothing
/// about the user or the query.
String newRequestId() {
  const alphabet = '0123456789abcdef';
  final random = Random();
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(alphabet[random.nextInt(16)]);
  }
  return buffer.toString();
}

/// Receives completed search telemetry. Production wires this to structured
/// logging; tests capture the records directly.
abstract class SearchTelemetrySink {
  void record(SearchTelemetry telemetry);
}

/// Discards everything. The default, so instrumentation costs nothing unless a
/// sink is deliberately installed.
class NullSearchTelemetrySink implements SearchTelemetrySink {
  const NullSearchTelemetrySink();
  @override
  void record(SearchTelemetry telemetry) {}
}

/// Keeps records in memory for tests and local debugging.
class InMemorySearchTelemetrySink implements SearchTelemetrySink {
  final List<SearchTelemetry> records = [];
  @override
  void record(SearchTelemetry telemetry) => records.add(telemetry);
}
