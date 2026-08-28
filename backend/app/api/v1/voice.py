import json

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field

from ...config import Settings, get_settings
from ...domain.conversation_session import SearchConversationSession
from ...services.conversational_search_service import ConversationalSearchResult, ConversationalSearchService
from ...voice.models import SpokenWordTimestamp, TranscriptHypothesis
from ...voice.openai_provider import OpenAISpeechToTextProvider
from ...voice.provider import SpeechProviderConfig, SpeechProviderError
from ...voice.service import VoiceSearchService
from .conversation import get_conversational_service

router = APIRouter(prefix="/v1/voice")


class VoiceTranscriptionPayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    text: str
    language: str
    hypotheses: list[TranscriptHypothesis] = Field(default_factory=list)
    words: list[SpokenWordTimestamp] = Field(default_factory=list)
    duration_ms: int = Field(alias="durationMs")
    confidence: float | None = None
    confidence_kind: str | None = Field(default=None, alias="confidenceKind")
    provider: str
    model: str
    latency_ms: float = Field(alias="latencyMs")


class VoiceTranscribeResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    transcript: str
    provider: str
    model: str
    language: str
    latency_ms: float = Field(alias="latencyMs")
    uncalibrated_confidence: float | None = Field(default=None, alias="uncalibratedConfidence")


class VoiceSearchResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    session: SearchConversationSession
    result: ConversationalSearchResult
    transcription: VoiceTranscriptionPayload
    telemetry: dict
    request_id: int | None = Field(default=None, alias="requestId")


def _speech_provider(settings: Settings) -> OpenAISpeechToTextProvider:
    if settings.speech_provider.lower() != "openai":
        raise HTTPException(503, "unsupported speech provider")
    return OpenAISpeechToTextProvider(SpeechProviderConfig(
        provider="openai",
        model=settings.speech_model,
        api_key=settings.openai_api_key.get_secret_value(),
        base_url=settings.openai_base_url,
        timeout_seconds=settings.speech_timeout_seconds,
        dynamic_top3_enabled=False,
        preprocessing_strategy="raw",
    ))


def _voice_search_service(
    conversation: ConversationalSearchService,
    settings: Settings,
) -> VoiceSearchService:
    provider = _speech_provider(settings)
    return VoiceSearchService(speech_provider=provider, conversation_service=conversation)


@router.post("/transcribe", response_model=VoiceTranscribeResponse, response_model_by_alias=True)
async def transcribe_voice(
    request: Request,
    filename: str = Query("audio.wav"),
    language: str = Query("en"),
    settings: Settings = Depends(get_settings),
) -> VoiceTranscribeResponse:
    audio = await request.body()
    if not audio:
        raise HTTPException(422, "audio body must not be empty")
    transcription = None
    try:
        service = VoiceSearchService(speech_provider=_speech_provider(settings))
        transcription = await service.transcribe(
            audio,
            filename=filename,
            language=language,
        )
        return VoiceTranscribeResponse(
            transcript=transcription.text,
            provider=transcription.provider,
            model=transcription.model,
            language=transcription.language,
            latencyMs=transcription.latency_ms,
            uncalibratedConfidence=transcription.confidence,
        )
    except SpeechProviderError as exc:
        raise HTTPException(502, str(exc)) from exc
    finally:
        if transcription is not None:
            transcription.dispose_audio()



@router.post("/search", response_model=VoiceSearchResponse, response_model_by_alias=True)
async def search_voice(
    request: Request,
    filename: str = Query("audio.wav"),
    language: str = Query("en"),
    session_json: str | None = Query(default=None, alias="session"),
    edited_transcript: str | None = Query(default=None, alias="editedTranscript"),
    request_id: int | None = Query(default=None, alias="requestId"),
    conversation: ConversationalSearchService = Depends(get_conversational_service),
    settings: Settings = Depends(get_settings),
) -> VoiceSearchResponse:
    audio = await request.body()
    if not audio:
        raise HTTPException(422, "audio body must not be empty")
    try:
        session = SearchConversationSession.model_validate_json(session_json) if session_json else SearchConversationSession()
    except (ValueError, json.JSONDecodeError) as exc:
        raise HTTPException(422, "invalid session JSON") from exc
    try:
        outcome = await _voice_search_service(conversation, settings).transcribe_and_search(
            audio,
            filename=filename,
            language=language,
            session=session,
            edited_transcript=edited_transcript,
        )
    except SpeechProviderError as exc:
        raise HTTPException(502, str(exc)) from exc
    t = outcome.transcription
    return VoiceSearchResponse(
        session=outcome.session,
        result=outcome.result,
        transcription=VoiceTranscriptionPayload(
            text=t.text,
            language=t.language,
            hypotheses=t.hypotheses,
            words=t.words,
            durationMs=t.duration_ms,
            confidence=t.confidence,
            confidenceKind=t.confidence_kind,
            provider=t.provider,
            model=t.model,
            latencyMs=t.latency_ms,
        ),
        telemetry=outcome.telemetry,
        requestId=request_id,
    )
