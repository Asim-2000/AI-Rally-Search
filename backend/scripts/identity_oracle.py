"""Independent role-matrix oracle using direct relational audit queries only."""
import argparse,asyncio,json
from pathlib import Path
from sqlalchemy import text
from app.db.engine import get_engine

def id_predicate(role,ids,driver_col,codriver_col,params):
 terms=[]
 for i,value in enumerate(ids):params[f"id{i}"]=value
 placeholders=",".join(f":id{i}" for i in range(len(ids)))
 if role in ("DRIVER","ANY"):terms.append(f"{driver_col} IN ({placeholders})")
 if role in ("CO_DRIVER","ANY"):terms.append(f"{codriver_col} IN ({placeholders})")
 return "("+" OR ".join(terms)+")"

async def query_case(conn,case):
 q=case["searchQuery"];ids=q["driverIds"];role=q["personRole"];params={"limit":q["limit"],"offset":q.get("offset",0)}
 intent=q["intent"]
 if intent=="SEARCH_DRIVER_RALLIES":
  pred=id_predicate(role,ids,"entry.user_driver_id","entry.user_co_driver_id",params)
  joins="FROM rally_events event JOIN rally_sub_events sub ON sub.event_id=event.event_id JOIN rally_entry_list entry ON entry.sub_event_id=sub.sub_event_id"
  sql=f"SELECT DISTINCT event.event_id {joins} WHERE {pred} ORDER BY event.start_date DESC LIMIT :limit OFFSET :offset"
  total_sql=f"SELECT COUNT(DISTINCT event.event_id) {joins} WHERE {pred}"
 elif intent=="SEARCH_DRIVER_VIDEOS":
  pred=id_predicate(role,ids,"entry.user_driver_id","entry.user_co_driver_id",params)
  joins="FROM rally_videos video JOIN rally_video_metadata attribution ON attribution.video_id=video.id JOIN rally_entry_list entry ON entry.id=attribution.entry_list_id JOIN rally_streams playable ON playable.video_id=video.id"
  valid="playable.on_demand_url IS NOT NULL AND playable.on_demand_url!='' AND (playable.video_type IS NULL OR playable.video_type!='instantReplay')"
  sql=f"SELECT DISTINCT video.id {joins} WHERE {valid} AND {pred} ORDER BY video.id DESC LIMIT :limit OFFSET :offset"
  total_sql=f"SELECT COUNT(DISTINCT video.id) {joins} WHERE {valid} AND {pred}"
 else:
  pred=id_predicate(role,ids,"entry.user_driver_id","entry.user_co_driver_id",params)
  joins="FROM rally_video_metadata attribution JOIN rally_streams playable ON playable.video_id=attribution.video_id JOIN rally_entry_list entry ON entry.id=attribution.entry_list_id"
  valid="playable.on_demand_url IS NOT NULL AND playable.on_demand_url!='' AND (playable.video_type IS NULL OR playable.video_type!='instantReplay')"
  sql=f"SELECT DISTINCT attribution.id {joins} WHERE {valid} AND {pred} ORDER BY attribution.id DESC LIMIT :limit OFFSET :offset"
  total_sql=f"SELECT COUNT(DISTINCT attribution.id) {joins} WHERE {valid} AND {pred}"
 result=await conn.execute(text(sql),params);ordered=[str(x) for x in result.scalars().all()]
 total=int((await conn.execute(text(total_sql),params)).scalar_one() or 0)
 return ordered,total

async def main(matrix_path:Path,output_path:Path):
 matrix=json.loads(matrix_path.read_text())
 with output_path.open("w") as sink:
  async with get_engine().connect() as conn:
   for case in matrix["cases"]:
    ids,total=await query_case(conn,case)
    sink.write(json.dumps({"schemaVersion":"1.0","runtime":"raw_db","caseId":case["caseId"],"searchQuery":case["searchQuery"],"orderedCanonicalIds":ids,"total":total})+"\n")
 print(json.dumps({"status":"complete","auditedCases":len(matrix["cases"])}))

if __name__=="__main__":
 p=argparse.ArgumentParser();p.add_argument("matrix",type=Path);p.add_argument("output",type=Path);a=p.parse_args();asyncio.run(main(a.matrix,a.output))
