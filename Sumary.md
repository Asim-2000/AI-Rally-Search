# AI Rally Search — Architecture, Evolution, Experiments & Learnings

> **Status:** Production-oriented Flutter + FastAPI architecture, deployed backend on Railway, AWS RDS MySQL as source of truth, OpenAI-powered Query Understanding and Cloud Whisper STT, deterministic entity resolution and SQL execution.
>
> This document explains **how the system evolved**, **what experiments were conducted**, **what failed**, **what we learned**, and **why the current architecture looks the way it does**.

---

## 1. Product Goal

AI Rally Search is a **search-first rally discovery product**, not a chatbot.

Users can search rally data using natural language or voice, for example:

- `Rallies in Ireland`
- `Show rallies where Max Freeman participated`
- `Who won Rally Alūksne 2026?`
- `Show jumps from Rally Alūksne`
- `Show Max Freeman videos`
- `aluqsne`

The system converts natural language into structured search semantics, resolves noisy entity names into canonical database identities, executes deterministic queries against MySQL, and returns rally/video/result data.

The core design principle is:

> **LLMs interpret language. Deterministic systems own identity, relational truth, and execution.**

---

# 2. Current Architecture

```text
                         ┌──────────────────────┐
                         │        USER          │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │   Flutter Mobile App │
                         └──────────┬───────────┘
                                    │
            ┌───────────────────────┼────────────────────────┐
            │                       │                        │
            ▼                       ▼                        ▼
     ┌──────────────┐      ┌────────────────┐      ┌─────────────────┐
     │ Typed Search │      │  Native Voice  │      │  Cloud Whisper  │
     └──────┬───────┘      └───────┬────────┘      └────────┬────────┘
            │                      │                        │
            │               OS speech-to-text              │
            │                      │                        ▼
            │                      │              POST /v1/voice/transcribe
            │                      │                        │
            │                      │                        ▼
            │                      │                OpenAI whisper-1
            │                      │                        │
            └──────────────────────┴──────────────┬─────────┘
                                                  ▼
                                      ┌────────────────────┐
                                      │ Editable transcript│
                                      │ / search text field│
                                      └──────────┬─────────┘
                                                 │
                                      Explicit Search only
                                                 │
                                                 ▼
                                 POST /v1/conversation/search
                                                 │
                                                 ▼
                                   ┌────────────────────────┐
                                   │ Special Query Matcher  │
                                   └───────────┬────────────┘
                                               │
                                               ▼
                                   ┌────────────────────────┐
                                   │  Query Understanding   │
                                   │   text → SearchQuery   │
                                   └───────────┬────────────┘
                                               │
                                               ▼
                                   ┌────────────────────────┐
                                   │ OpenEntity / Entity    │
                                   │ Search + Resolver      │
                                   └───────────┬────────────┘
                                               │
                                               ▼
                                   ┌────────────────────────┐
                                   │ Canonical SearchQuery  │
                                   └───────────┬────────────┘
                                               │
                                               ▼
                                   ┌────────────────────────┐
                                   │ Deterministic Repo/SQL │
                                   └───────────┬────────────┘
                                               │
                                               ▼
                                     ┌───────────────────┐
                                     │ AWS RDS MySQL     │
                                     └──────────┬────────┘
                                                │
                                                ▼
                                      Structured Results
                                                │
                                                ▼
                                          Flutter UI
```

### Key architectural boundaries

| Layer | Responsibility |
|---|---|
| Flutter | User input, voice capture, editable transcript, rendering, stale-response protection |
| Native STT | Device/OS speech-to-text only |
| Cloud STT | Audio → transcript only |
| Query Understanding | Natural language → `SearchQuery` |
| OpenEntity / Entity Search | Noisy mentions → canonical entities/IDs |
| Conversation layer | Deterministic state and referent handling |
| Repository layer | Relational truth and SQL execution |
| MySQL | Authoritative product data |

The LLM **does not**:

- generate SQL;
- select canonical database IDs;
- determine participation from fuzzy text;
- own relational truth;
- silently merge human identities;
- mutate application state directly.

