"""Generate the offline execution-parity ORACLE from the authoritative online
pipeline (SearchPlanBuilder + SearchRepository over live MySQL).

For a curated set of *resolved* SearchQueries (concrete ids/filters) covering all
9 intents, dump the online SearchResponse rows. The Dart offline executor runs
the identical SearchQuery over the SQLite snapshot and must match canonical ids,
counts and (for ranked intents) ordering.

Usage: .venv/bin/python scripts/generate_offline_oracle.py
Writes: ../parity/offline/execution_oracle.jsonl
"""

import asyncio
import json
import os

from app.db.engine import get_engine
from app.domain.search_query import SearchQuery
from app.repositories.search_repository import SearchRepository
from app.services.search_plan_builder import SearchPlanBuilder

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "parity", "offline", "execution_oracle.jsonl")

# Anchors taken from the live snapshot (see inspection).
ALUKSNE = "0cea6942-72e3-4257-a8c1-0f8148747d82"        # Rally Alūksne 2026 (has final results)
DONEGAL_2026 = "a73dfca5-83b2-4f09-98f6-5d27ad749c81"   # Wilton Donegal International Rally 2026
FREEMAN_CODRIVER = "7a633b52-950e-49ef-8cab-34cd43e99366"
MOFFETT_DRIVER = "4e1a528d-0d6b-4aa3-bf06-27a27318fb70"  # Josh Moffett (1 win)

# name -> SearchQuery kwargs (resolved). Keep limits modest & deterministic.
CASES: list[tuple[str, dict]] = [
    ("rallies_ireland_2025", {"intent": "SEARCH_RALLIES", "countries": ["ireland"], "years": [2025], "limit": 50}),
    ("rallies_ireland_all", {"intent": "SEARCH_RALLIES", "countries": ["ireland"], "limit": 50}),
    ("rallies_portugal", {"intent": "SEARCH_RALLIES", "countries": ["portugal"], "limit": 50}),
    ("rallies_year_2026", {"intent": "SEARCH_RALLIES", "years": [2026], "limit": 100}),
    ("rally_aluksne_byid", {"intent": "SEARCH_RALLIES", "rally_names": [ALUKSNE], "limit": 20}),
    ("driver_rallies_freeman", {"intent": "SEARCH_DRIVER_RALLIES", "driver_ids": [FREEMAN_CODRIVER], "limit": 200}),
    ("driver_wins_moffett", {"intent": "SEARCH_DRIVER_WINS", "driver_ids": [MOFFETT_DRIVER], "limit": 50}),
    ("rally_results_aluksne", {"intent": "GET_RALLY_RESULTS", "rally_names": [ALUKSNE], "limit": 20}),
    ("rally_results_donegal", {"intent": "GET_RALLY_RESULTS", "rally_names": [DONEGAL_2026], "limit": 20}),
    ("top_finishers_aluksne", {"intent": "GET_RALLY_TOP_FINISHERS", "rally_names": [ALUKSNE], "limit": 300}),
    ("top_finishers_donegal", {"intent": "GET_RALLY_TOP_FINISHERS", "rally_names": [DONEGAL_2026], "limit": 300}),
    ("top_uploaders_global", {"intent": "GET_TOP_UPLOADERS", "limit": 10}),
    ("top_drivers_by_wins", {"intent": "GET_TOP_DRIVERS_BY_WINS", "limit": 10}),
    ("driver_videos_freeman", {"intent": "SEARCH_DRIVER_VIDEOS", "driver_ids": [FREEMAN_CODRIVER], "limit": 200}),
    ("video_actions_jumps", {"intent": "SEARCH_VIDEO_ACTIONS", "action_types": ["jump"], "limit": 25}),
    ("video_actions_crashes", {"intent": "SEARCH_VIDEO_ACTIONS", "action_types": ["crash"], "limit": 25}),
]


def _row_ids(intent: str, rows: list) -> list:
    out = []
    for r in rows:
        d = r.model_dump()
        if intent == "SEARCH_RALLIES":
            out.append({"event_id": d["event_id"]})
        elif intent in ("SEARCH_DRIVER_RALLIES", "SEARCH_DRIVER_WINS"):
            out.append({"rally_id": d["rally_id"], "person_id": d.get("person_id"), "pos_overall": d.get("pos_overall")})
        elif intent in ("GET_RALLY_RESULTS", "GET_RALLY_TOP_FINISHERS"):
            out.append({"rally_id": d["rally_id"], "driver_id": d.get("driver_id"), "pos_overall": d["pos_overall"]})
        elif intent == "SEARCH_VIDEO_ACTIONS":
            out.append({"id": d["id"], "video_id": d["video_id"], "action_type": d["action_type"]})
        elif intent == "SEARCH_DRIVER_VIDEOS":
            out.append({"video_id": d["video_id"]})
        elif intent == "GET_TOP_UPLOADERS":
            out.append({"uploader_id": d["uploader_id"], "upload_count": d["upload_count"]})
        elif intent == "GET_TOP_DRIVERS_BY_WINS":
            out.append({"person_id": d["person_id"], "win_count": d["win_count"]})
    return out


async def main():
    builder = SearchPlanBuilder()
    lines = []
    async with get_engine().connect() as conn:
        repo = SearchRepository(conn)
        for name, kwargs in CASES:
            q = SearchQuery(**kwargs)
            plan = builder.build(q)
            resp = await repo.search(plan)
            lines.append(json.dumps({
                "name": name,
                "query": q.model_dump(mode="json", by_alias=True),
                "intent": kwargs["intent"],
                "total_count": resp.total_count,
                "rows": _row_ids(kwargs["intent"], resp.results),
            }, default=str))
            print(f"{name:28s} intent={kwargs['intent']:24s} total={resp.total_count:5d} rows={len(resp.results)}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", OUT)


if __name__ == "__main__":
    asyncio.run(main())
