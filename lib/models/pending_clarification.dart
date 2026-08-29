import 'entity_candidate.dart';
import 'result_referent_context.dart';
import 'search_query.dart';

class ClarificationSelection {
  final SearchQuery query;
  final ResultReferentContext referents;

  const ClarificationSelection({required this.query, required this.referents});
}

/// Immutable context captured when entity resolution asks the user to choose.
/// A selection replaces only the ambiguous entity dimension.
class PendingClarification {
  final SearchQuery query;
  final ResultReferentContext referents;
  final int requestId;

  const PendingClarification({
    required this.query,
    required this.referents,
    required this.requestId,
  });

  ClarificationSelection? select(
    EntityCandidate candidate, {
    required int currentRequestId,
  }) {
    if (currentRequestId != requestId) return null;

    var updated = query;
    var updatedReferents = referents;
    switch (candidate.type) {
      case EntityType.rally:
        final year = candidate.metadata?['year'] as int?;
        updated = query.copyWith(
          rallyNames: [candidate.canonicalName],
          years: year == null ? query.years : [year],
        );
        updatedReferents = referents.copyWith(
          activeRally: candidate.canonicalName,
          activeRallyId: candidate.id,
          activeRallies: [candidate.canonicalName],
          lastSelectedRally: candidate.canonicalName,
          lastSelectedRallyId: candidate.id,
        );
        break;
      case EntityType.driver:
        updated = query.copyWith(
          driverNames: [candidate.canonicalName],
          driverIds: candidate.id.isEmpty ? query.driverIds : [candidate.id],
        );
        updatedReferents = referents.copyWith(
          activeDriver: candidate.canonicalName,
          activeDriverId: candidate.id,
          activeDrivers: [candidate.canonicalName],
          lastSelectedDriver: candidate.canonicalName,
          lastSelectedDriverId: candidate.id,
        );
        break;
      case EntityType.stage:
        updated = query.copyWith(stageNames: [candidate.canonicalName]);
        updatedReferents = referents.copyWith(
          activeStage: candidate.canonicalName,
          activeStageNumber: candidate.metadata?['stageNumber']?.toString(),
        );
        break;
      case EntityType.uploader:
        updated = query.copyWith(uploaders: [candidate.canonicalName]);
        break;
      case EntityType.city:
        updated = query.copyWith(cities: [candidate.canonicalName]);
        break;
    }
    return ClarificationSelection(query: updated, referents: updatedReferents);
  }
}
