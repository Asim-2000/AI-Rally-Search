from dataclasses import dataclass


@dataclass(frozen=True)
class AudioPreprocessingResult:
    strategy: str
    bytes: bytes
    filename: str
    changed: bool = False


class NoOpAudioPreprocessor:
    async def process(self, *, input_bytes: bytes, filename: str) -> AudioPreprocessingResult:
        return AudioPreprocessingResult("raw", input_bytes, filename, False)
