# Final Query Understanding Benchmark

## Executive Summary

- 392 cases × 2 models = 784 measured requests.
- Recommended production model: `gemini-3.5-flash-lite`.
- Best raw: `gpt-5.6-luna`; best system: `gemini-3.5-flash-lite`; best latency: `gemini-3.5-flash-lite`; best cost: `gemini-3.5-flash-lite`.

## Environment

- Timestamp: `20260829_053539`
- Branch / commit: `benchmark-final` / `8fa449077968e1c91a850c3cb2d078c0eb62fe22`
- Working tree dirty before run: `false`
- Dataset hash: `b7fd39226592281c565c0e835c16b460654f43cd2da4bc09655a5abf06972662`
- Prompt hash: `c82c75d4d10017478084b4c37ee0be005b910bd67cb6c45cf64452d3a2e2c09b`
- DB: `pineamite_dev_db`
- Models: `gpt-5.6-luna, gemini-3.5-flash-lite`
- Randomization seed: `20260829`

## Dataset

- Total: 392
- Per intent: `{'SEARCH_RALLIES': 72, 'SEARCH_DRIVER_RALLIES': 77, 'SEARCH_VIDEO_ACTIONS': 123, 'SEARCH_DRIVER_WINS': 30, 'GET_RALLY_RESULTS': 35, 'GET_RALLY_TOP_FINISHERS': 14, 'GET_TOP_UPLOADERS': 11, 'SEARCH_DRIVER_VIDEOS': 20, 'GET_TOP_DRIVERS_BY_WINS': 10}`
- Per category: `{'immutable_regression': 7, 'simple_filter': 45, 'multi_filter': 60, 'entity_heavy': 60, 'noisy/phonetic': 50, 'multi_value': 40, 'ambiguity/clarification': 30, 'conversation/referents': 40, 'video/action': 40, 'realistic/adversarial': 20}`

## Raw QU Results

| Model | Schema | Intent | Precision | Recall | F1 | Exact | Retention | Wrong field | Hallucination | Extra | Multi | Role | Match |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `gpt-5.6-luna` | 100.0% | 93.4% | 89.9% | 95.0% | 92.1% | 66.1% | 87.5% | 0.3% | 3.1% | 27.0% | 100.0% | 97.2% | 100.0% |
| `gemini-3.5-flash-lite` | 100.0% | 92.6% | 86.8% | 92.6% | 89.3% | 64.3% | 81.0% | 1.0% | 8.4% | 33.2% | 100.0% | 100.0% | 96.4% |

## System-Level Results

| Model | Success | Canonical | Clarification | No-match | False confident | Router recovery | OpenEntity recovery | Safe recovery |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `gpt-5.6-luna` | 74.7% | 64.8% | 71.4% | 0.0% | 0.0% | 24.7% | 9.9% | 24.7% |
| `gemini-3.5-flash-lite` | 76.0% | 61.2% | 71.4% | 0.0% | 0.0% | 25.8% | 7.7% | 25.8% |

## Conditional System Success

| Model | Exact raw match | Correct intent | Field F1 ≥ .95 |
|---|---:|---:|---:|
| `gpt-5.6-luna` | 75.7% | 76.0% | 74.5% |
| `gemini-3.5-flash-lite` | 78.2% | 75.8% | 77.3% |

## Per-Intent Results

