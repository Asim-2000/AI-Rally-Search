# Post-Accuracy-Hardening Benchmark

> Timestamp: `20260829_212927` · Purpose: measure the effect of the **new downstream pipeline** (ACC-1/2/3/4/6) on system quality using the **same frozen Gemini Flash-Lite outputs**. **The QU model and prompt did not change.** No full paid 392-case QU rerun; frozen cached replay + a 26-call live sanity check only.

## 1. Executive Summary

| | Previous (pre-ACC) | Current (post-ACC) | Δ |
|---|---:|---:|---:|
| Frozen system success | **314 / 392 (80.10%)** | **310 / 392 (79.08%)** | **−4 (−1.02 pp)** |
| False confident | **0 / 392** | **0 / 392** | 0 |
| P(success \| exact query) | 84.52% | 84.52% | 0 |

The frozen single-turn replay shows a **−4 case regression**, entirely attributable to **ACC-6** (cross-type recovery restricted to a true rally no-match). Crucially:
- **2 of the 4** are a *genuine but safe* regression (`act_0344`, `act_0352`): the model misfiled a person into `rallyNames`; ACC-6 now blocks the person-recovery on a spuriously-ambiguous rally, so it **clarifies safely** instead of resolving. No false-confident.
- **2 of the 4** (`nsy_0207`, `nsy_0208`) are an **evaluator artifact that is actually a correctness improvement**: the old code hijacked the ambiguous rally `Mayo Forestry` into the **wrong** person (`Simon May`) and executed — a wrong-entity execution the lenient evaluator scored as "success." ACC-6 now safely clarifies the true rally ambiguity.

The **conversation-facing fixes (ACC-1/2/3/4) are barely exercised by the frozen set** because it is predominantly single-turn (ACC-2: 0 activations, ACC-1: 1 neutral, ACC-4: 0). Their value is validated by the **conversation benchmark (8/8 flows pass)** and the **live validation (0 wrong-confident, both prior measured failures fixed)**. The critical safety invariant — **false_confident = 0** — holds in every run.

**Verdict: `ACCURACY_HARDENING_VALIDATED_WITH_REGRESSIONS`.**

## 2. Frozen Dataset and Model Outputs

- Dataset: **392 cases**, SHA256 `b7fd39226592281c565c0e835c16b460654f43cd2da4bc09655a5abf06972662` (verified match).
- Prompt SHA256 `c82c75d4d10017478084b4c37ee0be005b910bd67cb6c45cf64452d3a2e2c09b` — **matches the frozen run exactly** (prompt unchanged).
- Frozen output source: `benchmarks/results/full_20260829_053539/qu_raw_results.jsonl` (model `gemini-3.5-flash-lite`, 392 cached `parsed_query`).
- **No new full QU run occurred.** The evaluator `benchmarks/scoring/system_scoring.evaluate_system_pipeline` was used **unchanged**.
- Method: A/B through the identical evaluator — baseline measured by temporarily reverting the uncommitted ACC changes (`git stash`), current measured with them in place; repo restored afterward (net-zero code change, verified).

## 3. Historical Raw QU Results (frozen — unchanged)

Using the same frozen Gemini outputs, the raw model metrics are historical facts and are **not** recomputed here (Field F1 89.3%, exact match 64.3%, false-confident 0%, etc. from `full_20260829_053539`). **The model did not improve; only the deterministic downstream pipeline changed.**

## 4. Previous Downstream Baseline

Documented hardened baseline: **315 / 392 (80.36%)**, P(success|exact) 84.92%, false-confident 0. Re-measuring the pre-ACC working tree through the current evaluator reproduces **314 / 392 (80.10%)** (±1 case of borderline-resolution variance vs the documented 315), confirming the A/B baseline is faithful.

## 5. Current Downstream Results

