from __future__ import annotations
import csv,json,re,sys
from collections import Counter
from pathlib import Path
from statistics import fmean

MODELS=("whisper-1","gpt-4o-mini-transcribe","gpt-transcribe")
PRICES={"whisper-1":.006,"gpt-4o-mini-transcribe":.003,"gpt-transcribe":.0045}
def rate(rs,k):return sum(bool(k(r)) for r in rs)/len(rs) if rs else 0
def avg(rs,k):return fmean(k(r) for r in rs) if rs else 0
def write_csv(p,rows):
    with p.open("w",newline="",encoding="utf-8") as f:w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def main(path):
    p=Path(path); raw=p/"stt_raw_results.jsonl";rs=[json.loads(x) for x in raw.read_text().splitlines()]
    for r in rs:
        sy=r["transcript_path"]["sys_score"];rf=r["reference_path"]["sys_score"]
        induced=bool(r["expected_canonical"] and rf["system_success"] and not sy["correct_canonical_resolution"] and sy["outcome"]=="RESOLVED" and sy["db_count"]>0)
        r["false_confident"]=bool(sy["false_confident"] or induced)
        r["stt_induced_false_confident"]=induced
        if induced:r["stt_impact"]="STT_CAUSED_FALSE_CONFIDENT"
    raw.write_text("".join(json.dumps(r,ensure_ascii=False)+"\n" for r in rs))
    with (p/"stt_e2e_results.jsonl").open("w") as f:
        for r in rs:f.write(json.dumps({k:r[k] for k in ("model","case_id","speaker_type","reference_text","expected_canonical","reference_path","transcript_path","correct_search_query","correct_canonical_entity","correct_search_plan","system_success","correct_clarification","correct_no_match","false_confident","stt_induced_false_confident","stt_impact")},ensure_ascii=False)+"\n")
    by={m:[r for r in rs if r["model"]==m] for m in MODELS};s=[]
    for m,z in by.items():s.append({"model":m,"cases":len(z),"wer":avg(z,lambda r:r["vanilla"]["score"]["wer"]),"cer":avg(z,lambda r:r["vanilla"]["score"]["cer"]),"entity_preservation":avg(z,lambda r:r["vanilla"]["score"]["entity_preservation_rate"]),"failure_rate":rate(z,lambda r:r["vanilla"]["error"]),"system_success":rate(z,lambda r:r["system_success"]),"false_confident_rate":rate(z,lambda r:r["false_confident"]),"correct_search_query":rate(z,lambda r:r["correct_search_query"]),"correct_canonical_entity":rate(z,lambda r:r["correct_canonical_entity"]),"correct_search_plan":rate(z,lambda r:r["correct_search_plan"])})
    write_csv(p/"stt_summary.csv",s)
    costs=[]
    for m,z in by.items():
        mins=sum(r["duration_seconds"] for r in z)/60; vanilla=mins*PRICES[m]
        costs.append({"model":m,"audio_minutes_per_condition":round(mins,4),"conditions":2,"total_billed_audio_minutes":round(mins*2,4),"verified_price_per_minute":PRICES[m],"vanilla_cost_usd":round(vanilla,6),"total_stt_benchmark_cost_usd":round(vanilla*2,6),"cost_per_1000_average_utterances":round(vanilla/len(z)*1000,4)})
    write_csv(p/"stt_cost_summary.csv",costs)
    finalists=sorted(MODELS,key=lambda m:(rate(by[m],lambda r:r["false_confident"]),-avg(by[m],lambda r:r["vanilla"]["score"]["entity_preservation_rate"]),-rate(by[m],lambda r:r["system_success"])))[:2]
    meta=json.loads((p/"run_metadata.json").read_text());meta["derived_metric_audit"]={"stt_false_confident_definition":"reference path succeeds; transcript path confidently resolves with DB results but misses expected canonical entity","false_confident_counts":{m:sum(r["false_confident"] for r in by[m]) for m in MODELS},"finalists":finalists};(p/"run_metadata.json").write_text(json.dumps(meta,indent=2)+"\n")
    report=(p/"stt_benchmark_report.md").read_text()
    def summary_row(m):
        x=next(v for v in s if v["model"]==m);return f"| `{m}` | {x['wer']:.1%} | {x['cer']:.1%} | {x['entity_preservation']:.1%} | {x['failure_rate']:.1%} |"
    report=re.sub(r"\| `whisper-1` \| [^\n]+\|\n\| `gpt-4o-mini-transcribe` \| [^\n]+\|\n\| `gpt-transcribe` \| [^\n]+\|",summary_row(MODELS[0])+"\n"+summary_row(MODELS[1])+"\n"+summary_row(MODELS[2]),report,count=1)
    for track,heading in (("human","## Human Results"),("synthetic","## Synthetic Results")):
        rows=[]
        for m in MODELS:
            z=[r for r in by[m] if r["speaker_type"]==track];rows.append(f"| `{m}` | {avg(z,lambda r:r['vanilla']['score']['wer']):.1%} | {avg(z,lambda r:r['vanilla']['score']['entity_preservation_rate']):.1%} | {rate(z,lambda r:r['system_success']):.1%} | {rate(z,lambda r:r['false_confident']):.1%} |")
        start=report.index(heading);table=report.index("| Model |",start);end=report.index("\n\n",table)
        header="| Model | WER | Entity preservation | E2E success | False confident |\n|---|---:|---:|---:|---:|\n"
        report=report[:table]+header+"\n".join(rows)+report[end:]
    erows=[]
    for m in MODELS:
        x=next(v for v in s if v["model"]==m);erows.append(f"| `{m}` | {x['correct_search_query']:.1%} | {x['correct_canonical_entity']:.1%} | {x['correct_search_plan']:.1%} | {x['system_success']:.1%} | {x['false_confident_rate']:.1%} |")
    start=report.index("## End-to-End Search Results");table=report.index("| Model |",start);end=report.index("\n\n",table);header="| Model | Query match | Canonical | Plan | System success | False confident |\n|---|---:|---:|---:|---:|---:|\n";report=report[:table]+header+"\n".join(erows)+report[end:]
    impacts="\n".join(f"- `{m}`: `{dict(Counter(r['stt_impact'] for r in by[m]))}`" for m in MODELS);report=re.sub(r"## STT-Induced Failures\n\n.*?\n\n## False-Confident Analysis",f"## STT-Induced Failures\n\n{impacts}\n\n## False-Confident Analysis",report,flags=re.S)
    fc={m:sum(r["false_confident"] for r in by[m]) for m in MODELS};report=re.sub(r"- Counts: `.*?`\.",f"- STT-induced false-confident counts: `{fc}`.",report)
    costlines=[f"- Total STT benchmark cost across vanilla + vocabulary conditions: ${sum(x['total_stt_benchmark_cost_usd'] for x in costs):.6f}."]+[f"- `{x['model']}`: ${x['vanilla_cost_usd']:.6f} vanilla; ${x['total_stt_benchmark_cost_usd']:.6f} both conditions; ${x['cost_per_1000_average_utterances']:.4f}/1,000 average utterances." for x in costs]
    report=re.sub(r"## Cost\n\n.*?\n\n## End-to-End", "## Cost\n\n"+"\n".join(costlines)+"\n\n## End-to-End",report,flags=re.S)
    report=re.sub(r"- RECOMMENDED_STT_FINALISTS_FOR_HUMAN_TEST: `.*?`",f"- RECOMMENDED_STT_FINALISTS_FOR_HUMAN_TEST: `{', '.join(finalists)}`",report)
    report=report.replace("Human evidence is insufficient for a production winner. Finalists: `gpt-4o-mini-transcribe, whisper-1`.",f"Human evidence is insufficient for a production winner. Safety-gated finalists: `{', '.join(finalists)}`.")
    (p/"stt_benchmark_report.md").write_text(report)
    print(json.dumps({"false_confident":fc,"finalists":finalists,"total_cost":sum(x["total_stt_benchmark_cost_usd"] for x in costs)},indent=2))
if __name__=="__main__":main(sys.argv[1])
