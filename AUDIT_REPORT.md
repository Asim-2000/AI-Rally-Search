# AI Rally Search — Project Audit

> Audit date: 2026-08-29 · Branch: `audit` · Scope: requirements, architecture, code, data semantics, tests, docs, benchmarks. **No production code, tests, docs, models, or config were modified.** This is an audit-only pass.

---

## 1. Executive Summary

**Overall health: Good.** The project is a genuinely well-architected search system. The documented design principle — *"the LLM interprets language; deterministic software owns identity, execution, and relational truth"* — is real and largely enforced in code, not just described in prose. The most important invariants (LLM cannot emit SQL, LLM cannot invent canonical IDs, deterministic router, SearchPlan as executable contract, clarification-over-wrong-confidence) are implemented and covered by tests.

| Dimension | Assessment |
|---|---|
| **Functional search coverage** | ~95% — all 13 client example query classes map to one of the 9 intents and execute against correct relational paths. |
| **Client deliverable coverage** | ~60% — code is strong, but three *explicit* deliverables are missing: setup instructions, a shipped sample/mock dataset, and a consolidated 10–15 example-query list. |
| **Architecture quality** | Strong. Clean layer boundaries, strict Pydantic schemas, deterministic router/plan/repository. |
| **Test quality** | Good breadth (170+ unit tests pass) but the committed suite is **currently red** (1 stale failing unit test) and heavy reliance on a live DB for integration coverage. |
| **Production readiness** | Conditional. Works with the current `.env`, but has latent config footguns (default provider is `mock`, no fail-fast) and prototype-grade DB plumbing (`NullPool`, ignored `DB_USE_SSL`). |

**Biggest risks**
1. **Deliverable gaps** (setup docs, sample dataset, example-query list) — these are graded criteria in `PROBLEM_STATEMENT.md` and are the items most likely to cost marks in client review.
2. **Config default = `mock` parser with no production guard** — a deploy missing `QUERY_UNDERSTANDING_PROVIDER` silently returns mock results.
3. **Prototype depends on a live private AWS RDS instance**; a reviewer cannot run it offline.

**Verdict: `READY_FOR_CLIENT_REVIEW_WITH_KNOWN_GAPS`** (see §23). No P0 corruption/blocker was found in the core search path; the gaps are deliverable-completeness and config-hardening, not core functionality.

---

## 2. Client Requirements Matrix

Extracted from `PROBLEM_STATEMENT.md`. Status verified against code, not README claims.