---

# 3. Supported Search Intents

The system currently supports nine product intents:

1. `SEARCH_RALLIES`
2. `SEARCH_DRIVER_RALLIES`
3. `SEARCH_DRIVER_WINS`
4. `GET_RALLY_RESULTS`
5. `GET_RALLY_TOP_FINISHERS`
6. `SEARCH_VIDEO_ACTIONS`
7. `SEARCH_DRIVER_VIDEOS`
8. `GET_TOP_UPLOADERS`
9. `GET_TOP_DRIVERS_BY_WINS`

The structured `SearchQuery` supports multi-value dimensions such as:

- countries;
- cities;
- years;
- year ranges;
- rally/event names;
- stage names;
- stage numbers;
- driver names;
- driver IDs;
- action types;
- uploaders;
- person role;
- match mode.

Semantic rule:

- **OR within a dimension**
- **AND across dimensions**

Example:

```text
countries = ["Ireland", "Latvia"]
years = [2025, 2026]
```

means:

```text
(country = Ireland OR Latvia)
AND
(year = 2025 OR 2026)
```

---

# 4. Database Truth & Domain Relationships

The backend deliberately keeps relational truth in SQL/database logic instead of asking the LLM to infer relationships.

## Rally / video hierarchy

```text
rally_events
    ↓
rally_stages
    ↓
rally_videos
    ↓
rally_streams
```

Video actions are timestamp segments within videos:

```text
rally_video_metadata
    ├── action_id
    ├── entry_list_id
    ├── start_action
    ├── end_action
    └── points
```

Action names come from:

```text
rally_video_actions.action_name
```

## Participation truth

Participation is determined through:

```text
rally_entry_list
    ↓
rally_sub_events
    ↓
rally_events
```

This is important because `rally_results` represents **classification/results**, not generic participation.

Therefore:

- `SEARCH_DRIVER_RALLIES` uses entry-list participation truth;
- wins/results/top-finishers use classification/results tables.

## Driver-video attribution

For video attribution the system uses:

```text
rally_video_metadata.entry_list_id
    ↓
rally_entry_list
```

rather than trying to infer a driver from uploader/video text.

---

# 5. Human Identity Model

Drivers and co-drivers can represent the same human across different database roles.

The identity rules are deterministic:

```text
account_id present
    → person:account:<account_id>

driver with null account
    → person:driver:<driver_id>

codriver with null account
    → person:codriver:<codriver_id>
```

Important safety rule:

> **Name equality never merges two null-account people.**

`PersonRole` supports:

- `DRIVER`
- `CO_DRIVER`
- `ANY`

Role semantics are enforced during entity resolution.

---

# 6. OpenEntity / Entity Search

The system uses a database-driven in-memory entity index as the canonical resolution layer.

Entity types:

- `RALLY`
- `PERSON`
- `STAGE`
- `UPLOADER`

Current indexed universe is approximately:

| Entity type | Count |
|---|---:|
| Rally | 111 |
| Person | 8,750 |
| Stage | 1,024 |
| Uploader | 1,359 |
| **Total** | **11,244** |

The PERSON index includes:

- account-backed identities;
- null-account drivers;
- null-account co-drivers.

## Entity-resolution philosophy

Preferred outcome ordering:

```text
correct confident resolution
    >
clarification
    >
no match
    >
wrong confident resolution
```

This means the system is intentionally conservative.

It does **not** maintain hand-written aliases such as:

```text
aluqsne -> Aluksne
aluksnay -> Aluksne
```

Instead it relies on:

- Unicode normalization;
- lexical similarity;
- trigram retrieval;
- phonetic signals;
- token-order matching;
- deterministic confidence/ambiguity rules.

---

# 7. Why the Entity Index Is Cached

An important production issue was discovered after deployment.

Initially, every `/v1/conversation/search` request did this:

```text
AWS RDS
    ↓
load ~11.2k entities
    ↓
rebuild trigram/in-memory search index
    ↓
run actual query
```

Measured overhead was roughly:

- ~1.0s DB entity load;
- ~0.5s index reconstruction;
- plus LLM and SQL execution.

