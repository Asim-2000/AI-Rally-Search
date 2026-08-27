import 'result_referent_context.dart';
import 'search_intent.dart';
import 'search_query.dart';
import 'search_results.dart';

/// Immutable snapshot of a single conversational turn in the history stack.
class SessionTurnSnapshot {
  final String title;
  final SearchQuery query;
  final ResultReferentContext referents;
  final String? interpretedSummary;
  final SearchResponse<dynamic>? response;
  final DateTime timestamp;

  const SessionTurnSnapshot({
    required this.title,
    required this.query,
    required this.referents,
    this.interpretedSummary,
    this.response,
    required this.timestamp,
  });
}

/// State machine managing continuous conversational search sessions.
///
/// Keeps query filter state ([SearchQuery]) strictly separate from result-derived
/// referents ([ResultReferentContext]).
class SearchConversationSession {
  final SearchQuery activeQuery;
  final SearchQuery? previousQuery;
  final ResultReferentContext referents;
  final List<SessionTurnSnapshot> history;
  final Set<String> inheritedFields;
  final Set<String> currentRefinementFields;
  final int activeRequestId;

  const SearchConversationSession({
    this.activeQuery = const SearchQuery(intent: SearchIntent.searchRallies),
    this.previousQuery,
    this.referents = ResultReferentContext.empty,
    this.history = const [],
    this.inheritedFields = const {},
    this.currentRefinementFields = const {},
    this.activeRequestId = 0,
  });

  /// Initial clean session.
  static const SearchConversationSession initial = SearchConversationSession();

  /// Creates a copy with selectively replaced properties.
  SearchConversationSession copyWith({
    SearchQuery? activeQuery,
    SearchQuery? previousQuery,
    ResultReferentContext? referents,
    List<SessionTurnSnapshot>? history,
    Set<String>? inheritedFields,
    Set<String>? currentRefinementFields,
    int? activeRequestId,
  }) {
    return SearchConversationSession(
      activeQuery: activeQuery ?? this.activeQuery,
      previousQuery: previousQuery ?? this.previousQuery,
      referents: referents ?? this.referents,
      history: history ?? this.history,
      inheritedFields: inheritedFields ?? this.inheritedFields,
      currentRefinementFields: currentRefinementFields ?? this.currentRefinementFields,
      activeRequestId: activeRequestId ?? this.activeRequestId,
    );
  }

  /// Increments and returns the new active request ID for stale response protection.
  SearchConversationSession nextRequest() {
    return copyWith(activeRequestId: activeRequestId + 1);
  }

  /// Records a completed turn into the history stack and advances session state.
  SearchConversationSession recordTurn({
    required SearchQuery query,
    required ResultReferentContext referents,
    required String title,
    SearchResponse<dynamic>? response,
    String? interpretedSummary,
    Set<String> inherited = const {},
    Set<String> refinements = const {},
  }) {
    final snapshot = SessionTurnSnapshot(
      title: title,
      query: query,
      referents: referents,
      interpretedSummary: interpretedSummary,
      response: response,
      timestamp: DateTime.now(),
    );

    return SearchConversationSession(
      activeQuery: query,
      previousQuery: activeQuery,
      referents: referents,
      history: [...history, snapshot],
      inheritedFields: inherited,
      currentRefinementFields: refinements,
      activeRequestId: activeRequestId,
    );
  }

  /// Rolls back history to the specified index.
  SearchConversationSession rollbackTo(int historyIndex) {
    if (historyIndex < 0 || historyIndex >= history.length) return this;
    final target = history[historyIndex];
    final newHistory = history.sublist(0, historyIndex + 1);

    return SearchConversationSession(
      activeQuery: target.query,
      previousQuery: historyIndex > 0 ? history[historyIndex - 1].query : null,
      referents: target.referents,
      history: newHistory,
      inheritedFields: const {},
      currentRefinementFields: const {},
      activeRequestId: activeRequestId + 1,
    );
  }

