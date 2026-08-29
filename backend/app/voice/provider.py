from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass

from .models import SpeechTranscriptionContext, SpeechTranscriptionResult, SpokenAudioContext


class SpeechProviderError(RuntimeError):
    pass


class SpeechProviderTimeout(SpeechProviderError):
    pass


@dataclass(frozen=True)
class SpeechProviderConfig:
    provider: str
    model: str
    api_key: str | None = None
    base_url: str = "https://api.openai.com/v1"
    timeout_seconds: float = 30
    dynamic_top3_enabled: bool = False
    preprocessing_strategy: str = "raw"


class SpeechToTextProvider(ABC):
    def __init__(self, config: SpeechProviderConfig):
        self.config = config

    @abstractmethod
    async def transcribe(
        self,
        audio: SpokenAudioContext,
        *,
        filename: str,
        language: str,
        context: SpeechTranscriptionContext | None = None,
    ) -> SpeechTranscriptionResult:
        raise NotImplementedError
