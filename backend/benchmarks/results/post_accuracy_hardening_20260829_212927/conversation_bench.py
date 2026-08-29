"""Deterministic conversation benchmark for ACC-1/3/4/6 (no LLM calls).

Each turn feeds a prebuilt SearchQuery (what QU would emit, including the KNOWN
buggy outputs the ACC fixes are meant to correct) into the real
ConversationalSearchService with the live DB, threading the session across turns.
Scores complete-flow success.
"""
from __future__ import annotations
import asyncio, json, sys
from typing import Any

from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.warmup import get_shared_entity_search_service
from app.query_understanding.context import SearchContext
from app.query_understanding.models import QueryUnderstandingResult
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService


class SeqParser(QueryUnderstandingService):
    def __init__(self, q: SearchQuery):
        self._q = q
    async def parse(self, natural_language_query, *, language=None, context=None):
        return QueryUnderstandingResult(query=self._q, provider="bench", model="direct",
                                        prompt_version="v1", schema_version="v1", few_shot_version="v1")


def Q(**kw) -> SearchQuery:
    return SearchQuery(**kw)


# Each flow: list of turns (raw_text, prebuilt_query, checker(result)->(ok,note))
FLOWS: dict[str, list[tuple[str, SearchQuery, Any]]] = {
    "A_videos_from_that_rally": [
        ("Show Rally Aluksne", Q(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Rally Aluksne"]),
         lambda r: (r.search_plan and r.search_plan.strategy.value == "RALLIES", "turn1 rallies")),
        # BUGGY model output: SEARCH_RALLIES for a video follow-up (ACC-1 must correct)
        ("show videos from that rally", Q(intent=SearchIntent.SEARCH_RALLIES),
         lambda r: (r.resolved_query and r.resolved_query.intent == SearchIntent.SEARCH_VIDEO_ACTIONS
                    and r.search_plan and r.search_plan.strategy.value == "VIDEO_ACTIONS", "ACC-1 -> VIDEO_ACTIONS")),
    ],
    "B_jump_highlights_from_that_rally": [
        ("Show Rally Aluksne", Q(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Rally Aluksne"]),
         lambda r: (True, "")),
        ("show jump highlights from that rally", Q(intent=SearchIntent.SEARCH_RALLIES),
         lambda r: (r.resolved_query.intent == SearchIntent.SEARCH_VIDEO_ACTIONS
                    and "jump" in r.resolved_query.action_types, "ACC-1 jump preserved")),
    ],
    "C_who_won_it": [
        ("Show Rally Aluksne", Q(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Rally Aluksne"]),
         lambda r: (True, "")),
        # BUGGY: pronoun, empty rally (ACC-4 must reuse active rally, not clarify)
        ("who won it?", Q(intent=SearchIntent.GET_RALLY_RESULTS),
         lambda r: (not r.requires_clarification and r.search_plan
                    and r.search_plan.strategy.value == "RALLY_RESULTS", "ACC-4 reuse active rally")),
    ],
    "D_driver_year_refine": [
        ("Show Max Freeman's rallies", Q(intent=SearchIntent.SEARCH_DRIVER_RALLIES, driver_names=["Max Freeman"]),
         lambda r: (not r.requires_clarification and r.referents.active_driver_id is not None, "ACC-3 driver id pinned")),
        ("what about 2025?", Q(intent=SearchIntent.SEARCH_DRIVER_RALLIES, driver_names=["Max Freeman"], years=[2025]),
         lambda r: (not r.requires_clarification and 2025 in r.resolved_query.years, "year refine, driver kept")),
    ],
    "E_show_his_videos": [
        ("Show Max Freeman's rallies", Q(intent=SearchIntent.SEARCH_DRIVER_RALLIES, driver_names=["Max Freeman"]),
         lambda r: (r.referents.active_driver_id is not None, "ACC-3 id set turn1")),
        ("show his videos", Q(intent=SearchIntent.SEARCH_DRIVER_VIDEOS, driver_names=["Max Freeman"]),
         lambda r: (not r.requires_clarification and r.search_plan
                    and r.search_plan.strategy.value == "DRIVER_VIDEOS"
                    and len(r.search_plan.driver_ids) > 0, "ACC-3 canonical driver reused")),
    ],
    "F_rallies_in_ireland_stays": [
        ("Show Rally Aluksne", Q(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Rally Aluksne"]),
         lambda r: (True, "")),
        # New unrelated rally-country search: must NOT become video, must NOT leak stale rally
        ("Rallies in Ireland", Q(intent=SearchIntent.SEARCH_RALLIES, countries=["Ireland"]),
         lambda r: (r.resolved_query.intent == SearchIntent.SEARCH_RALLIES
                    and r.search_plan.strategy.value == "RALLIES", "ACC-1 not triggered; rally search")),
    ],
    "G_latest_referent_wins": [
        ("Show Rally Aluksne", Q(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Rally Aluksne"]),
         lambda r: (True, "")),
        ("Show Donegal test rally", Q(intent=SearchIntent.SEARCH_RALLIES, rally_names=["Donegal test rally 15th"]),
         lambda r: (True, "")),
        ("show videos from that rally", Q(intent=SearchIntent.SEARCH_RALLIES),
         lambda r: (r.resolved_query.intent == SearchIntent.SEARCH_VIDEO_ACTIONS
                    and any("donegal" in n.lower() for n in r.resolved_query.target_rally_names), "latest (Donegal) wins")),
    ],
    "J_driver_only_who_won": [
        ("Show Max Freeman's rallies", Q(intent=SearchIntent.SEARCH_DRIVER_RALLIES, driver_names=["Max Freeman"]),
         lambda r: (True, "")),
        # who won it? with NO active rally -> must clarify (missing rally), NOT misuse driver as rally
        ("who won it?", Q(intent=SearchIntent.GET_RALLY_RESULTS),
         lambda r: (r.requires_clarification and not r.resolved_query, "ACC-4 does not misuse driver as rally")),
    ],
}


async def run_flow(name, turns, engine):
    session = SearchConversationSession()
    turn_notes = []
    ok_all = True
    async with engine.connect() as conn:
        svc = await get_shared_entity_search_service(conn)
        adapter = EntitySearchLookupAdapter(search_service=svc)
        for i, (raw, q, check) in enumerate(turns, 1):
            # fresh service per turn (own resolver/repo on this conn)
            service = ConversationalSearchService(
                query_parser=SeqParser(q),
                entity_resolver=DatabaseEntityResolver(repository=adapter),
                repository=SearchRepository(conn),
            )
            session, result = await service.search(raw, session=session)
            ok, note = check(result)
            wrong_confident = False  # evaluator: none of these expect wrong-confident
            ok_all = ok_all and ok
            turn_notes.append({
                "turn": i, "raw": raw, "ok": bool(ok), "note": note,
                "intent": result.resolved_query.intent.value if result.resolved_query else None,
                "plan": result.search_plan.strategy.value if result.search_plan else None,
                "clarify": result.requires_clarification,
                "active_driver_id": result.referents.active_driver_id,
            })
    return {"flow": name, "passed": ok_all, "turns": turn_notes}


async def main(out):
    engine = get_engine()
    results = []
    for name, turns in FLOWS.items():
        results.append(await run_flow(name, turns, engine))
    passed = sum(1 for r in results if r["passed"])
    summary = {"total_flows": len(results), "passed": passed, "failed": len(results) - passed,
               "flows": results}
    with open(f"{out}/conversation_results.json", "w") as f:
        json.dump(summary, f, indent=2)
    for r in results:
        print(("PASS" if r["passed"] else "FAIL"), r["flow"])
        for t in r["turns"]:
            if not t["ok"]:
                print("     turn", t["turn"], "FAILED:", t["note"], "| intent=", t["intent"], "plan=", t["plan"], "clarify=", t["clarify"])
    print(f"\nCONVERSATION: {passed}/{len(results)} flows passed")


asyncio.run(main(sys.argv[1]))
