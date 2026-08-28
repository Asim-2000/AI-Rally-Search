# PY-3 Query Understanding BASELINE_V1

- Fixture: `dart_golden_176_v1` (176 cases, SHA-256 `dd1773465906104983f8dfc46209104f18991b724af47f9cd2a36621b2139df8`)
- Provider/model: `mock` / `mock-parser-v1`
- Prompt/schema/few-shot: `query_understanding_prompt_v1` / `search_query_py1_v1` / `query_understanding_few_shot_v1`

| Metric | Value |
|---|---:|
| SearchQuery accuracy | 11.93% |
| Intent accuracy | 51.70% |
| Field precision / recall / F1 | 89.22% / 46.42% / 61.07% |
| Schema success | 100.00% |
| Hallucinated-filter rate | 0.00% |
| End-to-end exact | not run |
| Latency avg / p50 / p95 / max (ms) | 0.0 / 0.0 / 0.0 / 0.1 |
| Retries | 0 |
| Cost/query | not configured |

## Failure categories

- MISSING_ENTITY: 113
- MULTIVALUE_LOSS: 26
- WRONG_INTENT: 85
- WRONG_YEAR: 2
