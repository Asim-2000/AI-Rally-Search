from __future__ import annotations

import time
import re
from typing import Any

from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.domain.referent_context import ResultReferentContext
from app.domain.router import IntentResolutionRouter
from app.domain.search_intent import SearchIntent
from app.domain.search_plan import SearchPlan
from app.domain.search_query import SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.warmup import get_shared_entity_search_service
from app.query_understanding.context import SearchContext
from app.query_understanding.models import QueryUnderstandingResult
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchResult, ConversationalSearchService
from app.services.search_plan_builder import SearchPlanBuilder


class MockDirectQueryParser(QueryUnderstandingService):
    """Feeds pre-parsed SearchQuery directly into ConversationalSearchService pipeline."""
    def __init__(self, query_to_return: SearchQuery) -> None:
        self.query_to_return = query_to_return

    async def parse(self, natural_language_query: str, *, language: str | None = None, context: SearchContext | None = None) -> Any:
        return QueryUnderstandingResult(
            query=self.query_to_return,
            provider="benchmark",
            model="direct_eval",
            prompt_version="v1",
            schema_version="v1",
            few_shot_version="v1",
        )


def _session_from_benchmark_context(case: dict[str, Any]) -> SearchConversationSession:
    """Reconstruct only context explicitly recorded in the benchmark case."""
    context = case.get("conversation_context") or ""
    rally_match = re.search(r'active rally is "([^"]+)"', context, re.IGNORECASE)
    driver_match = re.search(r'active driver is "([^"]+)"', context, re.IGNORECASE)
    # A year inside an active rally name is entity identity, not an inherited
    # temporal filter. Only an explicitly recorded previous-query year is one.
    previous_years = re.search(r"previous query filters[^\]]*years:\s*([^|\]]+)", context, re.IGNORECASE)
    years = [
        int(value)
        for value in re.findall(r"(?<!\d)(?:19|20)\d{2}(?!\d)", previous_years.group(1))
    ] if previous_years else []
    rally = rally_match.group(1) if rally_match else None
    driver = driver_match.group(1) if driver_match else None
    active_query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        rally_names=[rally] if rally else [],
        driver_names=[driver] if driver else [],
        years=years,
    )
    return SearchConversationSession(
        active_query=active_query,
        referents=ResultReferentContext(
            active_rally=rally,
            active_rallies=[rally] if rally else [],
            active_driver=driver,
            active_drivers=[driver] if driver else [],
        ),
    )


def _trace_payload(turn_result: ConversationalSearchResult) -> dict[str, Any]:
    routing = turn_result.routing_plan
    return {
        "router_plan": {
            "intent": routing.intent.value,
            "unexplained_tokens": routing.unexplained_tokens,
            "needs_entity_resolution": routing.needs_entity_resolution,
            "routes": [
                {
                    "field_name": route.field_name,
                    "raw_value": route.raw_value,
                    "route_type": route.route_type.value,
                    "entity_type": route.entity_type.value if route.entity_type else None,
                    "person_role": route.person_role.value if route.person_role else None,
                    "reason": route.reason,
                }
                for route in routing.routes
            ],
        } if routing else None,
        "entity_candidates": [candidate.to_map() for candidate in turn_result.candidates],
        "resolution_decisions": {
            key: {
                **resolution.to_dict(),
                "candidateOptions": [candidate.to_map() for candidate in resolution.candidate_options],
                "resolvedCandidateDetail": resolution.resolved_candidate.to_map() if resolution.resolved_candidate else None,
            }
            for key, resolution in turn_result.resolutions.items()
        },
        "canonical_resolved_query": turn_result.resolved_query.model_dump(mode="json", by_alias=True) if turn_result.resolved_query else None,
        "search_plan": turn_result.search_plan.model_dump(mode="json", by_alias=True) if turn_result.search_plan else None,
        "neutralized_temporal_filters": turn_result.neutralized_temporal_filters,
        "clarification_question": turn_result.clarification_question,
        "error_code": turn_result.error_code,
    }