| Intent | Model | N | Intent | F1 | Exact | System | False confident | p50 ms |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `GET_RALLY_RESULTS` | `gpt-5.6-luna` | 35 | 100.0% | 82.7% | 22.9% | 77.1% | 0.0% | 2774.76 |
| `GET_RALLY_RESULTS` | `gemini-3.5-flash-lite` | 35 | 97.1% | 78.4% | 8.6% | 68.6% | 0.0% | 787.29 |
| `GET_RALLY_TOP_FINISHERS` | `gpt-5.6-luna` | 14 | 100.0% | 74.5% | 35.7% | 85.7% | 0.0% | 2658.53 |
| `GET_RALLY_TOP_FINISHERS` | `gemini-3.5-flash-lite` | 14 | 100.0% | 72.4% | 35.7% | 85.7% | 0.0% | 800.32 |
| `GET_TOP_DRIVERS_BY_WINS` | `gpt-5.6-luna` | 10 | 100.0% | 100.0% | 100.0% | 0.0% | 0.0% | 2698.97 |
| `GET_TOP_DRIVERS_BY_WINS` | `gemini-3.5-flash-lite` | 10 | 100.0% | 100.0% | 100.0% | 0.0% | 0.0% | 859.65 |
| `GET_TOP_UPLOADERS` | `gpt-5.6-luna` | 11 | 100.0% | 81.4% | 36.4% | 72.7% | 0.0% | 2988.30 |
| `GET_TOP_UPLOADERS` | `gemini-3.5-flash-lite` | 11 | 100.0% | 80.5% | 36.4% | 72.7% | 0.0% | 749.05 |
| `SEARCH_DRIVER_RALLIES` | `gpt-5.6-luna` | 77 | 98.7% | 100.0% | 98.7% | 80.5% | 0.0% | 2862.80 |
| `SEARCH_DRIVER_RALLIES` | `gemini-3.5-flash-lite` | 77 | 97.4% | 92.1% | 72.7% | 80.5% | 0.0% | 897.69 |
| `SEARCH_DRIVER_VIDEOS` | `gpt-5.6-luna` | 20 | 100.0% | 100.0% | 100.0% | 80.0% | 0.0% | 2809.64 |
| `SEARCH_DRIVER_VIDEOS` | `gemini-3.5-flash-lite` | 20 | 100.0% | 100.0% | 100.0% | 80.0% | 0.0% | 833.78 |
| `SEARCH_DRIVER_WINS` | `gpt-5.6-luna` | 30 | 100.0% | 92.7% | 63.3% | 100.0% | 0.0% | 2884.70 |
| `SEARCH_DRIVER_WINS` | `gemini-3.5-flash-lite` | 30 | 100.0% | 100.0% | 100.0% | 96.7% | 0.0% | 798.74 |
| `SEARCH_RALLIES` | `gpt-5.6-luna` | 72 | 65.3% | 87.6% | 45.8% | 66.7% | 0.0% | 3105.43 |
| `SEARCH_RALLIES` | `gemini-3.5-flash-lite` | 72 | 66.7% | 79.5% | 47.2% | 76.4% | 0.0% | 891.34 |
| `SEARCH_VIDEO_ACTIONS` | `gpt-5.6-luna` | 123 | 100.0% | 93.3% | 68.3% | 73.2% | 0.0% | 3133.78 |
| `SEARCH_VIDEO_ACTIONS` | `gemini-3.5-flash-lite` | 123 | 98.4% | 93.8% | 73.2% | 74.8% | 0.0% | 860.61 |

## Per-Category Results

| Category | Model | N | Intent | F1 | Exact | System | False confident | p50 ms |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `ambiguity/clarification` | `gpt-5.6-luna` | 30 | 96.7% | 90.0% | 46.7% | 73.3% | 0.0% | 3362.93 |
| `ambiguity/clarification` | `gemini-3.5-flash-lite` | 30 | 86.7% | 97.6% | 80.0% | 73.3% | 0.0% | 903.78 |
| `conversation/referents` | `gpt-5.6-luna` | 40 | 100.0% | 94.6% | 62.5% | 77.5% | 0.0% | 2809.64 |
| `conversation/referents` | `gemini-3.5-flash-lite` | 40 | 100.0% | 93.2% | 52.5% | 72.5% | 0.0% | 817.23 |
| `entity_heavy` | `gpt-5.6-luna` | 60 | 100.0% | 80.1% | 38.3% | 68.3% | 0.0% | 2834.06 |
| `entity_heavy` | `gemini-3.5-flash-lite` | 60 | 100.0% | 78.1% | 38.3% | 68.3% | 0.0% | 827.88 |
| `immutable_regression` | `gpt-5.6-luna` | 7 | 100.0% | 95.2% | 85.7% | 100.0% | 0.0% | 3255.74 |
| `immutable_regression` | `gemini-3.5-flash-lite` | 7 | 85.7% | 90.5% | 71.4% | 100.0% | 0.0% | 1068.12 |
| `multi_filter` | `gpt-5.6-luna` | 60 | 100.0% | 95.8% | 75.0% | 83.3% | 0.0% | 3118.07 |
| `multi_filter` | `gemini-3.5-flash-lite` | 60 | 100.0% | 98.6% | 91.7% | 83.3% | 0.0% | 836.27 |
| `multi_value` | `gpt-5.6-luna` | 40 | 100.0% | 100.0% | 100.0% | 57.5% | 0.0% | 2813.85 |
| `multi_value` | `gemini-3.5-flash-lite` | 40 | 100.0% | 89.7% | 65.0% | 57.5% | 0.0% | 889.08 |
| `noisy/phonetic` | `gpt-5.6-luna` | 50 | 50.0% | 93.1% | 50.0% | 78.0% | 0.0% | 3008.19 |
| `noisy/phonetic` | `gemini-3.5-flash-lite` | 50 | 52.0% | 77.5% | 40.0% | 92.0% | 0.0% | 842.85 |
| `realistic/adversarial` | `gpt-5.6-luna` | 20 | 100.0% | 89.8% | 65.0% | 35.0% | 0.0% | 2725.75 |
| `realistic/adversarial` | `gemini-3.5-flash-lite` | 20 | 100.0% | 89.3% | 65.0% | 35.0% | 0.0% | 755.19 |
| `simple_filter` | `gpt-5.6-luna` | 45 | 100.0% | 88.5% | 71.1% | 84.4% | 0.0% | 3247.02 |
| `simple_filter` | `gemini-3.5-flash-lite` | 45 | 100.0% | 89.2% | 73.3% | 84.4% | 0.0% | 966.58 |
| `video/action` | `gpt-5.6-luna` | 40 | 100.0% | 98.9% | 90.0% | 87.5% | 0.0% | 2745.53 |
| `video/action` | `gemini-3.5-flash-lite` | 40 | 100.0% | 95.8% | 80.0% | 87.5% | 0.0% | 804.80 |

