import 'search_intent.dart';
import 'search_results.dart';
import 'video_action.dart';

/// Encapsulates entities established by database search results, entity resolutions,
/// or explicit user selections during a conversational search session.
///
/// This is decoupled from [SearchQuery] filters:
/// - [SearchQuery] defines what filters we are executing.
/// - [ResultReferentContext] defines the entities derived from past result responses
///   (e.g., the winner of a rally, the single rally returned from a search, or a clicked driver).
class ResultReferentContext {
  final String? activeRally;
  final String? activeRallyId;
  final List<String> activeRallies;
  final String? activeDriver;
  final String? activeDriverId;
  final List<String> activeDrivers;
  final String? activeStage;
  final String? activeStageNumber;
  final String? lastWinner;
  final String? lastWinnerDriverId;
  final String? lastSelectedDriver;
  final String? lastSelectedDriverId;
  final String? lastSelectedRally;
  final String? lastSelectedRallyId;
  final Map<String, dynamic> metadata;

  const ResultReferentContext({
    this.activeRally,
    this.activeRallyId,
    this.activeRallies = const [],
    this.activeDriver,
    this.activeDriverId,
    this.activeDrivers = const [],
    this.activeStage,
    this.activeStageNumber,
    this.lastWinner,
    this.lastWinnerDriverId,
    this.lastSelectedDriver,
    this.lastSelectedDriverId,
    this.lastSelectedRally,
    this.lastSelectedRallyId,
    this.metadata = const {},
  });

  /// Empty initial referent context.
  static const ResultReferentContext empty = ResultReferentContext();

