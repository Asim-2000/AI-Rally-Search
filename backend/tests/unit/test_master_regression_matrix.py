import pytest
from app.domain.router import IntentResolutionRouter
from app.domain.search_intent import SearchIntent
from app.domain.search_query import MatchMode, PersonRole, SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.models import CanonicalSearchEntity, SearchEntityType
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.query_understanding.context import SearchContext
from app.services.search_plan_builder import SearchPlanBuilder, UnresolvedEntityError


@pytest.fixture
def entity_resolver():
    entities = [
        CanonicalSearchEntity(
            canonical_id="0cea6942-72e3-4257-a8c1-0f8148747d82",
            canonical_name="Rally Alūksne 2026",
            entity_type=SearchEntityType.RALLY,
            metadata={
                "eventId": "0cea6942-72e3-4257-a8c1-0f8148747d82",
                "year": 2026,
                "country": "Latvia",
                "city": "Alūksne",
                "searchableNames": ["Rally Alūksne 2026", "Rally Aluksne"],
            },
        ),
        CanonicalSearchEntity(
            canonical_id="01594380-c4aa-4d99-b19c-af125e032102",
            canonical_name="Donegal test rally 15th",
            entity_type=SearchEntityType.RALLY,
            metadata={
                "eventId": "01594380-c4aa-4d99-b19c-af125e032102",
                "year": 2026,
                "country": "Ireland",
                "city": "Letterkenny",
                "searchableNames": ["Donegal test rally 15th"],
            },
        ),
        CanonicalSearchEntity(
            canonical_id="f42b053d-8df9-4b5c-9d60-6ff3cfbf1642",
            canonical_name="Wilton Donegal International Rally 2025",
            entity_type=SearchEntityType.RALLY,
            metadata={
                "eventId": "f42b053d-8df9-4b5c-9d60-6ff3cfbf1642",
                "year": 2025,
                "country": "Ireland",
                "city": "Letterkenny",
                "searchableNames": ["Wilton Donegal International Rally 2025", "Donegal Rally 2025"],
            },
        ),
        CanonicalSearchEntity(
            canonical_id="a73dfca5-83b2-4f09-98f6-5d27ad749c81",
            canonical_name="Wilton Donegal International Rally 2026",
            entity_type=SearchEntityType.RALLY,
            metadata={
                "eventId": "a73dfca5-83b2-4f09-98f6-5d27ad749c81",
                "year": 2026,
                "country": "Ireland",
                "city": "Letterkenny",
                "searchableNames": ["Wilton Donegal International Rally 2026", "Donegal Rally 2026"],
            },
        ),
        CanonicalSearchEntity(
            canonical_id="person:account:cf3ddf9c-a64b-4f59-a5e4-5230c44b4d87",
            canonical_name="Max Freeman",
            entity_type=SearchEntityType.PERSON,
            metadata={
                "accountId": "cf3ddf9c-a64b-4f59-a5e4-5230c44b4d87",
                "driverId": "d-max-1",
                "codriverId": "c-max-1",
                "role": "both",
                "country": "GB",
                "searchableNames": ["Max Freeman"],
            },
        ),
    ]
    service = InMemoryEntitySearchService.from_entities(entities)
    adapter = EntitySearchLookupAdapter(search_service=service)
    return DatabaseEntityResolver(repository=adapter)


@pytest.mark.asyncio
async def test_shape_a_rally_names_aluqsne(entity_resolver):
    # A. rally_names=["aluqsne"] -> ENTITY/RALLY -> Rally Alūksne 2026
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rally_names=["aluqsne"])
    res = await entity_resolver.resolve(query)

    assert not res.requires_clarification
    assert res.resolved_query is not None
    assert "Rally Alūksne 2026" in res.resolved_query.rally_names
    plan = SearchPlanBuilder().build(res.resolved_query, resolutions=res.resolutions)
    assert plan.rally_names == ["Rally Alūksne 2026"]


