import asyncio
import json
import urllib.request
import os
import httpx

from backend.app.config import Settings
from backend.app.domain.search_query import SearchQuery, PersonRole
from backend.app.domain.search_intent import SearchIntent
from backend.app.query_understanding.prompt import SYSTEM_PROMPT as PY_SYSTEM_PROMPT
from backend.app.query_understanding.provider import ProviderConfig
from backend.app.query_understanding.providers.openai_provider import OpenAIProvider, _schema
from backend.app.query_understanding.service import QueryUnderstandingService
from backend.app.query_understanding.context import SearchContext

# Dart canonical system prompt from lib/services/llm/query_understanding_spec.dart
with open("lib/services/llm/query_understanding_spec.dart") as f:
    dart_spec = f.read()

# Extract Dart system prompt between """
start_idx = dart_spec.find("static const String systemPrompt = '''") + len("static const String systemPrompt = '''")
end_idx = dart_spec.find("''';", start_idx)
DART_SYSTEM_PROMPT = dart_spec[start_idx:end_idx].strip()

with open(".env") as f:
    env = dict(line.strip().split("=", 1) for line in f if "=" in line and not line.startswith("#"))

api_key = env.get("OPENAI_API_KEY")

queries = [
    "Rallies in Ireland",
    "Rallies in Germany",
    "Rallies in Latvia",
    "Rallies in Dublin",
    "Rallies in Aluksne",
    "Rallies in 2025",
    "Rallies in Ireland in 2025",
    "Show rallies where Max Freeman participated",
    "Show Max Freeman videos",
    "Who won Rally Aluksne?",
]

async def run():
    print("=== DART VS PYTHON QUERY UNDERSTANDING PARITY EVAL ===")
    
    config = ProviderConfig(
        provider="openai",
        model="gpt-4o-mini",
        api_key=api_key,
        temperature=0.0,
    )
    py_provider = OpenAIProvider(config)
    py_service = QueryUnderstandingService(py_provider)
    
    # Custom Dart-equivalent provider
    class DartOpenAIProvider(OpenAIProvider):
        async def parse_raw(self, natural_language_query, *, language=None, context=None):
            schema = _schema()
            user_content = ""
            if context is not None:
                ctx_str = getattr(context, "format_prompt_context", lambda: "")()
                if ctx_str:
                    user_content = f"{ctx_str}{natural_language_query}"
                else:
                    user_content = natural_language_query
            else:
                user_content = natural_language_query
            
            body = {
                "model": "gpt-4o-mini",
                "messages": [
                    {"role": "system", "content": DART_SYSTEM_PROMPT},
                    {"role": "user", "content": user_content},
                ],
                "response_format": {"type": "json_schema", "json_schema": {"name": "rally_search_query", "strict": True, "schema": schema}},
                "temperature": 0.0,
            }
            from backend.app.query_understanding.providers.http import post_json
            data = await post_json(
                "https://api.openai.com/v1/chat/completions",
                body,
                {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
                30.0,
            )
            raw = data["choices"][0]["message"]["content"]
            from backend.app.query_understanding.models import ProviderResponse
            return ProviderResponse(raw_response=raw)
            
    dart_service = QueryUnderstandingService(DartOpenAIProvider(config))
    
    for q in queries:
        print(f"\n--- QUERY: '{q}' ---")
        
        # 1. Dart style (with SearchContext current_year=2026)
        ctx = SearchContext(current_year=2026, locale="en-US", language_code="en")
        dart_res = await dart_service.parse(q, context=ctx)
        
        # 2. Python style (with SearchContext current_year=2026)
        py_res = await py_service.parse(q, context=ctx)
        
        print(f"DART:   intent={dart_res.query.intent.value if dart_res.query else None}, "
              f"countries={dart_res.query.countries if dart_res.query else []}, "
              f"cities={dart_res.query.cities if dart_res.query else []}, "
              f"years={dart_res.query.years if dart_res.query else []}, "
              f"rallyNames={dart_res.query.rally_names if dart_res.query else []}, "
              f"driverNames={dart_res.query.driver_names if dart_res.query else []}, "
              f"personRole={dart_res.query.person_role.value if dart_res.query else None}, "
              f"clarification={dart_res.requires_clarification}")
              
        print(f"PYTHON: intent={py_res.query.intent.value if py_res.query else None}, "
              f"countries={py_res.query.countries if py_res.query else []}, "
              f"cities={py_res.query.cities if py_res.query else []}, "
              f"years={py_res.query.years if py_res.query else []}, "
              f"rallyNames={py_res.query.rally_names if py_res.query else []}, "
              f"driverNames={py_res.query.driver_names if py_res.query else []}, "
              f"personRole={py_res.query.person_role.value if py_res.query else None}, "
              f"clarification={py_res.requires_clarification}")

if __name__ == "__main__":
    asyncio.run(run())
