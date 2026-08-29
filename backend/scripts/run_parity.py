import argparse, asyncio, json
from pathlib import Path
from app.db.engine import get_engine
from app.domain.search_query import SearchQuery
from app.repositories.search_repository import SearchRepository
from tests.parity.canonical import canonical_ids

async def run(fixtures: Path, output: Path):
    document=json.loads(fixtures.read_text())
    if document["schemaVersion"]!="1.0": raise ValueError("Unsupported fixture schema")
    with output.open("w") as sink:
        async with get_engine().connect() as connection:
            repository=SearchRepository(connection)
            for fixture in document["cases"]:
                query=SearchQuery.model_validate(fixture["searchQuery"])
                response=await repository.search(query)
                sink.write(json.dumps({"schemaVersion":"1.0","runtime":"python","caseId":fixture["caseId"],"searchQuery":fixture["searchQuery"],"intent":response.intent.value,"orderedCanonicalIds":canonical_ids(response),"total":response.total_count,"limit":response.limit,"offset":response.offset,"hasMore":response.has_more,"currentPage":response.offset//response.limit+1})+"\n")

if __name__=="__main__":
    parser=argparse.ArgumentParser(); parser.add_argument("fixtures",type=Path); parser.add_argument("output",type=Path); args=parser.parse_args()
    asyncio.run(run(args.fixtures,args.output))