@pytest.mark.asyncio
async def test_shape_b_empty_entity_fields_recovery_aluqsne(entity_resolver):
    # B. rally_names=[], raw unresolved text="aluqsne" -> router recovery -> OpenEntity -> Rally Alūksne 2026
    router = IntentResolutionRouter()
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES)
    plan = router.route(query, raw_text="aluqsne")
    assert plan.needs_entity_resolution

    # Mirror the production orchestrator, which populates BOTH the routing plan
    # and the unresolved mentions in the context extras. Empty-entity recovery
    # requires the routing plan to know which residual mentions are RALLY-typed.
    context = SearchContext(extra={
        "routing_plan": plan,
        "unresolved_mentions": plan.unresolved_text_mentions,
    })
    res = await entity_resolver.resolve(query, context=context)

    assert not res.requires_clarification
    assert res.resolved_query is not None
    assert "Rally Alūksne 2026" in res.resolved_query.rally_names
    plan_built = SearchPlanBuilder().build(res.resolved_query, resolutions=res.resolutions)
    assert plan_built.rally_names == ["Rally Alūksne 2026"]


@pytest.mark.asyncio
async def test_shape_c_misclassified_city_aluksnay(entity_resolver):
    # C. cities=["aluksnay"] -> city direct lookup fails -> safe RALLY discovery -> Rally Alūksne 2026
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, cities=["aluksnay"])
    res = await entity_resolver.resolve(query)

    assert not res.requires_clarification
    assert res.resolved_query is not None
    assert "Rally Alūksne 2026" in res.resolved_query.rally_names
    assert "aluksnay" not in res.resolved_query.cities
    plan = SearchPlanBuilder().build(res.resolved_query, resolutions=res.resolutions)
    assert plan.rally_names == ["Rally Alūksne 2026"]


def test_shape_d_direct_country_ireland():
    # D. countries=["Ireland"] -> DIRECT_FILTER -> no OpenEntity
    router = IntentResolutionRouter()
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Ireland"])
    plan = router.route(query, raw_text="Rallies in Ireland")

    assert not plan.needs_entity_resolution
    assert len(plan.direct_filter_routes) == 1
    assert plan.direct_filter_routes[0].field_name == "countries"
    assert plan.direct_filter_routes[0].raw_value == "Ireland"


def test_shape_e_direct_year_2025():
    # E. years=[2025] -> DIRECT_FILTER -> no OpenEntity
    router = IntentResolutionRouter()
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, years=[2025])
    plan = router.route(query, raw_text="Rallies in 2025")

    assert not plan.needs_entity_resolution
    assert len(plan.direct_filter_routes) == 1
    assert plan.direct_filter_routes[0].field_name == "years"
    assert plan.direct_filter_routes[0].raw_value == 2025


@pytest.mark.asyncio
async def test_shape_f_driver_names_max_freemn(entity_resolver):
    # F1. driver_names=["max freemn"] -> ENTITY/PERSON -> Max Freeman
    query1 = SearchQuery(intent=SearchIntent.SEARCH_DRIVER_VIDEOS, driver_names=["max freemn"])
    res1 = await entity_resolver.resolve(query1)
    assert not res1.requires_clarification
    assert res1.resolved_query is not None
    assert "Max Freeman" in res1.resolved_query.driver_names

    # F2. Misclassified rally_names=["max freemn"] with person-capable intent -> recovers to Max Freeman
    query2 = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rally_names=["max freemn"])
    res2 = await entity_resolver.resolve(query2)
    assert not res2.requires_clarification
    assert res2.resolved_query is not None
    assert "Max Freeman" in res2.resolved_query.driver_names
    assert res2.resolved_query.intent == SearchIntent.SEARCH_DRIVER_RALLIES


@pytest.mark.asyncio
async def test_shape_g_rally_names_donegl_clarification_safety(entity_resolver):
    # G. rally_names=["donegl"] -> clarification -> no SearchPlan, no repository execution
    query = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, rally_names=["donegl"])
    res = await entity_resolver.resolve(query)

    assert res.requires_clarification
    assert res.clarification_question is not None
    assert len(res.candidates) >= 2
    # In ConversationalSearchService, requires_clarification returns early without building SearchPlan
    assert res.is_success is False
