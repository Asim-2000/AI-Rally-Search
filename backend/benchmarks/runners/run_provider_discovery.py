from __future__ import annotations

import asyncio
from benchmarks.providers.anthropic_qu import AnthropicQUAdapter
from benchmarks.providers.gemini_qu import GeminiQUAdapter
from benchmarks.providers.openai_qu import OpenAIQUAdapter
from benchmarks.providers.openai_stt import OpenAISTTAdapter
from benchmarks.runners.helpers import get_benchmark_api_keys


async def main() -> None:
    keys = get_benchmark_api_keys()
    print("Running provider discovery probe...\n")

    qu_probes = [
        ("OpenAI", "gpt-5.6-luna", OpenAIQUAdapter(api_key=keys["openai"], model="gpt-5.6-luna")),
        ("Anthropic", "claude-haiku-4-5", AnthropicQUAdapter(api_key=keys["claude"], model="claude-haiku-4-5")),
        ("Google Gemini", "gemini-3.5-flash-lite", GeminiQUAdapter(api_key=keys["gemini"], model="gemini-3.5-flash-lite")),
        ("Google Gemini", "gemini-3.7-flash", GeminiQUAdapter(api_key=keys["gemini"], model="gemini-3.7-flash")),
    ]

    print("--- Active Shortlist Provider Discovery Results ---")
    for provider, model_id, adapter in qu_probes:
        res = await adapter.parse_query(
            case_id="discovery_probe",
            query="Rallies in Ireland 2025",
        )
        if res.schema_valid and res.parsed_query is not None:
            print(f"[QU] {provider} - {model_id}: ✅ ACCESSIBLE (latency: {res.latency_ms:.1f}ms) ")
        else:
            print(f"[QU] {provider} - {model_id}: ❌ INACCESSIBLE (latency: {res.latency_ms:.1f}ms) {res.error}")

    stt_models = ["whisper-1", "gpt-4o-mini-transcribe", "gpt-transcribe"]
    for m in stt_models:
        adapter = OpenAISTTAdapter(api_key=keys["openai"], model=m)
        ok = await adapter.verify_access()
        status = "✅ ACCESSIBLE" if ok else "❌ INACCESSIBLE"
        print(f"[STT] OpenAI (STT) - {m}: {status} (latency: 0.0ms) ")


if __name__ == "__main__":
    asyncio.run(main())
