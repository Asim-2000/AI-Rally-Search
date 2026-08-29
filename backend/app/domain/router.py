from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
import re
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
class IntentCapability:
    intent: SearchIntent
    allowed_primary_entity_types: set[SearchEntityType]
    allowed_filter_entity_types: set[SearchEntityType]
    allow_cross_type_recovery: bool = True
    allowed_recovery_transitions: dict[SearchEntityType, SearchEntityType] = field(default_factory=dict)


# Intent Capability Matrix explicitly defining primary entity types, allowed filter entity types,
# and allowed cross-type recovery transitions for all 9 search intents.
INTENT_CAPABILITIES: dict[SearchIntent, IntentCapability] = {
    SearchIntent.SEARCH_RALLIES: IntentCapability(
        intent=SearchIntent.SEARCH_RALLIES,
        allowed_primary_entity_types={SearchEntityType.RALLY},
        allowed_filter_entity_types={SearchEntityType.STAGE, SearchEntityType.PERSON, SearchEntityType.UPLOADER},
        allow_cross_type_recovery=True,
        allowed_recovery_transitions={
            SearchEntityType.STAGE: SearchEntityType.RALLY,
            SearchEntityType.PERSON: SearchEntityType.PERSON,
        },
    ),
    SearchIntent.SEARCH_DRIVER_RALLIES: IntentCapability(
        intent=SearchIntent.SEARCH_DRIVER_RALLIES,
        allowed_primary_entity_types={SearchEntityType.PERSON},
        allowed_filter_entity_types={SearchEntityType.RALLY, SearchEntityType.STAGE},
        allow_cross_type_recovery=True,
        allowed_recovery_transitions={
            SearchEntityType.RALLY: SearchEntityType.PERSON,
        },
    ),
    SearchIntent.SEARCH_DRIVER_WINS: IntentCapability(
        intent=SearchIntent.SEARCH_DRIVER_WINS,
        allowed_primary_entity_types={SearchEntityType.PERSON},
        allowed_filter_entity_types={SearchEntityType.RALLY, SearchEntityType.STAGE},
        allow_cross_type_recovery=True,
        allowed_recovery_transitions={
            SearchEntityType.RALLY: SearchEntityType.PERSON,
        },
    ),
    SearchIntent.GET_RALLY_RESULTS: IntentCapability(
        intent=SearchIntent.GET_RALLY_RESULTS,
        allowed_primary_entity_types={SearchEntityType.RALLY},
        allowed_filter_entity_types={SearchEntityType.STAGE},
        allow_cross_type_recovery=False,
        allowed_recovery_transitions={},
    ),
    SearchIntent.GET_RALLY_TOP_FINISHERS: IntentCapability(
        intent=SearchIntent.GET_RALLY_TOP_FINISHERS,
        allowed_primary_entity_types={SearchEntityType.RALLY},
        allowed_filter_entity_types={SearchEntityType.STAGE},
        allow_cross_type_recovery=False,
        allowed_recovery_transitions={},
    ),
    SearchIntent.SEARCH_VIDEO_ACTIONS: IntentCapability(
        intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
        allowed_primary_entity_types=set(),
        allowed_filter_entity_types={
            SearchEntityType.RALLY,
            SearchEntityType.PERSON,
            SearchEntityType.STAGE,
            SearchEntityType.UPLOADER,
        },
        allow_cross_type_recovery=True,
        allowed_recovery_transitions={
            SearchEntityType.STAGE: SearchEntityType.RALLY,
        },
    ),
    SearchIntent.SEARCH_DRIVER_VIDEOS: IntentCapability(
        intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
        allowed_primary_entity_types={SearchEntityType.PERSON},
        allowed_filter_entity_types={SearchEntityType.RALLY, SearchEntityType.STAGE, SearchEntityType.UPLOADER},
        allow_cross_type_recovery=True,
        allowed_recovery_transitions={
            SearchEntityType.RALLY: SearchEntityType.PERSON,
        },
    ),
    SearchIntent.GET_TOP_UPLOADERS: IntentCapability(
        intent=SearchIntent.GET_TOP_UPLOADERS,
        allowed_primary_entity_types={SearchEntityType.UPLOADER},
        allowed_filter_entity_types={SearchEntityType.RALLY},
        allow_cross_type_recovery=False,
        allowed_recovery_transitions={},
    ),
    SearchIntent.GET_TOP_DRIVERS_BY_WINS: IntentCapability(
        intent=SearchIntent.GET_TOP_DRIVERS_BY_WINS,
        allowed_primary_entity_types={SearchEntityType.PERSON},
        allowed_filter_entity_types={SearchEntityType.RALLY},
        allow_cross_type_recovery=False,
        allowed_recovery_transitions={},
    ),
}


