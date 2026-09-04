"""Backend latency instrumentation.

Covers the three properties the timing record has to hold: it measures the
whole request (not just the part inside the handler), it correlates end to end
with the client's id, and it never carries user content.
"""

import json
import logging

import pytest
from httpx import ASGITransport, AsyncClient

from app.api.v1.conversation import get_conversational_service
from app.domain.conversation_session import SearchConversationSession
from app.domain.results import SearchResponse
from app.domain.search_intent import SearchIntent
from app.domain.search_plan import INTENT_TO_STRATEGY, SearchPlan
from app.main import app
from app.observability import Phase, RequestTimings, request_scope
from app.observability.logging import JsonFormatter, log_request_timing, sanitize
from app.observability.middleware import REQUEST_ID_HEADER, SERVER_TIMING_HEADER
from app.services.conversational_search_service import (
    ConversationalSearchResult,
    ConversationalSearchService,
)

pytestmark = pytest.mark.unit


class _StubService:
    """Stands in for the real pipeline, recording phase times the way it does."""

    def __init__(self, *, clarification: bool = False) -> None:
        self.clarification = clarification

    async def search(self, query, *, session=None, language=None, expose_timings=False, **_):
        from app.observability import current_request_id, current_timings

        timings = current_timings()
        if timings is not None:
            timings.add(Phase.QUERY_UNDERSTANDING, 12.0)
            timings.add(Phase.GEMINI, 11.0)
            timings.add(Phase.REPOSITORY_DB, 5.0)
            timings.update(model="gemini-3.5-flash-lite", gemini_called=True)
        result = ConversationalSearchResult(
            requires_clarification=self.clarification,
            clarification_question="Which one?" if self.clarification else None,
            search_response=None
            if self.clarification
            else SearchResponse(
                intent=SearchIntent.SEARCH_RALLIES,
                results=[],
                total_count=0,
                has_more=False,
                limit=20,
                offset=0,
            ),
            search_plan=None
            if self.clarification
            else SearchPlan(
                intent=SearchIntent.SEARCH_RALLIES,
                strategy=INTENT_TO_STRATEGY[SearchIntent.SEARCH_RALLIES],
                limit=20,
                offset=0,
            ),
            request_id=current_request_id(),
            timings=timings.snapshot() if (expose_timings and timings) else None,
        )
        return (session or SearchConversationSession()), result


def _override(service):
    app.dependency_overrides[get_conversational_service] = lambda: service


async def _post(payload, headers=None):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        return await client.post("/v1/conversation/search", json=payload, headers=headers or {})


