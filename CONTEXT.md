# Project Context

This file is a compact handoff for future work on AI Rally Search.

## Product

Flutter app + FastAPI backend + MySQL. Search-first, not chatbot-first. Users search rally data using natural language or voice.

## Current models

```text
QU:  gemini / gemini-3.5-flash-lite
STT: openai / whisper-1 (PROVISIONAL)
```

## Core pipeline

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

Voice:

```text
Audio → whisper-1 → editable transcript → same pipeline
```

## Non-negotiable invariants

- LLM never generates SQL.
- LLM never generates canonical IDs.
- Router is deterministic.
- OpenEntity resolves identity.
- SearchPlan is the executable contract.
- Repository owns relational truth.
- Conversation layer owns referent inheritance.
- Clarification is preferred to wrong confident execution.

## Supported intents

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

A rally→participants query is currently outside this model.

## SearchQuery

Key fields:

```text
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

OR within a dimension; AND across dimensions.

## Entity types

```text
RALLY
PERSON
STAGE
UPLOADER
```

Drivers are PERSON + PersonRole.

## Person identity

```text
person:account:<account_id>
person:driver:<driver_id>
person:codriver:<codriver_id>
```

Never merge null-account people only by name.

## Database truth

```text
rally_events → rally_stages → rally_videos → rally_streams
```

Actions:

```text
rally_video_metadata → rally_video_actions
```

Driver-video association:

```text
rally_video_metadata.entry_list_id → rally_entry_list
```

Participation:

```text
rally_entry_list → rally_sub_events → rally_events
```

`rally_results` is wins/classification truth only.

## Router

Input:

```text
raw text + conversation-effective SearchQuery
```

Routes:

```text
DIRECT_FILTER
ENTITY
SEMANTIC
NONE
```

Entity mapping:

```text
rallyNames  → RALLY
driverNames → PERSON
stageNames  → STAGE
uploaders   → UPLOADER where supported
```

Residual recovery must stay conservative.

## OpenEntity safety

```text
correct confident > clarification > safe no-match > wrong confident
```

Known behavior:

```text
aluqsne  → Rally Alūksne 2026
aluksnay → Rally Alūksne 2026
donegl   → clarification
max freemn → Max Freeman
```

No hardcoded per-entity aliases.

## Conversation

State concepts:

```text
SearchConversationSession
ResultReferentContext
```

Semantics:

```text
INHERIT / ADD / REPLACE / REMOVE / CLEAR
```

Canonical IDs must survive follow-ups.

### Recent referent fix

```text
Show Rally Aluksne
→ Show videos from that rally
```

The canonical event ID now survives into the video-action SearchPlan.

### Recent clarification fix

Problem:

```text
show me jump highlights from karl martin from rally ireland
```

Clarification itself worked, but chip selection used `_session.activeQuery` instead of the clarification response’s pending parsed query.

Fix:

- preserve pending query
- replace only ambiguous entity dimension
- preserve filters/referents/generation
- use selected canonical ID directly
- no LLM call on selection

Final intent remains `SEARCH_VIDEO_ACTIONS`; jump + rally filters remain intact.

### Recent VIDEO_ACTIONS routing fix

Problem:

```text
show me jump highlights featuring max freeman
```

Residual routing defaulted multi-entity `SEARCH_VIDEO_ACTIONS` text to RALLY and rally clarification happened before PERSON recovery.

Fix:

```text
max freeman → PERSON → canonical person → VIDEO_ACTIONS SearchPlan
```

## Other recent fixes

- voice E2E targets `native_voice_button`
- captured audio disposed when only editable transcript retained
- multi-driver fallback IDs added independently
- exact canonical rally names with embedded years win before fuzzy ambiguity
- ungrounded temporal filter guard neutralizes model-invented years

## Benchmark results

### Final QU

Dataset: 392 cases / 784 requests.

```text
Luna system success:       74.7%
Flash-Lite system success: 76.0%

Luna p50:       2975 ms
Flash-Lite p50: 852 ms

Luna p95:       4424 ms
Flash-Lite p95: 1083 ms

Luna cost/1k:       ~$1.086
Flash-Lite cost/1k: ~$0.314
```

Selected: `gemini-3.5-flash-lite`.

After deterministic hardening replay:

```text
Flash-Lite system success: 80.36%
P(success | exact query):   84.92%
false confident:            0
```

### STT

Current provisional choice: `whisper-1`.

Synthetic:

```text
WER: 36.4%
Entity preservation: 40.9%
E2E: 57.4%
```

Human validation remains insufficient.

## Production validation

Previous live validation before final targeted fixes:

```text
52/56 acceptable
92.86%
false confident: 0
HTTP p50: ~1522 ms
HTTP p95: ~2039 ms
historical regressions: 5/5
downstream regressions: 5/5
```

## Startup

```text
/health → immediate
/ready  → 503 while OpenEntity warms, then 200
```

Warmup uses shared singleton + async lock/task + dedicated DB connection.

## Voice details

```text
AAC-LC `.m4a`
44.1 kHz
mono
128 kbps
```

Endpoint: `POST /v1/voice/transcribe`. Search: `/v1/conversation/search`. No auto-submit.

## Deployment

Target: Railway. DB: AWS RDS MySQL.

Expected model env:

```text
QUERY_UNDERSTANDING_PROVIDER=gemini
QUERY_UNDERSTANDING_MODEL=gemini-3.5-flash-lite
GEMINI_API_KEY=<secret>

SPEECH_PROVIDER=openai
SPEECH_MODEL=whisper-1
OPENAI_API_KEY=<secret>
```

## Deferred

- larger human Whisper validation
- certificate-verified AWS RDS CA TLS
- rally→participants intent/capability
- genuine ambiguity cases that intentionally clarify

## Future debugging workflow

1. reproduce exact query
2. inspect raw SearchQuery
3. inspect Router plan
4. inspect entity resolution
5. inspect canonical resolved query
6. inspect SearchPlan
7. inspect repository result
8. patch only the failing layer
9. add deterministic regression test
10. replay cached benchmark outputs where possible

Do not assume a model failure until the full trace proves it.
