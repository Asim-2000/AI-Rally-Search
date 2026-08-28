"""Run the bounded, raw-audio STT bake-off requested before PY-6 voice cutover.

This deliberately sends no prompt, vocabulary, aliases, or other recognition
context.  Every successful transcript is passed through the frozen PY-3.1
OpenAI query-understanding configuration and the existing PY-2/PY-1 live path.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import re
import sys
import unicodedata
import wave
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean
from typing import Any

BACKEND_ROOT = Path(__file__).parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import get_settings
from app.db.engine import get_engine
from app.domain.conversation_session import SearchConversationSession
from app.entity_search.adapter import EntitySearchLookupAdapter
from app.entity_search.data_source import MySqlEntitySearchDataSource
from app.entity_search.resolver import DatabaseEntityResolver
from app.entity_search.service import InMemoryEntitySearchService
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.openai_provider import OpenAIProvider
from app.query_understanding.service import QueryUnderstandingService
from app.repositories.search_repository import SearchRepository
from app.services.conversational_search_service import ConversationalSearchService
from app.voice.models import SpokenAudioContext
from app.voice.openai_provider import OpenAISpeechToTextProvider
from app.voice.provider import SpeechProviderConfig, SpeechProviderError, SpeechProviderTimeout


ROOT = Path(__file__).parents[2]
MANIFEST = ROOT / "test/eval/entity_search/human_voice_smoke_manifest.json"
DEFAULT_REPORT = ROOT / "backend/tests/integration/stt_quality_bakeoff_report.json"
MODELS = (
    "whisper-1",
    "gpt-4o-mini-transcribe",
    "gpt-4o-transcribe",
    "gpt-transcribe",
)
PY3_MODEL = "gpt-4.1-mini"
PRICE_PER_MINUTE_USD = {
    "whisper-1": 0.006,
    "gpt-4o-mini-transcribe": 0.003,
    "gpt-4o-transcribe": 0.006,
    "gpt-transcribe": 0.0045,
}


def tokens(text: str, *, fold_accents: bool = False) -> list[str]:
    value = unicodedata.normalize("NFKD", text.casefold())
    if fold_accents:
        value = "".join(char for char in value if not unicodedata.combining(char))
    else:
        value = unicodedata.normalize("NFC", value)
    return re.findall(r"[^\W_]+", value, flags=re.UNICODE)


def edit_distance(reference: list[str], hypothesis: list[str]) -> int:
    previous = list(range(len(hypothesis) + 1))
    for row, ref_token in enumerate(reference, start=1):
        current = [row]
        for column, hyp_token in enumerate(hypothesis, start=1):
            current.append(min(
                previous[column] + 1,
                current[column - 1] + 1,
                previous[column - 1] + (ref_token != hyp_token),
            ))
        previous = current
    return previous[-1]


def phrase_diagnostic(expected: str, transcript: str) -> dict[str, Any]:
    expected_tokens = tokens(expected, fold_accents=True)
    actual_tokens = tokens(transcript, fold_accents=True)
    expected_counts = Counter(expected_tokens)
    actual_counts = Counter(actual_tokens)
    correct = sum(min(count, actual_counts[token]) for token, count in expected_counts.items())
    contiguous = any(
        actual_tokens[index:index + len(expected_tokens)] == expected_tokens
        for index in range(max(0, len(actual_tokens) - len(expected_tokens) + 1))
    )
    missing = list((expected_counts - actual_counts).elements())
    return {
        "expectedPhrase": expected,
        "correct": contiguous,
        "correctTokens": correct,
        "totalTokens": len(expected_tokens),
        "missingTokens": missing,
        "observedTranscript": transcript,
    }


def wav_duration_ms(path: Path) -> int:
    with wave.open(str(path), "rb") as audio:
        return round(audio.getnframes() / audio.getframerate() * 1000)


def nearest_rank_p95(values: list[float]) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(0.95 * len(ordered)) - 1)]


def resolution_ids(result: Any) -> set[str]:
    ids: set[str] = set()
    for resolution in result.resolutions.values():
        if resolution.resolved_candidate is not None:
            ids.add(str(resolution.resolved_candidate.id))
    if result.resolved_query is not None:
        ids.update(str(value) for value in result.resolved_query.driver_ids)
    return ids


def score_pipeline(
    fixture: dict[str, Any],
    result: Any,
    *,
    entity_mention_correct: bool,
) -> dict[str, Any]:
    parsed = result.parsed_query
    resolved = result.resolved_query
    expected_intents = set(fixture.get("expectedIntents") or [fixture["expectedIntent"]])
    actual_intent = parsed.intent.value if parsed is not None else None
    intent_correct = actual_intent in expected_intents
    expected_ids = set(fixture.get("expectedCanonicalIds") or [])
    equivalent_ids = set(fixture.get("equivalentResolverEntityIds") or [])
    observed_ids = resolution_ids(result)
    expected_name = fixture.get("expectedCanonicalName")
    observed_names = {
        resolution.resolved_candidate.canonical_name
        for resolution in result.resolutions.values()
        if resolution.resolved_candidate is not None
    }
    canonical_scorable = bool(fixture.get("canonicalScorable"))
    canonical_correct: bool | None = None
    if canonical_scorable:
        canonical_correct = bool(
            observed_ids.intersection(expected_ids | equivalent_ids)
            or (expected_name and expected_name in observed_names)
        )

    if result.requires_clarification:
        outcome = "CLARIFICATION"
    elif not result.is_success:
        outcome = "NO_MATCH"
    elif (
        not intent_correct
        or (canonical_scorable and not canonical_correct)
        or (not canonical_scorable and not entity_mention_correct)
    ):
        outcome = "WRONG_CONFIDENT"
    else:
        outcome = "CORRECT_CONFIDENT"

    response = result.search_response
    return {
        "outcome": outcome,
        "intentExpected": sorted(expected_intents),
        "intentActual": actual_intent,
        "intentCorrect": intent_correct,
        "canonicalScorable": canonical_scorable,
        "canonicalCorrect": canonical_correct,
        "entityMentionCorrect": entity_mention_correct,
        "expectedCanonicalIds": sorted(expected_ids),
        "equivalentResolverEntityIds": sorted(equivalent_ids),
        "observedCanonicalIds": sorted(observed_ids),
        "expectedCanonicalName": expected_name,
        "observedCanonicalNames": sorted(observed_names),
        "resolvedQuery": resolved.model_dump(by_alias=True, mode="json") if resolved else None,
        "dbExecuted": response is not None,
        "dbResultCount": response.total_count if response is not None else None,
        "dbResultIntent": response.intent.value if response is not None else None,
        "pipelineLatencyMs": round(result.total_latency_ms, 3),
        "errorCode": result.error_code,
        "error": result.error,
        "clarificationQuestion": result.clarification_question,
    }


def aggregate(model: str, rows: list[dict[str, Any]], duration_minutes: float) -> dict[str, Any]:
    successful = [row for row in rows if row.get("transcript") is not None]
    raw_edits = sum(row["rawWordErrors"] for row in successful)
    raw_words = sum(row["rawReferenceWords"] for row in successful)
    normalized_edits = sum(row["normalizedWordErrors"] for row in successful)
    normalized_words = sum(row["normalizedReferenceWords"] for row in successful)
    entity_correct = sum(row["entity"]["correctTokens"] for row in successful)
    entity_total = sum(row["entity"]["totalTokens"] for row in successful)
    pipeline_rows = [row["pipeline"] for row in successful if row.get("pipeline")]
    scorable = [row for row in pipeline_rows if row["canonicalScorable"]]
    latencies = [row["sttLatencyMs"] for row in successful]
    by_entity_type: dict[str, dict[str, int]] = {}
    for row in successful:
        entity_type = row["entityType"]
        bucket = by_entity_type.setdefault(entity_type, {"correct": 0, "total": 0})
        bucket["correct"] += int(row["entity"]["correct"])
        bucket["total"] += 1
    outcomes = Counter(row["outcome"] for row in pipeline_rows)
    return {
        "filesAttempted": len(rows),
        "filesTranscribed": len(successful),
        "overallWer": raw_edits / raw_words if raw_words else None,
        "normalizedWer": normalized_edits / normalized_words if normalized_words else None,
        "entityTokenAccuracy": entity_correct / entity_total if entity_total else None,
        "entityPhraseAccuracyByType": by_entity_type,
        "intentAccuracy": (
            sum(row["intentCorrect"] for row in pipeline_rows) / len(pipeline_rows)
            if pipeline_rows else None
        ),
        "canonicalAccuracy": (
            sum(bool(row["canonicalCorrect"]) for row in scorable) / len(scorable)
            if scorable else None
        ),
        "outcomes": {
            "CORRECT_CONFIDENT": outcomes["CORRECT_CONFIDENT"],
            "CLARIFICATION": outcomes["CLARIFICATION"],
            "NO_MATCH": outcomes["NO_MATCH"],
            "WRONG_CONFIDENT": outcomes["WRONG_CONFIDENT"],
        },
        "averageSttLatencyMs": mean(latencies) if latencies else None,
        "p95SttLatencyMs": nearest_rank_p95(latencies),
        "audioMinutes": duration_minutes,
        "estimatedCostUsd": duration_minutes * PRICE_PER_MINUTE_USD[model],
        "estimatedCostPerMinuteUsd": PRICE_PER_MINUTE_USD[model],
    }


def winner(models: list[dict[str, Any]]) -> str:
    accessible = [value for value in models if value["status"] == "ACCESSIBLE"]
    if not accessible:
        return "RAW_STT_INSUFFICIENT"
    # A domain STT winner must correctly recognize at least one labeled rally
    # phrase.  Safe downstream clarification is valuable, but it cannot turn a
    # complete failure on the core rally-name task into an STT recommendation.
    if not any(
        value["aggregate"]["entityPhraseAccuracyByType"].get("rally", {}).get("correct", 0) > 0
        for value in accessible
    ):
        return "RAW_STT_INSUFFICIENT"
    safe = [
        value for value in accessible
        if value["aggregate"]["outcomes"]["WRONG_CONFIDENT"] == 0
    ]
    candidates = safe or accessible
    candidates.sort(key=lambda value: (
        -value["aggregate"]["canonicalAccuracy"] if value["aggregate"]["canonicalAccuracy"] is not None else 1,
        -value["aggregate"]["intentAccuracy"] if value["aggregate"]["intentAccuracy"] is not None else 1,
        -value["aggregate"]["entityTokenAccuracy"] if value["aggregate"]["entityTokenAccuracy"] is not None else 1,
        value["aggregate"]["normalizedWer"] if value["aggregate"]["normalizedWer"] is not None else 999,
        value["aggregate"]["averageSttLatencyMs"] or 999999,
    ))
    return candidates[0]["model"]


async def run(report_path: Path) -> dict[str, Any]:
    settings = get_settings()
    if not settings.openai_api_key.get_secret_value():
        raise RuntimeError("OPENAI_API_KEY is not configured")
    manifest = json.loads(MANIFEST.read_text())
    fixtures = manifest["fixtures"]
    missing = [fixture["audioFile"] for fixture in fixtures if not (ROOT / fixture["audioFile"]).is_file()]
    if missing:
        raise RuntimeError(f"labeled audio is missing: {missing}")
    total_minutes = sum(wav_duration_ms(ROOT / fixture["audioFile"]) for fixture in fixtures) / 60_000

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

    model_reports: list[dict[str, Any]] = []
    engine = get_engine()
    async with engine.connect() as connection:
        entities = await MySqlEntitySearchDataSource(connection=connection).load_entities()
        entity_search = InMemoryEntitySearchService.from_entities(entities)
        conversation = ConversationalSearchService(
            query_parser=query_parser,
            entity_resolver=DatabaseEntityResolver(
                repository=EntitySearchLookupAdapter(search_service=entity_search)
            ),
            repository=SearchRepository(connection),
        )

        for model in MODELS:
            print(f"STT model: {model}", flush=True)
            provider = OpenAISpeechToTextProvider(SpeechProviderConfig(
                provider="openai",
                model=model,
                api_key=settings.openai_api_key.get_secret_value(),
                base_url=settings.openai_base_url,
                timeout_seconds=60.0,
                dynamic_top3_enabled=False,
                preprocessing_strategy="raw",
            ))
            rows: list[dict[str, Any]] = []
            inaccessible_error: str | None = None
            for fixture in fixtures:
                path = ROOT / fixture["audioFile"]
                duration_ms = wav_duration_ms(path)
                try:
                    transcription = await provider.transcribe(
                        SpokenAudioContext(
                            bytes=path.read_bytes(),
                            format="wav",
                            duration_ms=duration_ms,
                            local_file_path=None,
                        ),
                        filename=path.name,
                        language=fixture["language"],
                        context=None,
                    )
                except SpeechProviderTimeout as exc:
                    rows.append({
                        "fixtureId": fixture["fixtureId"],
                        "audioFile": fixture["audioFile"],
                        "errorClass": type(exc).__name__,
                        "error": str(exc),
                        "transcript": None,
                    })
                    continue
                except SpeechProviderError as exc:
                    message = str(exc)
                    rows.append({
                        "fixtureId": fixture["fixtureId"],
                        "audioFile": fixture["audioFile"],
                        "errorClass": type(exc).__name__,
                        "error": message,
                        "transcript": None,
                    })
                    if len(rows) == 1 and re.search(r"HTTP (400|403|404)", message):
                        inaccessible_error = message
                        break
                    continue

                raw_reference = fixture["referenceTranscriptRaw"]
                normalized_reference = fixture["referenceTranscriptNormalized"]
                raw_ref_tokens = tokens(raw_reference)
                raw_hyp_tokens = tokens(transcription.text)
                norm_ref_tokens = tokens(normalized_reference, fold_accents=True)
                norm_hyp_tokens = tokens(transcription.text, fold_accents=True)
                entity = phrase_diagnostic(fixture["expectedEntityMention"], transcription.text)
                _, pipeline_result = await conversation.search(
                    transcription.text,
                    session=SearchConversationSession(),
                    language=fixture["language"],
                )
                rows.append({
                    "fixtureId": fixture["fixtureId"],
                    "audioFile": fixture["audioFile"],
                    "audioDurationMs": duration_ms,
                    "language": fixture["language"],
                    "entityType": fixture["entityType"],
                    "referenceTranscriptRaw": raw_reference,
                    "referenceTranscriptNormalized": normalized_reference,
                    "transcript": transcription.text,
                    "rawWordErrors": edit_distance(raw_ref_tokens, raw_hyp_tokens),
                    "rawReferenceWords": len(raw_ref_tokens),
                    "wer": edit_distance(raw_ref_tokens, raw_hyp_tokens) / len(raw_ref_tokens),
                    "normalizedWordErrors": edit_distance(norm_ref_tokens, norm_hyp_tokens),
                    "normalizedReferenceWords": len(norm_ref_tokens),
                    "normalizedWer": edit_distance(norm_ref_tokens, norm_hyp_tokens) / len(norm_ref_tokens),
                    "entity": entity,
                    "sttLatencyMs": round(transcription.latency_ms, 3),
                    "pipeline": score_pipeline(
                        fixture,
                        pipeline_result,
                        entity_mention_correct=entity["correct"],
                    ),
                })
                transcription.dispose_audio()
                print(f"  {fixture['fixtureId']}: {transcription.text}", flush=True)

            status = "MODEL_NOT_ACCESSIBLE" if inaccessible_error else "ACCESSIBLE"
            model_reports.append({
                "model": model,
                "status": status,
                "accessError": inaccessible_error,
                "settings": {
                    "languageFromFixture": True,
                    "timeoutSeconds": 60,
                    "preprocessing": "RAW_NO_OP",
                    "hintsOrContext": False,
                },
                "rows": rows,
                "aggregate": aggregate(model, rows, total_minutes),
            })

    recommendation = winner(model_reports)
    report = {
        "runVersion": "URGENT_STT_QUALITY_BAKEOFF_V1",
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "primaryCorpus": "REAL_LABELED_HUMAN_AUDIO_ONLY",
        "fixtureManifest": str(MANIFEST.relative_to(ROOT)),
        "fixtureCount": len(fixtures),
        "syntheticPrimaryData": False,
        "sharedConditions": {
            "preprocessing": "RAW_NO_OP",
            "hintsOrContext": False,
            "aliasesAdded": False,
            "downstream": "PY-3.1 -> PY-2 Entity Search -> resolver -> PY-1 live MySQL",
            "queryUnderstandingProvider": "openai",
            "queryUnderstandingModel": PY3_MODEL,
            "queryUnderstandingTemperature": 0.0,
        },
        "models": model_reports,
        "specialDiagnostics": {
            "aluksneFixtures": ["human-smoke-001", "human-smoke-002", "human-smoke-003", "human-smoke-005"],
            "maxFreemanFixtures": ["human-smoke-004"],
            "instruction": "See each model row's verbatim transcript and entity diagnostic.",
        },
        "recommendation": (
            f"STT_WINNER={recommendation}"
            if recommendation != "RAW_STT_INSUFFICIENT"
            else recommendation
        ),
        "pricingNote": "Static official list-price estimates; actual billing may vary.",
        "finalModelBenchmark": "DEFERRED",
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
        "recommendation": report["recommendation"],
        "models": [
            {"model": value["model"], "status": value["status"], "aggregate": value["aggregate"]}
            for value in report["models"]
        ],
    }, indent=2))


if __name__ == "__main__":
    main()
