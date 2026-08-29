import asyncio
import pytest
from app.domain.conversation_session import SearchConversationSession
from app.domain.referent_context import ResultReferentContext
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.domain.session_commit import commit_if_current


@pytest.mark.unit
async def test_stale_async_response_protection_concurrent_race():
    session = SearchConversationSession()

    # Request A is launched
    req_a_id = session.active_request_id + 1
    session = session.copy_with(active_request_id=req_a_id)

    # Request B is launched shortly after
    req_b_id = session.active_request_id + 1
    session = session.copy_with(active_request_id=req_b_id)

    # Barriers / events for deterministic out-of-order completion
    b_finished = asyncio.Event()
    a_can_finish = asyncio.Event()

    query_a = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Ireland"])
    referents_a = ResultReferentContext(active_rally="Irish Rally")

    query_b = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Latvia"])
    referents_b = ResultReferentContext(active_rally="Rally Alūksne")

    async def run_worker_a():
        await b_finished.wait()
        # Worker A attempts commit
        outcome = commit_if_current(
            session,
            response_request_id=req_a_id,
            query=query_a,
            referents=referents_a,
            title="Query A (Ireland)",
        )
        return outcome.committed, outcome.session

    async def run_worker_b():
        # Worker B completes first and commits
        nonlocal session
        outcome = commit_if_current(
            session,
            response_request_id=req_b_id,
            query=query_b,
            referents=referents_b,
            title="Query B (Latvia)",
        )
        committed, new_sess = outcome.committed, outcome.session
        session = new_sess
        b_finished.set()
        return committed, new_sess

    task_a = asyncio.create_task(run_worker_a())
    task_b = asyncio.create_task(run_worker_b())

    b_committed, b_session = await task_b
    a_committed, a_session = await task_a

    # Worker B must have committed successfully
    assert b_committed is True
    assert b_session.active_query.countries == ["Latvia"]
    assert b_session.referents.active_rally == "Rally Alūksne"

    # Worker A must have been rejected as stale
    assert a_committed is False
    # Final session state remains Worker B's committed state
    assert session.active_query.countries == ["Latvia"]
    assert session.referents.active_rally == "Rally Alūksne"


@pytest.mark.unit
async def test_session_reset_invalidates_in_flight_request():
    session = SearchConversationSession()

    # Request A is launched
    req_a_id = session.active_request_id + 1
    session = session.copy_with(active_request_id=req_a_id)

    # User clicks "Reset Session" / clearAll while request A is in flight
    session = session.clear_all()
    assert session.active_request_id > req_a_id

    # Request A returns late
    query_a = SearchQuery(intent=SearchIntent.SEARCH_RALLIES, countries=["Ireland"])
    referents_a = ResultReferentContext(active_rally="Irish Rally")

    outcome = commit_if_current(
        session,
        response_request_id=req_a_id,
        query=query_a,
        referents=referents_a,
        title="Stale Query",
    )
    committed, final_session = outcome.committed, outcome.session

    assert committed is False
    assert final_session.active_query.countries == []
    assert len(final_session.history) == 0
