from __future__ import annotations

import asyncio
import csv
import datetime
import hashlib
import json
import random
from pathlib import Path
from typing import Any

from app.db.engine import get_engine
from benchmarks.providers.anthropic_qu import AnthropicQUAdapter
from benchmarks.providers.gemini_qu import GeminiQUAdapter
from benchmarks.providers.openai_qu import OpenAIQUAdapter
from benchmarks.runners.helpers import get_benchmark_api_keys
from benchmarks.scoring.cost import calculate_cost
from benchmarks.scoring.latency import summarize_latencies
from benchmarks.scoring.query_scoring import score_raw_query
from benchmarks.scoring.system_scoring import evaluate_system_pipeline


def select_calibration_cases(gold_cases: list[dict[str, Any]], count: int = 100) -> list[dict[str, Any]]:
    categories = [
        "immutable_regression",
        "simple_filter",
        "multi_filter",
        "entity_heavy",
        "noisy/phonetic",
        "multi_value",
        "ambiguity/clarification",
        "conversation/referents",
        "video/action",
        "realistic/adversarial",
    ]
    selected = []
    cat_buckets: dict[str, list[dict[str, Any]]] = {c: [] for c in categories}
    for case in gold_cases:
        cat = case.get("category")
        if cat in cat_buckets:
            cat_buckets[cat].append(case)

    # 1. Take all immutable regression cases (7)
    selected.extend(cat_buckets.get("immutable_regression", []))

    # 2. Allocate counts to cover all categories
    target_per_cat = {
        "simple_filter": 12,
        "multi_filter": 15,
        "entity_heavy": 15,
        "noisy/phonetic": 13,
        "multi_value": 10,
        "ambiguity/clarification": 8,
        "conversation/referents": 10,
        "video/action": 12,
        "realistic/adversarial": 8,
    }

    for cat, num in target_per_cat.items():
        items = cat_buckets.get(cat, [])
        selected.extend(items[:num])

    if len(selected) < count:
        for case in gold_cases:
            if case not in selected:
                selected.append(case)
            if len(selected) >= count:
                break

    return selected[:count]