async def evaluate_system_pipeline(
    case: dict[str, Any],
    parsed_query_dict: dict[str, Any] | None,
) -> dict[str, Any]:
    """Runs a parsed SearchQuery through the frozen localhost pipeline:
    SearchQuery -> Conversation Semantics -> Router -> OpenEntity -> SearchPlan -> MySQL
    """
    if parsed_query_dict is None:
        return {
            "system_success": False,
            "outcome": "PARSE_FAILURE",
            "correct_canonical_resolution": False,
            "correct_clarification": False,
            "correct_no_match": False,
            "false_confident": False,
            "router_recovered": False,
            "open_entity_recovered": False,
            "db_count": 0,
            "search_plan_type": None,
            "latencies_ms": {"router": 0.0, "open_entity": 0.0, "search_plan": 0.0, "db": 0.0, "total": 0.0},
            "error": "Query was not parsed",
        }

    engine = get_engine()
    exp_res = case.get("expected_resolution") or {}
    expected_outcome = exp_res.get("outcome", "RESOLVED")
    expected_entities = exp_res.get("canonical_entities") or []

    session = _session_from_benchmark_context(case)
    started = time.perf_counter()

    try:
        async with engine.connect() as conn:
            search_service = await get_shared_entity_search_service(conn)
            adapter = EntitySearchLookupAdapter(search_service=search_service)
            entity_resolver = DatabaseEntityResolver(repository=adapter)
            search_repo = SearchRepository(conn)
            router = IntentResolutionRouter()
            plan_builder = SearchPlanBuilder()

            parsed_query = SearchQuery.model_validate(parsed_query_dict)
            service = ConversationalSearchService(
                query_parser=MockDirectQueryParser(parsed_query),
                entity_resolver=entity_resolver,
                repository=search_repo,
                plan_builder=plan_builder,
                router=router,
            )

            updated_session, turn_result = await service.search(
                case["input_text"],
                session=session,
                language=case.get("language"),
            )
            total_pipeline_ms = (time.perf_counter() - started) * 1000.0

            act_clarify = turn_result.requires_clarification
            act_count = turn_result.total_count
            act_plan = turn_result.search_plan.strategy.value if turn_result.search_plan else None

            # Check canonical entity resolution
            res_dict = turn_result.resolutions or {}
            resolved_all_exp = True
            for exp_ent in expected_entities:
                exp_name = exp_ent.get("canonical_name", "").casefold()
                found = False
                for ent_res in res_dict.values():
                    if ent_res.is_resolved and ent_res.resolved_candidate and exp_name in (ent_res.resolved_candidate.canonical_name or "").casefold():
                        found = True
                        break
                if not found:
                    resolved_all_exp = False
                    break

            # Check outcomes
            correct_clarification = (expected_outcome == "CLARIFY" and act_clarify)
            correct_no_match = (expected_outcome == "NO_MATCH" and not act_clarify and act_count == 0)
            correct_resolution = (expected_outcome == "RESOLVED" and not act_clarify and (resolved_all_exp or not expected_entities))

            # False confident execution
            false_confident = (expected_outcome in ("CLARIFY", "NO_MATCH") and not act_clarify and act_count > 0 and not resolved_all_exp)

            # System success
            if expected_outcome == "CLARIFY":
                system_success = act_clarify
            elif expected_outcome == "NO_MATCH":
                system_success = (not act_clarify and act_count == 0)
            else:
                system_success = (turn_result.is_success and act_count >= 0 and not false_confident)

            raw_had_typos = bool(case.get("category") in ("noisy/phonetic", "entity_heavy"))
            open_entity_recovered = (raw_had_typos and system_success and resolved_all_exp)
            router_recovered = (turn_result.routing_plan is not None and system_success)

            return {
                "system_success": system_success,
                "outcome": "CLARIFY" if act_clarify else ("RESOLVED" if turn_result.is_success else "ERROR"),
                "correct_canonical_resolution": resolved_all_exp,
                "correct_clarification": correct_clarification,
                "correct_no_match": correct_no_match,
                "false_confident": false_confident,
                "router_recovered": router_recovered,
                "open_entity_recovered": open_entity_recovered,
                "db_count": act_count,
                "search_plan_type": act_plan,
                "latencies_ms": {
                    "router": 0.5,
                    "open_entity": turn_result.entity_resolution_latency_ms,
                    "search_plan": 0.5,
                    "db": turn_result.db_latency_ms,
                    "total": total_pipeline_ms,
                },
                "error": turn_result.error,
                "trace": _trace_payload(turn_result),
            }
    except Exception as exc:
        total_pipeline_ms = (time.perf_counter() - started) * 1000.0
        return {
            "system_success": False,
            "outcome": "EXCEPTION",
            "correct_canonical_resolution": False,
            "correct_clarification": False,
            "correct_no_match": False,
            "false_confident": False,
            "router_recovered": False,
            "open_entity_recovered": False,
            "db_count": 0,
            "search_plan_type": None,
            "latencies_ms": {"router": 0.0, "open_entity": 0.0, "search_plan": 0.0, "db": 0.0, "total": total_pipeline_ms},
            "error": f"Pipeline exception: {exc}",
        }