  /// Deterministically removes a specific filter value from the active [SearchQuery].
  ///
  /// For instance: removing "Ireland" from countries, or removing "jump" from actionTypes.
  /// Also updates referents if the removed entity was the active referent.
  SearchConversationSession removeFilter({required String field, required dynamic value}) {
    final q = activeQuery;
    SearchQuery updatedQuery = q;
    ResultReferentContext updatedReferents = referents;

    final valStr = value?.toString().trim();

    switch (field.toLowerCase()) {
      case 'country':
      case 'countries':
        final list = List<String>.from(q.countries);
        list.removeWhere((c) => c.equalsIgnoreCase(valStr));
        updatedQuery = q.copyWith(countries: list);
        break;

      case 'city':
      case 'cities':
        final list = List<String>.from(q.cities);
        list.removeWhere((c) => c.equalsIgnoreCase(valStr));
        updatedQuery = q.copyWith(cities: list);
        break;

      case 'year':
      case 'years':
        final list = List<int>.from(q.years);
        final yr = value is int ? value : int.tryParse(valStr ?? '');
        if (yr != null) list.remove(yr);
        updatedQuery = q.copyWith(years: list);
        break;

      case 'rally':
      case 'rallies':
      case 'rallynames':
      case 'targetrallyname':
        final list = List<String>.from(q.rallyNames);
        list.removeWhere((r) => r.equalsIgnoreCase(valStr));
        updatedQuery = q.copyWith(rallyNames: list);
        if (referents.activeRally?.equalsIgnoreCase(valStr) == true) {
          updatedReferents = referents.copyWith(clearActiveRally: true);
        }
        break;

      case 'driver':
      case 'drivers':
      case 'drivernames':
      case 'drivername':
        final list = List<String>.from(q.driverNames);
        list.removeWhere((d) => d.equalsIgnoreCase(valStr));
        updatedQuery = q.copyWith(driverNames: list);
        if (referents.activeDriver?.equalsIgnoreCase(valStr) == true ||
            referents.lastWinner?.equalsIgnoreCase(valStr) == true) {
          updatedReferents = referents.copyWith(clearActiveDriver: true, clearLastWinner: true);
        }
        break;

      case 'action':
      case 'actions':
      case 'actiontypes':
      case 'actiontype':
        final list = List<String>.from(q.actionTypes);
        list.removeWhere((a) => a.equalsIgnoreCase(valStr));
        updatedQuery = q.copyWith(actionTypes: list);
        break;

      case 'stage':
      case 'stages':
      case 'stagenames':
        final list = List<String>.from(q.stageNames);
        list.removeWhere((s) => s.equalsIgnoreCase(valStr));
        updatedQuery = q.copyWith(stageNames: list);
        if (referents.activeStage?.equalsIgnoreCase(valStr) == true) {
          updatedReferents = referents.copyWith(clearActiveStage: true);
        }
        break;
    }

    final newInherited = Set<String>.from(inheritedFields);
    final newRefinements = Set<String>.from(currentRefinementFields);

    return copyWith(
      activeQuery: updatedQuery,
      referents: updatedReferents,
      inheritedFields: newInherited,
      currentRefinementFields: newRefinements,
      activeRequestId: activeRequestId + 1,
    );
  }

  /// Deterministically adds a filter value (e.g. adding 'drift' alongside existing 'jump').
  SearchConversationSession addFilter({required String field, required dynamic value}) {
    final q = activeQuery;
    SearchQuery updatedQuery = q;
    final valStr = value?.toString().trim();
    if (valStr == null || valStr.isEmpty) return this;

    switch (field.toLowerCase()) {
      case 'country':
      case 'countries':
        final list = List<String>.from(q.countries);
        if (!list.any((c) => c.equalsIgnoreCase(valStr))) list.add(valStr);
        updatedQuery = q.copyWith(countries: list);
        break;

      case 'city':
      case 'cities':
        final list = List<String>.from(q.cities);
        if (!list.any((c) => c.equalsIgnoreCase(valStr))) list.add(valStr);
        updatedQuery = q.copyWith(cities: list);
        break;

      case 'year':
      case 'years':
        final list = List<int>.from(q.years);
        final yr = value is int ? value : int.tryParse(valStr);
        if (yr != null && !list.contains(yr)) list.add(yr);
        updatedQuery = q.copyWith(years: list);
        break;

      case 'rally':
      case 'rallies':
      case 'rallynames':
        final list = List<String>.from(q.rallyNames);
        if (!list.any((r) => r.equalsIgnoreCase(valStr))) list.add(valStr);
        updatedQuery = q.copyWith(rallyNames: list);
        break;

      case 'driver':
      case 'drivers':
      case 'drivernames':
        final list = List<String>.from(q.driverNames);
        if (!list.any((d) => d.equalsIgnoreCase(valStr))) list.add(valStr);
        updatedQuery = q.copyWith(driverNames: list);
        break;

      case 'action':
      case 'actions':
      case 'actiontypes':
        final list = List<String>.from(q.actionTypes);
        if (!list.any((a) => a.equalsIgnoreCase(valStr))) list.add(valStr.toLowerCase());
        updatedQuery = q.copyWith(
          intent: SearchIntent.searchVideoActions,
          actionTypes: list,
        );
        break;
    }

    final newRefinements = Set<String>.from(currentRefinementFields)..add(field);

    return copyWith(
      activeQuery: updatedQuery,
      currentRefinementFields: newRefinements,
      activeRequestId: activeRequestId + 1,
    );
  }

  /// Clears the session back to default.
  SearchConversationSession clearAll() {
    return SearchConversationSession(
      activeQuery: const SearchQuery(intent: SearchIntent.searchRallies),
      previousQuery: null,
      referents: ResultReferentContext.empty,
      history: const [],
      inheritedFields: const {},
      currentRefinementFields: const {},
      activeRequestId: activeRequestId + 1,
    );
  }
}

extension _StringExt on String {
  bool equalsIgnoreCase(String? other) {
    if (other == null) return false;
    return toLowerCase() == other.toLowerCase();
  }
}
