import re
import time
from typing import Any
from pydantic import BaseModel, ConfigDict, Field

from ..domain.conversation_reducer import reduce_turn
from ..domain.conversation_session import SearchConversationSession
from ..domain.referent_context import ResultReferentContext
from ..domain.results import SearchResponse
from ..domain.router import IntentResolutionPlan, IntentResolutionRouter
from ..domain.search_plan import SearchPlan
from ..domain.search_intent import SearchIntent
from ..domain.search_query import SearchQuery
from ..domain.summary import generate_interpreted_summary
from ..entity_search.models import EntityCandidate, EntityResolution, SearchEntityType
from ..entity_search.resolver import DatabaseEntityResolver
from ..query_understanding.context import SearchContext
from ..query_understanding.service import QueryUnderstandingService
from ..repositories.search_repository import SearchRepository
from .search_plan_builder import SearchPlanBuilder, SearchPlanError, UnresolvedEntityError
from .special_query import match_special_query

# Deterministic direct-filter recovery (ACC-2). Canonical country names present
# in the dataset gazetteer (repositories/sql.py COUNTRIES). Only full names are
# used so that a stray two-letter token cannot be mistaken for a country.
_RECOVERABLE_COUNTRIES: dict[str, str] = {
    "ireland": "Ireland", "portugal": "Portugal", "united kingdom": "United Kingdom",
    "france": "France", "austria": "Austria", "norway": "Norway", "poland": "Poland",
    "belgium": "Belgium", "spain": "Spain", "italy": "Italy", "latvia": "Latvia",
    "czech republic": "Czech Republic", "germany": "Germany", "kenya": "Kenya",
    "croatia": "Croatia", "netherlands": "Netherlands", "new zealand": "New Zealand",
    "lithuania": "Lithuania", "slovakia": "Slovakia", "qatar": "Qatar",
    "pakistan": "Pakistan", "barbados": "Barbados", "sweden": "Sweden",
    "finland": "Finland", "estonia": "Estonia",
}

# Follow-up video/action intent recovery cues (ACC-1).
_VIDEO_INTENT_CUES: frozenset[str] = frozenset({
    "video", "videos", "footage", "clip", "clips",
    "highlight", "highlights", "moment", "moments",
})
# Raw action cue token -> canonical action taxonomy value.
_ACTION_INTENT_CUES: dict[str, str] = {
    "jump": "jump", "jumps": "jump", "jumping": "jump", "jumped": "jump",
    "crash": "crash", "crashes": "crash", "crashing": "crash", "crashed": "crash",
    "drift": "drift", "drifts": "drift", "drifting": "drift", "drifted": "drift",
    "spin": "spin", "spins": "spin", "spinning": "spin", "spun": "spin",
    "donut": "donut", "donuts": "donut",
    "roll": "roll", "rolls": "roll", "rolling": "roll", "rolled": "roll",
}


class ConversationalSearchResult(BaseModel):
    """Complete result of a multi-turn natural language search turn,

    mirroring NaturalLanguageSearchResult in Dart.
    """
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    parsed_query: SearchQuery | None = Field(default=None, alias="parsedQuery")
    resolved_query: SearchQuery | None = Field(default=None, alias="resolvedQuery")
    routing_plan: IntentResolutionPlan | None = Field(default=None, alias="routingPlan")
    search_plan: SearchPlan | None = Field(default=None, alias="searchPlan")
    search_response: SearchResponse | None = Field(default=None, alias="searchResponse")
    requires_clarification: bool = Field(default=False, alias="requiresClarification")
    clarification_question: str | None = Field(default=None, alias="clarificationQuestion")
    candidates: list[EntityCandidate] = Field(default_factory=list)
    resolutions: dict[str, EntityResolution] = Field(default_factory=dict)
    error: str | None = None
    error_code: str | None = Field(default=None, alias="errorCode")
    friendly_message: str | None = Field(default=None, alias="friendlyMessage")
    special_response_category: str | None = Field(default=None, alias="specialResponseCategory")
    neutralized_temporal_filters: list[str] = Field(
        default_factory=list,
        alias="neutralizedTemporalFilters",
    )
    interpreted_summary: str | None = Field(default=None, alias="interpretedSummary")
    referents: ResultReferentContext = Field(default_factory=ResultReferentContext)
    parse_latency_ms: float = Field(default=0, alias="parseLatencyMs")
    entity_resolution_latency_ms: float = Field(default=0, alias="entityResolutionLatencyMs")
    db_latency_ms: float = Field(default=0, alias="dbLatencyMs")
    total_latency_ms: float = Field(default=0, alias="totalLatencyMs")

    @property
    def is_success(self) -> bool:
        return self.search_response is not None and self.error is None and not self.requires_clarification

    @property
    def total_count(self) -> int:
        return self.search_response.total_count if self.search_response else 0


