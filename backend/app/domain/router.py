from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any

from .search_intent import SearchIntent
from .search_query import MatchMode, PersonRole, SearchQuery
from ..entity_search.models import SearchEntityType


class ResolutionRouteType(StrEnum):
    DIRECT_FILTER = "DIRECT_FILTER"
    ENTITY = "ENTITY"
    SEMANTIC = "SEMANTIC"
    NONE = "NONE"


@dataclass(frozen=True)
class ResolutionRoute:
    field_name: str
    raw_value: Any
    route_type: ResolutionRouteType
    entity_type: SearchEntityType | None = None
    person_role: PersonRole | None = None
    reason: str = ""


@dataclass(frozen=True)
class IntentResolutionPlan:
    intent: SearchIntent
    routes: list[ResolutionRoute] = field(default_factory=list)
    raw_query: str = ""
    normalized_raw_text: str = ""
    unresolved_text_mentions: list[str] = field(default_factory=list)
    needs_entity_resolution: bool = False

    @property
    def direct_filter_routes(self) -> list[ResolutionRoute]:
        return [r for r in self.routes if r.route_type == ResolutionRouteType.DIRECT_FILTER]

    @property
    def entity_routes(self) -> list[ResolutionRoute]:
        return [r for r in self.routes if r.route_type == ResolutionRouteType.ENTITY]