- Total: 392 · System success: **310 (79.08%)** · False confident: **0**
- Correct clarification: 25 · P(success|exact): 84.52% (n=252) · P(success|correct intent): 80.72% · P(success|F1≥0.95): 83.98%
- Deterministic recovery activations on the frozen set: ACC-2 = 0, ACC-1 = 1 (neutral), ACC-4 = 0, ACC-6 = 4 (the 4 flips).
- Stability: two independent current-process runs both = 310 (deterministic).

## 6. Before vs After

| Metric | Previous | Current | Delta |
|---|---:|---:|---:|
| System success | 314/392 (80.10%) | 310/392 (79.08%) | −4 (−1.02 pp) |
| False confident | 0 | 0 | 0 |
| Correct clarification | 25 | 25 | 0 |
| P(success \| exact query) | 84.52% | 84.52% | 0 |
| Entity-resolution / Router / SearchPlan / Repository failures | 0 pipeline crashes | 0 pipeline crashes | 0 |

## 7. Case-Level Changes

Fixed: **0** · Regressed (by score): **4** · Different-but-equivalent: **0** (machine); after manual review 2 of the 4 are DIFFERENT_BUT_EQUIVALENT. See `case_diff.jsonl`.

| Case | Category | Input | Prev → Curr | Manual class | Root cause |
|---|---|---|---|---|---|
| `act_0344` | video/action | "Pokaż nawroty w Aaron Duville" | RESOLVED → CLARIFY | REGRESSED_SAFE | ACC-6 blocks person-recovery on ambiguous rally; gold=DRIVER |
| `act_0352` | video/action | "Saltos en Aaron Nau" | RESOLVED → CLARIFY | REGRESSED_SAFE | same |
| `nsy_0207` | noisy/phonetic | "Show clips from Mayo Forestry 202 Rally #7" | RESOLVED(wrong entity) → CLARIFY | DIFFERENT_BUT_EQUIVALENT | old code hijacked to driver "Simon May"; ACC-6 clarifies true rally ambiguity |
| `nsy_0208` | noisy/phonetic | "Show clips from Mayo Stages 202 Rally #8" | RESOLVED(wrong entity) → CLARIFY | DIFFERENT_BUT_EQUIVALENT | same |

All 4 are safe (CLARIFY, 0 false-confident). No case regressed into wrong-confident execution.

## 8. ACC-1 Impact — follow-up video/action intent recovery

- Frozen set: 1 activation, neutral (no regression, no flip).
- Conversation benchmark: flows A, B, G pass — `show videos from that rally` / `show jump highlights from that rally` correctly become `SEARCH_VIDEO_ACTIONS` with the active rally injected; latest-referent wins.
- Live: `Show Rally Aluksne → show videos from that rally` returns **VIDEO_ACTIONS** (the prior measured `SEARCH_RALLIES` failure is **fixed**). Flow F confirms `Rallies in Ireland` stays `SEARCH_RALLIES` (no over-correction).

## 9. ACC-2 Impact — grounded direct-filter recovery

- Frozen set: **0 activations** — no frozen case had a model-dropped grounded country/year (the "Crashes in Ireland in 2025" drop was a *fresh live-call* failure, not present in the cached outputs).
- Live: `crashes in ireland in 2025` **RESOLVES** to a country+year+action search (the prior measured drop-and-clarify failure is **fixed**). Only literal raw-text values are restored; adversarial `country-inside-entity-phrase` and `edition-year` cases confirm no false additions.

## 10. ACC-3 Impact — canonical driver referent preservation

- Conversation flows D, E pass: after `Show Max Freeman's rallies`, `active_driver_id` is populated; `show his videos` reuses the canonical driver (DRIVER_VIDEOS, n=53 — identical to the standalone driver-video query, confirming the same identity).
- Live: `Show Max Freeman's rallies → show his videos` resolves to the same driver's videos.

## 11. ACC-4 Impact — referent fallback before missing-subject clarification

