import 'entity_search_models.dart';

abstract class IEntitySearchService {
  Future<List<EntitySearchCandidate>> search(EntitySearchRequest request);

  /// Re-reads the source of truth and atomically replaces the current index.
  Future<EntitySearchIndexStats> rebuild();

  EntitySearchIndexStats? get indexStats;
}

abstract class IEntitySearchDataSource {
  Future<List<CanonicalSearchEntity>> loadEntities();
}