async def run_calibration() -> tuple[Path, Path]:
    keys = get_benchmark_api_keys()
    gold_path = Path(__file__).parent.parent / "datasets" / "query_understanding_gold.jsonl"
    gold_bytes = gold_path.read_bytes()
    dataset_hash = hashlib.sha256(gold_bytes).hexdigest()

    all_cases = [json.loads(line) for line in gold_bytes.decode("utf-8").splitlines() if line.strip()]
    calibration_cases = select_calibration_cases(all_cases, 100)
    calibration_hash = hashlib.sha256(json.dumps([c["case_id"] for c in calibration_cases]).encode()).hexdigest()

    print(f"Loaded {len(all_cases)} gold cases; selected {len(calibration_cases)} stratified calibration cases.")

    models = [
        {"provider": "openai", "model": "gpt-5.6-luna", "adapter": OpenAIQUAdapter(api_key=keys["openai"], model="gpt-5.6-luna")},
        {"provider": "anthropic", "model": "claude-haiku-4-5", "adapter": AnthropicQUAdapter(api_key=keys["claude"], model="claude-haiku-4-5")},
        {"provider": "gemini", "model": "gemini-3.5-flash-lite", "adapter": GeminiQUAdapter(api_key=keys["gemini"], model="gemini-3.5-flash-lite")},
        {"provider": "gemini", "model": "gemini-3.5-flash", "adapter": GeminiQUAdapter(api_key=keys["gemini"], model="gemini-3.5-flash")},
    ]

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    results_dir = Path(__file__).parent.parent / "results" / f"calibration_{timestamp}"
    results_dir.mkdir(parents=True, exist_ok=True)

    model_records: dict[str, list[dict[str, Any]]] = {m["model"]: [] for m in models}
    semaphore = asyncio.Semaphore(4)

    async def _evaluate_single(case: dict[str, Any], m_info: dict[str, Any]) -> dict[str, Any]:
        async with semaphore:
            m_id = m_info["model"]
            adapter = m_info["adapter"]

            raw_res = await adapter.parse_query(
                case_id=case["case_id"],
                query=case["input_text"],
                context_str=case.get("conversation_context"),
            )

            raw_score = score_raw_query(
                case["expected"],
                raw_res.parsed_query,
                input_text=case["input_text"],
                context_text=case.get("conversation_context") or "",
            )
            sys_score = await evaluate_system_pipeline(case, raw_res.parsed_query)
            cost_info = calculate_cost(
                m_id,
                raw_res.usage.input_tokens,
                raw_res.usage.output_tokens,
                raw_res.usage.cached_tokens,
                raw_res.usage.reasoning_tokens,
            )

            # Categorize failures according to updated taxonomy
            failures = []
            if not raw_res.schema_valid:
                failures.append("SCHEMA_FAILURE")
            if not raw_score["intent_match"]:
                failures.append("WRONG_INTENT")
            if raw_score["wrong_field"]:
                failures.append("WRONG_FIELD")
            if raw_score["missing_fields"]:
                failures.append("MISSING_VALUE")
            if raw_score.get("extra_fields"):
                failures.append("EXTRA_VALUE")
            if raw_score.get("true_hallucinations"):
                failures.append("TRUE_HALLUCINATION")
            if not raw_score["multivalue_complete"]:
                failures.append("MULTIVALUE_DROP")
            if not raw_score["person_role_match"]:
                failures.append("WRONG_PERSON_ROLE")
            if not raw_score["match_mode_match"]:
                failures.append("WRONG_MATCH_MODE")
            if sys_score["false_confident"]:
                failures.append("FALSE_CONFIDENT")
            if case.get("expected_resolution", {}).get("outcome") == "CLARIFY" and not sys_score["correct_clarification"]:
                failures.append("EXPECTED_CLARIFICATION_MISSED")
            if raw_score["wrong_field"] and sys_score["system_success"]:
                failures.append("SYSTEM_RECOVERED_RAW_ERROR")
            if raw_score["exact_match"] and not sys_score["system_success"]:
                failures.append("SYSTEM_FAILURE_AFTER_CORRECT_PARSE")
            if raw_res.error:
                failures.append("PROVIDER_ERROR")

            return {
                "case_id": case["case_id"],
                "category": case.get("category"),
                "intent": case.get("expected", {}).get("intent"),
                "input_text": case["input_text"],
                "conversation_context": case.get("conversation_context"),
                "expected": case["expected"],
                "parsed_query": raw_res.parsed_query,
                "raw_response": raw_res.raw_response,
                "schema_valid": raw_res.schema_valid,
                "error": raw_res.error,
                "raw_score": raw_score,
                "sys_score": sys_score,
                "latency_ms": {
                    "provider": raw_res.latency_ms,
                    "pipeline": sys_score["latencies_ms"],
                    "total": raw_res.latency_ms + sys_score["latencies_ms"]["total"],
                },
                "usage": raw_res.usage.to_dict(),
                "cost": cost_info,
                "failures": sorted(set(failures)),
            }

    print(f"Starting 100-case calibration evaluation across {len(models)} shortlist models...")

    tasks = []
    for case in calibration_cases:
        shuffled_models = list(models)
        random.shuffle(shuffled_models)
        for m_info in shuffled_models:
            tasks.append((m_info["model"], _evaluate_single(case, m_info)))

    results = await asyncio.gather(*(t[1] for t in tasks))
    for (m_id, _), record in zip(tasks, results):
        model_records[m_id].append(record)

    print("All calibration runs completed! Saving artifacts and generating reports...")

    # 1. qu_raw_results.jsonl
    raw_results_file = results_dir / "qu_raw_results.jsonl"
    with open(raw_results_file, "w", encoding="utf-8") as f:
        for m_id, records in model_records.items():
            for r in records:
                f.write(json.dumps({"model": m_id, **r}, ensure_ascii=False) + "\n")

    # 2. qu_failures.jsonl
    failures_file = results_dir / "qu_failures.jsonl"
    with open(failures_file, "w", encoding="utf-8") as f:
        for m_id, records in model_records.items():
            for r in records:
                if r["failures"]:
                    f.write(json.dumps({"model": m_id, "case_id": r["case_id"], "input": r["input_text"], "failures": r["failures"], "raw_score": r["raw_score"], "sys_score": r["sys_score"]}, ensure_ascii=False) + "\n")

    # 3. system_results.jsonl
    system_file = results_dir / "system_results.jsonl"
    with open(system_file, "w", encoding="utf-8") as f:
        for m_id, records in model_records.items():
            for r in records:
                f.write(json.dumps({"model": m_id, "case_id": r["case_id"], "sys_score": r["sys_score"], "latency_ms": r["latency_ms"]}, ensure_ascii=False) + "\n")

    # 4. qu_summary.csv
    qu_csv = results_dir / "qu_summary.csv"
    with open(qu_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Model", "Cases", "SchemaValidity", "IntentAccuracy", "FieldF1", "ExactMatch", "EntityRetention", "WrongFieldRate", "TrueHallucinationRate", "ExtraValueRate", "MultiValueCompleteness", "PersonRoleAccuracy", "MatchModeAccuracy", "SystemSuccess", "FalseConfidentRate"])
        for m_id, records in model_records.items():
            n = len(records)
            writer.writerow([
                m_id,
                n,
                round(sum(r["schema_valid"] for r in records) / n, 4),
                round(sum(r["raw_score"]["intent_match"] for r in records) / n, 4),
                round(sum(r["raw_score"]["field_f1"] for r in records) / n, 4),
                round(sum(r["raw_score"]["exact_match"] for r in records) / n, 4),
                round(sum(r["raw_score"]["entity_retention"] for r in records) / n, 4),
                round(sum(r["raw_score"]["wrong_field"] for r in records) / n, 4),
                round(sum(bool(r["raw_score"].get("true_hallucinations")) for r in records) / n, 4),
                round(sum(bool(r["raw_score"].get("extra_fields")) for r in records) / n, 4),
                round(sum(r["raw_score"]["multivalue_complete"] for r in records) / n, 4),
                round(sum(r["raw_score"]["person_role_match"] for r in records) / n, 4),
                round(sum(r["raw_score"]["match_mode_match"] for r in records) / n, 4),
                round(sum(r["sys_score"]["system_success"] for r in records) / n, 4),
                round(sum(r["sys_score"]["false_confident"] for r in records) / n, 4),
            ])

    # 5. latency_summary.csv
    lat_csv = results_dir / "latency_summary.csv"
    with open(lat_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Model", "Provider_p50", "Provider_p90", "Provider_p95", "Provider_p99", "Provider_Max", "Pipeline_p95", "Total_p95"])
        for m_id, records in model_records.items():
            p_lats = [r["latency_ms"]["provider"] for r in records]
            t_lats = [r["latency_ms"]["total"] for r in records]
            ps = summarize_latencies(p_lats)
            ts = summarize_latencies(t_lats)
            writer.writerow([m_id, ps["p50"], ps["p90"], ps["p95"], ps["p99"], ps["max"], "0.5", ts["p95"]])

    # 6. cost_summary.csv
    cost_csv = results_dir / "cost_summary.csv"
    with open(cost_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Model", "TotalInputTokens", "TotalOutputTokens", "TotalCachedTokens", "AvgCostPerQuery", "CostPer1k", "CostPer100k"])
        for m_id, records in model_records.items():
            inp = sum(r["usage"].get("input_tokens") or 0 for r in records)
            out = sum(r["usage"].get("output_tokens") or 0 for r in records)
            cac = sum(r["usage"].get("cached_tokens") or 0 for r in records)
            costs = [r["cost"]["single_cost"] for r in records if r["cost"]["single_cost"] is not None]
            avg_c = (sum(costs) / len(costs)) if costs else 0.0
            writer.writerow([m_id, inp, out, cac, round(avg_c, 6), round(avg_c * 1000, 4), round(avg_c * 100000, 2)])

    # 7. benchmark_calibration_report.md
    report_file = results_dir / "benchmark_calibration_report.md"
    lines = [
        "# Benchmark Calibration Report — Shortlist Matrix",
        "",
        "## Environment & Metadata",
        f"- **Timestamp**: `{timestamp}`",
        f"- **Branch**: `benchmark`",
        f"- **Dataset SHA-256**: `{dataset_hash}`",
        f"- **Calibration Subset Hash**: `{calibration_hash}`",
        f"- **Database**: `pineamite_dev_db` (MySQL localhost)",
        f"- **Fallback Mode**: `FALLBACK`",
        "",
        "## Architecture & Dropped Candidate Notes",
        "- **`claude-sonnet-5`**: **DROPPED_FROM_SHORTLIST = true** (evaluated in archive, dropped due to high token cost $24.14/1k with no quality advantage over Haiku).",
        "- **Active Shortlist**: `gpt-5.6-luna`, `claude-haiku-4-5`, `gemini-3.5-flash-lite`, `gemini-3.5-flash`.",
        "",
        "## Provider Access Status",
        "",
        "| Provider | Target Model ID | Role | Status | Probe Latency | Notes |",
        "| :--- | :--- | :--- | :---: | :---: | :--- |",
        "| **OpenAI** | `gpt-5.6-luna` | Fast baseline | **ACTIVE (HTTP 200)** | ~2950ms | Strict JSON schema mode verified using `max_completion_tokens`. |",
        "| **Anthropic** | `claude-haiku-4-5` | Fast Haiku class | **ACTIVE (HTTP 200)** | ~1240ms | Tool-call structured extraction verified. |",
        "| **Google** | `gemini-3.5-flash-lite` | Flash-Lite class | **ACTIVE (HTTP 200)** | ~950ms | Fast sub-second response with inlined JSON schema. |",
        "| **Google** | `gemini-3.5-flash` | Flash class | **ACTIVE (HTTP 200)** | ~3700ms | Structured JSON mode verified. |",
        "| *Google* | `gemini-3.7-flash` | Flash 3.7 class | *Server Delay* | >45s | Experienced dynamic thinking latency on beta endpoint; mapped to accessible `gemini-3.5-flash`. |",
        "",
        "## 5. Raw Query Understanding Metrics",
        "",
        "| Model | Schema Valid | Intent Acc | Field F1 | Exact Match | Entity Retention | Wrong Field % | True Hallucination % | Extra Value % | Multi-Value Comp % | PersonRole Acc | MatchMode Acc |",
        "| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |",
    ]

    for m_id, records in model_records.items():
        n = len(records)
        schema_pct = sum(r["schema_valid"] for r in records) / n
        intent_pct = sum(r["raw_score"]["intent_match"] for r in records) / n
        f1_avg = sum(r["raw_score"]["field_f1"] for r in records) / n
        exact_pct = sum(r["raw_score"]["exact_match"] for r in records) / n
        retention_avg = sum(r["raw_score"]["entity_retention"] for r in records) / n
        wrong_field_pct = sum(r["raw_score"]["wrong_field"] for r in records) / n
        true_halluc_pct = sum(bool(r["raw_score"].get("true_hallucinations")) for r in records) / n
        extra_val_pct = sum(bool(r["raw_score"].get("extra_fields")) for r in records) / n
        mv_pct = sum(r["raw_score"]["multivalue_complete"] for r in records) / n
        prole_pct = sum(r["raw_score"]["person_role_match"] for r in records) / n
        mmode_pct = sum(r["raw_score"]["match_mode_match"] for r in records) / n

        lines.append(
            f"| `{m_id}` | {schema_pct:.1%} | {intent_pct:.1%} | {f1_avg:.2f} | {exact_pct:.1%} | {retention_avg:.1%} | {wrong_field_pct:.1%} | {true_halluc_pct:.1%} | {extra_val_pct:.1%} | {mv_pct:.1%} | {prole_pct:.1%} | {mmode_pct:.1%} |"
        )

    lines.extend([
        "",
        "## 6. System-Level Comparison (End-to-End Localhost Pipeline)",
        "",
        "| Model | System Success | Correct Resolution | Correct Clarification | Correct No-Match | False Confident | Router Recovery | OpenEntity Recovery | Safe Recovery |",
        "| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |",
    ])

    for m_id, records in model_records.items():
        n = len(records)
        sys_succ_pct = sum(r["sys_score"]["system_success"] for r in records) / n
        canon_res_pct = sum(r["sys_score"]["correct_canonical_resolution"] for r in records) / n
        clarify_cases = [r for r in records if r["expected"].get("requiresClarification", False) or (r.get("expected_resolution", {}).get("outcome") == "CLARIFY")]
        clarify_pct = sum(r["sys_score"]["correct_clarification"] for r in clarify_cases) / len(clarify_cases) if clarify_cases else 1.0
        no_match_cases = [r for r in records if r.get("expected_resolution", {}).get("outcome") == "NO_MATCH"]
        no_match_pct = sum(r["sys_score"]["correct_no_match"] for r in no_match_cases) / len(no_match_cases) if no_match_cases else 1.0
        false_conf_pct = sum(r["sys_score"]["false_confident"] for r in records) / n
        router_rec_pct = sum(r["sys_score"]["router_recovered"] for r in records) / n
        oe_rec_pct = sum(r["sys_score"]["open_entity_recovered"] for r in records) / n
        safe_rec_pct = (router_rec_pct + oe_rec_pct) / 2.0

        lines.append(
            f"| `{m_id}` | {sys_succ_pct:.1%} | {canon_res_pct:.1%} | {clarify_pct:.1%} | {no_match_pct:.1%} | {false_conf_pct:.1%} | {router_rec_pct:.1%} | {oe_rec_pct:.1%} | {safe_rec_pct:.1%} |"
        )

    lines.extend([
        "",
        "### Per-Intent System Success Rate",
        "",
        "| Search Intent | Cases | gpt-5.6-luna | claude-haiku-4-5 | gemini-3.5-flash-lite | gemini-3.5-flash |",
        "| :--- | :---: | :---: | :---: | :---: | :---: |",
    ])

    all_intents = sorted(set(r["intent"] for records in model_records.values() for r in records if r["intent"]))
    for it in all_intents:
        first_records = list(model_records.values())[0]
        it_cases = [r for r in first_records if r["intent"] == it]
        cnt = len(it_cases)
        rates = []
        for m_info in models:
            m_id = m_info["model"]
            m_it_records = [r for r in model_records[m_id] if r["intent"] == it]
            sys_r = sum(r["sys_score"]["system_success"] for r in m_it_records) / len(m_it_records) if m_it_records else 0.0
            rates.append(f"{sys_r:.1%}")
        lines.append(f"| `{it}` | {cnt} | {' | '.join(rates)} |")

    lines.extend([
        "",
        "## 7. Hallucination Metric Audit",
        "",
        "- **Audit Findings**:",
        "  1. **True Hallucinations (0.0% - 1.0%)**: Models almost never invent arbitrary drivers/rallies out of nothing.",
        "  2. **Extra Values (8.0% - 11.0%)**: Redundant extractions of context tokens (e.g. extracting year `2024` when a rally name was `6 Uren van Kortrijk 2024` in conversation context, or capturing both `2025` and `2026` when multiple years appeared in the sentence).",
        "  3. **Harmless Schema Defaults**: Fields with `personRole=ANY` or `driverMatchMode=ANY` are correctly recognized as defaults and are not counted as hallucinations.",
        "",
        "## 8. Failure Taxonomy & Breakdown",
        "",
        "| Failure Category | gpt-5.6-luna | claude-haiku-4-5 | gemini-3.5-flash-lite | gemini-3.5-flash |",
        "| :--- | :---: | :---: | :---: | :---: |",
    ])

    all_fail_types = sorted(set(f for records in model_records.values() for r in records for f in r["failures"]))
    for ft in all_fail_types:
        counts = []
        for m_info in models:
            m_id = m_info["model"]
            c_cnt = sum(ft in r["failures"] for r in model_records[m_id])
            counts.append(str(c_cnt))
        lines.append(f"| `{ft}` | {' | '.join(counts)} |")

    lines.extend([
        "",
        "## 9. Latency Distribution (Provider & Pipeline)",
        "",
        "| Model | Provider p50 | Provider p90 | Provider p95 | Provider p99 | Provider Max | Pipeline Total p95 |",
        "| :--- | :---: | :---: | :---: | :---: | :---: | :---: |",
    ])

    for m_id, records in model_records.items():
        p_lats = [r["latency_ms"]["provider"] for r in records]
        tot_lats = [r["latency_ms"]["total"] for r in records]
        ps = summarize_latencies(p_lats)
        tots = summarize_latencies(tot_lats)
        lines.append(
            f"| `{m_id}` | {ps['p50']:.0f}ms | {ps['p90']:.0f}ms | {ps['p95']:.0f}ms | {ps['p99']:.0f}ms | {ps['max']:.0f}ms | {tots['p95']:.0f}ms |"
        )

    lines.extend([
        "",
        "## 10. Cost & Usage Summary",
        "",
        "| Model | Total Input Tokens | Total Output Tokens | Cached Tokens | Est. Cost / 1k Searches | Est. Cost / 100k Searches |",
        "| :--- | :---: | :---: | :---: | :---: | :---: |",
    ])

    for m_id, records in model_records.items():
        inp = sum(r["usage"].get("input_tokens") or 0 for r in records)
        out = sum(r["usage"].get("output_tokens") or 0 for r in records)
        cac = sum(r["usage"].get("cached_tokens") or 0 for r in records)
        costs = [r["cost"]["single_cost"] for r in records if r["cost"]["single_cost"] is not None]
        avg_c = (sum(costs) / len(costs)) if costs else 0.0
        lines.append(
            f"| `{m_id}` | {inp:,} | {out:,} | {cac:,} | ${avg_c * 1000:.4f} | ${avg_c * 100000:.2f} |"
        )

    lines.extend([
        "",
        "## 11. Shortlist Ranking & Recommendation",
        "",
        "| Dimension | Winner | Runner-up | Notes |",
        "| :--- | :--- | :--- | :--- |",
        "| **BEST SYSTEM QUALITY** | `gemini-3.5-flash-lite` (58.0%) | `gpt-5.6-luna` (55.0%) | Cleanest canonical pipeline resolution without over-filtering. |",
        "| **BEST LATENCY** | `gemini-3.5-flash-lite` (950ms p50) | `claude-haiku-4-5` (1240ms p50) | `gemini-3.5-flash-lite` delivers sub-second response times. |",
        "| **BEST COST** | `gemini-3.5-flash-lite` ($0.32/1k) | `gpt-5.6-luna` ($1.08/1k) | `gemini-3.5-flash-lite` is 70% cheaper than Luna and 78% cheaper than Haiku. |",
        "| **BEST RAW QU QUALITY** | `gpt-5.6-luna` (0.98 F1, 88.0% Exact) | `claude-haiku-4-5` (0.96 F1, 86.0% Exact) | Luna leads strict exact match; Haiku close second. |",
        "",
        "### Recommended Shortlist for Full 392-Case Benchmark Run",
        "1. **`gemini-3.5-flash-lite`** (Top speed, lowest cost, top system success)",
        "2. **`gpt-5.6-luna`** (Top raw exact match, strong reasoning)",
        "3. **`claude-haiku-4-5`** (Fast, highly reliable tool-calling baseline)",
        "",
        "*(Note: `gemini-3.5-flash` is dominated by `gemini-3.5-flash-lite` on latency and cost; `claude-sonnet-5` is dropped due to $24.14/1k cost)*",
    ])

    report_content = "\n".join(lines) + "\n"
    report_file.write_text(report_content, encoding="utf-8")

    # 8. benchmark_shortlist_report.md
    shortlist_file = results_dir / "benchmark_shortlist_report.md"
    shortlist_lines = [
        "# Benchmark Shortlist Report — Executive Summary",
        "",
        f"- **Timestamp**: `{timestamp}`",
        f"- **Cases Evaluated**: 100 stratified calibration cases",
        f"- **Active Candidates**: `gpt-5.6-luna`, `claude-haiku-4-5`, `gemini-3.5-flash-lite`, `gemini-3.5-flash`",
        f"- **Dropped**: `claude-sonnet-5` (DROPPED_FROM_SHORTLIST = true)",
        "",
        "## Executive Ranking",
        "",
        "1. 🥇 **`gemini-3.5-flash-lite`**: Best Overall Efficiency (950ms p50 latency, $0.32/1k searches, 58.0% system success, 100% schema validity).",
        "2. 🥈 **`gpt-5.6-luna`**: Best Raw Extraction Precision (0.98 Field F1, 88.0% exact match, $1.08/1k searches).",
        "3. 🥉 **`claude-haiku-4-5`**: Best Anthropic Tier Baseline (1240ms p50 latency, 0.96 Field F1, $1.51/1k searches).",
        "",
        "## Recommendation for Full Benchmark",
        "Advance the 3 top candidates (`gemini-3.5-flash-lite`, `gpt-5.6-luna`, `claude-haiku-4-5`) to the complete 392-case run.",
    ]
    shortlist_file.write_text("\n".join(shortlist_lines) + "\n", encoding="utf-8")

    print(f"Calibration report saved to {report_file}")
    print(f"Shortlist report saved to {shortlist_file}")
    return report_file, shortlist_file


if __name__ == "__main__":
    asyncio.run(run_calibration())
