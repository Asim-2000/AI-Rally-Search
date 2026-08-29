import pytest
from sqlalchemy import text
from app.config import get_settings
from app.db.engine import get_engine
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.repositories.search_repository import SearchRepository
from app.services.search_plan_builder import SearchPlanBuilder

HAS_DB_CONFIG = bool(get_settings().db_host)

@pytest.mark.live_db
@pytest.mark.skipif(not HAS_DB_CONFIG,reason="DB_HOST not configured")
async def test_live_database_truth_source():
    async with get_engine().connect() as conn:
        assert (await conn.execute(text("SELECT 1"))).scalar_one()==1

@pytest.mark.live_db
@pytest.mark.skipif(not HAS_DB_CONFIG,reason="DB_HOST not configured")
@pytest.mark.parametrize("intent",list(SearchIntent))
async def test_every_intent_executes(intent):
    builder = SearchPlanBuilder()
    plan = builder.build(SearchQuery(intent=intent, limit=2))
    async with get_engine().connect() as conn:
        response=await SearchRepository(conn).search(plan)
    assert response.intent == intent
    assert len(response.results) <= 2
    assert len({(x.kind,str(x)) for x in response.results}) == len(response.results)

@pytest.mark.live_db
@pytest.mark.skipif(not HAS_DB_CONFIG,reason="DB_HOST not configured")
@pytest.mark.parametrize("intent",[SearchIntent.SEARCH_VIDEO_ACTIONS,SearchIntent.SEARCH_DRIVER_VIDEOS])
async def test_stable_non_overlapping_pages(intent):
    builder = SearchPlanBuilder()
    async with get_engine().connect() as conn:
        repo=SearchRepository(conn)
        first=await repo.search(builder.build(SearchQuery(intent=intent,limit=5,offset=0)))
        second=await repo.search(builder.build(SearchQuery(intent=intent,limit=5,offset=5)))
    key="id" if intent == SearchIntent.SEARCH_VIDEO_ACTIONS else "video_id"
    first_ids=[getattr(x,key) for x in first.results]; second_ids=[getattr(x,key) for x in second.results]
    assert len(first_ids)==len(set(first_ids)) and len(second_ids)==len(set(second_ids))
    assert set(first_ids).isdisjoint(second_ids)
    assert first.total_count == second.total_count
