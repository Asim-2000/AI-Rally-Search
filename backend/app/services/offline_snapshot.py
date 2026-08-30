"""Offline snapshot builder.

Produces a compact, denormalised, read-only snapshot of public rally data for the
Flutter client to store in local SQLite (`sqflite`). This is the *only* data
channel to the device: MySQL access and precompute stay server-side, no DB
credentials or API secrets ever reach the client.

Design principles (see OFFLINE_SEARCH_ARCHITECTURE.md):

* Do **not** mirror MySQL. Ship exactly the columns the 9 offline execution
  strategies read.
* Pre-compute the aggregate/classification concerns server-side
  (`final_results`, `driver_wins`, `uploader_stats`) so the device never runs the
  `FINAL_STAGE` subquery or stores per-stage results.
* Preserve current production semantics: canonical person identity
  (`person:account:* | person:driver:* | person:codriver:*`), participation from
  `entry_list -> sub_event -> event` (never `rally_results`), final-stage
  classification for wins/results.
* Client-appropriate data only. No emails / PII / internal-only fields.

The module is split into a thin SQL data source (`load_snapshot_rows`) and pure
transform functions (`build_people`, `build_snapshot_payload`, ...) so the
transforms can be unit-tested deterministically without a live database.
"""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncConnection

# Bump SCHEMA_VERSION when the *shape* of the local DB changes (forces the client
# to re-bootstrap and rebuild). DATA_VERSION is derived from content below.
SCHEMA_VERSION = 1

# The finished snapshot tables, in dependency order.
SNAPSHOT_TABLES = (
    "rallies",
    "people",
    "stages",
    "participation",
    "final_results",
    "driver_wins",
    "uploader_stats",
    "video_meta",
    "video_actions",
)

CORE_TABLES = (
    "rallies",
    "people",
    "stages",
    "participation",
    "final_results",
    "driver_wins",
    "uploader_stats",
)

VIDEO_TABLES = ("video_meta", "video_actions")

# The FINAL_STAGE predicate, aliased for the standalone result queries below.
_FINAL_STAGE = """(rr.rally_id, CAST(stg.stage_number AS UNSIGNED)) IN (
 SELECT s2.event_id, MAX(CAST(s2.stage_number AS UNSIGNED)) FROM rally_stages s2
 JOIN rally_results r2 ON s2.stage_id=r2.stage_id AND s2.event_id=r2.rally_id
 GROUP BY s2.event_id)"""


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

def _s(value: Any) -> str | None:
    """Trim to a clean string or None (treating none/null sentinels as absent)."""
    if value is None:
        return None
    text_val = str(value).strip()
    if not text_val or text_val.lower() in ("none", "null"):
        return None
    return text_val


def _int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        s = str(value).strip()
        return int(s) if s.isdigit() else None


