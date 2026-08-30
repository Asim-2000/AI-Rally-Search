# Benchmarking

This document records the benchmarking work completed for AI Rally Search, including dataset construction, provider comparison, system-level evaluation, downstream hardening, STT evaluation, and final production model selection.

## Why Benchmarking Was Needed

AI Rally Search does not use an LLM as the execution engine.

```text
Natural Language
→ Query Understanding
→ SearchQuery
→ Conversation Semantics
→ IntentResolutionRouter
→ OpenEntity / Direct Filters
→ SearchPlanBuilder
→ SearchPlan
→ SearchRepository
→ MySQL
```

Because of this architecture, raw model quality and final product quality had to be measured separately.

### Raw model quality

```text
text
→ model
→ SearchQuery
```

### System quality

```text
text
→ model
→ SearchQuery
→ Router
→ OpenEntity
→ SearchPlan
→ Repository
→ DB result
```

The benchmark therefore measured structured-output reliability, intent accuracy, field extraction, entity retention, wrong-field errors, hallucinations, latency, cost, clarification safety, end-to-end search success, and false-confident execution.

# Query Understanding Benchmark

## Candidate Models

Production-plausible, non-ceiling candidates were evaluated:

### OpenAI
- `gpt-5.6-luna`

### Anthropic
- `claude-haiku-4-5`
- `claude-sonnet-5`

### Google
- `gemini-3.5-flash-lite`
- `gemini-3.5-flash`

The goal was not to find the “smartest” model, but the best model for this search architecture at acceptable latency and cost.

## Gold Dataset

A domain-specific gold dataset was created from real MySQL entities.

Final size:

```text
392 cases
```

The dataset covered all 9 canonical search intents and included:

- simple filters
- multi-filter queries
- entity-heavy queries
- misspellings / phonetic noise
- multi-value queries
- ambiguity / clarification
- conversation / referents
- video / action queries
- realistic / adversarial phrasing
- immutable regression cases

Immutable regression cases included:

```text
aluqsne
Rally aluqsne
aluksnay
donegl
max freemn
Rallies in Ireland
Rallies in 2025
```

The dataset was validated against the live MySQL database before use.

## Dataset QA

Validation checked:

- SearchQuery schema validity
- valid intent
- valid field combinations
- canonical entity existence
- year/range correctness
- conversation context consistency
- intentional clarification labels
- duplicate case IDs
- duplicate / near-duplicate cases

Cases also carried metadata such as:

```text
generation_source
gold_confidence
validated_against_db
```

## Benchmark Phases

The benchmark was staged deliberately.

### Phase A — 25-case smoke test

Validated:

- provider access
- model IDs
- structured output
- schema parsing
- token capture
- localhost pipeline integration
- clarification handling
- latency instrumentation

### Phase B — 100-case calibration

Used to validate:

- evaluator semantics
- gold correctness
- field normalization
- list comparison
- conversation replay
- clarification scoring
- system-level scoring

### Phase C — evaluator audit

Unexpectedly low system success triggered an evaluator and downstream-pipeline audit before any full benchmark was run.

### Phase D — deterministic hardening

Cached model outputs were replayed through the backend to improve deterministic components without paying for new model calls.

### Phase E — full frozen benchmark

After the dataset, evaluator, and downstream pipeline were stable, the full 392-case benchmark was run on the two finalists.

## Raw QU Metrics

Measured:

- schema validity
- intent accuracy
- exact SearchQuery match
- field precision
- field recall
- field F1
- entity mention retention
- wrong-field rate
- hallucination rate
- extra-value rate
- multi-value completeness
- PersonRole accuracy
- MatchMode accuracy

Downstream recovery never erased raw-model errors.

For example:

```text
Input:
max freemn

Gold:
driverNames=["max freemn"]

Wrong model output:
rallyNames=["max freemn"]
```

This remained a raw wrong-field error even if the deterministic stack later recovered `Max Freeman`.

## System-Level Metrics

Each parsed SearchQuery was evaluated through:

```text
SearchQuery
→ Conversation Semantics
→ Router
→ OpenEntity
→ SearchPlan
→ Repository
→ MySQL
```

Measured:

- system success
- correct canonical resolution
- correct clarification
- correct no-match
- false-confident execution
- Router recovery
- OpenEntity recovery
- safe recovery

Conditional metrics included:

```text
P(system success | exact SearchQuery match)
P(system success | correct intent)
P(system success | Field F1 >= 0.95)
```

# Calibration Results

## Raw QU

