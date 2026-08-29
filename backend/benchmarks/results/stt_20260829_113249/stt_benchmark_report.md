# Final STT Benchmark

## Executive Summary

- Status: **STT BENCHMARK COMPLETE — HUMAN VALIDATION REQUIRED**
- Fixed QU: `gemini-3.5-flash-lite`
- Measured 115 audio rows: 110 synthetic and 5 human (4 unique waveforms, 1 speaker).
- Human evidence is insufficient for a production winner. Safety-gated finalists: `gpt-transcribe, gpt-4o-mini-transcribe`.

## Environment

- Branch / commit: `benchmark-final` / `8fa449077968e1c91a850c3cb2d078c0eb62fe22`
- Dataset SHA256: `0a61c34e1fcd3f6e4bfb74a7a7254c83324fff6baf9cb4bd11dc929292941195`
- Working tree was dirty before STT run: `true`

## Audio Dataset

- Total utterances: 115
- Total minutes: 3.57
- Human: 5 rows, 4 unique waveforms, 1 speaker
- Synthetic: 110 controlled, clean English TTS rows
- Entity distribution: 30 rally, 50 person, 30 stage plus human labels

## Provider / Model Access

- `whisper-1`: measured
- `gpt-4o-mini-transcribe`: measured
- `gpt-transcribe`: measured
- `gemini-3.5-transcribe`: unavailable for measurement; HTTP 200 but empty output and zero output tokens on both tested official input paths.

## Transcript Metrics

| Model | WER | CER | Entity preservation | Failure |
|---|---:|---:|---:|---:|
| `whisper-1` | 36.4% | 14.0% | 40.9% | 0.0% |
| `gpt-4o-mini-transcribe` | 36.7% | 19.5% | 43.5% | 0.0% |
| `gpt-transcribe` | 45.3% | 20.3% | 39.1% | 0.0% |

## Entity Preservation

Detailed exact/normalized/recoverable/dropped/substituted counts by track and type are in `stt_entity_summary.csv`.

## Human Results

| Model | WER | Entity preservation | E2E success | False confident |
|---|---:|---:|---:|---:|
| `whisper-1` | 86.7% | 20.0% | 20.0% | 0.0% |
| `gpt-4o-mini-transcribe` | 46.7% | 20.0% | 60.0% | 20.0% |
| `gpt-transcribe` | 33.3% | 20.0% | 40.0% | 0.0% |

## Synthetic Results

| Model | WER | Entity preservation | E2E success | False confident |
|---|---:|---:|---:|---:|
| `whisper-1` | 34.1% | 41.8% | 59.1% | 3.6% |
| `gpt-4o-mini-transcribe` | 36.2% | 44.5% | 55.5% | 2.7% |
| `gpt-transcribe` | 45.8% | 40.0% | 50.0% | 2.7% |

## Latency

| Model | p50 ms | p95 ms | p50 RTF | p95 RTF |
|---|---:|---:|---:|---:|
| `whisper-1` | 1004.25 | 1869.40 | 0.600 | 1.470 |
| `gpt-4o-mini-transcribe` | 610.20 | 828.55 | 0.460 | 0.660 |
| `gpt-transcribe` | 627.93 | 874.92 | 0.470 | 0.640 |

## Cost

- Total STT benchmark cost across vanilla + vocabulary conditions: $0.096267.
- `whisper-1`: $0.021393 vanilla; $0.042785 both conditions; $0.1860/1,000 average utterances.
- `gpt-4o-mini-transcribe`: $0.010696 vanilla; $0.021393 both conditions; $0.0930/1,000 average utterances.
- `gpt-transcribe`: $0.016044 vanilla; $0.032089 both conditions; $0.1395/1,000 average utterances.

## End-to-End Search Results

| Model | Query match | Canonical | Plan | System success | False confident |
|---|---:|---:|---:|---:|---:|
| `whisper-1` | 33.0% | 47.0% | 75.7% | 57.4% | 3.5% |
| `gpt-4o-mini-transcribe` | 40.9% | 44.3% | 73.9% | 55.7% | 3.5% |
| `gpt-transcribe` | 25.2% | 39.1% | 64.3% | 49.6% | 2.6% |

## STT-Induced Failures

- `whisper-1`: `{'STT_CHANGED_QUERY_BUT_SYSTEM_SUCCEEDED': 23, 'STT_CAUSED_SYSTEM_FAILURE': 18, 'NO_STT_IMPACT': 40, 'STT_ERROR_RECOVERED': 30, 'STT_CAUSED_FALSE_CONFIDENT': 4}`
- `gpt-4o-mini-transcribe`: `{'STT_CHANGED_QUERY_BUT_SYSTEM_SUCCEEDED': 17, 'STT_CAUSED_SYSTEM_FAILURE': 20, 'STT_ERROR_RECOVERED': 34, 'NO_STT_IMPACT': 40, 'STT_CAUSED_FALSE_CONFIDENT': 4}`
- `gpt-transcribe`: `{'STT_CHANGED_QUERY_BUT_SYSTEM_SUCCEEDED': 21, 'STT_CAUSED_SYSTEM_FAILURE': 28, 'NO_STT_IMPACT': 40, 'STT_ERROR_RECOVERED': 23, 'STT_CAUSED_FALSE_CONFIDENT': 3}`

## False-Confident Analysis

- STT-induced false-confident counts: `{'whisper-1': 4, 'gpt-4o-mini-transcribe': 4, 'gpt-transcribe': 3}`.

## Vocabulary Bias Experiment

Separate vanilla and DB-canonical-vocabulary transcript metrics are in `stt_vocabulary_comparison.csv`; biased transcripts are not mixed into vanilla or E2E results.

## Head-to-Head Cases

- 114 differing transcript/outcome cases saved in `stt_head_to_head.jsonl`.

## Model Recommendation

- BEST_TRANSCRIPT_ACCURACY: `whisper-1`
- BEST_ENTITY_PRESERVATION: `gpt-4o-mini-transcribe`
- BEST_END_TO_END: `whisper-1`
- BEST_LATENCY: `gpt-4o-mini-transcribe`
- BEST_COST: `gpt-4o-mini-transcribe`
- RECOMMENDED_STT_FINALISTS_FOR_HUMAN_TEST: `gpt-transcribe, gpt-4o-mini-transcribe`

## Remaining Limitations

- Only four unique human waveforms from one speaker are available; no production winner is declared.
- Synthetic TTS cannot validate real accents, microphones, hesitations, or environmental noise.
- The Google candidate was listed but produced no transcript output during verified probes.
- E2E comparisons use the frozen fixed-QU reference path to isolate STT damage from known downstream weaknesses.
