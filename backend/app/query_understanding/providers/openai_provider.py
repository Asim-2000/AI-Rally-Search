from typing import Any

from ..models import ProviderResponse, TokenUsage
from ..prompt import SYSTEM_PROMPT
from ..provider import ProviderConfig, ProviderError, QueryUnderstandingProvider
from .http import post_json



class OpenAIProvider(QueryUnderstandingProvider):
    async def parse_raw(
        self,
        natural_language_query: str,
        *,
        language: str | None = None,
        context: Any = None,
    ) -> ProviderResponse:
        c = self.config
        if not c.api_key:
            raise ProviderError("OPENAI_API_KEY is missing")
        schema = _schema()
        user_content = natural_language_query
        if context is not None:
            ctx_str = getattr(context, "format_prompt_context", lambda: "")()
            if ctx_str:
                user_content = f"{natural_language_query}\n\n{ctx_str}"
        body = {"model": c.model, "messages": [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": user_content}], "max_completion_tokens": c.max_tokens}

        if c.structured_output:
            body["response_format"] = {"type": "json_schema", "json_schema": {"name": "rally_search_query", "strict": True, "schema": schema}}
        if not _is_reasoning_model(c.model):
            body["temperature"] = c.temperature
        if c.seed is not None:
            body["seed"] = c.seed
        body.update(c.parameters)
        data = await post_json(f"{(c.base_url or 'https://api.openai.com/v1').rstrip('/')}/chat/completions", body, {"Content-Type": "application/json", "Authorization": f"Bearer {c.api_key}"}, c.timeout_seconds)
        try:
            raw = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise ProviderError("OpenAI response contained no message content") from exc
        u = data.get("usage", {})
        details = u.get("completion_tokens_details") or {}
        prompt_details = u.get("prompt_tokens_details") or {}
        return ProviderResponse(raw_response=raw, usage=TokenUsage(input_tokens=u.get("prompt_tokens"), output_tokens=u.get("completion_tokens"), cached_tokens=prompt_details.get("cached_tokens"), reasoning_tokens=details.get("reasoning_tokens"), total_tokens=u.get("total_tokens")), metadata={"finish_reason": data["choices"][0].get("finish_reason"), "system_fingerprint": data.get("system_fingerprint")})


def _is_reasoning_model(model: str) -> bool:
    value = model.lower().split("/")[-1]
    return value.startswith(("o1", "o3", "o4", "gpt-5", "chatgpt-5")) or "reasoning" in value


def _schema() -> dict:
    from ...domain.search_query import SearchQuery
    schema = SearchQuery.model_json_schema(by_alias=True)
    schema["additionalProperties"] = False
    # OpenAI strict Structured Outputs requires every declared property to be
    # present. Optional semantics remain represented by nullable values, empty
    # arrays, and the canonical SearchQuery defaults.
    schema["required"] = list(schema.get("properties", {}))
    _strip_schema_defaults(schema)
    return schema


def _strip_schema_defaults(value) -> None:
    if isinstance(value, dict):
        value.pop("default", None)
        for child in value.values():
            _strip_schema_defaults(child)
    elif isinstance(value, list):
        for child in value:
            _strip_schema_defaults(child)