class ConversationalSearchService:
    """Orchestrates multi-turn conversational search:

    1. Parses natural-language queries into structured SearchQuery with SearchContext.
    2. Routes fields deterministically via IntentResolutionRouter.
    3. Resolves entities via DatabaseEntityResolver (PY-2).
    4. Executes database search via SearchRepository (PY-1).
    5. Deterministically extracts referents (ResultReferentContext).
    6. Advances session state via deterministic reducer (SearchConversationSession).
    """

    def __init__(
        self,
        *,
        query_parser: QueryUnderstandingService,
        entity_resolver: DatabaseEntityResolver | None = None,
        repository: SearchRepository | None = None,
        plan_builder: SearchPlanBuilder | None = None,
        router: IntentResolutionRouter | None = None,
    ) -> None:
        self.query_parser = query_parser
        self.entity_resolver = entity_resolver
        self.repository = repository
        self.plan_builder = plan_builder or SearchPlanBuilder()
        self.router = router or IntentResolutionRouter()

    @staticmethod
    def _neutralize_ungrounded_temporal_filters(
        query: SearchQuery,
        raw_text: str,
        session: SearchConversationSession,
    ) -> tuple[SearchQuery, list[str]]:
        """Remove model-added years absent from this turn and committed context."""
        raw_years = {
            int(value)
            for value in re.findall(r"(?<!\d)(?:19|20)\d{2}(?!\d)", raw_text)
        }
        context_years = set(session.active_query.years)
        if session.active_query.year_from is not None:
            context_years.add(session.active_query.year_from)
        if session.active_query.year_to is not None:
            context_years.add(session.active_query.year_to)
        grounded = raw_years | context_years

        kept_years = [year for year in query.years if year in grounded]
        removed = [f"years:{year}" for year in query.years if year not in grounded]
        year_from = query.year_from
        year_to = query.year_to
        if year_from is not None and year_from not in grounded:
            removed.append(f"yearFrom:{year_from}")
            year_from = None
        if year_to is not None and year_to not in grounded:
            removed.append(f"yearTo:{year_to}")
            year_to = None

        if not removed:
            return query, []
        return query.model_copy(update={
            "years": kept_years,
            "year_from": year_from,
            "year_to": year_to,
        }), removed

    @staticmethod
    def _recover_grounded_direct_filters(
        query: SearchQuery,
        raw_text: str,
    ) -> SearchQuery:
        """ACC-2: re-attach direct filters the model dropped but that are
        explicitly grounded in the raw text (known country names, 4-digit years).

        Rules: only ADD, never overwrite correct model values; deduplicate; never
        treat a token as a country when it is part of an already-extracted entity
        phrase; never treat a year embedded in an entity phrase as a filter.
        """
        lowered = raw_text.lower()
        updates: dict[str, Any] = {}

        # Entity phrases already present; used to avoid double-counting tokens
        # that belong to a resolved/extracted entity (e.g. "Rally Ireland").
        entity_blob = " ".join(
            p.lower()
            for p in (
                *query.rally_names, *query.event_names,
                *query.driver_names, *query.stage_names,
            )
        )

        # --- Countries ---
        existing_countries = {c.strip().lower() for c in query.countries}
        recovered_countries: list[str] = []
        # Longer phrases first so "czech republic" wins over "czech".
        for phrase in sorted(_RECOVERABLE_COUNTRIES, key=len, reverse=True):
            if re.search(rf"\b{re.escape(phrase)}\b", lowered) and phrase not in entity_blob:
                canonical = _RECOVERABLE_COUNTRIES[phrase]
                if canonical.lower() not in existing_countries:
                    existing_countries.add(canonical.lower())
                    recovered_countries.append(canonical)
        if recovered_countries:
            updates["countries"] = [*query.countries, *recovered_countries]

        # --- Years --- only recover when the model produced no temporal fields
        # at all, so we never fight edition years or model-provided ranges.
        if not query.years and query.year_from is None and query.year_to is None:
            raw_years = [
                int(v) for v in re.findall(r"(?<!\d)(?:19|20)\d{2}(?!\d)", raw_text)
            ]
            recovered_years: list[int] = []
            for yr in raw_years:
                if str(yr) in entity_blob:
                    continue  # part of an entity phrase (e.g. an edition year)
                if yr not in recovered_years:
                    recovered_years.append(yr)
            if recovered_years:
                updates["years"] = recovered_years

        if not updates:
            return query
        return query.model_copy(update=updates)

    @staticmethod
    def _recover_followup_video_intent(
        query: SearchQuery,
        raw_text: str,
        referents: ResultReferentContext,
    ) -> SearchQuery:
        """ACC-1: correct a model-misclassified follow-up.

        When the model returns SEARCH_RALLIES but the raw text carries a strong
        video/action cue AND the turn is about a specific rally (explicit or the
        active referent), route to SEARCH_VIDEO_ACTIONS. Conservative: broad rally
        discovery like "rallies in Ireland" has no video cue and is untouched.
        """
        if query.intent != SearchIntent.SEARCH_RALLIES:
            return query

        tokens = set(re.findall(r"[a-z]+", raw_text.lower()))
        action_hits = [
            _ACTION_INTENT_CUES[t] for t in tokens if t in _ACTION_INTENT_CUES
        ]
        has_video_cue = bool(tokens & _VIDEO_INTENT_CUES)
        if not action_hits and not has_video_cue and not query.action_types:
            return query

        # Only correct when the query is clearly scoped to a rally, so we never
        # hijack a broad rally search that merely happens to mention a cue word.
        has_rally_subject = bool(query.target_rally_names) or bool(
            referents.active_rally and referents.active_rally.strip()
        )
        if not has_rally_subject:
            return query

        updates: dict[str, Any] = {"intent": SearchIntent.SEARCH_VIDEO_ACTIONS}
        if action_hits and not query.action_types:
            updates["action_types"] = list(dict.fromkeys(action_hits))
        # Scope to the active rally when the model relied on a pronoun ("that
        # rally") and omitted the rally name.
        if not query.target_rally_names and referents.active_rally:
            updates["rally_names"] = [referents.active_rally]
        return query.model_copy(update=updates)

    @staticmethod
    def _apply_referent_fallback(
        query: SearchQuery,
        referents: ResultReferentContext,
    ) -> SearchQuery:
        """ACC-4: before deciding a required subject is missing, fall back to a
        type-compatible active referent (e.g. "who won it?" reuses the active
        rally). A driver referent is never used as a rally, or vice versa.
        """
        updates: dict[str, Any] = {}
        if query.intent in {
            SearchIntent.GET_RALLY_RESULTS,
            SearchIntent.GET_RALLY_TOP_FINISHERS,
        }:
            if (
                not query.target_rally_names
                and not query.stage_names
                and referents.active_rally
                and referents.active_rally.strip()
            ):
                updates["rally_names"] = [referents.active_rally]
        elif query.intent in {
            SearchIntent.SEARCH_DRIVER_RALLIES,
            SearchIntent.SEARCH_DRIVER_WINS,
            SearchIntent.SEARCH_DRIVER_VIDEOS,
        }:
            if not query.driver_names and not query.driver_ids:
                driver = referents.active_driver or referents.last_winner
                if driver and driver.strip():
                    updates["driver_names"] = [driver]
        if not updates:
            return query
        return query.model_copy(update=updates)

    @staticmethod
    def _missing_required_subject(query: SearchQuery) -> str | None:
        if query.intent in {
            SearchIntent.GET_RALLY_RESULTS,
            SearchIntent.GET_RALLY_TOP_FINISHERS,
        } and not query.target_rally_names and not query.stage_names:
            return "Which rally do you mean?"
        if query.intent in {
            SearchIntent.SEARCH_DRIVER_RALLIES,
            SearchIntent.SEARCH_DRIVER_WINS,
            SearchIntent.SEARCH_DRIVER_VIDEOS,
        } and not query.driver_names and not query.driver_ids:
            return "Which driver do you mean?"
        return None

    @staticmethod
    def _reuse_committed_referent_ids(
        query: SearchQuery,
        referents: ResultReferentContext,
    ) -> tuple[SearchQuery, list[str], list[str], list[str], list[str]]:
        """Remove already-canonical session referents from open-set resolution.

        Returns the query to resolve plus trusted rally names and IDs, driver
        names and IDs to restore afterward. This is a PY-4 conversation concern;
        PY-2 scoring remains unchanged.
        """
        trusted_rallies: list[str] = []
        trusted_rally_ids: list[str] = []
        trusted_drivers: list[str] = []
        trusted_driver_ids: list[str] = []
        unresolved_rallies: list[str] = []
        unresolved_drivers: list[str] = []

        for name in query.target_rally_names:
            if (
                referents.active_rally_id
                and referents.active_rally
                and name.casefold() == referents.active_rally.casefold()
            ):
                trusted_rallies.append(name)
                trusted_rally_ids.append(referents.active_rally_id)
            else:
                unresolved_rallies.append(name)

        for name in query.driver_names:
            trusted_id = None
            if (
                referents.active_driver_id
                and referents.active_driver
                and name.casefold() == referents.active_driver.casefold()
            ):
                trusted_id = referents.active_driver_id
            elif (
                referents.last_winner_driver_id
                and referents.last_winner
                and name.casefold() == referents.last_winner.casefold()
            ):
                trusted_id = referents.last_winner_driver_id
            if trusted_id:
                trusted_drivers.append(name)
                trusted_driver_ids.append(trusted_id)
            else:
                unresolved_drivers.append(name)

        resolution_query = query.model_copy(update={
            "rally_names": unresolved_rallies,
            "event_names": [],
            "driver_names": unresolved_drivers,
            "driver_ids": [],
        })
        return resolution_query, trusted_rallies, trusted_rally_ids, trusted_drivers, trusted_driver_ids

    async def search(
        self,
        natural_query: str,
        *,
        session: SearchConversationSession | None = None,
        language: str | None = None,
        current_year: int = 2026,
    ) -> tuple[SearchConversationSession, ConversationalSearchResult]:
        current_session = session or SearchConversationSession()
        started = time.perf_counter()
        clean = natural_query.strip()

        if not clean:
            elapsed = (time.perf_counter() - started) * 1000
            result = ConversationalSearchResult(
                error="Search query cannot be empty",
                error_code="QUERY_PARSE_FAILED",
                friendly_message="Please enter a search query.",
                referents=current_session.referents,
                total_latency_ms=elapsed,
            )
            return current_session, result

        # Dart's client advances generation before dispatch. Non-committing
        # outcomes retain that generation but do not alter query/referents/history.
        request_session = current_session.next_request()

        special = match_special_query(clean)
        if special is not None:
            elapsed = (time.perf_counter() - started) * 1000
            return request_session, ConversationalSearchResult(
                error_code=special.error_code,
                friendly_message=special.message,
                special_response_category=special.category,
                referents=request_session.referents,
                total_latency_ms=elapsed,
            )

        search_context = SearchContext(
            current_year=current_year,
            locale=language,
            language_code=language,
            referents=request_session.referents,
            previous_query=request_session.active_query,
        )

        # Step 1: Query Understanding
        parse_start = time.perf_counter()
        parse_result = await self.query_parser.parse(
            clean,
            language=language,
            context=search_context,
        )
        parse_ms = (time.perf_counter() - parse_start) * 1000

        if parse_result.requires_clarification:
            elapsed = (time.perf_counter() - started) * 1000
            result = ConversationalSearchResult(
                requires_clarification=True,
                clarification_question=parse_result.clarification_question or "Please provide more details.",
                referents=request_session.referents,
                parse_latency_ms=parse_ms,
                total_latency_ms=elapsed,
            )
            return request_session, result

        if not parse_result.succeeded or parse_result.query is None:
            elapsed = (time.perf_counter() - started) * 1000
            result = ConversationalSearchResult(
                error=parse_result.error or "Unable to understand search query",
                error_code="QUERY_PARSE_FAILED",
                friendly_message="Unable to understand search query.",
                referents=request_session.referents,
                parse_latency_ms=parse_ms,
                total_latency_ms=elapsed,
            )
            return request_session, result

        parsed_query, neutralized_temporal_filters = self._neutralize_ungrounded_temporal_filters(
            parse_result.query,
            clean,
            request_session,
        )
        # ACC-2: re-attach direct filters the model dropped but are grounded in
        # the raw text (known countries, explicit years).
        parsed_query = self._recover_grounded_direct_filters(parsed_query, clean)
        # ACC-1: correct a follow-up the model misclassified as SEARCH_RALLIES
        # when it is clearly a video/action request about the active rally.
        parsed_query = self._recover_followup_video_intent(
            parsed_query, clean, request_session.referents
        )
        # ACC-4: reuse a type-compatible active referent before deciding a
        # required subject is missing.
        parsed_query = self._apply_referent_fallback(
            parsed_query, request_session.referents
        )
        missing_subject_question = self._missing_required_subject(parsed_query)
        if missing_subject_question is not None:
            elapsed = (time.perf_counter() - started) * 1000
            return request_session, ConversationalSearchResult(
                parsed_query=parsed_query,
                requires_clarification=True,
                clarification_question=missing_subject_question,
                neutralized_temporal_filters=neutralized_temporal_filters,
                referents=request_session.referents,
                parse_latency_ms=parse_ms,
                total_latency_ms=elapsed,
            )
        resolved_query = parsed_query
        candidates: list[EntityCandidate] = []
        resolutions: dict[str, EntityResolution] = {}
        er_ms = 0.0
        trusted_rally_ids: list[str] = []

        # Step 2: Intent & Resolution Routing
        routing_plan = self.router.route(parsed_query, raw_text=clean)
        search_context.extra["routing_plan"] = routing_plan
        search_context.extra["unresolved_mentions"] = routing_plan.unresolved_text_mentions

        # Materialize typed residual recovery into the same structured fields
        # used by explicit QU output. This keeps resolver lookup type aligned
        # with the router instead of implicitly treating every residual as a rally.
        residual_updates: dict[str, list[str]] = {}
        for route in routing_plan.entity_routes:
            if route.field_name != "unresolved_text":
                continue
            if route.entity_type == SearchEntityType.PERSON:
                residual_updates.setdefault("driver_names", []).append(str(route.raw_value))
            elif route.entity_type == SearchEntityType.RALLY:
                residual_updates.setdefault("rally_names", []).append(str(route.raw_value))
            elif route.entity_type == SearchEntityType.STAGE:
                residual_updates.setdefault("stage_names", []).append(str(route.raw_value))
            elif route.entity_type == SearchEntityType.UPLOADER:
                residual_updates.setdefault("uploaders", []).append(str(route.raw_value))
        if residual_updates:
            parsed_query = parsed_query.model_copy(update={
                field: [*getattr(parsed_query, field), *values]
                for field, values in residual_updates.items()
            })
        ambiguous_residuals = [
            str(route.raw_value)
            for route in routing_plan.entity_routes
            if route.field_name == "unresolved_text" and route.entity_type is None
        ]
        if ambiguous_residuals:
            elapsed = (time.perf_counter() - started) * 1000
            return request_session, ConversationalSearchResult(
                parsed_query=parsed_query,
                routing_plan=routing_plan,
                requires_clarification=True,
                clarification_question=(
                    f'Is "{ambiguous_residuals[0]}" a rally, person, stage, or uploader?'
                ),
                neutralized_temporal_filters=neutralized_temporal_filters,
                referents=request_session.referents,
                parse_latency_ms=parse_ms,
                total_latency_ms=elapsed,
            )

        # Step 3: Deterministic Entity Resolution
        if self.entity_resolver is not None:
            er_start = time.perf_counter()
            resolution_query, trusted_rallies, trusted_rally_ids, trusted_drivers, trusted_driver_ids = (
                self._reuse_committed_referent_ids(parsed_query, request_session.referents)
            )
            resolution_result = await self.entity_resolver.resolve(
                resolution_query,
                context=search_context,
            )
            er_ms = (time.perf_counter() - er_start) * 1000
            candidates = resolution_result.candidates
            resolutions = resolution_result.resolutions

            if resolution_result.requires_clarification:
                elapsed = (time.perf_counter() - started) * 1000
                result = ConversationalSearchResult(
                    parsed_query=parsed_query,
                    routing_plan=routing_plan,
                    requires_clarification=True,
                    clarification_question=resolution_result.clarification_question or "Please clarify the entity.",
                    candidates=candidates,
                    resolutions=resolutions,
                    referents=request_session.referents,
                    parse_latency_ms=parse_ms,
                    entity_resolution_latency_ms=er_ms,
                    total_latency_ms=elapsed,
                )
                return request_session, result

            if resolution_result.error:
                elapsed = (time.perf_counter() - started) * 1000
                result = ConversationalSearchResult(
                    parsed_query=parsed_query,
                    routing_plan=routing_plan,
                    error=resolution_result.error,
                    error_code="ENTITY_RESOLUTION_FAILED",
                    referents=request_session.referents,
                    parse_latency_ms=parse_ms,
                    entity_resolution_latency_ms=er_ms,
                    total_latency_ms=elapsed,
                )
                return request_session, result

            resolved_query = resolution_result.resolved_query or resolution_query
            resolved_query = resolved_query.model_copy(update={
                "rally_names": [*trusted_rallies, *resolved_query.rally_names],
                "event_names": [*trusted_rallies, *resolved_query.event_names],
                "driver_names": [*trusted_drivers, *resolved_query.driver_names],
                "driver_ids": [*trusted_driver_ids, *resolved_query.driver_ids],
            })

        # Step 4: Deterministic SearchPlan Compilation & Validation
        try:
            search_plan = self.plan_builder.build(resolved_query, resolutions=resolutions)
            if trusted_rally_ids:
                search_plan = search_plan.model_copy(update={
                    "event_ids": [*trusted_rally_ids, *search_plan.event_ids],
                })
        except UnresolvedEntityError as exc:
            elapsed = (time.perf_counter() - started) * 1000
            result = ConversationalSearchResult(
                parsed_query=parsed_query,
                resolved_query=resolved_query,
                routing_plan=routing_plan,
                error=str(exc),
                error_code="UNRESOLVED_ENTITY",
                friendly_message="We couldn't resolve the entity mentioned in your query.",
                referents=request_session.referents,
                candidates=candidates,
                resolutions=resolutions,
                parse_latency_ms=parse_ms,
                entity_resolution_latency_ms=er_ms,
                total_latency_ms=elapsed,
            )
            return request_session, result
        except SearchPlanError as exc:
            elapsed = (time.perf_counter() - started) * 1000
            result = ConversationalSearchResult(
                parsed_query=parsed_query,
                resolved_query=resolved_query,
                routing_plan=routing_plan,
                error=str(exc),
                error_code="INVALID_SEARCH_PLAN",
                friendly_message="Invalid search parameters.",
                referents=request_session.referents,
                candidates=candidates,
                resolutions=resolutions,
                parse_latency_ms=parse_ms,
                entity_resolution_latency_ms=er_ms,
                total_latency_ms=elapsed,
            )
            return request_session, result

        # Step 5: Deterministic Database Search via SearchPlan
        db_ms = 0.0
        search_response: SearchResponse | None = None
        if self.repository is not None:
            db_start = time.perf_counter()
            try:
                search_response = await self.repository.search(search_plan)
                db_ms = (time.perf_counter() - db_start) * 1000
            except Exception as exc:
                elapsed = (time.perf_counter() - started) * 1000
                result = ConversationalSearchResult(
                    parsed_query=parsed_query,
                    resolved_query=resolved_query,
                    routing_plan=routing_plan,
                    search_plan=search_plan,
                    error=f"Database execution error: {exc}",
                    error_code="DATABASE_ERROR",
                    friendly_message="Database execution error.",
                    referents=request_session.referents,
                    parse_latency_ms=parse_ms,
                    entity_resolution_latency_ms=er_ms,
                    total_latency_ms=elapsed,
                )
                return request_session, result
        else:
            search_response = SearchResponse(
                intent=search_plan.intent,
                results=[],
                total_count=0,
                has_more=False,
                limit=search_plan.limit,
                offset=search_plan.offset,
            )

        # Step 6: Interpret Summary and Referents
        summary = generate_interpreted_summary(resolved_query)
        derived_referents = ResultReferentContext.from_search_response(
            search_response,
            previous=request_session.referents,
            query_rally=resolved_query.target_rally_name,
            query_driver=resolved_query.driver_name,
            query_rallies=resolved_query.target_rally_names,
            query_drivers=resolved_query.driver_names,
            query_driver_ids=resolved_query.driver_ids,
            query_rally_ids=trusted_rally_ids,
            query_person_role=resolved_query.person_role,
        )

        # Step 7: Advance State Machine via Pure Reducer
        updated_session = reduce_turn(
            request_session,
            query=resolved_query,
            referents=derived_referents,
            title=clean,
            response=search_response,
            interpreted_summary=summary,
        )

        elapsed = (time.perf_counter() - started) * 1000
        result = ConversationalSearchResult(
            parsed_query=parsed_query,
            resolved_query=resolved_query,
            routing_plan=routing_plan,
            search_plan=search_plan,
            search_response=search_response,
            candidates=candidates,
            interpreted_summary=summary,
            referents=derived_referents,
            resolutions=resolutions,
            neutralized_temporal_filters=neutralized_temporal_filters,
            parse_latency_ms=parse_ms,
            entity_resolution_latency_ms=er_ms,
            db_latency_ms=db_ms,
            total_latency_ms=elapsed,
        )
        return updated_session, result
