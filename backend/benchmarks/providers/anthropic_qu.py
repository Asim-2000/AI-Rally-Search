from __future__ import annotations

import json
import time
from typing import Any

import httpx

from app.domain.search_query import SearchQuery
from app.query_understanding.prompt import SYSTEM_PROMPT
from .base import ProviderUsage, RawBenchmarkResponse


class AnthropicQUAdapter:
    def __init__(
        self,
        api_key: str,
        model: str = "claude-haiku-4-5",
        base_url: str = "https://api.anthropic.com/v1",
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
        schema = SearchQuery.model_json_schema(by_alias=True)

        tool = {
            "name": "rally_search_query",
            "description": "Extract the structured rally SearchQuery",
            "input_schema": schema,
        }

        body: dict[str, Any] = {
            "model": self.model,
            "max_tokens": 1024,
            "system": SYSTEM_PROMPT,
            "messages": [{"role": "user", "content": user_content}],
            "tools": [tool],
            "tool_choice": {"type": "tool", "name": "rally_search_query"},
        }
        # Models such as claude-sonnet-5 deprecate temperature parameter
        if "sonnet-5" not in self.model:
            body["temperature"] = 0.0

        headers = {
            "Content-Type": "application/json",
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
        }

        started = time.perf_counter()
        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                res = await client.post(
                    f"{self.base_url}/messages",
                    headers=headers,
                    json=body,
                )
            latency_ms = (time.perf_counter() - started) * 1000.0

            if res.status_code != 200:
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="anthropic",
                    model=self.model,
                    raw_response=res.text,
                    parsed_query=None,
                    schema_valid=False,
                    latency_ms=latency_ms,
                    error=f"HTTP {res.status_code}: {res.text[:300]}",
                )

            data = res.json()
            blocks = data.get("content") or []
            block = next(
                (item for item in blocks if item.get("type") == "tool_use" and item.get("name") == "rally_search_query"),
                None,
            )

            u = data.get("usage", {})
            input_tokens = u.get("input_tokens")
            output_tokens = u.get("output_tokens")
            cached_tokens = (u.get("cache_read_input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0)
            total = (input_tokens + output_tokens) if input_tokens is not None and output_tokens is not None else None

            usage = ProviderUsage(
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                cached_tokens=cached_tokens,
                total_tokens=total,
            )

            if block is None:
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="anthropic",
                    model=self.model,
                    raw_response=json.dumps(data),
                    parsed_query=None,
                    schema_valid=False,
                    latency_ms=latency_ms,
                    usage=usage,
                    error="No rally_search_query tool use returned by Anthropic",
                )

            tool_input = block.get("input") or {}
            raw_str = json.dumps(tool_input)

            try:
                parsed_query = SearchQuery.model_validate(tool_input).model_dump(
                    by_alias=True, mode="json", exclude_none=True
                )
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="anthropic",
                    model=self.model,
                    raw_response=raw_str,
                    parsed_query=parsed_query,
                    schema_valid=True,
                    latency_ms=latency_ms,
                    usage=usage,
                )
            except Exception as parse_exc:
                return RawBenchmarkResponse(
                    case_id=case_id,
                    provider="anthropic",
                    model=self.model,
                    raw_response=raw_str,
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
                provider="anthropic",
                model=self.model,
                raw_response=None,
                parsed_query=None,
                schema_valid=False,
                latency_ms=latency_ms,
                error=f"Transport error: {exc}",
            )