| Requirement | Source | Status | Evidence | Risk |
|---|---|---|---|---|
| Text natural-language search | §Problem | FULLY_IMPLEMENTED | `conversational_search_service.py`, `/v1/conversation/search` | Low |
| Voice/audio search, same pipeline as text | §Audio | FULLY_IMPLEMENTED | `voice.py /transcribe`, editable transcript → text pipeline | Low |
| "Rallies in Ireland" (country) | line 15 | FULLY_IMPLEMENTED | `sql.py:common` country aliases + `SEARCH_RALLIES` | Low |
| "Rallies in Donegal" (location) | line 16 | FULLY_IMPLEMENTED | city resolution + `donegl→clarification` handling | Low |
| "Rallies from 2025" (year) | line 17 | FULLY_IMPLEMENTED | `years` filter in `common()`, ungrounded-year guard | Low |
| "Which rallies did Driver X participate in?" | line 18 | FULLY_IMPLEMENTED | `SEARCH_DRIVER_RALLIES` → `participations()` via entry_list→sub_events→events | Low |
| "Which rallies did Driver X win?" | line 19 | FULLY_IMPLEMENTED | `SEARCH_DRIVER_WINS` → `classifications(winner=True)` + `FINAL_STAGE` | Low |
| "Who finished first in Rally X?" | line 20 | FULLY_IMPLEMENTED | `GET_RALLY_RESULTS` → single winner, limit forced to 1 | Low |
| "Top 10 finishers from Rally X" | line 21 | FULLY_IMPLEMENTED | `GET_RALLY_TOP_FINISHERS` → `classifications()` ordered by pos_overall | Low |
| "Jump highlights from Rally X" | line 22 | FULLY_IMPLEMENTED | `SEARCH_VIDEO_ACTIONS` + rally filter, `video_actions()` | Low |
| "Videos featuring Driver X" | line 23 | FULLY_IMPLEMENTED | `SEARCH_DRIVER_VIDEOS` → metadata.entry_list_id → entry_list | Low |
| "Top uploaders for Rally X" | line 24 | FULLY_IMPLEMENTED | `GET_TOP_UPLOADERS` → `top_uploaders()` | Low |
| "Drivers with most wins" | line 25 | FULLY_IMPLEMENTED | `GET_TOP_DRIVERS_BY_WINS` → `top_drivers()` | Low |
| Combo: "Ireland in 2025 where Driver X participated" | line 27 | FULLY_IMPLEMENTED | `rallies()` supports a driver participation subquery + country + year (AND across dimensions) | Low |
| Combo: "jump highlights featuring Driver X from Rally Y" | line 28 | FULLY_IMPLEMENTED | multi-entity `VIDEO_ACTIONS` routing (person+rally+action) | Low |
| Multiple filters / similar names / unknown / ambiguous | line 62 | FULLY_IMPLEMENTED | OpenEntity clarification, safety ordering, `donegl` clarify | Low |
| Conversational follow-ups (bonus) | line 65 | FULLY_IMPLEMENTED | `ResultReferentContext`, reducer, canonical-ID reuse | Low |
| "Biggest jumps" / "exciting moments from Rally X" | line 72 | PARTIALLY_IMPLEMENTED | Mapped to action search but ordered by `vm.id DESC` (recency), not by magnitude/`points` | Medium |
| Inverse: "drivers that participated in Rally X" | (audit prompt) | NOT_IMPLEMENTED (by design) | No `rally→participants` intent; documented as deferred | Low (not an explicit client example) |
| **Deliverable: sample/mock dataset** | line 81 | NOT_IMPLEMENTED | No SQL dump/seed shipped; relies on live AWS RDS | **High** |
| **Deliverable: README setup instructions** | line 82 | NOT_IMPLEMENTED | README is architecture-only; no install/run steps | **High** |
| **Deliverable: 10–15 example queries** | line 83 | PARTIALLY_IMPLEMENTED | Examples scattered as "known behaviors"; no consolidated demo list | Medium |
| Deliverable: source code | line 80 | FULLY_IMPLEMENTED | Full Flutter + FastAPI repo | Low |
| Deliverable: basic UI/API/CLI | line 84 | FULLY_IMPLEMENTED | Flutter UI + FastAPI API | Low |

---

## 3. Architecture Assessment

**Strong**
- Clean, enforced layering: `QueryUnderstanding → SearchQuery → Router → OpenEntity → SearchPlanBuilder → SearchPlan → Repository → MySQL`. Each layer is a separate module with a narrow contract.
- Strict schemas: `SearchQuery` and `SearchPlan` use Pydantic `extra="forbid"`; `SearchPlan` is `frozen=True` and self-validates strategy↔intent and filter compatibility.
- Deterministic router is genuinely pure (no LLM/DB), with an explicit `IntentCapability` matrix constraining cross-type recovery — this is what fixes the "max freeman → rally clarification" bug class.
- Validator hard-rejects model-supplied `driverIds` and unknown fields, enforcing "LLM never invents canonical IDs."
- Health/readiness separation and background OpenEntity warmup are correctly implemented (singleton + `asyncio.Lock` + dedicated connection).

