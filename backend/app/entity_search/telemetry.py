from __future__ import annotations

from dataclasses import dataclass, field
from datetime import timedelta
from typing import Protocol
from .models import CandidateOrigin, EntityType


@dataclass
class EntitySearchFallbackMetrics:
    legacy_resolved: int = 0
    legacy_clarified: int = 0
    legacy_no_match: int = 0
    entity_search_invoked: int = 0
    entity_search_resolved: int = 0
    entity_search_clarified: int = 0
    entity_search_no_match: int = 0
    entity_search_recovered_legacy_failure: int = 0
    role_constraint_rejected: int = 0
    year_constraint_rejected: int = 0
    duplicate_identity_clarification: int = 0
    legacy_latency_microseconds: int = 0
    entity_search_latency_microseconds: int = 0
    total_resolution_latency_microseconds: int = 0

    def to_map(self) -> dict[str, int]:
        return {
            "legacyResolved": self.legacy_resolved,
            "legacyClarified": self.legacy_clarified,
            "legacyNoMatch": self.legacy_no_match,
            "entitySearchInvoked": self.entity_search_invoked,
            "entitySearchResolved": self.entity_search_resolved,
            "entitySearchClarified": self.entity_search_clarified,
            "entitySearchNoMatch": self.entity_search_no_match,
            "entitySearchRecoveredLegacyFailure": self.entity_search_recovered_legacy_failure,
            "roleConstraintRejected": self.role_constraint_rejected,
            "yearConstraintRejected": self.year_constraint_rejected,
            "duplicateIdentityClarification": self.duplicate_identity_clarification,
            "legacyLatencyMicroseconds": self.legacy_latency_microseconds,
            "entitySearchLatencyMicroseconds": self.entity_search_latency_microseconds,
            "totalResolutionLatencyMicroseconds": self.total_resolution_latency_microseconds,
        }


@dataclass(frozen=True)
class EntitySearchShadowDiagnostic:
    raw_mention: str
    entity_type: EntityType
    legacy_outcome: str
    legacy_candidate_ids: list[str]
    entity_search_candidate_ids: list[str]
    entity_search_ranks: list[int]
    candidate_origins: dict[str, CandidateOrigin]
    legacy_resolved_id: str | None
    legacy_resolved_id_appears_in_entity_search: bool
    latency: timedelta


class IEntitySearchFallbackTelemetry(Protocol):
    def record(self, diagnostic: EntitySearchShadowDiagnostic) -> None:
        ...


class NoOpEntitySearchFallbackTelemetry:
    def record(self, diagnostic: EntitySearchShadowDiagnostic) -> None:
        pass
