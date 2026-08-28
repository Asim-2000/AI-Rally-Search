from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from pathlib import Path
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class TranscriptionOrigin(StrEnum):
    BASELINE = "baseline"
    STATIC_CONTEXT = "staticContext"
    DYNAMIC_BIASED = "dynamicBiased"


class SpeechTranscriptionContext(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    origin: TranscriptionOrigin = TranscriptionOrigin.BASELINE
    prompt: str | None = None
    keywords: list[str] = Field(default_factory=list)
    language_hints: list[str] = Field(default_factory=list, alias="languageHints")

    @property
    def has_bias(self) -> bool:
        return bool((self.prompt or "").strip() or self.keywords)


class TranscriptHypothesis(BaseModel):
    text: str
    confidence: float
    log_prob: float | None = Field(default=None, alias="logProb")


class SpokenWordTimestamp(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    word: str
    start_ms: int = Field(alias="startMs")
    end_ms: int = Field(alias="endMs")
    confidence: float | None = None

    @property
    def duration_ms(self) -> int:
        return max(0, min(1_000_000, self.end_ms - self.start_ms))


@dataclass
class SpokenAudioContext:
    bytes: bytes
    format: str = "m4a"
    sample_rate: int = 44_100
    channels: int = 1
    duration_ms: int = 0
    local_file_path: Path | None = None
    _is_disposed: bool = field(default=False, init=False, repr=False)

    @property
    def is_disposed(self) -> bool:
        return self._is_disposed

    @property
    def byte_length(self) -> int:
        return len(self.bytes)

    def dispose(self) -> None:
        if self._is_disposed:
            return
        self._is_disposed = True
        if self.local_file_path is not None:
            try:
                self.local_file_path.unlink(missing_ok=True)
            except OSError:
                pass


@dataclass
class SpeechTranscriptionResult:
    text: str
    language: str = "en"
    hypotheses: list[TranscriptHypothesis] = field(default_factory=list)
    words: list[SpokenWordTimestamp] = field(default_factory=list)
    audio_context: SpokenAudioContext | None = None
    duration_ms: int = 0
    confidence: float | None = None
    confidence_kind: str | None = None
    provider: str = "unknown"
    model: str = "unknown"
    latency_ms: float = 0
    metadata: dict[str, Any] = field(default_factory=dict)

    def effective_text(self, edited_transcript: str | None = None) -> str:
        edited = (edited_transcript or "").strip()
        return edited if edited else self.text.strip()

    def dispose_audio(self) -> None:
        if self.audio_context is not None:
            self.audio_context.dispose()