**Weak / differs from documented architecture**
- **Rally canonical *IDs* are not carried into `SearchPlan` on a first-turn search.** The resolver replaces `rally_names` with the canonical *name* (e.g. `"Rally Alūksne 2026"`) and discards the resolved `event_id`. Drivers *do* get canonical `driver_ids`; rallies do not. Execution then matches rallies by `event_name LIKE`. The documented invariant "SearchPlan carries canonical IDs / IDs preferred over raw names" is only fully true for people. (§9, §10)
- **Injected `event_ids` are effectively dead.** In the conversation-referent path the orchestrator injects `trusted_rally_ids` into `SearchPlan.event_ids`, but `target_rally_names` returns `rally_names or event_ids` — and `rally_names` (canonical names) is always populated alongside, so `event_ids` is never consulted by the SQL filter. (§10)
- **Two full parallel implementations exist.** A complete legacy Dart pipeline (`lib/services/llm/**`, `lib/services/**/database_service`) mirrors the entire Python backend, gated by `SEARCH_BACKEND=legacy|python`. Documented as an intentional rollback switch, but it is a large drift/duplication surface. (§14, §17)
- DB plumbing is prototype-grade: `NullPool` (new connection per request) and an **ignored `DB_USE_SSL`** flag. (§15)

---

## 4. Critical Findings (P0 / P1)

No P0 (blocker/corruption/wrong-confident) finding was confirmed in the core search path. The P1 set below is dominated by *deliverable completeness* and *config safety*.

### P1-1 — Missing sample/mock dataset deliverable · REQUIREMENT_GAP
- **Client impact:** `PROBLEM_STATEMENT.md` line 81 explicitly lists "Sample/mock dataset" as a deliverable. None is shipped; the app only works against a private AWS RDS dev DB. A reviewer cannot run or evaluate the prototype offline.
- **Evidence:** No `*.sql`/seed/mock-data files in repo (only test fixtures). `.env` points at `pineamite-testing-dev-db...rds.amazonaws.com`.
- **Affected:** repo root, `README.md`, `backend/`.
- **Fix direction:** Ship a small MySQL seed/dump (or a SQLite/JSON fixture the repository can run against) covering the entities referenced in the examples; document loading it.

### P1-2 — README has no setup instructions · REQUIREMENT_GAP / DOCUMENTATION
- **Client impact:** Line 82 requires "README with setup instructions and a brief explanation of your approach." Current `README.md` is architecture-only — no `pip install`, `uvicorn`, `flutter run`, env, or DB steps.
- **Evidence:** `grep` for setup/install/run/getting-started across all root `.md` returns nothing.
- **Fix direction:** Add a "Getting Started" section (backend env + run, Flutter run, `SEARCH_BACKEND` switch, required keys).

### P1-3 — Default QU provider is `mock` with no production guard · CONFIGURATION
- **Client impact:** `config.py` defaults `query_understanding_provider="mock"` / `query_understanding_model="mock-parser-v1"`. If a deployment is missing `QUERY_UNDERSTANDING_PROVIDER`, the backend **silently serves mock parses** — wrong results with no error. `_build_query_service` accepts `mock` in production with no fail-fast.
- **Evidence:** `app/config.py:41`, `app/api/v1/conversation.py:61-70`.
- **Fix direction:** Either default to `gemini`, or refuse to start when `provider=mock` outside tests; fail-fast when `provider=gemini` and `GEMINI_API_KEY` is empty.

### P1-4 — Gemini fallback model drift · CONFIGURATION / DOCUMENTATION
- **Client impact:** In `config.py`, when provider=gemini and no model is given, the fallback is `gemini-3.6-flash` — **not** the documented/benchmarked `gemini-3.5-flash-lite`. A partial env would silently run an unbenchmarked model, invalidating the benchmark story.
- **Evidence:** `app/config.py` `_apply_env_fallbacks` (`elif p_lower in ("gemini","google"): ... or "gemini-3.6-flash"`).
- **Fix direction:** Make the fallback the benchmarked model, or drop implicit model fallbacks entirely.

### P1-5 — "Biggest jumps" / "exciting moments" not ranked by magnitude · DATA_SEMANTICS
- **Client impact:** These are called out in the client task (lines 71–73). The system routes them to action search but `video_actions()` orders by `vm.id DESC` (recency). A `points` column is selected but never used for ranking, so "biggest" is not honored.
- **Evidence:** `search_repository.py:96` `ORDER BY vm.id DESC`; `vm.points` selected but unused in ORDER BY.
- **Note:** The client frames these as stretch ("cannot be answered through simple metadata"), so this is a known-gap rather than a hard bug — but it is a visible mismatch a reviewer will notice.
- **Fix direction:** For magnitude-cued phrasing, order by `vm.points DESC` (deterministic, no model change needed).

