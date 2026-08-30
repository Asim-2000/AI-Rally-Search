# AI Rally Search

AI Rally Search is a search-first Flutter + FastAPI application for rally events, drivers, stages, videos, actions, results, and rankings using natural language or voice.

The core rule is simple: **LLMs interpret language; deterministic backend code owns identity, execution, and relational truth.**

The Flutter app's AI-search path runs against the **Python FastAPI backend exclusively**. There is no legacy in-app search engine at runtime and no `SEARCH_BACKEND` switch; if the backend is unreachable the app shows a clean error rather than falling back to any in-app engine.

## Final stack

### Text

```text
User text
→ Gemini `gemini-3.5-flash-lite`
→ SearchQuery
→ Conversation Semantics + deterministic direct-filter / intent recovery
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

Resolved canonical referents are preserved across turns, and are backed by deterministic protections so conversation correctness does not depend solely on the model re-emitting context:

- **Canonical identities persist**: a confidently-resolved rally/driver keeps its canonical ID (`activeRallyId` / `activeDriverId`) across follow-ups, so `Show Max Freeman's rallies → show his videos` reuses the same canonical driver rather than re-resolving by fuzzy match.
- **Referent before clarification**: a missing required subject falls back to a type-compatible active referent before asking (`Show Rally Aluksne → who won it?` reuses the active rally; a driver referent is never used as a rally).
- **Grounded direct-filter recovery**: explicit countries/years present in the raw text but dropped by the model are restored deterministically (e.g. `crashes in ireland in 2025`). Only literal raw-text values are restored — nothing is invented.
- **Safe follow-up intent recovery**: a strong video/action follow-up about the active rally (`show videos from that rally`) is corrected to a video intent even if the model returns `SEARCH_RALLIES`; broad rally searches like `Rallies in Ireland` are left untouched.
- **Ambiguity beats cross-type recovery**: an ambiguous rally clarifies rather than being silently substituted with a person.

Example:

```text
Show Rally Aluksne
→ Show videos from that rally
```

The second turn reuses the canonical event identity and executes a video-action search.

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

After deterministic hardening replay (historical baseline):

- system success: **80.36%** (315/392)
- `P(success | exact query)`: **84.92%**
- false confident: **0**

After the ACC-1/2/3/4/6 accuracy hardening, the **same frozen Gemini outputs** were replayed through the newer downstream pipeline (no new paid QU run; the model did not change). Downstream-only frozen replay progression (same evaluator/gold; not interchangeable with the raw-model or historical-harness numbers above):

- pre-ACC controlled re-measurement: **80.10%** (314/392) — the A/B reference for the ACC deltas (vs the 315/392 historical-harness baseline above)
- initial post-ACC replay: **79.08%** (310/392) — the strict ambiguity-before-cross-type-recovery rule
- **refined ACC-6 (current): 79.59% (312/392)** — recovery now gates on rally-match *strength*
- false confident: **0** throughout
- conversation flows: **8/8**, adversarial: **21/22** (0 wrong-confident), live sanity check: **26 calls, 0 wrong-confident**

The refined replay recovers the two `act_*` cases (confident PERSON misfiled into `rallyNames`) while keeping the two `nsy_*` "Mayo …" cases as safe RALLY clarifications. The pre-ACC `314/392` is **not** the target: two of those prior "successes" were wrong-entity executions ("Mayo …" → driver "Simon May") the lenient evaluator scored as passing. The conversation-facing fixes (ACC-1/3/4) barely register on the single-turn frozen set; they are validated by the conversation/live runs. See `backend/benchmarks/results/post_accuracy_hardening_20260829_212927/` and `backend/benchmarks/results/acc6_refinement_20260830_024000/`.

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
- Python-only AI-search cutover (legacy runtime backend switch removed).
- Query-understanding config hardening (no silent mock, fail-fast on missing key, pinned model).
- Deterministic downstream accuracy protections: follow-up video-intent recovery (ACC-1), grounded direct-filter recovery (ACC-2), canonical driver-referent preservation (ACC-3), referent-before-clarification (ACC-4), strength-gated ambiguity-before-cross-type-recovery (ACC-6, refined).

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

Query-understanding configuration is hardened:

- The **mock** parser cannot activate silently in production — `provider=mock` is rejected unless `ALLOW_MOCK_QUERY_UNDERSTANDING=true` (tests only).
- A real provider with a missing key **fails fast** with a clear error (e.g. `provider=gemini` without `GEMINI_API_KEY`).
- Only the explicit `QUERY_UNDERSTANDING_*` variables select provider/model. There is **no** implicit fallback to a stale provider or to an unbenchmarked model; when unset, Gemini pins to `gemini-3.5-flash-lite`.

## Deferred items

- Larger human Whisper validation.
- Certificate-verified AWS RDS CA TLS.
- Inverse rally→participants capability.
- Some genuine ambiguity cases intentionally remain clarification-first.

## Other Details

- [ARCHITECURE](ARCHITECTURE.md)
- [BENCHMARKS](BENCHMARKS.md)
- [LEARNINGS](LEARNINGS.md)
- [SUMMARY](SUMMARY.md)
- [CONTEXT](CONTEXT.md)
