import '../../models/entity_candidate.dart';
import '../../models/search_intent.dart';
import '../../models/search_query.dart';
import '../../models/search_results.dart';
import '../friendly_response_service.dart';
import 'offline_database.dart';
import 'offline_entity_index.dart';
import 'offline_query_parser.dart';
import 'offline_search_executor.dart';

/// What the offline pipeline concluded for one query.
enum OfflineOutcomeKind { results, clarification, special, noMatch, unsupported }

/// A fully-offline search result envelope. Shares the online result shapes so
/// the UI render path is identical.
class OfflineSearchOutcome {
  final OfflineOutcomeKind kind;
  final SearchQuery? query;
  final SearchResponse<dynamic>? response;
  final String? clarificationQuestion;
  final List<EntityCandidate> candidates;
  final SearchIntent? intent;
  final FriendlyResponseCategory? specialCategory;
  final String? unresolvedMention;

  const OfflineSearchOutcome({
    required this.kind,
    this.query,
    this.response,
    this.clarificationQuestion,
    this.candidates = const [],
    this.intent,
    this.specialCategory,
    this.unresolvedMention,
  });

  bool get isSpecial => kind == OfflineOutcomeKind.special;
  bool get requiresClarification => kind == OfflineOutcomeKind.clarification;
  bool get hasResults => kind == OfflineOutcomeKind.results;
}

/// Deterministic, model-free offline search: special-query match -> deterministic
/// parser -> local entity resolution -> local SearchPlan-compatible execution over
/// the SQLite snapshot. No LLM, no dynamic SQL, no direct MySQL.
class OfflineSearchEngine {
  final OfflineDatabase database;
  final OfflineEntityIndex index;
  final OfflineQueryParser parser;
  final OfflineSearchExecutor executor;

  OfflineSearchEngine._(this.database, this.index, this.parser, this.executor);

  /// Builds the engine, loading the in-memory entity index from local SQLite.
  static Future<OfflineSearchEngine> create(OfflineDatabase database, {int limit = 20}) async {
    final index = await database.buildEntityIndex();
    final parser = OfflineQueryParser(index: index, limit: limit);
    final executor = OfflineSearchExecutor(database);
    return OfflineSearchEngine._(database, index, parser, executor);
  }

  /// Runs a raw text query fully offline.
  Future<OfflineSearchOutcome> search(
    String rawText, {
    int limit = 20,
    int offset = 0,
  }) async {
    final parsed = parser.parse(rawText);
    switch (parsed.kind) {
      case OfflineParseKind.special:
        return OfflineSearchOutcome(
          kind: OfflineOutcomeKind.special,
          specialCategory: parsed.specialCategory,
        );
      case OfflineParseKind.unsupported:
        return const OfflineSearchOutcome(kind: OfflineOutcomeKind.unsupported);
      case OfflineParseKind.noMatch:
        return OfflineSearchOutcome(
          kind: OfflineOutcomeKind.noMatch,
          unresolvedMention: parsed.unresolvedMention,
        );
      case OfflineParseKind.clarification:
        return OfflineSearchOutcome(
          kind: OfflineOutcomeKind.clarification,
          intent: parsed.intent,
          clarificationQuestion: parsed.clarificationQuestion,
          candidates: parsed.candidates.map(_toCandidate).toList(),
        );
      case OfflineParseKind.results:
        final query = parsed.query!.copyWith(limit: limit, offset: offset);
        final response = await executor.execute(query);
        return OfflineSearchOutcome(
          kind: OfflineOutcomeKind.results,
          query: query,
          response: response,
          intent: query.intent,
        );
    }
  }

  /// Executes an already-resolved query offline (e.g. pagination / a chosen
  /// clarification candidate).
  Future<SearchResponse<dynamic>> execute(SearchQuery query) => executor.execute(query);

  EntityCandidate _toCandidate(OfflineCandidate c) {
    final e = c.entity;
    final type = switch (e.type) {
      OfflineEntityType.rally => EntityType.rally,
      OfflineEntityType.person => EntityType.driver,
      OfflineEntityType.stage => EntityType.stage,
      OfflineEntityType.uploader => EntityType.uploader,
    };
    return EntityCandidate(
      id: e.canonicalId,
      type: type,
      canonicalName: e.canonicalName,
      score: c.score,
      metadata: {
        if (e.year != null) 'year': e.year,
        if (e.country != null) 'country': e.country,
        if (e.driverId != null) 'driverId': e.driverId,
        if (e.codriverId != null) 'codriverId': e.codriverId,
        if (e.accountId != null) 'accountId': e.accountId,
      },
    );
  }
}