This caused the mobile application to feel as though it was hanging between searches.

The current architecture now does:

```text
FastAPI startup
    ↓
load canonical entity universe once
    ↓
build InMemoryEntitySearchService once
    ↓
cache for process lifetime
```

Each request reuses the shared entity-search service while maintaining request-scoped database connections for repository execution.

Observed improvement in one production-style verification:

```text
Cold request:  ~5.9s
Cached request: ~3.5s
Saved:          ~2.4s
```

The remaining large latency component is generally Query Understanding / external model latency rather than entity resolution.

---

# 8. Query Understanding

Query Understanding converts natural language into a strict structured `SearchQuery`.

Current conceptual flow:

```text
raw text
    ↓
provider-neutral QueryUnderstandingService
    ↓
strict schema
    ↓
SearchQuery
```

The system has provider adapters for:

- OpenAI;
- Gemini;
- Anthropic;
- mock/testing.

The production Railway deployment currently uses an explicitly configured OpenAI model.

## Important production learning: model configuration must be explicit

A major deployment issue was discovered because local and Railway environments were using different effective Query Understanding models.

The old configuration allowed fallback precedence such as:

```text
QUERY_UNDERSTANDING_MODEL
    ↓
OPENAI_MODEL
    ↓
hardcoded default
```

This caused local and production behavior to drift silently.

After setting the intended model explicitly in Railway, simple searches such as:

```text
Rallies in Ireland
```

returned to expected behavior.

### Architectural learning

Production model configuration should eventually be:

```text
QUERY_UNDERSTANDING_PROVIDER=<explicit>
QUERY_UNDERSTANDING_MODEL=<explicit>
```

with:

- no silent production fallback;
- startup validation;
- safe startup logging of active provider/model;
- no secrets in logs.

---

# 9. Query Understanding Validation

A frozen 176-case provider validation set was used during migration.

Validation configuration:

- OpenAI provider;
- temperature `0`;
- strict JSON output;
- retries enabled;
- controlled timeout.

Observed migration-validation metrics:

| Metric | Result |
|---|---:|
| Schema validity | 100% |
| Provider failures | 0 |
| Intent accuracy | ~92.05% |
| Field F1 | ~96.21% |

This was sufficient to validate the Python integration, but it was **not treated as proof that every production search query would be perfect**.

Real mobile usage later exposed routing issues around ambiguous or typo-heavy inputs, which led to additional deterministic safeguards.

---

# 10. Canonical Typo Recovery

A useful production example was:

```text
aluqsne
```

Originally, Query Understanding sometimes produced:

```text
rally_names = []
cities = []
```

which meant Entity Search was never invoked.

However:

```text
Rally aluqsne
```

produced a rally mention, and OpenEntity correctly retrieved:

```text
Rally Alūksne 2026
```

This proved the canonical index itself was working.

## Current behavior

Routing was improved so uncertain entity-like text is preserved instead of silently discarded.

Current verified examples include:

| Input | Current behavior |
|---|---|
| `aluqsne` | resolves to Rally Alūksne 2026 |
| `Rally aluqsne` | resolves to Rally Alūksne 2026 |
| `aluksnay` | resolves to Rally Alūksne 2026 |
| `donegl` | safe clarification because multiple Donegal candidates compete |
| `max freemn` | resolves to Max Freeman |

Important learning:

> **Canonical recovery should happen in OpenEntity, but Query Understanding must preserve the noisy mention long enough for OpenEntity to see it.**

---

# 11. “Did You Mean?” Suggestions

A separate issue appeared after migration: OpenEntity candidates existed, but candidate suggestions disappeared from the UI.

The failure occurred because candidates were only propagated when:

```text
requires_clarification == true
```

On a normal zero-result turn, candidates were dropped.

The architecture now preserves relevant candidates across the response contract.

Flutter can display:

```text
Did you mean?

[ Rally Alūksne 2026 ]
```

when:

```text
total_count == 0
AND
candidate suggestions exist
```

This is intentionally separate from strict clarification.

---

# 12. Conversation Architecture

