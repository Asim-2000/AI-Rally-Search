"""Redacted semantic audit: union, role isolation, and data availability."""
import argparse,json
from pathlib import Path

def load(path):return {x["caseId"]:x for x in (json.loads(line) for line in Path(path).read_text().splitlines())}

def main(matrix_path,dart_path,python_path,raw_path,output_path):
 matrix=json.loads(Path(matrix_path).read_text());dart=load(dart_path);python=load(python_path);raw=load(raw_path)
 aliases=sorted({x["identityAlias"] for x in matrix["cases"]});rows=[];all_exact=True
 for alias in aliases:
  category=next(x["identityCategory"] for x in matrix["cases"] if x["identityAlias"]==alias)
  by={}
  for kind in ("participation","videos","actions"):
   role_data={}
   for role in ("driver","co_driver","any"):
    cid=f"{alias.lower()}-{kind}-{role}";d=dart[cid];p=python[cid];r=raw[cid]
    exact=d["orderedCanonicalIds"]==p["orderedCanonicalIds"]==r["orderedCanonicalIds"] and d["total"]==p["total"]==r["total"]
    all_exact &= exact;role_data[role]={"count":d["total"],"exact":exact,"ids":d["orderedCanonicalIds"]}
   by[kind]=role_data
  part=by["participation"];driver=set(part["driver"]["ids"]);codriver=set(part["co_driver"]["ids"]);any_ids=part["any"]["ids"]
  union_exact=set(any_ids)==driver|codriver and len(any_ids)==len(set(any_ids))
  if category in ("DRIVER_ONLY_ACCOUNT_BACKED","NULL_ACCOUNT_DRIVER"): isolation=part["co_driver"]["count"]==0 and set(any_ids)==driver
  elif category in ("CODRIVER_ONLY_ACCOUNT_BACKED","NULL_ACCOUNT_CODRIVER"): isolation=part["driver"]["count"]==0 and set(any_ids)==codriver
  else:isolation=union_exact
  all_exact &= union_exact and isolation
  rows.append({"alias":alias,"category":category,"driverCount":part["driver"]["count"],"codriverCount":part["co_driver"]["count"],"intersectionCount":len(driver&codriver),"anyCount":part["any"]["count"],"unionExact":union_exact,"roleIsolationExact":isolation,"videosHaveUsableData":any(by["videos"][x]["count"] for x in by["videos"]),"actionsHaveUsableData":any(by["actions"][x]["count"] for x in by["actions"]),"allRuntimeCasesExact":all(by[k][r]["exact"] for k in by for r in by[k])})
 report={"schemaVersion":"1.0","summary":{"identities":len(rows),"cases":len(matrix["cases"]),"exact":all_exact},"identities":rows}
 Path(output_path).write_text(json.dumps(report,indent=2)+"\n");print(json.dumps(report["summary"]));return 0 if all_exact else 1

if __name__=="__main__":
 p=argparse.ArgumentParser();p.add_argument("matrix");p.add_argument("dart");p.add_argument("python");p.add_argument("raw");p.add_argument("output");a=p.parse_args();raise SystemExit(main(a.matrix,a.dart,a.python,a.raw,a.output))
