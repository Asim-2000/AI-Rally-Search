# PY-3 implementation and baseline report

Status: **PY-3 BLOCKED** for acceptance. The implementation and hermetic
176-case mock baseline are complete, but live target-model, canonical-resolution,
and eligible live-DB benchmark results have not been produced in this environment.
No PY-1/PY-2 Entity Search or deterministic repository code was changed.

## A–F. Audit, architecture, and frozen artifacts

| Dart component | Python component | Notes |
|---|---|---|
| `LlmQueryParser` / `SearchContext` | `QueryUnderstandingProvider` | PY-3 accepts query plus language only; conversational context is deliberately excluded. |
| `OpenAIQueryParser` | `OpenAIProvider` | Chat Completions JSON Schema; reasoning-model temperature exception retained. |
| `GeminiQueryParser` | `GeminiProvider` | JSON MIME type plus response JSON schema. |
| `AnthropicQueryParser` | `AnthropicProvider` | Forced `rally_search_query` tool use. |
| `MockLlmQueryParser` | `MockProvider` | Deterministic hermetic contract/smoke adapter. |
| `FallbackQueryParser` | service retry policy only | No cross-model router added; model comparisons remain independent. |
| `QueryUnderstandingSpec` | `prompt.py` | Current single-turn Dart semantics ported; PY-4 conversation sections removed. |
| `QueryOutputValidator` | `validator.py` | Python is intentionally stricter: unknown fields and invented IDs fail instead of being silently discarded/coerced. |
| `QueryParseResult` | `QueryUnderstandingResult` | Adds explicit failure type, attempts, separated latency, usage, and version fields. |
| Dart evaluator/report formatter | `benchmark.py` and runner | JSON/JSONL truth, Markdown summary, configurable models/pricing, optional canonical/DB hooks. |

- Authoritative schema: existing Pydantic `SearchQuery`, version `search_query_py1_v1`.
- Prompt: `query_understanding_prompt_v1`; few-shot: `query_understanding_few_shot_v1`.
- Golden fixture: `dart_golden_176_v1`, 176 cases, SHA-256
  `dd1773465906104983f8dfc46209104f18991b724af47f9cd2a36621b2139df8`.
- The fixture contains all nine intents. Ten legacy cases have no expected intent
  because the current Dart corpus marks clarification behavior; they remain frozen
  and are not silently removed, although clarification/conversation is outside PY-3.
- Implemented provider matrix: arbitrary OpenAI, Gemini/Google, Anthropic, and mock
  entries with model, temperature, max tokens, timeout, retries, structured-output,
  seed, reasoning, base URL, and provider parameter overrides.
- Tested matrix in this environment: `mock / mock-parser-v1` only.

## G–U. BASELINE_V1 results

| Measure | Mock baseline |
|---|---:|
| Cases | 176 |
| SearchQuery accuracy | 11.93% |
| Intent accuracy | 51.70% |
| Field precision / recall / F1 | 89.22% / 46.42% / 61.07% |
| Schema-valid output | 100.00% |
| Hallucinated-filter rate | 0.00% |
| PersonRole accuracy | Not separately meaningful for the smoke mock |
| Canonical-resolution accuracy | Not run |
| Correct confident / clarification / no match / wrong confident | Not run |
| End-to-end DB exact correctness | Not run |
| Zero-result correctness | Not run |
| Latency avg / p50 / p95 / max | 0.014 / 0.013 / 0.017 / 0.118 ms |
| Tokens | Synthetic mock: 15 input, 25 output, 40 total/query |
| Cost | Not computed; pricing snapshot is deliberately empty |
| Retries | 0 |

Failure categories: 85 `WRONG_INTENT`, 113 `MISSING_ENTITY`, 26
`MULTIVALUE_LOSS`, and 2 `WRONG_YEAR`. Counts overlap by design. Provider errors,
timeouts, invalid JSON, schema failures, semantic failures, retry types, raw output,
usage, and separated latency are retained per record.

## V–X. Strengths, semantic differences, limitations

- The mock is a hermetic smoke adapter, not a candidate model. Its useful property
  is deterministic, schema-valid behavior; its extraction coverage is deliberately
  too small for selection.
- Python rejects unknown fields, unsupported actions, invalid enums/ranges, and
  model-supplied `driverIds`. Current Dart validation is more forgiving and can
  normalize or discard some malformed content. This is the principal deliberate
  Dart/Python boundary difference required by PY-3's strict Pydantic gate.
- Provider mechanics differ (OpenAI schema, Gemini response schema, Anthropic tool)
  but all receive the same prompt semantics and Pydantic contract.
- The API adds only `POST /v1/query-understanding`; `POST /v1/search` and Flutter
  production routing are unchanged. No SQL or repository handle is exposed to a model.
- Canonical and DB levels are represented by evaluator hooks and record/score fields,
  but measured results require live Entity Search/DB wiring and eligible expected DB
  truths. The frozen 176 fixture currently contains parser expectations, not canonical
  ID or DB result-set truth for every case.
- Live provider tests/runs are opt-in and require credentials. No provider/model
  winner can responsibly be recommended from the mock baseline.

Recommendation: **PY-3 BLOCKED**. Configure the intended live model matrix, add or
associate frozen canonical/DB truth for eligible cases without changing parser
answers, run and preserve those `BASELINE_V1` artifacts, then review model-specific
accuracy, safety, latency, usage, and cost before proceeding to PY-4.