The application supports conversational follow-ups without becoming a general chatbot.

Backend remains stateless from an HTTP perspective; state is passed explicitly.

Two concepts are kept separate:

```text
SearchConversationSession
ResultReferentContext
```

The system also uses request generations on the client to protect against stale asynchronous responses.

Successful zero-result searches may still commit relevant conversation state, while provider/schema/resolver/database failures do not incorrectly mutate the session.

The conversation layer handles semantics such as:

- inheritance;
- replacement;
- addition;
- removal;
- clearing;
- referent reuse.

The LLM does not directly control state mutation.

---

# 13. Special Query Handling

Some inputs do not belong in rally search at all.

A deterministic `SpecialQueryMatcher` runs before normal Query Understanding for cases such as:

- weather;
- greetings;
- thanks;
- identity;
- capabilities;
- jokes;
- alive/status;
- rally opinion.

Important rule:

```text
"weather"
    → friendly special response

"weather at Rally Aluksne 2026"
    → legitimate rally search
```

This prevents the search system from becoming a generic chatbot while preserving rally-related queries.

---

# 14. Voice Architecture Evolution

Voice went through several experiments before arriving at the current architecture.

---

## 14.1 Initial backend STT architecture

The first Python voice architecture was:

```text
audio
    ↓
backend STT
    ↓
Query Understanding
    ↓
Entity Search
    ↓
DB search
```

The backend exposed:

```text
POST /v1/voice/search
```

This route still exists for compatibility/debugging, but it is no longer the preferred product path.

---

# 15. STT Experiments

Several STT experiments were conducted because rally names are unusually difficult for general speech recognition.

## 15.1 Raw STT bakeoff

Models tested included:

- `whisper-1`
- `gpt-4o-mini-transcribe`
- `gpt-4o-transcribe`
- `gpt-transcribe`

Representative aggregate observations across a small labeled recording set:

| Model | Approx. normalized WER |
|---|---:|
| whisper-1 | ~55.6% |
| gpt-4o-mini-transcribe | ~33.3% |
| gpt-4o-transcribe | ~29.6% |
| gpt-transcribe | ~25.9% |

Despite some newer models showing lower raw WER, the product-level canonical outcomes did not improve enough to justify immediate architecture changes.

A major difficulty was proper-noun transcription such as:

```text
Alūksne
```

### Learning

> Lowest word-error-rate does not automatically mean best product search behavior.

The downstream entity resolver can recover some transcription errors, while a seemingly better transcript can occasionally produce a worse semantic interpretation.

---

## 15.2 Database-aware STT context

A second experiment injected bounded domain vocabulary/context before transcription.

Goal:

```text
database entities
    ↓
domain context
    ↓
STT
```

The experiment did not produce sufficient quality gains and added significant latency.

Outcome:

```text
DOMAIN_CONTEXT_NO_MEANINGFUL_GAIN
```

It was not enabled.

---

## 15.3 Audio grounding / second-pass experiment

A further experiment used an additional audio-aware grounding step.

It improved some transcript-level metrics, including a difficult rally-name example, but:

- added substantial latency;
- did not improve the final correct/clarify/wrong outcome distribution enough;
- introduced additional system complexity.

Outcome:

```text
AUDIO_GROUNDING_INSUFFICIENT
```

It was not enabled.

### Learning

> Do not keep adding AI passes when deterministic entity resolution can recover noise more cheaply and safely.

---

# 16. Native vs Cloud STT

Under deadline pressure, the architecture was simplified into two directly testable input methods.

## Native Voice

```text
phone microphone
    ↓
iOS/Android native speech recognition
    ↓
editable search field
```

No backend audio upload.

## Cloud Whisper

```text
phone microphone
    ↓
Flutter audio recorder
    ↓
POST /v1/voice/transcribe
    ↓
OpenAI whisper-1
    ↓
editable search field
```

Neither path auto-submits.

The user can:

1. inspect the transcript;
2. edit it;
3. explicitly press Search.

Both paths then converge on:

```text
POST /v1/conversation/search
```

