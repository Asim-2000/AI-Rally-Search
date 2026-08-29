from __future__ import annotations

import asyncio
import csv
import datetime
import hashlib
import json
import random
from pathlib import Path
from typing import Any

from benchmarks.providers.gemini_qu import GeminiQUAdapter
from benchmarks.providers.openai_qu import OpenAIQUAdapter
from benchmarks.runners.helpers import get_benchmark_api_keys
from benchmarks.scoring.cost import calculate_cost
from benchmarks.scoring.latency import summarize_latencies
from benchmarks.scoring.query_scoring import score_raw_query
from benchmarks.scoring.system_scoring import evaluate_system_pipeline


async def run_full_qu_benchmark() -> Path:
    keys = get_benchmark_api_keys()
    gold_path = Path(__file__).parent.parent / "datasets" / "query_understanding_gold.jsonl"
    gold_bytes = gold_path.read_bytes()
    dataset_hash = hashlib.sha256(gold_bytes).hexdigest()

    all_cases = [json.loads(line) for line in gold_bytes.decode("utf-8").splitlines() if line.strip()]
    print(f"Loaded {len(all_cases)} full gold cases for benchmark run.")

    models = [
        {"provider": "openai", "model": "gpt-5.6-luna", "adapter": OpenAIQUAdapter(api_key=keys["openai"], model="gpt-5.6-luna")},
        {"provider": "gemini", "model": "gemini-3.5-flash-lite", "adapter": GeminiQUAdapter(api_key=keys["gemini"], model="gemini-3.5-flash-lite")},
    ]

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    results_dir = Path(__file__).parent.parent / "results" / f"full_{timestamp}"
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

            raw_score = score_raw_query(case["expected"], raw_res.parsed_query, input_text=case["input_text"], context_text=case.get("conversation_context") or "")
            sys_score = await evaluate_system_pipeline(case, raw_res.parsed_query)
            cost_info = calculate_cost(
                m_id,
                raw_res.usage.input_tokens,
                raw_res.usage.output_tokens,
                raw_res.usage.cached_tokens,
                raw_res.usage.reasoning_tokens,
            )

            failures = []
            if not raw_res.schema_valid:
                failures.append("SCHEMA_FAILURE")
            if not raw_score["intent_match"]:
                failures.append("WRONG_INTENT")
            if raw_score["wrong_field"]:
                failures.append("WRONG_FIELD")
            if raw_score["missing_fields"]:
                failures.append("MISSING_VALUE")
            if raw_score["hallucinated_fields"]:
                failures.append("HALLUCINATED_VALUE")
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
            if raw_res.error:
                failures.append("PROVIDER_ERROR")

            return {
                "case_id": case["case_id"],
                "category": case.get("category"),
                "intent": case.get("expected", {}).get("intent"),
                "input_text": case["input_text"],
                "conversation_context": case.get("conversation_context"),
                "expected": case["expected"],
                "expected_resolution": case.get("expected_resolution"),
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

    tasks = []
    rng = random.Random(20260829)
    for case in all_cases:
        shuffled_models = list(models)
        rng.shuffle(shuffled_models)
        for m_info in shuffled_models:
            tasks.append((m_info["model"], _evaluate_single(case, m_info)))

    results = await asyncio.gather(*(t[1] for t in tasks))
    for (m_id, _), record in zip(tasks, results):
        model_records[m_id].append(record)

    # Save artifacts
    raw_results_file = results_dir / "qu_raw_results.jsonl"
    with open(raw_results_file, "w", encoding="utf-8") as f:
        for m_id, records in model_records.items():
            for r in records:
                f.write(json.dumps({"model": m_id, **r}, ensure_ascii=False) + "\n")

    report_file = results_dir / "benchmark_report.md"
    # Basic report stub for full runner
    report_file.write_text(f"# Full Benchmark Report\n\nCompleted {len(all_cases)} cases across {len(models)} models.\n", encoding="utf-8")
    print(f"Full benchmark complete! Results saved to {results_dir}")
    return report_file


if __name__ == "__main__":
    asyncio.run(run_full_qu_benchmark())
