"""STT-3 audio-grounded domain interpretation experiment.

Exactly one gpt-audio call is made per existing labeled recording. The raw
gpt-transcribe evidence is reused from STT-2, so this runner makes no additional
transcription calls and changes no production behavior.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import json
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean
from typing import Any

import httpx
from pydantic import BaseModel, ConfigDict, Field, ValidationError

BACKEND_ROOT = Path(__file__).parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import get_settings
from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.models import CanonicalSearchEntity, SearchEntityType
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.openai_provider import OpenAIProvider
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService
from scripts.run_stt2_database_context_experiment import retrieve_candidates
from scripts.run_stt_quality_bakeoff import (
    MANIFEST,
    PY3_MODEL,
    ROOT,
    edit_distance,
    nearest_rank_p95,
    phrase_diagnostic,
    score_pipeline,
    tokens,
)


MODEL = "gpt-audio"
RAW_REPORT = ROOT / "backend/tests/integration/stt2_database_context_report.json"
DEFAULT_REPORT = ROOT / "backend/tests/integration/stt3_audio_grounding_report.json"
MAX_PER_GROUP = 3
MAX_LOCATIONS = 4


class AudioInterpretation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    heard_text: str = Field(min_length=1)
    normalized_transcript: str = Field(min_length=1)
    rally_names: list[str] = Field(default_factory=list)
    driver_names: list[str] = Field(default_factory=list)
    stage_names: list[str] = Field(default_factory=list)
    location_names: list[str] = Field(default_factory=list)
    uncertain_terms: list[str] = Field(default_factory=list)


INSTRUCTION = """Interpret the supplied original audio as grounded spoken text.
Candidate names are possibilities, not facts. Select a candidate only when it is
acoustically supported by the audio. Do not insert an entity merely because it
appears in a candidate list. Preserve ordinary words faithfully. Put uncertain
domain words in uncertain_terms. Output no IDs. Invent no filters or missing
details. normalized_transcript must represent what was actually spoken. The raw
transcript and candidate list are supporting context, not independent evidence.
Call interpret_spoken_search exactly once."""


def tool_definition() -> dict[str, Any]:
    schema = AudioInterpretation.model_json_schema()
    schema["additionalProperties"] = False
    return {
        "type": "function",
        "function": {
            "name": "interpret_spoken_search",
            "description": "Return an audio-grounded textual interpretation without IDs.",
            "parameters": schema,
        },
    }


def candidate_groups(
    candidates: list[dict[str, Any]],
    entities_by_id: dict[str, CanonicalSearchEntity],
) -> dict[str, list[str]]:
    groups = {
        "rally_names": [],
        "driver_names": [],
        "stage_names": [],
        "location_names": [],
    }
    mapping = {
        SearchEntityType.RALLY.value: "rally_names",
        SearchEntityType.PERSON.value: "driver_names",
        SearchEntityType.STAGE.value: "stage_names",
    }
    for candidate in candidates:
        group = mapping.get(candidate["type"])
        name = str(candidate["canonicalName"]).strip()
        if group and name and name not in groups[group] and len(groups[group]) < MAX_PER_GROUP:
            groups[group].append(name)
        if candidate["type"] == SearchEntityType.RALLY.value:
            entity = entities_by_id.get(candidate["canonicalId"])
            if entity is not None:
                for key in ("city", "country"):
                    value = str(entity.metadata.get(key) or "").strip()
                    if value and value not in groups["location_names"]:
                        groups["location_names"].append(value)
    groups["location_names"] = groups["location_names"][:MAX_LOCATIONS]
    return groups


async def interpret_audio(
    *,
    settings: Any,
    path: Path,
    language: str,
    raw_transcript: str,
    candidates: dict[str, list[str]],
) -> tuple[AudioInterpretation, float, dict[str, Any]]:
    supporting_text = json.dumps({
        "language": language,
        "raw_transcript": raw_transcript,
        "candidate_display_names": candidates,
    }, ensure_ascii=False)
    body = {
        "model": MODEL,
        "messages": [
            {"role": "developer", "content": INSTRUCTION},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": supporting_text},
                    {
                        "type": "input_audio",
                        "input_audio": {
                            "data": base64.b64encode(path.read_bytes()).decode("ascii"),
                            "format": "wav",
                        },
                    },
                ],
            },
        ],
        "tools": [tool_definition()],
        "tool_choice": {
            "type": "function",
            "function": {"name": "interpret_spoken_search"},
        },
        "temperature": 0,
    }
    started = time.perf_counter()

    def send() -> httpx.Response:
        with httpx.Client(timeout=90.0) as client:
            return client.post(
                f"{settings.openai_base_url.rstrip('/')}/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.openai_api_key.get_secret_value()}",
                    "Content-Type": "application/json",
                },
                json=body,
            )

    response = await asyncio.wait_for(asyncio.to_thread(send), timeout=91.0)
    latency_ms = (time.perf_counter() - started) * 1000
    if not response.is_success:
        raise RuntimeError(f"gpt-audio HTTP {response.status_code}")
    try:
        payload = response.json()
        message = payload["choices"][0]["message"]
        calls = message.get("tool_calls") or []
        call = next(
            value for value in calls
            if value.get("type") == "function"
            and value.get("function", {}).get("name") == "interpret_spoken_search"
        )
        arguments = json.loads(call["function"]["arguments"])
        interpretation = AudioInterpretation.model_validate(arguments)
    except (KeyError, IndexError, StopIteration, TypeError, ValueError, ValidationError) as exc:
        raise RuntimeError(f"invalid forced function response: {type(exc).__name__}") from exc
    usage = payload.get("usage") or {}
    return interpretation, latency_ms, {
        "promptTokens": usage.get("prompt_tokens"),
        "completionTokens": usage.get("completion_tokens"),
        "totalTokens": usage.get("total_tokens"),
    }


def canonicalize_returned_names(
    interpretation: AudioInterpretation,
    supplied: dict[str, list[str]],
) -> tuple[AudioInterpretation, list[dict[str, str]]]:
    updates: dict[str, list[str]] = {}
    violations: list[dict[str, str]] = []
    for field in ("rally_names", "driver_names", "stage_names", "location_names"):
        allowed = {value.casefold(): value for value in supplied[field]}
        values: list[str] = []
        for returned in getattr(interpretation, field):
            match = allowed.get(returned.strip().casefold())
            if match is None:
                violations.append({"field": field, "value": returned})
            elif match not in values:
                values.append(match)
        updates[field] = values
    return interpretation.model_copy(update=updates), violations


def transcript_metrics(reference: str, transcript: str, entity: str) -> dict[str, Any]:
    reference_tokens = tokens(reference, fold_accents=True)
    transcript_tokens = tokens(transcript, fold_accents=True)
    diagnostic = phrase_diagnostic(entity, transcript)
    diagnostic["allEntityTokensPresent"] = (
        diagnostic["correctTokens"] == diagnostic["totalTokens"]
    )
    errors = edit_distance(reference_tokens, transcript_tokens)
    return {
        "wordErrors": errors,
        "referenceWords": len(reference_tokens),
        "normalizedWer": errors / len(reference_tokens),
        "entity": diagnostic,
    }


def apply_safety_gate(
    *,
    raw_pipeline: dict[str, Any],
    grounded_pipeline: dict[str, Any],
    interpretation: AudioInterpretation,
    violations: list[dict[str, str]],
) -> tuple[dict[str, Any], dict[str, Any]]:
    selected = [
        *interpretation.rally_names,
        *interpretation.driver_names,
        *interpretation.stage_names,
        *interpretation.location_names,
    ]
    resolver_accepted = grounded_pipeline["outcome"] in {
        "CORRECT_CONFIDENT", "WRONG_CONFIDENT"
    }
    candidate_gate = not violations
    correction_trusted = candidate_gate and (not selected or resolver_accepted)
    final = dict(grounded_pipeline)
    fallback = None
    if violations:
        fallback = "RAW_PATH_OR_CLARIFICATION_UNLISTED_ENTITY"
        if raw_pipeline["outcome"] == "CORRECT_CONFIDENT":
            final = dict(raw_pipeline)
        else:
            final["outcome"] = "CLARIFICATION"
            final["clarificationQuestion"] = "Please clarify the spoken entity."
    elif selected and not resolver_accepted:
        fallback = "NORMAL_PY2_CLARIFICATION_OR_NO_MATCH"
    return final, {
        "candidateMembershipPassed": candidate_gate,
        "resolverAcceptedTextualEntity": resolver_accepted,
        "correctionTrusted": correction_trusted,
        "violations": violations,
        "fallback": fallback,
    }


def aggregate(rows: list[dict[str, Any]], key: str) -> dict[str, Any]:
    metrics = [row[key]["metrics"] for row in rows]
    pipelines = [row[key]["pipeline"] for row in rows]
    outcomes = Counter(value["outcome"] for value in pipelines)
    scorable = [value for value in pipelines if value["canonicalScorable"]]
    errors = sum(value["wordErrors"] for value in metrics)
    reference_words = sum(value["referenceWords"] for value in metrics)
    entity_correct = sum(value["entity"]["correctTokens"] for value in metrics)
    entity_total = sum(value["entity"]["totalTokens"] for value in metrics)
    return {
        "normalizedWer": errors / reference_words,
        "entityTokenAccuracy": entity_correct / entity_total,
        "entityCorrect": sum(value["entity"]["allEntityTokensPresent"] for value in metrics),
        "intentAccuracy": sum(value["intentCorrect"] for value in pipelines) / len(pipelines),
        "canonicalAccuracy": sum(bool(value["canonicalCorrect"]) for value in scorable) / len(scorable),
        "outcomes": {
            "CORRECT_CONFIDENT": outcomes["CORRECT_CONFIDENT"],
            "CLARIFICATION": outcomes["CLARIFICATION"],
            "NO_MATCH": outcomes["NO_MATCH"],
            "WRONG_CONFIDENT": outcomes["WRONG_CONFIDENT"],
        },
    }


def decision(rows: list[dict[str, Any]], raw: dict[str, Any], final: dict[str, Any]) -> str:
    aluksne = [row for row in rows if row["fixtureId"] in {
        "human-smoke-001", "human-smoke-002", "human-smoke-003", "human-smoke-005"
    }]
    fixed = sum(row["final"]["metrics"]["entity"]["allEntityTokensPresent"] for row in aluksne)
    unique_fixed = sum(
        row["final"]["metrics"]["entity"]["allEntityTokensPresent"]
        for row in aluksne if row["fixtureId"] != "human-smoke-003"
    )
    safe = final["outcomes"]["WRONG_CONFIDENT"] == 0
    improved = (
        final["canonicalAccuracy"] > raw["canonicalAccuracy"]
        and final["outcomes"]["CORRECT_CONFIDENT"] > raw["outcomes"]["CORRECT_CONFIDENT"]
    )
    return (
        "AUDIO_GROUNDING_WORKS"
        if safe and improved and fixed >= 3 and unique_fixed >= 2
        else "AUDIO_GROUNDING_INSUFFICIENT"
    )


async def run(report_path: Path) -> dict[str, Any]:
    settings = get_settings()
    fixtures = json.loads(MANIFEST.read_text())["fixtures"]
    raw_report = json.loads(RAW_REPORT.read_text())
    raw_by_fixture = {row["fixtureId"]: row for row in raw_report["rows"]}
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
    model_accessible = False
    engine = get_engine()
    async with engine.connect() as connection:
        entities = await MySqlEntitySearchDataSource(connection=connection).load_entities()
        entities_by_id = {entity.canonical_id: entity for entity in entities}
        entity_search = InMemoryEntitySearchService.from_entities(entities)
        conversation = ConversationalSearchService(
            query_parser=query_parser,
            entity_resolver=DatabaseEntityResolver(
                repository=EntitySearchLookupAdapter(search_service=entity_search)
            ),
            repository=SearchRepository(connection),
        )
        for fixture in fixtures:
            raw_evidence = raw_by_fixture[fixture["fixtureId"]]["raw"]
            raw_transcript = raw_evidence["transcript"]
            retrieval_started = time.perf_counter()
            candidates = await retrieve_candidates(entity_search, raw_transcript)
            supplied = candidate_groups(candidates, entities_by_id)
            retrieval_ms = (time.perf_counter() - retrieval_started) * 1000
            interpretation, audio_ms, usage = await interpret_audio(
                settings=settings,
                path=ROOT / fixture["audioFile"],
                language=fixture["language"],
                raw_transcript=raw_transcript,
                candidates=supplied,
            )
            model_accessible = True
            interpretation, violations = canonicalize_returned_names(interpretation, supplied)
            grounded_metrics = transcript_metrics(
                fixture["referenceTranscriptNormalized"],
                interpretation.normalized_transcript,
                fixture["expectedEntityMention"],
            )
            _, grounded_result = await conversation.search(
                interpretation.normalized_transcript,
                session=SearchConversationSession(),
                language=fixture["language"],
            )
            grounded_pipeline = score_pipeline(
                fixture,
                grounded_result,
                entity_mention_correct=grounded_metrics["entity"]["allEntityTokensPresent"],
            )
            raw_pipeline = raw_evidence["pipeline"]
            raw_metrics = transcript_metrics(
                fixture["referenceTranscriptNormalized"],
                raw_transcript,
                fixture["expectedEntityMention"],
            )
            final_pipeline, safety = apply_safety_gate(
                raw_pipeline=raw_pipeline,
                grounded_pipeline=grounded_pipeline,
                interpretation=interpretation,
                violations=violations,
            )
            final_metrics = grounded_metrics if safety["candidateMembershipPassed"] else raw_metrics
            total_ms = raw_evidence["sttLatencyMs"] + retrieval_ms + audio_ms + grounded_pipeline["pipelineLatencyMs"]
            rows.append({
                "fixtureId": fixture["fixtureId"],
                "audioFile": fixture["audioFile"],
                "reference": fixture["referenceTranscriptNormalized"],
                "candidateRetrieval": {
                    "latencyMs": retrieval_ms,
                    "candidatesWithLocalProvenance": candidates,
                    "displayTermsSent": supplied,
                    "idsSent": False,
                },
                "raw": {
                    "transcript": raw_transcript,
                    "metrics": raw_metrics,
                    "pipeline": raw_pipeline,
                    "sttLatencyMs": raw_evidence["sttLatencyMs"],
                },
                "audioGrounding": {
                    "heardText": interpretation.heard_text,
                    "normalizedTranscript": interpretation.normalized_transcript,
                    "rallyNames": interpretation.rally_names,
                    "driverNames": interpretation.driver_names,
                    "stageNames": interpretation.stage_names,
                    "locationNames": interpretation.location_names,
                    "uncertainTerms": interpretation.uncertain_terms,
                    "metrics": grounded_metrics,
                    "pipeline": grounded_pipeline,
                    "latencyMs": audio_ms,
                    "usage": usage,
                    "pydanticValidated": True,
                },
                "safetyGate": safety,
                "final": {
                    "transcript": (
                        interpretation.normalized_transcript
                        if safety["candidateMembershipPassed"] else raw_transcript
                    ),
                    "metrics": final_metrics,
                    "pipeline": final_pipeline,
                },
                "totalLatencyMs": total_ms,
            })
            print(
                f"{fixture['fixtureId']}: {raw_transcript} -> {interpretation.normalized_transcript}",
                flush=True,
            )
    raw_aggregate = aggregate(rows, "raw")
    grounded_aggregate = aggregate(rows, "audioGrounding")
    final_aggregate = aggregate(rows, "final")
    report = {
        "runVersion": "STT3_AUDIO_GROUNDING_V1",
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "status": decision(rows, raw_aggregate, final_aggregate),
        "model": MODEL,
        "modelAccessible": model_accessible,
        "audioCalls": len(rows),
        "productionEnabled": False,
        "configuration": {
            "rawEvidenceSource": str(RAW_REPORT.relative_to(ROOT)),
            "forcedFunction": "interpret_spoken_search",
            "pydanticValidation": True,
            "canonicalIdsSent": False,
            "maximumCandidatesPerEntityGroup": MAX_PER_GROUP,
            "maximumLocations": MAX_LOCATIONS,
            "fullPersonDatabaseSent": False,
            "aliasesOrTypoRules": False,
            "confidenceCombination": False,
        },
        "rawAggregate": raw_aggregate,
        "audioGroundingAggregateBeforeSafety": grounded_aggregate,
        "finalAggregateAfterSafety": final_aggregate,
        "latencyMs": {
            "averageRawStt": mean(row["raw"]["sttLatencyMs"] for row in rows),
            "averageCandidateRetrieval": mean(row["candidateRetrieval"]["latencyMs"] for row in rows),
            "averageGptAudio": mean(row["audioGrounding"]["latencyMs"] for row in rows),
            "p95GptAudio": nearest_rank_p95([row["audioGrounding"]["latencyMs"] for row in rows]),
            "averageTotal": mean(row["totalLatencyMs"] for row in rows),
            "p95Total": nearest_rank_p95([row["totalLatencyMs"] for row in rows]),
        },
        "rows": rows,
        "finalModelBenchmark": "NOT_RUN",
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    report = asyncio.run(run(args.report.resolve()))
    print(json.dumps({
        "report": str(args.report.resolve()),
        "status": report["status"],
        "modelAccessible": report["modelAccessible"],
        "audioCalls": report["audioCalls"],
        "rawAggregate": report["rawAggregate"],
        "finalAggregateAfterSafety": report["finalAggregateAfterSafety"],
        "latencyMs": report["latencyMs"],
    }, indent=2))


if __name__ == "__main__":
    main()
