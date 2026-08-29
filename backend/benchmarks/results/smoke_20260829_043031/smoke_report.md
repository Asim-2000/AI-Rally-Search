# Smoke Test Report (25 Cases)

- **Timestamp**: `20260829_043031`
- **Smoke Subset Size**: 25 cases
- **Candidate Models**: `gpt-5.6-luna`, `claude-haiku-4-5`, `claude-sonnet-5`

## Summary Results Table

| Model | Schema Valid | Intent Acc | Field F1 | Exact Match | Wrong Field % | System Success | False Confident | p50 Latency (ms) | p95 Latency (ms) | Cost / 1k |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `gpt-5.6-luna` | 100.0% | 96.0% | 0.95 | 80.0% | 4.0% | 64.0% | 0.0% | 2933ms | 3922ms | $1.0806 |
| `claude-haiku-4-5` | 96.0% | 96.0% | 0.92 | 80.0% | 0.0% | 64.0% | 0.0% | 1200ms | 2303ms | $1.5001 |
| `claude-sonnet-5` | 92.0% | 92.0% | 0.88 | 76.0% | 0.0% | 56.0% | 0.0% | 1648ms | 9532ms | $23.9222 |

## Smoke Observations & Adapter Health
- **OpenAI (`gpt-5.6-luna`)**: Structured JSON mode functioning correctly with `max_completion_tokens`.
- **Anthropic (`claude-haiku-4-5`)**: Low-latency tool-call parser responding with valid schema.
- **Anthropic (`claude-sonnet-5`)**: Tool-call parser responding with valid schema.
- **Localhost Pipeline**: Successfully executing `IntentResolutionRouter`, `OpenEntity`, `SearchPlanBuilder`, and `SearchRepository` against MySQL `pineamite_dev_db`.

## Smoke Status
✅ **ALL ADAPTERS & SCORING PIPELINES VERIFIED HEALTHY**