This makes Native vs Cloud STT a fair product test because **everything downstream is identical**.

---

# 17. Cloud Whisper Architecture

Current Cloud Whisper path:

```text
[Cloud Whisper Button]
          │
          ▼
[Flutter AudioRecorder]
          │
          ▼
[Finalized AAC-LC .m4a]
          │
          ▼
[POST /v1/voice/transcribe]
          │
          ▼
[OpenAISpeechToTextProvider]
          │
          ▼
[OpenAI whisper-1]
          │
          ▼
[Transcript]
          │
          ▼
[Editable Search Field]
```

## Flutter audio configuration

Current recording configuration is explicit:

- AAC-LC;
- `.m4a`;
- 44.1 kHz;
- mono;
- 128 kbps.

The file is finalized before reading/upload.

Audio bytes are uploaded as raw binary to FastAPI.

The backend then sends the preserved audio to OpenAI using the appropriate filename/MIME information.

---

# 18. Cloud STT Regression & Fix

After moving Cloud Whisper through Python/Railway, transcription quality initially became noticeably worse.

An architecture review found that the Python provider was injecting a hardcoded vocabulary prompt containing rally names, driver names, and action terms into **every** Whisper request.

Example categories included:

```text
Donegal
Josh Moffett
Kalle Rovanperä
jump
drift
crash
...
```

Although intended as domain assistance, it biased transcription toward those terms and degraded ordinary speech recognition.

## Fix

Production Cloud Whisper now sends:

```text
model = whisper-1
audio file
normalized language when available
response_format = json
NO unconditional vocabulary prompt
```

After removing prompt pollution, real-device STT quality improved substantially.

### Learning

> Domain prompting inside speech recognition can be harmful when applied globally. Keep baseline STT simple and let the entity resolver recover domain-specific names downstream.

---

# 19. STT Endpoint Isolation

Another architectural issue was that:

```text
POST /v1/voice/transcribe
```

depended on `ConversationalSearchService`.

That meant a pure transcription request could trigger:

- database connectivity;
- entity loading;
- search dependencies.

The endpoint is now transcription-only.

Current responsibility:

```text
audio
    ↓
STT provider
    ↓
transcript
```

No Query Understanding.  
No Entity Search.  
No MySQL.  
No conversation mutation.

---

# 20. Voice Request Safety

The Flutter dual-STT implementation includes:

- mutual microphone exclusion;
- monotonic generation tokens;
- stale-result protection;
- editable transcript;
- no automatic search;
- temporary audio cleanup on success/failure/cancel;
- typed search remains usable even when either STT path fails.

Native STT and Cloud STT can therefore be compared without introducing different downstream semantics.

---

# 21. Friendly Error Handling

A separate engineering pass added deterministic friendly responses for:

- no results;
- search errors;
- unsupported special requests;
- voice failures.

The architecture deliberately avoids using an LLM to generate error messages or jokes inside core search execution.

---

# 22. Backend Migration Timeline

The Python migration was executed in phases.

## PY-1 — Deterministic FastAPI/MySQL

Implemented:

- FastAPI service;
- nine intents;
- `/health`;
- `/v1/search`;
- deterministic repositories;
- raw database parity with existing implementation.

**Outcome:** accepted and frozen.

---

## PY-2 — Entity Search

Implemented:

- database-driven canonical entity index;
- RALLY/PERSON/STAGE/UPLOADER retrieval;
- identity bridge;
- resolver safety rules;
- phonetic/lexical retrieval;
- no per-entity hardcoded alias dictionaries.

Representative frozen validation:

- 1,101 PERSON cases exact parity;
- safety set with zero false-confident outcomes;
- difficult rally-name transcription set;
- large retrieval benchmark with near-perfect top-5/top-10 coverage.

**Outcome:** accepted and frozen.

---

## PY-3 — Query Understanding

Implemented:

- provider-neutral adapters;
- strict schema;
- `/v1/query-understanding`;
- frozen benchmark fixture;
- OpenAI provider validation.

**Outcome:** accepted for migration, but later production testing exposed configuration/routing issues that were fixed without changing the overall architecture.

