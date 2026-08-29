# Downstream Accuracy Audit

> Audit date: 2026-08-29 · Branch: `audit` · Focus: **search accuracy, correctness, and safe failure** — not latency. **Audit only; no code changed.**
>
> Priority ordering used throughout: **correct-confident > correct-clarification > safe no-match > wrong-confident.**
>
> Findings tagged **MEASURED** (observed in `benchmarks/results/production_validation_20260829_122808/` or the test suite), **INFERRED** (traced in code), or **SPECULATIVE**. The production validation run (56 text cases, live Gemini Flash-Lite + live MySQL, 11,245-entity index) is the primary measured source.

---

## Executive Summary

The deterministic spine is **safe**: 0 false-confident executions across 56 live cases, 6/6 ambiguity cases clarified correctly, typo recovery (aluqsne/aluksnay) worked, and the ungrounded-year guard fired correctly (identity vs filter separation held). Zero-result handling does **not** substitute fuzzy entities or fall back to unrelated searches. The architecture prefers clarification over wrong-confidence, as designed.

**The accuracy weak point is not the deterministic core — it is that conversational inheritance and intent selection are entirely LLM-driven, with no deterministic safety net.** The reducer (`conversation_reducer.py`) only *labels* inherited/refined fields; it does **not** merge prior filters. Filter/intent inheritance depends on Gemini Flash-Lite re-emitting context correctly, and when it doesn't, there is no downstream recovery. This produced the two measured conversation failures and one measured filter-drop failure below.

**Confirmed measured failures (P1):**
1. **`Show videos from that rally` → wrong intent.** Flash-Lite emitted `SEARCH_RALLIES` instead of `SEARCH_VIDEO_ACTIONS` in **both** measured follow-ups; the rally referent survived but the user got rallies, not videos. No deterministic intent correction exists.
2. **`Crashes in Ireland in 2025` → dropped country + year, then unnecessary clarification.** Flash-Lite dropped `Ireland` and `2025`; the router then treated residual `ireland` as a rally and clarified. A known country became an entity-clarification.
3. **`activeDriverId` never preserved.** After a canonical Max Freeman resolution, the result-derived `activeDriverId` stayed `null`; driver identity is not pinned across turns (only rally IDs and winner IDs are).

None of these require prompt changes — each has a concrete deterministic remedy. Rankings, ranking-word handling, and one cross-type-recovery ordering issue round out the P2 set.

---

## Accuracy Risk Map

| Layer | Risk level | Dominant risk |
|---|---|---|
| Query Understanding (field/intent) | **High** (LLM-bound) | dropped filters, wrong intent on follow-ups; no deterministic net |
| Conversation inheritance | **High** | reducer does not merge; inheritance is LLM-only |
| Canonical ID preservation | **Medium-High** | `activeDriverId` never set from resolution |
| Router residual recovery | Medium | known countries misrouted to entity clarification |
| Cross-type recovery | Medium | rally→person can preempt correct rally clarification |
| OpenEntity picks | **Low** (safe) | exact-match precedence not mirrored for single-token drivers (over-clarify) |
| Clarification selection | **Low** (correct) | preserves pending query + canonical ID, no LLM |
| SearchPlan | Low | stage filter silently dropped for results intents |
| Repository/SQL | Low | country LIKE cross-border false positives |
| Zero-result | **Low** (safe) | no fuzzy substitution |

---

## Query Understanding Recovery

Deterministic recovery **exists and works** for: noisy/typo entities (OpenEntity), model-invented years (ungrounded-year guard), residual entity-like text (router materialization), and `driverIds` injection (validator rejects them). Recovery **does not exist** for:

- **Dropped direct filters (country/year/action).** MEASURED: `Crashes in Ireland in 2025` lost country and year. The ungrounded-year guard only *removes* ungrounded years; there is no symmetric logic to *add* a year that is present in the raw text but omitted by the model. → ACC-2.
- **Wrong intent on follow-ups.** MEASURED: `Show videos from that rally` → `SEARCH_RALLIES`. The router trusts `query.intent` and never corrects it, even when strong action/video cue words are present. → ACC-1.
- **personRole misassignment.** "co-drove" vs "drove" is inferred solely by the model; a wrong role silently filters the wrong person dimension. Role *words* are in the router function-word set, but the role *value* is LLM-only. → ACC-12 (document; low deterministic feasibility).

