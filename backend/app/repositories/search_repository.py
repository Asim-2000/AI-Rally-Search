from sqlalchemy.ext.asyncio import AsyncConnection
from ..domain.person import CanonicalPerson
from ..domain.results import *
from ..domain.search_intent import SearchIntent
from ..domain.search_query import MatchMode, SearchQuery
from .sql import FINAL_STAGE, Filters, count, rows

class SearchRepository:
    def __init__(self, connection: AsyncConnection): self.conn = connection

    async def search(self, q: SearchQuery) -> SearchResponse:
        handlers = {
            SearchIntent.SEARCH_RALLIES: self.rallies,
            SearchIntent.SEARCH_DRIVER_RALLIES: self.participations,
            SearchIntent.SEARCH_DRIVER_WINS: self.driver_wins,
            SearchIntent.GET_RALLY_RESULTS: self.rally_results,
            SearchIntent.GET_RALLY_TOP_FINISHERS: self.top_finishers,
            SearchIntent.SEARCH_VIDEO_ACTIONS: self.video_actions,
            SearchIntent.SEARCH_DRIVER_VIDEOS: self.driver_videos,
            SearchIntent.GET_TOP_UPLOADERS: self.top_uploaders,
            SearchIntent.GET_TOP_DRIVERS_BY_WINS: self.top_drivers,
        }
        items, total = await handlers[q.intent](q)
        return SearchResponse(intent=q.intent, results=items, total_count=total,
            has_more=q.offset + len(items) < total, limit=q.limit, offset=q.offset)

    async def rallies(self, q):
        f=Filters().common(q)
        people=f.people(q,"dpx","cdpx","elx")
        if people:
            if q.driver_match_mode == MatchMode.ALL:
                for expr in people: f.clauses.append(f"ev.event_id IN (SELECT DISTINCT sex.event_id FROM rally_entry_list elx JOIN rally_sub_events sex ON elx.sub_event_id=sex.sub_event_id LEFT JOIN user_driver_profile dpx ON elx.user_driver_id=dpx.driver_id LEFT JOIN user_codriver_profile cdpx ON elx.user_co_driver_id=cdpx.codriver_id WHERE {expr})")
            else: f.clauses.append(f"ev.event_id IN (SELECT DISTINCT sex.event_id FROM rally_entry_list elx JOIN rally_sub_events sex ON elx.sub_event_id=sex.sub_event_id LEFT JOIN user_driver_profile dpx ON elx.user_driver_id=dpx.driver_id LEFT JOIN user_codriver_profile cdpx ON elx.user_co_driver_id=cdpx.codriver_id WHERE {' OR '.join(people)})")
        base="FROM rally_events ev LEFT JOIN rally_stages stg ON ev.event_id=stg.event_id " + f.where
        data=await rows(self.conn, f"SELECT ev.event_id,ev.event_name,ev.status,ev.country,ev.city,ev.start_date,ev.end_date,COALESCE(ev.stages_count,COUNT(DISTINCT stg.stage_id),0) stages_count {base} GROUP BY ev.event_id,ev.event_name,ev.status,ev.country,ev.city,ev.start_date,ev.end_date,ev.stages_count ORDER BY ev.start_date DESC LIMIT :limit OFFSET :offset", f.params|{"limit":q.limit,"offset":q.offset})
        total=await count(self.conn,"SELECT COUNT(DISTINCT ev.event_id) FROM rally_events ev "+f.where,f.params)
        return [RallyResultItem(**r) for r in data],total

    async def participations(self,q):
        f=Filters().common(q); p=f.people(q)
        if p:f.dimension(p)
        base="FROM rally_entry_list el JOIN rally_sub_events se ON el.sub_event_id=se.sub_event_id JOIN rally_events ev ON se.event_id=ev.event_id LEFT JOIN user_driver_profile dp ON el.user_driver_id=dp.driver_id LEFT JOIN user_codriver_profile cdp ON el.user_co_driver_id=cdp.codriver_id "+f.where
        data=await rows(self.conn,"SELECT ev.event_id rally_id,ev.event_name,COALESCE(dp.driver_id,cdp.codriver_id) person_id,COALESCE(dp.full_name,cdp.full_name,'Competitor') driver_name,CASE WHEN dp.driver_id IS NOT NULL AND cdp.codriver_id IS NOT NULL THEN 'Driver / Co-Driver' WHEN cdp.codriver_id IS NOT NULL THEN 'Co-Driver' ELSE 'Driver' END role,NULL pos_overall "+base+" GROUP BY ev.event_id,ev.event_name,person_id,driver_name,role ORDER BY ev.start_date DESC LIMIT :limit OFFSET :offset",f.params|{"limit":q.limit,"offset":q.offset})
        total=await count(self.conn,"SELECT COUNT(DISTINCT ev.event_id) "+base,f.params)
        return [ParticipationItem(**r) for r in data],total

    def classification_filters(self,q,winner=False):
        f=Filters().common(q); f.clauses[:0]=[FINAL_STAGE]+(["rr.pos_overall=1"] if winner else ["rr.pos_overall IS NOT NULL"])
        # Dart classification intents are driver-only.
        person=[]
        for x in q.driver_ids:
            b=f.bind(x,"driver_id"); person.append(f"(dp.driver_id={b} OR el.user_driver_id={b})")
        for x in q.driver_names:
            b=f.bind('%'+x.lower()+'%',"driver_name"); person.append(f"(LOWER(dp.full_name) LIKE {b} OR LOWER(dp.nick_name) LIKE {b} OR LOWER(rr.crew) LIKE {b})")
        f.dimension(person); return f

    async def classifications(self,q,winner=False,single=False):
        f=self.classification_filters(q,winner)
        base="FROM rally_results rr JOIN rally_events ev ON rr.rally_id=ev.event_id JOIN rally_stages stg ON rr.stage_id=stg.stage_id LEFT JOIN rally_entry_list el ON rr.entry_list_id=el.id LEFT JOIN user_driver_profile dp ON el.user_driver_id=dp.driver_id "+f.where
        limit=1 if single else q.limit; offset=0 if single else q.offset
        data=await rows(self.conn,"SELECT rr.id,rr.rally_id,ev.event_name,dp.driver_id,COALESCE(dp.full_name,rr.crew) driver_name,rr.pos_overall "+base+" GROUP BY rr.id,rr.rally_id,ev.event_name,dp.driver_id,dp.full_name,rr.crew,rr.pos_overall ORDER BY rr.pos_overall ASC LIMIT :limit OFFSET :offset",f.params|{"limit":limit,"offset":offset})
        total=len(data) if single else await count(self.conn,"SELECT COUNT(DISTINCT rr.id) "+base,f.params)
        return [ClassificationItem(**r) for r in data],total
    async def driver_wins(self,q):
        items,total=await self.classifications(q,True)
        return [ParticipationItem(rally_id=x.rally_id,event_name=x.event_name,person_id=x.driver_id,driver_name=x.driver_name,pos_overall=x.pos_overall) for x in items],total
    async def rally_results(self,q): return await self.classifications(q,True,True)
    async def top_finishers(self,q): return await self.classifications(q)

    async def video_actions(self,q):
        f=Filters().common(q,stages=True); f.clauses[:0]=["rs.on_demand_url IS NOT NULL AND rs.on_demand_url!=''","(rs.video_type IS NULL OR rs.video_type!='instantReplay')"]
        actions=[]
        for a in q.action_types:
            clean=a.lower().removesuffix('_segments')
            actions.extend([f"va.action_name={f.bind(clean,'action')}",f"va.action_name={f.bind(clean+'_segments','action')}"])
        f.dimension(actions)
        p=f.people(q)
        if p:f.dimension(p)
        base="FROM rally_video_metadata vm JOIN rally_video_actions va ON vm.action_id=va.id JOIN rally_streams rs ON vm.video_id=rs.video_id LEFT JOIN rally_videos rv ON vm.video_id=rv.id LEFT JOIN rally_stages stg ON rv.stage_id=stg.stage_id LEFT JOIN rally_events ev ON stg.event_id=ev.event_id LEFT JOIN rally_entry_list el ON vm.entry_list_id=el.id LEFT JOIN user_driver_profile dp ON el.user_driver_id=dp.driver_id LEFT JOIN user_codriver_profile cdp ON el.user_co_driver_id=cdp.codriver_id "+f.where
        data=await rows(self.conn,"SELECT vm.id,vm.video_id,MIN(rs.id) stream_id,va.id action_type_id,va.action_name action_type "+base+" GROUP BY vm.id,vm.video_id,va.id,va.action_name ORDER BY vm.id DESC LIMIT :limit OFFSET :offset",f.params|{"limit":q.limit,"offset":q.offset})
        total=await count(self.conn,"SELECT COUNT(DISTINCT vm.id) "+base,f.params)
        return [VideoActionItem(**r) for r in data],total

    async def driver_videos(self,q):
        f=Filters().common(q,stages=True); f.clauses[:0]=["rs.on_demand_url IS NOT NULL AND rs.on_demand_url!=''","(rs.video_type IS NULL OR rs.video_type!='instantReplay')"]
        p=f.people(q)
        if p:f.dimension(p)
        base="FROM rally_videos rv JOIN rally_video_metadata vm ON rv.id=vm.video_id JOIN rally_entry_list el ON vm.entry_list_id=el.id LEFT JOIN user_driver_profile dp ON el.user_driver_id=dp.driver_id LEFT JOIN user_codriver_profile cdp ON el.user_co_driver_id=cdp.codriver_id LEFT JOIN rally_streams rs ON rv.id=rs.video_id LEFT JOIN rally_stages stg ON rv.stage_id=stg.stage_id LEFT JOIN rally_events ev ON stg.event_id=ev.event_id "+f.where
        data=await rows(self.conn,"SELECT rv.id video_id,MIN(rs.id) stream_id,COALESCE(dp.driver_id,cdp.codriver_id) driver_id,COALESCE(dp.full_name,cdp.full_name) driver_name "+base+" GROUP BY rv.id,dp.driver_id,cdp.codriver_id,dp.full_name,cdp.full_name ORDER BY rv.id DESC LIMIT :limit OFFSET :offset",f.params|{"limit":q.limit,"offset":q.offset})
        total=await count(self.conn,"SELECT COUNT(DISTINCT rv.id) "+base,f.params)
        return [VideoItem(**r) for r in data],total

    async def top_uploaders(self,q):
        f=Filters().common(q); f.clauses.insert(0,"rv.uploader_user_id IS NOT NULL")
        base="FROM rally_videos rv LEFT JOIN user_fan_profile fp ON rv.uploader_user_id=fp.fan_id LEFT JOIN user_account ua ON fp.account_id=ua.id LEFT JOIN rally_stages stg ON rv.stage_id=stg.stage_id LEFT JOIN rally_events ev ON stg.event_id=ev.event_id "+f.where
        data=await rows(self.conn,"SELECT CAST(rv.uploader_user_id AS CHAR) uploader_id,CAST(fp.account_id AS CHAR) account_id,COALESCE(NULLIF(TRIM(ua.user_name),''),NULLIF(TRIM(fp.full_name),''),NULLIF(TRIM(ua.email),''),'Rally Contributor') uploader_name,COUNT(rv.id) upload_count "+base+" GROUP BY rv.uploader_user_id,fp.account_id,ua.user_name,fp.full_name,ua.email ORDER BY upload_count DESC LIMIT :limit OFFSET :offset",f.params|{"limit":q.limit,"offset":q.offset})
        total=await count(self.conn,"SELECT COUNT(DISTINCT rv.uploader_user_id) "+base,f.params)
        return [UploaderItem(**r) for r in data],total

    async def top_drivers(self,q):
        f=Filters().common(q); f.clauses[:0]=["rr.pos_overall=1",FINAL_STAGE]
        base="FROM rally_results rr JOIN rally_events ev ON rr.rally_id=ev.event_id JOIN rally_stages stg ON rr.stage_id=stg.stage_id LEFT JOIN rally_entry_list el ON rr.entry_list_id=el.id LEFT JOIN user_driver_profile dp ON el.user_driver_id=dp.driver_id "+f.where
        data=await rows(self.conn,"SELECT dp.driver_id,COALESCE(dp.full_name,rr.crew) driver_name,COUNT(DISTINCT rr.rally_id) win_count "+base+" GROUP BY dp.driver_id,driver_name ORDER BY win_count DESC LIMIT :limit OFFSET :offset",f.params|{"limit":q.limit,"offset":q.offset})
        items=[]
        for r in data:
            r["person_id"]=str(r.get("driver_id") or r["driver_name"]); items.append(DriverWinsItem(**r))
        total=await count(self.conn,"SELECT COUNT(DISTINCT COALESCE(dp.driver_id,rr.crew)) "+base,f.params)
        return items,total
