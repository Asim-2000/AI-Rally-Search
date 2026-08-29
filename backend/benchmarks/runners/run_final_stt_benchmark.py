from __future__ import annotations
import asyncio, csv, datetime as dt, hashlib, json, math, re, subprocess, unicodedata, wave
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from statistics import fmean
from typing import Any
from benchmarks.providers.openai_stt import OpenAISTTAdapter
from benchmarks.providers.gemini_qu import GeminiQUAdapter
from benchmarks.runners.helpers import get_benchmark_api_keys
from benchmarks.scoring.stt_scoring import score_stt_result, _normalize_text
from benchmarks.scoring.system_scoring import evaluate_system_pipeline

MODELS=("whisper-1","gpt-4o-mini-transcribe","gpt-transcribe")
UNAVAILABLE=("gemini-3.5-transcribe",)
CONCURRENCY=4
PRICES={"whisper-1":.006,"gpt-4o-mini-transcribe":.003,"gpt-transcribe":.0045}

def duration(path:Path)->float:
    with wave.open(str(path),"rb") as w:return w.getnframes()/w.getframerate()
def cer(a,b):
    a=_normalize_text(a).replace(" ","");b=_normalize_text(b or "").replace(" ","")
    if not a:return 0 if not b else 1
    d=list(range(len(b)+1))
    for i,x in enumerate(a,1):
        q=[i]+[0]*len(b)
        for j,y in enumerate(b,1):q[j]=d[j-1] if x==y else 1+min(d[j],q[j-1],d[j-1])
        d=q
    return d[-1]/len(a)
def fold(x):return "".join(c for c in unicodedata.normalize("NFKD",_normalize_text(x)) if not unicodedata.combining(c))
def entity_class(text,transcript):
    a,b=_normalize_text(text),_normalize_text(transcript or "")
    if not transcript:return "ENTITY_DROPPED"
    if a in b:return "EXACT_ENTITY"
    if fold(a) in fold(b):return "NORMALIZED_ENTITY"
    words=b.split(); n=len(a.split()); spans=[" ".join(words[i:i+n]) for i in range(max(1,len(words)-n+1))]
    best=max([SequenceMatcher(None,fold(a),fold(x)).ratio() for x in spans] or [0])
    if best>=.68:return "RECOVERABLE_ENTITY_ERROR"
    return "ENTITY_SUBSTITUTED" if words else "ENTITY_DROPPED"
def q(vals,q):
    vals=sorted(vals);return round(vals[max(0,min(len(vals)-1,math.ceil(q*len(vals))-1))],2) if vals else 0
def lat(vals):return {"mean":round(fmean(vals),2),"p50":q(vals,.5),"p75":q(vals,.75),"p90":q(vals,.9),"p95":q(vals,.95),"p99":q(vals,.99),"max":round(max(vals),2)}
def rate(rs,fn):return sum(bool(fn(r)) for r in rs)/len(rs) if rs else 0
def avg(rs,fn):return fmean(fn(r) for r in rs) if rs else 0
def write_csv(p,rows):
    with p.open("w",newline="",encoding="utf-8") as f:w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

def build_cases(root:Path):
    corpus=json.loads((root/"test/eval/entity_search/synthetic_stt_biasing_report.json").read_text())["corpus"]["manifest"]
    cases=[]
    for x in corpus:
        if x["templateIndex"]!=0 or x["entityType"] not in {"rally","person","stage"}:continue
        p=root/"test/eval/audio/es6a"/f"{x['id']}_clean.wav"
        typ={"rally":"RALLY","person":"PERSON","stage":"STAGE"}[x["entityType"]]
        ents=[{"text":x["targetName"],"type":typ}]
        years=sorted({int(y) for y in re.findall(r"\b(?:19|20)\d{2}\b",x["text"])})
        ents += [{"text":str(y),"type":"YEAR"} for y in years if str(y) not in x["targetName"]]
        cases.append({"case_id":"synthetic_"+x["id"],"audio_path":str(p),"reference_text":x["text"],"entities":ents,"language":"en","noise_class":"clean","speaker_type":"synthetic","duration_seconds":duration(p),"expected_canonical":{"type":typ,"canonical_id":x["targetId"],"canonical_name":x["targetName"]}})
    hm=json.loads((root/"test/eval/entity_search/human_voice_smoke_manifest.json").read_text())
    for x in hm["fixtures"]:
        p=root/x["filePath"]; typ=x["expectedEntityType"]
        ent={"text":x["expectedEntityMention"],"type":typ if typ in {"RALLY","PERSON","STAGE","ACTION","YEAR"} else "RALLY"}
        canon=None
        if x.get("canonicalScorable"):canon={"type":typ,"canonical_id":x["expectedCanonicalId"],"canonical_name":x["expectedCanonicalName"]}
        cases.append({"case_id":x["fixtureId"],"audio_path":str(p),"reference_text":x["referenceTranscriptNormalized"],"entities":[ent],"language":x["language"],"noise_class":x.get("audioCondition") or "unknown","speaker_type":"human","speaker_id":x["speakerId"],"duration_seconds":duration(p),"expected_canonical":canon,"duplicate_audio_of":x.get("duplicateAudioOf")})
    assert len(cases)==115 and sum(c["speaker_type"]=="human" for c in cases)==5
    return cases

