import asyncio
import json
import statistics
import time
from pathlib import Path
import pytest

from app.db.engine import get_engine
from app.entity_search.candidate_generator import InvertedIndexCandidateGenerator
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.models import (
    EntitySearchRequest,
    SearchEntityType,
)
from app.entity_search.service import InMemoryEntitySearchService


@pytest.mark.live_db
@pytest.mark.benchmark
async def test_entity_search_performance_measurements():
    # =========================================================================
    # 1. INDEX STARTUP MEASUREMENT
    # =========================================================================
    engine = get_engine()
    t_start = time.perf_counter()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        t_db_start = time.perf_counter()
        entities = await source.load_entities()
        t_db_end = time.perf_counter()

    db_load_ms = (t_db_end - t_db_start) * 1000.0

    t_idx_start = time.perf_counter()
    service = InMemoryEntitySearchService.from_entities(entities)
    t_idx_end = time.perf_counter()

    index_build_ms = (t_idx_end - t_idx_start) * 1000.0
    total_startup_ms = (time.perf_counter() - t_start) * 1000.0

    startup_metrics = {
        "entityCount": len(entities),
        "dbLoadMs": round(db_load_ms, 2),
        "indexBuildMs": round(index_build_ms, 2),
        "totalStartupMs": round(total_startup_ms, 2),
    }

    # =========================================================================
    # 2. QUERY LATENCY BY TYPE (Candidate Generation, Scoring, Total)
    # =========================================================================
    eval_dir = Path("/Users/asim/Documents/AHA Ventures AI/Pineamite/ai_rally_search/test/eval/entity_search")
    cases803 = json.loads((eval_dir / "frozen_803_cases.json").read_text())

    by_type_queries: dict[SearchEntityType, list[str]] = {
        SearchEntityType.RALLY: [],
        SearchEntityType.PERSON: [],
        SearchEntityType.STAGE: [],
        SearchEntityType.UPLOADER: [],
    }

    for c in cases803:
        t_str = c["entityType"].lower()
        if t_str == "rally":
            by_type_queries[SearchEntityType.RALLY].append(c["input"])
        elif t_str in ("person", "driver", "co_driver"):
            by_type_queries[SearchEntityType.PERSON].append(c["input"])
        elif t_str == "stage":
            by_type_queries[SearchEntityType.STAGE].append(c["input"])
        elif t_str == "uploader":
            by_type_queries[SearchEntityType.UPLOADER].append(c["input"])

    type_latencies = {}

    def stats_dict(vals: list[float]) -> dict[str, float]:
        if not vals:
            return {"avg": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0}
        s = sorted(vals)
        p50_idx = int(len(s) * 0.50)
        p95_idx = int(len(s) * 0.95)
        return {
            "avg": round(statistics.mean(s), 2),
            "p50": round(s[min(p50_idx, len(s) - 1)], 2),
            "p95": round(s[min(p95_idx, len(s) - 1)], 2),
            "max": round(max(s), 2),
        }

    for entity_type, queries in by_type_queries.items():
        gen_ms_list = []
        score_ms_list = []
        total_ms_list = []

        # Warm up 5 queries
        for q in queries[:5]:
            await service.search(EntitySearchRequest(raw_mention=q, entity_type=entity_type, limit=10))

        for q in queries:
            req = EntitySearchRequest(raw_mention=q, entity_type=entity_type, limit=10)
            res = await service.search(req)
            stats = service.last_query_stats
            assert stats is not None
            gen_ms_list.append(stats.candidate_generation_latency.total_seconds() * 1000.0)
            score_ms_list.append(stats.scoring_latency.total_seconds() * 1000.0)
            total_ms_list.append(stats.latency.total_seconds() * 1000.0)

        type_latencies[entity_type.value.upper()] = {
            "queryCount": len(queries),
            "candidateGenerationMs": stats_dict(gen_ms_list),
            "scoringMs": stats_dict(score_ms_list),
            "totalMs": stats_dict(total_ms_list),
        }

    report = {
        "startup": startup_metrics,
        "queryLatency": type_latencies,
    }

    out_path = eval_dir / "py_performance_report.json"
    out_path.write_text(json.dumps(report, indent=2))
    print("Performance Report:", json.dumps(report, indent=2))
