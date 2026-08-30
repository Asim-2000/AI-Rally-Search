# Downstream Pipeline Efficiency Audit

> Audit date: 2026-08-29 · Branch: `audit` · Scope: `SearchQuery → conversation → Router → OpenEntity → SearchPlanBuilder → SearchRepository → MySQL → mapping → Flutter`, plus startup where it affects request latency. **Audit only — nothing was modified.** LLM/STT/prompt/model tuning is explicitly out of scope.
>
> Findings are tagged **MEASURED** (backed by existing benchmark/timing artifacts), **INFERRED** (obvious from the code path, not separately profiled), or **SPECULATIVE** (plausible, needs profiling).

---

## 1. Executive Summary

**The downstream pipeline is architecturally efficient and, for its data volume, cheap.** After warmup, entity resolution is fully in-memory (zero DB calls), retrieval uses an inverted index (not full scans), and a normal search touches the DB exactly **once per connection with two queries**. There is no N+1, no per-request index rebuild, and no accidental DB access during resolution. The dominant *absolute* request latency is the Gemini QU call (~850 ms p50, out of scope), so downstream work is a minority of wall-clock time.

Within the downstream budget (everything after the LLM), the real, actionable costs are:

1. **Connection management — `NullPool` opens a fresh RDS connection (+ handshake) every request.** Biggest easy latency win. (INFERRED/MEASURED-adjacent)
2. **Two DB round-trips per search (`rows` + a separate `COUNT(DISTINCT …)`)** that re-executes the *entire* join graph — for the 6-join VIDEO_ACTIONS strategy this doubles the heaviest query. (INFERRED)
3. **Double entity scoring** — the in-memory index scores candidates (`score_name`), then `DatabaseEntityResolver._score_candidates` throws that away and re-scores every returned candidate with the much heavier `compute_composite_score`, **twice per candidate**. (INFERRED)
4. **Rally identity executes by `LOWER(event_name) LIKE '%…%'`** even though a canonical `event_id` was resolved and discarded — a leading-wildcard, function-wrapped predicate that cannot use an index. Carrying `event_ids` into the SearchPlan turns this into indexed equality. (INFERRED)
5. **Unbounded conversation history with full `SearchResponse` bodies is serialized both directions every turn**, growing O(turns × results). (INFERRED, grows with session length)

**Is the architecture itself efficient?** Yes. None of the above requires an architectural change — they are localized, low-risk tweaks. The layering does not cause the costs.

**Top 5 optimization opportunities:** bounded async connection pool · single-round-trip count (`COUNT(*) OVER()` or omit count when `len<limit`) · reuse the index score / avoid re-scoring (or at least compute `compute_composite_score` once, not twice) · carry `event_ids`/`stage_ids` into the plan for indexed rally/stage filters · trim `response` bodies (or cap depth) from the session payload crossing the API.

---

## 2. Request Cost Model

Per representative query. "OpenEntity calls" = adapter/`search_service.search` invocations (each = 1 candidate-gen + scoring pass over a bounded pool, **in-memory, no DB**). "DB queries" = SQL statements executed. All queries share **1 connection/request** (NullPool → that connection is newly opened).

| Query | OpenEntity Calls | DB Queries | Connections | Repeated Work | Main Cost |
|---|---:|---:|---:|---|---|
| A. Rallies in Ireland | 0 | 2 (rows+count) | 1 (new) | `resolve()` invoked but no-op | LLM + 2 DB RTT + connect |
| B. Rallies in Ireland in 2025 | 0 | 2 | 1 (new) | year-guard scan of raw text (cheap) | LLM + 2 DB RTT + connect |
| C. Show Rally Aluksne | 1 (RALLY) | 2 | 1 (new) | **double scoring** (index + resolver×2) | LLM + entity scoring + 2 DB |
| D. Show Max Freeman's rallies | 1 (PERSON, largest pool) | 2 | 1 (new) | **double scoring**; person pool up to 50 | LLM + person scoring + 2 DB |
| E. jump highlights featuring max freeman | 1 (PERSON) | 2 (6-join rows + 6-join count) | 1 (new) | double scoring; **count re-runs 6 joins** | LLM + person scoring + 2 heavy DB |
| F. jump highlights from karl martin from rally ireland | 2 (RALLY + PERSON, **sequential**) | 2 (6-join) | 1 (new) | 2× double scoring; count re-runs joins | LLM + 2 entity scorings + 2 heavy DB |
| G. Show videos from that rally (follow-up of C) | **0** (referent reuse) | 2 | 1 (new) | trusted `event_id` injected but unused in SQL | LLM + 2 DB (no fuzzy lookup ✅) |

