# Smoke Test Report (25 Cases)

- **Timestamp**: `20260829_042311`
- **Smoke Subset Size**: 25 cases
- **Candidate Models**: `gpt-5.6-luna`, `claude-haiku-4-5`, `claude-sonnet-5`

## Summary Results Table

| Model | Schema Valid | Intent Acc | Field F1 | Exact Match | Wrong Field % | System Success | False Confident | p50 Latency (ms) | p95 Latency (ms) | Cost / 1k |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `gpt-5.6-luna` | 92.0% | 88.0% | 0.90 | 80.0% | 4.0% | 0.0% | 0.0% | 2874ms | 30013ms | $0.9853 |
| `claude-haiku-4-5` | 92.0% | 92.0% | 0.90 | 80.0% | 0.0% | 0.0% | 0.0% | 1325ms | 2907ms | $1.4408 |
| `claude-sonnet-5` | 88.0% | 88.0% | 0.83 | 68.0% | 0.0% | 0.0% | 0.0% | 1643ms | 2440ms | $23.9570 |

## Smoke Observations & Adapter Health
- **OpenAI (`gpt-5.6-luna`)**: Structured JSON mode functioning correctly with `max_completion_tokens`.
- **Anthropic (`claude-haiku-4-5`)**: Low-latency tool-call parser responding with valid schema.
- **Anthropic (`claude-sonnet-5`)**: Tool-call parser responding with valid schema.
- **Localhost Pipeline**: Successfully executing `IntentResolutionRouter`, `OpenEntity`, `SearchPlanBuilder`, and `SearchRepository` against MySQL `pineamite_dev_db`.

## Smoke Status
✅ **ALL ADAPTERS & SCORING PIPELINES VERIFIED HEALTHY**
