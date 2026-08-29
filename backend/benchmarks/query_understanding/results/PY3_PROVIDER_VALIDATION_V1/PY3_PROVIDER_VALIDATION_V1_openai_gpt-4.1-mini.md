# PY-3 Query Understanding BASELINE_V1

- Fixture: `dart_golden_176_v1` (176 cases, SHA-256 `dd1773465906104983f8dfc46209104f18991b724af47f9cd2a36621b2139df8`)
- Provider/model: `openai` / `gpt-4.1-mini`
- Prompt/schema/few-shot: `query_understanding_prompt_v1` / `search_query_py1_v1` / `query_understanding_few_shot_v1`

| Metric | Value |
|---|---:|
| SearchQuery accuracy | 83.52% |
| Intent accuracy | 92.05% |
| Field precision / recall / F1 | 97.44% / 95.02% / 96.21% |
| Schema success | 100.00% |
| Hallucinated-filter rate | 3.98% |
| End-to-end exact | not run |
| Latency avg / p50 / p95 / max (ms) | 1945.5 / 1842.7 / 2656.5 / 5728.7 |
| Retries | 0 |
| Cost/query | not configured |

## Failure categories

- EXTRA_ENTITY: 3
- HALLUCINATED_FILTER: 4
- MISSING_ENTITY: 9
- MULTIVALUE_LOSS: 6
- WRONG_INTENT: 14
- WRONG_YEAR: 4
