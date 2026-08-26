import '../../../models/entity_candidate.dart';
import '../../../models/search_query.dart';
import '../llm_query_parser.dart';

/// Abstract contract for deterministic database-backed entity resolution.
abstract class EntityResolver {
  /// Resolves raw entity phrases inside [query] into canonical database entities.
  /// If an entity is ambiguous or multiple strong candidates exist, returns
  /// [EntityResolutionResult.clarification].
  Future<EntityResolutionResult> resolve(
    SearchQuery query, {
    SearchContext? context,
  });
}
