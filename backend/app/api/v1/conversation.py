from functools import lru_cache

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncConnection

from ...config import Settings, get_settings
from ...observability import Phase, current_timings
from ...db.engine import get_connection
from ...domain.conversation_session import SearchConversationSession
from ...entity_search.adapter import EntitySearchLookupAdapter
from ...entity_search.data_source import MySqlEntitySearchDataSource
from ...entity_search.resolver import DatabaseEntityResolver
from ...entity_search.service import InMemoryEntitySearchService
from ...query_understanding.provider import ProviderConfig
from ...query_understanding.providers import AnthropicProvider, GeminiProvider, MockProvider, OpenAIProvider
from ...query_understanding.service import QueryUnderstandingService
from ...repositories.search_repository import SearchRepository
from ...services.conversational_search_service import (
    ConversationalSearchResult,
    ConversationalSearchService,
    record_result_attributes,
)

router = APIRouter(prefix="/v1/conversation")


class ConversationSearchRequest(BaseModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    query: str = Field(min_length=1)
    session: SearchConversationSession = Field(default_factory=SearchConversationSession)
    language: str | None = None
    request_id: int | None = Field(default=None, alias="requestId")


class ConversationSearchResponse(BaseModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    session: SearchConversationSession
    result: ConversationalSearchResult
    request_id: int | None = Field(default=None, alias="requestId")
    trace_id: str | None = Field(default=None, alias="traceId")


@lru_cache(maxsize=4)
def _cached_query_service(
    provider: str,
    model: str,
    api_key: str | None,
    base_url: str | None,
    temperature: float,
    timeout_seconds: float,
    max_retries: int,
    provider_type: type,
) -> QueryUnderstandingService:
    config = ProviderConfig(
        provider=provider,
        model=model,
        api_key=api_key,
        base_url=base_url,
        temperature=temperature,
        timeout_seconds=timeout_seconds,
        max_retries=max_retries,
    )
    return QueryUnderstandingService(provider_type(config))


def _build_query_service(settings: Settings) -> QueryUnderstandingService:
    name = settings.query_understanding_provider.lower()

    provider_types = {
        "openai": OpenAIProvider,
        "gemini": GeminiProvider,
        "google": GeminiProvider,
        "anthropic": AnthropicProvider,
        "mock": MockProvider,
    }
    if name not in provider_types:
        raise ValueError(f"unsupported query understanding provider: {name!r}")

    # The mock parser must never activate silently in production. It is only
    # allowed when explicitly opted in via ALLOW_MOCK_QUERY_UNDERSTANDING.
    if name == "mock" and not settings.allow_mock_query_understanding:
        raise ValueError(
            "Query understanding provider is 'mock', which is not permitted in "
            "production. Set QUERY_UNDERSTANDING_PROVIDER to a real provider "
            "(e.g. 'gemini'), or set ALLOW_MOCK_QUERY_UNDERSTANDING=true for tests."
        )

    secrets = {
        "openai": settings.openai_api_key,
        "gemini": settings.gemini_api_key,
        "google": settings.gemini_api_key,
        "anthropic": settings.anthropic_api_key,
    }
    urls = {
        "openai": settings.openai_base_url,
        "gemini": settings.gemini_base_url,
        "google": settings.gemini_base_url,
        "anthropic": settings.anthropic_base_url,
    }

    api_key = None
    if name in secrets:
        secret = secrets[name]
        api_key = secret.get_secret_value() if secret else None
        # Fail fast on a real provider that has no API key, rather than
        # surfacing an opaque error at the first request.
        if not api_key:
            env_var = "GEMINI_API_KEY" if name in ("gemini", "google") else f"{name.upper()}_API_KEY"
            raise ValueError(
                f"Query understanding provider is {name!r} but {env_var} is "
                "missing. Provide the API key or change the provider."
            )

    # Validation above runs on every call and still fails fast; only the
    # construction of the (stateless) service and provider is memoised, so
    # each request no longer rebuilds them.
    return _cached_query_service(
        name,
        settings.query_understanding_model,
        api_key,
        urls.get(name),
        settings.query_understanding_temperature,
        settings.query_understanding_timeout_seconds,
        settings.query_understanding_max_retries,
        provider_types[name],
    )


from ...entity_search.warmup import (
    get_shared_entity_search_service,
    reset_shared_entity_search_service,
)


async def get_conversational_service(
    connection: AsyncConnection = Depends(get_connection),
    settings: Settings = Depends(get_settings),
) -> ConversationalSearchService:
    query_parser = _build_query_service(settings)
    search_service = await get_shared_entity_search_service(connection)
    adapter = EntitySearchLookupAdapter(search_service=search_service)
    entity_resolver = DatabaseEntityResolver(repository=adapter)
    search_repo = SearchRepository(connection)
    return ConversationalSearchService(
        query_parser=query_parser,
        entity_resolver=entity_resolver,
        repository=search_repo,
    )



@router.post("/search", response_model=ConversationSearchResponse, response_model_by_alias=True)
async def search_conversation(
    request: ConversationSearchRequest,
    service: ConversationalSearchService = Depends(get_conversational_service),
    settings: Settings = Depends(get_settings),
) -> ConversationSearchResponse:
    timings = current_timings()
    if timings is not None:
        # Everything before the handler body — dependency resolution, which is
        # where the DB connection is checked out and the entity index awaited.
        timings.add(
            Phase.DEPENDENCIES,
            max(0.0, timings.total_ms - sum(timings.phases.values())),
        )
    updated_session, result = await service.search(
        request.query,
        session=request.session,
        language=request.language,
        expose_timings=settings.expose_debug_timings,
    )
    if timings is not None:
        record_result_attributes(timings, result)
        timings.mark_handler_complete()
    return ConversationSearchResponse(
        session=updated_session,
        result=result,
        request_id=request.request_id,
        trace_id=result.request_id,
    )
