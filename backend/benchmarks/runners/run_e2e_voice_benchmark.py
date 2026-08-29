from __future__ import annotations

import asyncio
import datetime
import json
from pathlib import Path
from typing import Any

from benchmarks.providers.anthropic_qu import AnthropicQUAdapter
from benchmarks.providers.openai_qu import OpenAIQUAdapter
from benchmarks.providers.openai_stt import OpenAISTTAdapter
from benchmarks.runners.helpers import get_benchmark_api_keys
from benchmarks.scoring.query_scoring import score_raw_query
from benchmarks.scoring.system_scoring import evaluate_system_pipeline


async def run_e2e_voice_benchmark() -> Path:
    keys = get_benchmark_api_keys()
    manifest_path = Path(__file__).parent.parent / "datasets" / "stt_manifest.jsonl"
    with open(manifest_path, "r", encoding="utf-8") as f:
        cases = [json.loads(line) for line in f if line.strip()]

    print(f"Loaded {len(cases)} cases for End-to-End Voice evaluation.")

    stt_adapter = OpenAISTTAdapter(api_key=keys["openai"], model="whisper-1")
    qu_adapter = OpenAIQUAdapter(api_key=keys["openai"], model="gpt-5.6-luna")

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    results_dir = Path(__file__).parent.parent / "results" / f"e2e_voice_{timestamp}"
    results_dir.mkdir(parents=True, exist_ok=True)

    records = []
    for case in cases:
        a_path = Path("..") / case["audio_path"]
        if not a_path.exists():
            a_path = Path(case["audio_path"])

        # 1. STT pass
        stt_res = await stt_adapter.transcribe(
            case_id=case["case_id"],
            audio_path=a_path,
            language=case.get("language"),
        )

        if not stt_res.transcript:
            records.append({
                "case_id": case["case_id"],
                "audio": str(a_path),
                "transcript": None,
                "e2e_success": False,
                "error": stt_res.error,
            })
            continue

        # 2. QU pass
        qu_res = await qu_adapter.parse_query(
            case_id=case["case_id"],
            query=stt_res.transcript,
        )

        # 3. System localhost pipeline pass
        synth_case = {
            "case_id": case["case_id"],
            "input_text": stt_res.transcript,
            "category": "voice",
            "expected_resolution": {"outcome": "RESOLVED"},
        }
        sys_res = await evaluate_system_pipeline(synth_case, qu_res.parsed_query)

        records.append({
            "case_id": case["case_id"],
            "audio": str(a_path),
            "transcript": stt_res.transcript,
            "parsed_query": qu_res.parsed_query,
            "e2e_success": sys_res["system_success"],
            "stt_latency_ms": stt_res.latency_ms,
            "qu_latency_ms": qu_res.latency_ms,
            "pipeline_latency_ms": sys_res["latencies_ms"]["total"],
            "total_e2e_latency_ms": stt_res.latency_ms + qu_res.latency_ms + sys_res["latencies_ms"]["total"],
        })

    report_file = results_dir / "e2e_voice_report.md"
    n = len(records)
    succ_rate = sum(r.get("e2e_success", False) for r in records) / n if n > 0 else 0.0
    avg_lat = sum(r.get("total_e2e_latency_ms", 0) for r in records) / n if n > 0 else 0.0

    lines = [
        "# End-to-End Voice Benchmark Report",
        "",
        f"- **Timestamp**: `{timestamp}`",
        f"- **Pipeline**: Audio $\\to$ Whisper-1 $\\to$ gpt-5.6-luna $\\to$ Router $\\to$ OpenEntity $\\to$ MySQL",
        f"- **Utterances Evaluated**: {n}",
        f"- **End-to-End Search Success Rate**: **{succ_rate:.1%}**",
        f"- **Average End-to-End Latency**: **{avg_lat:.0f}ms**",
        "",
    ]
    report_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"E2E Voice benchmark complete! Report saved to {report_file}")
    return report_file


if __name__ == "__main__":
    asyncio.run(run_e2e_voice_benchmark())