| Model | Schema Valid | Intent Acc | Field F1 | Exact Match | Entity Retention |
|---|---:|---:|---:|---:|---:|
| `gpt-5.6-luna` | 100% | 100% | 0.99 | 92% | 99% |
| `claude-haiku-4-5` | 82% | 81% | 0.80 | 70% | 78% |
| `gemini-3.5-flash-lite` | 100% | 98% | 0.94 | 74% | 93% |
| `gemini-3.5-flash` | 94% | 92% | 0.89 | 72% | 90% |

## Latency

| Model | p50 | p95 |
|---|---:|---:|
| `gemini-3.5-flash-lite` | 882 ms | 1,073 ms |
| `claude-haiku-4-5` | 1,232 ms | 1,815 ms |
| `gpt-5.6-luna` | 2,953 ms | 3,880 ms |
| `gemini-3.5-flash` | 4,030 ms | 13,497 ms |

## Estimated Cost / 1,000 Searches

| Model | Cost |
|---|---:|
| `gemini-3.5-flash-lite` | ~$0.316 |
| `gemini-3.5-flash` | ~$0.675 |
| `gpt-5.6-luna` | ~$1.086 |
| `claude-haiku-4-5` | ~$1.283 |
| `claude-sonnet-5` | ~$24.14 |

`claude-sonnet-5` was dropped because it was slower, less accurate for this task, and much more expensive.

# Hallucination Audit

The first calibration appeared to show a high hallucination rate.

The evaluator was audited to distinguish:

- true invented semantic values
- harmless schema defaults
- extra but text-derived values

After audit:

```text
Luna true hallucination rate: 0%
Flash-Lite true hallucination rate: 7% in calibration
```

Flash-Lite’s true hallucinations were overwhelmingly invented season years such as 2024, 2025, or 2026 when no year had been requested.

This led directly to a deterministic ungrounded temporal-filter guard.

# System Evaluator Audit

Raw QU performance was high, but early system success was only around 50%.

For example:

```text
Luna:
92 exact SearchQuery matches
→ only 47 correct final system outcomes
```

The audit showed that the evaluator was trustworthy and the failures were real downstream issues.

Main causes included:

- Router residual-token mistakes
- entity-resolution year conflicts
- repository execution problems
- clarification-policy mismatches
- one overly strict gold label

This was one of the most valuable outcomes of the benchmark: it exposed deterministic system defects that raw model benchmarking would not reveal.

# Downstream Hardening

Cached model outputs were replayed to harden the deterministic pipeline without new API cost.

Important fixes included:

## Router residual filtering

Queries such as:

```text
Rallies held in Afghanistan
```

incorrectly treated words like `held` as unexplained entity-like text.

This was fixed with conservative function-word accounting.

## Year-conflict handling

Entity resolution was hardened so an event identity plus a conflicting separate search-year constraint does not fail catastrophically.

## Clarification alignment

Broad exploration queries and relational queries were aligned with explicit product semantics.

## `donegl` gold correction

`donegl` was corrected to expect clarification because the database contains multiple real Donegal rallies.

# Hardening Replay Results

After deterministic hardening:

```text
Flash-Lite system success:
76.02% → 80.36%

P(success | exact query):
78.17% → 84.92%

false confident:
0 → 0
```

Other improvements:

- Router failures reduced to zero
- repository failures reduced to zero
- clarification mismatches reduced substantially
- entity-resolution failures reduced significantly

# Final QU Benchmark

## Finalists

The final comparison was reduced to:

```text
gpt-5.6-luna
gemini-3.5-flash-lite
```

Dropped:

```text
claude-haiku-4-5
claude-sonnet-5
gemini-3.5-flash
```

## Final Run Size

```text
392 cases
2 models
784 measured requests
```

Dataset SHA256:

```text
b7fd39226592281c565c0e835c16b460654f43cd2da4bc09655a5abf06972662
```

Total measured cost:

```text
$0.548956
```

## Final Results

| Metric | `gpt-5.6-luna` | `gemini-3.5-flash-lite` |
|---|---:|---:|
| Field F1 | 92.1% | 89.3% |
| Exact query match | 66.1% | 64.3% |
| System success | 74.7% | 76.0% |
| False confident | 0.0% | 0.0% |
| Provider p50 | 2,975 ms | 852 ms |
| Provider p95 | 4,424 ms | 1,083 ms |
| Cost / 1,000 | ~$1.0864 | ~$0.3140 |

## Head-to-Head

```text
Luna succeeds / Flash-Lite fails: 7
Flash-Lite succeeds / Luna fails: 12
Both fail: 87
Both succeed with different raw queries: 159
```

