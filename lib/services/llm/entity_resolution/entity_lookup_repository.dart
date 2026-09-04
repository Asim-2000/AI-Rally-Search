import '../../../models/entity_candidate.dart';
import '../../../models/search_query.dart';

/// Abstract contract for entity candidate lookups.
///
/// Implementations are backend-backed (over HTTPS) or test doubles. The device
/// never queries the database directly; the former AWS RDS/MySQL implementation
/// has been removed so no DB credentials or SQL ship in the client.
abstract class IEntityLookupRepository {
  Future<List<EntityCandidate>> lookupRallies(
    String phrase, {
    int? year,
    String? country,
    String? city,
    int limit = 25,
  });

  Future<List<EntityCandidate>> lookupDrivers(
    String phrase, {
    String? eventId,
    String? eventName,
    int? year,
    PersonRole personRole = PersonRole.any,
    int limit = 25,
  });

  Future<List<EntityCandidate>> lookupStages(
    String phrase, {
    String? eventId,
    String? eventName,
    int limit = 25,
  });

  Future<List<EntityCandidate>> lookupCities(
    String phrase, {
    String? country,
    int limit = 25,
  });

  Future<List<EntityCandidate>> lookupUploaders(
    String phrase, {
    int limit = 25,
  });
}
