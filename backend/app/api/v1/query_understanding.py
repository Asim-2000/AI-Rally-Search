from functools import lru_cache

from fastapi import APIRouter, Depends

from ...config import Settings, get_settings
from ...query_understanding.models import QueryUnderstandingRequest, QueryUnderstandingResult
from ...query_understanding.provider import ProviderConfig
from ...query_understanding.providers import AnthropicProvider, GeminiProvider, MockProvider, OpenAIProvider
from ...query_understanding.service import QueryUnderstandingService

router = APIRouter(prefix="/v1")


def build_service(settings: Settings) -> QueryUnderstandingService:
    name = settings.query_understanding_provider.lower()
    secrets = {
        "openai": settings.openai_api_key,
        "gemini": settings.gemini_api_key,
        "google": settings.gemini_api_key,
        "anthropic": settings.anthropic_api_key,
    }
    urls = {"openai": settings.openai_base_url, "gemini": settings.gemini_base_url, "google": settings.gemini_base_url, "anthropic": settings.anthropic_base_url}
    config = ProviderConfig(
        provider=name, model=settings.query_understanding_model,
        api_key=secrets[name].get_secret_value() if name in secrets else None,
        base_url=urls.get(name), temperature=settings.query_understanding_temperature,
        timeout_seconds=settings.query_understanding_timeout_seconds,
        max_retries=settings.query_understanding_max_retries,
    )
    provider_types = {"openai": OpenAIProvider, "gemini": GeminiProvider, "google": GeminiProvider, "anthropic": AnthropicProvider, "mock": MockProvider}
    if name not in provider_types:
        raise ValueError(f"unsupported query understanding provider: {name}")
    return QueryUnderstandingService(provider_types[name](config))


def get_query_understanding_service(settings: Settings = Depends(get_settings)) -> QueryUnderstandingService:
    return build_service(settings)


@router.post("/query-understanding", response_model=QueryUnderstandingResult, response_model_by_alias=True)
async def understand(request: QueryUnderstandingRequest, service: QueryUnderstandingService = Depends(get_query_understanding_service)) -> QueryUnderstandingResult:
    return await service.parse(request.query, language=request.language)