---

## 5. Functional Search Coverage

All 9 intents are wired end-to-end (intent → strategy → repository handler), verified in `search_plan.py:INTENT_TO_STRATEGY` and `search_repository.py:handlers`:

| Intent | Strategy | Relational path | Correct? |
|---|---|---|---|
| SEARCH_RALLIES | RALLIES | `rally_events` (+ entry_list subquery for driver filter) | ✅ |
| SEARCH_DRIVER_RALLIES | PARTICIPATIONS | entry_list→sub_events→events, dedup by event | ✅ |
| SEARCH_DRIVER_WINS | DRIVER_WINS | rally_results + FINAL_STAGE + pos=1 | ✅ |
| GET_RALLY_RESULTS | RALLY_RESULTS | rally_results, single winner (limit 1) | ✅ |
| GET_RALLY_TOP_FINISHERS | TOP_FINISHERS | rally_results, pos_overall ASC | ✅ |
| SEARCH_VIDEO_ACTIONS | VIDEO_ACTIONS | video_metadata→video_actions→streams→…entry_list | ✅ |
| SEARCH_DRIVER_VIDEOS | DRIVER_VIDEOS | videos→metadata.entry_list_id→entry_list | ✅ |
| GET_TOP_UPLOADERS | TOP_UPLOADERS | videos→fan_profile→account | ✅ |
| GET_TOP_DRIVERS_BY_WINS | TOP_DRIVERS_BY_WINS | rally_results pos=1 + FINAL_STAGE | ✅ |

**Missing query classes**
- **Inverse participation** ("drivers that participated in Rally X" as an entry-list roster). Not an explicit client example; `GET_RALLY_TOP_FINISHERS` partially covers it (drivers *with results*, not all entrants). Documented as deferred — this is a **MISSING CAPABILITY, not a bug** (§19).
- **Magnitude ranking** ("biggest") — see P1-5.

---

## 6. Query Understanding

- Provider abstraction is clean (`providers/{gemini,openai,anthropic,mock}.py` behind `ProviderConfig`). Gemini uses structured output with `SearchQuery.model_json_schema()` and `responseMimeType: application/json`.
- **Schema is strict and safe:** `validate_provider_output` rejects unknown fields, rejects model-supplied `driverIds`, and constrains `actionTypes` to `ALLOWED_ACTIONS`. Invalid JSON → typed `OutputValidationError`. ✅ invariant "no SQL / no invented IDs".
- **Ungrounded year guard** works as documented: `_neutralize_ungrounded_temporal_filters` strips model years not present in raw text or committed context, and reports them in `neutralizedTemporalFilters`. ✅
- **Minor:** `ALLOWED_ACTIONS` (validator) and `ACTION_EXPANSIONS` (router) are two separate lists that don't fully overlap (validator allows `hairpin`, `water splash`, etc.; router only expands 10 verbs). Cosmetic; not a correctness bug. (P3)
- **Minor:** Gemini API key is passed in the request URL query string (`?key=...`) — standard for Gemini REST but can leak into logs. (P3, SECURITY)

---

## 7. Router

- Pure/deterministic; `IntentCapability` matrix constrains recovery per intent. `SEARCH_VIDEO_ACTIONS` has empty `allowed_primary_entity_types` and a 4-way filter set, so a residual with no cue resolves to `None` → clarification rather than defaulting to RALLY. ✅ (fixes the historical "max freeman → RALLY" bug).
- **"jump highlights featuring max freeman" → PERSON** verified: `person_cued` regex matches `featuring` and `PERSON ∈ allowed_filter_entity_types`, so recovery targets PERSON. ✅
- Residual accounting is conservative: only fires when no ENTITY field already exists, excludes `KNOWN_INTENT_FUNCTION_WORDS` and digits, and skips `GLOBAL_AGGREGATE_INTENTS`. ✅ (fixes "held in Afghanistan").
- **Edge:** "jump highlights **of** max freeman" (no `featuring`/`driver` cue, no `rally` cue) → target `None` → clarification. Safe but slightly less helpful than the `featuring` phrasing. Acceptable per safety ordering.

