import asyncio

import pytest

from app.domain.conversation_session import SearchConversationSession
from app.domain.results import SearchResponse
from app.domain.search_intent import SearchIntent
from app.query_understanding.provider import ProviderConfig
from app.query_understanding.providers.mock_provider import MockProvider
from app.query_understanding.service import QueryUnderstandingService
from app.services.conversational_search_service import ConversationalSearchService
from app.voice.mock_provider import MockSpeechToTextProvider
from app.voice.models import (
    SpeechTranscriptionContext,
    SpeechTranscriptionResult,
    SpokenAudioContext,
    SpokenWordTimestamp,
    TranscriptHypothesis,
    TranscriptionOrigin,
)
from app.voice.openai_provider import OpenAISpeechToTextProvider
from app.voice.provider import SpeechProviderConfig, SpeechProviderError
from app.voice.service import VoiceSearchService
from app.main import app


class EmptyRepository:
    async def search(self, query):
        return SearchResponse(intent=query.intent, results=[], total_count=0, has_more=False, limit=query.limit, offset=query.offset)


@pytest.mark.unit
@pytest.mark.voice
def test_experimental_raw_audio_endpoint_is_registered():
    assert "post" in app.openapi()["paths"]["/v1/voice/search"]
    assert "post" in app.openapi()["paths"]["/v1/voice/transcribe"]


