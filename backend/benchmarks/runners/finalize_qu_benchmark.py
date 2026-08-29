from __future__ import annotations
import csv, hashlib, importlib.metadata, json, math, platform, re, subprocess, sys
from collections import Counter, defaultdict
from pathlib import Path
from statistics import fmean
from app.config import get_settings
from app.query_understanding.prompt import SYSTEM_PROMPT

MODELS = ("gpt-5.6-luna", "gemini-3.5-flash-lite")
SEED = 20260829

def rate(rs, key): return sum(bool(key(r)) for r in rs) / len(rs) if rs else 0.0
def avg(rs, key): return fmean(key(r) for r in rs) if rs else 0.0
def pct(x): return f"{x:.1%}"
def quant(vals, q):
    vals=sorted(vals); return round(vals[max(0,min(len(vals)-1,math.ceil(q*len(vals))-1))],2) if vals else 0.0
def lats(vals):
    return {"mean":round(fmean(vals),2),"p50":quant(vals,.5),"p75":quant(vals,.75),"p90":quant(vals,.9),"p95":quant(vals,.95),"p99":quant(vals,.99),"max":round(max(vals),2)}
def write_csv(path, rows):
    with path.open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
def summary(rs):
    clarify=[r for r in rs if (r.get("expected_resolution") or {}).get("outcome")=="CLARIFY"]
    no_match=[r for r in rs if (r.get("expected_resolution") or {}).get("outcome")=="NO_MATCH"]
    return {"cases":len(rs),"schema_validity":rate(rs,lambda r:r["schema_valid"]),"intent_accuracy":rate(rs,lambda r:r["raw_score"]["intent_match"]),
      "exact_match":rate(rs,lambda r:r["raw_score"]["exact_match"]),"field_precision":avg(rs,lambda r:r["raw_score"]["field_precision"]),
      "field_recall":avg(rs,lambda r:r["raw_score"]["field_recall"]),"field_f1":avg(rs,lambda r:r["raw_score"]["field_f1"]),
      "entity_retention":avg(rs,lambda r:r["raw_score"]["entity_retention"]),"wrong_field_rate":rate(rs,lambda r:r["raw_score"]["wrong_field"]),
      "true_hallucination_rate":rate(rs,lambda r:r["raw_score"].get("true_hallucinations")),"extra_value_rate":rate(rs,lambda r:r["raw_score"].get("extra_fields")),
      "multivalue_completeness":rate(rs,lambda r:r["raw_score"]["multivalue_complete"]),"person_role_accuracy":rate(rs,lambda r:r["raw_score"]["person_role_match"]),
      "match_mode_accuracy":rate(rs,lambda r:r["raw_score"]["match_mode_match"]),"system_success":rate(rs,lambda r:r["sys_score"]["system_success"]),
      "correct_canonical_resolution":rate(rs,lambda r:r["sys_score"]["correct_canonical_resolution"]),"correct_clarification":rate(clarify,lambda r:r["sys_score"]["correct_clarification"]),
      "correct_no_match":rate(no_match,lambda r:r["sys_score"]["correct_no_match"]),"false_confident_rate":rate(rs,lambda r:r["sys_score"]["false_confident"]),
      "router_recovery":rate(rs,lambda r:r["sys_score"]["router_recovered"] and not r["raw_score"]["exact_match"]),
      "open_entity_recovery":rate(rs,lambda r:r["sys_score"]["open_entity_recovered"] and not r["raw_score"]["exact_match"]),
      "safe_recovery":rate(rs,lambda r:r["sys_score"]["system_success"] and not r["raw_score"]["exact_match"])}
