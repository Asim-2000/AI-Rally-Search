from __future__ import annotations

import base64
import json
import time
from pathlib import Path
from typing import Any

import httpx

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
        p = Path(audio_path)
        if not self.api_key:
            return STTBenchmarkResult(
                case_id=case_id,
                provider="gemini",
                model=self.model,
                audio_path=str(audio_path),
                transcript=None,
                latency_ms=0.0,
                error="Missing Google Gemini API key",
            )
        if not p.exists():
            return STTBenchmarkResult(case_id, "gemini", self.model, str(audio_path), None, 0.0, f"Audio file not found: {audio_path}")
        mime = "audio/wav" if p.suffix.lower() == ".wav" else "audio/mpeg"
        instruction = "Transcribe this audio verbatim. Return only the transcript text, with no explanation."
        if language:
            instruction += f" The expected language code is {language}."
        if prompt_hint:
            instruction += f" Canonical vocabulary context: {prompt_hint}"
        body = {"contents": [{"role": "user", "parts": [
            {"text": instruction},
            {"inlineData": {"mimeType": mime, "data": base64.b64encode(p.read_bytes()).decode("ascii")}},
        ]}], "generationConfig": {"temperature": 0.0, "maxOutputTokens": 512}}
        started = time.perf_counter()
        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                res = await client.post(f"{self.base_url}/models/{self.model}:generateContent", params={"key": self.api_key}, json=body)
            latency = (time.perf_counter() - started) * 1000
            if res.status_code != 200:
                return STTBenchmarkResult(case_id, "gemini", self.model, str(audio_path), None, latency, f"HTTP {res.status_code}: {res.text[:200]}")
            payload = res.json()
            parts = (((payload.get("candidates") or [{}])[0].get("content") or {}).get("parts") or [])
            transcript = "".join(str(x.get("text") or "") for x in parts).strip()
            if not transcript:
                return STTBenchmarkResult(case_id, "gemini", self.model, str(audio_path), None, latency, "Empty transcript")
            return STTBenchmarkResult(case_id, "gemini", self.model, str(audio_path), transcript, latency, metadata={"usage": payload.get("usageMetadata") or {}})
        except Exception as exc:
            return STTBenchmarkResult(case_id, "gemini", self.model, str(audio_path), None, (time.perf_counter() - started) * 1000, f"Transcription error: {exc}")
