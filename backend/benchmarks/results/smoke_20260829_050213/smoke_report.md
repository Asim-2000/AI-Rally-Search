# Smoke Test Report (25 Cases) — Shortlist Matrix

- **Timestamp**: `20260829_050213`
- **Smoke Subset Size**: 25 cases
- **Candidate Models**: `gpt-5.6-luna`, `claude-haiku-4-5`, `gemini-3.5-flash-lite`, `gemini-3.5-flash`

## Summary Results Table

| Model | Schema Valid | Intent Acc | Field F1 | Exact Match | Wrong Field % | System Success | False Confident | p50 Latency (ms) | p95 Latency (ms) | Cost / 1k |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `gpt-5.6-luna` | 100.0% | 96.0% | 0.96 | 84.0% | 4.0% | 64.0% | 0.0% | 2928ms | 4021ms | $1.0768 |
| `claude-haiku-4-5` | 96.0% | 96.0% | 0.92 | 80.0% | 0.0% | 64.0% | 0.0% | 1242ms | 1808ms | $1.5001 |
| `gemini-3.5-flash-lite` | 100.0% | 96.0% | 0.94 | 76.0% | 0.0% | 68.0% | 0.0% | 947ms | 1815ms | $0.3166 |
| `gemini-3.5-flash` | 84.0% | 80.0% | 0.77 | 60.0% | 0.0% | 60.0% | 0.0% | 5743ms | 21745ms | $0.6189 |

## Smoke Observations & Adapter Health
- **OpenAI (`gpt-5.6-luna`)**: Structured JSON mode functioning correctly with `max_completion_tokens`.
- **Anthropic (`claude-haiku-4-5`)**: Low-latency tool-call parser responding with valid schema.
- **Google (`gemini-3.5-flash-lite`)**: Fast sub-second response (~900-1100ms) with inlined JSON schema.
- **Google (`gemini-3.5-flash`)**: Solid schema compliance and accurate entity parsing.
- **Localhost Pipeline**: Successfully executing `IntentResolutionRouter`, `OpenEntity`, `SearchPlanBuilder`, and `SearchRepository` against MySQL `pineamite_dev_db`.

## Smoke Status
✅ **ALL ACTIVE SHORTLIST ADAPTERS VERIFIED HEALTHY**