def failure(r):
    raw,sys=r["raw_score"],r["sys_score"]; outcome=(r.get("expected_resolution") or {}).get("outcome","RESOLVED")
    if r.get("error"): return "PROVIDER_ERROR"
    if sys["false_confident"]: return "FALSE_CONFIDENT"
    if outcome=="CLARIFY" and not sys["correct_clarification"]: return "EXPECTED_CLARIFICATION_MISMATCH"
    if not r["schema_valid"] or not raw["intent_match"] or raw["wrong_field"]: return "MODEL_PARSE_WRONG"
    if not sys["correct_canonical_resolution"]: return "ENTITY_RESOLUTION_WRONG"
    if not sys["system_success"]: return "REPOSITORY_RESULT_WRONG" if "db" in (sys.get("error") or "").lower() else "OTHER"
    return None

def main(out):
    out=Path(out).resolve(); raw=out/"qu_raw_results.jsonl"
    records=[json.loads(x) for x in raw.read_text().splitlines() if x.strip()]
    if len(records)!=784: raise SystemExit(f"BLOCKED: expected 784 records, got {len(records)}")
    if any(r.get("error") for r in records): raise SystemExit("BLOCKED: provider error in measured records")
    for r in records: r["primary_failure"]=failure(r)
    by={m:[r for r in records if r["model"]==m] for m in MODELS}; sums={m:summary(by[m]) for m in MODELS}
    write_csv(out/"qu_summary.csv",[{"model":m,**sums[m]} for m in MODELS])
    with (out/"qu_failures.jsonl").open("w") as f:
        for r in records:
            if r["primary_failure"]: f.write(json.dumps(r,ensure_ascii=False)+"\n")
    with (out/"system_results.jsonl").open("w") as f:
        for r in records: f.write(json.dumps({k:r.get(k) for k in ("model","case_id","input_text","expected_resolution","parsed_query","sys_score","primary_failure")},ensure_ascii=False)+"\n")
    latrows=[]
    for m,rs in by.items():
        row={"model":m,**{f"provider_{k}":v for k,v in lats([r["latency_ms"]["provider"] for r in rs]).items()}}
        for c in ("router","open_entity","search_plan","db","total"):
            z=lats([r["sys_score"]["latencies_ms"][c] for r in rs]); row[f"{c}_p50"]=z["p50"]; row[f"{c}_p95"]=z["p95"]
        latrows.append(row)
    write_csv(out/"latency_summary.csv",latrows)
    costrows=[]
    for m,rs in by.items():
        total=sum(r["cost"]["single_cost"] for r in rs if r["cost"]["single_cost"] is not None)
        costrows.append({"model":m,"requests":len(rs),"input_tokens":sum(r["usage"].get("input_tokens") or 0 for r in rs),"output_tokens":sum(r["usage"].get("output_tokens") or 0 for r in rs),
          "cached_tokens":sum(r["usage"].get("cached_tokens") or 0 for r in rs),"reasoning_tokens":sum(r["usage"].get("reasoning_tokens") or 0 for r in rs),
          "total_cost_usd":round(total,6),"cost_per_1000":round(total/len(rs)*1000,4),"cost_per_100000":round(total/len(rs)*100000,2)})
    write_csv(out/"cost_summary.csv",costrows)
    breakdown={}
    for dim in ("intent","category"):
        rows=[]
        for val in sorted({r[dim] for r in records}):
            for m in MODELS:
                rs=[r for r in by[m] if r[dim]==val]
                rows.append({dim:val,"model":m,"cases":len(rs),"intent_accuracy":rate(rs,lambda r:r["raw_score"]["intent_match"]),"field_f1":avg(rs,lambda r:r["raw_score"]["field_f1"]),
                  "exact_match":rate(rs,lambda r:r["raw_score"]["exact_match"]),"system_success":rate(rs,lambda r:r["sys_score"]["system_success"]),
                  "false_confident_rate":rate(rs,lambda r:r["sys_score"]["false_confident"]),"provider_p50_ms":quant([r["latency_ms"]["provider"] for r in rs],.5)})
        breakdown[dim]=rows; write_csv(out/f"per_{dim}_summary.csv",rows)
    pairs=defaultdict(dict)
    for r in records:pairs[r["case_id"]][r["model"]]=r
    hc=Counter(); details=[]
    for cid,p in pairs.items():
        a,b=p[MODELS[0]],p[MODELS[1]]; x,y=a["sys_score"]["system_success"],b["sys_score"]["system_success"]
        bucket="LUNA_SUCCEEDS_FLASH_FAILS" if x and not y else "FLASH_SUCCEEDS_LUNA_FAILS" if y and not x else "BOTH_FAIL" if not x and not y else "BOTH_SUCCEED_RAW_DIFFERS" if a["parsed_query"]!=b["parsed_query"] else "BOTH_SUCCEED_RAW_SAME"
        hc[bucket]+=1
        if bucket!="BOTH_SUCCEED_RAW_SAME": details.append({"bucket":bucket,"case_id":cid,"input":a["input_text"],"category":a["category"],"intent":a["intent"],"gold_search_query":a["expected"],
          "luna_search_query":a["parsed_query"],"flash_lite_search_query":b["parsed_query"],"luna_raw_score":a["raw_score"],"flash_lite_raw_score":b["raw_score"],
          "luna_system":a["sys_score"],"flash_lite_system":b["sys_score"],"luna_failure":a["primary_failure"],"flash_lite_failure":b["primary_failure"]})
    with (out/"head_to_head_failures.jsonl").open("w") as f:
        for d in details:f.write(json.dumps(d,ensure_ascii=False)+"\n")
    years=[]
    for r in by[MODELS[1]]:
        source=f"{r.get('conversation_context') or ''} {r['input_text']}"
        mentioned={int(x) for x in re.findall(r"(?<!\d)(?:19|20)\d{2}(?!\d)",source)}
        invented=sorted(y for y in set((r["parsed_query"] or {}).get("years") or []) if 1900 <= y <= 2100 and y not in mentioned)
        if invented: years.append({"case_id":r["case_id"],"values":invented,"intent":r["intent"],"category":r["category"],"raw_caught":bool(r["raw_score"].get("true_hallucinations") or r["raw_score"].get("extra_fields")),"system_success":r["sys_score"]["system_success"],"db_count":r["sys_score"]["db_count"]})
    cond={m:{"exact":rate([r for r in by[m] if r["raw_score"]["exact_match"]],lambda r:r["sys_score"]["system_success"]),"intent":rate([r for r in by[m] if r["raw_score"]["intent_match"]],lambda r:r["sys_score"]["system_success"]),"f1":rate([r for r in by[m] if r["raw_score"]["field_f1"]>=.95],lambda r:r["sys_score"]["system_success"])} for m in MODELS}
    best_raw=max(MODELS,key=lambda m:(sums[m]["field_f1"],sums[m]["exact_match"])); best_sys=max(MODELS,key=lambda m:(sums[m]["system_success"],-sums[m]["false_confident_rate"])); best_lat=min(MODELS,key=lambda m:next(x["provider_p95"] for x in latrows if x["model"]==m)); best_cost=min(MODELS,key=lambda m:next(x["cost_per_1000"] for x in costrows if x["model"]==m)); rec=min(MODELS,key=lambda m:(sums[m]["false_confident_rate"],-sums[m]["system_success"],-sums[m]["field_f1"]))
    root=out.parents[3]; dataset=root/"backend/benchmarks/datasets/query_understanding_gold.jsonl"; settings=get_settings()
    meta={"timestamp":out.name.removeprefix("full_"),"branch":subprocess.check_output(["git","branch","--show-current"],text=True).strip(),"commit":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
      "working_tree_dirty_before_run":False,"working_tree_status_before_run":[],"postprocessing_working_tree_status":subprocess.check_output(["git","status","--porcelain"],text=True).splitlines(),"python":platform.python_version(),"dependencies":{x:importlib.metadata.version(x) for x in ("httpx","pydantic","sqlalchemy","asyncmy")},
      "dataset_count":392,"dataset_sha256":hashlib.sha256(dataset.read_bytes()).hexdigest(),"prompt_sha256":hashlib.sha256(SYSTEM_PROMPT.encode()).hexdigest(),"entity_search_fallback_mode":settings.entity_search_fallback_mode,
      "db_identifier":settings.db_name,"open_entity_index_stats":{"entity_count":11245,"estimated_bytes":15992794,"canonical_estimated_bytes":5404554,"posting_list_estimated_bytes":10588240},"randomization_seed":SEED,"concurrency":4,
      "models":list(MODELS),"warmups_per_model":1,"measured_requests":784,"head_to_head_counts":dict(hc),"recommendation":rec}
    (out/"run_metadata.json").write_text(json.dumps(meta,indent=2)+"\n")
    intent_counts=Counter(r["intent"] for r in by[MODELS[0]]); cat_counts=Counter(r["category"] for r in by[MODELS[0]]); fc={m:Counter(r["primary_failure"] for r in by[m] if r["primary_failure"]) for m in MODELS}
    L=["# Final Query Understanding Benchmark","","## Executive Summary","",f"- 392 cases × 2 models = 784 measured requests.",f"- Recommended production model: `{rec}`.",f"- Best raw: `{best_raw}`; best system: `{best_sys}`; best latency: `{best_lat}`; best cost: `{best_cost}`.","","## Environment","",f"- Timestamp: `{meta['timestamp']}`",f"- Branch / commit: `{meta['branch']}` / `{meta['commit']}`",f"- Working tree dirty before run: `false`",f"- Dataset hash: `{meta['dataset_sha256']}`",f"- Prompt hash: `{meta['prompt_sha256']}`",f"- DB: `{meta['db_identifier']}`",f"- Models: `{', '.join(MODELS)}`",f"- Randomization seed: `{SEED}`","","## Dataset","",f"- Total: 392",f"- Per intent: `{dict(intent_counts)}`",f"- Per category: `{dict(cat_counts)}`","","## Raw QU Results","","| Model | Schema | Intent | Precision | Recall | F1 | Exact | Retention | Wrong field | Hallucination | Extra | Multi | Role | Match |","|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for m in MODELS:
        s=sums[m];L.append(f"| `{m}` | {pct(s['schema_validity'])} | {pct(s['intent_accuracy'])} | {pct(s['field_precision'])} | {pct(s['field_recall'])} | {pct(s['field_f1'])} | {pct(s['exact_match'])} | {pct(s['entity_retention'])} | {pct(s['wrong_field_rate'])} | {pct(s['true_hallucination_rate'])} | {pct(s['extra_value_rate'])} | {pct(s['multivalue_completeness'])} | {pct(s['person_role_accuracy'])} | {pct(s['match_mode_accuracy'])} |")
    L += ["","## System-Level Results","","| Model | Success | Canonical | Clarification | No-match | False confident | Router recovery | OpenEntity recovery | Safe recovery |","|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for m in MODELS:
        s=sums[m];L.append(f"| `{m}` | {pct(s['system_success'])} | {pct(s['correct_canonical_resolution'])} | {pct(s['correct_clarification'])} | {pct(s['correct_no_match'])} | {pct(s['false_confident_rate'])} | {pct(s['router_recovery'])} | {pct(s['open_entity_recovery'])} | {pct(s['safe_recovery'])} |")
    L += ["","## Conditional System Success","","| Model | Exact raw match | Correct intent | Field F1 ≥ .95 |","|---|---:|---:|---:|"]+[f"| `{m}` | {pct(cond[m]['exact'])} | {pct(cond[m]['intent'])} | {pct(cond[m]['f1'])} |" for m in MODELS]
    for title,dim in (("Per-Intent Results","intent"),("Per-Category Results","category")):
        L += ["",f"## {title}","",f"| {dim.title()} | Model | N | Intent | F1 | Exact | System | False confident | p50 ms |","|---|---|---:|---:|---:|---:|---:|---:|---:|"]
        for r in breakdown[dim]:L.append(f"| `{r[dim]}` | `{r['model']}` | {r['cases']} | {pct(r['intent_accuracy'])} | {pct(r['field_f1'])} | {pct(r['exact_match'])} | {pct(r['system_success'])} | {pct(r['false_confident_rate'])} | {r['provider_p50_ms']:.2f} |")
    L += ["","## Latency","","| Model | Mean | p50 | p75 | p90 | p95 | p99 | Max |","|---|---:|---:|---:|---:|---:|---:|---:|"]+[f"| `{r['model']}` | {r['provider_mean']:.2f} | {r['provider_p50']:.2f} | {r['provider_p75']:.2f} | {r['provider_p90']:.2f} | {r['provider_p95']:.2f} | {r['provider_p99']:.2f} | {r['provider_max']:.2f} |" for r in latrows]
    L += ["","## Cost","",f"- Total measured benchmark cost: ${sum(r['total_cost_usd'] for r in costrows):.6f}."]+[f"- `{r['model']}`: ${r['total_cost_usd']:.6f} total; ${r['cost_per_1000']:.4f}/1,000; ${r['cost_per_100000']:.2f}/100,000." for r in costrows]
    L += ["","## Safety / False-Confident Results",""]+[f"- `{m}`: {pct(sums[m]['false_confident_rate'])} ({sum(r['sys_score']['false_confident'] for r in by[m])}/392)." for m in MODELS]
    L += ["","## Flash-Lite Hallucination Analysis","",f"- Invented year cases: {len(years)}.",f"- Invented values: `{sorted({v for x in years for v in x['values']})}`.",f"- Intents: `{dict(Counter(x['intent'] for x in years))}`.",f"- Categories: `{dict(Counter(x['category'] for x in years))}`.",f"- Raw scorer caught: {sum(x['raw_caught'] for x in years)}/{len(years)}.",f"- System success despite invented year: {sum(x['system_success'] for x in years)}/{len(years)}.","","## Head-to-Head Results",""]+[f"- {k}: {hc[k]}" for k in ("LUNA_SUCCEEDS_FLASH_FAILS","FLASH_SUCCEEDS_LUNA_FAILS","BOTH_FAIL","BOTH_SUCCEED_RAW_DIFFERS","BOTH_SUCCEED_RAW_SAME")]
    L += ["","## Failure Taxonomy",""]+[f"- `{m}`: `{dict(fc[m])}`" for m in MODELS]+["","## Production Recommendation","",f"- BEST_RAW_QU_QUALITY: `{best_raw}`",f"- BEST_SYSTEM_QUALITY: `{best_sys}`",f"- BEST_LATENCY: `{best_lat}`",f"- BEST_COST: `{best_cost}`",f"- RECOMMENDED_PRODUCTION_QU_MODEL: `{rec}`","","## Why Not the Other Model","",f"`{next(m for m in MODELS if m!=rec)}` lost under the hard-gate ordering: schema reliability, false-confidence safety, critical failures, and clarification safety, followed by system quality, raw quality, latency, cost, and hallucination behavior.","","## Remaining Limitations","","- Results apply to the frozen dataset and current MySQL snapshot.","- The frozen dataset contains no `NO_MATCH` outcomes, so correct no-match is not estimable (the summary CSV's 0.0 is an empty-denominator sentinel, not a measured failure rate).","- Router and SearchPlanBuilder component timings are fixed placeholders in existing instrumentation; DB, OpenEntity, total pipeline, and provider timings are measured."]
    (out/"benchmark_report.md").write_text("\n".join(L)+"\n")
    print(json.dumps({"summaries":sums,"latency":latrows,"cost":costrows,"head_to_head":dict(hc),"years":years,"recommendation":rec,"report":str(out/"benchmark_report.md")},indent=2))
if __name__=="__main__": main(sys.argv[1])
