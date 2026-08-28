"""Explicitly refresh the private live-identity fixture. Never prints live IDs."""
import argparse,asyncio,hashlib,json
from datetime import datetime,timezone
from pathlib import Path
from sqlalchemy import text
from app.db.engine import get_engine

SELECTIONS={
 "IDENTITY_DRIVER_ONLY_01":("DRIVER_ONLY_ACCOUNT_BACKED","""SELECT d.driver_id,d.account_id FROM user_driver_profile d WHERE d.account_id IS NOT NULL AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_driver_id=d.driver_id) AND NOT EXISTS(SELECT 1 FROM user_codriver_profile c WHERE c.account_id=d.account_id) ORDER BY d.driver_id LIMIT 1""","driver account non-null; participation exists; no codriver profile for account"),
 "IDENTITY_CODRIVER_ONLY_01":("CODRIVER_ONLY_ACCOUNT_BACKED","""SELECT c.codriver_id,c.account_id FROM user_codriver_profile c WHERE c.account_id IS NOT NULL AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_co_driver_id=c.codriver_id) AND NOT EXISTS(SELECT 1 FROM user_driver_profile d WHERE d.account_id=c.account_id) ORDER BY c.codriver_id LIMIT 1""","codriver account non-null; participation exists; no driver profile for account"),
 "IDENTITY_DUAL_ROLE_01":("DUAL_ROLE_ACCOUNT_BACKED","""SELECT d.driver_id,c.codriver_id,d.account_id FROM user_driver_profile d JOIN user_codriver_profile c ON c.account_id=d.account_id WHERE d.account_id IS NOT NULL AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_driver_id=d.driver_id) AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_co_driver_id=c.codriver_id) ORDER BY d.account_id LIMIT 1""","same non-null account bridges participating driver and codriver profiles"),
 "IDENTITY_NULL_DRIVER_01":("NULL_ACCOUNT_DRIVER","""SELECT d.driver_id FROM user_driver_profile d WHERE d.account_id IS NULL AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_driver_id=d.driver_id) ORDER BY d.driver_id LIMIT 1""","driver account null; participation exists"),
 "IDENTITY_NULL_CODRIVER_01":("NULL_ACCOUNT_CODRIVER","""SELECT c.codriver_id FROM user_codriver_profile c WHERE c.account_id IS NULL AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_co_driver_id=c.codriver_id) ORDER BY c.codriver_id LIMIT 1""","codriver account null; participation exists"),
}

async def main(output:Path):
 identities=[]
 async with get_engine().connect() as conn:
  for alias,(category,sql,predicate) in SELECTIONS.items():
   row=dict((await conn.execute(text(sql))).mappings().one())
   account=row.get("account_id"); driver=row.get("driver_id"); codriver=row.get("codriver_id")
   canonical=f"account:{account}" if account else f"person:driver:{driver}" if driver else f"person:codriver:{codriver}"
   identities.append({"alias":alias,"category":category,"canonicalIdentity":canonical,"accountId":str(account) if account else None,"driverId":str(driver) if driver else None,"codriverId":str(codriver) if codriver else None,"categoryPredicate":predicate})
 payload={"schemaVersion":"1.0","selectionTimestamp":datetime.now(timezone.utc).isoformat(),"identities":identities}
 canonical=json.dumps(payload,sort_keys=True,separators=(",",":")); payload["fixtureHash"]="sha256:"+hashlib.sha256(canonical.encode()).hexdigest()
 output.parent.mkdir(parents=True,exist_ok=True); output.write_text(json.dumps(payload,indent=2)+"\n")
 print(json.dumps({"status":"refreshed","aliases":[x["alias"] for x in identities],"count":len(identities)}))

if __name__=="__main__":
 p=argparse.ArgumentParser();p.add_argument("output",type=Path);a=p.parse_args();asyncio.run(main(a.output))
