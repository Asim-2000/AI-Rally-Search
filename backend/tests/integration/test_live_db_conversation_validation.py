import pytest
from app.config import get_settings
from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.domain.search_intent import SearchIntent
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.mock_provider import MockProvider
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService

HAS_DB_CONFIG = bool(get_settings().db_host)


@pytest.mark.live_db
@pytest.mark.skipif(not HAS_DB_CONFIG, reason="DB_HOST not configured")
async def test_live_database_multi_turn_conversational_flow():
    engine = get_engine()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        entities = await source.load_entities()
        search_service = InMemoryEntitySearchService.from_entities(entities)
        adapter = EntitySearchLookupAdapter(search_service=search_service)
        resolver = DatabaseEntityResolver(repository=adapter)
        search_repo = SearchRepository(conn)

        provider = MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))
        query_parser = QueryUnderstandingService(provider)

        service = ConversationalSearchService(
            query_parser=query_parser,
            entity_resolver=resolver,
            repository=search_repo,
        )

        session = SearchConversationSession()

        # Turn 1: "Show Moonraker Forestry Rally 2026"
        s1, r1 = await service.search("Show Moonraker Forestry Rally 2026", session=session)
        assert r1.is_success is True
        assert r1.resolved_query.intent == SearchIntent.SEARCH_RALLIES
        assert r1.search_response.total_count > 0
        assert len(r1.search_response.results) > 0
        first_rally = r1.search_response.results[0]
        assert first_rally.event_id
        assert r1.referents.active_rally_id == first_rally.event_id
        assert "Moonraker" in (r1.referents.active_rally or "")
        assert len(s1.history) == 1



        # Turn 2: "Who won it?"
        s2, r2 = await service.search("Who won it?", session=s1)
        assert r2.is_success is True, [
            (candidate.id, candidate.canonical_name, candidate.score)
            for candidate in r2.candidates
        ]
        assert r2.resolved_query.intent == SearchIntent.GET_RALLY_RESULTS
        assert r2.search_response.total_count > 0
        assert len(r2.search_response.results) > 0
        winner = r2.search_response.results[0]
        assert winner.rally_id == first_rally.event_id
        assert winner.driver_id
        assert r2.referents.last_winner_driver_id == winner.driver_id
        assert len(s2.history) == 2
        assert s2.referents.active_rally is not None

        # Turn 3: "Show videos of him"
        s3, r3 = await service.search("Show videos of him", session=s2)
        assert r3.is_success is True
        assert r3.resolved_query.intent == SearchIntent.SEARCH_DRIVER_VIDEOS
        assert r3.search_response.total_count > 0
        assert len(r3.search_response.results) > 0
        assert all(item.video_id > 0 for item in r3.search_response.results)
        assert len(s3.history) == 3

        # Turn 4: "Only show jumps"
        s4, r4 = await service.search("Only show jumps", session=s3)
        assert r4.is_success is True
        assert r4.resolved_query.intent == SearchIntent.SEARCH_VIDEO_ACTIONS
        assert r4.resolved_query.action_types == ["jump"]
        # Zero is a legitimate canonical answer for this exact rally/driver/action
        # intersection and must still commit as a successful turn.
        assert r4.search_response.total_count == len(r4.search_response.results)
        assert len(s4.history) == 4

        # Independently prove that the live action repository returns canonical
        # action/video IDs, without relying on that sparse four-turn intersection.
        _, global_actions = await service.search("Show jumps", session=SearchConversationSession())
        assert global_actions.is_success is True
        assert global_actions.search_response.total_count > 0
        assert len(global_actions.search_response.results) > 0
        assert all(
            item.id > 0 and item.video_id > 0
            for item in global_actions.search_response.results
        )


@pytest.mark.live_db
@pytest.mark.skipif(not HAS_DB_CONFIG, reason="DB_HOST not configured")
async def test_live_database_ambiguity_clarification():
    engine = get_engine()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        entities = await source.load_entities()
        search_service = InMemoryEntitySearchService.from_entities(entities)
        adapter = EntitySearchLookupAdapter(search_service=search_service)
        resolver = DatabaseEntityResolver(repository=adapter)
        search_repo = SearchRepository(conn)

        provider = MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))
        query_parser = QueryUnderstandingService(provider)

        service = ConversationalSearchService(
            query_parser=query_parser,
            entity_resolver=resolver,
            repository=search_repo,
        )

        session = SearchConversationSession()

        # "Who won Donegal International Rally?" without year matches 2025 & 2026 editions.
        # For GET_RALLY_RESULTS without year, multi-year ambiguity triggers clarification.
        s_out, r_out = await service.search("Who won Donegal International Rally?", session=session)
        assert r_out.requires_clarification is True
        assert len(r_out.candidates) >= 2
        # Session state must remain untouched
        assert len(s_out.history) == 0
        assert s_out.active_request_id == session.active_request_id + 1
