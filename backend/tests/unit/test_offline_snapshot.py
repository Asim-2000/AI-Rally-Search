"""Unit tests for the deterministic offline snapshot builders.

These exercise the pure transform layer with synthetic rows (no DB), covering
canonical person identity, participation truth, final-stage results, aggregates,
video linkage, secret/PII exclusion and deterministic versioning.
"""

import json

from app.services import offline_snapshot as S


def test_person_identity_account_authoritative():
    rows = [
        {"account_id": "acc-1", "profile_id": "drv-1", "full_name": "Max Freeman",
         "country": "Ireland", "person_role": "driver"},
        {"account_id": "acc-1", "profile_id": "cod-1", "full_name": "Max Freeman",
         "country": "Ireland", "person_role": "co_driver"},
    ]
    people = S.build_people(rows)
    assert len(people) == 1
    p = people[0]
    assert p["person_id"] == "person:account:acc-1"
    assert p["driver_id"] == "drv-1"
    assert p["codriver_id"] == "cod-1"
    assert p["role"] == "both"
    assert json.loads(p["searchable_names"]) == ["Max Freeman"]


def test_person_identity_null_account_driver_and_codriver():
    rows = [
        {"account_id": None, "profile_id": "drv-9", "full_name": "Solo Driver",
         "country": None, "person_role": "driver"},
        {"account_id": "", "profile_id": "cod-9", "full_name": "Solo Codriver",
         "country": None, "person_role": "co_driver"},
    ]
    people = {p["person_id"]: p for p in S.build_people(rows)}
    assert "person:driver:drv-9" in people
    assert "person:codriver:cod-9" in people
    assert people["person:driver:drv-9"]["driver_id"] == "drv-9"
    assert people["person:codriver:cod-9"]["codriver_id"] == "cod-9"


def test_participation_person_id_and_role():
    rows = [
        {"event_id": "ev1", "driver_id": "d1", "codriver_id": "c1", "driver_name": "Ann"},
        {"event_id": "ev1", "driver_id": None, "codriver_id": "c2", "driver_name": "Ben"},
        {"event_id": "ev1", "driver_id": "d3", "codriver_id": None, "driver_name": "Cara"},
        {"event_id": "ev1", "driver_id": None, "codriver_id": None, "driver_name": "Nobody"},
    ]
    part = {p["person_id"]: p for p in S.build_participation(rows)}
    assert part["d1"]["role"] == "Driver / Co-Driver"
    assert part["c2"]["role"] == "Co-Driver"
    assert part["d3"]["role"] == "Driver"
    assert "Nobody" not in [p["driver_name"] for p in part.values()]  # dropped: no person id


def test_final_results_shape():
    rows = [
        {"id": 5, "event_id": "ev1", "pos_overall": 1, "driver_id": "d1", "driver_name": "Ann"},
        {"id": 6, "event_id": "ev1", "pos_overall": None, "driver_id": "d2", "driver_name": "Ben"},
    ]
    out = S.build_final_results(rows)
    assert len(out) == 1  # None pos dropped
    assert out[0] == {"id": 5, "event_id": "ev1", "driver_id": "d1",
                      "driver_name": "Ann", "pos_overall": 1}


def test_driver_wins_person_id_fallback_and_order():
    rows = [
        {"driver_id": "d1", "driver_name": "Ann", "win_count": 2},
        {"driver_id": None, "driver_name": "Crew Only", "win_count": 3},
    ]
    out = S.build_driver_wins(rows)
    assert out[0]["win_count"] == 3  # sorted desc
    assert out[0]["person_id"] == "Crew Only"  # falls back to name when driver_id null
    assert out[1]["person_id"] == "d1"


def test_uploader_stats_excludes_email_pii():
    rows = [
        {"uploader_id": "42", "account_id": "9", "user_name": None, "full_name": None,
         "upload_count": 7},
    ]
    out = S.build_uploader_stats(rows)
    assert out[0]["uploader_name"] == "Rally Contributor"  # never email
    # No email field is ever emitted.
    assert "email" not in out[0]


def test_video_meta_person_id_and_url_only():
    rows = [
        {"video_id": 100, "event_id": "ev1", "stage_id": "s1", "driver_id": "d1",
         "codriver_id": None, "driver_name": "Ann", "event_name": "Rally X",
         "stage_name": "SS1", "stage_number": "1", "thumbnail_url": "http://t/1.jpg",
         "on_demand_url": "http://v/1.m3u8", "length_seconds": 61.0, "created_at": None},
    ]
    out = S.build_video_meta(rows)
    assert out[0]["person_id"] == "d1"
    assert out[0]["on_demand_url"] == "http://v/1.m3u8"


def test_no_secrets_or_pii_fields_in_payload():
    tables = {
        "rallies": S.build_rallies([
            {"event_id": "ev1", "event_name": "Rally X", "country": "Ireland",
             "city": "Cork", "year": 2025, "start_date": None, "end_date": None,
             "status": "completed", "stages_count": 3},
        ]),
        "people": S.build_people([
            {"account_id": "acc-1", "profile_id": "d1", "full_name": "Ann",
             "country": None, "person_role": "driver"},
        ]),
    }
    payload = S.assemble_payload(tables, segment="core")
    blob = json.dumps(payload).lower()
    for forbidden in ("password", "db_host", "secret", "api_key", "@", "email"):
        assert forbidden not in blob, f"snapshot leaked '{forbidden}'"


def test_snapshot_metadata_and_deterministic_version():
    tables = {"rallies": S.build_rallies([
        {"event_id": "ev1", "event_name": "Rally X", "country": "IE", "city": None,
         "year": 2025, "start_date": None, "end_date": None, "status": None,
         "stages_count": 1},
    ])}
    p1 = S.assemble_payload(tables, segment="core")
    p2 = S.assemble_payload(tables, segment="core")
    assert p1["schema_version"] == S.SCHEMA_VERSION
    assert p1["data_version"] == p2["data_version"]  # deterministic
    assert p1["snapshot_id"].endswith("-core")
    assert set(S.SNAPSHOT_TABLES).issubset(p1.keys())
    # Changing content changes data_version.
    tables2 = {"rallies": S.build_rallies([
        {"event_id": "ev2", "event_name": "Rally Y", "country": "PT", "city": None,
         "year": 2024, "start_date": None, "end_date": None, "status": None,
         "stages_count": 2},
    ])}
    assert S.assemble_payload(tables2, segment="core")["data_version"] != p1["data_version"]


def test_core_segment_omits_video_tables_in_counts():
    payload = S.assemble_payload({}, segment="core")
    assert payload["table_counts"]["video_meta"] == 0
    assert payload["table_counts"]["video_actions"] == 0
