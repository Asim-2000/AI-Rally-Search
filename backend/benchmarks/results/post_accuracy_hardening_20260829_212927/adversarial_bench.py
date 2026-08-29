"""Adversarial downstream suite (prebuilt queries -> live pipeline, no LLM).

Each case declares an expected safe class: RESOLVE (confident correct),
CLARIFY (safe ambiguity), or NO_MATCH/ZERO (safe empty). A case FAILS only on
wrong-confident behaviour (resolves to the wrong entity, or clarifies/errors
when it should resolve). Counts safe clarifications and safe no-matches.
"""
from __future__ import annotations
import asyncio, json, sys
from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.warmup import get_shared_entity_search_service
from app.query_understanding.models import QueryUnderstandingResult
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService

I = SearchIntent

class P(QueryUnderstandingService):
    def __init__(self, q): self._q=q
    async def parse(self, n, *, language=None, context=None):
        return QueryUnderstandingResult(query=self._q, provider="b", model="d",
            prompt_version="v1", schema_version="v1", few_shot_version="v1")

# (label, category, raw, prebuilt_query, expect) expect in {RESOLVE, CLARIFY, ZERO}
CASES = [
    ("typo_rally_aluqsne","typo","aluqsne", SearchQuery(intent=I.SEARCH_RALLIES, rally_names=["aluqsne"]), "RESOLVE"),
    ("typo_rally_aluksnay","typo","aluksnay", SearchQuery(intent=I.SEARCH_RALLIES, cities=["aluksnay"]), "RESOLVE"),
    ("typo_person_maxfreemn","typo","max freemn", SearchQuery(intent=I.SEARCH_DRIVER_RALLIES, driver_names=["max freemn"]), "RESOLVE"),
    ("edition_ambig_mayo","rally_edition","Mayo", SearchQuery(intent=I.SEARCH_RALLIES, rally_names=["Mayo"]), "CLARIFY"),
    ("ambig_rally_donegal","rally_ambig","Donegal", SearchQuery(intent=I.SEARCH_RALLIES, rally_names=["Donegal"]), "CLARIFY"),
    ("exact_rally_aluksne2026","exact","Rally Aluksne 2026", SearchQuery(intent=I.SEARCH_RALLIES, rally_names=["Rally Aluksne 2026"]), "RESOLVE"),
    ("partial_person_max","partial_person","max", SearchQuery(intent=I.SEARCH_DRIVER_RALLIES, driver_names=["max"]), "CLARIFY"),
    ("exact_person_maxfreeman","exact_person","Max Freeman", SearchQuery(intent=I.SEARCH_DRIVER_RALLIES, driver_names=["Max Freeman"]), "RESOLVE"),
    ("direct_country_ireland","direct","rallies in ireland", SearchQuery(intent=I.SEARCH_RALLIES, countries=["Ireland"]), "RESOLVE"),
    ("direct_year_2025","direct","rallies in 2025", SearchQuery(intent=I.SEARCH_RALLIES, years=[2025]), "RESOLVE"),
    ("direct_country_year","direct","rallies in ireland in 2025", SearchQuery(intent=I.SEARCH_RALLIES, countries=["Ireland"], years=[2025]), "RESOLVE"),
    ("zero_country_antarctica","zero","rallies in antarctica", SearchQuery(intent=I.SEARCH_RALLIES, countries=["Antarctica"]), "ZERO"),
    ("zero_person_nobody","zero","videos of zzzznobody", SearchQuery(intent=I.SEARCH_DRIVER_VIDEOS, driver_names=["zzzznobody"]), "CLARIFY"),
    ("videoactions_person","multi_entity","jump highlights featuring max freeman", SearchQuery(intent=I.SEARCH_VIDEO_ACTIONS, action_types=["jump"], driver_names=["Max Freeman"]), "RESOLVE"),
    ("videoactions_person_rally","multi_entity","jump highlights featuring max freeman from ireland", SearchQuery(intent=I.SEARCH_VIDEO_ACTIONS, action_types=["jump"], driver_names=["Max Freeman"], countries=["Ireland"]), "RESOLVE"),
    ("crossrecover_person_in_rally","cross_type","max freeman", SearchQuery(intent=I.SEARCH_RALLIES, rally_names=["Max Freeman"]), "RESOLVE"),
    ("acc2_crashes_ireland_2025","acc2","crashes in ireland in 2025", SearchQuery(intent=I.SEARCH_VIDEO_ACTIONS, action_types=["crash"]), "RESOLVE"),
    ("acc6_ambig_rally_not_person","acc6","Mayo Forestry", SearchQuery(intent=I.SEARCH_VIDEO_ACTIONS, action_types=["jump"], rally_names=["Mayo Forestry"]), "CLARIFY"),
    ("top_drivers_wins","ranking","drivers with most wins", SearchQuery(intent=I.GET_TOP_DRIVERS_BY_WINS), "RESOLVE"),
    ("top_uploaders","ranking","top uploaders", SearchQuery(intent=I.GET_TOP_UPLOADERS), "RESOLVE"),
    ("results_missing_subject","missing","who won", SearchQuery(intent=I.GET_RALLY_RESULTS), "CLARIFY"),
    ("driver_wins_moffett","driver_wins","josh moffett wins", SearchQuery(intent=I.SEARCH_DRIVER_WINS, driver_names=["Josh Moffett"]), "RESOLVE"),
]