class IntentResolutionRouter:
    """Deterministic routing layer that decides HOW extracted SearchQuery fields and raw query text
    should be processed (DIRECT_FILTER vs ENTITY vs NONE).

    Rules:
    - Pure scalar/relational filters (countries, years, year_from, year_to, stage_numbers) -> DIRECT_FILTER
    - Action taxonomy (action_types) -> DIRECT_FILTER
    - Entity mention fields (rally_names, driver_names, stage_names, uploaders) -> ENTITY
    - Suspicious / unmatched direct fields (e.g. cities) -> flagged for safe entity candidate recovery
    - Empty entity fields with remaining non-filter text -> flagged for entity discovery
    """

    # Intents that can naturally operate on or be satisfied by a person entity
    PERSON_CAPABLE_INTENTS: set[SearchIntent] = {
        SearchIntent.SEARCH_RALLIES,
        SearchIntent.SEARCH_DRIVER_RALLIES,
        SearchIntent.SEARCH_DRIVER_WINS,
        SearchIntent.SEARCH_DRIVER_VIDEOS,
        SearchIntent.SEARCH_VIDEO_ACTIONS,
        SearchIntent.GET_TOP_DRIVERS_BY_WINS,
    }

    # Intents strictly requiring a rally event
    RALLY_STRICT_INTENTS: set[SearchIntent] = {
        SearchIntent.GET_RALLY_RESULTS,
        SearchIntent.GET_RALLY_TOP_FINISHERS,
    }

    def route(
        self,
        query: SearchQuery,
        *,
        raw_text: str = "",
    ) -> IntentResolutionPlan:
        routes: list[ResolutionRoute] = []
        clean_raw = raw_text.strip()
        normalized_raw = clean_raw.lower()

        # 1. Direct filters
        for country in query.countries:
            if country and country.strip():
                routes.append(ResolutionRoute(
                    field_name="countries",
                    raw_value=country.strip(),
                    route_type=ResolutionRouteType.DIRECT_FILTER,
                    reason="Country is a deterministic relational filter",
                ))

        for yr in query.years:
            routes.append(ResolutionRoute(
                field_name="years",
                raw_value=yr,
                route_type=ResolutionRouteType.DIRECT_FILTER,
                reason="Year is a deterministic temporal filter",
            ))

        if query.year_from is not None:
            routes.append(ResolutionRoute(
                field_name="year_from",
                raw_value=query.year_from,
                route_type=ResolutionRouteType.DIRECT_FILTER,
                reason="Year-from is a deterministic temporal range",
            ))

        if query.year_to is not None:
            routes.append(ResolutionRoute(
                field_name="year_to",
                raw_value=query.year_to,
                route_type=ResolutionRouteType.DIRECT_FILTER,
                reason="Year-to is a deterministic temporal range",
            ))

        for stg_num in query.stage_numbers:
            if stg_num and stg_num.strip():
                routes.append(ResolutionRoute(
                    field_name="stage_numbers",
                    raw_value=stg_num.strip(),
                    route_type=ResolutionRouteType.DIRECT_FILTER,
                    reason="Stage number is a deterministic direct filter",
                ))

        for act in query.action_types:
            if act and act.strip():
                routes.append(ResolutionRoute(
                    field_name="action_types",
                    raw_value=act.strip(),
                    route_type=ResolutionRouteType.DIRECT_FILTER,
                    reason="Action taxonomy is a deterministic direct filter",
                ))

        # 2. Entity routes
        for r_name in query.target_rally_names:
            if r_name and r_name.strip():
                routes.append(ResolutionRoute(
                    field_name="rally_names",
                    raw_value=r_name.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.RALLY,
                    reason="Rally name requires canonical entity resolution",
                ))

        for d_name in query.driver_names:
            if d_name and d_name.strip():
                routes.append(ResolutionRoute(
                    field_name="driver_names",
                    raw_value=d_name.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.PERSON,
                    person_role=query.person_role,
                    reason="Driver / Person name requires canonical entity resolution",
                ))

        for s_name in query.stage_names:
            if s_name and s_name.strip():
                routes.append(ResolutionRoute(
                    field_name="stage_names",
                    raw_value=s_name.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.STAGE,
                    reason="Stage name requires canonical entity resolution",
                ))

        for uploader in query.uploaders:
            if uploader and uploader.strip():
                routes.append(ResolutionRoute(
                    field_name="uploaders",
                    raw_value=uploader.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.UPLOADER,
                    reason="Uploader requires canonical entity resolution",
                ))

        for city in query.cities:
            if city and city.strip() and city.strip().upper() != "ALL":
                routes.append(ResolutionRoute(
                    field_name="cities",
                    raw_value=city.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=None,
                    reason="City filter requires validation or cross-type discovery",
                ))

        # 3. Empty entity recovery check:
        # If canonical entity fields are empty, but meaningful unresolved text remains
        # and direct filters alone do not fully explain the search request.
        unresolved_mentions: list[str] = []
        has_entity_field = any(r.route_type == ResolutionRouteType.ENTITY for r in routes)

        if not has_entity_field and clean_raw:
            filter_tokens: set[str] = set()
            for r in routes:
                if r.route_type == ResolutionRouteType.DIRECT_FILTER:
                    filter_tokens.update(str(r.raw_value).lower().split())

            ignored_tokens = {
                "rally", "rallies", "in", "from", "to", "the", "a", "an", "all",
                "videos", "video", "action", "actions", "results", "winner",
                "winners", "top", "driver", "drivers", "show", "me", "find",
                "search", "of", "by", "for", "on", "at", "who", "won"
            }
            raw_tokens = [t for t in normalized_raw.replace(",", " ").replace("?", " ").split() if t]
            residual_tokens = [t for t in raw_tokens if t not in filter_tokens and t not in ignored_tokens]

            if residual_tokens:
                unresolved_candidate = " ".join(residual_tokens)
                unresolved_mentions.append(unresolved_candidate)
                routes.append(ResolutionRoute(
                    field_name="unresolved_text",
                    raw_value=unresolved_candidate,
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.RALLY if query.intent not in (
                        SearchIntent.SEARCH_DRIVER_VIDEOS,
                        SearchIntent.SEARCH_DRIVER_RALLIES,
                        SearchIntent.SEARCH_DRIVER_WINS,
                        SearchIntent.GET_TOP_DRIVERS_BY_WINS,
                    ) else SearchEntityType.PERSON,
                    reason="Unresolved text remaining after direct filters",
                ))

        needs_er = any(r.route_type == ResolutionRouteType.ENTITY for r in routes)

        return IntentResolutionPlan(
            intent=query.intent,
            routes=routes,
            raw_query=clean_raw,
            normalized_raw_text=normalized_raw,
            unresolved_text_mentions=unresolved_mentions,
            needs_entity_resolution=needs_er,
        )
