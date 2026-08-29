from __future__ import annotations

from typing import Any
from ..domain.search_query import PersonRole
from .eligibility import is_person_role_eligible
from .models import (
    CandidateOrigin,
    EntityCandidate,
    EntitySearchRequest,
    EntityType,
    SearchEntityType,
)
from .service import IEntitySearchService


class EntitySearchLookupAdapter:
    """Adapter for querying InMemoryEntitySearchService through IEntityLookupRepository interface."""

    def __init__(
        self,
        *,
        search_service: IEntitySearchService,
        city_fallback: Any | None = None,
        metrics: Any | None = None,
    ) -> None:
        self.search_service = search_service
        self.city_fallback = city_fallback
        self.metrics = metrics

    async def _search(
        self,
        phrase: str,
        entity_type: SearchEntityType,
        limit: int,
        *,
        year: int | None = None,
        country: str | None = None,
        context: dict[str, Any] | None = None,
    ) -> list[EntityCandidate]:
        candidates = await self.search_service.search(
            EntitySearchRequest(
                raw_mention=phrase,
                entity_type=entity_type,
                limit=limit,
                year=year,
                country=country,
                context=context or {},
            )
        )

        eligible: list[EntityCandidate] = []
        for c in candidates:
            if year is not None and entity_type == SearchEntityType.RALLY:
                allowed = c.metadata.get("year") == year
                if not allowed:
                    if self.metrics is not None:
                        self.metrics.year_constraint_rejected += 1
                    continue

            type_map = {
                SearchEntityType.RALLY: EntityType.RALLY,
                SearchEntityType.PERSON: EntityType.DRIVER,
                SearchEntityType.STAGE: EntityType.STAGE,
                SearchEntityType.UPLOADER: EntityType.UPLOADER,
            }

            meta = dict(c.metadata)
            meta["retrievalSignals"] = c.signals.to_map()
            meta["candidateOrigin"] = CandidateOrigin.ENTITY_SEARCH.value

            eligible.append(
                EntityCandidate(
                    id=c.canonical_id,
                    type=type_map[c.entity_type],
                    canonical_name=c.canonical_name,
                    score=c.score,
                    metadata=meta,
                )
            )

        return eligible

    async def lookup_rallies(
        self,
        phrase: str,
        *,
        year: int | None = None,
        country: str | None = None,
        city: str | None = None,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        context = {"city": city} if city is not None else {}
        return await self._search(
            phrase,
            SearchEntityType.RALLY,
            limit,
            year=year,
            country=country,
            context=context,
        )

    async def lookup_drivers(
        self,
        phrase: str,
        *,
        event_id: str | None = None,
        event_name: str | None = None,
        year: int | None = None,
        person_role: PersonRole = PersonRole.ANY,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        context: dict[str, Any] = {}
        if event_id is not None:
            context["eventId"] = event_id
        if event_name is not None:
            context["eventName"] = event_name

        candidates = await self._search(
            phrase,
            SearchEntityType.PERSON,
            limit,
            year=year,
            context=context,
        )

        eligible: list[EntityCandidate] = []
        for c in candidates:
            allowed = is_person_role_eligible(c.metadata, person_role)
            if not allowed:
                if self.metrics is not None:
                    self.metrics.role_constraint_rejected += 1
                continue
            eligible.append(c)

        return eligible

    async def lookup_stages(
        self,
        phrase: str,
        *,
        event_id: str | None = None,
        event_name: str | None = None,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        context: dict[str, Any] = {}
        if event_id is not None:
            context["eventId"] = event_id
        if event_name is not None:
            context["eventName"] = event_name

        return await self._search(
            phrase,
            SearchEntityType.STAGE,
            limit,
            context=context,
        )

    async def lookup_uploaders(
        self,
        phrase: str,
        *,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        return await self._search(phrase, SearchEntityType.UPLOADER, limit)

    async def lookup_cities(
        self,
        phrase: str,
        *,
        country: str | None = None,
        limit: int = 25,
    ) -> list[EntityCandidate]:
        if self.city_fallback is not None:
            return await self.city_fallback.lookup_cities(phrase, country=country, limit=limit)
        return []