---

## 8. OpenEntity

- Taxonomy RALLY/PERSON/STAGE/UPLOADER; drivers are PERSON+`PersonRole`. Safety order `correct > clarify > no-match > wrong` is realized via thresholds (`min_confidence=0.75`, `min_score_gap=0.15`) and `_evaluate_candidate_selection`.
- **Exact-canonical-with-year precedence:** a year embedded in the phrase (`extract_year`) drives `identity_years`, and the multi-year ambiguity branch is skipped when years are explicit — so exact year-qualified names avoid spurious fuzzy ambiguity. ✅
- **Partial single-token driver names** → `partial_name_ambiguity` clarification (e.g. `donegl`-style) rather than wrong-confident pick. ✅
- **Duplicate-person identity:** distinct account identities with equal effective name and equal score → `duplicate_person_identity` clarification, keyed on `accountId or id` (no name-based merge). ✅
- Verified expected behaviors are covered by `test_master_regression_matrix.py` (shape A passes for `aluqsne`). See §17 for the one stale shape-B test.

---

## 9. SearchPlan

- `SearchQuery` is never executed directly in the conversational path; a `SearchPlan` is always compiled (`SearchPlanBuilder.build`). `/v1/search` also builds a plan. ✅
- Builder rejects ambiguous/unresolved resolutions (`UnresolvedEntityError`) and incompatible filters (`action_types` outside VIDEO_ACTIONS). ✅
- Pagination semantics enforced (GET_RALLY_RESULTS → limit 1/offset 0). ✅
- **Gap:** builder does **not** hydrate `event_ids`/`stage_ids` from `resolutions`; canonical *rally* identity reaches execution as a name, not an ID (see §3, §10). `stage_ids` in `SearchPlan` is always empty in practice.

---

## 10. Repository / Database Semantics

- Relational truth matches the documented paths: participation via `entry_list→sub_events→events` with `COUNT(DISTINCT event_id)`; wins/results via `rally_results` + `FINAL_STAGE` last-stage subquery; driver-video via `video_metadata.entry_list_id→entry_list`. ✅ No case observed of using participation as results or vice-versa.
- Dedup: `GROUP BY` + `COUNT(DISTINCT …)` used consistently across handlers. ✅
- Person-role handling threads through `PersonRole` in `people()` and classification filters. ✅
- **Finding (P2, ARCHITECTURE):** rally matching is `event_name LIKE %name% OR event_id = name.lower()` (`sql.py:60`). The `= event_id` half never matches because a canonical *name* string is passed, not an ID — confirming `event_ids` is dead in the filter. Correctness holds because year-qualified canonical names are effectively unique, but the "IDs are the execution key" claim is not met for rallies.
- **Finding (P2, PERFORMANCE):** `NullPool` opens a fresh RDS connection per request/warmup; contributes to the ~1.5s p50 HTTP latency and will not scale.

---

## 11. Conversation

- State is split into `SearchConversationSession` (query/history/generation) and `ResultReferentContext` (result-derived referents); reducer is pure. ✅
- **Canonical referent reuse** verified: `_reuse_committed_referent_ids` pulls committed rally/driver IDs out of open-set resolution and restores them, and injects `trusted_rally_ids` into the plan — so "Show videos from that rally" reuses the prior event identity without re-resolving from display text. ✅ (Note the `event_ids`-unused caveat in §10; behavior is still correct because the canonical name is also carried.)
- Generation/stale-response handling: `next_request()` increments a generation that non-committing outcomes retain; the Flutter side rejects responses whose `requestId` != active. ✅
- Flows A–G (videos-from-rally, jumps-from-rally, who-won-it, year refinement, his-videos, unrelated-country-replace, ambiguous→clarify) are structurally supported by referent merge + reducer + `removeFilter`/`addFilter`. Flow F (old referent must not leak into an unrelated query) is handled because a new country/rally turn refines rather than inherits the stale rally (referent only reused when the same name reappears).

---

## 12. Clarification

