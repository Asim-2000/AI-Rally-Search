import argparse,json
from pathlib import Path

def load_jsonl(path): return {x["caseId"]:x for x in (json.loads(line) for line in Path(path).read_text().splitlines() if line)}
def first_diff(a,b):
    for i,(x,y) in enumerate(zip(a,b)):
        if x!=y:return i
    return min(len(a),len(b)) if len(a)!=len(b) else None

def main(fixtures,dart_path,python_path,raw_path,output):
    fixture_doc=json.loads(Path(fixtures).read_text()); fixture_map={x["caseId"]:x for x in fixture_doc["cases"]}
    dart=load_jsonl(dart_path); python=load_jsonl(python_path); raw=load_jsonl(raw_path) if raw_path and Path(raw_path).exists() else {}
    cases=[]
    for case_id,fixture in fixture_map.items():
        d=dart.get(case_id); p=python.get(case_id); oracle=raw.get(case_id)
        d_ids=d and d["orderedCanonicalIds"]; p_ids=p and p["orderedCanonicalIds"]; raw_ids=oracle and oracle["orderedCanonicalIds"]
        exact=bool(d and p and d_ids==p_ids and d["total"]==p["total"])
        raw_exact=oracle is None or (d_ids==raw_ids and p_ids==raw_ids and d["total"]==p["total"]==oracle["total"])
        classification=None
        if not exact:
            classification="UNDEFINED_ORDERING" if d and p and sorted(d_ids)==sorted(p_ids) and d["total"]==p["total"] else "PYTHON_PORT_BUG"
        if exact and not raw_exact: classification="DART_EXISTING_BUG" if d_ids==p_ids else "UNKNOWN"
        cases.append({"caseId":case_id,"searchQuery":fixture["searchQuery"],"exact":exact,"rawExact":raw_exact,"dartIds":d_ids,"pythonIds":p_ids,"rawExpectedIds":raw_ids,"firstDifferingIndex":first_diff(d_ids or [],p_ids or []),"dartTotal":d and d["total"],"pythonTotal":p and p["total"],"rawTotal":oracle and oracle["total"],"classification":classification})
    pages={}
    for fixture in fixture_doc["cases"]:
        if fixture.get("pageGroup"): pages.setdefault(fixture["pageGroup"],[]).append(fixture["caseId"])
    page_results={}
    for group,ids in pages.items():
        dpages=[dart[x]["orderedCanonicalIds"] for x in ids]; ppages=[python[x]["orderedCanonicalIds"] for x in ids]
        page_results[group]={"dartNoDuplicates":all(len(x)==len(set(x)) for x in dpages),"pythonNoDuplicates":all(len(x)==len(set(x)) for x in ppages),"dartNoOverlap":set(dpages[0]).isdisjoint(dpages[1]),"pythonNoOverlap":set(ppages[0]).isdisjoint(ppages[1]),"sameTotals":len({dart[x]["total"] for x in ids}|{python[x]["total"] for x in ids})==1}
    report={"schemaVersion":"1.0","summary":{"fixtures":len(cases),"exact":sum(x["exact"] for x in cases),"failed":sum(not x["exact"] for x in cases),"audited":sum(x["rawExpectedIds"] is not None for x in cases),"auditedExact":sum(x["rawExpectedIds"] is not None and x["rawExact"] for x in cases)},"pagination":page_results,"cases":cases}
    output_path=Path(output); output_path.parent.mkdir(parents=True,exist_ok=True)
    output_path.write_text(json.dumps(report,indent=2)+"\n")
    return 0 if report["summary"]["failed"]==0 and report["summary"]["audited"]==report["summary"]["auditedExact"] else 1

if __name__=="__main__":
    p=argparse.ArgumentParser(); p.add_argument("fixtures"); p.add_argument("dart"); p.add_argument("python"); p.add_argument("output"); p.add_argument("--raw"); a=p.parse_args(); raise SystemExit(main(a.fixtures,a.dart,a.python,a.raw,a.output))