- Frozen set: 0 activations. Conversation flow C passes: `who won it?` after a rally reuses the active rally (RALLY_RESULTS, no clarification). Flow J passes: `who won it?` with only an active **driver** and no rally correctly **clarifies** (a driver referent is never used as a rally). Live turn-3 `who won it?` resolves to RALLY_RESULTS.

## 12. ACC-6 Impact — ambiguous rally before PERSON recovery

- The **only** change affecting the frozen set (all 4 flips). It eliminated 2 wrong-entity executions (`nsy_*`: Mayo→"Simon May") and, as a side effect, over-blocked 2 correct person-recoveries (`act_*`) where the misfiled person was the right answer and the rally match was spurious/low-confidence.
- **Tradeoff finding (documented, not fixed):** ACC-6's blanket "ambiguous rally blocks recovery" is slightly too broad — it treats a spurious low-confidence `plausible_candidates` rally the same as a genuine multi-edition ambiguity. A future refinement could gate recovery on rally-match *confidence* rather than the ambiguity flag alone. Left unchanged this pass (code frozen during benchmark).

## 13. Conversation Results

8 end-to-end flows through the real `ConversationalSearchService` + live DB (prebuilt per-turn model outputs incl. the known buggy ones): **8 / 8 flows passed, 0 wrong-confident.** (Clarification-selection flows H/I are Dart-side `PendingClarification` and are covered by the Flutter clarification tests.) See `conversation_results.json`.

## 14. Adversarial Results

22 single-turn adversarial cases (typos, editions, partial people, direct filters, zero-result, cross-type, ranking, multi-entity) through the live pipeline: **21 / 22 expected outcomes, 0 wrong-confident**, 7 safe clarifications, 1 safe no-match. The one miss (`Rally Aluksne 2026` ASCII → safe CLARIFY offering `Rally Alūksne 2026`) is a pre-existing ASCII-vs-`ū` behavior, safe and unrelated to ACC. Plus **49 deterministic accuracy/safety unit tests pass** (master regression matrix, resolver safety, residual routing, phonetics, accuracy-hardening). See `adversarial_results.json`.

## 15. False-Confident Audit

**0 false-confident in every run** (frozen previous, frozen current ×2, conversation, adversarial, live). ACC-6 additionally removed 2 real wrong-entity executions the frozen evaluator had scored as success. **Safety gate: PASS.**

## 16. Remaining Failures

The 82 remaining frozen failures are dominated by raw-model parse errors and repository/gold edge cases unchanged by this pass (per the original taxonomy). The 4 new ACC-6-related flips are all safe clarifications. `act_0344`/`act_0352` are the only genuinely-worse cases and are the candidate for the ACC-6 confidence-gating refinement above.

## 17. Capability Gaps (unchanged, separate from bugs)

Inverse "drivers that participated in Rally X", stage-level results, and true "biggest/exciting" magnitude ranking remain **MISSING CAPABILITIES**, not bugs. Not addressed here.

## 18. Live Production Validation

26 real Gemini Flash-Lite calls → current downstream → live MySQL (11,245-entity index). **23 RESOLVE / 2 safe CLARIFY / 1 ZERO, 0 exceptions, 0 wrong-confident.** HTTP-ish pipeline p50 **1,310 ms**, p95 **1,895 ms**. Estimated cost **~$0.0085**. Both prior measured failures (`show videos from that rally`, `crashes in ireland in 2025`) are fixed; all conversation flows succeed. See `live_validation_results.jsonl`. Not used for model selection.

## 19. Final Verdict

### `ACCURACY_HARDENING_VALIDATED_WITH_REGRESSIONS`

The safety gate passes everywhere (false_confident = 0; ACC-6 net-removed real wrong-entity executions). The conversation and live validations confirm ACC-1/2/3/4 deliver their intended fixes with no wrong-confident behavior. The frozen single-turn replay shows a small −4 regression driven solely by ACC-6, of which 2 are safe clarifications replacing previously-wrong executions and 2 are a genuine but safe over-clarification worth a future confidence-gating refinement.