- **Chip selection preserves the pending query, not `activeQuery`.** `PendingClarification.select` operates on the pending parsed query, replaces only the ambiguous dimension, injects the canonical candidate ID directly, and does **no** LLM call. The screen builds `PendingClarification` from `result.parsedQuery ?? result.query` and passes `requestId` for stale rejection. ✅ This is exactly the documented fix for "jump highlights from karl martin from rally ireland."
- Selection → `_executeDeterministicSearch` → `/v1/search` (plan build, no resolution) using the canonical IDs already in the selection. ✅
- Stale-generation rejection: `select()` returns `null` when `currentRequestId != requestId`. ✅

---

## 13. Voice

- Cloud path matches docs: recorder → m4a → `POST /v1/voice/transcribe` (whisper-1) → editable transcript. `_speech_provider` refuses non-openai providers (503).
- **`/transcribe` does not touch the DB** (only the speech provider) — matches the requirement. ✅
- **No auto-submit:** `_handleVoiceTranscriptReceived` only fills the text field; the user must press search. Audio is disposed after transcript retention (`detailed?.disposeAudio()`), and again in `finally` on the Python path. ✅
- A combined `POST /v1/voice/search` (transcribe+search) exists server-side, but the general search screen uses transcribe-only + manual submit, so the invariant holds for the shipped UI.
- STT remains explicitly PROVISIONAL (whisper-1) per docs; human validation deferred — consistent everywhere.

---

## 14. Flutter / Backend Contract

- Intent enum parity: Dart `SearchIntent.toIntentString()` ↔ Python `SearchIntent` (SCREAMING_SNAKE) match exactly. `PersonRole` (`DRIVER`/`CO_DRIVER`) and `MatchMode` (`ANY`/`ALL`) match. ✅
- JSON field parity: Dart emits camelCase (`rallyNames`, `driverIds`, `actionTypes`, `yearFrom`, `driverMatchMode`, `personRole`); Python `SearchQuery`/`SearchPlan` accept those via aliases + `populate_by_name`. Backwards snake_case also accepted on the Dart `fromMap`. ✅
- Session round-trip: `ConversationSearchRequest.session` deserializes a `SearchConversationSession`; a dedicated parity suite exists (`tests/parity/test_conversation_parity.py`, `backend/benchmarks/conversation/fixtures/…json`).
- **Risk (P2, TECH_DEBT):** the legacy Dart pipeline is a second source of truth for the same contract. `Dart.SearchIntent.fromString` defaults unknown → `searchRallies` (silent misclassification rather than error). `MIGRATION.md` also notes the legacy Dart SQL "does not filter uploaders" — a legacy-only gap.

---

## 15. Startup / Deployment

- `/health` returns 200 immediately; `/ready` returns 503 until `is_entity_search_ready()`, then 200 with `entityCount`. ✅
- Warmup is backgrounded via lifespan; `get_shared_entity_search_service` coalesces on the in-flight task and otherwise builds once under `_warmup_lock` — no duplicate index builds; failures set `_last_error` and allow a later on-demand rebuild (not permanently wedged). ✅
- **Finding (P2, CONFIGURATION):** `DB_USE_SSL` is declared in `Settings` but **never applied** — `database_url` adds only `?charset=utf8mb4`, and `engine.py` passes no `ssl`/`connect_args`. Credentials to RDS are not TLS-protected by the app despite `DB_USE_SSL=true` in `.env`. This is adjacent to the explicitly-deferred "verified RDS CA TLS," but note it is currently *no* app-level TLS, not merely *unverified* TLS.
- **Finding (P2, PERFORMANCE):** `NullPool` — see §10.

---

## 16. Benchmark Audit

**Reproducibility: strong.** Independently verified:
- Gold dataset `query_understanding_gold.jsonl` = **392 lines** (matches the "392 cases" claim). ✅
- SHA256 = `b7fd39226592281c565c0e835c16b460654f43cd2da4bc09655a5abf06972662` — **exact match** to `BENCHMARKS.md`. ✅

