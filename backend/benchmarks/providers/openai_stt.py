from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import httpx


@dataclass
class STTBenchmarkResult:
    case_id: str
    provider: str
    model: str
    audio_path: str
    transcript: str | None
    latency_ms: float
    error: str | None = None
    metadata: dict[str, Any] = None


class OpenAISTTAdapter:
    def __init__(
        self,
        api_key: str,
        model: str = "whisper-1",
        base_url: str = "https://api.openai.com/v1",
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
        p = Path(audio_path)
        if not p.exists():
            return STTBenchmarkResult(
                case_id=case_id,
                provider="openai",
                model=self.model,
                audio_path=str(audio_path),
                transcript=None,
                latency_ms=0.0,
                error=f"Audio file not found: {audio_path}",
            )

        data: dict[str, Any] = {"model": self.model, "response_format": "json"}
        if language:
            data["language"] = language
        if prompt_hint:
            data["prompt"] = prompt_hint

        headers = {"Authorization": f"Bearer {self.api_key}"}
        url = f"{self.base_url}/audio/transcriptions"

        def _send() -> httpx.Response:
            with open(p, "rb") as f:
                with httpx.Client(timeout=self.timeout_seconds) as client:
                    return client.post(
                        url,
                        headers=headers,
                        data=data,
                        files={"file": (p.name, f.read(), "audio/mpeg" if p.suffix == ".mp3" else "audio/wav")},
                    )

        started = time.perf_counter()
        try:
            res = await asyncio.to_thread(_send)
            latency_ms = (time.perf_counter() - started) * 1000.0
            if res.status_code != 200:
                return STTBenchmarkResult(
                    case_id=case_id,
                    provider="openai",
                    model=self.model,
                    audio_path=str(audio_path),
                    transcript=None,
                    latency_ms=latency_ms,
                    error=f"HTTP {res.status_code}: {res.text[:200]}",
                )
            payload = res.json()
            return STTBenchmarkResult(
                case_id=case_id,
                provider="openai",
                model=self.model,
                audio_path=str(audio_path),
                transcript=payload.get("text", "").strip(),
                latency_ms=latency_ms,
            )
        except Exception as exc:
            latency_ms = (time.perf_counter() - started) * 1000.0
            return STTBenchmarkResult(
                case_id=case_id,
                provider="openai",
                model=self.model,
                audio_path=str(audio_path),
                transcript=None,
                latency_ms=latency_ms,
                error=f"Transcription error: {exc}",
            )