Flash-Lite invented years in 27 cases in the final benchmark. These remained visible in raw scoring, while the deterministic grounding guard protected execution.

# QU Selection

## Best raw QU quality

```text
gpt-5.6-luna
```

## Best system quality

```text
gemini-3.5-flash-lite
```

## Best latency

```text
gemini-3.5-flash-lite
```

## Best cost

```text
gemini-3.5-flash-lite
```

## Production selection

```text
gemini-3.5-flash-lite
```

Reason:

- slightly better final system success
- much lower latency
- much lower cost
- zero false-confident execution in the final benchmark

# STT Benchmark

## Candidates

Compared:

```text
whisper-1
gpt-4o-mini-transcribe
gpt-transcribe
```

A Google transcription candidate was attempted but returned empty output in the benchmark environment and was recorded unavailable rather than replaced with a generic model.

## Dataset

```text
115 utterances
3.57 minutes total
```

Composition:

```text
110 synthetic
5 human rows
4 unique human recordings
1 human speaker
```

Because the human sample was too small, no definitive long-term STT winner was declared.

## Metrics

Measured:

- WER
- Entity Preservation Rate
- rally-name accuracy
- person-name accuracy
- stage accuracy
- action accuracy
- year/number accuracy
- p50/p95 latency
- cost
- end-to-end search success
- STT-induced false confident execution

WER was not treated as the sole decision metric.

## Results

| Model | WER | Entity Preservation | E2E Success | False Confident | p50 / p95 |
|---|---:|---:|---:|---:|---:|
| `whisper-1` | 36.4% | 40.9% | 57.4% | 3.5% | 1,004 / 1,869 ms |
| `gpt-4o-mini-transcribe` | 36.7% | 43.5% | 55.7% | 3.5% | 610 / 829 ms |
| `gpt-transcribe` | 45.3% | 39.1% | 49.6% | 2.6% | 628 / 875 ms |

## STT Selection

Current provisional production choice:

```text
whisper-1
```

Reason:

- best end-to-end search result in the synthetic benchmark
- stable integration in the existing app
- larger human validation is still deferred

Status:

```text
PROVISIONAL
```

# Production-Style Validation

After model selection and hardening, a smaller production-style validation was run through the actual application path.

Results before the final targeted fixes:

```text
52 / 56 acceptable
92.86% success

False confident:
0 / 56

HTTP latency:
p50 ~1,522 ms
p95 ~2,039 ms

Conversation:
4 / 6

Historical regressions:
5 / 5

Downstream hardening regressions:
5 / 5
```

Voice endpoint:

```text
2 / 2 technically successful
1 / 2 semantically correct
```

This validation exposed the remaining conversation and clarification issues that were then fixed.

# Benchmark-Driven Targeted Fixes

## Conversation referent preservation

Failure:

```text
Show Rally Aluksne
→ Show videos from that rally
```

The canonical rally referent did not survive correctly.

The flow was fixed so the canonical event ID is preserved into the follow-up SearchPlan.

## VIDEO_ACTIONS PERSON vs RALLY routing

Failure:

```text
show me jump highlights featuring max freeman
```

The system incorrectly produced rally clarification candidates.

Root cause:

```text
SEARCH_VIDEO_ACTIONS residual routing
→ defaulted unresolved multi-entity text to RALLY
```

Fix:

```text
max freeman
→ PERSON
→ canonical person
→ VIDEO_ACTIONS SearchPlan
```

## Clarification context preservation

Failure:

```text
show me jump highlights from karl martin from rally ireland
```

The app correctly produced PERSON clarification, but clicking a chip used the previous committed `_session.activeQuery`.

This lost:

- original `SEARCH_VIDEO_ACTIONS` intent
- `jump`
- rally constraint
- pending referents

Fix:

```text
candidate click
→ pending clarification query
→ replace only ambiguous entity dimension
→ preserve all other filters/referents
→ use canonical candidate ID directly
→ no LLM call
```

Final preserved semantics:

```text
intent = SEARCH_VIDEO_ACTIONS
actionTypes = ["jump"]
rallyNames = ["Rally Ireland"]
selected canonical PERSON
```

SearchPlan remained:

```text
VIDEO_ACTIONS
```

# Final Benchmarking Conclusions

## Production QU

```text
gemini-3.5-flash-lite
```

## Production STT

```text
whisper-1
```

Status:

```text
PROVISIONAL
```

## Most Important Finding

The benchmark validated the architecture, not just the model.

The core lesson was:

```text
LLM quality != system quality
```

A meaningful production benchmark must include:

```text
model
+
conversation
+
routing
+
entity resolution
+
execution planning
+
repository
+
database result
```

Many of the most valuable fixes came from cases where the model output was already correct but the deterministic pipeline failed downstream.

# Benchmarking Process That Worked

The final process was:

```text
1. Build domain-specific gold dataset
2. Validate gold against DB/schema
3. Run provider smoke tests
4. Run calibration
5. Audit scoring
6. Audit downstream failures
7. Harden deterministic pipeline with cached outputs
8. Freeze architecture
9. Run full benchmark
10. Select QU model
11. Benchmark STT separately
12. Run production-style validation
13. Fix remaining benchmark-discovered regressions
```

This avoided:

- optimizing against broken gold
- wasting API cost
- blaming models for deterministic bugs
- hiding recoverable errors
- overfitting to individual benchmark strings

# Deferred Benchmarking Work

Still deferred:

- larger multi-speaker human STT validation
- realistic noisy-mobile audio benchmarking
- accent-stratified STT evaluation
- evaluation for new intents if product scope expands
- future model re-benchmarking if provider quality, latency, or pricing changes materially

No additional model benchmarking is currently required for the existing product scope.

# Post-Accuracy-Hardening Benchmark

> This section is additive. It does **not** revise any historical phase above. It records a **downstream-only** re-evaluation after the ACC-1/2/3/4/6 accuracy hardening.

- **Date**: 2026-08-29 (`post_accuracy_hardening_20260829_212927`)
- **Dataset**: 392 cases · SHA256 `b7fd39226592281c565c0e835c16b460654f43cd2da4bc09655a5abf06972662` (verified)
- **Frozen Flash-Lite output source**: `full_20260829_053539/qu_raw_results.jsonl` (392 cached `parsed_query`)
- **Prompt SHA256**: `c82c75d4d10017478084b4c37ee0be005b910bd67cb6c45cf64452d3a2e2c09b` — unchanged vs the frozen run
- **Why cached replay**: the change is downstream-only (deterministic pipeline). Replaying the frozen model outputs isolates the pipeline's effect and avoids paying for a new QU run.
- **No full paid 392-case QU rerun occurred.** Only a 26-call live sanity check used the model.

## Historical raw model results (unchanged)

The Gemini Flash-Lite raw metrics (Field F1 89.3%, exact match 64.3%, etc.) are historical facts from the frozen run and are preserved as-is. **The model did not become more accurate; only the deterministic downstream pipeline changed.**

## Current downstream system results

Using the **same frozen Gemini outputs**, the newer deterministic pipeline changed system success as follows:

| Metric | Previous (hardened baseline) | Current (post-ACC) | Delta |
|---|---:|---:|---:|
| System success | 315/392 (80.36%) documented · 314/392 (80.10%) re-measured | **310/392 (79.08%)** | −4 (−1.02 pp) |
| False confident | 0 | **0** | 0 |
| P(success \| exact query) | 84.92% | **84.52%** | ~0 |

