from functools import lru_cache
from typing import Any

from ...observability import Phase
from ..models import ProviderResponse, TokenUsage
from ..prompt import SYSTEM_PROMPT
from ..provider import ProviderError, QueryUnderstandingProvider
from .http import post_json


@lru_cache(maxsize=1)
def _response_schema() -> dict[str, Any]:
    """The SearchQuery JSON schema, built once per process rather than per call."""
    from ...domain.search_query import SearchQuery

    return SearchQuery.model_json_schema(by_alias=True)


class GeminiProvider(QueryUnderstandingProvider):
    async def parse_raw(
        self,
        natural_language_query: str,
        *,
        language: str | None = None,
        context: Any = None,
    ) -> ProviderResponse:
        c = self.config
        if not c.api_key:
            raise ProviderError("GEMINI_API_KEY is missing")
        model = c.model if c.model.startswith("models/") else f"models/{c.model}"
        generation = {
            "temperature": c.temperature,
            "maxOutputTokens": c.max_tokens,
            "responseMimeType": "application/json",
        }
        if c.structured_output:
            generation["responseJsonSchema"] = _response_schema()
        generation.update(c.parameters)
        user_content = natural_language_query
        if context is not None:
            ctx_str = getattr(context, "format_prompt_context", lambda: "")()
            if ctx_str:
                user_content = f"{ctx_str}{natural_language_query}"
        body = {
            "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
            "contents": [{"role": "user", "parts": [{"text": user_content}]}],
            "generationConfig": generation,
        }

        base = (c.base_url or "https://generativelanguage.googleapis.com/v1beta").rstrip("/")
        # The key travels as a header rather than a query parameter so it
        # cannot be captured by URL logging on any hop.
        data = await post_json(
            f"{base}/{model}:generateContent",
            body,
            {"Content-Type": "application/json", "x-goog-api-key": c.api_key},
            c.timeout_seconds,
            phase=Phase.GEMINI,
        )
        try:
            raw = data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError) as exc:
            raise ProviderError("Gemini response contained no candidate text") from exc
        u = data.get("usageMetadata", {})
        return ProviderResponse(
            raw_response=raw,
            usage=TokenUsage(
                input_tokens=u.get("promptTokenCount"),
                output_tokens=u.get("candidatesTokenCount"),
                cached_tokens=u.get("cachedContentTokenCount"),
                total_tokens=u.get("totalTokenCount"),
            ),
            metadata={"finish_reason": data["candidates"][0].get("finishReason")},
        )