Notes:
- **A/B/G confirm the good news:** direct-filter and canonical-referent paths perform **zero** OpenEntity candidate scoring. G proves canonical reuse avoids a new fuzzy lookup, exactly as designed.
- `resolve()` is always invoked when a resolver is configured (`conversational_search_service.py:346`), even for A/B where there are no entities — but it short-circuits before any candidate work (one `model_copy` + context check). Negligible.
- Clarification-chip selection (not shown) → `/v1/search` → **no LLM, no OpenEntity**, just plan build + 2 DB queries. Efficient and correct.

---

## 3. Router

Efficient and cheap; keep as-is.
- Pure in-memory, no DB/LLM. `INTENT_CAPABILITIES` and `KNOWN_INTENT_FUNCTION_WORDS` are module/class-level constants → constant-time lookups.
- Regexes are inline string literals passed to `re.search`/`re.findall`; Python's internal `re` cache (~512 compiled patterns) makes recompilation effectively free at this scale. A micro-optimization would pre-compile them as module constants, but the benefit is negligible. (SPECULATIVE, LOW)
- Residual analysis runs **once**, only when no ENTITY field already exists, and is gated by function-word/ digit filtering — no duplicated passes.
- **Direct filters correctly skip OpenEntity:** country/city/year/stage-number/action produce `DIRECT_FILTER` routes and never enter candidate resolution (verified in cost model A/B). ✅

No router finding rises above LOW.

---

## 4. OpenEntity

Retrieval design is sound: index built once at warmup; per-`_IndexedName` normalization, collapsed form, token set, bi/tri-grams, and phonetic key are **precomputed and cached** (`service.py:_IndexedName`). Query-side normalization/phonetics are computed **once per search** (`service.py:184-189`), not per candidate. Candidate generation is an inverted-index posting-list merge, not a scan.

Findings:

- **OE-1 (INFERRED, MEDIUM CPU) — Double scoring across two engines.** `InMemoryEntitySearchService.search` already scores and rank-orders candidates via `score_name` and returns the top `limit`. The resolver (`resolver._score_candidates`) then **ignores that score** and recomputes `compute_composite_score` for every returned candidate. `compute_composite_score` is heavy (jaro-winkler + levenshtein + dice bi/tri-gram + token-window + acoustic fold + optional transliteration), and internally **re-normalizes** its inputs on nearly every sub-call (e.g. `dice_bigram`, `jaro_winkler` each call `normalize()` again on already-normalized strings). This is the single largest downstream CPU item after the LLM.
- **OE-2 (INFERRED, LOW-MEDIUM CPU) — `compute_composite_score` called twice per candidate.** `_score_candidates` computes `base_score` (no year context) and `score` (with year) separately. When there is no year context the two are identical → the second call is pure waste. Even with year context, only the context boost differs; the expensive lexical core is recomputed.
- **OE-3 (INFERRED, LOW-MEDIUM CPU) — Full `universe` built on every query even when unused.** `InvertedIndexCandidateGenerator.generate` (`candidate_generator.py:193-197`) materializes the entire role-filtered candidate list of that entity type on every request, but `universe` is only consumed on the `suspicious` full-scan-escape branch. For PERSON (largest type) this is a list comprehension + role check over all people per query, thrown away in the common case. Compute it lazily only when `suspicious`.
- **OE-4 (INFERRED, LOW) — City resolution has no in-memory path.** `EntitySearchLookupAdapter` is constructed without `city_fallback` (`conversation.py:85`), so `lookup_cities` always returns `[]`, and `_resolve_city` then performs its rally-fallback lookups (up to 2–3 `lookup_rallies` calls) for any city mention. Cities are rare in the query mix, so impact is small, but the fallback path does redundant lookups.
- **Good:** no per-request index rebuild; no DB access after warmup; cross-type recovery only fires when the primary type fails and the capability matrix allows it (bounded, not blanket).

