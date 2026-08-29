from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

from ..domain.conversation_session import SearchConversationSession
from ..services.conversational_search_service import ConversationalSearchResult, ConversationalSearchService
from .models import SpeechTranscriptionContext, SpeechTranscriptionResult, SpokenAudioContext
from .preprocessing import NoOpAudioPreprocessor
from .provider import SpeechToTextProvider


@dataclass
class VoiceSearchOutcome:
    session: SearchConversationSession
    result: ConversationalSearchResult
    transcription: SpeechTranscriptionResult
    telemetry: dict[str, Any]


class VoiceSearchService:
    def __init__(
        self,
        *,
        speech_provider: SpeechToTextProvider,
        conversation_service: ConversationalSearchService | None = None,
        preprocessor: NoOpAudioPreprocessor | None = None,
    ) -> None:
        self.speech_provider = speech_provider
        self.conversation_service = conversation_service
        self.preprocessor = preprocessor or NoOpAudioPreprocessor()

    async def transcribe(
        self,
        audio_bytes: bytes,
        *,
        filename: str = "audio.m4a",
        language: str = "en",
        duration_ms: int = 0,
        context: SpeechTranscriptionContext | None = None,
    ) -> SpeechTranscriptionResult:
        processed = await self.preprocessor.process(input_bytes=audio_bytes, filename=filename)
        audio = SpokenAudioContext(
            bytes=processed.bytes,
            format=filename.rsplit(".", 1)[-1].lower() if "." in filename else "m4a",
            duration_ms=duration_ms,
        )
        try:
            return await self.speech_provider.transcribe(
                audio,
                filename=processed.filename,
                language=language,
                context=context,
            )
        except Exception:
            audio.dispose()
            raise

    async def search_spoken(
        self,
        transcription: SpeechTranscriptionResult,
        *,
        session: SearchConversationSession | None = None,
        edited_transcript: str | None = None,
    ) -> VoiceSearchOutcome:
        if self.conversation_service is None:
            raise RuntimeError("conversation_service is required for search_spoken")
        started = time.perf_counter()
        effective_text = transcription.effective_text(edited_transcript)
        try:
            updated_session, result = await self.conversation_service.search(
                effective_text,
                session=session,
                language=transcription.language,
            )
            return VoiceSearchOutcome(
                session=updated_session,
                result=result,
                transcription=transcription,
                telemetry={
                    "provider": transcription.provider,
                    "model": transcription.model,
                    "sttLatencyMs": transcription.latency_ms,
                    "voicePipelineLatencyMs": (time.perf_counter() - started) * 1000,
                    "audioBytes": transcription.audio_context.byte_length if transcription.audio_context else 0,
                    "durationMs": transcription.duration_ms,
                    "confidence": transcription.confidence,
                    "confidenceKind": transcription.confidence_kind,
                    "editedTranscriptUsed": effective_text != transcription.text.strip(),
                    "hypothesisCount": len(transcription.hypotheses),
                    "dynamicTop3Enabled": False,
                    "preprocessing": "raw_no_op",
                },
            )
        finally:
            transcription.dispose_audio()

    async def transcribe_and_search(self, audio_bytes: bytes, **kwargs: Any) -> VoiceSearchOutcome:
        search_keys = {"session", "edited_transcript"}
        search_args = {key: kwargs.pop(key) for key in list(kwargs) if key in search_keys}
        transcription = await self.transcribe(audio_bytes, **kwargs)
        return await self.search_spoken(transcription, **search_args)
