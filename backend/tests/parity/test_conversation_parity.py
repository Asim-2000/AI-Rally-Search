import hashlib
import json
from pathlib import Path
import pytest

from app.domain.conversation_session import SearchConversationSession
from app.domain.referent_context import ResultReferentContext
from app.domain.search_intent import SearchIntent
from app.domain.search_query import MatchMode, PersonRole, SearchQuery
from app.query_understanding.context import SearchContext
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.mock_provider import MockProvider
from app.query_understanding.service import QueryUnderstandingService

FIXTURE_PATH = Path(__file__).parent.parent.parent / "benchmarks" / "conversation" / "fixtures" / "conversation_parity_fixtures_v1.json"


def load_fixtures() -> dict:
    with open(FIXTURE_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


@pytest.fixture(scope="module")
def fixture_data():
    return load_fixtures()


@pytest.mark.parity
def test_fixture_integrity(fixture_data):
    content = FIXTURE_PATH.read_bytes()
    sha256_hex = hashlib.sha256(content).hexdigest()
    assert len(sha256_hex) == 64
    assert len(fixture_data["cases"]) >= 12


@pytest.mark.parity
@pytest.mark.parametrize(
    "case",
    load_fixtures()["cases"],
    ids=lambda c: c["id"],
)
async def test_conversational_parity_case(case):
    ctx_data = case.get("context", {})
    prev_query = None
    if "previous_query" in ctx_data:
        prev_query = SearchQuery.model_validate(ctx_data["previous_query"])

    referents = ResultReferentContext(
        active_rally=ctx_data.get("active_rally"),
        active_driver=ctx_data.get("active_driver"),
        last_winner=ctx_data.get("last_winner"),
        active_drivers=ctx_data.get("active_drivers", []),
        active_rallies=ctx_data.get("active_rallies", []),
    )

    search_context = SearchContext(
        referents=referents,
        previous_query=prev_query,
        active_rally=ctx_data.get("active_rally"),
        active_driver=ctx_data.get("active_driver"),
    )

    provider = MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))
    service = QueryUnderstandingService(provider)

    result = await service.parse(case["query"], context=search_context)

    if case.get("expected_clarification"):
        assert result.requires_clarification is True
        expected_substr = case.get("expected_clarification_question_contains")
        if expected_substr:
            assert expected_substr.lower() in (result.clarification_question or "").lower()
        return

    assert result.succeeded is True
    assert result.query is not None
    q = result.query

    exp = case["expected_query"]
    if "intent" in exp:
        assert q.intent.value == exp["intent"]
    if "driverNames" in exp:
        assert q.driver_names == exp["driverNames"]
    if "rallyNames" in exp:
        assert q.rally_names == exp["rallyNames"]
    if "actionTypes" in exp:
        assert q.action_types == exp["actionTypes"]
    if "years" in exp:
        assert q.years == exp["years"]
    if "personRole" in exp:
        assert q.person_role.value == exp["personRole"]
    if "driverMatchMode" in exp:
        assert q.driver_match_mode.value == exp["driverMatchMode"]
