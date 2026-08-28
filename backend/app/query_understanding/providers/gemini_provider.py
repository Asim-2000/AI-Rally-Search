import json
from urllib.parse import quote

from ..models import ProviderResponse, TokenUsage
from ..prompt import SYSTEM_PROMPT
from ..provider import ProviderError, QueryUnderstandingProvider
from .http import post_json


class GeminiProvider(QueryUnderstandingProvider):
    async def parse_raw(self, natural_language_query: str, *, language: str | None = None) -> ProviderResponse:
        c = self.config
        if not c.api_key:
            raise ProviderError("GEMINI_API_KEY is missing")
        model = c.model if c.model.startswith("models/") else f"models/{c.model}"
        generation = {"temperature": c.temperature, "maxOutputTokens": c.max_tokens, "responseMimeType": "application/json"}
        if c.structured_output:
            from ...domain.search_query import SearchQuery
            generation["responseJsonSchema"] = SearchQuery.model_json_schema(by_alias=True)
        generation.update(c.parameters)
        body = {"systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]}, "contents": [{"role": "user", "parts": [{"text": natural_language_query}]}], "generationConfig": generation}
        url = f"{(c.base_url or 'https://generativelanguage.googleapis.com/v1beta').rstrip('/')}/{model}:generateContent?key={quote(c.api_key)}"
        data = await post_json(url, body, {"Content-Type": "application/json"}, c.timeout_seconds)
        try:
            raw = data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError) as exc:
            raise ProviderError("Gemini response contained no candidate text") from exc
        u = data.get("usageMetadata", {})
        return ProviderResponse(raw_response=raw, usage=TokenUsage(input_tokens=u.get("promptTokenCount"), output_tokens=u.get("candidatesTokenCount"), cached_tokens=u.get("cachedContentTokenCount"), total_tokens=u.get("totalTokenCount")), metadata={"finish_reason": data["candidates"][0].get("finishReason")})
