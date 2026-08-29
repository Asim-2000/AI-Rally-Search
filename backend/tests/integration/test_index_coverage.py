from __future__ import annotations

import json
import pytest
from sqlalchemy import text
from app.db.engine import get_engine
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.models import SearchEntityType
from app.entity_search.normalization import normalize


@pytest.mark.live_db
async def test_live_source_versus_index_coverage():
    engine = get_engine()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        entities = await source.load_entities()

        # Query raw profiles for audit
        profiles_res = await conn.execute(text("""
            SELECT 'driver' AS role, driver_id AS role_id, account_id, full_name, country
            FROM user_driver_profile
            UNION ALL
            SELECT 'co_driver' AS role, codriver_id AS role_id, account_id, full_name, country
            FROM user_codriver_profile;
        """))
        profiles = [dict(r._mapping) for r in profiles_res.fetchall()]

        stages_count_res = await conn.execute(text("SELECT COUNT(*) FROM rally_stages WHERE stage_name IS NOT NULL AND TRIM(stage_name) <> ''"))
        live_stages_count = stages_count_res.scalar()

        rallies_count_res = await conn.execute(text("SELECT COUNT(*) FROM rally_events WHERE event_name IS NOT NULL AND TRIM(event_name) <> ''"))
        live_rallies_count = rallies_count_res.scalar()

        uploaders_count_res = await conn.execute(text("SELECT COUNT(*) FROM user_fan_profile fp LEFT JOIN user_account ua ON ua.id = fp.account_id WHERE COALESCE(NULLIF(TRIM(ua.user_name), ''), NULLIF(TRIM(fp.full_name), ''), NULLIF(TRIM(ua.email), '')) IS NOT NULL"))
        live_uploaders_count = uploaders_count_res.scalar()

    def has_account(row: dict) -> bool:
        val = row.get("account_id")
        return val is not None and str(val).strip() != "" and str(val).strip().lower() != "null" and str(val).strip().lower() != "none"

    def has_name(row: dict) -> bool:
        val = row.get("full_name")
        return bool(val and str(val).strip())

    indexed_people = [e for e in entities if e.entity_type == SearchEntityType.PERSON]
    non_null_accounts = [r for r in profiles if has_account(r)]
    expected_account_ids = {str(r["account_id"]).strip() for r in non_null_accounts if has_name(r)}
    indexed_account_ids = {
        str(e.metadata.get("accountId")).strip()
        for e in indexed_people
        if e.metadata.get("accountId")
    }

    missing_account_ids = expected_account_ids - indexed_account_ids
    assert len(missing_account_ids) == 0, f"Missing account IDs: {missing_account_ids}"

    null_accounts = [r for r in profiles if not has_account(r)]
    null_legitimate = [r for r in null_accounts if has_name(r)]
    null_drivers = [r for r in null_legitimate if r["role"] == "driver"]
    null_codrivers = [r for r in null_legitimate if r["role"] == "co_driver"]

    expected_person_ids = (
        {f"person:account:{acc_id}" for acc_id in expected_account_ids}
        | {f"person:driver:{r['role_id']}" for r in null_drivers}
        | {f"person:codriver:{r['role_id']}" for r in null_codrivers}
    )
    indexed_person_ids = {e.canonical_id for e in indexed_people}
    missing_person_ids = expected_person_ids - indexed_person_ids
    assert len(missing_person_ids) == 0, f"Missing person IDs: {missing_person_ids}"

    assert len(indexed_people) == len(expected_person_ids)
    assert len([e for e in entities if e.entity_type == SearchEntityType.RALLY]) == live_rallies_count
    assert len([e for e in entities if e.entity_type == SearchEntityType.STAGE]) == live_stages_count
    assert len([e for e in entities if e.entity_type == SearchEntityType.UPLOADER]) == live_uploaders_count
    assert len(entities) == len(indexed_people) + live_rallies_count + live_stages_count + live_uploaders_count

    # Named traces for Paweł Molgo and Shea Breen
    pawel_entities = [e for e in indexed_people if normalize(e.canonical_name) == "pawel molgo"]
    assert len(pawel_entities) == 1
    assert pawel_entities[0].canonical_id.startswith("person:driver:")
    assert pawel_entities[0].metadata.get("identityKind") == "driver"

    shea_entities = [e for e in indexed_people if normalize(e.canonical_name) == "shea breen"]
    assert len(shea_entities) == 2
    shea_kinds = {e.metadata.get("identityKind") for e in shea_entities}
    assert shea_kinds == {"driver", "codriver"}