Threshold note: none of the above touches confidence thresholds or safety ordering — these are pure compute-reduction items.

---

## 5. Conversation / Referents

- **Canonical referent reuse works and avoids fuzzy work** (`_reuse_committed_referent_ids`): a follow-up naming the active rally/driver is pulled out of open-set resolution and restored with its committed ID — cost-model G shows **0 OpenEntity calls**. No "ID → name → re-resolve" round trip observed. ✅
- **CV-1 (INFERRED, MEDIUM — grows with session length) — Unbounded history with embedded responses on the wire.** `SessionTurnSnapshot.response: SearchResponse` is stored in `history`, history grows unbounded (`record_turn: [*self.history, snapshot]`), and `/v1/conversation/search` returns the **entire session** — including every prior turn's full result list — which the client then sends back on the next turn. Payload and serialize/deserialize cost grow O(turns × results/turn). A 10-turn session at 20 results/turn ships ~200 embedded rows each direction, every turn.
- **CV-2 (INFERRED, LOW CPU) — `copy_with` deep-copies unchanged sub-models.** `model_copy()` of `active_query`/`previous_query`/`referents` runs even when a field is unchanged. Cheap relative to serialization; not worth changing on its own.
- Stale-generation handling is a single integer compare (`active_request_id`); no overhead concern.

---

## 6. Clarification

Efficient. `PendingClarification.select` replaces only the ambiguous dimension, injects the canonical candidate ID directly, and the re-execution goes through `/v1/search` → **no LLM, no OpenEntity** (verified). Selection re-execution is exactly 2 DB queries. Nothing to optimize here; protect it (§17).

---

## 7. SearchPlan

- **SP-1 (INFERRED, LOW CPU + enables §8 win) — Canonical IDs are not carried; `event_ids`/`stage_ids` are effectively dead.** The builder emits rally identity as a canonical *name* (`rally_names`) and never hydrates `event_ids`/`stage_ids` from `resolutions`. In the referent path the orchestrator injects `event_ids`, but `SearchPlan.target_rally_names = rally_names or event_ids` means `event_ids` is never consulted while a name is present. The waste is small in CPU terms, but it **forces the repository into `LIKE '%name%'`** instead of an indexed `event_id IN (...)` (see SQL-3). This is the one SearchPlan change with a *measurable repository benefit*.
- **SP-2 (P3, no runtime cost) — Dead `match query.intent` block** in `SearchPlanBuilder.build` (all branches `pass`). Cosmetic; remove for clarity only.
- No repeated validation passes; the plan is built once per request in both the conversation and `/v1/search` paths. No redundant double-build observed.

Per the brief: I am **not** recommending a SearchPlan rewrite for cleanliness — only SP-1, and only because it yields an indexed SQL predicate.

---

## 8. Repository / SQL

Every strategy runs the same shape: one `rows` query + one `count` query, both built from the shared `Filters`. Explicit column lists (no `SELECT *`). `GROUP BY` + `COUNT(DISTINCT …)` are used to dedup fan-out joins and are generally *necessary* given the join graph.

