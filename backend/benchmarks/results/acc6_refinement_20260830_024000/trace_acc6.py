"""Trace ACC-6 four cases: capture rally_res + driver_check internal signals."""
from __future__ import annotations
import asyncio, json, sys
from app.db.engine import get_engine
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.warmup import get_shared_entity_search_service
from app.domain.search_query import PersonRole

CASES = [
    ("act_0344", "Aaron Duville", []),
    ("act_0352", "Aaron Nau", []),
    ("nsy_0207", "Mayo Forestry", []),
    ("nsy_0208", "Mayo Stages", []),
]

def dump_res(res):
    return {
        "strategy": res.strategy,
        "confidence": round(res.confidence, 4),
        "is_ambiguous": res.is_ambiguous,
        "resolved": res.resolved_candidate.canonical_name if res.resolved_candidate else None,
        "options": [
            {"name": c.canonical_name, "score": round(c.score, 4),
             "baseScore": round(float((c.metadata or {}).get("baseScore", c.score)), 4),
             "type": c.type.value}
            for c in res.candidate_options[:5]
        ],
    }

async def main():
    eng = get_engine()
    async with eng.connect() as conn:
        svc = await get_shared_entity_search_service(conn)
        adapter = EntitySearchLookupAdapter(search_service=svc)
        resolver = DatabaseEntityResolver(repository=adapter)
        out = {}
        for cid, phrase, years in CASES:
            rally_res = await resolver._resolve_rally(phrase, years=years or None, is_video_search=True)
            driver_check = await resolver._resolve_driver(phrase, person_role=PersonRole.ANY)
            # also non-video rally resolution (for SEARCH_RALLIES cases)
            rally_res_nonvideo = await resolver._resolve_rally(phrase, years=years or None, is_video_search=False)
            out[cid] = {
                "phrase": phrase,
                "rally_res_video": dump_res(rally_res),
                "rally_res_nonvideo": dump_res(rally_res_nonvideo),
                "driver_check": dump_res(driver_check),
                "driver_top_conf": round(driver_check.confidence, 4),
                "min_conf_threshold": resolver.min_confidence_threshold,
            }
        print(json.dumps(out, indent=2, ensure_ascii=False))

asyncio.run(main())
