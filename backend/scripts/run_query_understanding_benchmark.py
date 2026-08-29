import argparse
import asyncio
import json
import os
from pathlib import Path

from app.config import get_settings
from app.query_understanding.benchmark import BenchmarkRunner, Pricing, markdown_report
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers import AnthropicProvider, GeminiProvider, MockProvider, OpenAIProvider
from app.query_understanding.service import QueryUnderstandingService

PROVIDERS = {"openai": (OpenAIProvider, "OPENAI_API_KEY", "OPENAI_BASE_URL"), "gemini": (GeminiProvider, "GEMINI_API_KEY", "GEMINI_BASE_URL"), "google": (GeminiProvider, "GEMINI_API_KEY", "GEMINI_BASE_URL"), "anthropic": (AnthropicProvider, "ANTHROPIC_API_KEY", "ANTHROPIC_BASE_URL"), "mock": (MockProvider, None, None)}


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, default=Path("benchmarks/query_understanding/fixtures/golden_176_v1.json"))
    parser.add_argument("--results", type=Path, default=Path("benchmarks/query_understanding/results"))
    parser.add_argument("--run-version", default="BASELINE_V1")
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    pricing_path = Path(config.get("pricing", "benchmarks/query_understanding/pricing_v1.json"))
    pricing = json.loads(pricing_path.read_text()).get("models", {}) if pricing_path.exists() else {}
    settings = get_settings()
    settings_keys = {
        "OPENAI_API_KEY": settings.openai_api_key.get_secret_value(),
        "GEMINI_API_KEY": settings.gemini_api_key.get_secret_value(),
        "ANTHROPIC_API_KEY": settings.anthropic_api_key.get_secret_value(),
    }
    settings_urls = {
        "OPENAI_BASE_URL": settings.openai_base_url,
        "GEMINI_BASE_URL": settings.gemini_base_url,
        "ANTHROPIC_BASE_URL": settings.anthropic_base_url,
    }
    args.results.mkdir(parents=True, exist_ok=True)
    for item in config["models"]:
        name = item["provider"].lower(); cls, key_env, url_env = PROVIDERS[name]
        api_key = (os.getenv(key_env) or settings_keys.get(key_env)) if key_env else None
        base_url = item.get("baseUrl") or ((os.getenv(url_env) or settings_urls.get(url_env)) if url_env else None)
        pc = ProviderConfig(provider=name, model=item["model"], api_key=api_key, base_url=base_url, temperature=item.get("temperature", 0), max_tokens=item.get("maxTokens", 1024), timeout_seconds=item.get("timeoutSeconds", 30), max_retries=item.get("maxRetries", 2), structured_output=item.get("structuredOutput", True), seed=item.get("seed"), reasoning=item.get("reasoning"), parameters=item.get("parameters", {}))
        p = pricing.get(item["model"]); price = Pricing(**p) if p else None
        report = await BenchmarkRunner(QueryUnderstandingService(cls(pc)), pricing=price, run_version=args.run_version).run(args.fixture)
        stem = f"{args.run_version}_{name}_{item['model'].replace('/', '_')}"
        (args.results / f"{stem}.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        (args.results / f"{stem}.md").write_text(markdown_report(report))
        with (args.results / f"{stem}.jsonl").open("w") as stream:
            for record in report["records"]: stream.write(json.dumps(record, ensure_ascii=False) + "\n")


if __name__ == "__main__": asyncio.run(main())
