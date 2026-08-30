# Offline Search Architecture

> **Status: IMPLEMENTED (2026-08-30).**
>
> Normal rally search now works offline, on intermittent connectivity, and on
> very low bandwidth, via a deterministic, model-free local mirror of the
> authoritative pipeline. The online pipeline is unchanged; the legacy in-app
> Dart LLM / direct-MySQL search pipeline was **not** restored. See
> **Implementation Status** below for what actually shipped (files, schema,
> real snapshot sizes, and benchmark metrics). The design sections that follow
> describe the shipped system.

---

## Requirements

Hard requirement: **normal rally search must keep working** when the device is:

- completely offline,
- on intermittent connectivity,
- on very low bandwidth.

This is not limited to easter-egg / special queries.

Design constraints (from the brief and confirmed against the codebase):

- Offline search must be **deterministic, lightweight, local, safe, explainable, syncable**, and usable on low-end phones.
- **No LLM** may be required for offline behaviour (no local Gemini, no local Whisper for parsing).
- The online pipeline stays authoritative:
  `Flutter → FastAPI → Query Understanding (gemini-3.5-flash-lite) → deterministic recovery → IntentResolutionRouter → OpenEntity → SearchPlan → SearchRepository → MySQL`.
- Do **not** restore the legacy Dart AI/LLM search pipeline
  (`lib/services/llm/*`, `lib/services/database_service.dart`, `lib/services/entity_search/mysql_entity_search_data_source.dart`).
- Accuracy is more important than latency.
- No DB credentials, API secrets, or raw MySQL access may ship in the Flutter client.

---

## Current Limitations

Findings from the audit of the current tree:

1. **The Flutter client has no local persistence layer at all.**
   `pubspec.yaml` declares only `http`, `mysql_client`, `video_player`, `record`,
   `speech_to_text`, `flutter_dotenv`, `intl`. There is **no** `sqflite`, `drift`,
   `hive`, `isar`, `path_provider`, `shared_preferences`, or `connectivity_plus`.
   Offline storage is greenfield.

2. **The only legitimate runtime path today is fully network-dependent.**
   `lib/services/python_search_api_client.dart` is explicit: *"When [the backend]
   is absent the app surfaces a clean error rather than falling back to any in-app
   engine."* There is no `SEARCH_BACKEND` switch. Today, no backend ⇒ no search.

3. **A legacy offline-capable path exists but is forbidden and unsafe as-is.**
   `lib/services/database_service.dart` (58 KB) connects Flutter **directly to AWS
   RDS MySQL** using credentials from `.env` (`DB_HOST/DB_USER/DB_PASSWORD/…`).
   `lib/services/llm/*` is the legacy in-app LLM parser and
   `lib/services/entity_search/*` is the legacy in-app entity resolver. These must
   **not** be revived: they ship DB credentials to the device, bypass the
   authoritative pipeline, and violate the security constraints. They are useful
   only as *reference* for the deterministic (non-LLM) entity-scoring maths.

4. **Online entity resolution is deterministic and non-LLM — and therefore
   portable.** `backend/app/entity_search/` resolves entities with pure algorithms:
   `scorer.py` (dice-bigram similarity, composite scoring), `phonetics.py`
   (soundex + algorithmic pronunciation encoder), `transliteration.py`,
   `normalization.py` (year extraction, descriptor stripping). No model call is
   involved in entity resolution. This maths can be re-expressed locally in Dart.

5. **The semantic IR is flat, closed, and offline-friendly.**
   `SearchQuery` (`backend/app/domain/search_query.py`) is a small closed set of
   list fields (`countries`, `cities`, `years`, `year_from/to`, `rally_names`,
   `event_names`, `stage_names`, `stage_numbers`, `driver_names`, `driver_ids`,
   `action_types`, `uploaders`, `person_role`, `driver_match_mode`) over exactly
   **9 intents**. `SearchPlan` maps 1:1 to 9 `ExecutionStrategy` handlers in
   `search_repository.py`. This gives us a stable, model-free target structure an
   offline parser can emit and a local executor can run.

6. **Video rows carry playback URLs, not media.** The DB stores
   `rally_streams.on_demand_url` and `rally_videos.thumbnail`. Finding a video
   offline is a metadata operation; **playing** it is a network operation unless
   the media/thumbnail is separately cached.

---

## Offline Capability Matrix

Per-intent classification against what each `ExecutionStrategy` in
`search_repository.py` actually reads.

| Intent | Strategy / source tables | Offline class | Why |
|---|---|---|---|
| `SEARCH_RALLIES` | `RALLIES` — `rally_events` (+ `rally_stages` for count, + participation subquery when a driver filter is present) | **FULLY_OFFLINE_CAPABLE** | Pure filter over a small local `rallies` table (111 rows) by country/city/year/name; driver-participation filter needs the local `participation` table. |
| `SEARCH_DRIVER_RALLIES` | `PARTICIPATIONS` — `rally_entry_list → rally_sub_events → rally_events` | **FULLY_OFFLINE_CAPABLE** | Needs a compact local `participation` (person↔event) table. |
| `SEARCH_DRIVER_WINS` | `DRIVER_WINS` — `rally_results` final-stage `pos_overall=1` | **FULLY_OFFLINE_CAPABLE** | Served from a **pre-computed** local `final_results` / `driver_wins` snapshot (avoids shipping per-stage results + `FINAL_STAGE` subquery). |
| `GET_RALLY_RESULTS` | `RALLY_RESULTS` — winner of one rally (final stage, `pos_overall=1`, single) | **FULLY_OFFLINE_CAPABLE** | One lookup in the local `final_results` snapshot for the resolved `event_id`. |
| `GET_RALLY_TOP_FINISHERS` | `TOP_FINISHERS` — final-stage classification ordered by `pos_overall` | **FULLY_OFFLINE_CAPABLE** | Local `final_results` snapshot ordered by position. |
| `SEARCH_VIDEO_ACTIONS` | `VIDEO_ACTIONS` — `rally_video_metadata → rally_video_actions → rally_streams` | **PARTIALLY_OFFLINE_CAPABLE** | *Discovery* is local (video/action metadata table). *Playback* requires network unless the stream is cached. Thumbnails need caching to render offline. |
| `SEARCH_DRIVER_VIDEOS` | `DRIVER_VIDEOS` — `rally_videos ← rally_video_metadata ← rally_entry_list` | **PARTIALLY_OFFLINE_CAPABLE** | Same as above: metadata local, playback networked. |
| `GET_TOP_UPLOADERS` | `TOP_UPLOADERS` — aggregate `COUNT(rally_videos)` by uploader | **FULLY_OFFLINE_CAPABLE** | Served from a **pre-computed** local `uploader_stats` aggregate. |
| `GET_TOP_DRIVERS_BY_WINS` | `TOP_DRIVERS_BY_WINS` — winners aggregated by driver | **FULLY_OFFLINE_CAPABLE** | Served from a **pre-computed** local `driver_wins` aggregate. |