- Two-checkpoint methodology (raw model vs full system) is real and reflected in `scripts/` and `benchmarks/`. Hallucination-audit, downstream-hardening replay, and STT bakeoff have corresponding report artifacts under `backend/benchmarks/results/**` and `backend/tests/integration/STT*_REPORT.md`.
- **Caveat:** headline numbers (system success 76%→80.36%, latency, cost) were **not re-executed** in this audit (they require paid API calls / live DB, and the task said not to rerun expensive benchmarks). They are *artifact-backed* but *not re-derived here*. The dataset identity being verifiable materially raises confidence.
- **Caveat:** STT conclusions rest on 5 human rows / 1 speaker — the docs are appropriately candid that this is insufficient (PROVISIONAL). No overclaim detected.

---

## 17. Test Coverage

- **170+ backend unit tests pass**, covering router, residual filtering, search_plan, search_query, reducer, referents, resolver safety, identity, phonetics, fallback state machine, startup readiness, voice, API.
- **The committed suite is currently RED — 1 failing unit test:** `tests/unit/test_master_regression_matrix.py::test_shape_b_empty_entity_fields_recovery_aluqsne`. Root cause: the test builds `SearchContext(extra={"unresolved_mentions": …})` but omits `routing_plan`, while the resolver's empty-entity recovery now *requires* `routing_plan` in `context.extra` to derive rally mentions. The production orchestrator sets both (`conversational_search_service.py:302-303`), so **production is correct and the test is stale**. Still, a red committed suite is a client-review liability. (P2, TEST_GAP)
- **Heavy live-DB reliance:** most integration coverage (`test_live_db_*`, `test_live_voice`, benchmark runners) needs the RDS instance and/or paid providers — fragile and not runnable in a clean checkout, compounding P1-1.
- **Coverage gaps worth naming:** no offline end-to-end test of the Flutter clarification-chip → `/v1/search` round trip; magnitude-ranking ("biggest") has no test because it isn't implemented.

---

## 18. Documentation Consistency

`PROBLEM_STATEMENT` ↔ `README` ↔ `ARCHITECTURE` ↔ `SUMMARY` ↔ `LEARNINGS` ↔ `CONTEXT` ↔ `BENCHMARKS` are unusually consistent with each other and with the code. Contradictions found:

1. **Model config drift (docs vs code):** all docs + `.env.example` say `gemini-3.5-flash-lite`; `config.py` fallback is `gemini-3.6-flash`, and the default provider is `mock`. (P1-3/P1-4)
2. **`DB_USE_SSL` (config vs behavior):** documented/enabled but not applied. (§15)
3. **Deliverables (client vs repo):** setup instructions, sample dataset, and a consolidated example-query list are promised by `PROBLEM_STATEMENT` but absent. (§4)
4. **"Canonical IDs in SearchPlan" (docs vs code):** true for drivers, not for rallies/stages. (§9-10)
5. **`.env` vs `.env.example` drift:** `.env` sets `SEARCH_BACKEND=python` and carries stale `LLM_PROVIDER=openai`/`OPENAI_MODEL=gpt-5.6-luna`; `.env.example` sets `SEARCH_BACKEND=legacy`. Precedence in `config.py` favors `QUERY_UNDERSTANDING_PROVIDER` so the stale keys are inert, but they are confusing. (P3)

---

## 19. Product Capability Gaps (BUG vs MISSING CAPABILITY)

| Item | Classification | Notes |
|---|---|---|
| "drivers that participated in Rally X" (roster) | **MISSING CAPABILITY** | No `rally→participants` intent; documented/deferred. Not an explicit client example. |
| "biggest jumps" ranked by magnitude | **MISSING CAPABILITY** (small) | Data exists (`vm.points`); ordering not implemented. Deterministic fix available. |
| "exciting moments from Rally X" | **MISSING CAPABILITY** (interpretive) | Treated as generic highlights; acceptable interpretation, no semantic "excitement" model. |
| Default provider `mock` served silently | **BUG (config)** | Should fail-fast; P1-3. |
| Gemini fallback `gemini-3.6-flash` | **BUG (config drift)** | P1-4. |
| `event_ids` carried but unused in SQL | **BUG (latent)** | Harmless today; violates stated design. |
| `DB_USE_SSL` ignored | **BUG (config)** | Flag no-op. |
| Stale failing unit test | **BUG (test)** | Production correct; test not updated. |

