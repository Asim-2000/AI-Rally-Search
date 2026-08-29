import pytest
from app.config import get_settings
from app.domain.conversation_session import SearchConversationSession
from app.domain.referent_context import ResultReferentContext
from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery
from app.query_understanding.context import SearchContext
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.openai_provider import OpenAIProvider
from app.query_understanding.service import QueryUnderstandingService

HAS_OPENAI_KEY = bool(get_settings().openai_api_key.get_secret_value())


@pytest.mark.live_openai
@pytest.mark.skipif(not HAS_OPENAI_KEY, reason="OPENAI_API_KEY not configured")
async def test_live_openai_multi_turn_coreference():
    settings = get_settings()
    # PY-3.1's validated model is the explicit fallback when local settings use
    # the hermetic mock provider. Otherwise honor the configured live model.
    model = "gpt-4.1-mini" if settings.query_understanding_model.startswith("mock") else settings.query_understanding_model
    config = ProviderConfig(
        provider="openai",
        model=model,
        api_key=settings.openai_api_key.get_secret_value(),
        base_url=settings.openai_base_url,
        temperature=0.0,
        timeout_seconds=20.0,
    )

    provider = OpenAIProvider(config)
    service = QueryUnderstandingService(provider)

    # Turn 1: Initial query
    res1 = await service.parse("Show Donegal Rally 2025")
    assert res1.succeeded is True
    assert res1.query.intent in (SearchIntent.SEARCH_RALLIES, SearchIntent.GET_RALLY_RESULTS)

    # Turn 2: Relative pronoun with context
    search_context = SearchContext(
        current_year=2026,
        active_rally="Donegal International Rally 2025",
        referents=ResultReferentContext(
            active_rally="Donegal International Rally 2025",
            active_rallies=["Donegal International Rally 2025"],
        ),
        previous_query=res1.query,
    )
    res2 = await service.parse("Who won it?", context=search_context)
    assert res2.succeeded is True
    assert res2.query.intent == SearchIntent.GET_RALLY_RESULTS
    assert "Donegal" in (res2.query.target_rally_name or "")
