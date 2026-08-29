"""Generate shared SearchQuery cases from the frozen identity fixture."""
import argparse,json
from pathlib import Path

ROLES=("DRIVER","CO_DRIVER","ANY")
INTENTS=("SEARCH_DRIVER_RALLIES","SEARCH_DRIVER_VIDEOS","SEARCH_VIDEO_ACTIONS")

def main(identity_path:Path,output:Path):
 source=json.loads(identity_path.read_text()); cases=[]
 for identity in source["identities"]:
  ids=[x for x in (identity.get("driverId"),identity.get("codriverId")) if x]
  for intent in INTENTS:
   for role in ROLES:
    suffix={"SEARCH_DRIVER_RALLIES":"participation","SEARCH_DRIVER_VIDEOS":"videos","SEARCH_VIDEO_ACTIONS":"actions"}[intent]
    cases.append({"caseId":f'{identity["alias"].lower()}-{suffix}-{role.lower()}',"description":f'{identity["alias"]} {suffix} {role}',"identityAlias":identity["alias"],"identityCategory":identity["category"],"searchQuery":{"intent":intent,"driverIds":ids,"personRole":role,"limit":500},"expectedIntent":intent,"comparisonType":"RAW_DART_PYTHON","oracle":"identity_matrix"})
 document={"schemaVersion":"1.0","identityFixtureHash":source["fixtureHash"],"cases":cases}
 output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(document,indent=2)+"\n")
 print(json.dumps({"status":"built","caseCount":len(cases),"identityAliases":[x["alias"] for x in source["identities"]]}))

if __name__=="__main__":
 p=argparse.ArgumentParser();p.add_argument("identities",type=Path);p.add_argument("output",type=Path);a=p.parse_args();main(a.identities,a.output)