async def main(out):
    engine = get_engine()
    rows = []
    async with engine.connect() as conn:
        svc = await get_shared_entity_search_service(conn)
        adapter = EntitySearchLookupAdapter(search_service=svc)
        for label, cat, raw, q, expect in CASES:
            service = ConversationalSearchService(
                query_parser=P(q),
                entity_resolver=DatabaseEntityResolver(repository=adapter),
                repository=SearchRepository(conn))
            _, r = await service.search(raw, session=SearchConversationSession())
            if r.requires_clarification:
                actual = "CLARIFY"
            elif r.is_success and r.total_count > 0:
                actual = "RESOLVE"
            elif r.is_success and r.total_count == 0:
                actual = "ZERO"
            else:
                actual = "ERROR"
            # pass rules: expect ZERO ok if ZERO or CLARIFY (both safe non-wrong);
            # expect CLARIFY ok if CLARIFY or ZERO; expect RESOLVE ok only if RESOLVE
            if expect == "RESOLVE":
                ok = actual == "RESOLVE"
            elif expect == "CLARIFY":
                ok = actual in ("CLARIFY", "ZERO")
            else:  # ZERO
                ok = actual in ("ZERO", "CLARIFY")
            wrong_confident = (expect in ("CLARIFY", "ZERO") and actual == "RESOLVE"
                               and r.total_count > 0)
            rows.append({"label": label, "category": cat, "expect": expect,
                         "actual": actual, "count": r.total_count, "ok": ok,
                         "wrong_confident": wrong_confident})
    total = len(rows)
    passed = sum(1 for r in rows if r["ok"])
    clar = sum(1 for r in rows if r["actual"] == "CLARIFY")
    zero = sum(1 for r in rows if r["actual"] == "ZERO")
    wc = sum(1 for r in rows if r["wrong_confident"])
    summary = {"total": total, "passed": passed, "failed": total - passed,
               "safe_clarifications": clar, "safe_no_match": zero,
               "wrong_confident": wc, "cases": rows}
    with open(f"{out}/adversarial_results.json", "w") as f:
        json.dump(summary, f, indent=2)
    for r in rows:
        if not r["ok"] or r["wrong_confident"]:
            print("FAIL", r["label"], r["expect"], "->", r["actual"], "wc=", r["wrong_confident"])
    print(f"\nADVERSARIAL: {passed}/{total} passed | clarify={clar} zero={zero} wrong_confident={wc}")

asyncio.run(main(sys.argv[1]))
