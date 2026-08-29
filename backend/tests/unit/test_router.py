import pytest
from app.domain.router import IntentResolutionRouter, ResolutionRouteType
from app.domain.search_intent import SearchIntent
from app.domain.search_query import MatchMode, PersonRole, SearchQuery
from app.entity_search.models import SearchEntityType


def test_router_direct_filters():
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        countries=["Ireland"],
        years=[2025],
        year_from=2020,
        year_to=2026,
        stage_numbers=["SS1"],
        action_types=["jump"],
    )
    plan = router.route(query, raw_text="Rallies in Ireland in 2025")

    assert not plan.needs_entity_resolution
    assert len(plan.direct_filter_routes) == 6
    assert len(plan.entity_routes) == 0

    route_fields = {r.field_name: r.raw_value for r in plan.direct_filter_routes}
    assert route_fields["countries"] == "Ireland"
    assert route_fields["years"] == 2025
    assert route_fields["year_from"] == 2020
    assert route_fields["year_to"] == 2026
    assert route_fields["stage_numbers"] == "SS1"
    assert route_fields["action_types"] == "jump"


def test_router_entity_fields():
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
        rally_names=["Rally Aluksne"],
        driver_names=["Max Freeman"],
        stage_names=["SS3"],
        uploaders=["pineamite"],
        person_role=PersonRole.DRIVER,
    )
    plan = router.route(query, raw_text="videos of Max Freeman at Rally Aluksne SS3 by pineamite")

    assert plan.needs_entity_resolution
    assert len(plan.entity_routes) == 4

    entity_types = {r.field_name: r.entity_type for r in plan.entity_routes}
    assert entity_types["rally_names"] == SearchEntityType.RALLY
    assert entity_types["driver_names"] == SearchEntityType.PERSON
    assert entity_types["stage_names"] == SearchEntityType.STAGE
    assert entity_types["uploaders"] == SearchEntityType.UPLOADER


def test_router_empty_entity_recovery_for_residual_text():
    router = IntentResolutionRouter()
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES)
    plan = router.route(query, raw_text="aluqsne")

    assert plan.needs_entity_resolution
    assert "aluqsne" in plan.unresolved_text_mentions
    recovery_routes = [r for r in plan.entity_routes if r.field_name == "unresolved_text"]
    assert len(recovery_routes) == 1
    assert recovery_routes[0].raw_value == "aluqsne"
    assert recovery_routes[0].entity_type == SearchEntityType.RALLY


def test_router_no_recovery_for_pure_filter_queries():
    router = IntentResolutionRouter()
    
    # Rallies in Ireland
    q_ireland = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Ireland"])
    plan_ireland = router.route(q_ireland, raw_text="Rallies in Ireland")
    assert not plan_ireland.needs_entity_resolution
    assert len(plan_ireland.unresolved_text_mentions) == 0

    # Rallies in 2025
    q_2025 = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, years=[2025])
    plan_2025 = router.route(q_2025, raw_text="Rallies in 2025")
    assert not plan_2025.needs_entity_resolution
    assert len(plan_2025.unresolved_text_mentions) == 0


def test_router_city_routed_for_entity_validation():
    router = IntentResolutionRouter()
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, cities=["aluksnay"])
    plan = router.route(query, raw_text="aluksnay")

    assert plan.needs_entity_resolution
    city_routes = [r for r in plan.routes if r.field_name == "cities"]
    assert len(city_routes) == 1
    assert city_routes[0].route_type == ResolutionRouteType.ENTITY
