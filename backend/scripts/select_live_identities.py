import asyncio,json
from sqlalchemy import text
from app.db.engine import get_engine

QUERIES={
"driver_only":"""SELECT d.driver_id,d.account_id,d.full_name FROM user_driver_profile d WHERE EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_driver_id=d.driver_id) AND NOT EXISTS(SELECT 1 FROM user_codriver_profile c JOIN rally_entry_list e ON e.user_co_driver_id=c.codriver_id WHERE c.account_id=d.account_id) AND d.full_name IS NOT NULL ORDER BY d.driver_id LIMIT 1""",
"codriver_only":"""SELECT c.codriver_id,c.account_id,c.full_name FROM user_codriver_profile c WHERE EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_co_driver_id=c.codriver_id) AND NOT EXISTS(SELECT 1 FROM user_driver_profile d JOIN rally_entry_list e ON e.user_driver_id=d.driver_id WHERE d.account_id=c.account_id) AND c.full_name IS NOT NULL ORDER BY c.codriver_id LIMIT 1""",
"dual_account":"""SELECT d.driver_id,c.codriver_id,d.account_id,d.full_name driver_name,c.full_name codriver_name FROM user_driver_profile d JOIN user_codriver_profile c ON c.account_id=d.account_id WHERE d.account_id IS NOT NULL AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_driver_id=d.driver_id) AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_co_driver_id=c.codriver_id) ORDER BY d.account_id LIMIT 1""",
"null_driver":"""SELECT d.driver_id,d.full_name FROM user_driver_profile d WHERE d.account_id IS NULL AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_driver_id=d.driver_id) ORDER BY d.driver_id LIMIT 1""",
"null_codriver":"""SELECT c.codriver_id,c.full_name FROM user_codriver_profile c WHERE c.account_id IS NULL AND EXISTS(SELECT 1 FROM rally_entry_list e WHERE e.user_co_driver_id=c.codriver_id) ORDER BY c.codriver_id LIMIT 1"""}

async def main():
 async with get_engine().connect() as conn:
  out={}
  for key,sql in QUERIES.items(): out[key]=dict((await conn.execute(text(sql))).mappings().first() or {})
 print(json.dumps(out,default=str,indent=2))
if __name__=="__main__":asyncio.run(main())
