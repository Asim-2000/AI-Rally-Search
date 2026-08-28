from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from ..domain.search_query import SearchQuery


class FailureKind(StrEnum):
    PROVIDER_ERROR = "PROVIDER_ERROR"
    TIMEOUT = "TIMEOUT"
    INVALID_JSON = "INVALID_JSON"
    SCHEMA_VALIDATION_FAILURE = "SCHEMA_VALIDATION_FAILURE"
    SEMANTIC_VALIDATION_FAILURE = "SEMANTIC_VALIDATION_FAILURE"


class TokenUsage(BaseModel):
    input_tokens: int | None = None
    output_tokens: int | None = None
    cached_tokens: int | None = None
    reasoning_tokens: int | None = None
    total_tokens: int | None = None


class ProviderResponse(BaseModel):
    raw_response: str
    usage: TokenUsage = Field(default_factory=TokenUsage)
    metadata: dict[str, Any] = Field(default_factory=dict)


class QueryUnderstandingRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    query: str = Field(min_length=1)
    language: str | None = None


class QueryUnderstandingResult(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)
    query: SearchQuery | None = None

    provider: str
    model: str
    prompt_version: str
    schema_version: str
    few_shot_version: str
    raw_response: str | None = None
    requires_clarification: bool = Field(default=False, alias="requiresClarification")
    clarification_question: str | None = Field(default=None, alias="clarificationQuestion")
    failure_kind: FailureKind | None = None
    error: str | None = None
    attempts: int = 1
    provider_retries: int = 0
    schema_retries: int = 0
    provider_latency_ms: float = 0
    validation_latency_ms: float = 0
    total_latency_ms: float = 0
    usage: TokenUsage = Field(default_factory=TokenUsage)
    metadata: dict[str, Any] = Field(default_factory=dict)

    @property
    def succeeded(self) -> bool:
        return self.query is not None and self.failure_kind is None and not self.requires_clarification

