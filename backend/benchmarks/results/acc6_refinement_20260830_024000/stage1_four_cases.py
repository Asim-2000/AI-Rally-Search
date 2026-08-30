"""STAGE 1: replay the four ACC-6 cases through the frozen evaluator."""
from __future__ import annotations
import asyncio, json
from benchmarks.scoring.system_scoring import evaluate_system_pipeline

RESULTS = "benchmarks/results/full_20260829_053539/qu_raw_results.jsonl"
GOLD = "benchmarks/datasets/query_understanding_gold.jsonl"
MODEL = "gemini-3.5-flash-lite"
CASES = ["act_0344", "act_0352", "nsy_0207", "nsy_0208"]
EXPECT = {"act_0344": "RESOLVED", "act_0352": "RESOLVED", "nsy_0207": "CLARIFY", "nsy_0208": "CLARIFY"}

async def main():
    recs = [json.loads(l) for l in open(RESULTS, encoding="utf-8") if l.strip()]
    fl = {r["case_id"]: r for r in recs if r["model"] == MODEL}
    gold = {json.loads(l)["case_id"]: json.loads(l) for l in open(GOLD, encoding="utf-8") if l.strip()}
    for cid in CASES:
        rec = fl[cid]; g = gold[cid]
        s = await evaluate_system_pipeline(g, rec["parsed_query"])
        trace = s.get("trace") or {}
        print(f"=== {cid}: '{rec['input_text']}' ===")
        print(f"  gold outcome     : {(g.get('expected_resolution') or {}).get('outcome')}")
        print(f"  actual outcome   : {s['outcome']}")
        print(f"  system_success   : {s['system_success']}")
        print(f"  false_confident  : {s['false_confident']}")
        print(f"  db_count         : {s['db_count']}")
        print(f"  clarification_q  : {trace.get('clarification_question')}")
        # resolved driver/rally
        rq = trace.get("canonical_resolved_query") or {}
        print(f"  resolved driver  : {rq.get('driverNames')}  rally: {rq.get('rallyNames')}")
        print(f"  EXPECT (behavior): {EXPECT[cid]}")
        print()

asyncio.run(main())
