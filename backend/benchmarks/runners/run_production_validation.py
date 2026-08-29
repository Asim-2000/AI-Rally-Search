from __future__ import annotations

import asyncio
import csv
import datetime as dt
import json
import math
import os
import statistics
import time
from pathlib import Path
from typing import Any

import httpx


BASE_URL = os.getenv("VALIDATION_BASE_URL", "http://127.0.0.1:8000")


CASES: list[dict[str, Any]] = [
    # 10 direct deterministic filters
    {"id": "direct_01", "category": "direct_filter", "input": "Rallies in Ireland", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    {"id": "direct_02", "category": "direct_filter", "input": "Rallies in 2025", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    {"id": "direct_03", "category": "direct_filter", "input": "Rallies located in Andorra and United Arab Emirates", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    {"id": "direct_04", "category": "direct_filter", "input": "Show rallies in Austria", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    {"id": "direct_05", "category": "direct_filter", "input": "Rallies from 2024 to 2026", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    {"id": "direct_06", "category": "direct_filter", "input": "Crashes in Ireland in 2025", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "RESOLVED"},
    {"id": "direct_07", "category": "direct_filter", "input": "Show jump clips", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "RESOLVED"},
    {"id": "direct_08", "category": "direct_filter", "input": "Show rallies in Afghanistan", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    {"id": "direct_09", "category": "direct_filter", "input": "Show rallies in Albania and Armenia", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    {"id": "direct_10", "category": "direct_filter", "input": "Show rally events in 2026", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    # 10 entity/noisy searches
    {"id": "entity_01", "category": "entity_noisy", "input": "aluqsne", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Alūksne"},
    {"id": "entity_02", "category": "entity_noisy", "input": "Rally aluqsne", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Alūksne"},
    {"id": "entity_03", "category": "entity_noisy", "input": "aluksnay", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Alūksne"},
    {"id": "entity_04", "category": "entity_noisy", "input": "donegl", "intent": "SEARCH_RALLIES", "outcome": "CLARIFY"},
    {"id": "entity_05", "category": "entity_noisy", "input": "Show Moonraker Rally", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Moonraker"},
    {"id": "entity_06", "category": "entity_noisy", "input": "Show Woodpecker Rally 2025", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED", "entity": "Woodpecker"},
    {"id": "entity_07", "category": "entity_noisy", "input": "Show Trackrod Rally", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Trackrod"},
    {"id": "entity_08", "category": "entity_noisy", "input": "Show Killarney rallies", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Killarney"},
    {"id": "entity_09", "category": "entity_noisy", "input": "Show 6 Uren van Kortrijk 2024", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED", "entity": "Kortrijk"},
    {"id": "entity_10", "category": "entity_noisy", "input": "Show Get Jerky Rally", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Get Jerky"},
    # 8 driver/person searches
    {"id": "driver_01", "category": "driver_person", "input": "max freemn", "intent": "SEARCH_DRIVER_RALLIES", "outcome": "SAFE", "entity": "Max Freeman"},
    {"id": "driver_02", "category": "driver_person", "input": "Show Max Freeman's rallies", "intent": "SEARCH_DRIVER_RALLIES", "outcome": "RESOLVED", "entity": "Max Freeman"},
    {"id": "driver_03", "category": "driver_person", "input": "Rallies driven by Josh Moffett", "intent": "SEARCH_DRIVER_RALLIES", "outcome": "RESOLVED", "entity": "Josh Moffett"},
    {"id": "driver_04", "category": "driver_person", "input": "Rallies co-driven by Max Freeman", "intent": "SEARCH_DRIVER_RALLIES", "outcome": "RESOLVED", "entity": "Max Freeman"},
    {"id": "driver_05", "category": "driver_person", "input": "Wins by Josh Moffett", "intent": "SEARCH_DRIVER_WINS", "outcome": "RESOLVED", "entity": "Josh Moffett"},
    {"id": "driver_06", "category": "driver_person", "input": "Videos featuring Max Freeman", "intent": "SEARCH_DRIVER_VIDEOS", "outcome": "RESOLVED", "entity": "Max Freeman"},
    {"id": "driver_07", "category": "driver_person", "input": "Rallies where Aaron Browne competed", "intent": "SEARCH_DRIVER_RALLIES", "outcome": "SAFE", "entity": "Aaron Browne"},
    {"id": "driver_08", "category": "driver_person", "input": "Who has the most overall rally wins?", "intent": "GET_TOP_DRIVERS_BY_WINS", "outcome": "RESOLVED"},
    # 6 video/action searches
    {"id": "video_01", "category": "video_action", "input": "Show jumps from Moonraker", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "SAFE", "entity": "Moonraker"},
    {"id": "video_02", "category": "video_action", "input": "Water crossing clips from Woodpecker", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "SAFE", "entity": "Woodpecker"},
    {"id": "video_03", "category": "video_action", "input": "Show spins in Killarney in 2024", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "SAFE", "entity": "Killarney"},
    {"id": "video_04", "category": "video_action", "input": "Show drift clips from Get Jerky Rally", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "SAFE", "entity": "Get Jerky"},
    {"id": "video_05", "category": "video_action", "input": "Show crash clips featuring Josh Moffett", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "RESOLVED", "entity": "Josh Moffett"},
    {"id": "video_06", "category": "video_action", "input": "Find hairpins on Gale Rigg stage at Trackrod", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "SAFE", "entity": "Trackrod"},
    # 6 ambiguity / clarification cases
    {"id": "ambiguity_01", "category": "ambiguity", "input": "Who won?", "intent": "GET_RALLY_RESULTS", "outcome": "CLARIFY"},
    {"id": "ambiguity_02", "category": "ambiguity", "input": "Top finishers", "intent": "GET_RALLY_TOP_FINISHERS", "outcome": "CLARIFY"},
    {"id": "ambiguity_03", "category": "ambiguity", "input": "Show his rallies", "intent": "SEARCH_DRIVER_RALLIES", "outcome": "CLARIFY"},
    {"id": "ambiguity_04", "category": "ambiguity", "input": "Show driver videos", "intent": "SEARCH_DRIVER_VIDEOS", "outcome": "CLARIFY"},
    {"id": "ambiguity_05", "category": "ambiguity", "input": "Donegal Rally results", "intent": "GET_RALLY_RESULTS", "outcome": "CLARIFY"},
    {"id": "ambiguity_06", "category": "ambiguity", "input": "Leaderboard", "intent": "GET_RALLY_TOP_FINISHERS", "outcome": "CLARIFY"},
    # 6 real conversation turns, grouped into two sessions
    {"id": "conversation_01", "category": "conversation", "input": "Show Max Freeman's rallies", "intent": "SEARCH_DRIVER_RALLIES", "outcome": "RESOLVED", "entity": "Max Freeman", "session": "max"},
    {"id": "conversation_02", "category": "conversation", "input": "What about 2025?", "intent": "SEARCH_DRIVER_RALLIES", "outcome": "SAFE", "entity": "Max Freeman", "session": "max"},
    {"id": "conversation_03", "category": "conversation", "input": "Show videos from that rally", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "SAFE", "session": "max"},
    {"id": "conversation_04", "category": "conversation", "input": "Show Rally Aluksne", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Alūksne", "session": "aluksne"},
    {"id": "conversation_05", "category": "conversation", "input": "Who won it?", "intent": "GET_RALLY_RESULTS", "outcome": "RESOLVED", "entity": "Alūksne", "session": "aluksne"},
    {"id": "conversation_06", "category": "conversation", "input": "Show videos from that rally", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "SAFE", "entity": "Alūksne", "session": "aluksne"},
    # 5 special-query historical regressions
    {"id": "historical_01", "category": "historical", "input": "hello", "outcome": "SPECIAL"},
    {"id": "historical_02", "category": "historical", "input": "thanks", "outcome": "SPECIAL"},
    {"id": "historical_03", "category": "historical", "input": "what can you do?", "outcome": "SPECIAL"},
    {"id": "historical_04", "category": "historical", "input": "tell me a joke", "outcome": "SPECIAL"},
    {"id": "historical_05", "category": "historical", "input": "are you alive?", "outcome": "SPECIAL"},
    # 5 previously failing downstream cases
    {"id": "downstream_01", "category": "downstream_fixed", "input": "Rank drivers by historical rally victories", "intent": "GET_TOP_DRIVERS_BY_WINS", "outcome": "RESOLVED"},
    {"id": "downstream_02", "category": "downstream_fixed", "input": "Rallies located in UAE and Afghanistan", "intent": "SEARCH_RALLIES", "outcome": "RESOLVED"},
    {"id": "downstream_03", "category": "downstream_fixed", "input": "Show jump clips featuring A. Buyze from 6 Uren van Kortrijk 2024 in 2022", "intent": "SEARCH_VIDEO_ACTIONS", "outcome": "SAFE", "entity": "Kortrijk"},
    {"id": "downstream_04", "category": "downstream_fixed", "input": "Show results", "intent": "GET_RALLY_RESULTS", "outcome": "CLARIFY"},
    {"id": "downstream_05", "category": "downstream_fixed", "input": "weather at Rally Aluksne 2026", "intent": "SEARCH_RALLIES", "outcome": "SAFE", "entity": "Alūksne"},
]


def percentile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    index = (len(ordered) - 1) * q
    low = math.floor(index)
    high = math.ceil(index)
    if low == high:
        return ordered[low]
    return ordered[low] + (ordered[high] - ordered[low]) * (index - low)


def text_blob(result: dict[str, Any]) -> str:
    return json.dumps(result, ensure_ascii=False).casefold()


def classify(case: dict[str, Any], status: int, payload: dict[str, Any]) -> str:
    if status != 200:
        return "ERROR"
    result = payload.get("result") or {}
    actual_intent = ((result.get("parsedQuery") or {}).get("intent"))
    clarify = result.get("requiresClarification") is True
    count = ((result.get("searchResponse") or {}).get("totalCount") or 0)
    expected = case["outcome"]
    entity_ok = not case.get("entity") or case["entity"].casefold() in text_blob(result)
    intent_ok = not case.get("intent") or actual_intent == case["intent"]

    if expected == "SPECIAL":
        return "CORRECT_RESULT" if result.get("specialResponseCategory") else "ERROR"
    if expected == "CLARIFY":
        if clarify:
            return "CORRECT_CLARIFICATION"
        return "FALSE_CONFIDENT" if count > 0 else "WRONG_RESULT"
    if expected == "SAFE":
        if clarify:
            return "CORRECT_CLARIFICATION" if entity_ok or not case.get("entity") else "WRONG_RESULT"
        if result.get("error"):
            return "ERROR"
        return "SAFE_RECOVERY" if intent_ok and entity_ok else "WRONG_RESULT"
    if expected == "NO_MATCH":
        return "CORRECT_NO_MATCH" if not clarify and count == 0 and not result.get("error") else "WRONG_RESULT"
    if clarify:
        return "WRONG_RESULT"
    if result.get("error"):
        return "ERROR"
    return "CORRECT_RESULT" if intent_ok and entity_ok else "WRONG_RESULT"


async def main() -> None:
    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    output = Path(f"benchmarks/results/production_validation_{timestamp}")
    output.mkdir(parents=True, exist_ok=True)
    sessions: dict[str, dict[str, Any]] = {}
    rows: list[dict[str, Any]] = []

    async with httpx.AsyncClient(base_url=BASE_URL, timeout=60.0) as client:
        for generation, case in enumerate(CASES, 1):
            session_key = case.get("session")
            request = {
                "query": case["input"],
                "session": sessions.get(session_key, {}) if session_key else {},
                "language": "en",
                "requestId": generation,
            }
            started = time.perf_counter()
            try:
                response = await client.post("/v1/conversation/search", json=request)
                latency = (time.perf_counter() - started) * 1000
                payload = response.json()
                status = response.status_code
            except Exception as exc:
                latency = (time.perf_counter() - started) * 1000
                payload = {"transportError": str(exc)}
                status = 0
            if session_key and status == 200 and payload.get("session"):
                sessions[session_key] = payload["session"]
            result = payload.get("result") or {}
            outcome = classify(case, status, payload)
            row = {
                **case,
                "http_status": status,
                "generation": ((payload.get("session") or {}).get("activeRequestId")),
                "request_id": payload.get("requestId"),
                "parsed_query": result.get("parsedQuery"),
                "resolved_query": result.get("resolvedQuery"),
                "routing_plan": result.get("routingPlan"),
                "resolution_outcome": "CLARIFY" if result.get("requiresClarification") else ("ERROR" if result.get("error") else "RESOLVED"),
                "clarification": result.get("clarificationQuestion"),
                "candidates": result.get("candidates") or [],
                "search_plan": result.get("searchPlan"),
                "result_count": ((result.get("searchResponse") or {}).get("totalCount") or 0),
                "http_latency_ms": round(latency, 3),
                "component_latency_ms": {
                    "qu": result.get("parseLatencyMs"),
                    "entity_resolution": result.get("entityResolutionLatencyMs"),
                    "db": result.get("dbLatencyMs"),
                    "total": result.get("totalLatencyMs"),
                },
                "error": result.get("error") or payload.get("transportError"),
                "error_code": result.get("errorCode"),
                "friendly_message": result.get("friendlyMessage"),
                "neutralized_temporal_filters": result.get("neutralizedTemporalFilters") or [],
                "classification": outcome,
                "response": payload,
            }
            rows.append(row)
            print(f"{case['id']} {status} {outcome} {latency:.0f}ms")

        error_contract = []
        for name, body in [
            ("malformed", {"query": 42}),
            ("empty", {"query": ""}),
        ]:
            response = await client.post("/v1/conversation/search", json=body)
            error_contract.append({"case": name, "status": response.status_code, "body": response.json()})
        response = await client.post("/v1/voice/transcribe?filename=empty.wav&language=en", content=b"")
        error_contract.append({"case": "empty_voice", "status": response.status_code, "body": response.json()})

        voice_rows = []
        audio_files = [
            Path("../test/eval/audio/human/record_out.wav"),
            Path("../test/eval/audio/human/record_out (1).wav"),
        ]
        for audio_path in audio_files:
            audio = audio_path.read_bytes()
            started = time.perf_counter()
            response = await client.post(
                f"/v1/voice/transcribe?filename={audio_path.name}&language=en",
                content=audio,
                headers={"content-type": "audio/wav"},
            )
            stt_ms = (time.perf_counter() - started) * 1000
            payload = response.json()
            transcript = payload.get("transcript") or ""
            search_started = time.perf_counter()
            search_response = await client.post("/v1/conversation/search", json={"query": transcript, "language": "en"}) if transcript else None
            search_ms = (time.perf_counter() - search_started) * 1000 if search_response else 0.0
            voice_rows.append({
                "audio_file": str(audio_path),
                "http_status": response.status_code,
                "transcript": transcript,
                "provider": payload.get("provider"),
                "model": payload.get("model"),
                "language": payload.get("language"),
                "endpoint_latency_ms": round(stt_ms, 3),
                "provider_latency_ms": payload.get("latencyMs"),
                "search_http_status": search_response.status_code if search_response else None,
                "search_latency_ms": round(search_ms, 3),
                "total_voice_to_results_ms": round(stt_ms + search_ms, 3),
                "search_response": search_response.json() if search_response else None,
                "automatic_search_submission": False,
            })

    (output / "production_validation_results.jsonl").write_text("".join(json.dumps(row, ensure_ascii=False, default=str) + "\n" for row in rows), encoding="utf-8")
    failures = [row for row in rows if row["classification"] in {"WRONG_RESULT", "FALSE_CONFIDENT", "ERROR"}]
    (output / "production_validation_failures.jsonl").write_text("".join(json.dumps(row, ensure_ascii=False, default=str) + "\n" for row in failures), encoding="utf-8")
    (output / "voice_smoke_results.jsonl").write_text("".join(json.dumps(row, ensure_ascii=False, default=str) + "\n" for row in voice_rows), encoding="utf-8")

    latencies = [row["http_latency_ms"] for row in rows]
    with (output / "latency_summary.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["metric", "milliseconds"])
        for name, value in [
            ("mean", statistics.mean(latencies)),
            ("p50", percentile(latencies, 0.50)),
            ("p90", percentile(latencies, 0.90)),
            ("p95", percentile(latencies, 0.95)),
            ("max", max(latencies)),
        ]:
            writer.writerow([name, f"{value:.3f}"])

    counts: dict[str, int] = {}
    for row in rows:
        counts[row["classification"]] = counts.get(row["classification"], 0) + 1
    metadata = {
        "timestamp": timestamp,
        "base_url": BASE_URL,
        "text_cases": len(rows),
        "classifications": counts,
        "success_rate": sum(value for key, value in counts.items() if key.startswith("CORRECT_") or key == "SAFE_RECOVERY") / len(rows),
        "false_confident": counts.get("FALSE_CONFIDENT", 0),
        "latency_ms": {"p50": percentile(latencies, 0.5), "p95": percentile(latencies, 0.95), "max": max(latencies)},
        "conversation_success": sum(row["classification"] not in {"WRONG_RESULT", "FALSE_CONFIDENT", "ERROR"} for row in rows if row["category"] == "conversation"),
        "conversation_total": sum(row["category"] == "conversation" for row in rows),
        "historical_success": sum(row["classification"] not in {"WRONG_RESULT", "FALSE_CONFIDENT", "ERROR"} for row in rows if row["category"] == "historical"),
        "historical_total": sum(row["category"] == "historical" for row in rows),
        "hardening_success": sum(row["classification"] not in {"WRONG_RESULT", "FALSE_CONFIDENT", "ERROR"} for row in rows if row["category"] == "downstream_fixed"),
        "hardening_total": sum(row["category"] == "downstream_fixed" for row in rows),
        "ungrounded_guard_activations": sum(bool(row["neutralized_temporal_filters"]) for row in rows),
        "error_contract": error_contract,
        "voice_cases": len(voice_rows),
        "voice_success": sum(row["http_status"] == 200 and row["provider"] == "openai" and row["model"] == "whisper-1" for row in voice_rows),
    }
    (output / "run_metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(output)


if __name__ == "__main__":
    asyncio.run(main())
