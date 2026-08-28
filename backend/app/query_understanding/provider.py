from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any

from .models import ProviderResponse


class ProviderError(RuntimeError):
    pass


class ProviderTimeout(ProviderError):
    pass


@dataclass(frozen=True)
class ProviderConfig:
    provider: str
    model: str
    api_key: str | None = None
    base_url: str | None = None
    temperature: float = 0.0
    max_tokens: int = 1024
    timeout_seconds: float = 30.0
    max_retries: int = 2
    structured_output: bool = True
    seed: int | None = None
    reasoning: str | None = None
    parameters: dict[str, Any] = field(default_factory=dict)


class QueryUnderstandingProvider(ABC):
    def __init__(self, config: ProviderConfig):
        self.config = config

    @abstractmethod
    async def parse_raw(self, natural_language_query: str, *, language: str | None = None) -> ProviderResponse:
        """Return raw provider output. Validation belongs to the service boundary."""
