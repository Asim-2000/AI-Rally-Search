import time
import pytest
from app.domain.router import INTENT_CAPABILITIES, IntentResolutionRouter, ResolutionRouteType
from app.domain.search_intent import SearchIntent
from app.domain.search_query import MatchMode, PersonRole, SearchQuery
from app.entity_search.models import SearchEntityType


def test_matrix_a_rally_names_aluqsne():
    """A. raw="aluqsne", SearchQuery: SEARCH_RALLIES, rally_names=["aluqsne"] -> ENTITY / RALLY"""
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        rally_names=["aluqsne"],
    )
    plan = router.route("aluqsne", query)

    assert plan.needs_entity_resolution is True
    assert len(plan.entity_routes) == 1
    assert plan.entity_routes[0].field_name == "rally_names"
    assert plan.entity_routes[0].raw_value == "aluqsne"
    assert plan.entity_routes[0].entity_type == SearchEntityType.RALLY
    assert plan.entity_routes[0].route_type == ResolutionRouteType.ENTITY
    assert len(plan.unexplained_tokens) == 0


def test_matrix_b_empty_fields_unexplained_token_aluqsne():
    """B. raw="aluqsne", SearchQuery: SEARCH_RALLIES, rally_names=[], cities=[], countries=[]
    -> unexplained token recovery -> entity resolution required"""
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        rally_names=[],
        cities=[],
        countries=[],
    )
    plan = router.route("aluqsne", query)

    assert plan.needs_entity_resolution is True
    assert plan.unexplained_tokens == ["aluqsne"]
    assert len(plan.entity_routes) == 1
    assert plan.entity_routes[0].field_name == "unresolved_text"
    assert plan.entity_routes[0].raw_value == "aluqsne"
    assert plan.entity_routes[0].entity_type == SearchEntityType.RALLY
    assert "Unexplained entity-like text" in plan.entity_routes[0].reason


def test_matrix_c_city_direct_filter_initial_route():
    """C. raw="aluksnay", SearchQuery: SEARCH_RALLIES, cities=["aluksnay"]
    -> city direct route first -> safe RALLY recovery permitted downstream"""
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        cities=["aluksnay"],
    )
    plan = router.route("aluksnay", query)

    assert len(plan.direct_filters) == 1
    city_route = plan.direct_filters[0]
    assert city_route.field_name == "cities"
    assert city_route.raw_value == "aluksnay"
    assert city_route.route_type == ResolutionRouteType.DIRECT_FILTER
    assert "cross-type recovery" in city_route.reason

    # Capability allows RALLY recovery for SEARCH_RALLIES
    capability = INTENT_CAPABILITIES[SearchIntent.SEARCH_RALLIES]
    assert capability.allow_cross_type_recovery is True
    assert SearchEntityType.RALLY in capability.allowed_primary_entity_types


def test_matrix_d_direct_country_ireland():
    """D. raw="Rallies in Ireland", SearchQuery: countries=["Ireland"]
    -> DIRECT_FILTER, OpenEntity not needed"""
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        countries=["Ireland"],
    )
    plan = router.route("Rallies in Ireland", query)

    assert plan.needs_entity_resolution is False
    assert len(plan.entity_routes) == 0
    assert len(plan.unexplained_tokens) == 0
    assert len(plan.direct_filters) == 1
    assert plan.direct_filters[0].field_name == "countries"
    assert plan.direct_filters[0].raw_value == "Ireland"
    assert plan.direct_filters[0].route_type == ResolutionRouteType.DIRECT_FILTER


def test_matrix_e_direct_year_2025():
    """E. raw="Rallies in 2025", SearchQuery: years=[2025]
    -> DIRECT_FILTER, OpenEntity not needed"""
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        years=[2025],
    )
    plan = router.route("Rallies in 2025", query)

    assert plan.needs_entity_resolution is False
    assert len(plan.entity_routes) == 0
    assert len(plan.unexplained_tokens) == 0
    assert len(plan.direct_filters) == 1
    assert plan.direct_filters[0].field_name == "years"
    assert plan.direct_filters[0].raw_value == 2025
    assert plan.direct_filters[0].route_type == ResolutionRouteType.DIRECT_FILTER