## Latency

| Model | Mean | p50 | p75 | p90 | p95 | p99 | Max |
|---|---:|---:|---:|---:|---:|---:|---:|
| `gpt-5.6-luna` | 3096.05 | 2974.96 | 3490.81 | 4112.80 | 4423.97 | 5109.66 | 10619.66 |
| `gemini-3.5-flash-lite` | 869.52 | 852.42 | 919.47 | 1017.79 | 1083.38 | 1270.97 | 1490.93 |

## Cost

- Total measured benchmark cost: $0.548956.
- `gpt-5.6-luna`: $0.425856 total; $1.0864/1,000; $108.64/100,000.
- `gemini-3.5-flash-lite`: $0.123100 total; $0.3140/1,000; $31.40/100,000.

## Safety / False-Confident Results

- `gpt-5.6-luna`: 0.0% (0/392).
- `gemini-3.5-flash-lite`: 0.0% (0/392).

## Flash-Lite Hallucination Analysis

- Invented year cases: 27.
- Invented values: `[2010, 2013, 2015, 2020, 2021, 2022, 2023, 2024, 2025]`.
- Intents: `{'SEARCH_VIDEO_ACTIONS': 3, 'GET_RALLY_RESULTS': 5, 'SEARCH_RALLIES': 14, 'SEARCH_DRIVER_RALLIES': 5}`.
- Categories: `{'entity_heavy': 2, 'noisy/phonetic': 14, 'multi_value': 5, 'ambiguity/clarification': 2, 'conversation/referents': 4}`.
- Raw scorer caught: 27/27.
- System success despite invented year: 18/27.

## Head-to-Head Results

- LUNA_SUCCEEDS_FLASH_FAILS: 7
- FLASH_SUCCEEDS_LUNA_FAILS: 12
- BOTH_FAIL: 87
- BOTH_SUCCEED_RAW_DIFFERS: 159
- BOTH_SUCCEED_RAW_SAME: 127

## Failure Taxonomy

- `gpt-5.6-luna`: `{'ENTITY_RESOLUTION_WRONG': 129, 'MODEL_PARSE_WRONG': 26, 'EXPECTED_CLARIFICATION_MISMATCH': 8, 'OTHER': 10}`
- `gemini-3.5-flash-lite`: `{'MODEL_PARSE_WRONG': 30, 'ENTITY_RESOLUTION_WRONG': 132, 'EXPECTED_CLARIFICATION_MISMATCH': 8, 'OTHER': 10}`

## Production Recommendation

- BEST_RAW_QU_QUALITY: `gpt-5.6-luna`
- BEST_SYSTEM_QUALITY: `gemini-3.5-flash-lite`
- BEST_LATENCY: `gemini-3.5-flash-lite`
- BEST_COST: `gemini-3.5-flash-lite`
- RECOMMENDED_PRODUCTION_QU_MODEL: `gemini-3.5-flash-lite`

## Why Not the Other Model

`gpt-5.6-luna` lost under the hard-gate ordering: schema reliability, false-confidence safety, critical failures, and clarification safety, followed by system quality, raw quality, latency, cost, and hallucination behavior.

## Remaining Limitations

- Results apply to the frozen dataset and current MySQL snapshot.
- The frozen dataset contains no `NO_MATCH` outcomes, so correct no-match is not estimable (the summary CSV's 0.0 is an empty-denominator sentinel, not a measured failure rate).
- Router and SearchPlanBuilder component timings are fixed placeholders in existing instrumentation; DB, OpenEntity, total pipeline, and provider timings are measured.
