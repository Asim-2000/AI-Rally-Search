import pytest
from app.domain.conversation_session import SearchConversationSession
from app.domain.referent_context import ResultReferentContext
from app.domain.results import (
    ClassificationItem,
    RallyResultItem,
    SearchResponse,
    VideoActionItem,
    VideoItem,
)
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.entity_search.models import CandidateOrigin, EntityCandidate, EntityType
from app.entity_search.resolver import DatabaseEntityResolver, IEntityLookupRepository
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.mock_provider import MockProvider
from app.query_understanding.service import QueryUnderstandingService
from app.services.conversational_search_service import ConversationalSearchService


class MockConversationalLookupRepo(IEntityLookupRepository):
    async def lookup_rallies(self, phrase, *, year=None, country=None, city=None, limit=25):
        lower = phrase.lower().strip()
        if "donegal" in lower:
            cands = [
                EntityCandidate(
                    id="donegal-2025-uuid",
                    type=EntityType.RALLY,
                    canonical_name="Donegal International Rally 2025",
                    score=1.0,
                    metadata={"year": 2025},
                ),
                EntityCandidate(
                    id="donegal-2024-uuid",
                    type=EntityType.RALLY,
                    canonical_name="Donegal International Rally 2024",
                    score=0.9,
                    metadata={"year": 2024},
                ),
            ]
            if year == 2025 or "2025" in lower:
                return [cands[0]]
            if year == 2024 or "2024" in lower:
                return [cands[1]]
            return cands
        return [
            EntityCandidate(
                id=f"r-{lower}",
                type=EntityType.RALLY,
                canonical_name=phrase,
                score=1.0,
            )
        ]

    async def lookup_drivers(self, phrase, *, event_id=None, event_name=None, year=None, person_role=None, limit=25):
        lower = phrase.lower().strip()
        if "josh" in lower or "moffett" in lower:
            return [
                EntityCandidate(
                    id="d-101",
                    type=EntityType.DRIVER,
                    canonical_name="Josh Moffett",
                    score=1.0,
                )
            ]
        if "sam" in lower:
            return [
                EntityCandidate(
                    id="d-102",
                    type=EntityType.DRIVER,
                    canonical_name="Sam Moffett",
                    score=1.0,
                )
            ]
        return [
            EntityCandidate(
                id=f"d-{lower}",
                type=EntityType.DRIVER,
                canonical_name=phrase,
                score=1.0,
            )
        ]


    async def lookup_stages(self, phrase, *, event_id=None, event_name=None, limit=25):
        return []

    async def lookup_cities(self, phrase, *, country=None, limit=25):
        return []

    async def lookup_uploaders(self, phrase, *, limit=25):
        return []


class MockSearchRepo:
    async def search(self, query: SearchQuery) -> SearchResponse:
        match query.intent:
            case SearchIntent.SEARCH_RALLIES:
                return SearchResponse(
                    intent=query.intent,
                    results=[
                        RallyResultItem(
                            event_id="e-donegal-2025",
                            event_name="Donegal International Rally 2025",
                            country="Ireland",
                            city="Letterkenny",
                        )
                    ],
                    total_count=1,
                    has_more=False,
                    limit=query.limit,
                    offset=query.offset,
                )
            case SearchIntent.GET_RALLY_RESULTS | SearchIntent.GET_RALLY_TOP_FINISHERS:
                return SearchResponse(
                    intent=query.intent,
                    results=[
                        ClassificationItem(
                            id=101,
                            rally_id="e-donegal-2025",
                            event_name="Donegal International Rally 2025",
                            driver_id="d-101",
                            driver_name="Josh Moffett",
                            pos_overall=1,
                        ),
                        ClassificationItem(
                            id=102,
                            rally_id="e-donegal-2025",
                            event_name="Donegal International Rally 2025",
                            driver_id="d-102",
                            driver_name="Sam Moffett",
                            pos_overall=2,
                        ),
                    ],
                    total_count=2,
                    has_more=False,
                    limit=query.limit,
                    offset=query.offset,
                )
            case SearchIntent.SEARCH_DRIVER_VIDEOS:
                return SearchResponse(
                    intent=query.intent,
                    results=[
                        VideoItem(
                            video_id=101,
                            driver_id="d-101",
                            driver_name="Josh Moffett",
                        )
                    ],
                    total_count=1,
                    has_more=False,
                    limit=query.limit,
                    offset=query.offset,
                )
            case SearchIntent.SEARCH_VIDEO_ACTIONS:
                return SearchResponse(
                    intent=query.intent,
                    results=[
                        VideoActionItem(
                            id=501,
                            video_id=101,
                            action_type=query.action_types[0] if query.action_types else "jump",
                        )
                    ],
                    total_count=1,
                    has_more=False,
                    limit=query.limit,
                    offset=query.offset,
                )
            case _:
                return SearchResponse(
                    intent=query.intent,
                    results=[],
                    total_count=0,
                    has_more=False,
                    limit=query.limit,
                    offset=query.offset,
                )


@pytest.fixture
def conversational_service():
    provider = MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))
    query_parser = QueryUnderstandingService(provider)
    lookup_repo = MockConversationalLookupRepo()
    resolver = DatabaseEntityResolver(repository=lookup_repo)
    repo = MockSearchRepo()
    return ConversationalSearchService(
        query_parser=query_parser,
        entity_resolver=resolver,
        repository=repo,
    )