async def main():
    root=Path(__file__).resolve().parents[3]; keys=get_benchmark_api_keys(); cases=build_cases(root)
    ts=dt.datetime.now().astimezone().strftime("%Y%m%d_%H%M%S");out=root/"backend/benchmarks/results"/f"stt_{ts}";out.mkdir(parents=True)
    manifest=out/"evaluation_manifest.jsonl"
    manifest.write_text("".join(json.dumps(c,ensure_ascii=False)+"\n" for c in cases))
    adapters={m:OpenAISTTAdapter(keys["openai"],m,timeout_seconds=45) for m in MODELS};qu=GeminiQUAdapter(keys["gemini"],"gemini-3.5-flash-lite",timeout_seconds=45)
    names=defaultdict(list)
    for c in cases:
        if c["speaker_type"]=="synthetic":names[c["entities"][0]["type"]].append(c["entities"][0]["text"])
    sem=asyncio.Semaphore(CONCURRENCY)
    async def reference(c):
        async with sem:
            qr=await qu.parse_query(c["case_id"]+"_reference",c["reference_text"])
            gold={"case_id":c["case_id"],"input_text":c["reference_text"],"expected_resolution":{"outcome":"RESOLVED","canonical_entities":[c["expected_canonical"]] if c["expected_canonical"] else []}}
            sy=await evaluate_system_pipeline(gold,qr.parsed_query)
            return {"parsed_query":qr.parsed_query,"sys_score":sy,"qu_latency_ms":qr.latency_ms,"error":qr.error}
    refs=await asyncio.gather(*(reference(c) for c in cases));refmap={c["case_id"]:r for c,r in zip(cases,refs)}
    work=[(c,m) for c in cases for m in MODELS];done=0
    async def evaluate(c,m):
        nonlocal done
        async with sem:
            v=await adapters[m].transcribe(c["case_id"],c["audio_path"],language=c["language"])
            hint=", ".join(names[c["entities"][0]["type"]][:30])
            b=await adapters[m].transcribe(c["case_id"]+"_vocab",c["audio_path"],language=c["language"],prompt_hint=hint)
            sc=score_stt_result(c["reference_text"],v.transcript,c["entities"]);sc["cer"]=round(cer(c["reference_text"],v.transcript),4)
            classes=[{"text":e["text"],"type":e["type"],"classification":entity_class(e["text"],v.transcript)} for e in c["entities"]]
            qr=await qu.parse_query(c["case_id"]+"_"+m,v.transcript or "") if v.transcript else None
            gold={"case_id":c["case_id"],"input_text":v.transcript or "","expected_resolution":{"outcome":"RESOLVED","canonical_entities":[c["expected_canonical"]] if c["expected_canonical"] else []}}
            sy=await evaluate_system_pipeline(gold,qr.parsed_query if qr else None);rf=refmap[c["case_id"]]
            if not v.transcript:impact="STT_CAUSED_SYSTEM_FAILURE" if rf["sys_score"]["system_success"] else "NO_STT_IMPACT"
            elif sy["false_confident"] and not rf["sys_score"]["false_confident"]:impact="STT_CAUSED_FALSE_CONFIDENT"
            elif rf["sys_score"]["system_success"] and not sy["system_success"]:impact="STT_CAUSED_SYSTEM_FAILURE"
            elif sy["system_success"] and rf["sys_score"]["system_success"]:impact="STT_ERROR_RECOVERED" if qr.parsed_query==rf["parsed_query"] else "STT_CHANGED_QUERY_BUT_SYSTEM_SUCCEEDED"
            else:impact="NO_STT_IMPACT"
            done+=1
            if done%50==0:print(f"completed {done}/{len(work)}",flush=True)
            return {"model":m,**c,"vanilla":{"transcript":v.transcript,"latency_ms":v.latency_ms,"error":v.error,"score":sc,"entity_classifications":classes},"biased":{"transcript":b.transcript,"latency_ms":b.latency_ms,"error":b.error,"score":score_stt_result(c["reference_text"],b.transcript,c["entities"])},"reference_path":rf,"transcript_path":{"parsed_query":qr.parsed_query if qr else None,"qu_latency_ms":qr.latency_ms if qr else 0,"qu_error":qr.error if qr else None,"sys_score":sy},"correct_search_query":bool(qr and qr.parsed_query==rf["parsed_query"]),"correct_canonical_entity":sy["correct_canonical_resolution"],"correct_search_plan":sy["search_plan_type"]==rf["sys_score"]["search_plan_type"],"system_success":sy["system_success"],"correct_clarification":sy["correct_clarification"],"correct_no_match":sy["correct_no_match"],"false_confident":sy["false_confident"],"stt_impact":impact,"rtf":v.latency_ms/1000/c["duration_seconds"]}
    records=await asyncio.gather(*(evaluate(c,m) for c,m in work))
    with (out/"stt_raw_results.jsonl").open("w") as f:
        for r in records:f.write(json.dumps(r,ensure_ascii=False)+"\n")
    with (out/"stt_e2e_results.jsonl").open("w") as f:
        for r in records:f.write(json.dumps({k:r[k] for k in ("model","case_id","speaker_type","reference_text","expected_canonical","reference_path","transcript_path","correct_search_query","correct_canonical_entity","correct_search_plan","system_success","correct_clarification","correct_no_match","false_confident","stt_impact")},ensure_ascii=False)+"\n")
    by={m:[r for r in records if r["model"]==m] for m in MODELS}
    summaries=[];entityrows=[];latrows=[];costrows=[]
    for m,rs in by.items():
        summaries.append({"model":m,"cases":len(rs),"wer":avg(rs,lambda r:r["vanilla"]["score"]["wer"]),"cer":avg(rs,lambda r:r["vanilla"]["score"]["cer"]),"entity_preservation":avg(rs,lambda r:r["vanilla"]["score"]["entity_preservation_rate"]),"failure_rate":rate(rs,lambda r:r["vanilla"]["error"]),"system_success":rate(rs,lambda r:r["system_success"]),"false_confident_rate":rate(rs,lambda r:r["false_confident"]),"correct_search_query":rate(rs,lambda r:r["correct_search_query"]),"correct_canonical_entity":rate(rs,lambda r:r["correct_canonical_entity"]),"correct_search_plan":rate(rs,lambda r:r["correct_search_plan"])})
        for track in ("synthetic","human"):
            tr=[r for r in rs if r["speaker_type"]==track]
            for typ in ("RALLY","PERSON","STAGE","ACTION","YEAR"):
                cls=[x for r in tr for x in r["vanilla"]["entity_classifications"] if x["type"]==typ]
                entityrows.append({"model":m,"track":track,"entity_type":typ,"mentions":len(cls),"preservation_rate":rate(cls,lambda x:x["classification"] in {"EXACT_ENTITY","NORMALIZED_ENTITY","RECOVERABLE_ENTITY_ERROR"}),**{k.lower():sum(x["classification"]==k for x in cls) for k in ("EXACT_ENTITY","NORMALIZED_ENTITY","RECOVERABLE_ENTITY_ERROR","UNRECOVERABLE_ENTITY_ERROR","ENTITY_DROPPED","ENTITY_SUBSTITUTED")}})
        z=lat([r["vanilla"]["latency_ms"] for r in rs]);zr=lat([r["rtf"] for r in rs]);latrows.append({"model":m,**{f"latency_{k}":v for k,v in z.items()},**{f"rtf_{k}":v for k,v in zr.items()}})
        mins=sum(r["duration_seconds"] for r in rs)/60;cost=mins*PRICES[m];costrows.append({"model":m,"audio_minutes":round(mins,4),"verified_price_per_minute":PRICES[m],"vanilla_cost_usd":round(cost,6),"cost_per_1000_avg_utterances":round(cost/len(rs)*1000,4)})
    write_csv(out/"stt_summary.csv",summaries);write_csv(out/"stt_entity_summary.csv",entityrows);write_csv(out/"stt_latency_summary.csv",latrows);write_csv(out/"stt_cost_summary.csv",costrows)
    vocab=[]
    for m,rs in by.items():vocab.append({"model":m,"condition":"VANILLA","wer":avg(rs,lambda r:r["vanilla"]["score"]["wer"]),"entity_preservation":avg(rs,lambda r:r["vanilla"]["score"]["entity_preservation_rate"])});vocab.append({"model":m,"condition":"DB_CANONICAL_VOCABULARY","wer":avg(rs,lambda r:r["biased"]["score"]["wer"]),"entity_preservation":avg(rs,lambda r:r["biased"]["score"]["entity_preservation_rate"])})
    write_csv(out/"stt_vocabulary_comparison.csv",vocab)
    pairs=defaultdict(dict)
    for r in records:pairs[r["case_id"]][r["model"]]=r
    h=[]
    for cid,p in pairs.items():
        succ={m:p[m]["system_success"] for m in MODELS};
        if len(set(succ.values()))>1 or len({p[m]["vanilla"]["transcript"] for m in MODELS})>1:h.append({"case_id":cid,"track":p[MODELS[0]]["speaker_type"],"reference":p[MODELS[0]]["reference_text"],"success":succ,"transcripts":{m:p[m]["vanilla"]["transcript"] for m in MODELS}})
    with (out/"stt_head_to_head.jsonl").open("w") as f:
        for x in h:f.write(json.dumps(x,ensure_ascii=False)+"\n")
    dataset_hash=hashlib.sha256(manifest.read_bytes()).hexdigest();meta={"timestamp":ts,"branch":subprocess.check_output(["git","branch","--show-current"],text=True).strip(),"commit":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),"working_tree_dirty_before_stt_run":True,"fixed_qu_model":"gemini-3.5-flash-lite","models_measured":list(MODELS),"model_unavailable":{"gemini-3.5-transcribe":"listed and HTTP 200, but returned empty output with zero output tokens on inline and official Files API probes"},"cases":len(cases),"synthetic":110,"human_rows":5,"human_unique_waveforms":4,"human_speakers":1,"total_duration_seconds":sum(c["duration_seconds"] for c in cases),"dataset_sha256":dataset_hash,"concurrency":CONCURRENCY,"conditions":["VANILLA","DB_CANONICAL_VOCABULARY"]};(out/"run_metadata.json").write_text(json.dumps(meta,indent=2)+"\n")
    best_wer=min(MODELS,key=lambda m:next(x["wer"] for x in summaries if x["model"]==m));best_ent=max(MODELS,key=lambda m:next(x["entity_preservation"] for x in summaries if x["model"]==m));best_e2e=max(MODELS,key=lambda m:next(x["system_success"] for x in summaries if x["model"]==m));best_latency=min(MODELS,key=lambda m:next(x["latency_p95"] for x in latrows if x["model"]==m));best_cost=min(MODELS,key=lambda m:next(x["cost_per_1000_avg_utterances"] for x in costrows if x["model"]==m));finalists=sorted(MODELS,key=lambda m:(next(x["false_confident_rate"] for x in summaries if x["model"]==m),-next(x["entity_preservation"] for x in summaries if x["model"]==m),-next(x["system_success"] for x in summaries if x["model"]==m)))[:2]
    L=["# Final STT Benchmark","","## Executive Summary","",f"- Status: **STT BENCHMARK COMPLETE — HUMAN VALIDATION REQUIRED**",f"- Fixed QU: `gemini-3.5-flash-lite`",f"- Measured 115 audio rows: 110 synthetic and 5 human (4 unique waveforms, 1 speaker).",f"- Human evidence is insufficient for a production winner. Finalists: `{', '.join(finalists)}`.","","## Environment","",f"- Branch / commit: `{meta['branch']}` / `{meta['commit']}`",f"- Dataset SHA256: `{dataset_hash}`",f"- Working tree was dirty before STT run: `true`","","## Audio Dataset","",f"- Total utterances: 115",f"- Total minutes: {meta['total_duration_seconds']/60:.2f}","- Human: 5 rows, 4 unique waveforms, 1 speaker","- Synthetic: 110 controlled, clean English TTS rows","- Entity distribution: 30 rally, 50 person, 30 stage plus human labels","","## Provider / Model Access","","- `whisper-1`: measured","- `gpt-4o-mini-transcribe`: measured","- `gpt-transcribe`: measured","- `gemini-3.5-transcribe`: unavailable for measurement; HTTP 200 but empty output and zero output tokens on both tested official input paths.","","## Transcript Metrics","","| Model | WER | CER | Entity preservation | Failure |","|---|---:|---:|---:|---:|"]
    for x in summaries:L.append(f"| `{x['model']}` | {x['wer']:.1%} | {x['cer']:.1%} | {x['entity_preservation']:.1%} | {x['failure_rate']:.1%} |")
    L += ["","## Entity Preservation","","Detailed exact/normalized/recoverable/dropped/substituted counts by track and type are in `stt_entity_summary.csv`.","","## Human Results","","| Model | WER | Entity preservation | E2E success | False confident |","|---|---:|---:|---:|---:|"]
    for m in MODELS:
        rs=[r for r in by[m] if r["speaker_type"]=="human"];L.append(f"| `{m}` | {avg(rs,lambda r:r['vanilla']['score']['wer']):.1%} | {avg(rs,lambda r:r['vanilla']['score']['entity_preservation_rate']):.1%} | {rate(rs,lambda r:r['system_success']):.1%} | {rate(rs,lambda r:r['false_confident']):.1%} |")
    L += ["","## Synthetic Results","","| Model | WER | Entity preservation | E2E success | False confident |","|---|---:|---:|---:|---:|"]
    for m in MODELS:
        rs=[r for r in by[m] if r["speaker_type"]=="synthetic"];L.append(f"| `{m}` | {avg(rs,lambda r:r['vanilla']['score']['wer']):.1%} | {avg(rs,lambda r:r['vanilla']['score']['entity_preservation_rate']):.1%} | {rate(rs,lambda r:r['system_success']):.1%} | {rate(rs,lambda r:r['false_confident']):.1%} |")
    L += ["","## Latency","","| Model | p50 ms | p95 ms | p50 RTF | p95 RTF |","|---|---:|---:|---:|---:|"]+[f"| `{x['model']}` | {x['latency_p50']:.2f} | {x['latency_p95']:.2f} | {x['rtf_p50']:.3f} | {x['rtf_p95']:.3f} |" for x in latrows]
    L += ["","## Cost",""]+[f"- `{x['model']}`: ${x['vanilla_cost_usd']:.6f} vanilla; ${x['cost_per_1000_avg_utterances']:.4f}/1,000 average benchmark utterances." for x in costrows]
    L += ["","## End-to-End Search Results","","| Model | Query match | Canonical | Plan | System success | False confident |","|---|---:|---:|---:|---:|---:|"]+[f"| `{x['model']}` | {x['correct_search_query']:.1%} | {x['correct_canonical_entity']:.1%} | {x['correct_search_plan']:.1%} | {x['system_success']:.1%} | {x['false_confident_rate']:.1%} |" for x in summaries]
    L += ["","## STT-Induced Failures",""]+[f"- `{m}`: `{dict(Counter(r['stt_impact'] for r in by[m]))}`" for m in MODELS]+["","## False-Confident Analysis","",f"- Counts: `{ {m:sum(r['false_confident'] for r in by[m]) for m in MODELS} }`.","","## Vocabulary Bias Experiment","","Separate vanilla and DB-canonical-vocabulary transcript metrics are in `stt_vocabulary_comparison.csv`; biased transcripts are not mixed into vanilla or E2E results.","","## Head-to-Head Cases","",f"- {len(h)} differing transcript/outcome cases saved in `stt_head_to_head.jsonl`.","","## Model Recommendation","",f"- BEST_TRANSCRIPT_ACCURACY: `{best_wer}`",f"- BEST_ENTITY_PRESERVATION: `{best_ent}`",f"- BEST_END_TO_END: `{best_e2e}`",f"- BEST_LATENCY: `{best_latency}`",f"- BEST_COST: `{best_cost}`",f"- RECOMMENDED_STT_FINALISTS_FOR_HUMAN_TEST: `{', '.join(finalists)}`","","## Remaining Limitations","","- Only four unique human waveforms from one speaker are available; no production winner is declared.","- Synthetic TTS cannot validate real accents, microphones, hesitations, or environmental noise.","- The Google candidate was listed but produced no transcript output during verified probes.","- E2E comparisons use the frozen fixed-QU reference path to isolate STT damage from known downstream weaknesses."]
    report=out/"stt_benchmark_report.md";report.write_text("\n".join(L)+"\n");print(json.dumps({"out":str(out),"summaries":summaries,"latency":latrows,"cost":costrows,"finalists":finalists},indent=2))
if __name__=="__main__":asyncio.run(main())
