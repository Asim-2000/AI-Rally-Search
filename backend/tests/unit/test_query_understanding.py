import asyncio
import json

import pytest
from fastapi.testclient import TestClient

from app.query_understanding.benchmark import _parser_metrics, summarize
from app.query_understanding.models import FailureKind, ProviderResponse
from app.query_understanding.provider import ProviderConfig, ProviderError, QueryUnderstandingProvider
from app.query_understanding.providers.mock_provider import MockProvider
from app.query_understanding.providers.openai_provider import _schema as openai_schema
from app.query_understanding.service import QueryUnderstandingService
from app.query_understanding.validator import OutputValidationError, validate_provider_output
from app.main import app


def payload(**updates):
    value = {"intent": "SEARCH_RALLIES", "countries": ["Latvia", "Lithuania"], "years": [2024, 2025], "personRole": "ANY"}
    value.update(updates)
    return json.dumps(value)


@pytest.mark.unit
@pytest.mark.query_understanding
def test_strict_validation_and_multivalue_preservation():
    query = validate_provider_output(payload())
    assert query.countries == ["Latvia", "Lithuania"] and query.years == [2024, 2025]


@pytest.mark.unit
@pytest.mark.provider_contract
def test_openai_strict_schema_requires_every_property():
    schema = openai_schema()
    assert schema["additionalProperties"] is False
    assert set(schema["required"]) == set(schema["properties"])
    assert '"default"' not in json.dumps(schema)


@pytest.mark.unit
@pytest.mark.query_understanding
@pytest.mark.parametrize(("raw", "kind"), [("not json", FailureKind.INVALID_JSON), (payload(surprise=True), FailureKind.SCHEMA_VALIDATION_FAILURE), (payload(driverIds=["invented"]), FailureKind.SEMANTIC_VALIDATION_FAILURE), (payload(personRole="NAVIGATOR"), FailureKind.SCHEMA_VALIDATION_FAILURE), (payload(intent="MADE_UP"), FailureKind.SCHEMA_VALIDATION_FAILURE), (payload(actionTypes=["wheelie"]), FailureKind.SEMANTIC_VALIDATION_FAILURE), (payload(yearFrom=2025, yearTo=2022), FailureKind.SCHEMA_VALIDATION_FAILURE)])
def test_validation_failure_categories(raw, kind):
    with pytest.raises(OutputValidationError) as error: validate_provider_output(raw)
    assert error.value.kind == kind


class SequenceProvider(QueryUnderstandingProvider):
    def __init__(self, responses):
        super().__init__(ProviderConfig(provider="test", model="test", max_retries=1, timeout_seconds=.02))
        self.responses = iter(responses)

    async def parse_raw(self, natural_language_query, *, language=None):
        value = next(self.responses)
        if isinstance(value, Exception): raise value
        if value == "sleep": await asyncio.sleep(.1)
        return ProviderResponse(raw_response=value)


@pytest.mark.unit
@pytest.mark.query_understanding
async def test_schema_retry_is_visible():
    result = await QueryUnderstandingService(SequenceProvider(["bad", payload()])).parse("query")
    assert result.succeeded and result.schema_retries == 1 and result.attempts == 2


@pytest.mark.unit
@pytest.mark.query_understanding
async def test_provider_retry_and_timeout_mapping():
    retried = await QueryUnderstandingService(SequenceProvider([ProviderError("temporary"), payload()])).parse("query")
    assert retried.succeeded and retried.provider_retries == 1
    timed_out = await QueryUnderstandingService(SequenceProvider(["sleep", "sleep"])).parse("query")
    assert timed_out.failure_kind == FailureKind.TIMEOUT and timed_out.provider_retries == 1


@pytest.mark.unit
@pytest.mark.query_understanding
async def test_mock_provider_contract():
    result = await QueryUnderstandingService(MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))).parse("Show jumps by Josh Moffett in Ireland in 2025")
    assert result.query.intent.value == "SEARCH_VIDEO_ACTIONS"
    assert result.query.driver_names == ["Josh Moffett"] and result.query.driver_ids == []


@pytest.mark.unit
@pytest.mark.query_understanding
def test_evaluator_metrics_and_failure_aggregation():
    metric = _parser_metrics({"intent": "SEARCH_RALLIES", "countries": ["Latvia", "Lithuania"]}, {"intent": "SEARCH_RALLIES", "countries": ["Latvia"], "limit": 20})
    assert metric["fieldCounts"] == {"tp": 1, "fp": 0, "fn": 1}
    record = {"parserMetrics": metric, "validation": {"succeeded": True}, "canonicalResolution": None, "databaseResult": None, "latencyMs": {"total": 2}, "providerRetries": 0, "schemaRetries": 0, "failureCategories": ["MULTIVALUE_LOSS"], "estimatedCost": None}
    assert summarize([record])["failureCategories"] == {"MULTIVALUE_LOSS": 1}


@pytest.mark.unit
@pytest.mark.query_understanding
def test_experimental_api_does_not_change_structured_search():
    response = TestClient(app).post("/v1/query-understanding", json={"query": "Show rallies in Ireland"})
    assert response.status_code == 200
    assert response.json()["query"]["intent"] == "SEARCH_RALLIES"
