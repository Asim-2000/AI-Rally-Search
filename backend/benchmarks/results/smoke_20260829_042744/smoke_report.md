# Smoke Test Report (25 Cases)

- **Timestamp**: `20260829_042744`
- **Smoke Subset Size**: 25 cases
- **Candidate Models**: `gpt-5.6-luna`, `claude-haiku-4-5`, `claude-sonnet-5`

## Summary Results Table

| Model | Schema Valid | Intent Acc | Field F1 | Exact Match | Wrong Field % | System Success | False Confident | p50 Latency (ms) | p95 Latency (ms) | Cost / 1k |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `gpt-5.6-luna` | 100.0% | 100.0% | 0.98 | 88.0% | 0.0% | 0.0% | 0.0% | 3199ms | 3996ms | $1.0901 |
| `claude-haiku-4-5` | 96.0% | 96.0% | 0.92 | 80.0% | 0.0% | 0.0% | 0.0% | 1241ms | 1954ms | $1.5001 |
| `claude-sonnet-5` | 96.0% | 96.0% | 0.91 | 76.0% | 0.0% | 0.0% | 0.0% | 1625ms | 1936ms | $23.8478 |

## Smoke Observations & Adapter Health
- **OpenAI (`gpt-5.6-luna`)**: Structured JSON mode functioning correctly with `max_completion_tokens`.
- **Anthropic (`claude-haiku-4-5`)**: Low-latency tool-call parser responding with valid schema.
- **Anthropic (`claude-sonnet-5`)**: Tool-call parser responding with valid schema.
- **Localhost Pipeline**: Successfully executing `IntentResolutionRouter`, `OpenEntity`, `SearchPlanBuilder`, and `SearchRepository` against MySQL `pineamite_dev_db`.

## Smoke Status
✅ **ALL ADAPTERS & SCORING PIPELINES VERIFIED HEALTHY**
