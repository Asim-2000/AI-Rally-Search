from __future__ import annotations

import json
from pathlib import Path

AUDIO_DIR = Path("../test/eval/audio") if Path("../test/eval/audio").exists() else Path("test/eval/audio")

SAMPLE_STT_ENTRIES = [
    # Human track samples
    {
        "case_id": "stt_human_0001",
        "audio_path": "test/eval/audio/human/asim1.wav",
        "reference_text": "Show jump highlights from Moonraker",
        "entities": [
            {"text": "jump", "type": "ACTION"},
            {"text": "Moonraker", "type": "RALLY"},
        ],
        "language": "en",
        "noise_class": "clean",
        "speaker_type": "human",
    },
    {
        "case_id": "stt_human_0002",
        "audio_path": "test/eval/audio/human/asim2.wav",
        "reference_text": "Rallies driven by Josh Moffett",
        "entities": [
            {"text": "Josh Moffett", "type": "PERSON"},
        ],
        "language": "en",
        "noise_class": "clean",
        "speaker_type": "human",
    },
    {
        "case_id": "stt_human_0003",
        "audio_path": "test/eval/audio/human/asim3.wav",
        "reference_text": "Who won Donegal International Rally?",
        "entities": [
            {"text": "Donegal International Rally", "type": "RALLY"},
        ],
        "language": "en",
        "noise_class": "clean",
        "speaker_type": "human",
    },
    # Synthetic track samples
    {
        "case_id": "stt_synth_en_01",
        "audio_path": "test/eval/audio/synthetic/en_01.mp3",
        "reference_text": "Show me jumps and drifts by Josh Moffett",
        "entities": [
            {"text": "jumps", "type": "ACTION"},
            {"text": "drifts", "type": "ACTION"},
            {"text": "Josh Moffett", "type": "PERSON"},
        ],
        "language": "en",
        "noise_class": "clean",
        "speaker_type": "synthetic",
    },
    {
        "case_id": "stt_synth_de_01",
        "audio_path": "test/eval/audio/synthetic/de_01.mp3",
        "reference_text": "Zeig mir Sprünge von Josh Moffett",
        "entities": [
            {"text": "Sprünge", "type": "ACTION"},
            {"text": "Josh Moffett", "type": "PERSON"},
        ],
        "language": "de",
        "noise_class": "clean",
        "speaker_type": "synthetic",
    },
    {
        "case_id": "stt_synth_fr_01",
        "audio_path": "test/eval/audio/synthetic/fr_01.mp3",
        "reference_text": "Montre-moi les dérapages de Josh Moffett",
        "entities": [
            {"text": "dérapages", "type": "ACTION"},
            {"text": "Josh Moffett", "type": "PERSON"},
        ],
        "language": "fr",
        "noise_class": "clean",
        "speaker_type": "synthetic",
    },
    {
        "case_id": "stt_synth_es_01",
        "audio_path": "test/eval/audio/synthetic/es_01.mp3",
        "reference_text": "Vídeos de derrapes de Josh Moffett",
        "entities": [
            {"text": "derrapes", "type": "ACTION"},
            {"text": "Josh Moffett", "type": "PERSON"},
        ],
        "language": "es",
        "noise_class": "clean",
        "speaker_type": "synthetic",
    },
    {
        "case_id": "stt_synth_it_01",
        "audio_path": "test/eval/audio/synthetic/it_01.mp3",
        "reference_text": "Mostra incidenti di Josh Moffett",
        "entities": [
            {"text": "incidenti", "type": "ACTION"},
            {"text": "Josh Moffett", "type": "PERSON"},
        ],
        "language": "it",
        "noise_class": "clean",
        "speaker_type": "synthetic",
    },
]


def build_stt_manifest() -> None:
    manifest_path = Path(__file__).parent / "stt_manifest.jsonl"
    with open(manifest_path, "w", encoding="utf-8") as f:
        for entry in SAMPLE_STT_ENTRIES:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    print(f"Saved STT manifest ({len(SAMPLE_STT_ENTRIES)} items) to {manifest_path}")


if __name__ == "__main__":
    build_stt_manifest()
