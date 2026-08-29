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
from ..entity_search.models import EntityCandidate, EntityResolution
from ..entity_search.resolver import DatabaseEntityResolver
from ..query_understanding.context import SearchContext
from ..query_understanding.service import QueryUnderstandingService
from ..repositories.search_repository import SearchRepository
from .search_plan_builder import SearchPlanBuilder, SearchPlanError, UnresolvedEntityError
from .special_query import match_special_query


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
    ) -> tuple[SearchQuery, list[str], list[str], list[str]]:
        """Remove already-canonical session referents from open-set resolution.

        Returns the query to resolve plus trusted rally names, driver names and
        driver IDs to restore afterward. This is a PY-4 conversation concern;
        PY-2 scoring remains unchanged.
        """
        trusted_rallies: list[str] = []
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
        return resolution_query, trusted_rallies, trusted_drivers, trusted_driver_ids

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

        # Step 2: Intent & Resolution Routing
        routing_plan = self.router.route(parsed_query, raw_text=clean)
        search_context.extra["routing_plan"] = routing_plan
        search_context.extra["unresolved_mentions"] = routing_plan.unresolved_text_mentions

        # Step 3: Deterministic Entity Resolution
        if self.entity_resolver is not None:
            er_start = time.perf_counter()
            resolution_query, trusted_rallies, trusted_drivers, trusted_driver_ids = (
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
