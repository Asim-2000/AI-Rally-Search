# AI Rally Search

AI Rally Search is a search-first Flutter + FastAPI application for rally events, drivers, stages, videos, actions, results, and rankings using natural language or voice.

The core rule is simple: **LLMs interpret language; deterministic backend code owns identity, execution, and relational truth.**

## Final stack

### Text

```text
User text
→ Gemini `gemini-3.5-flash-lite`
→ SearchQuery
→ Conversation Semantics
→ IntentResolutionRouter
→ OpenEntity / Direct Filters
→ SearchPlanBuilder
→ SearchPlan
→ SearchRepository
→ MySQL
```

### Voice

```text
Microphone
→ OpenAI `whisper-1`
→ editable transcript
→ same text pipeline
```

`whisper-1` is the current **provisional** STT choice pending a larger human-audio validation set.

## Supported intents

1. `SEARCH_RALLIES`
2. `SEARCH_DRIVER_RALLIES`
3. `SEARCH_DRIVER_WINS`
4. `GET_RALLY_RESULTS`
5. `GET_RALLY_TOP_FINISHERS`
6. `SEARCH_VIDEO_ACTIONS`
7. `SEARCH_DRIVER_VIDEOS`
8. `GET_TOP_UPLOADERS`
9. `GET_TOP_DRIVERS_BY_WINS`

A query such as “drivers that participated in Rally X” is an inverse participation capability and is **not represented by the current 9-intent model**.

## SearchQuery

Important fields include `countries`, `cities`, `years`, `yearFrom`, `yearTo`, `rallyNames`, `eventNames`, `stageNames`, `stageNumbers`, `driverNames`, `driverIds`, `actionTypes`, `uploaders`, `personRole`, and `driverMatchMode`.

Semantics are **OR within one dimension** and **AND across dimensions**.

## Deterministic guarantees

- LLMs do not generate SQL.
- LLMs do not invent canonical entity IDs.
- `IntentResolutionRouter` is deterministic.
- `OpenEntity` canonicalizes noisy entity mentions.
- `SearchPlan` is the executable contract.
- `SearchRepository` owns relational execution.
- MySQL remains the source of relational truth.
- Safety prefers clarification over a wrong confident result.

Safety ordering:

```text
correct confident resolution
> clarification
> safe no-match
> wrong confident resolution
```

## OpenEntity

Entity types:

```text
RALLY
PERSON
STAGE
UPLOADER
```

Drivers are `PERSON` entities constrained by `PersonRole`.

Known examples:

```text
aluqsne   → Rally Alūksne 2026
aluksnay  → Rally Alūksne 2026
donegl    → clarification across multiple Donegal rallies
max freemn → Max Freeman
```

No per-entity alias dictionary is used.

## Conversation

Conversation state is conceptually split between `SearchConversationSession` and `ResultReferentContext`.

Supported semantics:

```text
INHERIT
ADD
REPLACE
REMOVE
CLEAR
```

Resolved canonical referents are preserved across turns. Example:

```text
Show Rally Aluksne
→ Show videos from that rally
```

The second turn reuses the canonical event identity.

Clarification selections preserve the **pending query**, replace only the ambiguous dimension, use the selected canonical ID directly, preserve referents/generation, and do not trigger another LLM call.

## Voice

Cloud voice flow:

```text
Flutter recorder
→ AAC-LC `.m4a`
→ POST /v1/voice/transcribe
→ whisper-1
→ editable transcript
```

Capture settings: 44.1 kHz, mono, 128 kbps. Search is submitted separately through `/v1/conversation/search`; voice never auto-submits.

## Database truth

Event hierarchy:

```text
rally_events
→ rally_stages
→ rally_videos
→ rally_streams
```

Video actions:

```text
rally_video_metadata
→ rally_video_actions
```

Driver-video/action association:

```text
rally_video_metadata.entry_list_id
→ rally_entry_list
```

Participation truth:

```text
rally_entry_list
→ rally_sub_events
→ rally_events
```

Deduplicate by `event_id`. `rally_results` is classification/wins truth, not generic participation truth.

## Person identity

If `account_id` exists:

```text
person:account:<account_id>
```

Fallbacks:

```text
person:driver:<driver_id>
person:codriver:<codriver_id>
```

Null-account people are never merged solely because names match.

## SearchPlan

`SearchQuery` is never executed directly.

```text
SearchQuery
→ resolution
→ SearchPlanBuilder
→ SearchPlan
→ SearchRepository
```

This keeps execution deterministic and inspectable.

## Benchmark results

### Query Understanding

Final 392-case comparison:

| Metric | gpt-5.6-luna | gemini-3.5-flash-lite |
|---|---:|---:|
| Field F1 | 92.1% | 89.3% |
| Exact query match | 66.1% | 64.3% |
| System success | 74.7% | **76.0%** |
| False confident | 0% | 0% |
| Provider p50 | 2,975 ms | **852 ms** |
| Provider p95 | 4,424 ms | **1,083 ms** |
| Cost / 1k | $1.0864 | **$0.3140** |

Selected QU model: `gemini-3.5-flash-lite`.

After deterministic hardening replay:

- system success: **80.36%**
- `P(success | exact query)`: **84.92%**
- false confident: **0**

### STT

Synthetic benchmark:

| Model | WER | Entity preservation | E2E success |
|---|---:|---:|---:|
| whisper-1 | **36.4%** | 40.9% | **57.4%** |
| gpt-4o-mini-transcribe | 36.7% | **43.5%** | 55.7% |
| gpt-transcribe | 45.3% | 39.1% | 49.6% |

Current provisional STT: `whisper-1`.

## Important fixes

- Background OpenEntity warmup with `/health` vs `/ready` separation.
- First-class SearchPlan execution layer.
- Residual-token routing hardening.
- Ungrounded temporal-field guard for model-invented years.
- Canonical referent preservation across conversation turns.
- `SEARCH_VIDEO_ACTIONS` PERSON-vs-RALLY routing fix.
- Clarification chip context preservation.
- Exact canonical rally-name precedence before fuzzy ambiguity.
- Multi-driver fallback-ID resolution fix.

## Deployment

Backend target: **Railway**  
Database: **AWS RDS MySQL**

Expected model configuration:

```text
QUERY_UNDERSTANDING_PROVIDER=gemini
QUERY_UNDERSTANDING_MODEL=gemini-3.5-flash-lite
GEMINI_API_KEY=<secret>

SPEECH_PROVIDER=openai
SPEECH_MODEL=whisper-1
OPENAI_API_KEY=<secret>
```

`ENTITY_SEARCH_FALLBACK_MODE` must use an approved explicit value and invalid values should fail fast.

## Deferred items

- Larger human Whisper validation.
- Certificate-verified AWS RDS CA TLS.
- Inverse rally→participants capability.
- Some genuine ambiguity cases intentionally remain clarification-first.

## Other Details

- [ARCHITECURE](ARCHITECTURE.md)
- [BENCHMARKS](BENCHMARKS.md)
- [SUMMARY](SUMMARY.md)
- [CONTEXT](CONTEXT.md)
