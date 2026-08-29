from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class ProviderUsage:
    input_tokens: int | None = None
    output_tokens: int | None = None
    cached_tokens: int | None = None
    reasoning_tokens: int | None = None
    total_tokens: int | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "input_tokens": self.input_tokens,
            "output_tokens": self.output_tokens,
            "cached_tokens": self.cached_tokens,
            "reasoning_tokens": self.reasoning_tokens,
            "total_tokens": self.total_tokens,
        }


@dataclass
class RawBenchmarkResponse:
    case_id: str
    provider: str
    model: str
    raw_response: str | None
    parsed_query: dict[str, Any] | None
    schema_valid: bool
    latency_ms: float
    usage: ProviderUsage = field(default_factory=ProviderUsage)
    error: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)