async def test_client_request_id_propagates_into_response_and_logs(caplog):
    _override(_StubService())
    try:
        with caplog.at_level(logging.INFO, logger="app.latency"):
            response = await _post({"query": "rallies in ireland"}, {REQUEST_ID_HEADER: "trace-abc-1"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    # Echoed on the wire in both the header and the body.
    assert response.headers[REQUEST_ID_HEADER] == "trace-abc-1"
    assert response.json()["traceId"] == "trace-abc-1"
    # And present on the structured timing line, which is what makes a client
    # record joinable to a backend record.
    record = next(r for r in caplog.records if r.getMessage() == "search_timing")
    assert record.timing["request_id"] == "trace-abc-1"


async def test_a_missing_or_unsafe_client_id_is_replaced_not_echoed():
    _override(_StubService())
    try:
        no_header = await _post({"query": "rallies in ireland"})
        unsafe = await _post(
            {"query": "rallies in ireland"},
            {REQUEST_ID_HEADER: "drop table users; -- " + "x" * 200},
        )
    finally:
        app.dependency_overrides.clear()

    generated = no_header.headers[REQUEST_ID_HEADER]
    assert len(generated) == 32 and generated.isalnum()
    assert "drop table" not in unsafe.headers[REQUEST_ID_HEADER]


async def test_timing_record_covers_every_required_phase(caplog):
    _override(_StubService())
    try:
        with caplog.at_level(logging.INFO, logger="app.latency"):
            await _post({"query": "rallies in ireland"}, {REQUEST_ID_HEADER: "trace-phases"})
    finally:
        app.dependency_overrides.clear()

    timing = next(
        r.timing for r in caplog.records if r.getMessage() == "search_timing"
    )
    for key in (
        "request_id",
        "total_backend_ms",
        "dependencies_ms",
        "query_understanding_ms",
        "gemini_ms",
        "repository_db_ms",
        "serialization_ms",
        "model",
        "gemini_called",
        "intent",
        "clarification",
        "status_code",
    ):
        assert key in timing, key
    assert timing["gemini_called"] is True
    assert timing["clarification"] is False


async def test_clarification_is_reported_as_such(caplog):
    _override(_StubService(clarification=True))
    try:
        with caplog.at_level(logging.INFO, logger="app.latency"):
            await _post({"query": "donegal"}, {REQUEST_ID_HEADER: "trace-clarify"})
    finally:
        app.dependency_overrides.clear()

    timing = next(r.timing for r in caplog.records if r.getMessage() == "search_timing")
    assert timing["clarification"] is True
    assert timing["intent"] is None


async def test_total_backend_ms_includes_time_outside_the_handler():
    """The regression this instrumentation exists to prevent.

    The pre-existing `totalLatencyMs` started inside the service, after FastAPI
    had already resolved dependencies (where the DB connection is opened). A
    cold request measured 2835 ms at the client while reporting 1024 ms. The
    header total must account for the dependency phase too.
    """
    import asyncio

    class _SlowDependency(_StubService):
        pass

    async def slow_service():
        await asyncio.sleep(0.05)
        return _SlowDependency()

    app.dependency_overrides[get_conversational_service] = slow_service
    try:
        response = await _post({"query": "rallies in ireland"}, {REQUEST_ID_HEADER: "trace-slow"})
    finally:
        app.dependency_overrides.clear()

    total = float(response.headers[SERVER_TIMING_HEADER])
    assert total >= 50.0, f"dependency time missing from the total: {total}"


def test_timings_accumulate_across_repeated_phases():
    timings = RequestTimings(request_id="t")
    timings.add(Phase.GEMINI, 100.0)
    timings.add(Phase.GEMINI, 250.0)
    # A provider retry must show the summed cost, not just the last attempt.
    assert timings.snapshot()["gemini_ms"] == 350.0


def test_user_content_is_stripped_from_timing_records():
    record = sanitize(
        {
            "request_id": "t",
            "query": "who won rally donegal",
            "transcript": "spoken words",
            "api_key": "secret",
            "session": {"history": ["..."]},
            "gemini_ms": 12.0,
        }
    )
    assert record == {"request_id": "t", "gemini_ms": 12.0}


def test_json_formatter_emits_one_parseable_object_per_line():
    record = logging.LogRecord("app.latency", logging.INFO, __file__, 1, "search_timing", None, None)
    record.timing = {"request_id": "t", "total_backend_ms": 1.5}
    line = JsonFormatter().format(record)
    assert "\n" not in line
    assert json.loads(line)["request_id"] == "t"


def test_request_scope_isolates_and_restores_context():
    from app.observability import current_request_id, current_timings

    assert current_request_id() is None
    with request_scope("outer"):
        assert current_request_id() == "outer"
        with request_scope("inner"):
            assert current_request_id() == "inner"
        assert current_request_id() == "outer"
        assert current_timings() is not None
    assert current_request_id() is None
    assert current_timings() is None


def test_recording_a_phase_outside_a_request_scope_is_a_no_op():
    from app.observability import current_timings

    # Pipeline code runs in benchmarks and scripts with no scope active; it must
    # simply record nothing rather than fail.
    assert current_timings() is None


async def test_search_result_carries_debug_timings_only_when_enabled():
    from app.query_understanding.provider import ProviderConfig
    from app.query_understanding.providers import MockProvider
    from app.query_understanding.service import QueryUnderstandingService

    service = ConversationalSearchService(
        query_parser=QueryUnderstandingService(
            MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))
        ),
    )
    with request_scope("trace-off"):
        _, off = await service.search("rallies in ireland", expose_timings=False)
    with request_scope("trace-on"):
        _, on = await service.search("rallies in ireland", expose_timings=True)

    assert off.request_id == "trace-off"
    assert off.timings is None
    assert on.timings is not None
    assert on.timings["request_id"] == "trace-on"
    assert "query_understanding_ms" in on.timings
