# ACC-6 Refinement Report

> Timestamp: `20260830_024000` · Scope: **ACC-6 only** (cross-type PERSON recovery gate).
> Method: frozen Flash-Lite SearchQuery replay through the **unchanged** `evaluate_system_pipeline` evaluator + live MySQL index. **0 paid LLM calls, 0 STT calls, evaluator/gold/dataset unchanged.**

## Root Cause

ACC-6 hardened cross-type recovery with a single coarse guard in
`DatabaseEntityResolver.resolve` ([resolver.py:167](../../../app/entity_search/resolver.py)):

```python
if (
    rally_res.resolved_candidate is None
    and not rally_res.is_ambiguous      # <-- too coarse
    and can_recover_person
    and not query.driver_names
):
```

`rally_res.is_ambiguous` is set by **two structurally different** situations in
`_evaluate_candidate_selection`:

1. **Genuine ambiguity** — the top rally candidate already *clears* the
   confidence threshold (`top_score >= 0.75`) but a runner-up is too close
   (`strategy="insufficient_gap"`), or multiple real editions share a base name
   (`strategy="multi_year_ambiguity"`). There is a real, strong rally to
   clarify.
2. **Spurious ambiguity** — *no* candidate clears the threshold; the top match
   is merely "plausible" (`0.50 <= top_score < 0.75`, `strategy="plausible_candidates"`).
   This is retrieval noise, typically produced when the model misfiles a
   **person** name into `rallyNames` and the fuzzy matcher returns unrelated
   rallies at low scores.

The blanket `not is_ambiguous` guard treated (2) exactly like (1), so a
confident PERSON that had been misfiled into `rallyNames` was blocked from
recovery and the system clarified an imaginary rally instead.

## Distinguishing Signal

The signal that separates the two, captured directly from the live resolver
(`four_case_trace.json`, reproducible via `trace_acc6.py`):

| Case | phrase | rally strategy | **rally top score** | is_ambiguous | driver conf | truth |
|---|---|---|---:|---|---:|---|
| act_0344 | "Aaron Duville" | plausible_candidates | **0.543** | True | 1.00 | PERSON |
| act_0352 | "Aaron Nau" | plausible_candidates | **0.518** | True | 1.00 | PERSON |
| nsy_0207 | "Mayo Forestry" | insufficient_gap | **0.940** | True | 0.846 | RALLY |
| nsy_0208 | "Mayo Stages" | insufficient_gap | **0.940** | True | 0.846 | RALLY |

**Weak/spurious rally ambiguity** ⇔ the top rally candidate is **below**
`min_confidence_threshold` (0.75): no rally is actually a strong match, so the
ambiguity is noise.

**Genuine rally ambiguity** ⇔ **at least one** rally candidate is **at or above**
`min_confidence_threshold`: a real, strong rally (or several) is competing and a
RALLY clarification is the correct answer.