@pytest.mark.unit
async def test_mandatory_4_turn_conversational_integration(conversational_service):
    session = SearchConversationSession()

    # TURN 1: "Show Donegal Rally 2025"
    s1, r1 = await conversational_service.search("Show Donegal Rally 2025", session=session)
    assert r1.is_success is True
    assert r1.resolved_query.intent == SearchIntent.SEARCH_RALLIES
    assert "Donegal" in r1.referents.active_rally
    assert len(s1.history) == 1

    # TURN 2: "Who won it?"
    s2, r2 = await conversational_service.search("Who won it?", session=s1)
    assert r2.is_success is True
    assert r2.resolved_query.intent == SearchIntent.GET_RALLY_RESULTS
    assert "Donegal" in r2.resolved_query.target_rally_name
    assert r2.referents.last_winner == "Josh Moffett"
    assert r2.referents.active_driver == "Josh Moffett"
    assert len(s2.history) == 2

    # TURN 3: "Show videos of him"
    s3, r3 = await conversational_service.search("Show videos of him", session=s2)
    assert r3.is_success is True
    assert r3.resolved_query.intent == SearchIntent.SEARCH_DRIVER_VIDEOS
    assert "Josh Moffett" in r3.resolved_query.driver_names
    assert len(s3.history) == 3

    # TURN 4: "Only show jumps"
    s4, r4 = await conversational_service.search("Only show jumps", session=s3)
    assert r4.is_success is True
    assert r4.resolved_query.intent == SearchIntent.SEARCH_VIDEO_ACTIONS
    assert r4.resolved_query.action_types == ["jump"]
    assert "Josh Moffett" in r4.resolved_query.driver_names
    assert "Donegal" in r4.resolved_query.target_rally_name
    assert len(s4.history) == 4


@pytest.mark.unit
async def test_clarification_preserves_session_state_untouched(conversational_service):
    # Initial session: "Who won it?" without active rally
    s0 = SearchConversationSession()
    s_out, r_out = await conversational_service.search("Who won it?", session=s0)
    assert r_out.requires_clarification is True
    assert "Which rally" in r_out.clarification_question
    # Session remains exactly untouched
    assert len(s_out.history) == 0
    assert s_out.active_query.intent == SearchIntent.SEARCH_RALLIES
    assert s_out.active_request_id == s0.active_request_id + 1


@pytest.mark.unit
async def test_ambiguous_driver_pronoun_requires_clarification(conversational_service):
    # Session with 2 candidate active drivers
    session = SearchConversationSession(
        referents=ResultReferentContext(
            active_drivers=["Josh Moffett", "Sam Moffett"],
        )
    )
    s_out, r_out = await conversational_service.search("Show videos of him", session=session)
    assert r_out.requires_clarification is True
    assert "Which driver do you mean?" in r_out.clarification_question
    assert len(s_out.history) == 0
    assert s_out.active_request_id == session.active_request_id + 1


@pytest.mark.unit
async def test_special_response_advances_generation_without_committing(conversational_service):
    session = SearchConversationSession()
    updated, result = await conversational_service.search("Hello!", session=session)
    assert result.special_response_category == "greeting"
    assert result.search_response is None
    assert updated.active_request_id == session.active_request_id + 1
    assert updated.active_query == session.active_query
    assert updated.referents == session.referents
    assert updated.history == session.history


@pytest.mark.unit
async def test_successful_zero_result_commits_turn_and_generation(conversational_service):
    session = SearchConversationSession()
    updated, result = await conversational_service.search("Show top uploaders", session=session)
    assert result.is_success
    assert result.total_count == 0
    assert updated.active_request_id == session.active_request_id + 1
    assert len(updated.history) == 1


@pytest.mark.unit
async def test_provider_schema_failure_advances_generation_without_commit():
    provider = MockProvider(
        ProviderConfig(provider="mock", model="mock-parser-v1", max_retries=0),
        responses={"broken": "not-json"},
    )
    service = ConversationalSearchService(
        query_parser=QueryUnderstandingService(provider),
        repository=MockSearchRepo(),
    )
    session = SearchConversationSession()
    updated, result = await service.search("broken", session=session)
    assert result.error_code == "QUERY_PARSE_FAILED"
    assert updated.active_request_id == session.active_request_id + 1
    assert updated.active_query == session.active_query
    assert updated.referents == session.referents
    assert updated.history == []


@pytest.mark.unit
async def test_database_failure_advances_generation_without_commit():
    class FailingRepository:
        async def search(self, query):
            raise RuntimeError("synthetic DB failure")

    service = ConversationalSearchService(
        query_parser=QueryUnderstandingService(
            MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))
        ),
        repository=FailingRepository(),
    )
    session = SearchConversationSession()
    updated, result = await service.search("Show rallies in Ireland", session=session)
    assert result.error_code == "DATABASE_ERROR"
    assert updated.active_request_id == session.active_request_id + 1
    assert updated.active_query == session.active_query
    assert updated.referents == session.referents
    assert updated.history == []


@pytest.mark.unit
def test_committed_referent_ids_bypass_open_set_reresolution():
    query = SearchQuery(
        intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
        rally_names=["Donegal International Rally 2025"],
        driver_names=["Josh Moffett"],
    )
    referents = ResultReferentContext(
        active_rally="Donegal International Rally 2025",
        active_rally_id="event-2025",
        last_winner="Josh Moffett",
        last_winner_driver_id="driver-101",
    )
    resolution_query, rallies, drivers, driver_ids = (
        ConversationalSearchService._reuse_committed_referent_ids(query, referents)
    )
    assert resolution_query.target_rally_names == []
    assert resolution_query.driver_names == []
    assert rallies == ["Donegal International Rally 2025"]
    assert drivers == ["Josh Moffett"]
    assert driver_ids == ["driver-101"]
