import argparse
import asyncio
import json
import time
from pathlib import Path

from app.db.engine import get_engine
from app.domain.search_query import SearchQuery
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.repositories.search_repository import SearchRepository


def result_id(item: dict) -> str:
    for key in ("id", "event_id", "rally_id", "video_id", "uploader_id", "person_id", "driver_id", "stream_id"):
        if item.get(key) is not None:
            return str(item[key])
    return json.dumps(item, sort_keys=True, ensure_ascii=False)


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider-report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = json.loads(args.provider_report.read_text())
    engine = get_engine()
    started = time.perf_counter()
    search_service = InMemoryEntitySearchService(data_source=MySqlEntitySearchDataSource(engine=engine))
    stats = await search_service.rebuild()
    resolver = DatabaseEntityResolver(repository=EntitySearchLookupAdapter(search_service=search_service))
    records = []
    for source_record in source["records"]:
        parsed = source_record.get("parsedSearchQuery")
        if not parsed:
            records.append({"caseId": source_record["caseId"], "eligible": False, "reason": "no validated SearchQuery"})
            continue
        query = SearchQuery.model_validate(parsed)
        entity_started = time.perf_counter()
        resolved = await resolver.resolve(query)
        entity_ms = (time.perf_counter() - entity_started) * 1000
        resolution_data = {name: value.to_dict() for name, value in resolved.resolutions.items()}
        outcome = "correct_confident" if resolved.is_success else ("clarification" if resolved.requires_clarification else "no_match")
        record = {"caseId": source_record["caseId"], "eligible": True, "parsedSearchQuery": parsed, "canonicalOutcome": outcome, "canonicalResolutions": resolution_data, "entitySearchLatencyMs": entity_ms, "clarificationQuestion": resolved.clarification_question, "resolutionError": resolved.error, "databaseExecuted": False}
        if resolved.is_success:
            db_started = time.perf_counter()
            async with engine.connect() as connection:
                response = await SearchRepository(connection).search(resolved.resolved_query)
            db_ms = (time.perf_counter() - db_started) * 1000
            items = [item.model_dump(mode="json") for item in response.results]
            record.update({"resolvedSearchQuery": resolved.resolved_query.model_dump(by_alias=True, mode="json", exclude_none=True), "databaseExecuted": True, "databaseLatencyMs": db_ms, "resultIds": [result_id(item) for item in items], "totalCount": response.total_count, "returnedCount": len(items)})
        records.append(record)
    report = {"runVersion": "PY3_PROVIDER_VALIDATION_V1", "sourceProviderReport": str(args.provider_report), "provider": source["provider"], "model": source["model"], "entityIndex": {"entityCount": stats.entity_count, "buildTimeMs": stats.build_time.total_seconds() * 1000}, "summary": {"cases": len(records), "eligible": sum(r["eligible"] for r in records), "canonicalSuccess": sum(r.get("canonicalOutcome") == "correct_confident" for r in records), "clarifications": sum(r.get("canonicalOutcome") == "clarification" for r in records), "noMatch": sum(r.get("canonicalOutcome") == "no_match" for r in records), "databaseExecutions": sum(r.get("databaseExecuted", False) for r in records)}, "totalLatencyMs": (time.perf_counter() - started) * 1000, "records": records}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(report["summary"], indent=2))
    await engine.dispose()


if __name__ == "__main__": asyncio.run(main())
