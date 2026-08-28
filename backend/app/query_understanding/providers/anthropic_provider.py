import json

from ..models import ProviderResponse, TokenUsage
from ..prompt import SYSTEM_PROMPT
from ..provider import ProviderError, QueryUnderstandingProvider
from .http import post_json


class AnthropicProvider(QueryUnderstandingProvider):
    async def parse_raw(self, natural_language_query: str, *, language: str | None = None) -> ProviderResponse:
        c = self.config
        if not c.api_key:
            raise ProviderError("ANTHROPIC_API_KEY is missing")
        from ...domain.search_query import SearchQuery
        tool = {"name": "rally_search_query", "description": "Extract the structured rally SearchQuery", "input_schema": SearchQuery.model_json_schema(by_alias=True)}
        body = {"model": c.model, "max_tokens": c.max_tokens, "temperature": c.temperature, "system": SYSTEM_PROMPT, "messages": [{"role": "user", "content": natural_language_query}], "tools": [tool], "tool_choice": {"type": "tool", "name": "rally_search_query"}}
        body.update(c.parameters)
        data = await post_json(f"{(c.base_url or 'https://api.anthropic.com/v1').rstrip('/')}/messages", body, {"Content-Type": "application/json", "x-api-key": c.api_key, "anthropic-version": "2023-06-01"}, c.timeout_seconds)
        blocks = data.get("content") or []
        block = next((item for item in blocks if item.get("type") == "tool_use" and item.get("name") == "rally_search_query"), None)
        if block is None:
            raise ProviderError("Anthropic response contained no rally_search_query tool use")
        u = data.get("usage", {})
        return ProviderResponse(raw_response=json.dumps(block.get("input")), usage=TokenUsage(input_tokens=u.get("input_tokens"), output_tokens=u.get("output_tokens"), cached_tokens=(u.get("cache_read_input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0), total_tokens=(u.get("input_tokens") + u.get("output_tokens")) if u.get("input_tokens") is not None and u.get("output_tokens") is not None else None), metadata={"stop_reason": data.get("stop_reason")})