def _float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _iso(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    return _s(value)


# ---------------------------------------------------------------------------
# Pure transforms (unit-testable without a DB)
# ---------------------------------------------------------------------------

def build_rallies(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in rows:
        event_id = _s(row.get("event_id"))
        event_name = _s(row.get("event_name"))
        if not event_id or not event_name:
            continue
        out.append(
            {
                "event_id": event_id,
                "event_name": event_name,
                "country": _s(row.get("country")),
                "city": _s(row.get("city")),
                "year": _int(row.get("year")),
                "start_date": _iso(row.get("start_date")),
                "end_date": _iso(row.get("end_date")),
                "status": _s(row.get("status")),
                "stages_count": _int(row.get("stages_count")) or 0,
            }
        )
    out.sort(key=lambda r: r["event_id"])
    return out


def build_people(person_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Reproduces the canonical person identity used online.

    Mirrors `MySqlEntitySearchDataSource._load_with_conn`:
      * account present  -> person:account:<account_id> (merges driver+codriver)
      * null-account driver   -> person:driver:<driver_id>
      * null-account codriver -> person:codriver:<codriver_id>
    """
    people: list[dict[str, Any]] = []
    by_account: dict[str, dict[str, Any]] = {}

    for row in person_rows:
        account_id = _s(row.get("account_id"))
        profile_id = _s(row.get("profile_id"))
        profile_name = _s(row.get("full_name"))
        role = str(row.get("person_role") or "").strip()
        country = _s(row.get("country"))

        if not account_id:
            if not profile_id or not profile_name:
                continue
            is_driver = role == "driver"
            canonical_id = (
                f"person:driver:{profile_id}" if is_driver else f"person:codriver:{profile_id}"
            )
            people.append(
                {
                    "person_id": canonical_id,
                    "display_name": profile_name,
                    "name_norm": None,  # filled by caller/normalizer if desired
                    "searchable_names": json.dumps([profile_name]),
                    "role": "driver" if is_driver else "co_driver",
                    "driver_id": profile_id if is_driver else None,
                    "codriver_id": None if is_driver else profile_id,
                    "account_id": None,
                    "country": country,
                }
            )
            continue

        current = by_account.setdefault(
            account_id,
            {
                "country": country,
                "role": role,
                "driver_names": set(),
                "codriver_names": set(),
                "driver_id": None,
                "codriver_id": None,
            },
        )
        if role == "driver":
            current["driver_id"] = profile_id
            if profile_name:
                current["driver_names"].add(profile_name)
        else:
            current["codriver_id"] = profile_id
            if profile_name:
                current["codriver_names"].add(profile_name)
        if current["driver_id"] is not None and current["codriver_id"] is not None:
            current["role"] = "both"

    for account_id, data in by_account.items():
        driver_names = sorted(data["driver_names"], key=lambda s: s.lower())
        codriver_names = sorted(data["codriver_names"], key=lambda s: s.lower())
        searchable = sorted(set(driver_names) | set(codriver_names), key=lambda s: s.lower())
        display = driver_names[0] if driver_names else (codriver_names[0] if codriver_names else "")
        people.append(
            {
                "person_id": f"person:account:{account_id}",
                "display_name": display,
                "name_norm": None,
                "searchable_names": json.dumps(searchable),
                "role": data["role"],
                "driver_id": data["driver_id"],
                "codriver_id": data["codriver_id"],
                "account_id": account_id,
                "country": data["country"],
            }
        )

    people.sort(key=lambda r: r["person_id"])
    return people


def build_stages(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in rows:
        stage_id = _s(row.get("stage_id"))
        stage_name = _s(row.get("stage_name"))
        if not stage_id or not stage_name:
            continue
        out.append(
            {
                "stage_id": stage_id,
                "event_id": _s(row.get("event_id")),
                "stage_name": stage_name,
                "stage_number": _s(row.get("stage_number")),
            }
        )
    out.sort(key=lambda r: r["stage_id"])
    return out


def build_participation(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """One row per (event, competitor entry), matching the online
    `participations` projection (person_id = COALESCE(driver_id, codriver_id))."""
    seen: set[tuple] = set()
    out: list[dict[str, Any]] = []
    for row in rows:
        event_id = _s(row.get("event_id"))
        driver_id = _s(row.get("driver_id"))
        codriver_id = _s(row.get("codriver_id"))
        person_id = driver_id or codriver_id
        if not event_id or not person_id:
            continue
        has_driver = driver_id is not None
        has_codriver = codriver_id is not None
        if has_driver and has_codriver:
            role = "Driver / Co-Driver"
        elif has_codriver and not has_driver:
            role = "Co-Driver"
        else:
            role = "Driver"
        key = (event_id, person_id, role)
        if key in seen:
            continue
        seen.add(key)
        out.append(
            {
                "event_id": event_id,
                "person_id": person_id,
                "driver_id": driver_id,
                "codriver_id": codriver_id,
                "driver_name": _s(row.get("driver_name")) or "Competitor",
                "role": role,
            }
        )
    out.sort(key=lambda r: (r["event_id"], r["person_id"], r["role"]))
    return out


def build_final_results(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in rows:
        rid = _int(row.get("id"))
        event_id = _s(row.get("event_id"))
        pos = _int(row.get("pos_overall"))
        if rid is None or not event_id or pos is None:
            continue
        out.append(
            {
                "id": rid,
                "event_id": event_id,
                "driver_id": _s(row.get("driver_id")),
                "driver_name": _s(row.get("driver_name")) or "Driver",
                "pos_overall": pos,
            }
        )
    out.sort(key=lambda r: (r["event_id"], r["pos_overall"], r["id"]))
    return out


def build_driver_wins(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in rows:
        driver_id = _s(row.get("driver_id"))
        driver_name = _s(row.get("driver_name")) or "Driver"
        win_count = _int(row.get("win_count")) or 0
        person_id = driver_id or driver_name
        out.append(
            {
                "person_id": person_id,
                "driver_id": driver_id,
                "driver_name": driver_name,
                "win_count": win_count,
            }
        )
    out.sort(key=lambda r: (-r["win_count"], r["driver_name"]))
    return out


def build_uploader_stats(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Uploader aggregates. Deliberately drops the email fallback used online
    (`ua.email`) — display name only, no PII on device."""
    out: list[dict[str, Any]] = []
    for row in rows:
        uploader_id = _s(row.get("uploader_id"))
        if not uploader_id:
            continue
        name = _s(row.get("user_name")) or _s(row.get("full_name")) or "Rally Contributor"
        out.append(
            {
                "uploader_id": uploader_id,
                "account_id": _s(row.get("account_id")),
                "uploader_name": name,
                "upload_count": _int(row.get("upload_count")) or 0,
            }
        )
    out.sort(key=lambda r: (-r["upload_count"], r["uploader_id"]))
    return out


def build_video_meta(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in rows:
        video_id = _int(row.get("video_id"))
        if video_id is None:
            continue
        driver_id = _s(row.get("driver_id"))
        codriver_id = _s(row.get("codriver_id"))
        out.append(
            {
                "video_id": video_id,
                "event_id": _s(row.get("event_id")),
                "stage_id": _s(row.get("stage_id")),
                "person_id": driver_id or codriver_id,
                "driver_id": driver_id,
                "codriver_id": codriver_id,
                "driver_name": _s(row.get("driver_name")),
                "event_name": _s(row.get("event_name")),
                "stage_name": _s(row.get("stage_name")),
                "stage_number": _s(row.get("stage_number")),
                "thumbnail_url": _s(row.get("thumbnail_url")),
                "on_demand_url": _s(row.get("on_demand_url")),
                "length_seconds": _float(row.get("length_seconds")),
                "created_at": _iso(row.get("created_at")),
            }
        )
    out.sort(key=lambda r: -(r["video_id"]))
    return out


def build_video_actions(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in rows:
        rid = _int(row.get("id"))
        video_id = _int(row.get("video_id"))
        action_type = _s(row.get("action_type"))
        if rid is None or video_id is None or not action_type:
            continue
        driver_id = _s(row.get("driver_id"))
        codriver_id = _s(row.get("codriver_id"))
        out.append(
            {
                "id": rid,
                "video_id": video_id,
                "event_id": _s(row.get("event_id")),
                "stage_id": _s(row.get("stage_id")),
                "person_id": driver_id or codriver_id,
                "driver_id": driver_id,
                "codriver_id": codriver_id,
                "action_type": action_type,
                "action_type_id": _int(row.get("action_type_id")),
                "driver_name": _s(row.get("driver_name")),
                "event_name": _s(row.get("event_name")),
                "event_country": _s(row.get("event_country")),
                "stage_name": _s(row.get("stage_name")),
                "stage_number": _s(row.get("stage_number")),
                "start_action": _float(row.get("start_action")),
                "end_action": _float(row.get("end_action")),
                "points": _float(row.get("points")),
                "thumbnail_url": _s(row.get("thumbnail_url")),
                "on_demand_url": _s(row.get("on_demand_url")),
            }
        )
    out.sort(key=lambda r: -(r["id"]))
    return out


def compute_data_version(tables: dict[str, list[dict[str, Any]]]) -> str:
    """Deterministic content hash: identical data -> identical data_version."""
    hasher = hashlib.sha256()
    for name in SNAPSHOT_TABLES:
        rows = tables.get(name, [])
        hasher.update(name.encode("utf-8"))
        hasher.update(len(rows).to_bytes(8, "big"))
        payload = json.dumps(rows, sort_keys=True, separators=(",", ":"), default=str)
        hasher.update(payload.encode("utf-8"))
    return hasher.hexdigest()[:16]


def assemble_payload(
    tables: dict[str, list[dict[str, Any]]],
    *,
    segment: str,
    generated_at: datetime | None = None,
) -> dict[str, Any]:
    generated_at = generated_at or datetime.now(timezone.utc)
    data_version = compute_data_version(tables)
    snapshot_id = f"{SCHEMA_VERSION}-{data_version}-{segment}"
    payload: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "data_version": data_version,
        "snapshot_id": snapshot_id,
        "segment": segment,
        "generated_at": generated_at.isoformat(),
        "table_counts": {name: len(tables.get(name, [])) for name in SNAPSHOT_TABLES},
    }
    for name in SNAPSHOT_TABLES:
        payload[name] = tables.get(name, [])
    return payload


# ---------------------------------------------------------------------------
# SQL data source
# ---------------------------------------------------------------------------

_RALLIES_SQL = """
SELECT ev.event_id, ev.event_name, ev.status, ev.country, ev.city,
       ev.start_date, ev.end_date,
       COALESCE(ev.stages_count, COUNT(DISTINCT stg.stage_id), 0) AS stages_count,
       COALESCE(YEAR(ev.start_date), YEAR(ev.end_date)) AS year
FROM rally_events ev
LEFT JOIN rally_stages stg ON ev.event_id = stg.event_id
WHERE ev.event_name IS NOT NULL AND TRIM(ev.event_name) <> ''
GROUP BY ev.event_id, ev.event_name, ev.status, ev.country, ev.city,
         ev.start_date, ev.end_date, ev.stages_count
"""

_PEOPLE_SQL = """
SELECT account_id, driver_id AS profile_id, full_name, country, 'driver' AS person_role
FROM user_driver_profile
WHERE driver_id IS NOT NULL AND full_name IS NOT NULL AND TRIM(full_name) <> ''
UNION ALL
SELECT account_id, codriver_id AS profile_id, full_name, country, 'co_driver' AS person_role
FROM user_codriver_profile
WHERE codriver_id IS NOT NULL AND full_name IS NOT NULL AND TRIM(full_name) <> ''
"""

_STAGES_SQL = """
SELECT stage_id, stage_name, stage_number, event_id
FROM rally_stages
WHERE stage_name IS NOT NULL AND TRIM(stage_name) <> ''
"""

_PARTICIPATION_SQL = """
SELECT se.event_id AS event_id,
       el.user_driver_id AS driver_id,
       el.user_co_driver_id AS codriver_id,
       COALESCE(dp.full_name, cdp.full_name, 'Competitor') AS driver_name
FROM rally_entry_list el
JOIN rally_sub_events se ON el.sub_event_id = se.sub_event_id
LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
LEFT JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
WHERE el.user_driver_id IS NOT NULL OR el.user_co_driver_id IS NOT NULL
"""

_FINAL_RESULTS_SQL = f"""
SELECT rr.id AS id, rr.rally_id AS event_id, rr.pos_overall,
       dp.driver_id AS driver_id, COALESCE(dp.full_name, rr.crew) AS driver_name
FROM rally_results rr
JOIN rally_stages stg ON rr.stage_id = stg.stage_id AND rr.rally_id = stg.event_id
LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
WHERE {_FINAL_STAGE} AND rr.pos_overall IS NOT NULL
"""

_DRIVER_WINS_SQL = f"""
SELECT dp.driver_id AS driver_id,
       COALESCE(dp.full_name, rr.crew) AS driver_name,
       COUNT(DISTINCT rr.rally_id) AS win_count
FROM rally_results rr
JOIN rally_events ev ON rr.rally_id = ev.event_id
JOIN rally_stages stg ON rr.stage_id = stg.stage_id
LEFT JOIN rally_entry_list el ON rr.entry_list_id = el.id
LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
WHERE rr.pos_overall = 1 AND {_FINAL_STAGE}
GROUP BY dp.driver_id, driver_name
"""

_UPLOADER_STATS_SQL = """
SELECT CAST(rv.uploader_user_id AS CHAR) AS uploader_id,
       CAST(fp.account_id AS CHAR) AS account_id,
       NULLIF(TRIM(ua.user_name), '') AS user_name,
       NULLIF(TRIM(fp.full_name), '') AS full_name,
       COUNT(rv.id) AS upload_count
FROM rally_videos rv
LEFT JOIN user_fan_profile fp ON rv.uploader_user_id = fp.fan_id
LEFT JOIN user_account ua ON fp.account_id = ua.id
WHERE rv.uploader_user_id IS NOT NULL
GROUP BY rv.uploader_user_id, fp.account_id, ua.user_name, fp.full_name
"""

_VIDEO_META_SQL = """
SELECT rv.id AS video_id, MIN(rs.on_demand_url) AS on_demand_url,
       rv.thumbnail AS thumbnail_url,
       ev.event_id AS event_id, ev.event_name AS event_name,
       stg.stage_id AS stage_id, stg.stage_name AS stage_name, stg.stage_number AS stage_number,
       dp.driver_id AS driver_id, cdp.codriver_id AS codriver_id,
       COALESCE(dp.full_name, cdp.full_name) AS driver_name,
       rv.video_length_seconds AS length_seconds, rv.created_at AS created_at
FROM rally_videos rv
JOIN rally_video_metadata vm ON rv.id = vm.video_id
JOIN rally_entry_list el ON vm.entry_list_id = el.id
LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
LEFT JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
LEFT JOIN rally_streams rs ON rv.id = rs.video_id
LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
WHERE rs.on_demand_url IS NOT NULL AND rs.on_demand_url <> ''
  AND (rs.video_type IS NULL OR rs.video_type <> 'instantReplay')
GROUP BY rv.id, rv.thumbnail, ev.event_id, ev.event_name, stg.stage_id, stg.stage_name,
         stg.stage_number, dp.driver_id, cdp.codriver_id, dp.full_name, cdp.full_name,
         rv.video_length_seconds, rv.created_at
"""

_VIDEO_ACTIONS_SQL = """
SELECT vm.id AS id, vm.video_id AS video_id, va.id AS action_type_id, va.action_name AS action_type,
       MIN(rs.on_demand_url) AS on_demand_url, rv.thumbnail AS thumbnail_url,
       TIME_TO_SEC(vm.start_action) AS start_action, TIME_TO_SEC(vm.end_action) AS end_action,
       vm.points AS points,
       stg.stage_id AS stage_id, stg.stage_name AS stage_name, stg.stage_number AS stage_number,
       ev.event_id AS event_id, ev.event_name AS event_name, ev.country AS event_country,
       dp.driver_id AS driver_id, cdp.codriver_id AS codriver_id,
       COALESCE(dp.full_name, cdp.full_name) AS driver_name
FROM rally_video_metadata vm
JOIN rally_video_actions va ON vm.action_id = va.id
JOIN rally_streams rs ON vm.video_id = rs.video_id
LEFT JOIN rally_videos rv ON vm.video_id = rv.id
LEFT JOIN rally_stages stg ON rv.stage_id = stg.stage_id
LEFT JOIN rally_events ev ON stg.event_id = ev.event_id
LEFT JOIN rally_entry_list el ON vm.entry_list_id = el.id
LEFT JOIN user_driver_profile dp ON el.user_driver_id = dp.driver_id
LEFT JOIN user_codriver_profile cdp ON el.user_co_driver_id = cdp.codriver_id
WHERE rs.on_demand_url IS NOT NULL AND rs.on_demand_url <> ''
  AND (rs.video_type IS NULL OR rs.video_type <> 'instantReplay')
GROUP BY vm.id, vm.video_id, va.id, va.action_name, rv.thumbnail, vm.start_action, vm.end_action,
         vm.points, stg.stage_id, stg.stage_name, stg.stage_number, ev.event_id, ev.event_name,
         ev.country, dp.driver_id, cdp.codriver_id, dp.full_name, cdp.full_name
"""


async def _rows(conn: AsyncConnection, sql: str) -> list[dict[str, Any]]:
    result = await conn.execute(text(sql))
    return [dict(row) for row in result.mappings().all()]


async def build_snapshot(conn: AsyncConnection, *, segment: str = "full") -> dict[str, Any]:
    """Run the precompute SQL and assemble the client snapshot payload.

    `segment="core"` omits the (large) video metadata tables for a ~2-4 MB
    low-bandwidth bootstrap; `segment="full"` includes them.
    """
    segment = segment if segment in ("core", "full") else "full"

    tables: dict[str, list[dict[str, Any]]] = {}
    tables["rallies"] = build_rallies(await _rows(conn, _RALLIES_SQL))
    tables["people"] = build_people(await _rows(conn, _PEOPLE_SQL))
    tables["stages"] = build_stages(await _rows(conn, _STAGES_SQL))
    tables["participation"] = build_participation(await _rows(conn, _PARTICIPATION_SQL))
    tables["final_results"] = build_final_results(await _rows(conn, _FINAL_RESULTS_SQL))
    tables["driver_wins"] = build_driver_wins(await _rows(conn, _DRIVER_WINS_SQL))
    tables["uploader_stats"] = build_uploader_stats(await _rows(conn, _UPLOADER_STATS_SQL))

    if segment == "full":
        tables["video_meta"] = build_video_meta(await _rows(conn, _VIDEO_META_SQL))
        tables["video_actions"] = build_video_actions(await _rows(conn, _VIDEO_ACTIONS_SQL))
    else:
        tables["video_meta"] = []
        tables["video_actions"] = []

    return assemble_payload(tables, segment=segment)
