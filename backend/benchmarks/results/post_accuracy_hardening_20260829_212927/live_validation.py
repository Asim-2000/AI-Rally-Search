"""Small LIVE integration sanity check: real Gemini Flash-Lite -> current
downstream -> live MySQL. NOT for model selection. ~28 queries incl. the
documented ACC examples and multi-turn conversation flows."""
from __future__ import annotations
import asyncio, json, sys, time, statistics

from app.config import get_settings
from app.api.v1.conversation import _build_query_service
from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.warmup import get_shared_entity_search_service
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService

# Single-turn queries (label, raw)
SINGLE = [
    ("acc_docs", "show me jump highlights featuring max freeman"),
    ("acc_docs", "show me jump highlights from karl martin from rally ireland"),
    ("acc2", "crashes in ireland in 2025"),
    ("direct", "rallies in ireland"),
    ("direct", "rallies in ireland in 2025"),
    ("typo_rally", "rally aluqsne"),
    ("ambig_rally", "rally donegl"),
    ("results", "who won rally aluksne"),
    ("finishers", "top 10 finishers rally aluksne"),
    ("ranking", "drivers with the most wins"),
    ("uploaders", "top uploaders for rally aluksne"),
    ("driver_rallies", "which rallies did max freeman compete in"),
    ("driver_wins", "which rallies did josh moffett win"),
    ("exact_rally", "Rally Alūksne 2026"),
    ("typo_person", "videos featuring max freemn"),
    ("zero", "rallies in antarctica"),
    ("multi", "show jump highlights featuring max freeman in ireland"),
]

# Multi-turn conversation flows
FLOWS = [
    ("conv_videos_from_that", ["Show Rally Aluksne", "show videos from that rally", "who won it?"]),
    ("conv_driver_videos", ["Show Max Freeman's rallies", "show his videos"]),
    ("conv_year_refine", ["Show Max Freeman's rallies", "what about 2025?"]),
    ("conv_replace_country", ["Show Rally Aluksne", "rallies in Ireland"]),
]


def classify(r):
    if r.special_response_category:
        return "SPECIAL"
    if r.requires_clarification:
        return "CLARIFY"
    if r.is_success and r.total_count > 0:
        return "RESOLVE"
    if r.is_success and r.total_count == 0:
        return "ZERO"
    return "ERROR"


async def main(out):
    settings = get_settings()
    engine = get_engine()
    rows = []
    calls = 0
    lat = []
    async with engine.connect() as conn:
        svc = await get_shared_entity_search_service(conn)
        adapter = EntitySearchLookupAdapter(search_service=svc)

        async def one(label, raw, session):
            nonlocal calls
            parser = _build_query_service(settings)  # REAL Gemini
            service = ConversationalSearchService(
                query_parser=parser,
                entity_resolver=DatabaseEntityResolver(repository=adapter),
                repository=SearchRepository(conn))
            t = time.perf_counter()
            new_session, r = await service.search(raw, session=session)
            ms = (time.perf_counter() - t) * 1000.0
            calls += 1
            lat.append(ms)
            return new_session, r, ms

        for label, raw in SINGLE:
            session = SearchConversationSession()
            try:
                _, r, ms = await one(label, raw, session)
                rows.append({"label": label, "raw": raw, "turn": 1,
                             "outcome": classify(r), "count": r.total_count,
                             "intent": r.resolved_query.intent.value if r.resolved_query else None,
                             "plan": r.search_plan.strategy.value if r.search_plan else None,
                             "clar_q": r.clarification_question, "latency_ms": round(ms, 1),
                             "neutralized": r.neutralized_temporal_filters})
            except Exception as e:
                rows.append({"label": label, "raw": raw, "outcome": "EXCEPTION", "error": str(e)[:200]})

        for fname, turns in FLOWS:
            session = SearchConversationSession()
            for i, raw in enumerate(turns, 1):
                try:
                    session, r, ms = await one(fname, raw, session)
                    rows.append({"label": fname, "raw": raw, "turn": i,
                                 "outcome": classify(r), "count": r.total_count,
                                 "intent": r.resolved_query.intent.value if r.resolved_query else None,
                                 "plan": r.search_plan.strategy.value if r.search_plan else None,
                                 "clar_q": r.clarification_question, "latency_ms": round(ms, 1)})
                except Exception as e:
                    rows.append({"label": fname, "raw": raw, "turn": i, "outcome": "EXCEPTION", "error": str(e)[:200]})

    with open(f"{out}/live_validation_results.jsonl", "w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")

    outcomes = [r["outcome"] for r in rows]
    from collections import Counter
    c = Counter(outcomes)
    p50 = round(statistics.median(lat), 1) if lat else None
    p95 = round(sorted(lat)[int(len(lat) * 0.95)], 1) if len(lat) > 1 else None
    est_cost = round(calls * 0.000326, 6)
    summary = {"calls": calls, "outcomes": dict(c), "p50_ms": p50, "p95_ms": p95,
               "est_cost_usd": est_cost, "exceptions": c.get("EXCEPTION", 0)}
    print(json.dumps(summary, indent=2))
    for r in rows:
        print(f"  [{r['outcome']:8}] t{r.get('turn','?')} {r['raw'][:52]:54} "
              f"intent={r.get('intent')} plan={r.get('plan')} n={r.get('count')}"
              + (f" clar={r.get('clar_q')!r}" if r.get('outcome') == 'CLARIFY' else ""))
    with open(f"{out}/live_summary.json", "w") as f:
        json.dump(summary, f, indent=2)

asyncio.run(main(sys.argv[1]))
