"""Post-accuracy-hardening downstream replay.

Replays the FROZEN Flash-Lite SearchQuery outputs from the final 392-case
benchmark through the CURRENT downstream pipeline using the FROZEN
evaluate_system_pipeline evaluator (unchanged). No LLM / no STT calls.

Usage: python replay_harness.py <label> <out_dir>
"""
from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

from benchmarks.scoring.system_scoring import evaluate_system_pipeline

RESULTS = "benchmarks/results/full_20260829_053539/qu_raw_results.jsonl"
GOLD = "benchmarks/datasets/query_understanding_gold.jsonl"
MODEL = "gemini-3.5-flash-lite"


async def main(label: str, out_dir: str) -> None:
    recs = [json.loads(l) for l in open(RESULTS, encoding="utf-8") if l.strip()]
    fl = [r for r in recs if r["model"] == MODEL]
    gold = {json.loads(l)["case_id"]: json.loads(l) for l in open(GOLD, encoding="utf-8") if l.strip()}
    assert len(fl) == 392, f"expected 392 flash-lite records, got {len(fl)}"

    sem = asyncio.Semaphore(4)

    async def one(rec):
        async with sem:
            cid = rec["case_id"]
            g = gold[cid]
            parsed = rec["parsed_query"]
            sys_score = await evaluate_system_pipeline(g, parsed)
            # drop the verbose trace from the stored row (kept lean)
            trace = sys_score.pop("trace", None)
            return {
                "case_id": cid,
                "category": g.get("category"),
                "input_text": rec["input_text"],
                "conversation_context": rec.get("conversation_context"),
                "intent": rec.get("intent"),
                "parsed_query": parsed,
                "raw_score": rec["raw_score"],           # frozen, historical
                "expected_resolution": g.get("expected_resolution"),
                "sys_score": sys_score,
                "search_plan_type": sys_score.get("search_plan_type"),
                "clarification_question": (trace or {}).get("clarification_question") if trace else None,
            }

    rows = await asyncio.gather(*[one(r) for r in fl])
    rows.sort(key=lambda r: r["case_id"])

    out = Path(out_dir) / f"replay_{label}.jsonl"
    with open(out, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")

    n = len(rows)
    succ = sum(1 for r in rows if r["sys_score"]["system_success"])
    fc = sum(1 for r in rows if r["sys_score"].get("false_confident"))
    clar = sum(1 for r in rows if r["sys_score"].get("correct_clarification"))
    nomatch = sum(1 for r in rows if r["sys_score"].get("correct_no_match"))
    exact = [r for r in rows if r["raw_score"]["exact_match"]]
    exact_succ = sum(1 for r in exact if r["sys_score"]["system_success"])
    intent_ok = [r for r in rows if r["raw_score"]["intent_match"]]
    intent_succ = sum(1 for r in intent_ok if r["sys_score"]["system_success"])
    f1 = [r for r in rows if r["raw_score"]["field_f1"] >= 0.95]
    f1_succ = sum(1 for r in f1 if r["sys_score"]["system_success"])

    summary = {
        "label": label,
        "model": MODEL,
        "total": n,
        "system_success": succ,
        "system_success_pct": round(succ / n, 4),
        "false_confident": fc,
        "correct_clarification": clar,
        "correct_no_match": nomatch,
        "p_success_given_exact": round(exact_succ / len(exact), 4) if exact else None,
        "exact_n": len(exact),
        "p_success_given_intent": round(intent_succ / len(intent_ok), 4) if intent_ok else None,
        "p_success_given_f1_ge_095": round(f1_succ / len(f1), 4) if f1 else None,
    }
    with open(Path(out_dir) / f"summary_{label}.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1], sys.argv[2]))
