"""STT-2: bounded database-derived context experiment for gpt-transcribe.

This is an evaluation-only two-pass runner. It does not change the production
speech provider or any PY-1/PY-2/PY-3/PY-4/Flutter behavior.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean
from typing import Any

import httpx

BACKEND_ROOT = Path(__file__).parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import get_settings
from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.models import CanonicalSearchEntity, EntitySearchRequest, SearchEntityType
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.openai_provider import OpenAIProvider
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService
from scripts.run_stt_quality_bakeoff import (
    MANIFEST,
    PY3_MODEL,
    ROOT,
    edit_distance,
    nearest_rank_p95,
    phrase_diagnostic,
    score_pipeline,
    tokens,
    wav_duration_ms,
)


MODEL = "gpt-transcribe"
DYNAMIC_PER_TYPE = 3
GLOBAL_RALLY_LIMIT = 8
GLOBAL_LOCATION_LIMIT = 4
MAX_KEYWORDS = 24
DEFAULT_REPORT = ROOT / "backend/tests/integration/stt2_database_context_report.json"
ENTITY_TYPES = (
    SearchEntityType.RALLY,
    SearchEntityType.PERSON,
    SearchEntityType.STAGE,
    SearchEntityType.UPLOADER,
)


async def transcribe(
    *,
    settings: Any,
    path: Path,
    language: str,
    keywords: list[str],
) -> tuple[str, float]:
    data: dict[str, str] = {
        "model": MODEL,
        "response_format": "json",
        "languages[0]": language,
    }
    data.update({f"keywords[{index}]": keyword for index, keyword in enumerate(keywords)})
    started = time.perf_counter()

    def send() -> httpx.Response:
        with httpx.Client(timeout=60.0) as client:
            return client.post(
                f"{settings.openai_base_url.rstrip('/')}/audio/transcriptions",
                headers={
                    "Authorization": (
                        f"Bearer {settings.openai_api_key.get_secret_value()}"
                    )
                },
                data=data,
                files={"file": (path.name, path.read_bytes(), "audio/wav")},
            )

    response = await asyncio.wait_for(asyncio.to_thread(send), timeout=61.0)
    if not response.is_success:
        raise RuntimeError(f"speech provider HTTP {response.status_code}")
    try:
        payload = response.json()
    except ValueError as exc:
        raise RuntimeError("speech provider returned invalid JSON") from exc
    transcript = str(payload.get("text") or "").strip()
    if not transcript:
        raise RuntimeError("speech provider returned an empty transcript")
    return transcript, (time.perf_counter() - started) * 1000


def retrieval_spans(transcript: str) -> list[str]:
    words = tokens(transcript, fold_accents=True)
    spans: list[str] = []
    for width in range(min(4, len(words)), 0, -1):
        for index in range(len(words) - width + 1):
            value = " ".join(words[index:index + width])
            if value not in spans:
                spans.append(value)
    if transcript.strip() and transcript.strip() not in spans:
        spans.insert(0, transcript.strip())
    return spans


async def retrieve_candidates(
    entity_search: InMemoryEntitySearchService,
    transcript: str,
) -> list[dict[str, Any]]:
    best: dict[tuple[str, str], dict[str, Any]] = {}
    for entity_type in ENTITY_TYPES:
        for span in retrieval_spans(transcript):
            candidates = await entity_search.search(EntitySearchRequest(
                raw_mention=span,
                entity_type=entity_type,
                limit=DYNAMIC_PER_TYPE,
            ))
            for candidate in candidates:
                key = (entity_type.value, candidate.canonical_id)
                previous = best.get(key)
                if previous is None or candidate.score > previous["score"]:
                    best[key] = {
                        "type": entity_type.value,
                        "canonicalId": candidate.canonical_id,
                        "canonicalName": candidate.canonical_name,
                        "score": candidate.score,
                        "matchedBy": sorted(candidate.matched_by),
                        "retrievalSpan": span,
                    }
    selected: list[dict[str, Any]] = []
    for entity_type in ENTITY_TYPES:
        typed = [value for value in best.values() if value["type"] == entity_type.value]
        typed.sort(key=lambda value: (-value["score"], value["canonicalName"]))
        selected.extend(typed[:DYNAMIC_PER_TYPE])
    return selected


def global_vocabulary(entities: list[CanonicalSearchEntity]) -> list[dict[str, str]]:
    rallies = [entity for entity in entities if entity.entity_type == SearchEntityType.RALLY]
    available_years = [
        int(entity.metadata["year"])
        for entity in rallies
        if isinstance(entity.metadata.get("year"), int)
    ]
    latest_year = max(available_years) if available_years else None
    latest = [
        entity for entity in rallies
        if latest_year is None or entity.metadata.get("year") == latest_year
    ]
    latest.sort(key=lambda entity: entity.canonical_name.casefold())
    selected = latest[:GLOBAL_RALLY_LIMIT]
    values: list[dict[str, str]] = []
    for entity in selected:
        values.append({
            "source": "latest_year_rally",
            "canonicalId": entity.canonical_id,
            "value": entity.canonical_name,
        })
    for field in ("city", "country"):
        unique = sorted({
            str(entity.metadata[field]).strip()
            for entity in selected
            if str(entity.metadata.get(field) or "").strip()
        }, key=str.casefold)
        for value in unique[:GLOBAL_LOCATION_LIMIT]:
            values.append({
                "source": f"latest_year_rally_{field}",
                "canonicalId": "",
                "value": value,
            })
    return values


def build_keywords(
    candidates: list[dict[str, Any]],
    global_terms: list[dict[str, str]],
) -> list[str]:
    values: list[str] = []
    for value in [
        *(candidate["canonicalName"] for candidate in candidates),
        *(term["value"] for term in global_terms),
    ]:
        clean = str(value).strip()
        if (
            clean
            and clean not in values
            and not re.search(r"[<>\r\n]", clean)
        ):
            values.append(clean)
        if len(values) == MAX_KEYWORDS:
            break
    return values


def contains_name(text: str, name: str) -> bool:
    text_tokens = tokens(text, fold_accents=True)
    name_tokens = [
        token for token in tokens(name, fold_accents=True)
        if not re.fullmatch(r"(?:19|20)\d{2}", token)
    ]
    return bool(name_tokens) and any(
        text_tokens[index:index + len(name_tokens)] == name_tokens
        for index in range(max(0, len(text_tokens) - len(name_tokens) + 1))
    )


def apply_circular_evidence_guard(
    *,
    raw_transcript: str,
    contextual_transcript: str,
    keywords: list[str],
    pipeline: dict[str, Any],
) -> dict[str, Any]:
    result = dict(pipeline)
    resolved_names = pipeline.get("observedCanonicalNames") or []
    newly_hinted = [
        name for name in resolved_names
        if any(contains_name(keyword, name) or contains_name(name, keyword) for keyword in keywords)
        and contains_name(contextual_transcript, name)
        and not contains_name(raw_transcript, name)
    ]
    guarded = bool(
        newly_hinted
        and pipeline["outcome"] in {"CORRECT_CONFIDENT", "WRONG_CONFIDENT"}
    )
    result["unguardedOutcome"] = pipeline["outcome"]
    result["circularEvidenceDetected"] = bool(newly_hinted)
    result["circularEvidenceNames"] = newly_hinted
    result["circularEvidenceGuardApplied"] = guarded
    if guarded:
        result["outcome"] = "CLARIFICATION"
        result["clarificationQuestion"] = (
            f'Did you mean "{newly_hinted[0]}"?'
        )
    return result


def transcript_metrics(reference: str, transcript: str, expected_entity: str) -> dict[str, Any]:
    reference_tokens = tokens(reference, fold_accents=True)
    transcript_tokens = tokens(transcript, fold_accents=True)
    errors = edit_distance(reference_tokens, transcript_tokens)
    return {
        "wordErrors": errors,
        "referenceWords": len(reference_tokens),
        "normalizedWer": errors / len(reference_tokens),
        "entity": phrase_diagnostic(expected_entity, transcript),
    }


def aggregate(rows: list[dict[str, Any]], pass_name: str) -> dict[str, Any]:
    metrics = [row[pass_name]["metrics"] for row in rows]
    pipelines = [row[pass_name]["pipeline"] for row in rows]
    outcomes = Counter(pipeline["outcome"] for pipeline in pipelines)
    errors = sum(metric["wordErrors"] for metric in metrics)
    reference_words = sum(metric["referenceWords"] for metric in metrics)
    correct_entity_tokens = sum(metric["entity"]["correctTokens"] for metric in metrics)
    entity_tokens = sum(metric["entity"]["totalTokens"] for metric in metrics)
    latencies = [row[pass_name]["sttLatencyMs"] for row in rows]
    scorable = [pipeline for pipeline in pipelines if pipeline["canonicalScorable"]]
    return {
        "normalizedWer": errors / reference_words,
        "entityTokenAccuracy": correct_entity_tokens / entity_tokens,
        "canonicalAccuracy": (
            sum(bool(pipeline["canonicalCorrect"]) for pipeline in scorable) / len(scorable)
        ),
        "outcomes": {
            "CORRECT_CONFIDENT": outcomes["CORRECT_CONFIDENT"],
            "CLARIFICATION": outcomes["CLARIFICATION"],
            "NO_MATCH": outcomes["NO_MATCH"],
            "WRONG_CONFIDENT": outcomes["WRONG_CONFIDENT"],
        },
        "averageSttLatencyMs": mean(latencies),
        "p95SttLatencyMs": nearest_rank_p95(latencies),
    }


def decision(raw: dict[str, Any], contextual: dict[str, Any]) -> str:
    raw_outcomes = raw["outcomes"]
    contextual_outcomes = contextual["outcomes"]
    unsafe = contextual_outcomes["WRONG_CONFIDENT"] > raw_outcomes["WRONG_CONFIDENT"]
    if unsafe:
        return "DOMAIN_CONTEXT_UNSAFE"
    entity_gain = contextual["entityTokenAccuracy"] - raw["entityTokenAccuracy"]
    canonical_gain = contextual["canonicalAccuracy"] - raw["canonicalAccuracy"]
    correct_gain = (
        contextual_outcomes["CORRECT_CONFIDENT"]
        - raw_outcomes["CORRECT_CONFIDENT"]
    )
    safe_target = contextual_outcomes["WRONG_CONFIDENT"] == 0
    if safe_target and entity_gain > 0 and canonical_gain > 0 and correct_gain > 0:
        return "DOMAIN_CONTEXT_WORKS"
    return "DOMAIN_CONTEXT_NO_MEANINGFUL_GAIN"


async def run(report_path: Path) -> dict[str, Any]:
    settings = get_settings()
    if not settings.openai_api_key.get_secret_value():
        raise RuntimeError("OPENAI_API_KEY is not configured")
    fixtures = json.loads(MANIFEST.read_text())["fixtures"]
    query_parser = QueryUnderstandingService(OpenAIProvider(ProviderConfig(
        provider="openai",
        model=PY3_MODEL,
        api_key=settings.openai_api_key.get_secret_value(),
        base_url=settings.openai_base_url,
        temperature=0.0,
        max_tokens=1024,
        timeout_seconds=30.0,
        max_retries=2,
    )))

    rows: list[dict[str, Any]] = []
    engine = get_engine()
    async with engine.connect() as connection:
        entities = await MySqlEntitySearchDataSource(connection=connection).load_entities()
        entity_search = InMemoryEntitySearchService.from_entities(entities)
        global_terms = global_vocabulary(entities)
        conversation = ConversationalSearchService(
            query_parser=query_parser,
            entity_resolver=DatabaseEntityResolver(
                repository=EntitySearchLookupAdapter(search_service=entity_search)
            ),
            repository=SearchRepository(connection),
        )
        for fixture in fixtures:
            path = ROOT / fixture["audioFile"]
            raw_transcript, raw_latency = await transcribe(
                settings=settings,
                path=path,
                language=fixture["language"],
                keywords=[],
            )
            retrieval_started = time.perf_counter()
            candidates = await retrieve_candidates(entity_search, raw_transcript)
            keywords = build_keywords(candidates, global_terms)
            retrieval_latency = (time.perf_counter() - retrieval_started) * 1000
            contextual_transcript, contextual_latency = await transcribe(
                settings=settings,
                path=path,
                language=fixture["language"],
                keywords=keywords,
            )
            raw_metrics = transcript_metrics(
                fixture["referenceTranscriptNormalized"],
                raw_transcript,
                fixture["expectedEntityMention"],
            )
            contextual_metrics = transcript_metrics(
                fixture["referenceTranscriptNormalized"],
                contextual_transcript,
                fixture["expectedEntityMention"],
            )
            _, raw_result = await conversation.search(
                raw_transcript,
                session=SearchConversationSession(),
                language=fixture["language"],
            )
            _, contextual_result = await conversation.search(
                contextual_transcript,
                session=SearchConversationSession(),
                language=fixture["language"],
            )
            raw_pipeline = score_pipeline(
                fixture,
                raw_result,
                entity_mention_correct=raw_metrics["entity"]["correct"],
            )
            contextual_pipeline = score_pipeline(
                fixture,
                contextual_result,
                entity_mention_correct=contextual_metrics["entity"]["correct"],
            )
            contextual_pipeline = apply_circular_evidence_guard(
                raw_transcript=raw_transcript,
                contextual_transcript=contextual_transcript,
                keywords=keywords,
                pipeline=contextual_pipeline,
            )
            row = {
                "fixtureId": fixture["fixtureId"],
                "audioFile": fixture["audioFile"],
                "reference": fixture["referenceTranscriptNormalized"],
                "expectedEntityMention": fixture["expectedEntityMention"],
                "language": fixture["language"],
                "audioDurationMs": wav_duration_ms(path),
                "retrieval": {
                    "candidates": candidates,
                    "globalTerms": global_terms,
                    "keywords": keywords,
                    "keywordCount": len(keywords),
                    "latencyMs": retrieval_latency,
                },
                "raw": {
                    "transcript": raw_transcript,
                    "metrics": raw_metrics,
                    "pipeline": raw_pipeline,
                    "sttLatencyMs": raw_latency,
                },
                "contextual": {
                    "transcript": contextual_transcript,
                    "metrics": contextual_metrics,
                    "pipeline": contextual_pipeline,
                    "sttLatencyMs": contextual_latency,
                    "incrementalLatencyMs": retrieval_latency + contextual_latency,
                },
            }
            rows.append(row)
            print(
                f"{fixture['fixtureId']}: {raw_transcript} -> {contextual_transcript}",
                flush=True,
            )

    raw_aggregate = aggregate(rows, "raw")
    contextual_aggregate = aggregate(rows, "contextual")
    incremental = [row["contextual"]["incrementalLatencyMs"] for row in rows]
    result = {
        "runVersion": "STT2_DATABASE_CONTEXT_V1",
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "status": decision(raw_aggregate, contextual_aggregate),
        "productionEnabled": False,
        "model": MODEL,
        "configuration": {
            "rawAndContextualStoredSeparately": True,
            "confidenceCombined": False,
            "audioPreprocessing": "RAW_NO_OP",
            "prompt": None,
            "languageField": "languages[]",
            "dynamicCandidatesPerEntityType": DYNAMIC_PER_TYPE,
            "globalLatestYearRallyLimit": GLOBAL_RALLY_LIMIT,
            "globalLocationLimitPerField": GLOBAL_LOCATION_LIMIT,
            "maximumKeywords": MAX_KEYWORDS,
            "personDatabaseGloballyLoadedIntoRequest": False,
            "sessionContextAvailableInCorpus": False,
            "circularEvidenceGuard": "newly hinted exact resolutions downgrade to clarification",
        },
        "databaseInventory": {
            "indexedEntities": len(entities),
            "globalVocabulary": global_terms,
        },
        "rawAggregate": raw_aggregate,
        "contextualAggregate": contextual_aggregate,
        "incrementalSecondPassLatencyMs": {
            "average": mean(incremental),
            "p95": nearest_rank_p95(incremental),
        },
        "rows": rows,
        "finalModelBenchmark": "NOT_RUN",
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    report = asyncio.run(run(args.report.resolve()))
    print(json.dumps({
        "report": str(args.report.resolve()),
        "status": report["status"],
        "rawAggregate": report["rawAggregate"],
        "contextualAggregate": report["contextualAggregate"],
        "incrementalSecondPassLatencyMs": report["incrementalSecondPassLatencyMs"],
    }, indent=2))


if __name__ == "__main__":
    main()
