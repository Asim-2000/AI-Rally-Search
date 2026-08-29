from __future__ import annotations

import json
import time
from typing import Any
from urllib.parse import quote

import httpx

from app.domain.search_query import SearchQuery
from app.query_understanding.prompt import SYSTEM_PROMPT
from .base import ProviderUsage, RawBenchmarkResponse

# Inlined OpenAPI schema for Google Gemini structured JSON output
GEMINI_SEARCH_QUERY_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "intent": {
            "type": "STRING",
            "enum": [
                "SEARCH_RALLIES",
                "SEARCH_DRIVER_RALLIES",
                "SEARCH_DRIVER_WINS",
                "GET_RALLY_RESULTS",
                "GET_RALLY_TOP_FINISHERS",
                "SEARCH_VIDEO_ACTIONS",
                "SEARCH_DRIVER_VIDEOS",
                "GET_TOP_UPLOADERS",
                "GET_TOP_DRIVERS_BY_WINS",
            ],
        },
        "countries": {"type": "ARRAY", "items": {"type": "STRING"}},
        "cities": {"type": "ARRAY", "items": {"type": "STRING"}},
        "years": {"type": "ARRAY", "items": {"type": "INTEGER"}},
        "yearFrom": {"type": "INTEGER"},
        "yearTo": {"type": "INTEGER"},
        "rallyNames": {"type": "ARRAY", "items": {"type": "STRING"}},
        "eventNames": {"type": "ARRAY", "items": {"type": "STRING"}},
        "stageNames": {"type": "ARRAY", "items": {"type": "STRING"}},
        "stageNumbers": {"type": "ARRAY", "items": {"type": "STRING"}},
        "driverNames": {"type": "ARRAY", "items": {"type": "STRING"}},
        "driverIds": {"type": "ARRAY", "items": {"type": "STRING"}},
        "actionTypes": {"type": "ARRAY", "items": {"type": "STRING"}},
        "uploaders": {"type": "ARRAY", "items": {"type": "STRING"}},
        "personRole": {"type": "STRING", "enum": ["DRIVER", "CO_DRIVER", "ANY"]},
        "driverMatchMode": {"type": "STRING", "enum": ["ALL", "ANY"]},
        "limit": {"type": "INTEGER"},
        "offset": {"type": "INTEGER"},
    },
    "required": ["intent"],
}


class GeminiQUAdapter:
    def __init__(
        self,
        api_key: str,
        model: str = "gemini-3.5-flash-lite",
        base_url: str = "https://generativelanguage.googleapis.com/v1beta",
        timeout_seconds: float = 30.0,
    ) -> None:
        self.api_key = api_key
        # Strip leading models/ if present, since URL template prepends models/
        raw_m = model.removeprefix("models/")
        self.model = raw_m
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

    async def parse_query(
        self,
        case_id: str,
        query: str,
        *,
        context_str: str | None = None,
        language: str | None = None,
    ) -> RawBenchmarkResponse:
        if not self.api_key:
            return RawBenchmarkResponse(
                case_id=case_id,
                provider="gemini",
                model=self.model,
                raw_response=None,
                parsed_query=None,
                schema_valid=False,
                latency_ms=0.0,
                error="Missing Google Gemini API key",
            )

        user_content = f"{context_str}{query}" if context_str else query

        gen_config: dict[str, Any] = {
            "temperature": 0.0,
            "maxOutputTokens": 1024,
            "responseMimeType": "application/json",
            "responseSchema": GEMINI_SEARCH_QUERY_SCHEMA,
        }

        # For models supporting thinkingConfig (e.g. gemini-3.7-flash, gemini-2.5-flash)
        if "3.7" in self.model or "2.5" in self.model:
            gen_config["thinkingConfig"] = {"thinkingBudget": 0}

        body = {
            "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
            "contents": [{"role": "user", "parts": [{"text": user_content}]}],
            "generationConfig": gen_config,
        }

        url = f"{self.base_url}/models/{self.model}:generateContent?key={quote(self.api_key)}"
        started = time.perf_counter()
        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                res = await client.post(
                    url,
                    headers={"Content-Type": "application/json"},
                    json=body,
                )
            latency_ms = (time.perf_counter() - started) * 1000.0

            if res.status_code != 200:
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="gemini",
                    model=self.model,
                    raw_response=res.text,
                    parsed_query=None,
                    schema_valid=False,
                    latency_ms=latency_ms,
                    error=f"HTTP {res.status_code}: {res.text[:300]}",
                )

            data = res.json()
            candidates = data.get("candidates") or []
            if not candidates or "content" not in candidates[0]:
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="gemini",
                    model=self.model,
                    raw_response=json.dumps(data),
                    parsed_query=None,
                    schema_valid=False,
                    latency_ms=latency_ms,
                    error="Empty candidate content returned",
                )

            raw_text = candidates[0]["content"]["parts"][0]["text"]
            u = data.get("usageMetadata", {})

            usage = ProviderUsage(
                input_tokens=u.get("promptTokenCount"),
                output_tokens=u.get("candidatesTokenCount"),
                cached_tokens=u.get("cachedContentTokenCount"),
                reasoning_tokens=u.get("thoughtsTokenCount"),
                total_tokens=u.get("totalTokenCount"),
            )

            try:
                parsed_json = json.loads(raw_text)
                parsed_query = SearchQuery.model_validate(parsed_json).model_dump(
                    by_alias=True, mode="json", exclude_none=True
                )
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="gemini",
                    model=self.model,
                    raw_response=raw_text,
                    parsed_query=parsed_query,
                    schema_valid=True,
                    latency_ms=latency_ms,
                    usage=usage,
                )
            except Exception as parse_exc:
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="gemini",
                    model=self.model,
                    raw_response=raw_text,
                    parsed_query=None,
                    schema_valid=False,
                    latency_ms=latency_ms,
                    usage=usage,
                    error=f"Schema validation error: {parse_exc}",
                )

        except Exception as exc:
            latency_ms = (time.perf_counter() - started) * 1000.0
            return RawBenchmarkResponse(
                case_id=case_id,
                provider="gemini",
                model=self.model,
                raw_response=None,
                parsed_query=None,
                schema_valid=False,
                latency_ms=latency_ms,
                error=f"Transport error: {exc}",
            )
