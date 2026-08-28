from __future__ import annotations

import asyncio
import math
import time
from typing import Any

import httpx

from .models import (
    SpeechTranscriptionContext,
    SpeechTranscriptionResult,
    SpokenAudioContext,
    SpokenWordTimestamp,
    TranscriptionOrigin,
)
from .provider import SpeechProviderError, SpeechProviderTimeout, SpeechToTextProvider


class OpenAISpeechToTextProvider(SpeechToTextProvider):
    async def transcribe(
        self,
        audio: SpokenAudioContext,
        *,
        filename: str,
        language: str,
        context: SpeechTranscriptionContext | None = None,
    ) -> SpeechTranscriptionResult:
        if not audio.bytes:
            raise SpeechProviderError("audio is empty")
        if context is not None and context.origin != TranscriptionOrigin.BASELINE:
            raise SpeechProviderError("biased transcription passes are disabled")
        if context is not None and context.has_bias:
            raise SpeechProviderError("static STT context is disabled")

        started = time.perf_counter()
        data: dict[str, str] = {"model": self.config.model}
        if language.strip():
            data["language"] = language.strip().lower()
        if self.config.model == "whisper-1":
            data["response_format"] = "verbose_json"
            data["timestamp_granularities[]"] = "word"
        else:
            data["response_format"] = "json"
        headers = {"Authorization": f"Bearer {self.config.api_key}"}
        url = f"{self.config.base_url.rstrip('/')}/audio/transcriptions"
        try:
            def send() -> httpx.Response:
                with httpx.Client(timeout=self.config.timeout_seconds) as client:
                    return client.post(
                        url,
                        headers=headers,
                        data=data,
                        files={"file": (filename, audio.bytes, _content_type(filename))},
                    )

            response = await asyncio.wait_for(
                asyncio.to_thread(send),
                timeout=self.config.timeout_seconds + 1,
            )
        except (httpx.TimeoutException, asyncio.TimeoutError) as exc:
            raise SpeechProviderTimeout("speech transcription timed out") from exc
        except httpx.HTTPError as exc:
            raise SpeechProviderError(f"speech provider transport error: {type(exc).__name__}") from exc
        if response.status_code < 200 or response.status_code >= 300:
            raise SpeechProviderError(f"speech provider HTTP {response.status_code}")
        try:
            payload: dict[str, Any] = response.json()
        except ValueError as exc:
            raise SpeechProviderError("speech provider returned invalid JSON") from exc
        text = str(payload.get("text") or "").strip()
        if not text:
            raise SpeechProviderError("no intelligible speech detected")

        words = []
        for value in payload.get("words") or []:
            if not isinstance(value, dict) or not str(value.get("word") or "").strip():
                continue
            words.append(SpokenWordTimestamp(
                word=str(value["word"]),
                startMs=int(float(value.get("start") or 0) * 1000),
                endMs=int(float(value.get("end") or value.get("start") or 0) * 1000),
                confidence=float(value["confidence"]) if value.get("confidence") is not None else None,
            ))

        log_probs = [
            float(segment["avg_logprob"])
            for segment in payload.get("segments") or []
            if isinstance(segment, dict) and isinstance(segment.get("avg_logprob"), (int, float))
        ]
        acoustic_score = math.exp(sum(log_probs) / len(log_probs)) if log_probs else None
        return SpeechTranscriptionResult(
            text=text,
            language=str(payload.get("language") or language),
            words=words,
            audio_context=audio,
            duration_ms=int(float(payload.get("duration") or 0) * 1000) or audio.duration_ms,
            confidence=min(1.0, max(0.0, acoustic_score)) if acoustic_score is not None else None,
            confidence_kind="exp_avg_logprob_uncalibrated" if acoustic_score is not None else None,
            provider="openai",
            model=self.config.model,
            latency_ms=(time.perf_counter() - started) * 1000,
            metadata={"nbestAvailable": False, "biasedSecondPass": False},
        )


def _content_type(filename: str) -> str:
    lower = filename.lower()
    if lower.endswith(".wav"):
        return "audio/wav"
    if lower.endswith(".mp3"):
        return "audio/mpeg"
    return "audio/mp4"