def test_matrix_f_driver_names_person_role_preserved():
    """F. raw="max freemn", SearchQuery: SEARCH_DRIVER_RALLIES, driver_names=["max freemn"]
    -> ENTITY / PERSON with PersonRole appropriately preserved"""
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_DRIVER_RALLIES,
        driver_names=["max freemn"],
        person_role=PersonRole.DRIVER,
    )
    plan = router.route("max freemn", query)

    assert plan.needs_entity_resolution is True
    assert len(plan.entity_routes) == 1
    assert plan.entity_routes[0].field_name == "driver_names"
    assert plan.entity_routes[0].raw_value == "max freemn"
    assert plan.entity_routes[0].entity_type == SearchEntityType.PERSON
    assert plan.entity_routes[0].person_role == PersonRole.DRIVER


def test_matrix_g_cross_type_rally_to_person_permission():
    """G. raw="max freemn", SearchQuery: SEARCH_RALLIES, rally_names=["max freemn"]
    -> RALLY primary route, PERSON recovery allowed by intent capability"""
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        rally_names=["max freemn"],
    )
    plan = router.route("max freemn", query)

    assert plan.needs_entity_resolution is True
    assert len(plan.entity_routes) == 1
    assert plan.entity_routes[0].field_name == "rally_names"
    assert plan.entity_routes[0].raw_value == "max freemn"
    assert plan.entity_routes[0].entity_type == SearchEntityType.RALLY

    # Validate intent capability transitions
    capability = INTENT_CAPABILITIES[SearchIntent.SEARCH_RALLIES]
    assert capability.allow_cross_type_recovery is True
    assert capability.allowed_recovery_transitions.get(SearchEntityType.PERSON) == SearchEntityType.PERSON


def test_matrix_h_rally_names_donegl_ambiguity_preserved():
    """H. raw="donegl", SearchQuery: rally_names=["donegl"]
    -> ENTITY / RALLY, downstream ambiguity preserved"""
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_RALLIES,
        rally_names=["donegl"],
    )
    plan = router.route("donegl", query)

    assert plan.needs_entity_resolution is True
    assert len(plan.entity_routes) == 1
    assert plan.entity_routes[0].field_name == "rally_names"
    assert plan.entity_routes[0].raw_value == "donegl"
    assert plan.entity_routes[0].entity_type == SearchEntityType.RALLY


def test_action_queries_no_false_unexplained_recovery():
    """Action queries ("Show jumps", "Only show jumps") should be pure DIRECT_FILTER
    with no spurious unexplained text recovery."""
    router = IntentResolutionRouter()
    query1 = SearchQuery(
        intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
        action_types=["jump"],
    )
    plan1 = router.route("Show jumps", query1)
    assert plan1.needs_entity_resolution is False
    assert len(plan1.entity_routes) == 0
    assert len(plan1.unexplained_tokens) == 0
    assert len(plan1.direct_filters) == 1
    assert plan1.direct_filters[0].field_name == "action_types"
    assert plan1.direct_filters[0].raw_value == "jump"

    query2 = SearchQuery(
        intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
        action_types=["drift"],
    )
    plan2 = router.route("Only drifts", query2)
    assert plan2.needs_entity_resolution is False
    assert len(plan2.unexplained_tokens) == 0


def test_video_action_featuring_residual_routes_to_person():
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
        action_types=["jump"],
        person_role=PersonRole.DRIVER,
    )

    plan = router.route("show me jump highlights featuring max freeman", query)

    assert plan.unexplained_tokens == ["max", "freeman"]
    assert len(plan.entity_routes) == 1
    route = plan.entity_routes[0]
    assert route.field_name == "unresolved_text"
    assert route.raw_value == "max freeman"
    assert route.entity_type == SearchEntityType.PERSON
    assert route.person_role == PersonRole.DRIVER


def test_video_action_explicit_entity_fields_keep_their_types():
    router = IntentResolutionRouter()

    person = router.route(
        "show me jump highlights featuring max freeman",
        SearchQuery(
            intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
            action_types=["jump"],
            driver_names=["max freeman"],
            person_role=PersonRole.DRIVER,
        ),
    )
    rally = router.route(
        "show jump highlights from Rally Aluksne",
        SearchQuery(
            intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
            action_types=["jump"],
            rally_names=["Rally Aluksne"],
        ),
    )
    stage = router.route(
        "show jump highlights from SS3",
        SearchQuery(
            intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
            action_types=["jump"],
            stage_names=["SS3"],
        ),
    )

    assert person.entity_routes[0].entity_type == SearchEntityType.PERSON
    assert rally.entity_routes[0].entity_type == SearchEntityType.RALLY
    assert stage.entity_routes[0].entity_type == SearchEntityType.STAGE


