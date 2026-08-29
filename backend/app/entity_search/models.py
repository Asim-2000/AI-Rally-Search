from __future__ import annotations

from dataclasses import dataclass, field
from datetime import timedelta
from enum import StrEnum
from typing import Any


class SearchEntityType(StrEnum):
    RALLY = "rally"
    PERSON = "person"
    STAGE = "stage"
    UPLOADER = "uploader"


class IndexedPersonRole(StrEnum):
    DRIVER = "driver"
    CO_DRIVER = "coDriver"
    BOTH = "both"


class EntityType(StrEnum):
    RALLY = "rally"
    DRIVER = "driver"
    STAGE = "stage"
    UPLOADER = "uploader"
    CITY = "city"


class EntitySearchFallbackMode(StrEnum):
    OFF = "off"
    SHADOW = "shadow"
    FALLBACK = "fallback"


class CandidateOrigin(StrEnum):
    SQL = "sql"
    ENTITY_SEARCH = "entitySearch"
    BOTH = "both"


@dataclass(frozen=True)
class EntitySearchRequest:
    raw_mention: str
    entity_type: SearchEntityType
    limit: int = 10
    year: int | None = None
    country: str | None = None
    person_role: Any = None
    context: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class EntitySearchSignals:
    exact_score: float = 0.0
    normalized_exact_score: float = 0.0
    token_score: float = 0.0
    ngram_score: float = 0.0
    lexical_score: float = 0.0
    phonetic_score: float = 0.0
    context_score: float = 0.0

    def to_map(self) -> dict[str, float]:
        return {
            "exact": self.exact_score,
            "normalizedExact": self.normalized_exact_score,
            "token": self.token_score,
            "ngram": self.ngram_score,
            "lexical": self.lexical_score,
            "phonetic": self.phonetic_score,
            "context": self.context_score,
        }


@dataclass(frozen=True)
class EntitySearchCandidate:
    canonical_id: str
    canonical_name: str
    entity_type: SearchEntityType
    score: float
    signals: EntitySearchSignals
    matched_by: set[str]
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class CanonicalSearchEntity:
    canonical_id: str
    canonical_name: str
    entity_type: SearchEntityType
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class EntitySearchIndexStats:
    entity_count: int
    build_time: timedelta
    estimated_bytes: int
    canonical_estimated_bytes: int = 0
    posting_list_estimated_bytes: int = 0


@dataclass(frozen=True)
class EntitySearchQueryStats:
    entity_type: SearchEntityType
    raw_candidates_evaluated: int
    surviving_candidates: int
    returned_candidates: int
    latency: timedelta
    candidate_generation_latency: timedelta = timedelta(0)
    scoring_latency: timedelta = timedelta(0)
    full_universe_size: int = 0
    generated_candidate_pool: int = 0
    used_full_scan_escape: bool = False


@dataclass(frozen=True)
class EntityCandidate:
    id: str
    type: EntityType
    canonical_name: str
    subtitle: str | None = None
    score: float = 1.0
    metadata: dict[str, Any] | None = None

    def copy_with(
        self,
        *,
        id: str | None = None,
        type: EntityType | None = None,
        canonical_name: str | None = None,
        subtitle: str | None = None,
        score: float | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> EntityCandidate:
        return EntityCandidate(
            id=id if id is not None else self.id,
            type=type if type is not None else self.type,
            canonical_name=canonical_name if canonical_name is not None else self.canonical_name,
            subtitle=subtitle if subtitle is not None else self.subtitle,
            score=score if score is not None else self.score,
            metadata=metadata if metadata is not None else self.metadata,
        )

    def to_map(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "id": self.id,
            "type": self.type.value,
            "canonicalName": self.canonical_name,
            "score": self.score,
        }
        if self.subtitle is not None:
            result["subtitle"] = self.subtitle
        if self.metadata is not None:
            result["metadata"] = self.metadata
        return result


@dataclass(frozen=True)
class EntityResolution:
    type: EntityType
    raw_phrase: str
    confidence: float
    strategy: str
    resolved_candidate: EntityCandidate | None = None
    is_ambiguous: bool = False
    candidate_options: list[EntityCandidate] = field(default_factory=list)

    @property
    def is_resolved(self) -> bool:
        return self.resolved_candidate is not None and not self.is_ambiguous

    def to_dict(self) -> dict[str, Any]:
        return {
            "type": self.type.value,
            "rawPhrase": self.raw_phrase,
            "resolvedCandidate": self.resolved_candidate.canonical_name if self.resolved_candidate else None,
            "resolvedId": self.resolved_candidate.id if self.resolved_candidate else None,
            "confidence": self.confidence,
            "strategy": self.strategy,
            "isAmbiguous": self.is_ambiguous,
            "candidateOptionsCount": len(self.candidate_options),
        }


@dataclass
class EntityResolutionResult:
    parsed_query: Any | None = None
    resolved_query: Any | None = None
    requires_clarification: bool = False
    clarification_question: str | None = None
    candidates: list[EntityCandidate] = field(default_factory=list)
    resolutions: dict[str, EntityResolution] = field(default_factory=dict)
    error: str | None = None

    @property
    def is_success(self) -> bool:
        return self.resolved_query is not None and not self.requires_clarification and self.error is None

    @classmethod
    def success(
        cls,
        *,
        parsed_query: Any,
        resolved_query: Any,
        resolutions: dict[str, EntityResolution] | None = None,
    ) -> EntityResolutionResult:
        return cls(
            parsed_query=parsed_query,
            resolved_query=resolved_query,
            requires_clarification=False,
            resolutions=resolutions or {},
        )

    @classmethod
    def clarification(
        cls,
        *,
        parsed_query: Any,
        clarification_question: str,
        candidates: list[EntityCandidate],
        resolutions: dict[str, EntityResolution] | None = None,
    ) -> EntityResolutionResult:
        return cls(
            parsed_query=parsed_query,
            resolved_query=parsed_query,
            requires_clarification=True,
            clarification_question=clarification_question,
            candidates=candidates,
            resolutions=resolutions or {},
        )

    @classmethod
    def failure(
        cls,
        error: str,
        *,
        parsed_query: Any | None = None,
    ) -> EntityResolutionResult:
        return cls(
            parsed_query=parsed_query,
            error=error,
        )
