"""Fail frozen fixtures on category drift; output contains aliases only."""
import argparse,asyncio,hashlib,json
from pathlib import Path
from sqlalchemy import text
from app.db.engine import get_engine

async def scalar(conn,sql,params):return int((await conn.execute(text(sql),params)).scalar_one() or 0)

async def main(path:Path,report_path:Path|None):
 fixture=json.loads(path.read_text()); statuses=[]
 stored_hash=fixture.get("fixtureHash"); hash_payload={k:v for k,v in fixture.items() if k!="fixtureHash"}
 canonical=json.dumps(hash_payload,sort_keys=True,separators=(",",":")); hash_valid=stored_hash=="sha256:"+hashlib.sha256(canonical.encode()).hexdigest()
 async with get_engine().connect() as conn:
  for x in fixture["identities"]:
   p={"a":x.get("accountId"),"d":x.get("driverId"),"c":x.get("codriverId")};cat=x["category"]
   if cat=="DRIVER_ONLY_ACCOUNT_BACKED": valid=await scalar(conn,"SELECT COUNT(*) FROM user_driver_profile d WHERE d.driver_id=:d AND d.account_id=:a AND NOT EXISTS(SELECT 1 FROM user_codriver_profile c WHERE c.account_id=d.account_id)",p)==1
   elif cat=="CODRIVER_ONLY_ACCOUNT_BACKED": valid=await scalar(conn,"SELECT COUNT(*) FROM user_codriver_profile c WHERE c.codriver_id=:c AND c.account_id=:a AND NOT EXISTS(SELECT 1 FROM user_driver_profile d WHERE d.account_id=c.account_id)",p)==1
   elif cat=="DUAL_ROLE_ACCOUNT_BACKED": valid=await scalar(conn,"SELECT COUNT(*) FROM user_driver_profile d JOIN user_codriver_profile c ON c.account_id=d.account_id WHERE d.driver_id=:d AND c.codriver_id=:c AND d.account_id=:a AND d.account_id IS NOT NULL",p)==1
   elif cat=="NULL_ACCOUNT_DRIVER": valid=await scalar(conn,"SELECT COUNT(*) FROM user_driver_profile WHERE driver_id=:d AND account_id IS NULL",p)==1
   else: valid=await scalar(conn,"SELECT COUNT(*) FROM user_codriver_profile WHERE codriver_id=:c AND account_id IS NULL",p)==1
   same_name=None
   if cat=="NULL_ACCOUNT_DRIVER": same_name=await scalar(conn,"SELECT COUNT(*) FROM user_codriver_profile c WHERE LOWER(TRIM(c.full_name))=(SELECT LOWER(TRIM(d.full_name)) FROM user_driver_profile d WHERE d.driver_id=:d)",p)
   elif cat=="NULL_ACCOUNT_CODRIVER": same_name=await scalar(conn,"SELECT COUNT(*) FROM user_driver_profile d WHERE LOWER(TRIM(d.full_name))=(SELECT LOWER(TRIM(c.full_name)) FROM user_codriver_profile c WHERE c.codriver_id=:c)",p)
   statuses.append({"alias":x["alias"],"valid":valid,"sameNameOppositeProfileCount":same_name})
 result={"status":"valid" if hash_valid and all(x["valid"] for x in statuses) else "stale","fixtureHashValid":hash_valid,"statuses":statuses}
 if report_path: report_path.write_text(json.dumps(result,indent=2)+"\n")
 if result["status"]!="valid":
  result["code"]="STALE_LIVE_IDENTITY_FIXTURE";print(json.dumps(result));raise SystemExit(2)
 print(json.dumps(result))

if __name__=="__main__":
 p=argparse.ArgumentParser();p.add_argument("fixture",type=Path);p.add_argument("--report",type=Path);a=p.parse_args();asyncio.run(main(a.fixture,a.report))
