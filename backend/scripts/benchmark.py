import asyncio, json, statistics, time
from app.db.engine import get_engine
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.repositories.search_repository import SearchRepository

INTENTS=[SearchIntent.SEARCH_RALLIES,SearchIntent.SEARCH_VIDEO_ACTIONS,SearchIntent.GET_RALLY_TOP_FINISHERS]

def percentile(values, fraction):
    ordered=sorted(values); return ordered[min(len(ordered)-1,int((len(ordered)-1)*fraction))]

async def main():
    report={}
    async with get_engine().connect() as conn:
        repo=SearchRepository(conn)
        for intent in INTENTS:
            samples=[]
            for _ in range(10):
                start=time.perf_counter(); await repo.search(SearchQuery(intent=intent,limit=20)); samples.append((time.perf_counter()-start)*1000)
            report[intent.value]={"average_ms":round(statistics.mean(samples),2),"p50_ms":round(statistics.median(samples),2),"p95_ms":round(percentile(samples,.95),2)}
    print(json.dumps(report,indent=2))

if __name__ == "__main__": asyncio.run(main())
