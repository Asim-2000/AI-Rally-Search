from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncConnection

from ...config import Settings, get_settings
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
from ...services.conversational_search_service import ConversationalSearchResult, ConversationalSearchService

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


def _build_query_service(settings: Settings) -> QueryUnderstandingService:
    name = settings.query_understanding_provider.lower()
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
    config = ProviderConfig(
        provider=name,
        model=settings.query_understanding_model,
        api_key=secrets[name].get_secret_value() if name in secrets and secrets[name] else None,
        base_url=urls.get(name),
        temperature=settings.query_understanding_temperature,
        timeout_seconds=settings.query_understanding_timeout_seconds,
        max_retries=settings.query_understanding_max_retries,
    )
    provider_types = {
        "openai": OpenAIProvider,
        "gemini": GeminiProvider,
        "google": GeminiProvider,
        "anthropic": AnthropicProvider,
        "mock": MockProvider,
    }
    if name not in provider_types:
        raise ValueError(f"unsupported query understanding provider: {name}")
    return QueryUnderstandingService(provider_types[name](config))


async def get_conversational_service(
    connection: AsyncConnection = Depends(get_connection),
    settings: Settings = Depends(get_settings),
) -> ConversationalSearchService:
    query_parser = _build_query_service(settings)
    source = MySqlEntitySearchDataSource(connection=connection)
    entities = await source.load_entities()
    search_service = InMemoryEntitySearchService.from_entities(entities)
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
) -> ConversationSearchResponse:
    updated_session, result = await service.search(
        request.query,
        session=request.session,
        language=request.language,
    )
    return ConversationSearchResponse(
        session=updated_session,
        result=result,
        request_id=request.request_id,
    )
