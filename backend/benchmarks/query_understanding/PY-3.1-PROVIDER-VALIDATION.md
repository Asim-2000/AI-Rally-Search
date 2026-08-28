# PY-3.1 live provider validation

Status: **GO TO PY-4**

`FINAL_MODEL_BENCHMARK = DEFERRED`

This is a functional provider/integration validation, not a model bake-off or
production-model recommendation. No alternate model was called, no prompt was
tuned from the frozen-176 scores, and no PY-4 work was started.

## Provider configuration

- Provider: OpenAI
- Exact model ID: `gpt-4.1-mini`
- API: Chat Completions with strict JSON Schema Structured Outputs
- Temperature: `0.0`
- Max output tokens: `1024`
- Timeout: `30s`
- Maximum retries: `2`
- Prompt: `query_understanding_prompt_v1`
- Schema: `search_query_py1_v1`
- Few-shot: `query_understanding_few_shot_v1`

The OpenAI Models API confirmed that this project can access the selected model.
The official API reference documents Chat Completions and JSON Schema structured
output: https://developers.openai.com/api/reference/resources/chat/subresources/completions

## Integration fixes proven by the live path

Two provider-adapter defects were found and fixed before the validation run:

1. OpenAI strict schemas require every property to appear in `required`.
2. Pydantic emits `default` annotations beside `$ref`, which OpenAI strict schema
   rejects. Defaults are now stripped from only the provider schema artifact;
   runtime Pydantic defaults and SearchQuery semantics are unchanged.

The standalone benchmark runner also now obtains credentials/base URLs through
the application `Settings` fallback when they are present in `.env` but not in
the shell environment. No credential is copied into source or result files.

Two single-turn prompt rules omitted during the original Python parity port were
restored before scoring: a single year uses `years: [year]`, and absent pagination
uses `limit=20, offset=0`. These are Dart-parity corrections, not score-driven tuning.

## Representative smoke

Fixture: `PY3_PROVIDER_SMOKE_V1`, 15 cases covering all nine intents, `ANY`,
`DRIVER`, and `CO_DRIVER`, single year, range, multi-value filters, rallies,
drivers, stages, actions, uploaders, and German input.

| Metric | Result |
|---|---:|
| Schema success | 100% (15/15) |
| Intent accuracy | 100% (15/15) |
| Exact expected-field accuracy | 80% (12/15) |
| Field precision / recall / F1 | 93.10% / 90.00% / 91.53% |
| PersonRole | 100% (3/3) |
| Retries | 0 |
| Usage | 19,247 input; 1,286 output; 20,533 total tokens |
| Latency average / p50 / p95 / max | 2,154 / 2,134 / 2,900 / 2,900 ms |

Observed extraction differences were preserved without tuning: two instances
of `Moonraker Rally` became `Moonraker`, and one `SS2` mention was placed in
`stageNames` instead of `stageNumbers`.

## Frozen 176 — PY3_PROVIDER_VALIDATION_V1

Fixture: `dart_golden_176_v1`, SHA-256
`dd1773465906104983f8dfc46209104f18991b724af47f9cd2a36621b2139df8`.
It was executed exactly once for this validation.

| Metric | Result |
|---|---:|
| Cases executed | 176 |
| Schema success | 100% |
| Provider failures | 0 |
| Retries | 0 |
| SearchQuery exact expected-field accuracy | 83.52% |
| Intent accuracy | 92.05% |
| Field precision / recall / F1 | 97.44% / 95.02% / 96.21% |
| Hallucinated-filter rate | 3.98% |
| Latency average / p50 / p95 / max | 1,945 / 1,843 / 2,656 / 5,729 ms |
| Usage | 225,760 input; 15,058 output; 4,608 cached; 240,818 total tokens |

Failure classifications overlap: 14 `WRONG_INTENT`, 9 `MISSING_ENTITY`, 6
`MULTIVALUE_LOSS`, 4 `WRONG_YEAR`, 4 `HALLUCINATED_FILTER`, and 3 `EXTRA_ENTITY`.
The frozen fixture does not carry expected `personRole` fields, so role accuracy
is reported from the explicit smoke cases rather than invented for this run.

Authoritative raw artifacts:

- `results/PY3_PROVIDER_VALIDATION_V1/PY3_PROVIDER_VALIDATION_V1_openai_gpt-4.1-mini.json`
- `results/PY3_PROVIDER_VALIDATION_V1/PY3_PROVIDER_VALIDATION_V1_openai_gpt-4.1-mini.jsonl`
- `results/PY3_PROVIDER_VALIDATION_V1/PY3_PROVIDER_VALIDATION_V1_openai_gpt-4.1-mini.md`

## Deterministic pipeline validation

The 15 recorded smoke SearchQueries were reused without further model calls:

`SearchQuery -> live PY-2 index -> resolver -> PY-1 repository -> live MySQL`

- Live entity index: 11,244 entities; build time 2,101 ms.
- Canonical confident: 10.
- Clarification: 5.
- No match: 0.
- Repository/MySQL executions: 10.
- Final result IDs, counts, resolved queries, canonical IDs/outcomes, and separated
  Entity Search/DB latency are retained in
  `results/PY3_PROVIDER_VALIDATION_V1/live_pipeline.json`.
- Clarifications stopped before DB execution, proving that the model cannot bypass
  canonical Entity Search/resolver safety.

A real 1 ms timeout probe produced `TIMEOUT`, two attempts, one visible provider
retry, zero schema retries, and unavailable usage rather than fabricated token
counts. Unit/provider-contract tests also cover provider errors, invalid JSON,
schema errors, semantic errors, and retry behavior. Fourteen focused tests pass.

## Architecture and deferral

Provider/model, temperature, reasoning, seed, structured-output mode, arbitrary
provider parameters, timeouts, retries, and separately versioned pricing remain
configuration-driven. No provider-specific SDK detail leaks into repositories or
Entity Search.

`FINAL_MODEL_BENCHMARK = DEFERRED` until PY-4 conversation migration, PY-5 voice
migration, and PY-6 Flutter/full-pipeline cutover. That later benchmark should cover
single-turn semantics, canonical/DB correctness, conversation, multilingual input,
human voice, latency, reliability, usage, and cost across the chosen model matrix.

Acceptance conclusion: the real OpenAI provider, strict structured SearchQuery,
frozen-176 execution, canonical/DB path, failure telemetry, usage, and latency are
all operational while the provider-neutral architecture remains intact.

**GO TO PY-4**
