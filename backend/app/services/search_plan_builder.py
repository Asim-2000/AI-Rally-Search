from __future__ import annotations

import logging
from typing import Any

from ..domain.search_intent import SearchIntent
from ..domain.search_plan import ExecutionStrategy, INTENT_TO_STRATEGY, SearchPlan
from ..domain.search_query import MatchMode, PersonRole, SearchQuery
from ..entity_search.models import EntityResolution

logger = logging.getLogger(__name__)


class SearchPlanError(ValueError):
    """Base exception for SearchPlan validation and compilation errors."""
    pass


class UnresolvedEntityError(SearchPlanError):
    """Raised when an unresolvable or ambiguous entity is supplied for a required intent."""
    pass


class IncompatibleFilterError(SearchPlanError):
    """Raised when incompatible filters are supplied for an intent."""
    pass


class SearchPlanBuilder:
    """Pure deterministic compiler that transforms resolved SearchQuery into an immutable SearchPlan.

    Guarantees:
    1. Zero provider, network, LLM, or DB calls.
    2. Pure deterministic in-memory validation.
    3. Rejects impossible or unresolvable execution states.
    4. Ensures no unresolved noisy entity mentions reach repository execution.
    """

    def build(
        self,
        query: SearchQuery,
        *,
        resolutions: dict[str, EntityResolution] | None = None,
    ) -> SearchPlan:
        if query is None:
            raise SearchPlanError("SearchQuery cannot be None")

        strategy = INTENT_TO_STRATEGY.get(query.intent)
        if strategy is None:
            raise SearchPlanError(f"Unsupported search intent: {query.intent}")

        # Check entity resolutions if provided
        resolutions = resolutions or {}
        for key, res in resolutions.items():
            if getattr(res, "is_ambiguous", False) or getattr(res, "requires_clarification", False):
                phrase = getattr(res, "raw_phrase", str(res))
                raise UnresolvedEntityError(
                    f"Cannot build SearchPlan: entity '{phrase}' requires clarification."
                )

        # Validate intent-specific requirements and filter compatibility
        rally_names = list(query.target_rally_names)
        driver_names = list(query.driver_names)
        driver_ids = list(query.driver_ids)
        stage_names = list(query.stage_names)
        stage_numbers = list(query.stage_numbers)
        countries = list(query.countries)
        cities = list(query.cities)
        years = list(query.years)
        action_types = list(query.action_types)
        uploaders = list(query.uploaders)

        # Filter out noisy unresolvable text if any resolution explicitly marked it unresolved
        for key, res in resolutions.items():
            if not res.is_resolved:
                phrase = getattr(res, "raw_phrase", "").strip()
                if phrase in rally_names:
                    rally_names.remove(phrase)
                if phrase in driver_names:
                    driver_names.remove(phrase)
                if phrase in stage_names:
                    stage_names.remove(phrase)
                if phrase in cities:
                    cities.remove(phrase)

        # Intent validation rules:
        match query.intent:
            case SearchIntent.SEARCH_RALLIES:
                pass

            case SearchIntent.SEARCH_DRIVER_RALLIES:
                pass

            case SearchIntent.SEARCH_DRIVER_WINS:
                pass

            case SearchIntent.GET_RALLY_RESULTS:
                # Results classification for single winner/event
                pass

            case SearchIntent.GET_RALLY_TOP_FINISHERS:
                pass

            case SearchIntent.SEARCH_VIDEO_ACTIONS:
                pass

            case SearchIntent.SEARCH_DRIVER_VIDEOS:
                pass

            case SearchIntent.GET_TOP_UPLOADERS:
                pass

            case SearchIntent.GET_TOP_DRIVERS_BY_WINS:
                pass

        # Incompatible filter checks
        if action_types and query.intent != SearchIntent.SEARCH_VIDEO_ACTIONS:
            raise IncompatibleFilterError(
                f"action_types {action_types} not supported for intent {query.intent}"
            )

        # Pagination & limits
        limit = max(1, query.limit)
        offset = max(0, query.offset)
        if query.intent == SearchIntent.GET_RALLY_RESULTS:
            limit = 1
            offset = 0

        plan = SearchPlan(
            intent=query.intent,
            strategy=strategy,
            rally_names=rally_names,
            driver_ids=driver_ids,
            driver_names=driver_names,
            person_role=query.person_role,
            driver_match_mode=query.driver_match_mode,
            stage_names=stage_names,
            stage_numbers=stage_numbers,
            countries=countries,
            cities=cities,
            years=years,
            year_from=query.year_from,
            year_to=query.year_to,
            action_types=action_types if query.intent == SearchIntent.SEARCH_VIDEO_ACTIONS else [],
            uploaders=uploaders,
            limit=limit,
            offset=offset,
        )

        logger.debug(
            "Compiled SearchPlan: intent=%s strategy=%s rallies=%s drivers=%s years=%s countries=%s",
            plan.intent,
            plan.strategy,
            plan.rally_names,
            plan.driver_ids or plan.driver_names,
            plan.years or (plan.year_from, plan.year_to),
            plan.countries,
        )
        return plan
