import hashlib
import json
import time
from pathlib import Path
import pytest
from sqlalchemy import text

from app.db.engine import get_engine
from app.domain.search_intent import SearchIntent
from app.domain.search_query import PersonRole, SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.candidate_generator import FullScanCandidateGenerator
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.fallback import (
    ControlledFallbackEntityResolver,
    EntitySearchFallbackConfig,
    EntitySearchFallbackMode,
)
from app.entity_search.models import (
    EntitySearchRequest,
    EntityType,
    SearchEntityType,
)
from app.entity_search.normalization import normalize
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.entity_search.telemetry import EntitySearchFallbackMetrics


@pytest.mark.live_db
@pytest.mark.benchmark
async def test_python_shared_fixture_benchmark_runner():
    # 1. Load entities from live MySQL DB
    engine = get_engine()
    async with engine.connect() as conn:
        source = MySqlEntitySearchDataSource(connection=conn)
        entities = await source.load_entities()

    indexed_service = InMemoryEntitySearchService.from_entities(entities)
    full_scan_service = InMemoryEntitySearchService.from_entities(
        entities,
        candidate_generator=FullScanCandidateGenerator(),
    )

    adapter = EntitySearchLookupAdapter(search_service=indexed_service)
    resolver = DatabaseEntityResolver(repository=adapter)
    fallback_metrics = EntitySearchFallbackMetrics()
    fallback_resolver = ControlledFallbackEntityResolver(
        legacy_resolver=resolver,  # in pure fallback parity, legacy = resolver
        entity_search_resolver=resolver,
        config=EntitySearchFallbackConfig(mode=EntitySearchFallbackMode.FALLBACK),
        metrics=fallback_metrics,
    )

    def parse_entity_type(type_str: str) -> SearchEntityType:
        t = type_str.lower()
        if t == "rally":
            return SearchEntityType.RALLY
        if t in ("person", "driver", "co_driver"):
            return SearchEntityType.PERSON
        if t == "stage":
            return SearchEntityType.STAGE
        if t == "uploader":
            return SearchEntityType.UPLOADER
        return SearchEntityType.PERSON

    def parse_person_role(role_str: str | None) -> PersonRole:
        if not role_str:
            return PersonRole.ANY
        r = role_str.lower()
        if r == "driver":
            return PersonRole.DRIVER
        if r in ("co_driver", "codriver"):
            return PersonRole.CO_DRIVER
        return PersonRole.ANY

    eval_dir = Path("/Users/asim/Documents/AHA Ventures AI/Pineamite/ai_rally_search/test/eval/entity_search")

    # =========================================================================
    # 1. RUN 803 SUITE (Indexed and Full Scan)
    # =========================================================================
    file803 = eval_dir / "frozen_803_cases.json"
    assert file803.exists(), "frozen_803_cases.json must exist"
    cases803 = json.loads(file803.read_text())
    assert len(cases803) == 803, "Exact 803 cases required"

    results803 = []
    r1_count_803, r5_count_803, r10_count_803 = 0, 0, 0
    reciprocal_sum_803 = 0.0
    escapes_803 = 0

    for idx, c in enumerate(cases803):
        case_id = c.get("caseId", f"case803_{idx}")
        target_id = c["targetCanonicalId"]
        target_name = c["targetCanonicalName"]
        type_ = parse_entity_type(c["entityType"])
        role = parse_person_role(c.get("personRole"))
        inp = c["input"]

        req = EntitySearchRequest(
            raw_mention=inp,
            entity_type=type_,
            person_role=role,
            limit=10,
        )

        generated = indexed_service.candidate_generator.generate(req)
        candidates = await indexed_service.search(req)
        stats = indexed_service.last_query_stats

        pool_size = len(generated.canonical_ids)
        target_present = target_id in generated.canonical_ids
        is_escape = stats.used_full_scan_escape if stats else False
        if is_escape:
            escapes_803 += 1

        target_rank = None
        for idx, cand in enumerate(candidates):
            if cand.canonical_id == target_id:
                target_rank = idx + 1
                break

        if target_rank == 1:
            r1_count_803 += 1
            r5_count_803 += 1
            r10_count_803 += 1
            reciprocal_sum_803 += 1.0
        elif target_rank is not None and target_rank <= 5:
            r5_count_803 += 1
            r10_count_803 += 1
            reciprocal_sum_803 += 1.0 / target_rank
        elif target_rank is not None and target_rank <= 10:
            r10_count_803 += 1
            reciprocal_sum_803 += 1.0 / target_rank

        top_score = candidates[0].score if candidates else 0.0
        second_score = candidates[1].score if len(candidates) > 1 else 0.0
        score_gap = top_score - second_score if candidates else 0.0

        if type_ == SearchEntityType.PERSON:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
                driver_names=[inp],
                person_role=role,
            )
        elif type_ == SearchEntityType.RALLY:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_RALLIES,
                rally_names=[inp],
            )
        else:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
                stage_names=[inp],
            )

        res_result = await resolver.resolve(query)
        primary_res = next(iter(res_result.resolutions.values()), None)

        if primary_res is None or (not primary_res.is_resolved and not primary_res.is_ambiguous):
            resolver_outcome = "NO_MATCH"
            resolver_reason = primary_res.strategy if primary_res else "no_resolution"
            selected_canonical_id = None
        elif primary_res.is_ambiguous or res_result.requires_clarification:
            resolver_outcome = "CLARIFICATION"
            resolver_reason = primary_res.strategy
            selected_canonical_id = None
        else:
            resolver_outcome = "RESOLVED"
            selected_canonical_id = primary_res.resolved_candidate.id if primary_res.resolved_candidate else None
            resolver_reason = primary_res.strategy

        results803.append({
            "caseId": case_id,
            "expectedCanonicalId": target_id,
            "expectedCanonicalName": target_name,
            "entityType": c["entityType"],
            "personRole": c.get("personRole"),
            "input": inp,
            "candidatePoolSize": pool_size,
            "targetPresent": target_present,
            "targetRank": target_rank,
            "topCandidates": [cand.canonical_id for cand in candidates],
            "resolverOutcome": resolver_outcome,
            "selectedCanonicalId": selected_canonical_id,
            "resolverReason": resolver_reason,
            "topScore": top_score,
            "scoreGap": score_gap,
            "fullScanEscape": is_escape,
            "escapeReason": "insufficient_candidates" if is_escape else None,
        })

    summary803 = {
        "cases": len(cases803),
        "recallAt1": r1_count_803 / len(cases803),
        "recallAt5": r5_count_803 / len(cases803),
        "recallAt10": r10_count_803 / len(cases803),
        "mrr": reciprocal_sum_803 / len(cases803),
        "fullScanEscapes": escapes_803,
        "results": results803,
    }
    (eval_dir / "py_803_results.json").write_text(json.dumps(summary803, indent=2))
    print(f"Python 803: R@1={summary803['recallAt1']} MRR={summary803['mrr']} escapes={escapes_803}")

    # =========================================================================
    # 2. RUN PERSON_FROZEN_1101 SUITE
    # =========================================================================
    file1101 = eval_dir / "frozen_1101_person_cases.json"
    assert file1101.exists(), "frozen_1101_person_cases.json must exist"
    cases1101 = json.loads(file1101.read_text())
    assert len(cases1101) == 1101, "Exact 1101 cases required"

    results1101 = []
    r1_count_1101, r5_count_1101, r10_count_1101 = 0, 0, 0
    reciprocal_sum_1101 = 0.0
    escapes_1101 = 0

    group_metrics = {
        "ACCOUNT_BACKED": {"cases": 0, "r1": 0, "r5": 0, "r10": 0, "mrr": 0.0},
        "NULL_DRIVER": {"cases": 0, "r1": 0, "r5": 0, "r10": 0, "mrr": 0.0},
        "NULL_CODRIVER": {"cases": 0, "r1": 0, "r5": 0, "r10": 0, "mrr": 0.0},
    }

    for c in cases1101:
        case_id = c["caseId"]
        group = c["group"]
        target_id = c["targetCanonicalId"]
        target_name = c["targetCanonicalName"]
        role = parse_person_role(c.get("personRole"))
        inp = c["input"]

        req = EntitySearchRequest(
            raw_mention=inp,
            entity_type=SearchEntityType.PERSON,
            person_role=role,
            limit=10,
        )

        generated = indexed_service.candidate_generator.generate(req)
        candidates = await indexed_service.search(req)
        stats = indexed_service.last_query_stats

        pool_size = len(generated.canonical_ids)
        target_present = target_id in generated.canonical_ids
        is_escape = stats.used_full_scan_escape if stats else False
        if is_escape:
            escapes_1101 += 1

        target_rank = None
        for idx, cand in enumerate(candidates):
            if cand.canonical_id == target_id:
                target_rank = idx + 1
                break

        gm = group_metrics[group]
        gm["cases"] += 1

        if target_rank == 1:
            r1_count_1101 += 1
            r5_count_1101 += 1
            r10_count_1101 += 1
            reciprocal_sum_1101 += 1.0
            gm["r1"] += 1
            gm["r5"] += 1
            gm["r10"] += 1
            gm["mrr"] += 1.0
        elif target_rank is not None and target_rank <= 5:
            r5_count_1101 += 1
            r10_count_1101 += 1
            reciprocal_sum_1101 += 1.0 / target_rank
            gm["r5"] += 1
            gm["r10"] += 1
            gm["mrr"] += 1.0 / target_rank
        elif target_rank is not None and target_rank <= 10:
            r10_count_1101 += 1
            reciprocal_sum_1101 += 1.0 / target_rank
            gm["r10"] += 1
            gm["mrr"] += 1.0 / target_rank

        top_score = candidates[0].score if candidates else 0.0
        second_score = candidates[1].score if len(candidates) > 1 else 0.0
        score_gap = top_score - second_score if candidates else 0.0

        query = SearchQuery(
            intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
            driver_names=[inp],
            person_role=role,
        )

        res_result = await resolver.resolve(query)
        primary_res = next(iter(res_result.resolutions.values()), None)

        if primary_res is None or (not primary_res.is_resolved and not primary_res.is_ambiguous):
            resolver_outcome = "NO_MATCH"
            resolver_reason = primary_res.strategy if primary_res else "no_resolution"
            selected_canonical_id = None
        elif primary_res.is_ambiguous or res_result.requires_clarification:
            resolver_outcome = "CLARIFICATION"
            resolver_reason = primary_res.strategy
            selected_canonical_id = None
        else:
            resolver_outcome = "RESOLVED"
            selected_canonical_id = primary_res.resolved_candidate.id if primary_res.resolved_candidate else None
            resolver_reason = primary_res.strategy

        results1101.append({
            "caseId": case_id,
            "group": group,
            "expectedCanonicalId": target_id,
            "expectedCanonicalName": target_name,
            "entityType": "person",
            "personRole": c.get("personRole"),
            "input": inp,
            "candidatePoolSize": pool_size,
            "targetPresent": target_present,
            "targetRank": target_rank,
            "topCandidates": [cand.canonical_id for cand in candidates],
            "resolverOutcome": resolver_outcome,
            "selectedCanonicalId": selected_canonical_id,
            "resolverReason": resolver_reason,
            "topScore": top_score,
            "scoreGap": score_gap,
            "fullScanEscape": is_escape,
            "escapeReason": "insufficient_candidates" if is_escape else None,
        })

    summary1101 = {
        "cases": len(cases1101),
        "recallAt1": r1_count_1101 / len(cases1101),
        "recallAt5": r5_count_1101 / len(cases1101),
        "recallAt10": r10_count_1101 / len(cases1101),
        "mrr": reciprocal_sum_1101 / len(cases1101),
        "byGroup": {
            k: {
                "cases": v["cases"],
                "recallAt1": v["r1"] / v["cases"],
                "recallAt5": v["r5"] / v["cases"],
                "recallAt10": v["r10"] / v["cases"],
                "mrr": v["mrr"] / v["cases"],
            }
            for k, v in group_metrics.items()
        },
        "results": results1101,
    }
    (eval_dir / "py_1101_person_results.json").write_text(json.dumps(summary1101, indent=2))
    print(f"Python 1101: R@1={summary1101['recallAt1']} MRR={summary1101['mrr']}")

    # =========================================================================
    # 3. RUN 168 SAFETY SUITE
    # =========================================================================
    file168 = eval_dir / "frozen_168_safety_cases.json"
    assert file168.exists(), "frozen_168_safety_cases.json must exist"
    cases168 = json.loads(file168.read_text())
    assert len(cases168) == 168, "Exact 168 cases required"

    results168 = []
    correct_confident_168 = 0
    wrong_positive_confident_168 = 0
    positive_clarification_168 = 0
    positive_no_match_168 = 0
    negative_wrong_confident_168 = 0
    negative_clarification_168 = 0
    negative_rejection_168 = 0

    for c in cases168:
        case_id = c["caseId"]
        category = c["category"]
        inp = c["input"]
        expected_name = c.get("expectedCanonicalName")
        type_ = parse_entity_type(c["entityType"])
        role = parse_person_role(c.get("personRole"))

        if type_ == SearchEntityType.PERSON:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
                driver_names=[inp],
                person_role=role,
            )
        elif type_ == SearchEntityType.RALLY:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_RALLIES,
                rally_names=[inp],
            )
        else:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
                stage_names=[inp],
            )

        result = await fallback_resolver.resolve(query)
        primary = next(iter(result.resolutions.values()), None)
        resolved_name = primary.resolved_candidate.canonical_name if primary and primary.resolved_candidate else None
        is_clarification = result.requires_clarification or (primary.is_ambiguous if primary else False)
        is_resolved = primary is not None and primary.is_resolved and resolved_name is not None

        if is_resolved:
            outcome = "RESOLVED"
        elif is_clarification:
            outcome = "CLARIFICATION"
        else:
            outcome = "NO_MATCH"

        if category == "positive":
            same_target = bool(
                resolved_name and expected_name and (
                    normalize(resolved_name) == normalize(expected_name)
                    or resolved_name in expected_name
                    or expected_name in resolved_name
                )
            )
            if is_resolved and same_target:
                correct_confident_168 += 1
            elif is_resolved:
                wrong_positive_confident_168 += 1
            elif is_clarification:
                positive_clarification_168 += 1
            else:
                positive_no_match_168 += 1
        else:
            if is_resolved:
                negative_wrong_confident_168 += 1
            elif is_clarification:
                negative_clarification_168 += 1
            else:
                negative_rejection_168 += 1

        results168.append({
            "caseId": case_id,
            "category": category,
            "input": inp,
            "expectedCanonicalName": expected_name,
            "entityType": c["entityType"],
            "personRole": c.get("personRole"),
            "resolverOutcome": outcome,
            "selectedCanonicalName": resolved_name,
            "selectedCanonicalId": primary.resolved_candidate.id if primary and primary.resolved_candidate else None,
            "resolverReason": primary.strategy if primary else None,
            "requiresClarification": is_clarification,
        })

    summary168 = {
        "totalQueries": len(cases168),
        "positive": {
            "queries": 62,
            "correctConfident": correct_confident_168,
            "wrongConfident": wrong_positive_confident_168,
            "clarification": positive_clarification_168,
            "noMatch": positive_no_match_168,
        },
        "negativeConfusable": {
            "queries": 106,
            "wrongConfident": negative_wrong_confident_168,
            "clarification": negative_clarification_168,
            "rejection": negative_rejection_168,
        },
        "falseConfidentAutoResolution": wrong_positive_confident_168 + negative_wrong_confident_168,
        "results": results168,
    }
    (eval_dir / "py_168_safety_results.json").write_text(json.dumps(summary168, indent=2))
    print(f"Python 168: falseConfident={summary168['falseConfidentAutoResolution']}")

    # =========================================================================
    # 4. RUN KNOWN TRANSCRIPTS SUITE
    # =========================================================================
    file_transcripts = eval_dir / "frozen_known_transcripts_cases.json"
    assert file_transcripts.exists(), "frozen_known_transcripts_cases.json must exist"
    cases_transcripts = json.loads(file_transcripts.read_text())
    assert len(cases_transcripts) == 12, "Exact 12 cases required"

    results_transcripts = []
    for c in cases_transcripts:
        case_id = c["caseId"]
        inp = c["input"]
        expected_name = c["expectedCanonicalName"]
        type_ = parse_entity_type(c["entityType"])
        role = parse_person_role(c.get("personRole"))

        req = EntitySearchRequest(
            raw_mention=inp,
            entity_type=type_,
            person_role=role,
            limit=10,
        )

        generated = indexed_service.candidate_generator.generate(req)
        candidates = await indexed_service.search(req)
        stats = indexed_service.last_query_stats

        pool_size = len(generated.canonical_ids)
        is_escape = stats.used_full_scan_escape if stats else False

        target_rank = None
        for idx, cand in enumerate(candidates):
            if cand.canonical_name == expected_name or normalize(cand.canonical_name) == normalize(expected_name):
                target_rank = idx + 1
                break

        if type_ == SearchEntityType.PERSON:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_DRIVER_VIDEOS,
                driver_names=[inp],
                person_role=role,
            )
        elif type_ == SearchEntityType.RALLY:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_RALLIES,
                rally_names=[inp],
            )
        else:
            query = SearchQuery(
                intent=SearchIntent.SEARCH_VIDEO_ACTIONS,
                stage_names=[inp],
            )

        res_result = await resolver.resolve(query)
        primary_res = next(iter(res_result.resolutions.values()), None)

        if primary_res is not None and primary_res.is_resolved and primary_res.resolved_candidate is not None:
            resolver_outcome = "RESOLVED"
            selected_name = primary_res.resolved_candidate.canonical_name
        elif res_result.requires_clarification or (primary_res.is_ambiguous if primary_res else False):
            resolver_outcome = "CLARIFICATION"
            selected_name = None
        else:
            resolver_outcome = "NO_MATCH"
            selected_name = None

        results_transcripts.append({
            "caseId": case_id,
            "input": inp,
            "expectedCanonicalName": expected_name,
            "entityType": c["entityType"],
            "personRole": c.get("personRole"),
            "candidatePoolSize": pool_size,
            "targetPresent": target_rank is not None,
            "targetRank": target_rank,
            "topCandidateName": candidates[0].canonical_name if candidates else None,
            "topCandidateScore": candidates[0].score if candidates else 0.0,
            "resolverOutcome": resolver_outcome,
            "resolverReason": primary_res.strategy if primary_res else None,
            "selectedCanonicalName": selected_name,
            "fullScanEscape": is_escape,
        })

    (eval_dir / "py_known_transcripts_results.json").write_text(json.dumps(results_transcripts, indent=2))
    print("Python Known Transcripts complete: 12 cases.")
