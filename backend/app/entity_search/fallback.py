from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import timedelta
from typing import Any, Protocol
from ..domain.search_query import SearchQuery
from .identity import get_canonical_identity
from .models import (
    CandidateOrigin,
    EntityCandidate,
    EntityResolutionResult,
    EntitySearchFallbackMode,
    EntityType,
)
from .telemetry import (
    EntitySearchFallbackMetrics,
    EntitySearchShadowDiagnostic,
    IEntitySearchFallbackTelemetry,
    NoOpEntitySearchFallbackTelemetry,
)


@dataclass(frozen=True)
class EntitySearchFallbackConfig:
    mode: EntitySearchFallbackMode = EntitySearchFallbackMode.OFF

    @classmethod
    def from_value(cls, value: str | None) -> EntitySearchFallbackConfig:
        if value is None or not value.strip():
            return cls(mode=EntitySearchFallbackMode.FALLBACK)
        v = value.strip().lower()
        if v == "shadow":
            return cls(mode=EntitySearchFallbackMode.SHADOW)
        if v == "fallback":
            return cls(mode=EntitySearchFallbackMode.FALLBACK)
        if v == "off":
            return cls(mode=EntitySearchFallbackMode.OFF)
        raise ValueError(
            f"Unsupported entity search fallback mode: '{value}'. "
            "Supported modes are: OFF, SHADOW, FALLBACK."
        )


class EntityResolverProtocol(Protocol):
    async def resolve(
        self,
        query: SearchQuery,
        *,
        context: Any = None,
    ) -> EntityResolutionResult:
        ...


