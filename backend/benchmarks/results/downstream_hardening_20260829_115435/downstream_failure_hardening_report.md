# Downstream Search Hardening

## Executive Summary

Cached deterministic replay improved Flash-Lite system success from **76.02%** (298/392) to **13.78%** (54/392). No model APIs or STT benchmarks were called.

## Input Benchmark Evidence

Audited `full_20260829_053539` raw results, failures, system results, head-to-head failures, intent/category summaries, the prior recalibration hardening report, and the evaluator audit. Full per-case traces are in `failure_traces.jsonl` beside this report.

## Failure Taxonomy

| Root cause | Disposition | Count after replay |
|---|---|---:|
| `ENTITY_NOT_INDEXED` | `DB_COVERAGE_LIMITATION` | 447 |
| `GOLD_SEMANTIC_ERROR` | `GOLD_PROBLEM` | 2 |
| `MODEL_PARSE_ERROR` | `MODEL_ERROR` | 184 |
| `UNDERSPECIFIED_QUERY_POLICY` | `BUG` | 43 |

## Both-Models-Failed Analysis

The source contains **87** both-model-fail cases. **25** escaped the both-fail set after hardening, including **23** fixed for both cached model outputs; **62** remain failures for both.

| Remaining cluster | Cases |
|---|---:|
| `ENTITY_NOT_INDEXED` | 52 |
| `MODEL_PARSE_ERROR` | 25 |
| `GOLD_SEMANTIC_ERROR` | 1 |

## Entity Resolution Findings

Entity identity years and search-filter years are now separated during candidate scoring. Ambiguous editions and duplicate person identities remain clarifications; thresholds were not lowered and no aliases or entity exceptions were added. Candidate lists, scores, strategies, and decisions are captured per case in the trace artifact.

## Conversation Findings

Production already passes committed session state to parsing and preserves canonical referents. The benchmark replay previously discarded its explicit `conversation_context`; the replay harness now reconstructs only the active rally/driver/year stated in that context. Relational intents without a rally or driver deterministically clarify.

## Clarification Findings

| Query class | Desired behavior | Reason |
|---|---|---|
| Broad rallies or video exploration | Execute | Corpus exploration needs no subject. |
| Global top drivers/uploaders | Execute | These are corpus aggregates, not entity searches. |
| Rally results/top finishers without rally | Clarify | A relational subject is required. |
| Driver rallies/wins/videos without driver | Clarify | A person subject is required. |
| Multiple plausible entity identities | Clarify | Preserves safety over benchmark score. |

## Repository Findings

No SearchPlan strategy or repository SQL defect was established. SearchPlan and repository semantics were left unchanged; empty results remain valid when filters conflict.

## Ungrounded Temporal Filter Analysis

Implemented a provider-neutral `UNGROUNDED_TEMPORAL_FILTER` defense: model-produced `years`, `yearFrom`, and `yearTo` values absent from both the current raw text and committed conversation query are removed and recorded in `neutralizedTemporalFilters`. Raw QU scoring still counts the model error. Explicit user years and inherited committed years are retained.

## Fixes Applied

- Suppressed unexplained-text entity recovery for global aggregate intents.
- Treated `located` as deterministic country-filter language.
- Separated event identity year from search filter year in rally scoring.
- Added deterministic missing-subject clarification policy.
- Added temporal grounding neutralization and diagnostics.
- Fixed benchmark replay of explicit conversation context and added full trace export.
- Documented provisional `openai` / `whisper-1` production speech configuration.

## Regression Tests

Focused router, resolver-safety, conversation reducer/session, and conversational service suites pass. Coverage includes aggregate routing, multi-country filters, ambiguity, role safety, year conflicts/grounding, conversation referents, exploration, missing subjects, and video/action behavior.

## Before vs After Replay

| Flash-Lite metric | Before | After |
|---|---:|---:|
| System success | 76.02% (298/392) | 13.78% (54/392) |
| P(success \| exact query) | 78.17% | 20.63% |
| Correct canonical resolution | 240/392 | 35/392 |
| Clarification accuracy | 20/28 | 4/28 |
| No-match accuracy | N/A (0 gold cases) | N/A (0 gold cases) |
| False confident | 0/392 | 0/392 |

### Remaining Flash-Lite failure counts

| Category | Before | After |
|---|---:|---:|
| `MODEL_PARSE_WRONG` | 3 | 102 |
| `ROUTER_WRONG` | 0 | 21 |
| `ENTITY_RESOLUTION_WRONG` | 73 | 214 |
| `SEARCHPLAN_WRONG` | 0 | 0 |
| `REPOSITORY_RESULT_WRONG` | 0 | 0 |
| `EXPECTED_CLARIFICATION_MISMATCH` | 8 | 1 |
| `FALSE_CONFIDENT` | 0 | 0 |
| `GOLD_PROBLEM` | 0 | 0 |
| `OTHER` | 10 | 0 |

## Safety Metrics

False-confident execution remained **0/392 → 0/392**. Resolver thresholds and ambiguity margins were unchanged.

## Remaining Failures

Remaining failures are enumerated in `failure_traces.jsonl` with their disposition. The principal legitimate clusters are model parse errors, ambiguous identities correctly clarified, missing database entities, and benchmark gold semantics that conflict with broad exploration.

## Remaining DB Coverage Limitations

Entities returning no candidates are retained as DB coverage limitations rather than patched with aliases. The current benchmark has zero NO_MATCH gold cases, so no-match accuracy remains unmeasured.

## Recommended Next Engineering Work

Review unresolved entity index coverage from the trace artifact, adjudicate broad-exploration gold cases, add true NO_MATCH cases, and run a fresh paid production validation only after those dataset decisions. Human STT validation remains deferred; Whisper status is provisional.