@dataclass(frozen=True)
class IntentResolutionPlan:
    intent: SearchIntent
    routes: list[ResolutionRoute] = field(default_factory=list)
    raw_query: str = ""
    normalized_raw_text: str = ""
    unexplained_tokens: list[str] = field(default_factory=list)
    needs_entity_resolution: bool = False

    @property
    def direct_filters(self) -> list[ResolutionRoute]:
        return [r for r in self.routes if r.route_type == ResolutionRouteType.DIRECT_FILTER]

    @property
    def direct_filter_routes(self) -> list[ResolutionRoute]:
        return self.direct_filters

    @property
    def entity_routes(self) -> list[ResolutionRoute]:
        return [r for r in self.routes if r.route_type == ResolutionRouteType.ENTITY]

    @property
    def unresolved_text_mentions(self) -> list[str]:
        return self.unexplained_tokens


class IntentResolutionRouter:
    """Deterministic routing layer that decides HOW extracted SearchQuery fields and raw query text
    should be processed (DIRECT_FILTER vs ENTITY vs NONE) before canonical resolution.

    The router:
    - Does NOT call LLMs
    - Does NOT query the DB
    - Does NOT perform fuzzy matching
    - Does NOT rank entity candidates
    - Does NOT generate canonical IDs
    - Does NOT generate SearchPlans or SQL
    - Operates purely in-memory in sub-millisecond time.
    """

    KNOWN_INTENT_FUNCTION_WORDS: set[str] = {
        "rally", "rallies", "in", "from", "to", "the", "a", "an", "all",
        "videos", "video", "clip", "clips", "action", "actions", "results",
        "result", "winner", "winners", "win", "wins", "won", "winning", "top",
        "finishers", "finisher", "driver", "drivers", "show", "shows", "showing",
        "me", "find", "finds", "finding", "search", "searches", "searching", "of",
        "by", "for", "on", "at", "who", "what", "where", "which", "when", "how",
        "he", "him", "his", "her", "she", "it", "that", "this", "these", "those",
        "both", "and", "or", "with", "only", "just", "about", "stage", "stages",
        "full", "leaderboard", "participat", "participate", "participated", "compete",
        "competed", "competing", "entered", "drove", "driven", "co-drove", "co-driven",
        "co-driver", "codriver", "codrivers", "co-drivers", "navigator", "navigators",
        "uploader", "uploaders", "most", "any", "some", "is", "are", "was", "were",
        "been", "being", "have", "has", "had", "do", "does", "did", "get", "gets",
        "getting", "list", "lists", "listing", "see", "display", "tell", "held", "hold",
        "holds", "holding", "took", "take", "takes", "taking", "place", "places",
        "featuring", "features", "featured", "stuck", "recorded", "shot", "captured",
        "between", "during", "season", "seasons", "year", "years", "country", "countries",
        "city", "cities", "event", "events", "located"
    }

    ACTION_EXPANSIONS: dict[str, set[str]] = {
        "jump": {"jump", "jumps", "jumping", "jumped"},
        "drift": {"drift", "drifts", "drifting", "drifted"},
        "crash": {"crash", "crashes", "crashing", "crashed"},
        "spin": {"spin", "spins", "spinning", "spun"},
        "donut": {"donut", "donuts"},
        "highlight": {"highlight", "highlights"},
        "moment": {"moment", "moments"},
        "action": {"action", "actions"},
        "roll": {"roll", "rolls", "rolling", "rolled"},
        "save": {"save", "saves", "saving", "saved"},
    }

    # Aggregate intents describe a ranking over the corpus. Their remaining raw
    # words are ranking language, not an omitted entity mention.
    GLOBAL_AGGREGATE_INTENTS: set[SearchIntent] = {
        SearchIntent.GET_TOP_DRIVERS_BY_WINS,
        SearchIntent.GET_TOP_UPLOADERS,
    }

    def route(
        self,
        raw_text_or_query: str | SearchQuery = "",
        query_or_raw: SearchQuery | str | None = None,
        *,
        raw_text: str | None = None,
        query: SearchQuery | None = None,
    ) -> IntentResolutionPlan:
        # Flexible signature normalization to support route(raw_text, query) or route(query, raw_text=...)
        effective_raw: str = ""
        effective_query: SearchQuery | None = None

        if isinstance(raw_text_or_query, SearchQuery):
            effective_query = raw_text_or_query
            if isinstance(query_or_raw, str):
                effective_raw = query_or_raw
        elif isinstance(raw_text_or_query, str):
            effective_raw = raw_text_or_query
            if isinstance(query_or_raw, SearchQuery):
                effective_query = query_or_raw

        if raw_text is not None:
            effective_raw = raw_text
        if query is not None:
            effective_query = query

        if effective_query is None:
            raise ValueError("A valid SearchQuery must be provided to IntentResolutionRouter.route")

        routes: list[ResolutionRoute] = []
        clean_raw = effective_raw.strip()
        normalized_raw = clean_raw.lower()

        # 1. Direct filters
        for country in effective_query.countries:
            if country and country.strip():
                routes.append(ResolutionRoute(
                    field_name="countries",
                    raw_value=country.strip(),
                    route_type=ResolutionRouteType.DIRECT_FILTER,
                    reason="Country is a deterministic relational filter",
                ))

        for city in effective_query.cities:
            if city and city.strip() and city.strip().upper() != "ALL":
                routes.append(ResolutionRoute(
                    field_name="cities",
                    raw_value=city.strip(),
                    route_type=ResolutionRouteType.DIRECT_FILTER,
                    reason="City is a deterministic filter (eligible for cross-type recovery if validation fails)",
                ))

        for yr in effective_query.years:
            routes.append(ResolutionRoute(
                field_name="years",
                raw_value=yr,
                route_type=ResolutionRouteType.DIRECT_FILTER,
                reason="Year is a deterministic temporal filter",
            ))

        if effective_query.year_from is not None:
            routes.append(ResolutionRoute(
                field_name="year_from",
                raw_value=effective_query.year_from,
                route_type=ResolutionRouteType.DIRECT_FILTER,
                reason="Year-from is a deterministic temporal range",
            ))

        if effective_query.year_to is not None:
            routes.append(ResolutionRoute(
                field_name="year_to",
                raw_value=effective_query.year_to,
                route_type=ResolutionRouteType.DIRECT_FILTER,
                reason="Year-to is a deterministic temporal range",
            ))

        for stg_num in effective_query.stage_numbers:
            if stg_num and stg_num.strip():
                routes.append(ResolutionRoute(
                    field_name="stage_numbers",
                    raw_value=stg_num.strip(),
                    route_type=ResolutionRouteType.DIRECT_FILTER,
                    reason="Stage number is a deterministic direct filter",
                ))

        for act in effective_query.action_types:
            if act and act.strip():
                routes.append(ResolutionRoute(
                    field_name="action_types",
                    raw_value=act.strip(),
                    route_type=ResolutionRouteType.DIRECT_FILTER,
                    reason="Action taxonomy is a deterministic direct filter",
                ))

        # 2. Entity routes
        for r_name in effective_query.target_rally_names:
            if r_name and r_name.strip():
                routes.append(ResolutionRoute(
                    field_name="rally_names",
                    raw_value=r_name.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.RALLY,
                    reason="Rally name requires canonical entity resolution",
                ))

        for d_name in effective_query.driver_names:
            if d_name and d_name.strip():
                routes.append(ResolutionRoute(
                    field_name="driver_names",
                    raw_value=d_name.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.PERSON,
                    person_role=effective_query.person_role,
                    reason="Driver / Person name requires canonical entity resolution",
                ))

        for s_name in effective_query.stage_names:
            if s_name and s_name.strip():
                routes.append(ResolutionRoute(
                    field_name="stage_names",
                    raw_value=s_name.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.STAGE,
                    reason="Stage name requires canonical entity resolution",
                ))

        for uploader in effective_query.uploaders:
            if uploader and uploader.strip():
                routes.append(ResolutionRoute(
                    field_name="uploaders",
                    raw_value=uploader.strip(),
                    route_type=ResolutionRouteType.ENTITY,
                    entity_type=SearchEntityType.UPLOADER,
                    reason="Uploader requires canonical entity resolution",
                ))

        # 3. Conservative Unexplained Raw Text Accounting:
        # Check whether structured fields + known intent/function words sufficiently explain the input.
        unexplained_tokens: list[str] = []
        has_entity_field = any(r.route_type == ResolutionRouteType.ENTITY for r in routes)

        if (
            not has_entity_field
            and clean_raw
            and effective_query.intent not in self.GLOBAL_AGGREGATE_INTENTS
        ):
            explained_tokens: set[str] = set()
            for r in routes:
                val_str = str(r.raw_value).lower()
                for token in re.findall(r"[\w-]+", val_str):
                    explained_tokens.add(token)
                if r.field_name == "action_types" and val_str in self.ACTION_EXPANSIONS:
                    explained_tokens.update(self.ACTION_EXPANSIONS[val_str])

            raw_tokens = re.findall(r"[\w-]+", normalized_raw)
            residual = [
                t for t in raw_tokens
                if t not in explained_tokens
                and t not in self.KNOWN_INTENT_FUNCTION_WORDS
                and not t.isdigit()
            ]

            if residual:
                unexplained_candidate = " ".join(residual)
                unexplained_tokens = list(residual)

                capability = INTENT_CAPABILITIES.get(effective_query.intent)
                if capability is not None:
                    # Choose recovery entity type constrained by capability matrix
                    if SearchEntityType.PERSON in capability.allowed_primary_entity_types:
                        target_entity_type = SearchEntityType.PERSON
                    elif SearchEntityType.RALLY in capability.allowed_primary_entity_types:
                        target_entity_type = SearchEntityType.RALLY
                    elif SearchEntityType.RALLY in capability.allowed_filter_entity_types:
                        target_entity_type = SearchEntityType.RALLY
                    elif SearchEntityType.PERSON in capability.allowed_filter_entity_types:
                        target_entity_type = SearchEntityType.PERSON
                    else:
                        target_entity_type = SearchEntityType.RALLY

                    routes.append(ResolutionRoute(
                        field_name="unresolved_text",
                        raw_value=unexplained_candidate,
                        route_type=ResolutionRouteType.ENTITY,
                        entity_type=target_entity_type,
                        person_role=effective_query.person_role if target_entity_type == SearchEntityType.PERSON else None,
                        reason="Unexplained entity-like text permitted by intent capability",
                    ))

        needs_er = any(r.route_type == ResolutionRouteType.ENTITY for r in routes)

        return IntentResolutionPlan(
            intent=effective_query.intent,
            routes=routes,
            raw_query=clean_raw,
            normalized_raw_text=normalized_raw,
            unexplained_tokens=unexplained_tokens,
            needs_entity_resolution=needs_er,
        )
