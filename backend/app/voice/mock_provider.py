from __future__ import annotations

from .models import SpeechTranscriptionContext, SpeechTranscriptionResult, SpokenAudioContext
from .provider import SpeechProviderError, SpeechToTextProvider


class MockSpeechToTextProvider(SpeechToTextProvider):
    def __init__(self, config, *, transcript: str = "", error: Exception | None = None):
        super().__init__(config)
        self.transcript = transcript
        self.error = error
        self.seen_audio: SpokenAudioContext | None = None

    async def transcribe(self, audio, *, filename, language, context=None):
        self.seen_audio = audio
        if self.error:
            raise self.error
        if not self.transcript.strip():
            raise SpeechProviderError("no intelligible speech detected")
        return SpeechTranscriptionResult(
            text=self.transcript.strip(),
            language=language,
            audio_context=audio,
            provider="mock",
            model=self.config.model,
            metadata={"nbestAvailable": False, "biasedSecondPass": False},
        )
