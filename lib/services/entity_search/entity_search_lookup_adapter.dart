import '../../models/entity_candidate.dart';
import '../llm/entity_resolution/entity_lookup_repository.dart';
import 'entity_search_models.dart';
import 'entity_search_service.dart';

/// POC adapter for exercising NEW retrieval through the unchanged resolver.
/// It is deliberately not wired into production construction.
class EntitySearchLookupAdapter implements IEntityLookupRepository {
  final IEntitySearchService searchService;
  final IEntityLookupRepository cityFallback;

  const EntitySearchLookupAdapter({
    required this.searchService,
    required this.cityFallback,
  });

  Future<List<EntityCandidate>> _search(
    String phrase,
    SearchEntityType type,
    int limit, {
    int? year,
    String? country,
    Map<String, Object?> context = const {},
  }) async {
    final candidates = await searchService.search(
      EntitySearchRequest(
        rawMention: phrase,
        entityType: type,
        limit: limit,
        year: year,
        country: country,
        context: context,
      ),
    );
    return candidates
        .map(
          (c) => EntityCandidate(
            id: c.canonicalId,
            type: switch (c.entityType) {
              SearchEntityType.rally => EntityType.rally,
              SearchEntityType.person => EntityType.driver,
              SearchEntityType.stage => EntityType.stage,
              SearchEntityType.uploader => EntityType.uploader,
            },
            canonicalName: c.canonicalName,
            score: c.score,
            metadata: Map<String, dynamic>.from(c.metadata)
              ..['retrievalSignals'] = c.signals.toMap(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 25,
  }) => _search(
    phrase,
    SearchEntityType.rally,
    limit,
    year: year,
    country: country,
    context: {if (city != null) 'city': city},
  );

  @override
  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    int limit = 25,
  }) => _search(
    phrase,
    SearchEntityType.person,
    limit,
    year: year,
    context: {
      if (eventId != null) 'eventId': eventId,
      if (eventName != null) 'eventName': eventName,
    },
  );

  @override
  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 25,
  }) => _search(
    phrase,
    SearchEntityType.stage,
    limit,
    context: {
      if (eventId != null) 'eventId': eventId,
      if (eventName != null) 'eventName': eventName,
    },
  );

  @override
  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 25,
  }) => _search(phrase, SearchEntityType.uploader, limit);

  @override
  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 25,
  }) => cityFallback.lookupCities(phrase, country: country, limit: limit);
}
