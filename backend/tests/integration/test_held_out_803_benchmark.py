from __future__ import annotations

import json
from pathlib import Path
from typing import Any
import pytest
from app.db.engine import get_engine
from app.entity_search.candidate_generator import FullScanCandidateGenerator
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.models import EntitySearchRequest, SearchEntityType
from app.entity_search.service import InMemoryEntitySearchService


class _MetricsAccumulator:
    def __init__(self) -> None:
        self.cases = 0
        self.r1 = 0
        self.r5 = 0
        self.r10 = 0
        self.reciprocal_sum = 0.0

    def add(self, rank: int | None) -> None:
        self.cases += 1
        if rank is not None:
            if rank == 1:
                self.r1 += 1
            if rank <= 5:
                self.r5 += 1
            if rank <= 10:
                self.r10 += 1
            self.reciprocal_sum += 1.0 / rank

    def summary(self) -> dict[str, Any]:
        if self.cases == 0:
            return {"cases": 0, "recallAt1": 0.0, "recallAt5": 0.0, "recallAt10": 0.0, "mrr": 0.0}
        return {
            "cases": self.cases,
            "recallAt1": self.r1 / self.cases,
            "recallAt5": self.r5 / self.cases,
            "recallAt10": self.r10 / self.cases,
            "mrr": self.reciprocal_sum / self.cases,
        }


@pytest.mark.live_db
@pytest.mark.benchmark
async def test_held_out_803_benchmark():
    # 1. Load frozen 803 cases from Dart reference
    fixture_path = Path("/Users/asim/Documents/AHA Ventures AI/Pineamite/ai_rally_search/test/eval/entity_search/frozen_803_cases.json")
    assert fixture_path.exists(), "Frozen 803 fixture must exist"
    frozen_cases = json.loads(fixture_path.read_text())
    assert len(frozen_cases) == 803, f"Expected 803 frozen cases, found {len(frozen_cases)}"

    baseline_path = Path("/Users/asim/Documents/AHA Ventures AI/Pineamite/ai_rally_search/test/eval/entity_search/held_out_baseline_report.json")
    dart_baseline = json.loads(baseline_path.read_text()) if baseline_path.exists() else {}

    # 2. Build Python In-Memory Search Service from live DB
    engine = get_engine()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        entities = await source.load_entities()

    service = InMemoryEntitySearchService.from_entities(entities)
    full_scan_service = InMemoryEntitySearchService.from_entities(
        entities,
        candidate_generator=FullScanCandidateGenerator(),
    )

    type_map = {
        "rally": SearchEntityType.RALLY,
        "person": SearchEntityType.PERSON,
        "stage": SearchEntityType.STAGE,
        "uploader": SearchEntityType.UPLOADER,
    }

    metrics_indexed = {"overall": _MetricsAccumulator()}
    metrics_full_scan = {"overall": _MetricsAccumulator()}
    metrics_by_type: dict[str, _MetricsAccumulator] = {}
    metrics_by_difficulty: dict[str, _MetricsAccumulator] = {}

    case_records = []

    for idx, c in enumerate(frozen_cases):
        target_id = c["targetCanonicalId"]
        target_name = c["targetCanonicalName"]
        etype = type_map[c["entityType"]]
        input_str = c["input"]
        kind = c["corruptionKind"]
        diff = c["difficulty"]

        request = EntitySearchRequest(
            raw_mention=input_str,
            entity_type=etype,
            limit=10,
        )

        gen_res = service.candidate_generator.generate(request)
        new_candidates = await service.search(request)
        full_scan_candidates = await full_scan_service.search(request)

        indexed_rank = next(
            (i + 1 for i, cand in enumerate(new_candidates) if cand.canonical_id == target_id),
            None,
        )
        full_scan_rank = next(
            (i + 1 for i, cand in enumerate(full_scan_candidates) if cand.canonical_id == target_id),
            None,
        )

        target_in_pool = target_id in gen_res.canonical_ids
        pre_ranked_rank = (
            gen_res.pre_ranked_canonical_ids.index(target_id) + 1
            if target_id in gen_res.pre_ranked_canonical_ids
            else None
        )

        metrics_indexed["overall"].add(indexed_rank)
        metrics_full_scan["overall"].add(full_scan_rank)

        type_key = c["entityType"]
        if type_key not in metrics_by_type:
            metrics_by_type[type_key] = _MetricsAccumulator()
        metrics_by_type[type_key].add(indexed_rank)

        if diff not in metrics_by_difficulty:
            metrics_by_difficulty[diff] = _MetricsAccumulator()
        metrics_by_difficulty[diff].add(indexed_rank)

        top_score = new_candidates[0].score if new_candidates else 0.0
        runner_up_score = new_candidates[1].score if len(new_candidates) > 1 else 0.0
        gap = top_score - runner_up_score

        case_records.append({
            "caseId": f"case_{idx + 1}",
            "targetCanonicalId": target_id,
            "targetCanonicalName": target_name,
            "entityType": type_key,
            "inputMention": input_str,
            "corruptionKind": kind,
            "difficulty": diff,
            "targetPresentInPool": target_in_pool,
            "preRankedRank": pre_ranked_rank,
            "indexedRank": indexed_rank,
            "fullScanRank": full_scan_rank,
            "candidatePoolSize": len(gen_res.canonical_ids),
            "topCandidates": [cand.canonical_name for cand in new_candidates[:5]],
            "score": top_score,
            "scoreGap": gap,
            "fullScanEscape": gen_res.used_full_scan_escape,
        })

    report = {
        "totalCases": len(case_records),
        "metricsIndexed": {k: v.summary() for k, v in metrics_indexed.items()},
        "metricsFullScan": {k: v.summary() for k, v in metrics_full_scan.items()},
        "metricsByType": {k: v.summary() for k, v in metrics_by_type.items()},
        "metricsByDifficulty": {k: v.summary() for k, v in metrics_by_difficulty.items()},
        "dartReference": dart_baseline.get("retrievalMetrics", {}),
        "cases": case_records,
    }

    out_path = Path(__file__).parent / "py_held_out_803_report.json"
    out_path.write_text(json.dumps(report, indent=2))

    summary = metrics_indexed["overall"].summary()
    assert summary["cases"] == 803, f"Expected 803 cases, got {summary['cases']}"
    assert summary["recallAt1"] >= 0.88, f"R@1 {summary['recallAt1']} is below threshold 0.88"
    assert summary["recallAt5"] >= 0.99, f"R@5 {summary['recallAt5']} is below threshold 0.99"
    assert summary["recallAt10"] == 1.0, f"R@10 {summary['recallAt10']} must be 1.0"
    assert summary["mrr"] >= 0.93, f"MRR {summary['mrr']} is below threshold 0.93"