**Summary — two independent dimensions.** "Offline capability" has two axes that
must not be collapsed into one number:

**A. Data / execution capability** (can local data answer this intent's query?)

- **7 of 9 intents are fully executable from local data** — `SEARCH_RALLIES`,
  `SEARCH_DRIVER_RALLIES`, `SEARCH_DRIVER_WINS`, `GET_RALLY_RESULTS`,
  `GET_RALLY_TOP_FINISHERS`, `GET_TOP_UPLOADERS`, `GET_TOP_DRIVERS_BY_WINS`.
- **2 of 9 (both video intents)** are local for **metadata discovery**, but
  **playback is networked** (`SEARCH_VIDEO_ACTIONS`, `SEARCH_DRIVER_VIDEOS`).
- No intent is `REQUIRES_NETWORK` for *search*; only video *playback* is
  inherently networked.

**B. Query-understanding capability** (can the offline parser interpret the way a
user phrased it?)

- The offline deterministic parser has **intentionally narrower natural-language
  coverage than Gemini**. It handles the canonical and common phrasings (see
  Offline Query Understanding) and **safely declines** anything it cannot ground —
  it never guesses.
- Therefore **"fully executable offline" ≠ "full online natural-language
  parity."** An intent counted as fully executable in dimension A can still be
  phrased in a way the offline parser declines in dimension B; that is a safe
  decline, not a failure. Coverage of dimension B is measured by
  `OFFLINE_COVERAGE_RATE` (see Offline Parity Benchmark).

This is a precision fix, not a weakening: the *execution* capability is unchanged;
we are simply not conflating it with *language* capability.

---

## Local Data Model

Design principle: **do not mirror MySQL.** Ship a compact, denormalised,
read-only snapshot shaped to the 9 execution strategies. Pre-compute the two
aggregate/classification concerns server-side so the device never runs the
`FINAL_STAGE` subquery or stores per-stage results.

Proposed local SQLite schema (device-friendly, indexed for the filter columns):

```sql
-- metadata / bookkeeping
meta(key TEXT PRIMARY KEY, value TEXT)        -- schema_version, data_version, last_sync_utc, snapshot_id

rallies(
  event_id TEXT PRIMARY KEY,
  event_name TEXT, name_norm TEXT,            -- name_norm = normalized for matching
  country TEXT, city TEXT,
  year INTEGER, start_date TEXT, end_date TEXT,
  status TEXT, stages_count INTEGER
)

people(                                       -- one row per canonical person identity
  person_id TEXT PRIMARY KEY,                 -- person:account:<id> | person:driver:<id> | person:codriver:<id>
  display_name TEXT, name_norm TEXT,
  searchable_names TEXT,                       -- JSON array (driver + codriver aliases)
  role TEXT,                                   -- driver | co_driver | both
  driver_id TEXT, codriver_id TEXT, account_id TEXT,
  country TEXT
)

stages(
  stage_id TEXT PRIMARY KEY,
  event_id TEXT, stage_name TEXT, name_norm TEXT,
  stage_number TEXT
)

participation(                                -- SEARCH_DRIVER_RALLIES / driver filter on SEARCH_RALLIES
  event_id TEXT, person_id TEXT, role TEXT,
  PRIMARY KEY(event_id, person_id, role)
)

final_results(                                -- pre-computed final-stage classification (GET_RALLY_RESULTS / TOP_FINISHERS / DRIVER_WINS)
  event_id TEXT, person_id TEXT,
  driver_name TEXT, pos_overall INTEGER,
  PRIMARY KEY(event_id, person_id)
)

driver_wins(                                  -- pre-computed aggregate (GET_TOP_DRIVERS_BY_WINS)
  person_id TEXT PRIMARY KEY, driver_name TEXT, win_count INTEGER
)

uploader_stats(                               -- pre-computed aggregate (GET_TOP_UPLOADERS)
  uploader_id TEXT PRIMARY KEY, account_id TEXT, uploader_name TEXT, upload_count INTEGER
)

video_meta(                                   -- SEARCH_DRIVER_VIDEOS discovery
  video_id INTEGER PRIMARY KEY,
  event_id TEXT, stage_id TEXT, person_id TEXT,
  driver_name TEXT, thumbnail_url TEXT,
  on_demand_url TEXT,                          -- URL only; NOT the media bytes
  length_seconds REAL, created_at TEXT
)

video_actions(                                -- SEARCH_VIDEO_ACTIONS discovery
  id INTEGER PRIMARY KEY,
  video_id INTEGER, event_id TEXT, stage_id TEXT, person_id TEXT,
  action_type TEXT, driver_name TEXT,
  start_action REAL, end_action REAL, points REAL,
  on_demand_url TEXT, thumbnail_url TEXT
)

-- suggested indexes
CREATE INDEX ix_rallies_country ON rallies(country);
CREATE INDEX ix_rallies_year ON rallies(year);
CREATE INDEX ix_part_person ON participation(person_id);
CREATE INDEX ix_final_event ON final_results(event_id);
CREATE INDEX ix_vmeta_person ON video_meta(person_id);
CREATE INDEX ix_vact_action ON video_actions(action_type);
CREATE INDEX ix_vact_person ON video_actions(person_id);
```

The offline **entity index** (rallies / people / stages / uploaders for fuzzy
resolution) is built in memory at app start from `rallies`, `people`, `stages`,
`uploader_stats` — mirroring what `MySqlEntitySearchDataSource.load_entities()`
produces server-side, but sourced from local SQLite instead of MySQL.

**Storage technology:** SQLite via **`sqflite`** (mature, ubiquitous, low
overhead, ships on iOS+Android; the app targets phones). `drift` is a reasonable
typed alternative if compile-time query safety is wanted later. Avoid Hive/Isar —
we want relational filtering that mirrors the SQL strategies. Add `path_provider`
(DB location) and `connectivity_plus` (reachability signal). This matches the
"check what the app already uses" instruction: the app uses none, so we pick the
smallest relational option that fits the 9 strategies.

---

## Sync Strategy

**Rule: the device never touches MySQL.** A new backend endpoint produces a
compact snapshot; Flutter stores it. This keeps the authoritative pipeline and
DB access server-side.

Proposed endpoint (new, additive):

```
GET /v1/offline/snapshot?schema=<n>&since=<iso8601|absent>
```

- **Initial bootstrap** (`since` absent): full compact snapshot of every local
  table above, plus `snapshot_id`, `schema_version`, `data_version`,
  `generated_at`. Format: gzip NDJSON per table (streamable, resumable) — or a
  pre-built SQLite file for the full bootstrap when bandwidth allows.
- **Incremental sync** (`since=<last_sync_utc>`): only rows changed since the
  timestamp, plus a `deletions` list (tombstones) per table keyed by primary key.
  Requires server-side `updated_at` (or a change log) on source tables; where a
  source table lacks it, that table falls back to periodic full refresh.
- **Versioning:** `schema_version` (shape of the local DB) and `data_version`
  (content revision). Client sends the `schema` it understands; a server bump
  forces a full bootstrap and local rebuild.
- **Stale-data handling:** persist `last_sync_utc`; surface age in the UI (see UX
  States). Data is usable while stale; never blocked on freshness.
- **Deleted records:** applied from the `deletions` tombstone list; never inferred
  from absence (absence in an incremental page ≠ deletion).
- **Interrupted / retried sync:** write into a **staging** DB/tables, verify row
  counts + `snapshot_id`, then **atomic swap** (single transaction / file rename).
  A half-applied sync never becomes the live DB. Resume from `since` on retry with
  exponential backoff.
- **App upgrade:** on launch compare bundled `schema_version` to stored; migrate
  or re-bootstrap. Keep the old DB readable until the new one is committed.

Sync triggers: first launch, app foreground after a threshold, manual
pull-to-refresh, and opportunistically after any successful online search.

---

## Offline Query Understanding

**No local LLM. No second AI architecture. No dynamic SQL.** A narrow,
deterministic parser emits the *same* `SearchQuery` structure the backend uses,
so the offline path and online path share one IR and one result shape.

Pipeline:

```
raw text (typed or on-device transcript)
  → normalize (lowercase, strip punctuation, collapse spaces)   [port of normalization.py]
  → special-query match (shared entry point; see Special Queries)
  → deterministic feature extraction:
       • year / year-range   ("2025", "2023-2025", "since 2020")   [extract_year]
       • country / city      (COUNTRIES alias table from sql.py)
       • action type         (jumps, crashes, … → action_types)
       • role cue            ("co-driver" → person_role)
       • intent cue keywords ("who won", "top drivers", "videos of",
                              "rallies in", "wins", "uploaders", "results")
       • residual phrase     → entity index (rally / person / stage / uploader)
  → intent selection (deterministic precedence table over the 9 intents)
  → SearchQuery { intent, countries, cities, years, …, driverNames/Ids, actionTypes, … }
```

Worked examples (all expressible without a model):

| Query | Intent | Key fields |
|---|---|---|
| "rallies in ireland in 2025" | `SEARCH_RALLIES` | `countries=[ireland] years=[2025]` |
| "rally aluksne" | `SEARCH_RALLIES` | rally entity → `rally_names/eventIds` |
| "max freeman rallies" | `SEARCH_DRIVER_RALLIES` | person entity → `driver_ids` |
| "who won rally donegal" | `GET_RALLY_RESULTS` | rally entity → `event_ids` |
| "videos of max freeman" | `SEARCH_DRIVER_VIDEOS` | person entity → `driver_ids` |
| "jumps from rally ireland" | `SEARCH_VIDEO_ACTIONS` | `actionTypes=[jump]` + rally/country |
| "top drivers by wins" | `GET_TOP_DRIVERS_BY_WINS` | (aggregate) |

Intent precedence must be explicit and deterministic (e.g. an action cue +
person ⇒ `SEARCH_VIDEO_ACTIONS`, mirroring the online VIDEO_ACTIONS routing fix
in `CONTEXT.md`). The parser must be **conservative**: emit only what it can
ground in the raw text or the local entity index — same discipline as the
backend's grounded direct-filter recovery and ungrounded-temporal guard.

Explainability: the offline `SearchQuery` (and which cue produced each field) is
logged/surfacable, so an offline result can always be explained.

---

## Entity Resolution

Reuse the **deterministic** resolution family from `backend/app/entity_search/`
(dice-bigram + soundex + pronunciation encoder + transliteration +
descriptor/year stripping) — re-expressed in Dart against the local entity index.
This is *not* the forbidden legacy pipeline: it is model-free scoring, and it is
built fresh over the compact local index rather than reviving
`mysql_entity_search_data_source.dart` or the LLM parser.

Requirements preserved offline:

- rally typo recovery (`aluqsne → Rally Alūksne`),
- person typo recovery (`max freemn → Max Freeman`),
- ambiguity detection (`donegl → clarify`),
- clarification instead of a wrong confident guess.

**Safety ordering is identical and non-negotiable:**

```
correct confident > correct clarification > safe no-match > wrong confident
```

Offline mode **clarifies rather than guesses**. Confidence thresholds are never
lowered to force an offline answer. If the local index cannot confidently resolve
an entity and cannot form a genuine clarification, it returns a safe no-match with
the offline-scope hint — it never fabricates a canonical ID.

Because canonical IDs in the local index are the *same* IDs used online
(`event_id`, `person:account:*`, `stage_id`, `fan_id`), a resolution made offline
stays valid if the same query is later re-run online.

---

## Search Execution

Offline execution mirrors the server's `ExecutionStrategy` dispatch, but over
SQLite instead of MySQL, and using **static parameterised queries** (one
hand-written query per strategy — never dynamically generated SQL):

```
SearchQuery
  → (local) IntentResolutionRouter + entity resolution   [deterministic, in-memory]
  → (local) SearchPlan  (canonical IDs + filters)         [same contract as backend]
  → (local) LocalSearchExecutor                            [9 fixed strategies over SQLite]
  → SearchResponse (same result item shapes: RallyResultItem, ParticipationItem,
                    ClassificationItem, VideoActionItem, VideoItem, UploaderItem,
                    DriverWinsItem)
```

Each of the 9 strategies maps to one parameterised SQLite query built to match
the semantics of its `search_repository.py` counterpart (OR within a dimension,
AND across dimensions; country alias expansion from the `COUNTRIES` table;
`final_results` used for wins/classification instead of the `FINAL_STAGE`
subquery). The executor returns the identical `SearchResponse` envelope so the UI
render path is shared between online and offline.

---

## Voice

Keep both voice paths; only the transcription source differs.

- **Cloud voice** (`record` → `.m4a` → `POST /v1/voice/transcribe` → whisper-1):
  **requires network. Offline: NO.**
- **On-device voice** (`speech_to_text`, already a dependency): can use the OS
  on-device recognizer. Where the device/OS supports on-device dictation
  (`onDevice` mode), it produces a transcript **offline** which feeds directly
  into the offline deterministic parser:

  ```
  on-device STT → transcript → local deterministic parser → local search
  ```

  On-device availability is device/OS-dependent, so offline voice is **YES where
  the device supports on-device recognition**, otherwise gracefully unavailable.

**No auto-submit** — unchanged. The transcript remains editable before search in
both paths.

---

## Special Queries

Re-audit result: the earlier draft's list ("greetings, identity, capabilities,
jokes, unsupported deflections") was **incomplete**. The complete, currently-
shipping special-query taxonomy is defined in **three agreeing sources** and must
be ported in full.

**Authoritative sources (exact, to be ported verbatim — do not invent copy):**

- Backend matcher + copy: `backend/app/services/special_query.py`
  (`match_special_query()`, the `_EXACT` map, and the two regex rules).
- Client matcher (already deterministic, standalone): `SpecialQueryMatcher.match()`
  in `lib/services/special_query_matcher.dart`.
- Client copy catalog (already the centralized store): `FriendlyResponseService`
  `_catalog` in `lib/services/friendly_response_service.dart`.

**Personality categories actually present (9), with original copy to port:**

| Category | Trigger examples | Original copy (verbatim) |
|---|---|---|
| `weather` | "weather", "what's the weather", "how is the weather" | *"Hopefully sideways — that makes rallying more interesting. I'm better with stages than forecasts though."* |
| `greeting` | hi / hello / hey / good morning-afternoon-evening | *"Hello! Ready to find a rally, driver, stage, result or video?"* (2nd variant: *"Hi, navigator. What rally are we looking for?"*) |
| `thanks` | thanks / thank you / cheers / thanks a lot | *"Any time, navigator. See you at the next stage."* |
| `identity` | who are you / what are you / what is your name | *"I'm AI Rally Search — your navigator for rallies, drivers, stages, results and videos."* |
| `capabilities` | what can you do / help / what do you do | *"I can find rallies, drivers, stages, results and rally videos. Try asking for a winner, event or year."* |
| `joke` | tell me a joke / say something funny / rally joke | *"Why did the rally driver bring a pencil? To draw the perfect racing line."* |
| `alive` | are you alive / are you real | *"Not alive, but the search engine is running. Give me a rally query and we'll hit the stage."* |
| `rallyOpinion` | "who is/was the best/greatest rally driver (of all time)?" (regex) | *"That's how arguments start in a service park. I can show you wins and results and let you decide."* |
| `unsupported` | "what is the capital of …", "how do i cook/bake/make …" (regex) | *"Wrong stage, navigator. I can help with rallies, drivers, stages, results and videos."* (`UNSUPPORTED_QUERY`) |

`FriendlyResponseService` additionally holds **error/state** cheesy copy already
in production (`noResults`, `parseFailure`, `networkError`, `timeout`,
`serverError`, `emptyVoice`). These are reused directly by the connectivity/offline
states below — the offline work does **not** need to author new copy for them.

**Offline architecture for special queries:**

```
raw text
  → LOCAL SpecialQueryMatcher   (ported verbatim from the sources above)
  → SpecialResponse             (category + verbatim copy)
  → [if no match] offline normal-query parser
```

The matcher runs at the **shared offline query entry point, before** the normal
rally parser — exactly as the backend checks specials ahead of the pipeline. It
is a **tiny deterministic product feature** (static string set + two regexes): it
stays **separate** from rally parsing and must **not** grow into a local
AI/query-understanding engine. Porting it does **not** reintroduce the legacy Dart
AI pipeline — `special_query_matcher.dart` and `friendly_response_service.dart`
are already standalone deterministic client files, independent of `lib/services/llm/*`.

---

## Low-Bandwidth Behaviour

Three strategies were evaluated:

| Strategy | Behaviour | Verdict |
|---|---|---|
| `ONLINE_AUTHORITATIVE` | always online, error if unreachable | Rejected — fails the offline requirement. |
| `LOCAL_FIRST_WITH_REFRESH` | show local immediately, silently replace with online | **Rejected as default** — causes the *silent semantic inconsistency* (result flips under the user) the brief forbids. |
| `NETWORK_FIRST_WITH_LOCAL_FALLBACK` | try online within a bandwidth-aware budget; on offline/timeout run local, clearly labelled | **Recommended.** |

**Recommended: `NETWORK_FIRST_WITH_LOCAL_FALLBACK`.** Because accuracy > latency
and the backend is authoritative:

1. If connectivity looks usable, attempt the online search within a short,
   bandwidth-aware timeout budget.
2. On success → authoritative online result (no offline label).
3. On offline / timeout / backend error → deterministic **local** result, clearly
   labelled *"Offline results"* with last-updated age.
4. Never show a local result and then silently swap it for a different online one.

`LOCAL_FIRST_WITH_REFRESH` may be offered later only as an *explicit, opt-in*
"show cached first" affordance — never as the silent default.

**Pending-request UX (bounded fallback).** Accuracy stays more important than
latency, but the user must **not** stare at a long network timeout before the
offline fallback appears. The policy (exact numbers to be tuned later, **not**
now):

- Fast reachability pre-check (`connectivity_plus`): if the device is plainly
  offline, skip the online attempt and go straight to local (no wasted wait).
- If online is attempted, apply a **short bandwidth-aware fallback budget** —
  materially shorter than the full request timeout (which stays at 35 s for the
  worst case). When the budget elapses without a response, **surface the local
  result immediately** in the `LOW_BANDWIDTH_LOCAL_FALLBACK` state while the online
  request keeps running in the background.
- If the online response then arrives and is authoritative, promote it **only via
  an explicit, non-jarring affordance** ("HQ answered — show latest") — never a
  silent swap under the user (consistent with rejecting `LOCAL_FIRST_WITH_REFRESH`).
- No indefinite spinner: the user always reaches either an authoritative online
  result or a clearly-labelled local result within the budget.

Exact budget/timeout values are deliberately left unspecified here and will be
tuned during implementation; the shape is fixed, the numbers are not.

---

## UX States

The app has a deliberate cheesy rally/motorsport personality (see the
`FriendlyResponseService` catalog). **Every** user-facing connectivity/offline
state must follow the product-tone pattern — never generic system copy:

1. **playful rally headline**, then
2. **clear plain-English explanation**, then
3. **an obvious action.**

Not every message is joke-heavy; the headline is a light touch, the explanation
is literal. The full copy is enumerated in the **User-Facing Messaging Matrix**
below. Behavioural rules per state:

- **Online result:** no offline chrome.
- **Offline result:** subtle-but-visible banner/chip with rally headline +
  last-updated age. Do **not** style every card as an error.
- **Stale / very stale data:** show the last-updated state; results remain usable;
  escalate the headline once the snapshot age crosses a threshold.
- **Video discovery offline:** cards render from metadata; each carries a clear
  playback state — *metadata available* shows card/title/action/driver/stage
  (thumbnail if cached); *media unavailable offline* shows the rally-themed
  "can't play offline" state, never implying offline playback.
- **Query exceeds offline capability:** rally headline + the literal "needs
  internet" explanation + reassurance that the query is preserved, plus the
  offline-scope hint (*"Offline search supports rallies, drivers, years,
  countries, and cached results."*).
- **Ambiguity offline:** show the same clarification chips as online (deterministic
  candidate selection), never a silent guess.
- **Voice:** cloud-voice-offline and on-device-voice-unavailable each have their
  own headline + action (fall back to on-device / to typing).

---

## User-Facing Messaging Matrix

Rally-themed headline + plain explanation + primary action for every
connectivity/offline state. Copy is illustrative product tone (to be finalised
with product/design); error/state rows reuse the existing `FriendlyResponseService`
personality. Keep wording concise.

| State | Rally-themed headline | Plain explanation | Primary action |
|---|---|---|---|
| `ONLINE` | *(no offline chrome)* | — | Show results normally |
| `OFFLINE_LOCAL_RESULTS` | "Still racing — even without signal 🏁" | "Searching the rally data saved on this device." | Show local results + last-updated |
| `OFFLINE_STALE_RESULTS` | "Running on the latest service-park notes" | "Updated 2 hours ago." | Show results; offer refresh when online |
| `LOW_BANDWIDTH_LOCAL_FALLBACK` | "Bit of a slow stage out there…" | "We're using local rally data while the connection catches up." | Show local now; keep trying online |
| `BACKEND_UNREACHABLE_LOCAL_AVAILABLE` | "The pit crew can't reach HQ right now" | "You're still searching with the data saved on this device." | Show local results, labelled |
| `BACKEND_UNREACHABLE_LOCAL_UNSUPPORTED` | "This one needs a quick radio check with HQ 📡" | "This search needs an internet connection. Your query is still here — try again when you're back online." | Preserve query; Retry |
| `NO_LOCAL_SNAPSHOT` | "We haven't packed the service notes yet" | "Connect once to download rally data for offline search." | Sync now (when online) |
| `SYNC_IN_PROGRESS` | "Loading the pace notes…" | "Downloading rally data for offline search." | Progress; allow background |
| `SYNC_FAILED` | "Radio dropped mid-message" | "Couldn't finish the update. Your existing offline data still works." | Retry sync; keep old data |
| `SYNC_COMPLETE` | "Service notes are fresh 🏁" | "Offline rally data is up to date." | Dismiss |
| `CLOUD_VOICE_OFFLINE` | "Cloud radio is out of range 📡" | "On-device voice is still available." | Switch to on-device voice |
| `ON_DEVICE_VOICE_UNAVAILABLE` | "Can't pick up the pace notes on this device" | "Voice isn't available offline here — you can still type your search." | Fall back to typing |
| `VIDEO_METADATA_OFFLINE` | "Found the clip in the notes" | "Details saved on this device." | Show card (playback gated) |
| `VIDEO_PLAYBACK_UNAVAILABLE` | "Found the clip — but the stream's off-stage" | "You're offline, so the video can't play right now." | Save/queue; play when online |
| `OFFLINE_AMBIGUITY` | "Two cars on the same stage 🏁" | "A few matches fit — which did you mean?" | Show clarification chips |
| `OFFLINE_SAFE_NO_MATCH` | "Even the marshals couldn't find that one" | "No match in the offline data. Try another spelling or fewer filters." | Refine query |
| `OFFLINE_QUERY_UNSUPPORTED` | "That's a stage we can't run offline yet" | "This kind of search needs a connection. Offline covers rallies, drivers, years, countries, and cached results." | Retry online later |

Usability rule for all rows: **fun headline → literal explanation → obvious
action.** Never make every card look like an error, and never let the headline
replace the literal explanation or the action.

## Storage Estimate

Using current DB scale (~111 rallies, ~8.7k people, ~1k stages, plus
participation / results / video metadata):

| Table | Rows (est.) | Bytes/row (est.) | Size (est.) |
|---|---|---|---|
| `rallies` | 111 | ~150 | ~17 KB |
| `people` | ~8.7k | ~90 | ~780 KB |
| `stages` | ~1k | ~70 | ~70 KB |
| `participation` | ~8–12k | ~40 | ~0.3–0.5 MB |
| `final_results` | ~3–6k | ~45 | ~0.2–0.3 MB |
| `driver_wins` + `uploader_stats` | ~1–2k | ~50 | ~0.1 MB |
| `video_meta` + `video_actions` | ~10–40k | ~130 | ~1.5–5 MB |
| **Subtotal (data)** | | | **~3–7 MB** |
| Indexes (~30–50%) | | | **~1–3 MB** |

- **Core snapshot** (everything except video metadata): **~2–4 MB** — trivial on
  any phone.
- **Full snapshot** (incl. video/action metadata): **~5–12 MB** typical,
  worst-case ~15–20 MB if video-action rows are large. Video metadata dominates.
- **No video binaries / no thumbnails** are stored by default (URLs only).
  Optional thumbnail caching would be a separate, bounded, LRU media cache — not
  part of the base snapshot.

Recommendation: ship the **core snapshot** as the mandatory bootstrap and treat
**video metadata as an optional, separately-syncable segment** so low-end / low-
bandwidth devices can opt into a ~2–4 MB install.

---

## Security

- **No DB credentials in the client.** The offline snapshot is served over the
  authenticated backend; Flutter stores read-only data. Do not revive
  `database_service.dart` or the `mysql_client` dependency for search.
- **No raw MySQL access from the device.** The `/v1/offline/snapshot` endpoint is
  the only data channel; it runs server-side against MySQL.
- **No API secrets bundled.** No Gemini/OpenAI keys reach the client; offline
  parsing and resolution are model-free.
- **Client-appropriate data only.** The snapshot contains public rally/driver/
  stage/result/video-metadata already surfaced by search. Exclude anything not
  appropriate for on-device storage (raw account emails beyond the display-name
  fallback already used by `top_uploaders`, internal IDs with no display purpose,
  PII). Review the uploader fields (`email` fallback) before including them.
- The local SQLite file holds only this snapshot; treat it as cache, not a
  security boundary.

---

## Offline Parity Benchmark

The offline parser/executor must be measured against the online pipeline on a
fixed corpus **before** it ships. The benchmark tests **language coverage**, not
just execution — because dimension B (query understanding) is where offline is
intentionally narrower.

**Corpus construction — for every one of the 9 intents, include:**

- canonical wording (e.g. "rallies in ireland in 2025"),
- natural conversational wording (e.g. "what rallies happened in ireland last year"),
- typo variants (e.g. "rally aluqsne", "max freemn"),
- multiple-filter queries (country + year + driver),
- entity-ambiguity cases (e.g. "donegl" → clarify),
- unsupported linguistic constructions (phrasings the parser is expected to *decline*).

**Metrics — measured separately:**

- Intent accuracy
- Field F1 (per `SearchQuery` field)
- Entity-resolution accuracy
- Execution-result parity (offline `SearchResponse` vs online for the same query)
- Clarification correctness
- Safe-unsupported rate (declined safely)
- Wrong-confident rate

**Primary gate — `wrong-confident = 0`.** The offline parser must never produce a
confident wrong interpretation; declining safely is always acceptable. This
mirrors the online invariant (`false confident: 0`).

**`OFFLINE_COVERAGE_RATE`** — the percentage of benchmark queries the deterministic
parser can **safely interpret and execute offline**. A query the parser *safely
declines* (routes to `OFFLINE_QUERY_UNSUPPORTED`) is **not** counted as wrong and
does **not** reduce the wrong-confident score — it simply falls outside coverage.
Coverage and correctness are reported as distinct numbers: a low coverage rate
with zero wrong-confident is an acceptable, honest offline mode; a high coverage
rate with any wrong-confident is a failure.

Where possible, reuse the existing benchmark harness and fixtures
(`backend/benchmarks/`, `parity/fixtures/`, `test/parity/`) so offline results are
compared against the same cases the online pipeline is validated on.

## Failure Modes

Every user-visible row maps to a state in the **User-Facing Messaging Matrix**
(rally headline + plain explanation + action) — no generic system copy.

| Failure | Handling | Messaging state |
|---|---|---|
| No backend + no local data | Offer to sync when online; preserve query. | `NO_LOCAL_SNAPSHOT` |
| No backend + local data present | Offline result, labelled + last-updated age. | `BACKEND_UNREACHABLE_LOCAL_AVAILABLE` |
| Intermittent drop mid-online-search | Fallback budget expires → local result for the same query; context preserved. | `LOW_BANDWIDTH_LOCAL_FALLBACK` |
| Online returns while offline session active | Do not discard user input/query; promote online only via explicit affordance, never a silent swap. | (promotion affordance) |
| Interrupted sync | Staging + atomic swap; live DB untouched until verified. | `SYNC_FAILED` (old data kept) |
| Schema drift after app upgrade | `schema_version` mismatch → full re-bootstrap; old DB readable until commit. | `SYNC_IN_PROGRESS` |
| Deleted upstream record | Tombstone list on incremental sync; never inferred from absence. | — |
| Entity unresolvable offline | Clarify if genuine ambiguity, else safe no-match + offline-scope hint. Never fabricate an ID. | `OFFLINE_AMBIGUITY` / `OFFLINE_SAFE_NO_MATCH` |
| Query needs network, unsupported offline | Preserve query; retry when online. | `BACKEND_UNREACHABLE_LOCAL_UNSUPPORTED` / `OFFLINE_QUERY_UNSUPPORTED` |
| Video found but unplayable offline | Metadata card shown; playback gated; never imply offline playback. | `VIDEO_PLAYBACK_UNAVAILABLE` |
| Cloud voice offline | On-device voice offered as fallback. | `CLOUD_VOICE_OFFLINE` |
| Stale data | Usable + visibly dated; refresh opportunistically. | `OFFLINE_STALE_RESULTS` |

---

## Implementation Plan

*(Design only — not started.)*

- **Phase O1 — Foundation:** add `sqflite` + `path_provider` + `connectivity_plus`;
  define the local schema; build the `/v1/offline/snapshot` endpoint (full
  bootstrap first) with pre-computed `final_results`, `driver_wins`,
  `uploader_stats`; store + atomic-swap on device.
- **Phase O2 — Understanding + resolution:** port `normalization.py` and the
  deterministic entity-scoring maths to Dart; build the local entity index from
  SQLite; implement the deterministic offline parser emitting `SearchQuery`.
- **Phase O3 — Execution + benchmark:** implement the 9 fixed parameterised SQLite
  strategies + local `SearchPlan`/executor returning the shared `SearchResponse`
  shapes; wire `NETWORK_FIRST_WITH_LOCAL_FALLBACK` with the bounded pending-request
  UX; stand up the **Offline Parity Benchmark** and hold the **wrong-confident = 0**
  gate.
- **Phase O4 — Voice + specials:** route `speech_to_text` on-device transcripts to
  the offline parser; port the full special-query taxonomy (all 9 personality
  categories, verbatim copy) to the shared entry point.
- **Phase O5 — Sync hardening + product-tone UX:** incremental sync (`since`,
  tombstones, versioning); implement the **User-Facing Messaging Matrix** (rally
  headline + plain explanation + action) for every connectivity/offline state;
  stale-data states; optional video-metadata segment and optional thumbnail LRU
  cache.

Each phase is independently shippable; O1–O3 already deliver 7 fully-offline
intents.

---

## Risks

| Risk | Level | Mitigation |
|---|---|---|
| Offline/online semantic divergence | Medium | Share one `SearchQuery`/`SearchResponse` contract; parity test offline results against online for a fixed query corpus; document supported-offline fields explicitly. |
| Offline parser recall lower than the LLM | Medium | Accept narrower coverage; clarify or show offline-scope hint rather than guess; keep online authoritative when reachable. |
| Source tables lacking `updated_at` for incremental sync | Medium | Per-table full-refresh fallback; add change tracking server-side later. |
| Video metadata size on low-end devices | Low–Med | Make video segment optional/separate; core snapshot ~2–4 MB. |
| Snapshot exposing PII (uploader email fallback) | Low | Field-level review before inclusion; prefer display-name-only. |
| Scope creep toward re-porting the whole AI stack | Medium | Hard rule: no LLM, no dynamic SQL, 9 fixed strategies, deterministic scoring only. |

---

## Recommendation

Build offline search as a **local-fallback mirror of the authoritative pipeline**,
not a second AI stack:

1. **SQLite (`sqflite`) compact snapshot**, populated by a new server-side
   `/v1/offline/snapshot` endpoint — no MySQL access and no secrets on the device.
2. **Deterministic, model-free offline query understanding + entity resolution**
   emitting the existing `SearchQuery` IR and reusing the online safety ordering
   (clarify, never wrong-confident).
3. **9 fixed parameterised SQLite strategies** returning the existing
   `SearchResponse` shapes, with wins/classification/uploader concerns
   **pre-computed server-side**.
4. **`NETWORK_FIRST_WITH_LOCAL_FALLBACK`** — online authoritative when reachable,
   deterministic local result (clearly labelled) otherwise; no silent result
   swaps.
5. **On-device voice** feeds the same offline parser; **cloud voice stays online.**
6. **Video: metadata offline, playback online** — never conflate the two.
7. **Product tone is a requirement, not decoration.** Every connectivity/offline
   state uses the cheesy rally personality via the **User-Facing Messaging Matrix**
   (playful headline → plain explanation → obvious action), and the **full**
   special-query taxonomy (all 9 categories incl. the WEATHER easter egg) is ported
   verbatim from the existing sources — no reinvented copy.
8. **Capability is stated on two axes** — data/execution (7/9 fully executable, 2/9
   video discovery-only) vs query-understanding (deterministically narrower than
   Gemini) — and gated by the **Offline Parity Benchmark** with **wrong-confident =
   0** and a reported `OFFLINE_COVERAGE_RATE`.

This satisfies the offline / intermittent / low-bandwidth requirement for normal
search, keeps the cheesy product voice in every offline state, preserves the
online architecture unchanged, ships nothing sensitive to the device, and never
restores the legacy Dart AI/MySQL pipeline. The technical architecture is
unchanged from the accepted design — these are tone, completeness, and
claim-precision corrections only.

---

## Implementation Status (2026-08-30)

### What shipped

**Backend (additive, online pipeline untouched):**
- `GET /v1/offline/snapshot?segment=core|full` — `backend/app/api/v1/offline.py`.
- `backend/app/services/offline_snapshot.py` — pure, unit-tested snapshot
  builders + precompute SQL. Precomputes `final_results`, `driver_wins`,
  `uploader_stats` server-side (device never runs the `FINAL_STAGE` subquery).
- Canonical person identity reproduced exactly
  (`person:account|driver|codriver:*`); participation from
  `entry_list → sub_event → event`; uploader **email fallback dropped** (display
  name only — no PII on device).
- Tests: `backend/tests/unit/test_offline_snapshot.py` (10) and
  `backend/tests/integration/test_offline_snapshot_live.py` (6, live-DB gated).

**Flutter offline engine (`lib/services/offline/`), all deterministic & model-free:**
- `offline_text_scoring.dart` — fresh port of the online dice-bigram / Jaro-Winkler
  / soundex / composite scorer (no import of the forbidden `lib/services/llm/*`).
- `offline_entity_index.dart` — local resolver preserving the online safety
  ordering exactly (`minConfidence=0.75`, `minGap=0.15`, plausible `0.50`,
  multi-year / partial-name / duplicate-identity ambiguity).
- `offline_query_parser.dart` — conservative deterministic parser emitting the
  shared `SearchQuery` IR; declines safely (`SAFE_UNSUPPORTED`/no-match) rather
  than guessing.
- `offline_database.dart` — `sqflite` schema + **staging import with atomic,
  transactional promotion** (a failed import always preserves the previous DB).
- `offline_search_executor.dart` — 9 fixed parameterised SQLite strategies
  returning the shared result models.
- `offline_search_engine.dart`, `offline_search_router.dart`
  (`NETWORK_FIRST_WITH_LOCAL_FALLBACK`, 4 s bandwidth-aware budget, no silent
  swap), `offline_snapshot_sync.dart`, `offline_messaging.dart` (17-state
  matrix), `offline_bootstrap.dart` (device wiring), plus
  `lib/widgets/offline_banner.dart` and video-playback gating in
  `lib/widgets/rally_video_player.dart` / `video_result_card.dart`.
- Screen integration: `lib/screens/general_search_screen.dart` (offline params
  are optional → tests unaffected; production wired in `lib/main.dart`).

### Actual snapshot schema

Implemented verbatim from the **Local Data Model** above, with these
implementation-driven additions for execution parity: `participation`,
`final_results`, `video_meta`, `video_actions` carry explicit `driver_id` /
`codriver_id` columns (so the executor filters by resolved ids exactly like
online and returns `person_id = COALESCE(driver_id, codriver_id)`);
`final_results` carries the row `id`; `name_norm` is filled on import.

### Real measured sizes (live DB, 2026-08-30)

| Segment | Rows | Snapshot JSON |
|---|---|---|
| **core** (mandatory bootstrap, no video) | 111 rallies, 8 750 people, 1 025 stages, 9 967 participation, 326 final_results, 5 driver_wins, 259 uploader_stats | **~5.1 MB** |
| **full** (adds 18 510 video_meta + 32 497 video_actions) | + video metadata | **~37 MB** |

`core` is the default install; `full`/video metadata is the opt-in segment. (The
37 MB is above the audit's optimistic estimate because on-demand stream + thumbnail
URLs dominate — URLs only, never media bytes.)

### Offline benchmark (deterministic corpus, `test/offline/offline_benchmark_test.dart`)

| Metric | Value |
|---|---|
| **Wrong-confident (primary gate)** | **0** |
| Intent accuracy | 100% |
| Field F1 | 1.00 |
| Entity-resolution accuracy | 100% |
| Clarification accuracy | 100% |
| Safe-unsupported rate | 100% |
| Special-query accuracy | 100% (all 9 categories) |
| Execution parity vs online oracle | 16/16 exact (all 9 intents) |
| `OFFLINE_COVERAGE_RATE` | 88.9% (answerable queries producing direct results; the remainder are safe clarifications) |

Artifacts: `backend/benchmarks/results/offline_search_<ts>/`.

### Known limitations (honest scope)
- **Cloud voice offline: NO** (network required). **On-device voice offline:
  DEVICE_DEPENDENT** — only where the OS on-device recognizer supports it; the
  transcript is editable and never auto-submitted.
- **Video playback offline: NO** (discovery from local metadata only; playback
  gated with the "stream's off-stage" state).
- The precomputed `driver_wins` / `uploader_stats` aggregates are **global**; a
  country/year-filtered leaderboard is safely declined offline rather than
  answered with a wrong-scope global result.
- Cross-script (Arabic/Urdu) transliteration is out of scope offline.
- The in-memory entity index is rebuilt at app launch (and after the bootstrap
  sync); a mid-session sync refreshes the executor's data immediately but the
  resolution index refreshes on next launch.