| ID | Finding | Strategies affected | Type | Fix / benefit | Correctness risk | Index helps? |
|---|---|---|---|---|---|---|
| SQL-1 | **Separate `COUNT(DISTINCT …)` re-runs the full join graph** — a second RTT re-executing all joins (6 joins for VIDEO_ACTIONS/DRIVER_VIDEOS). | all except GET_RALLY_RESULTS (which uses `len(data)`) | INFERRED, MEDIUM | Use `COUNT(*) OVER()` in the rows query to get total in one RTT; or skip the count entirely when `len(rows) < limit and offset == 0` (total is then known). Halves DB round-trips for the common single-page case. | Low | n/a |
| SQL-2 | **`LOWER(col) = …` / `LOWER(col) LIKE …` on country/city/event_name/stage** wrap indexed columns in a function and use leading wildcards → forces full scans. | RALLIES, PARTICIPATIONS, VIDEO_ACTIONS, DRIVER_VIDEOS | INFERRED, LOW-MED | Prefer case-insensitive collation comparisons or a normalized column; anchor LIKE where possible. Data is small today, so impact is modest. | Low | Yes (collation/generated column) |
| SQL-3 | **Rally identity matched by `LOWER(event_name) LIKE '%name%' OR event_id = name`** (`sql.py:60`); the `= event_id` half never matches (a name is passed). With SP-1 fixed, this becomes `ev.event_id IN (:ids)` — indexed equality, no `LOWER`, no wildcard. | RALLIES, VIDEO_ACTIONS, DRIVER_VIDEOS, results/finishers via rally filter | INFERRED, MEDIUM | Carry resolved `event_ids` into the plan and filter by PK. Removes the heaviest text predicate on the largest filtered table. | Low (IDs are exact) | Yes (PK) |
| SQL-4 | **`FINAL_STAGE` correlated subquery** (`rally_stages ⋈ rally_results GROUP BY event_id` to find each event's last classified stage) is embedded in every classification query. | DRIVER_WINS, RALLY_RESULTS, TOP_FINISHERS, TOP_DRIVERS_BY_WINS | INFERRED, MEDIUM (data-dependent) | Correct as written (not N+1 — one subquery per statement), but it re-derives last-stage per query. Candidate for a small cached/materialized "final stage per event" map if these intents get hot. | Low | Composite `(event_id, stage_id)` on `rally_results`; `(event_id, stage_number)` on `rally_stages` |
| SQL-5 | **`people()` builds token-AND `LIKE '%tok%'` predicates** for driver names even when a canonical `driver_id` is available. | RALLIES (driver subquery), PARTICIPATIONS, VIDEO_ACTIONS, DRIVER_VIDEOS | INFERRED, LOW | When `driver_ids` is present the name LIKEs are redundant (IDs already filter). Prefer ID equality and drop the name OR-branch when IDs exist. | Low | Yes (FK/PK on driver_id) |

No N+1, no `SELECT *`, no obviously spurious `DISTINCT` (each `COUNT(DISTINCT)` corresponds to a real fan-out). `LIMIT/OFFSET` are correctly placed on the rows query.

---

## 9. Database Connection Management

**Verdict: `NullPool` is the highest-value, lowest-risk downstream fix.**

- Per normal search: **1 connection opened and torn down** (request-scoped via `get_connection` → `engine.connect()`), plus TLS handshake cost *if* SSL were applied (note: `DB_USE_SSL` is currently a no-op per the prior audit, so today it's a TCP+auth handshake). Against RDS over a network this per-request setup is a recurring fixed tax on every request.
- Warmup uses its **own** `engine.connect()` (`warmup.py:53`), independent of request connections. ✅ No contention there.
- OpenEntity resolution uses **no** connection (in-memory). So the only connection is the repository's.
- A bounded async pool removes per-request connect/teardown. Suggested starting point (tune to RDS `max_connections` and worker count):
  - `poolclass`: default async `QueuePool` (drop `NullPool`)
  - `pool_size`: 5 · `max_overflow`: 5
  - `pool_pre_ping`: `True` (survive RDS idle drops)
  - `pool_recycle`: 1800 (under RDS/Proxy idle timeout)
- **Caveat (why NullPool was chosen):** async connections must not cross event loops/workers. This is safe with a single uvicorn worker per process; with multiple workers, size the pool as `pool_size × workers ≤ RDS max_connections` and keep each worker's pool bound to its own loop. Because of this caveat the change is **LOW-MEDIUM risk, not LOW** — validate under the actual Railway worker topology.

---

## 10. API / Serialization

- **API-1 (INFERRED, MEDIUM — grows with session) — Full session round-trips (see CV-1).** The largest serialization cost is re-encoding accumulated history+responses each turn, not the per-turn models themselves.
- **API-2 (INFERRED, LOW CPU) — Per-request JSON-schema generation.** All three QU providers call `SearchQuery.model_json_schema(by_alias=True)` on **every** request (`gemini_provider.py:27`, `openai_provider.py:54`, `anthropic_provider.py:23`). The schema is static; wrap in a module-level `@lru_cache`/constant. Small, safe.
- **API-3 (INFERRED, LOW) — Payloads include fields never rendered.** Result rows carry full metadata maps (e.g. `retrievalSignals`, `candidateOrigin`) useful for debugging but shipped to the client. Trim for production responses if payload size matters.
- No egregious model→dict→model churn in the hot path; Pydantic alias conversion is one pass per boundary.

---

## 11. Caching Opportunities

Only safe, clearly-scoped caches (index is immutable for the process lifetime → invalidate on rebuild):

| Cache | Key | Value | Lifetime | Invalidation | Risk |
|---|---|---|---|---|---|
| **Cross-request entity resolution** (currently per-request only — resolver is rebuilt each request, `conversation.py:86`) | `(entity_type, normalized_phrase, year, country, city, event_id, person_role, is_video_search)` | `EntityResolution` (resolved candidate or clarification set) | Process life | On OpenEntity index rebuild/warmup reset | LOW — key must include **all** context that affects scoring/selection (listed) or it will mis-serve; otherwise deterministic |
| **Static QU JSON schema** (API-2) | provider/model constant | serialized schema | Process life | Never (static) | LOW |
| **Country alias map** | already module-level constant | — | — | — | Already cached ✅ |
| **`FINAL_STAGE` last-stage-per-event** (SQL-4) | `event_id` | last classified stage id | Short TTL or per-warmup | TTL / results write | MEDIUM — results can change; needs a staleness policy, so only if these intents get hot |

**Do NOT cache:** ambiguous/clarification resolutions without the full context key; mutable per-session conversation state as if global; DB result sets without a staleness policy. `compute_composite_score` itself could be `lru_cache`d on `(query_phrase, candidate_name, year, is_person)` if the resolver-scoring path is retained — LOW risk, pure function.

---

## 12. Async / Parallelism Opportunities

- **Entity resolution is CPU-bound and in-memory** (no `await` on IO inside scoring). Query F's two entity lookups (rally + person) run sequentially, but `asyncio.gather` would **not** help — there is no IO to overlap and the event loop is single-threaded. **Do not parallelize scoring.** The right lever is *less* work (OE-1/OE-2/OE-3), not concurrency.
- **The two DB queries (`rows` then `count`) are sequential IO on one connection.** They cannot run concurrently on a single connection, and issuing them on two pooled connections doubles connection use. The better fix is to **eliminate the second round-trip** (SQL-1), not parallelize it.
- **Startup `load_entities`** already issues 4 independent bulk queries sequentially on one warmup connection. These *could* be gathered on separate connections, but warmup is background/off the request path — not worth the added connection pressure. (SPECULATIVE, LOW)

Net: **no safe request-latency parallelism win exists**; the gains are all in work-reduction and connection reuse.

---

## 13. Dead / Redundant Work

- Double entity scoring (OE-1) and its 2×-per-candidate call (OE-2).
- Full `universe` materialized-but-unused per query (OE-3).
- `count` query re-executing the whole join graph (SQL-1).
- `= event_id` predicate that can never match (SQL-3) and the resolved `event_id` being discarded (SP-1).
- Per-request JSON-schema regeneration (API-2).
- `resolve()` invoked for pure direct-filter queries (short-circuits; negligible).
- Dead `match query.intent` block in the plan builder (SP-2).
- Redundant `normalize()` calls inside `compute_composite_score`'s sub-functions on already-normalized inputs.

---

## 14. Index Recommendations

Only indexes tied to observed WHERE/JOIN/ORDER BY. Verify existing indexes before adding; do not add blindly.

| Index | Rationale (query pattern) | Priority |
|---|---|---|
| `rally_events(event_id)` used as PK filter | Unlocks SQL-3 `event_id IN (...)` once SP-1 carries IDs; also `ORDER BY start_date DESC` benefits from `(start_date)` | High (paired with SP-1) |
| `rally_events(start_date)` | `ORDER BY ev.start_date DESC LIMIT` in RALLIES/PARTICIPATIONS | Medium |
| `rally_results(rally_id, stage_id)` and `rally_stages(event_id, stage_number)` | `FINAL_STAGE` subquery join+group (SQL-4) | Medium |
| `rally_entry_list(sub_event_id)`, `rally_sub_events(event_id)` | participation join path | Medium |
| `rally_video_metadata(video_id)`, `rally_video_metadata(entry_list_id)`, `rally_video_actions(id)` | VIDEO_ACTIONS/DRIVER_VIDEOS join path | Medium |
| Case-insensitive collation (or generated normalized column) on `event_name`, `country`, `city`, `stage_name` | removes `LOWER()`/enables index on SQL-2 text predicates | Low-Medium |

These are **candidate** indexes — confirm against `SHOW INDEX` and `EXPLAIN` on the live schema before creating any.

---

## 15. Optimization Matrix

| ID | Optimization | Impact | Effort | Risk | Measured/Inferred | Recommendation |
|---|---|---|---|---|---|---|
| CONN-1 | Replace `NullPool` with bounded async pool (`pre_ping`, `recycle`) | HIGH (per-request latency) | SMALL | LOW-MED (worker/loop topology) | INFERRED | Do, after confirming Railway worker count vs RDS max_connections |
| SQL-1 | Single-round-trip count (`COUNT(*) OVER()` or skip when `len<limit`) | HIGH (DB load/latency) | SMALL-MED | LOW | INFERRED | Do |
| SP-1+SQL-3 | Carry `event_ids`/`stage_ids` into SearchPlan; filter by PK | MEDIUM-HIGH | MEDIUM | LOW | INFERRED | Do (also fixes documented "IDs in plan" invariant) |
| OE-2 | Compute `compute_composite_score` once (skip duplicate base/score) | MEDIUM (CPU) | SMALL | LOW | INFERRED | Do |
| OE-1 | Reuse index score / avoid full re-scoring in resolver | MEDIUM (CPU) | MEDIUM | MEDIUM (scoring parity) | INFERRED | Consider — validate against regression matrix first |
| OE-3 | Build `universe` lazily only on full-scan escape | LOW-MED (CPU) | SMALL | LOW | INFERRED | Do |
| CACHE-1 | Process-level entity-resolution cache (full context key) | MEDIUM (repeat queries) | MEDIUM | LOW | INFERRED | Do (careful key) |
| CV-1/API-1 | Trim `response` bodies / cap history depth in session payload | MEDIUM (long sessions) | MEDIUM | MEDIUM (rollback UX) | INFERRED | Consider — decide rollback re-exec policy |
| API-2 | Cache static QU JSON schema | LOW (CPU) | SMALL | LOW | INFERRED | Do (trivial) |
| SQL-5 | Drop name LIKEs when `driver_id` present | LOW-MED | SMALL | LOW | INFERRED | Do |
| SQL-2/IDX | Collation/index for text predicates | LOW-MED | MEDIUM | LOW | INFERRED | Defer until data grows |
| SP-2 | Remove dead `match` block | — | SMALL | LOW | INFERRED | Cosmetic |

---

## 16. Top Quick Wins (small effort, low risk)

1. **API-2** — module-level cache of the static QU JSON schema. Trivial, safe.
2. **SQL-1** — skip the count query when `offset == 0 and len(rows) < limit` (total is already known); otherwise switch to `COUNT(*) OVER()`. Halves DB work for the common single-page search.
3. **OE-2** — don't call `compute_composite_score` twice per candidate when there is no year context.
4. **OE-3** — compute the full `universe` list only on the `suspicious` branch.
5. **SP-2** — delete the dead `match query.intent` block (readability, zero risk).

`CONN-1` (pool) is the biggest win but is SMALL-effort / LOW-MED risk (topology validation), so it sits just outside "quick win" only because it needs a production-topology check.

---

## 17. Changes NOT Recommended (protect from premature optimization)

- **Do not parallelize entity resolution or the two DB queries.** Scoring is CPU-bound in-memory (no IO to overlap); the count fix is elimination, not concurrency. Parallel DB queries would only increase connection pressure.
- **Do not lower confidence thresholds or `min_score_gap` for speed.** Safety ordering (clarify > wrong-confident) must stay.
- **Do not restructure the layer boundaries** (`Router → OpenEntity → SearchPlan → Repository`). The costs are localized; the architecture is not the problem.
- **Do not touch the clarification/referent reuse paths** — they are already the cheapest correct paths (G = 0 OpenEntity calls; selection = 0 LLM/OpenEntity).
- **Do not remove `GROUP BY`/`COUNT(DISTINCT)`** — each corresponds to a real join fan-out; removing them corrupts totals/dedup.
- **Do not add indexes blindly** — confirm with `EXPLAIN` on the live schema first.
- **Do not cache ambiguous resolutions or session state globally.**

---

## 18. Recommended Implementation Order

1. **API-2, SQL-1, OE-2, OE-3, SP-2** — quick wins, low risk, no topology dependencies.
2. **CONN-1** — bounded pool, after validating Railway worker count vs RDS `max_connections`.
3. **SP-1 + SQL-3 (+ PK index)** — canonical IDs into the plan → indexed rally/stage filters; also closes a documented-invariant gap.
4. **CACHE-1** — process-level entity-resolution cache with a full context key.
5. **OE-1** — deeper scoring consolidation, gated on passing the regression matrix (scoring-parity risk).
6. **CV-1/API-1** — session payload trimming / history cap, once the rollback re-execution policy is decided.
7. **SQL-2/4/5 + remaining indexes** — as data volume grows; driven by `EXPLAIN`.

---

## 19. Expected Improvement (qualitative — no fabricated percentages)

| Item | Request latency | DB load | CPU | Memory | Complexity |
|---|---|---|---|---|---|
| CONN-1 (pool) | ↓ removes per-request connect/handshake on **every** request | neutral | neutral | slightly ↑ (idle conns) | slightly ↑ |
| SQL-1 (single count) | ↓ one DB RTT per search (biggest on 6-join VIDEO_ACTIONS) | ↓↓ ~halves join execution for single-page results | neutral | neutral | neutral |
| SP-1+SQL-3 (IDs) | ↓ heaviest text predicate → indexed PK equality | ↓ on rally-filtered queries | neutral | neutral | ↓ (also fixes invariant) |
| OE-1/OE-2/OE-3 | ↓ small (CPU is minor vs LLM) but removes redundant work | neutral | ↓↓ entity-scoring CPU | neutral | OE-2/3 ↓, OE-1 slightly ↑ |
| CACHE-1 | ↓ on repeated popular entity phrases | neutral (in-memory) | ↓ repeated scoring | ↑ (cache) | ↑ (invalidation) |
| CV-1/API-1 | ↓ growing serialization on long sessions | neutral | ↓ encode/decode | ↓ payload | ↑ (rollback policy) |
| API-2 | ↓ marginal per request | neutral | ↓ marginal | neutral | ↓ |

**Bottom line:** the two changes that move real wall-clock time are **CONN-1** (per-request connection setup) and **SQL-1** (second DB round-trip). Everything else is correctness-preserving cleanup and CPU trimming whose absolute effect is dwarfed by the (out-of-scope) LLM call but which reduces downstream load and tail latency.