---

## 20. Risk Register

| Risk | Severity | Likelihood | Impact | Recommendation |
|---|---|---|---|---|
| No sample dataset + no setup docs; reviewer can't run prototype | P1 | High | High | Ship seed dataset + Getting-Started; before client review |
| Deploy missing QU env → silent mock results | P1 | Medium | High | Fail-fast on `mock` in prod; remove implicit model fallback |
| Gemini fallback model ≠ benchmarked model | P1 | Medium | Medium | Pin fallback to `gemini-3.5-flash-lite` |
| "biggest/exciting" mismatch noticed in demo | P2 | Medium | Medium | Order VIDEO_ACTIONS by `points` for magnitude cues |
| Red test suite (1 stale test) | P2 | High (already red) | Low-Med | Pass `routing_plan` in the test's context |
| `DB_USE_SSL` ignored → plaintext creds to RDS | P2 | High | Medium | Apply `ssl` connect_args (still within deferred CA-verification) |
| `NullPool` per-request connections | P2 | High | Medium | Use a bounded async pool for production |
| Dual Dart/Python implementations drift | P2 | Medium | Medium | Pick one as source of truth post-cutover; freeze/retire legacy |
| Live secrets in local `.env` (untracked) + real host/user in tracked `.env.example` | P3 | Low | Low-Med | Rotate the dev DB/API creds that were shared; scrub host/user from `.env.example` |

---

## 21. Recommended Fix Order

1. **Ship a runnable sample dataset + README setup section** (P1-1, P1-2). Highest client-review leverage; no core-code risk.
2. **Harden provider config** (P1-3, P1-4): fail-fast on `mock`/empty key in prod; pin the Gemini fallback to the benchmarked model.
3. **Fix the stale unit test** so the committed suite is green (P2) — pass `routing_plan` in the shape-B test's `SearchContext`.
4. **Deterministically order "biggest" video actions by `points`** (P1-5) — small, high-visibility win.
5. **Apply `DB_USE_SSL`** in `engine.py` connect args, and switch `NullPool` → a bounded pool for production (P2).
6. **Consolidate a 10–15 example-query demo list** in the README (P1/§4).
7. (Optional, non-urgent) Decide the fate of the legacy Dart pipeline; make `SearchPlan` actually carry `event_ids`/`stage_ids` to match the documented invariant.

> Each of the above is a small deterministic change. **No rewrite is warranted** — the architecture is sound.

---

## 22. What Should NOT Be Changed (freeze)

- The layer boundary and its contracts: `QueryUnderstanding → SearchQuery → Router → OpenEntity → SearchPlanBuilder → SearchPlan → Repository`.
- The `IntentResolutionRouter` + `IntentCapability` matrix (this is what fixed the whole "residual defaults to RALLY" bug class).
- `OutputValidationError` guards (reject model `driverIds`, unknown fields, non-canonical actions).
- The ungrounded temporal guard.
- OpenEntity safety ordering and clarification thresholds.
- Health/readiness split + background warmup singleton/lock.
- `PendingClarification.select` pending-query preservation and no-LLM chip selection.
- Voice no-auto-submit + DB-free `/transcribe`.
- The benchmark methodology and the (verified-identity) gold dataset.

---

## 23. Final Verdict

### `READY_FOR_CLIENT_REVIEW_WITH_KNOWN_GAPS`

**Justification.** The core deliverable — a flexible, reliable AI text+voice search over rally data — is genuinely built and works: every client example query maps to a correct intent and a correct relational execution path, the deterministic architecture is real and well-tested, conversation/clarification/voice invariants hold, and the benchmark story is reproducible at the dataset level. No P0 corruption or wrong-confident-execution blocker was found.

It is **not** unconditionally ready because of *completeness and hardening* gaps that a client will notice: the explicitly-required sample dataset and setup instructions are missing (the prototype can't be run offline), and there are latent config footguns (default `mock` provider, model fallback drift, ignored SSL) plus one red (stale) test. All are small, low-risk fixes. Close P1-1 through P1-4 and the project moves to `READY_FOR_CLIENT_REVIEW`.