  /// Creates a copy with selectively updated referents.
  ResultReferentContext copyWith({
    String? activeRally,
    String? activeRallyId,
    List<String>? activeRallies,
    String? activeDriver,
    String? activeDriverId,
    List<String>? activeDrivers,
    String? activeStage,
    String? activeStageNumber,
    String? lastWinner,
    String? lastWinnerDriverId,
    String? lastSelectedDriver,
    String? lastSelectedDriverId,
    String? lastSelectedRally,
    String? lastSelectedRallyId,
    Map<String, dynamic>? metadata,
    bool clearActiveRally = false,
    bool clearActiveDriver = false,
    bool clearActiveStage = false,
    bool clearLastWinner = false,
  }) {
    return ResultReferentContext(
      activeRally: clearActiveRally ? null : (activeRally ?? this.activeRally),
      activeRallyId: clearActiveRally ? null : (activeRallyId ?? this.activeRallyId),
      activeRallies: clearActiveRally ? const [] : (activeRallies ?? this.activeRallies),
      activeDriver: clearActiveDriver ? null : (activeDriver ?? this.activeDriver),
      activeDriverId: clearActiveDriver ? null : (activeDriverId ?? this.activeDriverId),
      activeDrivers: clearActiveDriver ? const [] : (activeDrivers ?? this.activeDrivers),
      activeStage: clearActiveStage ? null : (activeStage ?? this.activeStage),
      activeStageNumber: clearActiveStage ? null : (activeStageNumber ?? this.activeStageNumber),
      lastWinner: clearLastWinner ? null : (lastWinner ?? this.lastWinner),
      lastWinnerDriverId: clearLastWinner ? null : (lastWinnerDriverId ?? this.lastWinnerDriverId),
      lastSelectedDriver: lastSelectedDriver ?? this.lastSelectedDriver,
      lastSelectedDriverId: lastSelectedDriverId ?? this.lastSelectedDriverId,
      lastSelectedRally: lastSelectedRally ?? this.lastSelectedRally,
      lastSelectedRallyId: lastSelectedRallyId ?? this.lastSelectedRallyId,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Deterministically extracts conversational referents from typed [SearchResponse] data.
  factory ResultReferentContext.fromSearchResponse(
    SearchResponse<dynamic> response, {
    ResultReferentContext previous = ResultReferentContext.empty,
    String? queryRally,
    String? queryDriver,
    List<String>? queryRallies,
    List<String>? queryDrivers,
  }) {
    String? activeRally = previous.activeRally;
    String? activeRallyId = previous.activeRallyId;
    List<String> activeRallies = List<String>.from(previous.activeRallies);
    String? activeDriver = previous.activeDriver;
    String? activeDriverId = previous.activeDriverId;
    List<String> activeDrivers = List<String>.from(previous.activeDrivers);
    String? activeStage = previous.activeStage;
    String? activeStageNumber = previous.activeStageNumber;
    String? lastWinner = previous.lastWinner;
    String? lastWinnerDriverId = previous.lastWinnerDriverId;

    if (queryRallies != null && queryRallies.isNotEmpty) {
      activeRallies = queryRallies;
      activeRally = queryRallies.first;
    } else if (queryRally != null && queryRally.isNotEmpty) {
      activeRally = queryRally;
      if (!activeRallies.contains(queryRally)) {
        activeRallies = [queryRally, ...activeRallies];
      }
    }

    if (queryDrivers != null && queryDrivers.isNotEmpty) {
      activeDrivers = queryDrivers;
      activeDriver = queryDrivers.first;
    } else if (queryDriver != null && queryDriver.isNotEmpty) {
      activeDriver = queryDriver;
      if (!activeDrivers.contains(queryDriver)) {
        activeDrivers = [queryDriver, ...activeDrivers];
      }
    }

    final results = response.results;
    if (results.isEmpty) {
      return previous.copyWith(
        activeRally: activeRally,
        activeRallies: activeRallies,
        activeDriver: activeDriver,
        activeDrivers: activeDrivers,
      );
    }

    switch (response.intent) {
      case SearchIntent.getRallyResults:
      case SearchIntent.getRallyTopFinishers:
        final finishers = results.whereType<RallyResult>().toList();
        if (finishers.isNotEmpty) {
          final first = finishers.first;
          lastWinner = first.driverName;
          if (first.driverId != null) {
            lastWinnerDriverId = first.driverId.toString();
          }
          activeDriver = first.driverName;
          if (first.eventName.isNotEmpty) {
            activeRally = first.eventName;
            activeRallyId = first.rallyId;
            if (!activeRallies.contains(first.eventName)) {
              activeRallies = [first.eventName, ...activeRallies];
            }
          }
          final allDrivers = finishers.map((f) => f.driverName).where((d) => d.isNotEmpty).toSet().toList();
          activeDrivers = allDrivers;
        }
        break;

      case SearchIntent.searchRallies:
        final rallies = results.whereType<RallySearchResult>().toList();
        if (rallies.length == 1) {
          activeRally = rallies.first.eventName;
          activeRallyId = rallies.first.eventId;
        }
        activeRallies = rallies.map((r) => r.eventName).toList();
        break;

      case SearchIntent.searchDriverRallies:
      case SearchIntent.searchDriverWins:
        final parts = results.whereType<RallyParticipationResult>().toList();
        if (parts.isNotEmpty) {
          final first = parts.first;
          if (first.driverName.isNotEmpty) {
            activeDriver = first.driverName;
          }
          if (parts.length == 1 && first.eventName.isNotEmpty) {
            activeRally = first.eventName;
            activeRallyId = first.rallyId;
          }
          final rallyNames = parts.map((p) => p.eventName).where((r) => r.isNotEmpty).toSet().toList();
          if (rallyNames.isNotEmpty) {
            activeRallies = rallyNames;
          }
        }
        break;

      case SearchIntent.searchVideoActions:
        final actions = results.whereType<VideoAction>().toList();
        if (actions.isNotEmpty) {
          final actionDrivers = actions.map((a) => a.driverName).whereType<String>().where((d) => d.isNotEmpty).toSet().toList();
          if (actionDrivers.length == 1) {
            activeDriver = actionDrivers.first;
          }
          final actionRallies = actions.map((a) => a.eventName).whereType<String>().where((r) => r.isNotEmpty).toSet().toList();
          if (actionRallies.length == 1) {
            activeRally = actionRallies.first;
          }
        }
        break;

      case SearchIntent.searchDriverVideos:
        final vids = results.whereType<VideoSearchResult>().toList();
        if (vids.isNotEmpty) {
          final vidDrivers = vids.map((v) => v.driverName).whereType<String>().where((d) => d.isNotEmpty).toSet().toList();
          if (vidDrivers.length == 1) {
            activeDriver = vidDrivers.first;
          }
        }
        break;

      case SearchIntent.getTopDriversByWins:
        final wins = results.whereType<DriverWinResult>().toList();
        if (wins.isNotEmpty) {
          lastWinner = wins.first.driverName;
          activeDriver = wins.first.driverName;
          activeDrivers = wins.map((w) => w.driverName).toList();
        }
        break;

      case SearchIntent.getTopUploaders:
        break;
    }

    return ResultReferentContext(
      activeRally: activeRally,
      activeRallyId: activeRallyId,
      activeRallies: activeRallies,
      activeDriver: activeDriver,
      activeDriverId: activeDriverId,
      activeDrivers: activeDrivers,
      activeStage: activeStage,
      activeStageNumber: activeStageNumber,
      lastWinner: lastWinner,
      lastWinnerDriverId: lastWinnerDriverId,
      lastSelectedDriver: previous.lastSelectedDriver,
      lastSelectedDriverId: previous.lastSelectedDriverId,
      lastSelectedRally: previous.lastSelectedRally,
      lastSelectedRallyId: previous.lastSelectedRallyId,
      metadata: previous.metadata,
    );
  }

  /// Compact string representation for logging or telemetry.
  @override
  String toString() {
    return 'ResultReferentContext(activeRally: $activeRally, activeDriver: $activeDriver, lastWinner: $lastWinner, activeDrivers: $activeDrivers)';
  }
}
