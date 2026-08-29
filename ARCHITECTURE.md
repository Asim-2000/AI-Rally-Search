# Architecture

## Design principle

> **The LLM interprets language; deterministic software executes truth.**

AI Rally Search separates language understanding, conversation semantics, entity resolution, execution planning, and relational execution.

## Production topology

The Flutter app is a client only. It owns UI, text input, voice recording, session state for the API contract, rendering, clarification selection, and networking. It does **not** own production LLM, search, entity-resolution, planning, or SQL execution — those are authoritative in the Python FastAPI backend. There is no legacy in-app search engine at runtime and no `SEARCH_BACKEND` switch; a missing/unreachable backend yields a clean error, never an in-app fallback.

```text
Flutter (client)
  ↓ HTTPS
Python FastAPI (authoritative for AI search)
```

## End-to-end flow

```text
User text
  ↓
Query Understanding (`gemini-3.5-flash-lite`)
  ↓
SearchQuery
  ↓
Deterministic recovery + Conversation Semantics
  ↓
IntentResolutionRouter
  ↓
┌───────────────┬───────────────┐
│ OpenEntity    │ Direct Filter │
└───────┬───────┴───────┬───────┘
        ↓               ↓
        Canonical Meaning
               ↓
        SearchPlanBuilder
               ↓
           SearchPlan
               ↓
        SearchRepository
               ↓
             MySQL
```

Voice adds only one stage in front:

```text
Audio → whisper-1 → editable transcript → text pipeline
```

## Query Understanding

Responsibility: convert raw language into `SearchQuery`.

Allowed:
- infer intent
- extract explicit filters
- infer person role / match semantics

Not allowed:
- SQL
- canonical DB IDs
- fuzzy entity selection
- SearchPlan execution

## SearchQuery

Semantic intermediate representation with fields such as:

```text
intent
countries
cities
years
yearFrom
yearTo
rallyNames
eventNames
stageNames
stageNumbers
driverNames
driverIds
actionTypes
uploaders
personRole
driverMatchMode
```

OR within a dimension, AND across dimensions.

## Canonical intents

Exactly 9:

```text
SEARCH_RALLIES
SEARCH_DRIVER_RALLIES
SEARCH_DRIVER_WINS
GET_RALLY_RESULTS
GET_RALLY_TOP_FINISHERS
SEARCH_VIDEO_ACTIONS
SEARCH_DRIVER_VIDEOS
GET_TOP_UPLOADERS
GET_TOP_DRIVERS_BY_WINS
```

## IntentResolutionRouter

Input:

```text
raw_text + conversation-effective SearchQuery
```

Output routes:

```text
DIRECT_FILTER
ENTITY
SEMANTIC
NONE
```

`SEMANTIC` is reserved.

Direct filters include country, city, years/ranges, stage numbers, and action types. Entity fields include rally→RALLY, driver→PERSON, stage→STAGE, uploader→UPLOADER where supported.

The router is pure, deterministic, in-memory, and does not call the DB or an LLM.

## OpenEntity

Entity taxonomy:

```text
RALLY
PERSON
STAGE
UPLOADER
```

Drivers are PERSON + PersonRole, not a separate entity type.

Safety order:

```text
correct confident > clarification > safe no-match > wrong confident
```

Cross-type recovery is constrained by intent capability. For example, `SEARCH_VIDEO_ACTIONS` can contain RALLY, PERSON, STAGE, or UPLOADER filters, so residual text must not blindly default to RALLY.

## SearchPlan

SearchPlan is the deterministic executable contract.

```text
SearchQuery
→ entity/direct-filter resolution
→ SearchPlanBuilder
→ SearchPlan
→ SearchRepository
```

It carries canonical IDs, filters, execution strategy, and pagination. Repository code does not need to understand natural language.

## Database truth

### Event hierarchy

```text
rally_events
→ rally_stages
→ rally_videos
→ rally_streams
```

### Video actions

```text
rally_video_metadata
→ rally_video_actions
```

Driver-specific action/video association uses:

```text
rally_video_metadata.entry_list_id
→ rally_entry_list
```

### Participation

```text
rally_entry_list
→ rally_sub_events
→ rally_events
```

Deduplicate by event ID. `rally_results` is reserved for classification/wins truth.

## Person identity

Account-first identity:

```text
person:account:<account_id>
```

Fallback:

```text
person:driver:<driver_id>
person:codriver:<codriver_id>
```

Never merge null-account people solely by name.

## Conversation architecture

Conceptual state:

```text
SearchConversationSession
ResultReferentContext
```

Semantics:

```text
INHERIT
ADD
REPLACE
REMOVE
CLEAR
```

Canonical IDs survive follow-up turns. Example:

```text
Show Rally Aluksne
→ Show videos from that rally
```

The LLM handles the new operation; the conversation layer supplies the prior canonical event identity.

Clarification candidate selection is deterministic: preserve the pending query and replace only the ambiguous entity dimension.

## Ungrounded temporal guard

`gemini-3.5-flash-lite` occasionally invented season years. Model-produced `years`, `yearFrom`, or `yearTo` must be grounded in the current raw text or valid conversation context before they can constrain execution.

## Deterministic recovery and conversation protections

Conversation correctness must not depend solely on the model re-emitting prior context. The pipeline applies deterministic, raw-text- and canonical-context-grounded protections between parsing and routing. Each is a general architectural principle, not a one-off:

- **Grounded direct-filter recovery** — explicit direct filters (known country names, 4-digit years) present in the raw text but omitted by the model are restored. Only literal raw-text values are restored; nothing is inferred, correct model values are never overwritten, and a token inside a resolved entity phrase is not treated as a filter.
- **Follow-up intent correction** — a strong grounded follow-up semantic (a video/action cue about the active rally) may override an incompatible model intent, conservatively: it only fires when the turn is clearly scoped to a rally (explicit or active referent), so broad discovery searches are untouched.
- **Canonical identity persistence** — a confidently-resolved rally/driver keeps its canonical ID (`activeRallyId`/`activeDriverId`) across follow-ups; follow-ups reuse the ID directly instead of re-resolving by fuzzy match. A new explicit entity replaces the prior referent (and clears a stale ID).
- **Referent before clarification** — a missing required subject consults a type-compatible active referent before clarifying (a driver referent is never used as a rally, or vice versa).
- **Ambiguity beats cross-type recovery** — valid entity ambiguity clarifies rather than being substituted across types; cross-type PERSON recovery is permitted only on a true rally no-match.

Selected clarification candidate IDs are likewise reused directly (no re-parse, no fuzzy re-resolution). Confidence thresholds are never lowered to force resolution.

## Voice

Cloud path:

```text
Flutter recorder
→ AAC-LC `.m4a`
→ POST /v1/voice/transcribe
→ whisper-1
→ editable transcript
```

44.1 kHz, mono, 128 kbps. No auto-submit. Search remains `/v1/conversation/search`.

## Startup

OpenEntity warmup is backgrounded:

```text
/health → immediate process health
/ready  → 503 while warming, 200 when ready
```

A shared singleton plus async lock/task prevents duplicate index builds.

## Benchmark architecture

Two checkpoints were measured:

```text
Raw model quality:
text → model → SearchQuery

System quality:
text → SearchQuery → Router → OpenEntity → SearchPlan → DB result
```

This separation exposed downstream bugs that initially looked like model errors.

## Final model choices

QU: `gemini-3.5-flash-lite`  
STT: `whisper-1` (provisional)

## Deferred architecture work

- larger human STT validation
- verified AWS RDS CA TLS
- inverse rally→participants intent/capability
