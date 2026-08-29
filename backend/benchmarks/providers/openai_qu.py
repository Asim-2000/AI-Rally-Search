from __future__ import annotations

import json
import time
from typing import Any

import httpx

from app.domain.search_query import SearchQuery
from app.query_understanding.prompt import SYSTEM_PROMPT
from .base import ProviderUsage, RawBenchmarkResponse


def _get_strict_schema() -> dict[str, Any]:
    schema = SearchQuery.model_json_schema(by_alias=True)
    schema["additionalProperties"] = False
    schema["required"] = list(schema.get("properties", {}))
    _strip_defaults(schema)
    return schema


def _strip_defaults(value: Any) -> None:
    if isinstance(value, dict):
        value.pop("default", None)
        for child in value.values():
            _strip_defaults(child)
    elif isinstance(value, list):
        for child in value:
            _strip_defaults(child)


class OpenAIQUAdapter:
    def __init__(
        self,
        api_key: str,
        model: str = "gpt-5.6-luna",
        base_url: str = "https://api.openai.com/v1",
        timeout_seconds: float = 30.0,
    ) -> None:
        self.api_key = api_key
        self.model = model
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
        user_content = f"{context_str}{query}" if context_str else query
        schema = _get_strict_schema()

        body: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
            "max_completion_tokens": 1024,
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "rally_search_query",
                    "strict": True,
                    "schema": schema,
                },
            },
        }
        # gpt-5.6-luna and reasoning models require omitting temperature
        is_temp_restricted = any(k in self.model for k in ("luna", "o1", "o3", "o4", "gpt-5"))
        if not is_temp_restricted:
            body["temperature"] = 0.0

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }

        started = time.perf_counter()
        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                res = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=headers,
                    json=body,
                )
            latency_ms = (time.perf_counter() - started) * 1000.0

            if res.status_code != 200:
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="openai",
                    model=self.model,
                    raw_response=res.text,
                    parsed_query=None,
                    schema_valid=False,
                    latency_ms=latency_ms,
                    error=f"HTTP {res.status_code}: {res.text[:300]}",
                )

            data = res.json()
            raw_content = data["choices"][0]["message"]["content"]
            usage_data = data.get("usage", {})
            prompt_details = usage_data.get("prompt_tokens_details") or {}
            comp_details = usage_data.get("completion_tokens_details") or {}

            usage = ProviderUsage(
                input_tokens=usage_data.get("prompt_tokens"),
                output_tokens=usage_data.get("completion_tokens"),
                cached_tokens=prompt_details.get("cached_tokens"),
                reasoning_tokens=comp_details.get("reasoning_tokens"),
                total_tokens=usage_data.get("total_tokens"),
            )

            try:
                parsed_json = json.loads(raw_content)
                parsed_query = SearchQuery.model_validate(parsed_json).model_dump(
                    by_alias=True, mode="json", exclude_none=True
                )
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="openai",
                    model=self.model,
                    raw_response=raw_content,
                    parsed_query=parsed_query,
                    schema_valid=True,
                    latency_ms=latency_ms,
                    usage=usage,
                )
            except Exception as parse_exc:
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="openai",
                    model=self.model,
                    raw_response=raw_content,
                    parsed_query=None,
                    schema_valid=False,
                    latency_ms=latency_ms,
                    usage=usage,
                    error=f"JSON/Schema validation error: {parse_exc}",
                )

        except Exception as exc:
            latency_ms = (time.perf_counter() - started) * 1000.0
            return RawBenchmarkResponse(
                case_id=case_id,
                provider="openai",
                model=self.model,
                raw_response=None,
                parsed_query=None,
                schema_valid=False,
                latency_ms=latency_ms,
                error=f"Transport error: {exc}",
            )
