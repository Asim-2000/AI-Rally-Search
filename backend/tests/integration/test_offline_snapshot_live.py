"""Live-DB integration tests for the /v1/offline/snapshot endpoint."""

import json

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import get_settings
from app.main import app
from app.services.offline_snapshot import CORE_TABLES, SCHEMA_VERSION, SNAPSHOT_TABLES

HAS_DB_CONFIG = bool(get_settings().db_host)

pytestmark = [
    pytest.mark.live_db,
    pytest.mark.skipif(not HAS_DB_CONFIG, reason="DB_HOST not configured"),
]


async def _get(segment: str) -> dict:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get(f"/v1/offline/snapshot?segment={segment}")
    assert resp.status_code == 200, resp.text
    return resp.json()


async def test_snapshot_metadata_present():
    snap = await _get("core")
    assert snap["schema_version"] == SCHEMA_VERSION
    assert snap["data_version"]
    assert snap["snapshot_id"].endswith("-core")
    assert snap["generated_at"]
    assert set(SNAPSHOT_TABLES).issubset(snap.keys())


async def test_core_snapshot_has_rows_but_no_video():
    snap = await _get("core")
    assert len(snap["rallies"]) > 0
    assert len(snap["people"]) > 0
    assert len(snap["participation"]) > 0
    assert snap["table_counts"]["video_meta"] == 0
    assert snap["table_counts"]["video_actions"] == 0


async def test_full_snapshot_has_video_metadata():
    snap = await _get("full")
    assert len(snap["video_meta"]) > 0
    row = snap["video_meta"][0]
    assert "on_demand_url" in row  # URL only, never media bytes
    assert row["video_id"] is not None


async def test_canonical_person_identity_shape():
    snap = await _get("core")
    for p in snap["people"][:200]:
        assert p["person_id"].startswith(("person:account:", "person:driver:", "person:codriver:"))
    # At least one account-merged identity exists.
    assert any(p["person_id"].startswith("person:account:") for p in snap["people"])


async def test_no_secrets_or_pii_leaked():
    snap = await _get("core")
    blob = json.dumps(snap).lower()
    for forbidden in ("password", "db_host", "secret", "api_key", "@gmail", "@hotmail"):
        assert forbidden not in blob, f"snapshot leaked '{forbidden}'"


async def test_final_results_and_wins_consistent():
    snap = await _get("core")
    # Every driver_wins row has a positive win_count and appears as a P1 in final_results
    # (by driver_id) when it has a driver_id.
    p1_driver_ids = {
        r["driver_id"] for r in snap["final_results"] if r["pos_overall"] == 1 and r["driver_id"]
    }
    for w in snap["driver_wins"]:
        assert w["win_count"] > 0
        if w["driver_id"]:
            assert w["driver_id"] in p1_driver_ids
