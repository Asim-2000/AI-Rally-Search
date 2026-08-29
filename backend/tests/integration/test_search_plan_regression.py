from __future__ import annotations

import pytest
from app.config import get_settings
from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.domain.search_intent import SearchIntent
from app.domain.search_plan import ExecutionStrategy, SearchPlan
from app.domain.search_query import SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.mock_provider import MockProvider
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService
from app.services.search_plan_builder import SearchPlanBuilder

HAS_DB_CONFIG = bool(get_settings().db_host)


@pytest.mark.live_db
@pytest.mark.skipif(not HAS_DB_CONFIG, reason="DB_HOST not configured")
async def test_search_plan_regression_suite():
    engine = get_engine()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        entities = await source.load_entities()
        search_service = InMemoryEntitySearchService.from_entities(entities)
        adapter = EntitySearchLookupAdapter(search_service=search_service)
        resolver = DatabaseEntityResolver(repository=adapter)
        search_repo = SearchRepository(conn)

        mock_responses = {
            "Rallies in Ireland": '{"intent": "SEARCH_RALLIES", "countries": ["Ireland"]}',
            "aluqsne": '{"intent": "SEARCH_RALLIES", "rallyNames": ["aluqsne"]}',
            "Rally aluqsne": '{"intent": "SEARCH_RALLIES", "rallyNames": ["aluqsne"]}',
            "Show videos of max freemn": '{"intent": "SEARCH_DRIVER_VIDEOS", "driverNames": ["max freemn"]}',
            "donegl": '{"intent": "SEARCH_RALLIES", "rallyNames": ["donegl"]}',
        }
        provider = MockProvider(
            ProviderConfig(provider="mock", model="mock-parser-v1"),
            responses=mock_responses,
        )
        query_parser = QueryUnderstandingService(provider)

        service = ConversationalSearchService(
            query_parser=query_parser,
            entity_resolver=resolver,
            repository=search_repo,
        )

        session = SearchConversationSession()

        # 1. Regression: "Rallies in Ireland"
        # SearchQuery: intent=SEARCH_RALLIES, countries=["Ireland"]
        # SearchPlan: intent=SEARCH_RALLIES, strategy=RALLIES, countries=["Ireland"] (no OpenEntity needed)
        s1, r1 = await service.search("Rallies in Ireland", session=session)
        assert r1.is_success is True
        assert r1.search_plan is not None
        assert r1.search_plan.intent == SearchIntent.SEARCH_RALLIES
        assert r1.search_plan.strategy == ExecutionStrategy.RALLIES
        assert r1.search_plan.countries == ["Ireland"]
        assert len(r1.search_plan.rally_names) == 0  # Direct country filter, no noisy rally name
        assert r1.search_response.total_count > 0

        # 2. Regression: "aluqsne"
        # SearchQuery: intent=SEARCH_RALLIES, rally_names=["aluqsne"]
        # OpenEntity: resolves to "Rally Alūksne 2026"
        # SearchPlan: contains canonical "Rally Alūksne 2026", never raw "aluqsne"
        s2, r2 = await service.search("aluqsne", session=session)
        assert r2.is_success is True
        assert r2.search_plan is not None
        assert r2.search_plan.intent == SearchIntent.SEARCH_RALLIES
        assert r2.search_plan.strategy == ExecutionStrategy.RALLIES
        assert "aluqsne" not in r2.search_plan.rally_names
        assert any("Alūksne" in name or "Aluksne" in name for name in r2.search_plan.rally_names)
        assert r2.search_response.total_count > 0

        # 3. Regression: "Rally aluqsne"
        s3, r3 = await service.search("Rally aluqsne", session=session)
        assert r3.is_success is True
        assert r3.search_plan is not None
        assert r3.search_plan.intent == SearchIntent.SEARCH_RALLIES
        assert r3.search_plan.strategy == ExecutionStrategy.RALLIES
        assert "aluqsne" not in r3.search_plan.rally_names
        assert any("Alūksne" in name or "Aluksne" in name for name in r3.search_plan.rally_names)
        assert r3.search_response.total_count > 0

        # 4. Regression: "max freemn"
        # SearchQuery: intent=SEARCH_DRIVER_VIDEOS (or SEARCH_DRIVER_RALLIES), driver_names=["max freemn"]
        # OpenEntity: resolves to "Max Freeman" with canonical driver ID
        # SearchPlan: contains canonical driver name "Max Freeman" and driver ID, never raw "max freemn"
        s4, r4 = await service.search("Show videos of max freemn", session=session)
        assert r4.is_success is True
        assert r4.search_plan is not None
        assert r4.search_plan.intent == SearchIntent.SEARCH_DRIVER_VIDEOS
        assert r4.search_plan.strategy == ExecutionStrategy.DRIVER_VIDEOS
        assert "max freemn" not in r4.search_plan.driver_names
        assert any("Max Freeman" in name for name in r4.search_plan.driver_names)
        assert len(r4.search_plan.driver_ids) > 0

        # 5. Regression: "donegl"
        # Typo with multiple plausible candidates -> clarification required
        # NO SearchPlan is constructed; candidates returned for user selection
        s5, r5 = await service.search("donegl", session=session)
        assert r5.requires_clarification is True
        assert r5.search_plan is None  # No execution plan created
        assert len(r5.candidates) > 0