This uses only evidence OpenEntity already produces (`candidate_options[i].score`
and the resolver's own `min_confidence_threshold`). It is robust to the
`multi_year_ambiguity` case, whose `confidence` field is hard-coded to 0.5 but
whose *candidate scores* are high — so gating on the candidate score, not the
`confidence` field, correctly classifies genuine multi-edition ambiguity as
strong.

## Code Change

Single file: [`app/entity_search/resolver.py`](../../../app/entity_search/resolver.py).
The guard now gates on rally-match **strength**, not the raw ambiguity flag:

```python
rally_has_strong_candidate = bool(
    rally_res.candidate_options
    and rally_res.candidate_options[0].score >= self.min_confidence_threshold
)
rally_blocks_recovery = rally_res.is_ambiguous and rally_has_strong_candidate
if (
    rally_res.resolved_candidate is None
    and not rally_blocks_recovery
    and can_recover_person
    and not query.driver_names
):
    ...  # attempt confident PERSON recovery (downstream PERSON confidence gate unchanged)
```

Nothing else changed: the downstream `driver_check.confidence >= self.min_confidence_threshold`
gate on the PERSON candidate is untouched, so a weak PERSON still never wins,
and the fall-through to RALLY clarification for a blocked/failed recovery is
unchanged. No case IDs, aliases, thresholds, prompts, gold, or other ACC fixes
were touched.

## Four-Case Validation

Replay of the frozen Flash-Lite outputs through the unchanged evaluator
(`stage1_four_cases.py`):

| Case | Before (ACC-6) | After (refined) | Expected | Result |
|---|---|---|---|---|
| act_0344 | CLARIFY (fail) | **RESOLVED → driver "Aaron Duville"** | RESOLVED | ✅ fixed |
| act_0352 | CLARIFY (fail) | **RESOLVED → driver "Aaron Nau"** | RESOLVED | ✅ fixed |
| nsy_0207 | CLARIFY | **CLARIFY** ("Which rally event named \"Mayo Forestry\"…") | CLARIFY | ✅ preserved |
| nsy_0208 | CLARIFY | **CLARIFY** ("Which rally event named \"Mayo Stages\"…") | CLARIFY | ✅ preserved |

`false_confident = 0` for all four. The nsy_* cases never resolve to the wrong
person ("Simon May") — the pre-ACC wrong-entity execution stays eliminated.

## Regression Tests

New generic tests in `tests/unit/test_accuracy_hardening.py`
(`test_acc6r_A`…`test_acc6r_H`), driven by a `_StubLookupRepo` whose candidate
names land in verified score bands via the real scorer:

| Test | Scenario | Expected | Pass |
|---|---|---|---|
| A | spurious rally + confident person (act_0344-eq) | PERSON recovery | ✅ |
| B | spurious rally + confident person (act_0352-eq) | PERSON recovery | ✅ |
| C | genuine strong rally ambiguity + coincidental person (nsy_0207-eq) | RALLY clarify, never person | ✅ |
| D | genuine strong rally ambiguity (nsy_0208-eq) | RALLY clarify, never person | ✅ |
| E | true rally no-match + strong person | PERSON recovery | ✅ |
| F | genuine strong rally ambiguity + weak person | RALLY clarify | ✅ |
| G | genuine strong rally ambiguity + **strong** person | RALLY clarify (safety invariant) | ✅ |
| H | weak rally ambiguity + weak person | safe, never wrong-confident person | ✅ |

Suite results (deterministic, no LLM):
- `tests/unit/test_accuracy_hardening.py`: **22 passed** (14 prior + 8 new).
- Targeted regression set (resolver safety, master regression matrix, router,
  router residual filtering, search plan, conversational service mock,
  accuracy hardening): **92 passed**.
- Full unit suite `tests/unit`: **193 passed**.
- Live-DB integration `tests/integration/test_shared_fixture_benchmark_runner.py`
  (`@live_db`, real MySQL index): **1 passed** (261.96s).

## 392 Replay

Same frozen dataset (SHA `b7fd3922…`, 392 Flash-Lite `parsed_query`), same
`evaluate_system_pipeline`, same gold, live MySQL index. No Gemini calls.

| Metric | Pre-ACC | ACC-6 Before Fix | ACC-6 Refined |
|---|---:|---:|---:|
| System success | **314 / 392 (80.10%)** | 310 / 392 (79.08%) | **312 / 392 (79.59%)** |
| False confident | 0 | 0 | **0** |
| Correct clarification | 25 | 25 | **25** |
| Entity-recovery wrong-executions (nsy_*) | 2 (scored as "success") | 0 | **0** |
| P(success \| exact query) | 84.52% | 84.52% | 84.52% |

The `310` baseline was reproduced exactly by re-running the pre-fix replay,
confirming the A/B is faithful.

## Case-Level Diff

**ACC-6 pre-fix (310) → refined (312)** — exactly two cases changed, both fixes,
nothing else moved:

| Case | Before | After | Input |
|---|---|---|---|
| act_0344 | CLARIFY (fail) | RESOLVED (success) | "Pokaż nawroty w Aaron Duville" |
| act_0352 | CLARIFY (fail) | RESOLVED (success) | "Saltos en Aaron Nau" |

**Refined (312) vs pre-ACC baseline (314)** — the only two remaining deltas:

| Case | Pre-ACC | Refined | Classification |
|---|---|---|---|
| nsy_0207 | RESOLVED (wrong entity: driver "Simon May") | CLARIFY | DIFFERENT_BUT_EQUIVALENT (correctness ↑) |
| nsy_0208 | RESOLVED (wrong entity: driver "Simon May") | CLARIFY | DIFFERENT_BUT_EQUIVALENT (correctness ↑) |

New regressions introduced by this fix: **0**. New false-confident: **0**.
Fixed-vs-pre-ACC: 0 net (the 2 act_ cases were never broken pre-ACC; they were
broken by ACC-6 and are now restored).

## Safety Review

Required ordering preserved — `correct confident > correct clarification > safe
no-match > wrong confident`:

- **The nsy_* wrong-entity executions stay eliminated.** Genuine strong rally
  ambiguity blocks PERSON recovery *regardless of how strong the coincidental
  person is* (test G: person score 0.98 vs "Donegal Rally" still clarifies).
  The block depends only on rally strength, so no coincidental person can
  reintroduce the "Mayo → Simon May" hijack.
- **Weak person never wins** (tests F, H): the untouched downstream
  `driver_check.confidence >= 0.75` gate means a spurious rally with no
  confident person falls through to a safe clarification, never a wrong
  execution.
- **false_confident = 0** across the four-case replay, the full 392 replay, and
  every test suite.

## Evaluator Note (unchanged)

The evaluator, gold, and dataset were **not modified**. `nsy_0207` / `nsy_0208`
still count as evaluator **failures** because their gold `expected_resolution`
is `RESOLVED` to a rally, while the semantically-correct behavior here is a
RALLY clarification (the phrase is genuinely ambiguous across two real
editions — "Mayo Forestry Rally 2025" and "Mayo Stages Rally 2026" — both at
0.94). This is a **known evaluator/gold limitation**, not a resolver defect:
the refined behavior is strictly safer and more correct than the pre-ACC
wrong-entity execution the lenient evaluator had scored as "success." It is
**not** a reason to weaken the resolver, and the headline stays at 312 rather
than being forced back to 314 by reintroducing wrong-entity behavior.

## Final Verdict

### `ACC6_REFINEMENT_VALIDATED`

- act_0344 fixed ✅ · act_0352 fixed ✅
- nsy_0207 remains safe RALLY clarification ✅ · nsy_0208 remains safe RALLY clarification ✅
- false_confident 0/392 ✅ · new regressions 0 ✅
- Headline 314 → 312 (the two remaining deltas are documented evaluator
  artifacts that represent a correctness improvement, not a regression).