---

## PY-4 — Conversation

Implemented:

- explicit session model;
- referent context;
- stale request protection;
- shared conversation fixtures;
- deterministic state commit rules.

**Outcome:** accepted for migration.

---

## PY-5 — Voice/STT

Implemented:

- provider-neutral STT;
- OpenAI adapter;
- `/v1/voice/search`;
- STT bakeoffs;
- contextual STT experiments;
- audio grounding experiments.

**Learning:** backend-heavy STT pipelines were becoming too complex relative to product value.

---

## Native STT / Dual STT

Architecture simplified into:

```text
Native STT
or
Cloud Whisper
    ↓
editable transcript
    ↓
same text search pipeline
```

This is the current preferred voice architecture.

---

# 23. API Surface

Current important endpoints include:

```text
GET  /health
POST /v1/search
POST /v1/query-understanding
POST /v1/conversation/search
POST /v1/voice/transcribe
POST /v1/voice/search
```

Recommended conceptual classification:

| Endpoint | Role |
|---|---|
| `/health` | production health |
| `/v1/conversation/search` | primary product search endpoint |
| `/v1/voice/transcribe` | production Cloud STT endpoint |
| `/v1/search` | structured/internal search |
| `/v1/query-understanding` | debugging/integration |
| `/v1/voice/search` | legacy/experimental compatibility |

---

# 24. Deployment Architecture

Current deployment:

```text
┌────────────────────────────┐
│ Flutter App — Physical Phone│
└─────────────┬──────────────┘
              │ HTTPS
              ▼
┌────────────────────────────┐
│ Railway FastAPI Backend    │
└──────────┬───────────┬─────┘
           │           │
           │           │
           ▼           ▼
┌────────────────┐  ┌──────────────────┐
│ OpenAI APIs    │  │ AWS RDS MySQL    │
│ - Query model  │  │ Source of truth  │
│ - whisper-1    │  │                  │
└────────────────┘  └──────────────────┘
```

The backend is deployed independently from the Flutter runtime even though the project may remain in a monorepo.

Recommended repository shape over time:

```text
ai-rally-search/
├── mobile/
└── backend/
```

A monorepo remains appropriate while mobile/backend contracts evolve together.

---

# 25. Important Production Learnings

## 25.1 Architecture bugs can look like model-quality bugs

Examples:

- wrong Railway Query Understanding model made text interpretation appear worse;
- Whisper vocabulary prompt pollution made STT appear worse;
- per-request entity-index rebuilding made the app appear to hang.

The fix was not “use a bigger model.”  
The fix was to correct system boundaries and configuration.

---

## 25.2 LLMs should preserve uncertainty, not erase it

Bad behavior:

```text
aluqsne
    ↓
LLM outputs no entity fields
    ↓
Entity Search never sees it
```

Better behavior:

```text
aluqsne
    ↓
preserve noisy mention
    ↓
OpenEntity
    ↓
Rally Alūksne
```

---

## 25.3 Fuzzy matching is discovery, not truth

The entity search system may discover likely candidates, but execution still requires safe canonical resolution.

This protects against confident wrong matches.

---

## 25.4 Suggestions and resolution are different UX concepts

An entity can be:

- confidently resolved;
- ambiguous and require clarification;
- not resolved but still have useful suggestions.

Therefore candidate propagation should not be tied exclusively to `requires_clarification`.

---

## 25.5 Cache immutable/slow canonical search structures

A DB-driven canonical index is appropriate, but rebuilding it for every request is not.

The correct lifecycle is:

```text
startup
→ load
→ index
→ reuse
```

with explicit refresh later if the product requires dynamic updates.

---

## 25.6 Voice should remain an input method

The winning conceptual model is:

```text
voice
→ text
→ normal search
```

not:

```text
voice
→ separate AI search architecture
```

This dramatically reduces complexity and makes Native vs Cloud STT easy to compare.

---

## 25.7 Production configuration must be observable

Provider/model configuration should be explicit and visible in sanitized startup logs.

Silent fallbacks can produce major behavioral changes that look like application bugs.

