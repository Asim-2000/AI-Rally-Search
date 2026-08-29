from __future__ import annotations

from pathlib import Path
from typing import Any

from .openai_stt import STTBenchmarkResult


class GeminiSTTAdapter:
    def __init__(
        self,
        api_key: str,
        model: str = "gemini-3.5-transcribe",
        base_url: str = "https://generativelanguage.googleapis.com/v1beta",
        timeout_seconds: float = 30.0,
    ) -> None:
        self.api_key = api_key
        self.model = model
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

    async def transcribe(
        self,
        case_id: str,
        audio_path: str | Path,
        *,
        language: str | None = None,
        prompt_hint: str | None = None,
    ) -> STTBenchmarkResult:
        if not self.api_key or not self.api_key.startswith("AIzaSy"):
            return STTBenchmarkResult(
                case_id=case_id,
                provider="gemini",
                model=self.model,
                audio_path=str(audio_path),
                transcript=None,
                latency_ms=0.0,
                error="Invalid or missing Google Gemini API key (must start with AIzaSy)",
            )
        return STTBenchmarkResult(
            case_id=case_id,
            provider="gemini",
            model=self.model,
            audio_path=str(audio_path),
            transcript=None,
            latency_ms=0.0,
            error="Gemini dedicated transcription endpoint requires valid Google cloud credentials",
        )