class ControlledFallbackEntityResolver:
    """Controlled SQL-First Entity Resolver with fallback to Entity Search."""

    def __init__(
        self,
        *,
        legacy_resolver: EntityResolverProtocol,
        entity_search_resolver: EntityResolverProtocol,
        config: EntitySearchFallbackConfig | None = None,
        telemetry: IEntitySearchFallbackTelemetry | None = None,
        metrics: EntitySearchFallbackMetrics | None = None,
    ) -> None:
        self.legacy_resolver = legacy_resolver
        self.entity_search_resolver = entity_search_resolver
        self.config = config or EntitySearchFallbackConfig()
        self.telemetry = telemetry or NoOpEntitySearchFallbackTelemetry()
        self.metrics = metrics or EntitySearchFallbackMetrics()

    async def resolve(
        self,
        query: SearchQuery,
        *,
        context: Any = None,
    ) -> EntityResolutionResult:
        return await self.resolve_controlled(query, context=context)

    async def resolve_controlled(
        self,
        query: SearchQuery,
        *,
        context: Any = None,
        voice: bool = False,
    ) -> EntityResolutionResult:
        total_start = time.perf_counter()
        legacy_start = time.perf_counter()
        legacy = await self.legacy_resolver.resolve(query, context=context)
        legacy_elapsed = time.perf_counter() - legacy_start

        self.metrics.legacy_latency_microseconds += int(legacy_elapsed * 1_000_000)
        self._increment_outcome(legacy, legacy=True)

        unsafe_legacy_person = self._has_unbridged_legacy_person(query, legacy)
        if self.config.mode == EntitySearchFallbackMode.OFF or (
            self._is_clear_legacy_winner(query, legacy) and not unsafe_legacy_person
        ):
            total_elapsed = time.perf_counter() - total_start
            self.metrics.total_resolution_latency_microseconds += int(total_elapsed * 1_000_000)
            return legacy

        self.metrics.entity_search_invoked += 1
        es_start = time.perf_counter()
        recovered = await self.entity_search_resolver.resolve(query, context=context)
        es_elapsed = time.perf_counter() - es_start

        self.metrics.entity_search_latency_microseconds += int(es_elapsed * 1_000_000)
        self._increment_outcome(recovered, legacy=False)
        self._record_diagnostics(query, legacy, recovered, timedelta(seconds=es_elapsed))

        if self.config.mode == EntitySearchFallbackMode.SHADOW:
            total_elapsed = time.perf_counter() - total_start
            self.metrics.total_resolution_latency_microseconds += int(total_elapsed * 1_000_000)
            return legacy

        if not self._has_useful_outcome(legacy) and self._has_useful_outcome(recovered):
            self.metrics.entity_search_recovered_legacy_failure += 1

        if self._is_duplicate_identity_clarification(recovered):
            self.metrics.duplicate_identity_clarification += 1

        if voice and self._is_recovered_auto_resolution(recovered):
            result = self._voice_clarification(query, recovered)
        else:
            result = (
                recovered
                if (self._has_useful_outcome(recovered) or unsafe_legacy_person)
                else legacy
            )

        total_elapsed = time.perf_counter() - total_start
        self.metrics.total_resolution_latency_microseconds += int(total_elapsed * 1_000_000)
        return result

    def _increment_outcome(
        self,
        result: EntityResolutionResult,
        *,
        legacy: bool,
    ) -> None:
        outcome = self._outcome(result)
        if legacy:
            if outcome == "resolved":
                self.metrics.legacy_resolved += 1
            elif outcome == "clarification":
                self.metrics.legacy_clarified += 1
            else:
                self.metrics.legacy_no_match += 1
        else:
            if outcome == "resolved":
                self.metrics.entity_search_resolved += 1
            elif outcome == "clarification":
                self.metrics.entity_search_clarified += 1
            else:
                self.metrics.entity_search_no_match += 1

    @staticmethod
    def _is_duplicate_identity_clarification(result: EntityResolutionResult) -> bool:
        if not result.requires_clarification:
            return False
        people = [c for c in result.candidates if c.type == EntityType.DRIVER]
        for i in range(len(people)):
            for j in range(i + 1, len(people)):
                if (
                    people[i].canonical_name.lower() == people[j].canonical_name.lower()
                    and get_canonical_identity(people[i]) != get_canonical_identity(people[j])
                ):
                    return True
        return False

    @staticmethod
    def _has_useful_outcome(result: EntityResolutionResult) -> bool:
        return (
            result.requires_clarification
            or any(r.is_resolved for r in result.resolutions.values())
        )

    @staticmethod
    def _is_clear_legacy_winner(
        query: SearchQuery,
        result: EntityResolutionResult,
    ) -> bool:
        if not result.is_success or result.requires_clarification or result.error is not None:
            return False
        expected = len(query.rally_names) + len(query.driver_names) + len(query.stage_names)
        if expected == 0:
            return True
        return sum(1 for r in result.resolutions.values() if r.is_resolved) >= expected

    @staticmethod
    def _has_unbridged_legacy_person(
        query: SearchQuery,
        result: EntityResolutionResult,
    ) -> bool:
        if not query.driver_names:
            return False
        for resolution in result.resolutions.values():
            if resolution.type != EntityType.DRIVER or not resolution.is_resolved:
                continue
            cand = resolution.resolved_candidate
            if cand is None:
                continue
            account_id = (cand.metadata or {}).get("accountId") or (cand.metadata or {}).get("account_id")
            if not account_id or str(account_id).strip() == "" or str(account_id).lower() == "null":
                return True
        return False

    @staticmethod
    def _is_recovered_auto_resolution(result: EntityResolutionResult) -> bool:
        for resolution in result.resolutions.values():
            cand = resolution.resolved_candidate
            if cand is None:
                continue
            signals = (cand.metadata or {}).get("retrievalSignals")
            if not isinstance(signals, dict):
                return True
            if (signals.get("exact", 0) < 1) and (signals.get("normalizedExact", 0) < 1):
                return True
        return False

    @staticmethod
    def _voice_clarification(
        query: SearchQuery,
        recovered: EntityResolutionResult,
    ) -> EntityResolutionResult:
        candidates = [
            r.resolved_candidate
            for r in recovered.resolutions.values()
            if r.resolved_candidate is not None
        ]
        if not candidates:
            return recovered
        return EntityResolutionResult.clarification(
            parsed_query=query,
            clarification_question=f'Did you mean "{candidates[0].canonical_name}"?',
            candidates=candidates,
            resolutions=recovered.resolutions,
        )

    def _record_diagnostics(
        self,
        query: SearchQuery,
        legacy: EntityResolutionResult,
        recovered: EntityResolutionResult,
        latency: timedelta,
    ) -> None:
        legacy_by_type = self._candidates_by_type(legacy)
        recovered_by_type = self._candidates_by_type(recovered)

        mentions: list[tuple[str, EntityType]] = []
        for m in query.rally_names:
            mentions.append((m, EntityType.RALLY))
        for m in query.driver_names:
            mentions.append((m, EntityType.DRIVER))
        for m in query.stage_names:
            mentions.append((m, EntityType.STAGE))

        for phrase, etype in mentions:
            legacy_cands = legacy_by_type.get(etype, [])
            new_cands = recovered_by_type.get(etype, [])

            legacy_resolved = next(
                (
                    r.resolved_candidate.id
                    for r in legacy.resolutions.values()
                    if r.type == etype and r.is_resolved and r.resolved_candidate is not None
                ),
                None,
            )

            legacy_ids = list({get_canonical_identity(c) for c in legacy_cands})
            new_ids = list({get_canonical_identity(c) for c in new_cands})

            self.telemetry.record(
                EntitySearchShadowDiagnostic(
                    raw_mention=phrase,
                    entity_type=etype,
                    legacy_outcome=self._outcome(legacy),
                    legacy_candidate_ids=legacy_ids,
                    entity_search_candidate_ids=new_ids,
                    entity_search_ranks=list(range(1, len(new_cands) + 1)),
                    candidate_origins=self._candidate_origins(legacy_cands, new_cands),
                    legacy_resolved_id=legacy_resolved,
                    legacy_resolved_id_appears_in_entity_search=(
                        legacy_resolved is not None
                        and any(get_canonical_identity(c) == legacy_resolved for c in new_cands)
                    ),
                    latency=latency,
                )
            )

    @staticmethod
    def _candidate_origins(
        legacy: list[EntityCandidate],
        entity_search: list[EntityCandidate],
    ) -> dict[str, CandidateOrigin]:
        legacy_ids = {get_canonical_identity(c) for c in legacy}
        es_ids = {get_canonical_identity(c) for c in entity_search}
        all_ids = legacy_ids | es_ids
        return {
            cid: (
                CandidateOrigin.BOTH
                if cid in legacy_ids and cid in es_ids
                else (CandidateOrigin.SQL if cid in legacy_ids else CandidateOrigin.ENTITY_SEARCH)
            )
            for cid in all_ids
        }

    @staticmethod
    def _candidates_by_type(
        result: EntityResolutionResult,
    ) -> dict[EntityType, list[EntityCandidate]]:
        all_cands = list(result.candidates)
        for res in result.resolutions.values():
            all_cands.extend(res.candidate_options)
            if res.resolved_candidate is not None:
                all_cands.append(res.resolved_candidate)

        grouped: dict[EntityType, list[EntityCandidate]] = {}
        for c in all_cands:
            identity = get_canonical_identity(c)
            bucket = grouped.setdefault(c.type, [])
            if not any(get_canonical_identity(existing) == identity for existing in bucket):
                bucket.append(c)
        return grouped

    @staticmethod
    def _outcome(result: EntityResolutionResult) -> str:
        if result.requires_clarification:
            return "clarification"
        if result.error is not None:
            return "no_match"
        if any(r.is_resolved for r in result.resolutions.values()):
            return "resolved"
        return "no_match"