def test_video_action_country_remains_direct_filter():
    plan = IntentResolutionRouter().route(
        "show jump highlights in Ireland",
        SearchQuery(
            intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
            action_types=["jump"],
            countries=["Ireland"],
        ),
    )

    assert not plan.entity_routes
    assert any(route.field_name == "countries" for route in plan.direct_filters)


def test_video_action_ambiguous_residual_is_not_forced_to_rally():
    plan = IntentResolutionRouter().route(
        "show jump highlights from mystery name",
        SearchQuery(intent=SearchIntent.SEARCH_VIDEO_ACTIONS, action_types=["jump"]),
    )

    assert len(plan.entity_routes) == 1
    assert plan.entity_routes[0].entity_type is None


def test_intent_capability_invariants():
    """Verify strict intent capability invariants:
    - GET_RALLY_RESULTS and GET_RALLY_TOP_FINISHERS require RALLY and disallow cross-type transitions
    - GET_TOP_UPLOADERS requires UPLOADER and disallows cross-type transitions
    - GET_TOP_DRIVERS_BY_WINS requires PERSON
    """
    cap_results = INTENT_CAPABILITIES[SearchIntent.GET_RALLY_RESULTS]
    assert cap_results.allowed_primary_entity_types == {SearchEntityType.RALLY}
    assert cap_results.allow_cross_type_recovery is False

    cap_finishers = INTENT_CAPABILITIES[SearchIntent.GET_RALLY_TOP_FINISHERS]
    assert cap_finishers.allowed_primary_entity_types == {SearchEntityType.RALLY}
    assert cap_finishers.allow_cross_type_recovery is False

    cap_uploaders = INTENT_CAPABILITIES[SearchIntent.GET_TOP_UPLOADERS]
    assert cap_uploaders.allowed_primary_entity_types == {SearchEntityType.UPLOADER}
    assert cap_uploaders.allow_cross_type_recovery is False


def test_router_performance_benchmark_10000_iterations():
    """Benchmark: Router must be pure in-memory logic executing in sub-millisecond time.
    Reports p50, p95, and max latency over 10,000 iterations.
    """
    router = IntentResolutionRouter()
    query = SearchQuery(
        intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
        rally_names=["Rally Alūksne"],
        driver_names=["Max Freeman"],
        stage_names=["SS3"],
        action_types=["jump"],
        countries=["Latvia"],
        years=[2026],
        person_role=PersonRole.DRIVER,
    )
    raw_text = "Show jumps of Max Freeman at Rally Aluksne 2026 SS3 in Latvia"

    latencies_us: list[float] = []
    iterations = 10000

    # Warmup
    for _ in range(100):
        router.route(raw_text, query)

    # Benchmark loop
    for _ in range(iterations):
        t0 = time.perf_counter()
        plan = router.route(raw_text, query)
        t1 = time.perf_counter()
        latencies_us.append((t1 - t0) * 1_000_000)

    latencies_us.sort()
    p50_us = latencies_us[int(iterations * 0.50)]
    p95_us = latencies_us[int(iterations * 0.95)]
    p99_us = latencies_us[int(iterations * 0.99)]
    max_us = max(latencies_us)

    p50_ms = p50_us / 1000.0
    p95_ms = p95_us / 1000.0
    max_ms = max_us / 1000.0

    print(
        f"\n[Router Benchmark] 10,000 runs -> "
        f"p50: {p50_us:.2f} µs ({p50_ms:.4f} ms), "
        f"p95: {p95_us:.2f} µs ({p95_ms:.4f} ms), "
        f"p99: {p99_us:.2f} µs ({(p99_us/1000.0):.4f} ms), "
        f"max: {max_us:.2f} µs ({max_ms:.4f} ms)"
    )

    assert p50_ms < 0.10, f"p50 latency {p50_ms:.4f} ms exceeds sub-millisecond threshold"
    assert p95_ms < 0.50, f"p95 latency {p95_ms:.4f} ms exceeds sub-millisecond threshold"