@pytest.mark.unit
@pytest.mark.voice
def test_transcribe_endpoint_returns_transcription_only(monkeypatch):
    from fastapi.testclient import TestClient
    from app.api.v1 import voice as voice_module

    config = SpeechProviderConfig(provider="mock", model="mock-stt")
    mock_provider = MockSpeechToTextProvider(config, transcript="show rallies where Max Freeman participated")
    monkeypatch.setattr(voice_module, "_speech_provider", lambda settings: mock_provider)

    client = TestClient(app)
    response = client.post(
        "/v1/voice/transcribe?filename=test.wav&language=en",
        content=b"dummy_audio_bytes",
        headers={"Content-Type": "application/octet-stream"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["transcript"] == "show rallies where Max Freeman participated"
    assert data["provider"] == "mock"
    assert data["model"] == "mock-stt"
    assert data["language"] == "en"
    assert "latencyMs" in data
    # Assert NO search, NO session, NO DB execution fields
    assert "session" not in data
    assert "result" not in data
    assert "searchResponse" not in data
    assert "parsedQuery" not in data


@pytest.mark.unit
@pytest.mark.voice
def test_transcribe_endpoint_has_no_conversational_service_dependency():
    """Prove /v1/voice/transcribe route does NOT depend on get_conversational_service or DB."""
    from app.api.v1.conversation import get_conversational_service
    from app.api.v1.voice import transcribe_voice
    import inspect

    # Inspect signature and dependencies of transcribe_voice directly
    sig = inspect.signature(transcribe_voice)
    for param_name, param in sig.parameters.items():
        assert param.default != get_conversational_service
        if hasattr(param.default, "dependency"):
            assert param.default.dependency != get_conversational_service



@pytest.mark.unit
@pytest.mark.voice
def test_transcribe_endpoint_empty_audio_returns_422():
    from fastapi.testclient import TestClient

    client = TestClient(app)
    response = client.post(
        "/v1/voice/transcribe",
        content=b"",
        headers={"Content-Type": "application/octet-stream"},
    )
    assert response.status_code == 422


@pytest.mark.unit
@pytest.mark.voice
def test_transcribe_endpoint_provider_error_returns_502(monkeypatch):
    from fastapi.testclient import TestClient
    from app.api.v1 import voice as voice_module

    config = SpeechProviderConfig(provider="mock", model="mock-stt")
    mock_provider = MockSpeechToTextProvider(config, error=SpeechProviderError("transcription failed"))
    monkeypatch.setattr(voice_module, "_speech_provider", lambda settings: mock_provider)

    client = TestClient(app)
    response = client.post(
        "/v1/voice/transcribe",
        content=b"dummy_audio_bytes",
        headers={"Content-Type": "application/octet-stream"},
    )
    assert response.status_code == 502
    assert "transcription failed" in response.text



def voice_service(transcript="Show rallies in Ireland", *, error=None):
    config = SpeechProviderConfig(provider="mock", model="mock-stt")
    speech = MockSpeechToTextProvider(config, transcript=transcript, error=error)
    conversation = ConversationalSearchService(
        query_parser=QueryUnderstandingService(MockProvider(ProviderConfig(provider="mock", model="mock-parser-v1"))),
        repository=EmptyRepository(),
    )
    return VoiceSearchService(speech_provider=speech, conversation_service=conversation), speech


@pytest.mark.unit
@pytest.mark.voice
def test_detailed_models_and_audio_lifecycle(tmp_path):
    temporary = tmp_path / "audio.wav"
    temporary.write_bytes(b"RIFFdata")
    audio = SpokenAudioContext(bytes=b"RIFFdata", format="wav", sample_rate=16_000, duration_ms=900, local_file_path=temporary)
    result = SpeechTranscriptionResult(
        text="hello",
        audio_context=audio,
        hypotheses=[TranscriptHypothesis(text="hullo", confidence=.4, logProb=-1)],
        words=[SpokenWordTimestamp(word="hello", startMs=100, endMs=350)],
    )
    assert result.hypotheses[0].text == "hullo"
    assert result.words[0].duration_ms == 250
    assert result.effective_text("edited text") == "edited text"
    result.dispose_audio()
    result.dispose_audio()
    assert audio.is_disposed and not temporary.exists()


@pytest.mark.unit
@pytest.mark.voice
async def test_search_spoken_edited_transcript_is_authoritative_and_disposes():
    service, _ = voice_service()
    audio = SpokenAudioContext(bytes=b"audio")
    transcription = SpeechTranscriptionResult(text="wrong words", audio_context=audio, provider="mock", model="mock-stt")
    outcome = await service.search_spoken(transcription, edited_transcript="Show rallies in Ireland")
    assert outcome.result.resolved_query.countries == ["Ireland"]
    assert outcome.telemetry["editedTranscriptUsed"] is True
    assert outcome.telemetry["dynamicTop3Enabled"] is False
    assert outcome.telemetry["preprocessing"] == "raw_no_op"
    assert audio.is_disposed


@pytest.mark.unit
@pytest.mark.voice
async def test_voice_reuses_conversation_and_propagates_clarification():
    service, _ = voice_service()
    audio = SpokenAudioContext(bytes=b"audio")
    transcription = SpeechTranscriptionResult(text="Who won it?", audio_context=audio)
    outcome = await service.search_spoken(transcription, session=SearchConversationSession())
    assert outcome.result.requires_clarification
    assert outcome.session.active_request_id == 1
    assert outcome.session.history == []
    assert audio.is_disposed


@pytest.mark.unit
@pytest.mark.voice
async def test_provider_failure_disposes_audio():
    service, provider = voice_service(error=SpeechProviderError("failed"))
    with pytest.raises(SpeechProviderError):
        await service.transcribe(b"audio")
    assert provider.seen_audio is not None and provider.seen_audio.is_disposed


@pytest.mark.unit
@pytest.mark.voice
async def test_openai_timeout_is_sanitized(monkeypatch):
    class FakeClient:
        def __enter__(self): return self
        def __exit__(self, *args): return None
        def post(self, *args, **kwargs): raise asyncio.TimeoutError

    monkeypatch.setattr("app.voice.openai_provider.httpx.Client", lambda **kwargs: FakeClient())
    provider = OpenAISpeechToTextProvider(SpeechProviderConfig(provider="openai", model="whisper-1", api_key="secret"))
    with pytest.raises(Exception, match="timed out"):
        await provider.transcribe(SpokenAudioContext(bytes=b"audio"), filename="a.wav", language="en")


@pytest.mark.unit
@pytest.mark.voice
async def test_static_and_dynamic_biasing_remain_disabled():
    provider = OpenAISpeechToTextProvider(SpeechProviderConfig(provider="openai", model="whisper-1", api_key="secret"))
    audio = SpokenAudioContext(bytes=b"audio")
    with pytest.raises(SpeechProviderError, match="static STT context"):
        await provider.transcribe(audio, filename="a.wav", language="en", context=SpeechTranscriptionContext(origin=TranscriptionOrigin.BASELINE, prompt="aliases"))
    with pytest.raises(SpeechProviderError, match="biased transcription"):
        await provider.transcribe(audio, filename="a.wav", language="en", context=SpeechTranscriptionContext(origin=TranscriptionOrigin.DYNAMIC_BIASED))


@pytest.mark.unit
@pytest.mark.voice
def test_map_to_whisper_language_bcp47_and_normalization():
    from app.voice.vocabulary import map_to_whisper_language

    assert map_to_whisper_language("en") == "en"
    assert map_to_whisper_language("en-US") == "en"
    assert map_to_whisper_language("en_GB") == "en"
    assert map_to_whisper_language("de-DE") == "de"
    assert map_to_whisper_language("fr-FR") == "fr"
    assert map_to_whisper_language("es-ES") == "es"
    assert map_to_whisper_language("nb-NO") == "no"
    assert map_to_whisper_language("nn") == "no"
    assert map_to_whisper_language("unknown-xyz") is None
    assert map_to_whisper_language("") is None


@pytest.mark.unit
@pytest.mark.voice
async def test_openai_whisper_outbound_request_has_no_prompt_and_uses_json(monkeypatch):
    captured_data = {}
    captured_files = {}

    class FakeClient:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            return None

        def post(self, url, headers=None, data=None, files=None):
            nonlocal captured_data, captured_files
            captured_data = data or {}
            captured_files = files or {}

            class FakeResponse:
                status_code = 200

                def json(self):
                    return {"text": "Show rallies in Ireland"}

            return FakeResponse()

    monkeypatch.setattr("app.voice.openai_provider.httpx.Client", lambda **kwargs: FakeClient())
    provider = OpenAISpeechToTextProvider(
        SpeechProviderConfig(provider="openai", model="whisper-1", api_key="secret")
    )
    result = await provider.transcribe(
        SpokenAudioContext(bytes=b"dummy_m4a_bytes"),
        filename="voice.m4a",
        language="en-US",
    )

    assert result.text == "Show rallies in Ireland"
    assert captured_data.get("model") == "whisper-1"
    assert captured_data.get("response_format") == "json"
    assert captured_data.get("language") == "en"
    # CRITICAL: Baseline Whisper request must NOT contain a 'prompt' field
    assert "prompt" not in captured_data
    # Verify file tuple metadata
    assert "file" in captured_files
    filename, file_bytes, content_type = captured_files["file"]
    assert filename == "voice.m4a"
    assert file_bytes == b"dummy_m4a_bytes"
    assert content_type == "audio/mp4"