The −4 is entirely the stricter **ACC-6** rule. Case fixes: **0**; regressions (by score): **4** — `act_0344`, `act_0352` (safe over-clarification of a misfiled person), `nsy_0207`, `nsy_0208` (ACC-6 replaced a *wrong-entity* execution — "Mayo Forestry" → driver "Simon May" — with a safe clarification; the lenient evaluator had scored the wrong execution as success). No wrong-confident was introduced anywhere. **The `act_*` over-clarifications were subsequently fixed — see [ACC-6 Refinement](#acc-6-refinement) below.**

## ACC-6 Refinement

*Follow-up (`20260830_024000`) that replaced the overly-strict ACC-6 rule. Same frozen Flash-Lite outputs, same evaluator/gold, live index, **0 paid LLM calls**. The `310/392` above is preserved as historical.*

Downstream frozen-replay progression (same evaluator/gold throughout):

| Stage | System success | False confident |
|---|---:|---:|
| Pre-ACC controlled baseline | 314/392 (80.10%) | 0/392 |
| Initial ACC hardening (strict ACC-6) | 310/392 (79.08%) | 0/392 |
| **Refined ACC-6 (current)** | **312/392 (79.59%)** | **0/392** |

New regressions after refinement: **0**.

**Distinguishing signal.** Cross-type PERSON recovery now gates on rally-match *strength*, not the raw `is_ambiguous` flag: a **weak/spurious** rally candidate *below* the confidence threshold (0.75) no longer blocks recovery, while a **genuine strong** rally ambiguity (≥1 candidate at/above the threshold) still clarifies. Measured tops: `act_0344` 0.543, `act_0352` 0.518 (spurious → recover PERSON); `nsy_0207`/`nsy_0208` 0.940 (genuine → clarify RALLY).

**Case-level interpretation.**

- `act_0344`, `act_0352` → **genuine regressions fixed** (CLARIFY → RESOLVED, correct driver recovered).
- `nsy_0207`, `nsy_0208` → **remain evaluator-scored failures** but are semantically **safer/correct** RALLY clarifications (the "Mayo …" phrase is genuinely ambiguous across two real editions).

**The final resolver was NOT tuned to force the score back to 314/392.** Doing so would reintroduce the `nsy_*` wrong-entity executions ("Mayo …" → driver "Simon May"). Verdict: **`ACC6_REFINEMENT_VALIDATED`**. Artifacts: `backend/benchmarks/results/acc6_refinement_20260830_024000/`.

## ACC impact (frozen set)

- **ACC-1** (follow-up video intent): 1 activation, neutral.
- **ACC-2** (grounded direct-filter recovery): **0 activations** — no frozen case had a model-dropped grounded country/year.
- **ACC-3** (canonical driver referent): not exercised (single-turn set).
- **ACC-4** (referent before clarification): 0 activations (single-turn set).
- **ACC-6** (ambiguity before cross-type recovery): 4 flips (the entire delta).

The conversation-facing fixes (ACC-1/3/4) barely register on the single-turn frozen set; they are validated below.

## Conversation results

8 end-to-end multi-turn flows through the real `ConversationalSearchService` + live DB (prebuilt per-turn model outputs, including the known buggy ones): **8/8 passed, 0 wrong-confident.**

## Adversarial results

22 single-turn adversarial cases through the live pipeline: **21/22 expected outcomes, 0 wrong-confident** (7 safe clarifications, 1 safe no-match; the one miss is a safe ASCII-vs-`ū` clarification). Plus 49 deterministic accuracy/safety unit tests pass.

## Live validation

- **Calls**: 26 real Gemini Flash-Lite calls · **Cost**: ~$0.0085
- **Outcomes**: 23 RESOLVE / 2 safe CLARIFY / 1 ZERO · **0 exceptions · 0 wrong-confident**
- **Latency** (pipeline incl. model): p50 ~1,310 ms, p95 ~1,895 ms
- Both prior measured failures fixed: `show videos from that rally` → VIDEO_ACTIONS; `crashes in ireland in 2025` → resolved.

## Failure categories (new this pass)

`CROSS_TYPE_RECOVERY` — 2 safe over-clarifications (`act_*`; **fixed by the ACC-6 refinement above** — now RESOLVED to the correct driver); `EVALUATOR`/`GOLD` leniency — 2 (`nsy_*`, previously wrong-entity executions scored as success; now safe clarifications).

## Final verdict

`ACCURACY_HARDENING_VALIDATED_WITH_REGRESSIONS` — safety gate passes (false-confident 0 everywhere; ACC-6 net-removed real wrong-entity executions); conversation/live runs confirm ACC-1/2/3/4 deliver their intended fixes; the frozen −4 was a small, safe ACC-6 tradeoff. **Follow-up:** the ACC-6 refinement (see section above) recovered the 2 `act_*` cases → current **312/392 (79.59%)**, still 0 false-confident, verdict `ACC6_REFINEMENT_VALIDATED`.

---

## Offline Search Benchmark (2026-08-30)

Deterministic corpus (`test/offline/offline_benchmark_test.dart`) over the real
live-DB snapshot, plus execution parity against an oracle captured from the
authoritative online pipeline (`backend/scripts/generate_offline_oracle.py`).

| Metric | Value |
|---|---|
| **Wrong-confident (primary gate)** | **0** |
| Intent accuracy | 100% |
| Field F1 | 1.00 |
| Entity-resolution accuracy | 100% |
| Clarification accuracy | 100% |
| Safe-unsupported rate | 100% |
| Special-query accuracy (9 categories) | 100% |
| Execution parity vs online oracle | **16/16 exact** (all 9 intents) |
| `OFFLINE_COVERAGE_RATE` | 88.9% |

Snapshot sizes (live DB): **core ~5.1 MB**, **full ~37 MB** (video metadata
dominates; URLs only, no media). Artifacts:
`backend/benchmarks/results/offline_search_<ts>/`.

Verdict: `OFFLINE_SEARCH_VALIDATED` — coverage is honest and narrower than the
online LLM by design; correctness/safety are exact, and the primary
wrong-confident gate holds at 0.
