from __future__ import annotations

import json
from pathlib import Path
import pytest
from app.db.engine import get_engine
from app.domain.search_intent import SearchIntent
from app.domain.search_query import PersonRole, SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.fallback import (
    ControlledFallbackEntityResolver,
    EntitySearchFallbackConfig,
    EntitySearchFallbackMode,
)
from app.entity_search.models import EntitySearchRequest, EntityType, SearchEntityType
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService

KNOWN_TRANSCRIPTS = [
    {"phrase": "aluksni", "expected": "Rally Alūksne 2026", "type": EntityType.RALLY, "searchType": SearchEntityType.RALLY},
    {"phrase": "aluksnay", "expected": "Rally Alūksne 2026", "type": EntityType.RALLY, "searchType": SearchEntityType.RALLY},
    {"phrase": "a looks nay", "expected": "Rally Alūksne 2026", "type": EntityType.RALLY, "searchType": SearchEntityType.RALLY},
    {"phrase": "alux new", "expected": "Rally Alūksne 2026", "type": EntityType.RALLY, "searchType": SearchEntityType.RALLY},
    {"phrase": "eluksne", "expected": "Rally Alūksne 2026", "type": EntityType.RALLY, "searchType": SearchEntityType.RALLY},
    {"phrase": "aluknse", "expected": "Rally Alūksne 2026", "type": EntityType.RALLY, "searchType": SearchEntityType.RALLY},
    {"phrase": "aluksney", "expected": "Rally Alūksne 2026", "type": EntityType.RALLY, "searchType": SearchEntityType.RALLY},
    {"phrase": "pawel malgo", "expected": "Paweł Molgo", "type": EntityType.DRIVER, "searchType": SearchEntityType.PERSON},
    {"phrase": "shea brain", "expected": "Shea Breen", "type": EntityType.DRIVER, "searchType": SearchEntityType.PERSON},
    {"phrase": "donny gall", "expected": "Donegal International Rally", "type": EntityType.RALLY, "searchType": SearchEntityType.RALLY},
    {"phrase": "kemel berg", "expected": "Woodstoxx Kemmelberg 1", "type": EntityType.STAGE, "searchType": SearchEntityType.STAGE},
    {"phrase": "dushniki", "expected": "Duszniki - Zieleniec 2", "type": EntityType.STAGE, "searchType": SearchEntityType.STAGE},
]


class _DummyLegacyRepo:
    async def lookup_rallies(self, phrase, **kwargs): return []
    async def lookup_drivers(self, phrase, **kwargs): return []
    async def lookup_stages(self, phrase, **kwargs): return []
    async def lookup_cities(self, phrase, **kwargs): return []
    async def lookup_uploaders(self, phrase, **kwargs): return []


@pytest.mark.live_db
@pytest.mark.benchmark
async def test_known_difficult_transcripts():
    engine = get_engine()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        entities = await source.load_entities()

    service = InMemoryEntitySearchService.from_entities(entities)
    adapter = EntitySearchLookupAdapter(search_service=service, city_fallback=_DummyLegacyRepo())
    resolver = DatabaseEntityResolver(repository=adapter)
    controlled_resolver = ControlledFallbackEntityResolver(
        legacy_resolver=DatabaseEntityResolver(repository=_DummyLegacyRepo()),
        entity_search_resolver=resolver,
        config=EntitySearchFallbackConfig(mode=EntitySearchFallbackMode.FALLBACK),
    )

    rows = []
    for item in KNOWN_TRANSCRIPTS:
        phrase = item["phrase"]
        etype = item["type"]
        search_type = item["searchType"]
        expected = item["expected"]

        # 1. Raw Candidate Generation
        gen_res = service.candidate_generator.generate(
            EntitySearchRequest(raw_mention=phrase, entity_type=search_type, limit=10)
        )
        candidates = await service.search(
            EntitySearchRequest(raw_mention=phrase, entity_type=search_type, limit=5)
        )

        top_cand = candidates[0] if candidates else None
        top_name = top_cand.canonical_name if top_cand else "NONE"
        top_score = top_cand.score if top_cand else 0.0
        top_signals = top_cand.signals.to_map() if top_cand else {}

        # 2. End-to-End Fallback Resolver
        query = SearchQuery(
            intent=SearchIntent.SEARCH_RALLIES if etype == EntityType.RALLY else (
                SearchIntent.SEARCH_DRIVER_VIDEOS if etype == EntityType.DRIVER else SearchIntent.SEARCH_VIDEO_ACTIONS
            ),
            rally_names=[phrase] if etype == EntityType.RALLY else [],
            driver_names=[phrase] if etype == EntityType.DRIVER else [],
            stage_names=[phrase] if etype == EntityType.STAGE else [],
            person_role=PersonRole.ANY,
        )
        resolved_res = await controlled_resolver.resolve(query)
        res_cand = next(
            (r.resolved_candidate for r in resolved_res.resolutions.values() if r.is_resolved and r.resolved_candidate),
            None,
        )
        final_outcome = (
            f"RESOLVED: {res_cand.canonical_name}"
            if res_cand
            else (
                f"CLARIFICATION ({resolved_res.resolutions[list(resolved_res.resolutions.keys())[0]].strategy})"
                if resolved_res.requires_clarification
                else "NO_MATCH"
            )
        )

        if res_cand is not None:
            assert res_cand.canonical_name == expected, (
                f"wrong-confident resolution for {phrase!r}: "
                f"{res_cand.canonical_name!r} != {expected!r}"
            )

        rows.append({
            "transcriptPhrase": phrase,
            "targetExpected": expected,
            "entityType": etype.value,
            "generatedPoolSize": len(gen_res.canonical_ids),
            "usedFullScanEscape": gen_res.used_full_scan_escape,
            "topCandidateName": top_name,
            "topCandidateScore": round(top_score, 4),
            "tokenScore": top_signals.get("tokenScore", 0.0),
            "ngramScore": round(top_signals.get("ngramScore", 0.0), 4),
            "lexicalScore": round(top_signals.get("lexicalScore", 0.0), 4),
            "phoneticScore": round(top_signals.get("phoneticScore", 0.0), 4),
            "finalResolverOutcome": final_outcome,
        })

    report_path = Path(__file__).parent / "py_known_transcripts_report.json"
    report_path.write_text(json.dumps(rows, indent=2))

    assert len(rows) == len(KNOWN_TRANSCRIPTS)
