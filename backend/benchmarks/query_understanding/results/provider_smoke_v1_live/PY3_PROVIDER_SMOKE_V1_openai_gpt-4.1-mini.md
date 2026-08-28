# PY-3 Query Understanding BASELINE_V1

- Fixture: `PY3_PROVIDER_SMOKE_V1` (15 cases, SHA-256 `024b9615cb099314d1224e1c743e1cd6ef13a56e9e938dd74ac41966649cdf95`)
- Provider/model: `openai` / `gpt-4.1-mini`
- Prompt/schema/few-shot: `query_understanding_prompt_v1` / `search_query_py1_v1` / `query_understanding_few_shot_v1`

| Metric | Value |
|---|---:|
| SearchQuery accuracy | 80.00% |
| Intent accuracy | 100.00% |
| Field precision / recall / F1 | 93.10% / 90.00% / 91.53% |
| Schema success | 100.00% |
| Hallucinated-filter rate | 13.33% |
| End-to-end exact | not run |
| Latency avg / p50 / p95 / max (ms) | 2154.1 / 2133.6 / 2900.3 / 2900.3 |
| Retries | 0 |
| Cost/query | not configured |

## Failure categories

- EXTRA_ENTITY: 2
- MISSING_ENTITY: 2
- MULTIVALUE_LOSS: 1
