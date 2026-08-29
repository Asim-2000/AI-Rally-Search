import asyncio
from unittest.mock import AsyncMock, patch
from httpx import ASGITransport, AsyncClient
import pytest

from app.api.v1.search import get_repository
from app.entity_search.models import CanonicalSearchEntity, SearchEntityType
from app.entity_search.service import InMemoryEntitySearchService
from app.entity_search.warmup import (
    cancel_background_entity_search_warmup,
    get_entity_count,
    get_entity_index_stats,
    get_shared_entity_search_service,
    is_entity_search_ready,
    reset_shared_entity_search_service,
    start_background_entity_search_warmup,
)
from app.main import app


@pytest.fixture(autouse=True)
def cleanup_warmup():
    reset_shared_entity_search_service()
    yield
    reset_shared_entity_search_service()


def _dummy_entities() -> list[CanonicalSearchEntity]:
    return [
        CanonicalSearchEntity(
            canonical_id="rally:1",
            canonical_name="Rally Finland",
            entity_type=SearchEntityType.RALLY,
            metadata={"eventId": "rally:1"},
        ),
        CanonicalSearchEntity(
            canonical_id="person:driver:1",
            canonical_name="Sebastien Ogier",
            entity_type=SearchEntityType.PERSON,
            metadata={"driverId": "1", "role": "driver"},
        ),
        CanonicalSearchEntity(
            canonical_id="stage:1",
            canonical_name="Ouninpohja",
            entity_type=SearchEntityType.STAGE,
            metadata={"stageId": "1"},
        ),
    ]


async def test_health_returns_ok_when_not_ready():
    """Verify /health responds 200 immediately even before entity search is warmed."""
    assert not is_entity_search_ready()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


async def test_ready_endpoint_states():
    """Verify /ready returns 503 while warming, and 200 once ready."""
    assert not is_entity_search_ready()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. While warming / not ready -> 503
        r1 = await client.get("/ready")
        assert r1.status_code == 503
        assert r1.json() == {"ready": False, "entityIndexReady": False}

        # 2. Simulate completed warm-up
        entities = _dummy_entities()
        service = InMemoryEntitySearchService.from_entities(entities)
        with patch("app.entity_search.warmup._shared_entity_search_service", service), \
             patch("app.entity_search.warmup._is_ready", True):
            assert is_entity_search_ready()
            assert get_entity_count() == 3

            r2 = await client.get("/ready")
            assert r2.status_code == 200
            assert r2.json() == {
                "ready": True,
                "entityIndexReady": True,
                "entityCount": 3,
            }


async def test_structured_search_usable_before_entity_readiness():
    """Verify /v1/search does not depend on entity search readiness."""
    class _MockSearchRepo:
        async def search(self, plan):
            from app.domain.results import SearchResponse
            return SearchResponse(
                intent="SEARCH_RALLIES",
                results=[],
                total_count=0,
                has_more=False,
                limit=20,
                offset=0,
            )

    app.dependency_overrides[get_repository] = lambda: _MockSearchRepo()
    try:
        assert not is_entity_search_ready()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/v1/search",
                json={
                    "intent": "SEARCH_RALLIES",
                    "limit": 20,
                    "offset": 0,
                    "driverMatchMode": "ANY",
                    "personRole": "ANY",
                },
            )
        assert response.status_code == 200
        assert response.json()["intent"] == "SEARCH_RALLIES"
    finally:
        app.dependency_overrides.clear()


class _MockConnContext:
    async def __aenter__(self):
        return AsyncMock()

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        pass


class _MockEngine:
    def connect(self):
        return _MockConnContext()


async def test_single_index_warmup_concurrency():
    """Verify concurrent calls await the single running background warm-up task."""
    load_call_count = 0

    async def fake_load_entities(self):
        nonlocal load_call_count
        load_call_count += 1
        await asyncio.sleep(0.05)  # Simulate DB latency
        return _dummy_entities()

    with patch("app.entity_search.data_source.MySqlEntitySearchDataSource.load_entities", fake_load_entities):
        # Start background task
        task = start_background_entity_search_warmup(_MockEngine())

        # Call get_shared_entity_search_service 5 times concurrently while task is running
        results = await asyncio.gather(
            get_shared_entity_search_service(),
            get_shared_entity_search_service(),
            get_shared_entity_search_service(),
            get_shared_entity_search_service(),
            task,
        )

        assert load_call_count == 1, "load_entities must only be invoked once across concurrent callers"
        service = results[0]
        for res in results:
            assert res is service, "All callers must receive the exact same singleton instance"
        assert is_entity_search_ready()


async def test_warmup_failure_leaves_readiness_false():
    """Verify background warm-up failure keeps /ready 503 and does not mark ready."""
    async def failing_load(self):
        raise RuntimeError("Database connection timed out")

    with patch("app.entity_search.data_source.MySqlEntitySearchDataSource.load_entities", failing_load):
        task = start_background_entity_search_warmup(_MockEngine())
        with pytest.raises(RuntimeError, match="Database connection timed out"):
            await task

        assert not is_entity_search_ready()
        assert get_entity_count() is None

        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            r_health = await client.get("/health")
            assert r_health.status_code == 200  # Liveness stays UP

            r_ready = await client.get("/ready")
            assert r_ready.status_code == 503  # Readiness stays DOWN

