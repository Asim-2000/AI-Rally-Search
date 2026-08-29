from __future__ import annotations

import pytest
from app.domain.router import IntentResolutionRouter, ResolutionRouteType
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery


def test_router_filters_country_phrases_without_false_residuals():
    router = IntentResolutionRouter()

    test_cases = [
        ("Rallies held in Afghanistan", SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Afghanistan"])),
        ("Rallies held in Andorra", SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Andorra"])),
        ("Rallies held in Argentina", SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Argentina"])),
        ("Rallies taking place in Ireland", SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Ireland"])),
        ("Show crash clips featuring Aaron Maxwell", SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, driver_names=["Aaron Maxwell"], action_types=["crash"])),
        ("Rallies where Aaron Browne competed", SearchQuery(intent=SearchIntent.SEARCH_DRIVER_RALLIES, driver_names=["Aaron Browne"])),
    ]

    for raw_text, sq in test_cases:
        plan = router.route(sq, raw_text=raw_text)
        assert len(plan.unexplained_tokens) == 0, f"Failed for '{raw_text}': got unexplained tokens {plan.unexplained_tokens}"
        assert not any(r.field_name == "unresolved_text" for r in plan.routes), f"Unexpected unresolved_text route for '{raw_text}'"