Wrong-field placement (entity in `rallyNames` vs `driverNames`) **is** recoverable via cross-type recovery (see that section) — this is a genuine strength.

---

## Router Accuracy

Traced against the requested examples:

| Query | Route | Correct? |
|---|---|---|
| show jump highlights featuring max freeman | residual→PERSON (`featuring` cue) | ✅ |
| show jump highlights from rally ireland | RALLY entity / country | ✅ |
| show jump highlights from SS3 | STAGE (`ss\d+` cue) | ✅ |
| show jump highlights from karl martin from rally ireland | PERSON + RALLY | ✅ (multi-entity preserved) |
| max freeman rallies | PERSON | ✅ |
| videos featuring max freeman | PERSON | ✅ |
| who won rally aluksne | RALLY | ✅ |
| top 10 finishers rally aluksne | RALLY | ✅ |
| rallies held in ireland | country direct filter (`held` is function word) | ✅ |
| rallies where max freeman competed | PERSON (`competed` function word, name residual) | ✅ |
| rally donegl | RALLY → clarify | ✅ |
| rally aluqsne | RALLY → Alūksne | ✅ |

**Finding ACC-2 (router side):** when the model drops a known country and the bare country token becomes residual, the router has **no gazetteer** and routes `ireland` to entity clarification. The country list already exists in `repositories/sql.py:COUNTRIES` but the router does not consult it. A residual token that exactly matches a known country/alias should become a `DIRECT_FILTER` country, not an entity mention. → ACC-2.

**Finding ACC-1 (router side):** the router does not use action/video cue words (`videos`, `highlights`, `jump`, …) to *correct* an implausible intent. When intent=`SEARCH_RALLIES` but the text carries a strong video/action cue and a rally referent is active, the correct intent is video. This is the single most impactful deterministic net available. → ACC-1.

Otherwise the router is conservative and correct; residual recovery is properly intent-capability-constrained.

---

## OpenEntity Accuracy

Safe and generally correct. Exact-match precedence works for rallies (embedded-year editions resolve; multi-year ambiguity clarifies correctly). Duplicate-account identities clarify rather than merge. Year mismatch is a hard penalty (`compute_composite_score` returns 0.25), producing safe no-match rather than wrong-confident. Country/city context and PersonRole eligibility are applied.

**Finding ACC-5 (unnecessary clarification):** single-token driver names take the `partial_name_ambiguity` branch (`resolver.py:573`) whenever `>1` candidate exists — **even if the top candidate is an exact unique canonical match**. The exact-canonical short-circuit that protects rallies is not mirrored for single-token people. Example: a surname that exactly equals one canonical person but is a substring of another produces an avoidable clarification. → ACC-5.

No wrong-confident OpenEntity pick was found in isolation; the risks are (a) over-clarification (ACC-5) and (b) the cross-type ordering issue below.

---

## Cross-Type Recovery

Recovery is intent-constrained (capability matrix) and evidence-gated (person confidence ≥ 0.75, only when rally match is absent/weak) — good.

**Finding ACC-6 (wrong-confident / suppressed clarification):** in `resolver.resolve` the rally→person recovery block runs **before** the rally-ambiguity clarification block (`resolver.py:163` precedes `:216`). If a rally phrase is genuinely *ambiguous* (`rally_res.is_ambiguous`, e.g. a multi-edition rally) **and** coincidentally matches a confident person, the code recovers to PERSON and `continue`s — **silently flipping intent (`SEARCH_RALLIES`→`SEARCH_DRIVER_RALLIES`) and skipping the correct rally-edition clarification.** Low likelihood (needs a ≥0.75 person hit on a rally-shaped phrase) but it is a true wrong-confident + suppressed-clarification path. Recommended: only attempt person recovery on a true rally no-match (`resolved_candidate is None and not is_ambiguous`), or prefer clarification when the rally is ambiguous. → ACC-6.

The complementary direction (`driverNames=["rally aluksne"]` must not blindly force PERSON) is handled: driver-required intents fail safely, non-required keep the raw string for a safe (likely empty) search.

---

## Conversation Accuracy

The reducer does **not** merge prior filters (`conversation_reducer.py` only computes inherited/refined labels). Inheritance = LLM re-emission + deterministic canonical-ID reuse (`_reuse_committed_referent_ids`). Traced flows:

| Flow | Behavior | Verdict |
|---|---|---|
| A. Aluksne → videos from that rally | rally referent survives, **but intent wrong** (`SEARCH_RALLIES`) | ❌ MEASURED (ACC-1) |
| B. Aluksne → who won it? | relies on LLM filling rally from context; if empty → unnecessary clarify (no referent fallback) | ⚠️ ACC-4 |
| C. Max Freeman → what about 2025? | LLM must re-emit driver; year grounded & kept; **no deterministic driver net** | ⚠️ ACC-3 |
| D. Max Freeman → show his videos | works only if LLM re-emits name; **driver ID not pinned** → re-resolves fuzzy | ⚠️ ACC-3 |
| E. Aluksne → Rallies in Ireland | if LLM inherits stale rally → `rally AND country` → wrong empty result; no REPLACE guard | ⚠️ ACC-7 |
| F. Aluksne → Donegal → videos from that rally | latest referent wins (referents overwritten per turn) ✅ (modulo ACC-1 intent) | ✅/❌ |
| G. ambiguous → clarify → select → videos from that rally | selected rally ID preserved via clarification (`activeRallyId`) ✅ | ✅ (modulo ACC-1) |
| H. ambiguous person + action + rally → select person | action/rally preserved via pending query ✅ | ✅ |

**Finding ACC-3 (canonical ID loss — MEASURED):** `ResultReferentContext.from_search_response` never sets `active_driver_id` from a resolved driver, and the orchestrator passes only driver *names* (not IDs) into referent derivation. So `active_driver_id` is populated **only** by clarification selection (Dart) — never by a plain confident text resolution. Consequences: (a) `_reuse_committed_referent_ids` cannot reuse the driver ID via the `active_driver` path (only via `last_winner`), so follow-ups re-resolve the driver by fuzzy matching each turn; (b) for an **ambiguous** driver name, turn-2 follow-ups can re-clarify or drift to a different person than turn-1. The production report states this plainly: *"activeDriverId remained null … Canonical referent-ID preservation is therefore incomplete."* → ACC-3.