---

# 26. Known Technical Debt / Future Work

## Query Understanding configuration

Move toward strict production configuration:

```text
QUERY_UNDERSTANDING_PROVIDER
QUERY_UNDERSTANDING_MODEL
```

and fail startup if a live provider is incompletely configured.

---

## Persistent OpenAI HTTP client

The speech provider currently has remaining opportunities around connection pooling / persistent async HTTP clients.

This is primarily a latency/concurrency improvement, not a transcription-quality fix.

---

## Entity-index refresh strategy

The current process-level entity index is fast and appropriate.

If rally/person data changes frequently, add an explicit refresh strategy rather than rebuilding on every request.

Potential options:

- periodic refresh;
- deployment-time refresh;
- admin refresh endpoint;
- versioned index snapshot.

---

## Production observability

Useful safe telemetry:

```text
request ID
endpoint
provider
model
query-understanding latency
entity-resolution latency
DB latency
result count
clarification reason
STT audio duration
STT byte size
STT provider latency
```

Avoid storing raw voice audio or sensitive transcripts unless explicitly required.

---

## SEC-1 — RDS TLS

Database SSL configuration has been recognized as a production-hardening task.

The eventual implementation should use verified RDS TLS/CA handling.

Do not weaken TLS verification simply to simplify deployment.

---

# 27. Current Design Principles

The architecture should continue to follow these rules:

1. **Search-first, not chatbot-first.**
2. **LLM interprets language only.**
3. **Canonical IDs come from deterministic entity resolution.**
4. **Relational truth comes from MySQL/repository logic.**
5. **No LLM-generated SQL.**
6. **No hardcoded typo aliases.**
7. **Wrong-confident matches are worse than clarification.**
8. **Voice is just another way to enter text.**
9. **User can inspect/edit transcripts before execution.**
10. **All input modes converge on one authoritative search pipeline.**
11. **Cache expensive immutable search structures.**
12. **Make production model/provider configuration explicit.**
13. **Prefer simple deterministic fixes over additional AI passes.**

---

# 28. Current End-to-End Examples

## Typed typo

```text
User:
aluqsne

Query Understanding:
preserves noisy entity-like mention

OpenEntity:
Rally Alūksne 2026

Resolver:
confident canonical selection

Repository:
event_id filter

MySQL:
1 rally

Flutter:
Rally Alūksne 2026
```

---

## Ambiguous rally

```text
User:
donegl

OpenEntity:
multiple competitive Donegal candidates

Resolver:
ambiguity

Flutter:
Which rally did you mean?

[ Donegal test rally 15th ]
[ Wilton Donegal International Rally 2025/2026 ]
```

---

## Driver typo

```text
User:
max freemn

Query Understanding:
SEARCH_DRIVER_RALLIES

OpenEntity:
Max Freeman

Canonical identity:
driver/person identity

Repository:
participation relationship

MySQL:
9 participations
```

---

## Cloud voice

```text
User speaks
"Rallies in Ireland"

Flutter:
records AAC-LC .m4a

/v1/voice/transcribe:
whisper-1

Transcript:
"Rallies in Ireland"

User may edit

/v1/conversation/search:
SEARCH_RALLIES
countries=["Ireland"]

Repository/MySQL:
Irish rally results
```

---

# 29. Summary

The project evolved from a tightly coupled AI/voice search implementation into a cleaner layered architecture:

```text
INPUT
    ↓
TEXT
    ↓
STRUCTURED SEMANTICS
    ↓
CANONICAL ENTITY RESOLUTION
    ↓
DETERMINISTIC SQL
    ↓
RESULTS
```

The most valuable lesson from the migration was that many perceived “AI quality” problems were actually **architecture, configuration, lifecycle, or routing problems**.

The current system deliberately keeps the probabilistic parts narrow:

```text
speech recognition
natural-language interpretation
fuzzy candidate discovery
```

while keeping the critical execution path deterministic:

```text
identity
state
canonical resolution
relationships
SQL
results
```

That separation is what now makes the system faster, safer, easier to debug, and easier to evolve.
