from __future__ import annotations

import asyncio
import datetime
import json
from pathlib import Path
from typing import Any

from benchmarks.providers.openai_stt import OpenAISTTAdapter
from benchmarks.runners.helpers import get_benchmark_api_keys
from benchmarks.scoring.latency import summarize_latencies
from benchmarks.scoring.stt_scoring import score_stt_result


async def run_stt_benchmark() -> Path:
    keys = get_benchmark_api_keys()
    manifest_path = Path(__file__).parent.parent / "datasets" / "stt_manifest.jsonl"
    with open(manifest_path, "r", encoding="utf-8") as f:
        cases = [json.loads(line) for line in f if line.strip()]

    print(f"Loaded {len(cases)} STT manifest cases.")

    models = [
        {"provider": "openai", "model": "whisper-1", "adapter": OpenAISTTAdapter(api_key=keys["openai"], model="whisper-1")},
        {"provider": "openai", "model": "gpt-4o-mini-transcribe", "adapter": OpenAISTTAdapter(api_key=keys["openai"], model="gpt-4o-mini-transcribe")},
    ]

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    results_dir = Path(__file__).parent.parent / "results" / f"stt_{timestamp}"
    results_dir.mkdir(parents=True, exist_ok=True)

    records: dict[str, list[dict[str, Any]]] = {m["model"]: [] for m in models}

    for case in cases:
        # Check audio path
        a_path = Path("..") / case["audio_path"]
        if not a_path.exists():
            a_path = Path(case["audio_path"])

        for m_info in models:
            m_id = m_info["model"]
            adapter = m_info["adapter"]

            # Condition 1: Vanilla
            vanilla_res = await adapter.transcribe(
                case_id=case["case_id"],
                audio_path=a_path,
                language=case.get("language"),
            )
            vanilla_score = score_stt_result(case["reference_text"], vanilla_res.transcript, case.get("entities", []))

            # Condition 2: Vocabulary Biased
            hint = "Moonraker, Donegal, Josh Moffett, Sam Moffett, drift, jump, stage"
            biased_res = await adapter.transcribe(
                case_id=case["case_id"],
                audio_path=a_path,
                language=case.get("language"),
                prompt_hint=hint,
            )
            biased_score = score_stt_result(case["reference_text"], biased_res.transcript, case.get("entities", []))

            records[m_id].append({
                "case_id": case["case_id"],
                "speaker_type": case.get("speaker_type"),
                "language": case.get("language"),
                "reference_text": case["reference_text"],
                "vanilla": {
                    "transcript": vanilla_res.transcript,
                    "latency_ms": vanilla_res.latency_ms,
                    "score": vanilla_score,
                    "error": vanilla_res.error,
                },
                "biased": {
                    "transcript": biased_res.transcript,
                    "latency_ms": biased_res.latency_ms,
                    "score": biased_score,
                    "error": biased_res.error,
                },
            })

    report_file = results_dir / "stt_report.md"
    lines = [
        "# Speech-to-Text Benchmark Report",
        "",
        f"- **Timestamp**: `{timestamp}`",
        f"- **Utterances Evaluated**: {len(cases)}",
        f"- **Tracks**: Synthetic & Human",
        "",
        "## STT Results Summary",
        "",
        "| Model | Track | Condition | WER | Entity Preservation Rate | p50 Latency (ms) | p95 Latency (ms) |",
        "| :--- | :---: | :---: | :---: | :---: | :---: | :---: |",
    ]

    for m_id, model_recs in records.items():
        for track in ["human", "synthetic"]:
            track_recs = [r for r in model_recs if r["speaker_type"] == track]
            if not track_recs:
                continue

            # Vanilla
            v_wers = [r["vanilla"]["score"]["wer"] for r in track_recs]
            v_eprs = [r["vanilla"]["score"]["entity_preservation_rate"] for r in track_recs]
            v_lats = [r["vanilla"]["latency_ms"] for r in track_recs]
            v_s = summarize_latencies(v_lats)

            # Biased
            b_wers = [r["biased"]["score"]["wer"] for r in track_recs]
            b_eprs = [r["biased"]["score"]["entity_preservation_rate"] for r in track_recs]
            b_lats = [r["biased"]["latency_ms"] for r in track_recs]
            b_s = summarize_latencies(b_lats)

            lines.append(
                f"| `{m_id}` | {track} | Vanilla | {sum(v_wers)/len(v_wers):.1%} | {sum(v_eprs)/len(v_eprs):.1%} | {v_s['p50']:.0f}ms | {v_s['p95']:.0f}ms |"
            )
            lines.append(
                f"| `{m_id}` | {track} | DB Biased | {sum(b_wers)/len(b_wers):.1%} | {sum(b_eprs)/len(b_eprs):.1%} | {b_s['p50']:.0f}ms | {b_s['p95']:.0f}ms |"
            )

    report_content = "\n".join(lines) + "\n"
    report_file.write_text(report_content, encoding="utf-8")
    print(f"STT benchmark complete! Report saved to {report_file}")
    return report_file


if __name__ == "__main__":
    asyncio.run(run_stt_benchmark())