**Finding ACC-4 (unnecessary clarification):** `_missing_required_subject` (orchestrator `:282`) runs on the **parsed** query, before referent reuse, and clarifies when a results/driver intent lacks a subject — **without consulting referents**. For `who won it?` (GET_RALLY_RESULTS with empty rally because the model didn't resolve the pronoun) it clarifies even though `referents.active_rally(_id)` is known. Deterministic fix: fall back to the active referent before clarifying. → ACC-4.

**Finding ACC-7 (stale filter leak):** no deterministic REPLACE guard prevents a stale rally from leaking into an unrelated new query (flow E). Because AND-across-dimensions applies, a leaked rally + new country yields a wrong empty result. Hard to fully fix deterministically (intent is ambiguous), but a heuristic — when the new turn introduces a strong new primary dimension (e.g. `countries`) and the model also re-emits a prior rally with no rally cue in the raw text — could drop the stale rally. Document; low-confidence fix. → ACC-7.

---

## Clarification Accuracy

**Correct and safe.** `PendingClarification.select` (Dart) replaces only the ambiguous dimension, injects the selected canonical ID directly, does **no** LLM call, preserves all other filters/referents, and rejects stale selections via `requestId`. The pending query (not `session.activeQuery`) is used. Re-execution goes to `/v1/search` (plan-only, no resolution).

**Multi-ambiguity (RALLY + PERSON both ambiguous):** the resolver clarifies the **first** ambiguous dimension it reaches (rally in step 1, else driver in step 3) and returns immediately (`EntityResolutionResult.clarification`). The second ambiguity is **not discarded** — it is simply not yet reached; after the user resolves the first, the next turn re-resolves and will clarify the second. So multi-ambiguity is handled **one at a time**, deterministically, without dropping the second dimension. This is correct behavior. (Minor UX note: the user resolves sequentially, but no data is lost.)

---

## SearchPlan Accuracy

- Strategy mapping is correct for all 9 intents; `SearchPlan` self-validates strategy↔intent and rejects `action_types` outside `SEARCH_VIDEO_ACTIONS`.
- Resolved filters survive; ambiguous/unresolved entities block execution (`UnresolvedEntityError`); raw typo strings for **required** intents fail safely rather than executing.
- OR-within / AND-across is preserved by the repository filter builder.

**Silently ignored fields:**
- **`stage_names`/`stage_numbers` for GET_RALLY_RESULTS / GET_RALLY_TOP_FINISHERS.** `classifications()` calls `common()` **without** `stages=True`, so a stage constraint on a results query is dropped → "top finishers of SS3 in Rally X" returns the **overall** classification, not the stage. Silent wrong-scope result. → ACC-9 (capability gap; should inform/clarify rather than silently drop).
- **`uploaders` filter** is carried into the plan but no repository handler filters by it (`top_uploaders` ranks only). Dead filter. → ACC-11 (P3).
- For non-required intents, an unresolved rally/driver **name** remains in the plan and executes as a `LIKE` — usually a safe empty result, occasionally a loose match. Acceptable under safe-failure ordering.

---

## Repository Semantics

Relational truth is correct: participation via `entry_list→sub_events→events` (dedup by event), wins/results via `rally_results` + `FINAL_STAGE` (last classified stage) + `pos_overall`, driver-video via `metadata.entry_list_id→entry_list`, top-N orderings as expected, first-place = `pos_overall=1`. Multi-driver (MatchMode.ALL → per-driver subqueries; ANY → OR) and multi-rally are correct. Pagination does not alter semantics (LIMIT/OFFSET on rows; count separate).

**Finding ACC-10 (P3):** country matching adds `LOWER(ev.country) LIKE '%ireland%'` for tokens >2 chars. This can match `Northern Ireland` for a query of `Ireland` (cross-border false positive), since the UK alias set does not include "northern ireland". Low impact, data-dependent. → ACC-10.

No N+1, no dedup errors, no participation-as-results confusion found.

---

## Ranking Semantics

| Word | Mapped ordering | Correct? |
|---|---|---|
| top / most (uploaders, wins) | `upload_count DESC` / `win_count DESC` | ✅ |
| first / won | `pos_overall = 1` | ✅ |
| top finishers | `pos_overall ASC` | ✅ |
| latest / recent (rallies, videos) | `start_date DESC` / `id DESC` | ✅ (implicit) |
| highlights | action filter, `vm.id DESC` (recency) | ⚠️ acceptable |
| **biggest / best (jumps/moments)** | `vm.id DESC` — **not** magnitude | ❌ ACC-8 |

**Finding ACC-8 (P2):** `video_actions()` orders by `vm.id DESC` and selects `vm.points` but never orders by it. "Biggest jumps" / "best moments" (client-listed stretch queries) return the most recent, not the largest. Deterministic fix: order by `vm.points DESC` when magnitude/superlative cues are present. → ACC-8.

---

## Zero-Result Handling

**Safe.** A correctly-resolved entity + correct plan + 0 rows returns a genuine empty `SearchResponse` (Flutter shows a no-results message). No conversion to unrelated clarification, no fallback rally search, no fuzzy substitute. The **only** path that substitutes an entity is cross-type recovery (ACC-6), which is confidence-gated. `GET_RALLY_RESULTS`/`GET_RALLY_TOP_FINISHERS` correctly fail-safe ("couldn't identify that rally") when the required entity is unresolved rather than returning something plausible-but-wrong.

---

## Capability Gaps (vs Bugs)

| Item | Classification |
|---|---|
| "drivers that participated in Rally X" (inverse roster) | **MISSING_CAPABILITY** (no rally→participants intent; deferred) |
| stage-level results ("who won SS3") | **MISSING_CAPABILITY** (results are event-level; stage filter dropped → ACC-9) |
| "biggest/exciting" true semantic ranking | **PARTIAL** (magnitude available via `points`, not used → ACC-8) |
| `Show videos from that rally` intent | **BUG** (recoverable → ACC-1) |
| dropped country/year on multi-filter | **BUG** (recoverable → ACC-2) |
| driver ID preservation | **BUG** (→ ACC-3) |

Do **not** force inverse-participation or stage-level results into existing intents — those need explicit new capabilities.

---

## Wrong-Confident Risk Cases

1. **ACC-6** — ambiguous rally coincidentally matching a confident person → silently becomes a person search (intent flipped, clarification suppressed). *Highest wrong-confident risk found*, though low frequency.
2. **ACC-3 (ambiguous drivers)** — follow-up re-resolves an ambiguous driver name and may pick a *different* person than the turn-1 selection, because the ID is not pinned.
3. **ACC-10** — `Ireland` may include `Northern Ireland` events (wrong-country inclusion presented confidently).
4. **ACC-9** — stage-scoped results query returns event-level results confidently (wrong scope).

No wrong-confident case was found in the isolated OpenEntity scorer or the clarification-selection path.

---

## Unnecessary Clarification Cases

1. **ACC-2** — known country dropped by model → residual country token → entity clarification (MEASURED: `Crashes in Ireland in 2025`).
2. **ACC-4** — missing-subject clarification ignores an available active referent (`who won it?`).
3. **ACC-5** — single-token driver that is an exact unique canonical match still clarifies when any weaker second candidate exists.

---

## Adversarial Query Set (deterministic; no paid LLM calls)

Use real entities (`Rally Alūksne 2026`, `Max Freeman`, `Karl Martin`, Donegal editions, `Rally Ireland`, Latvia/Ireland). Run by constructing `SearchQuery`/session fixtures and asserting Router → OpenEntity → SearchPlan outcomes (mirroring `test_master_regression_matrix.py`). Categories and representative cases (≈70):

**Typos / phonetic (expect canonical or safe clarify):** `aluqsne`, `aluksnay`, `aluksna`, `rally aluqsne`, `max freemn`, `max freeman`, `maxx freemann`, `karl martn`, `donegl`, `donegal`, `rally ireland`.

**Similar rallies / editions (expect edition clarify when no year):** `rally aluksne` (multi-year → clarify), `rally aluksne 2026` (resolve), `rally ireland`, `rally ireland historic` (must not collide), `donegal rally` (multiple → clarify).

**Similar / partial people (expect exact short-circuit or safe clarify):** `freeman` (surname only), `max` (given only → clarify), `martin` (surname), full `Karl Martin` (resolve).

**Year ambiguity / identity-vs-filter:** `rally aluksne 2026`, `rally aluksne in 2019` (no 2019 → safe no-match), `rallies in 2025`, `who won rally aluksne 2026`, `crashes in ireland in 2025` (dropped-filter regression → ACC-2).

**Country/city ambiguity:** `rallies in ireland` (must not include Northern Ireland → ACC-10), `rallies in donegal` (city vs event), `rallies in latvia`.

**Role ambiguity:** `rallies max freeman co-drove`, `rallies max freeman drove`, `videos where max freeman was co-driver` (personRole correctness → ACC-12).

**Multi-entity:** `jump highlights featuring max freeman from rally ireland`, `crashes featuring karl martin in latvia in 2026`, `videos of max freeman and karl martin`.

**Conversation:** `Show Rally Aluksne` → `Show videos from that rally` (**intent regression → ACC-1**); `Show Max Freeman's rallies` → `what about 2025?` (driver retention → ACC-3) → `show his videos` (ID pinning → ACC-3); `Show Rally Aluksne` → `Rallies in Ireland` (stale-leak → ACC-7); `Show Rally Aluksne` → `Show Rally Donegal` → `videos from that rally` (latest-wins).

**Clarification:** ambiguous rally → select → `videos from that rally` (ID persists); ambiguous person+action+rally → select person (filters preserved).

**Zero-result (must stay empty, no substitution):** `rallies in antarctica`, `who won rally nonexistent`, `videos of zzzznobody`, `crashes in 1970`.

**Direct filters (must NOT hit OpenEntity):** `rallies in ireland`, `rallies in 2025`, `rallies in ireland in 2025`, `stage 3 videos`, `jump highlights` (no entity).

**Ranking:** `biggest jumps` (magnitude → ACC-8), `most wins`, `top 10 finishers rally aluksne`, `top uploaders rally aluksne`, `latest rallies`.

---

## Missing Regression Tests

| Test | Guards |
|---|---|
| Follow-up `videos from that rally` forces `SEARCH_VIDEO_ACTIONS` when a rally referent + video/action cue exist | ACC-1 |
| Residual token equal to a known country → country `DIRECT_FILTER`, not entity clarification | ACC-2 |
| Raw-text year present but model omitted it → grounded-year *addition* | ACC-2 |
| Confident driver text resolution populates `active_driver_id`; follow-up reuses it without re-resolving | ACC-3 |
| Missing-subject with active referent → reuse referent, do **not** clarify | ACC-4 |
| Single-token driver with exact unique canonical match → resolve, do **not** clarify | ACC-5 |
| Ambiguous rally + confident person → clarify the rally (person recovery must not preempt) | ACC-6 |
| Stale rally not ANDed into a new country-primary query | ACC-7 |
| Magnitude-cued action query orders by `points` | ACC-8 |
| Stage-scoped results query → informs/clarifies instead of silently returning event-level | ACC-9 |
| `Ireland` country filter excludes `Northern Ireland` rows | ACC-10 |

---

## Top Accuracy Fixes

| ID | Sev | Layer | Example | Current | Expected | Root cause | Wrong-confident risk | Deterministic fix | Test |
|---|---|---|---|---|---|---|---|---|---|
| **ACC-1** | P1 | Router/QU→intent | `Show videos from that rally` | intent `SEARCH_RALLIES`; returns rallies | `SEARCH_VIDEO_ACTIONS`; returns videos of active rally | reducer/router never correct LLM intent; inheritance LLM-only | Medium (wrong result type, confident) | post-QU intent correction: strong video/action cue + rally referent ⇒ force video intent | yes |
| **ACC-2** | P1 | Router residual + year guard | `Crashes in Ireland in 2025` | country+year dropped; `ireland` → rally clarify | action + country=Ireland + year=2025 | model dropped direct filters; router has no country gazetteer; year guard only removes | Low (clarify, not wrong data) but common | (a) residual == known country ⇒ country DIRECT_FILTER; (b) add raw-text years the model omitted | yes |
| **ACC-3** | P1 | Referents | `Max Freeman's rallies` → `his videos` | `active_driver_id` null; driver re-resolved fuzzy each turn | canonical driver ID pinned across turns | `from_search_response` never sets `active_driver_id`; orchestrator passes names only | Medium (ambiguous driver may drift) | populate `active_driver_id`/`active_rally_id` from resolved IDs; reuse via `active_driver` path | yes |
| **ACC-4** | P2 | Orchestrator | `who won it?` (rally not re-emitted) | clarifies "which rally?" | reuse active rally referent | missing-subject check ignores referents | none (over-clarify) | consult referents before clarifying missing subject | yes |
| **ACC-6** | P2 | Resolver recovery | ambiguous rally that also matches a person | may flip to person, suppress rally clarify | clarify rally edition | recovery block precedes ambiguity block | **Medium** | gate person recovery to true rally no-match (`resolved_candidate is None and not is_ambiguous`) | yes |
| **ACC-5** | P2 | Resolver (person) | single-token exact person + weak 2nd | clarifies | resolve exact | no exact short-circuit for single-token drivers | none (over-clarify) | exact normalized/canonical match short-circuits partial-name ambiguity | yes |
| **ACC-8** | P2 | Repository | `biggest jumps` | recency order | magnitude order | `ORDER BY vm.id`; `points` unused | none | order by `vm.points DESC` on magnitude cues | yes |
| **ACC-9** | P2 | SearchPlan/Repo | `top finishers of SS3` | event-level result (stage dropped) | stage-level or explicit "not supported" | classifications ignore stage filters | Medium (wrong scope, confident) | detect stage constraint on results intents; inform/clarify | yes |
| **ACC-7** | P2 | Conversation | `Aluksne` → `Rallies in Ireland` | possible stale rally AND country → empty | drop stale rally | LLM inheritance, no REPLACE guard | Low (empty, not wrong) | heuristic drop of stale primary when new primary dimension appears without its cue | yes |
| **ACC-10** | P3 | SQL | `Ireland` | may include Northern Ireland | Ireland only | `LIKE '%ireland%'` | Low | tighten country matching to alias equality / exclude NI | yes |
| **ACC-11** | P3 | SearchPlan | uploader-name filter | ignored | ignored or supported | dead filter | none | remove field or wire it | no |
| **ACC-12** | P2 | QU | `co-drove` | LLM-only role | correct role | role value is model-only | Medium | limited; document — low deterministic feasibility | partial |

**Do NOT** change resolver confidence thresholds to "fix" ACC-5/ACC-6 — the production report explicitly warns against it, and safety ordering must hold. Every fix above is a deterministic behavior change, not a threshold move.

---

### Cross-references
See `AUDIT_REPORT.md` (architecture/requirements) and `DOWNSTREAM_EFFICIENCY_AUDIT.md` (latency). ACC-1/ACC-2/ACC-3 are the same conversation/inheritance gaps that `AUDIT_REPORT.md` flagged qualitatively; this audit ties them to **measured** failures and concrete deterministic remedies.
