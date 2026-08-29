# Project Summary

## What was built

AI Rally Search is a Flutter + FastAPI + MySQL application for natural-language and voice-driven rally search.

The final architecture is:

```text
User language
→ structured SearchQuery
→ deterministic resolution
→ deterministic SearchPlan
→ deterministic repository
→ MySQL
```

## Final model choices

### Query Understanding

Selected: `gemini-3.5-flash-lite`

Final 392-case benchmark:

- Field F1: 89.3%
- Exact SearchQuery match: 64.3%
- System success: 76.0%
- False confident: 0%
- p50: ~852 ms
- p95: ~1,083 ms
- cost: ~$0.314 / 1,000 searches

After deterministic hardening replay:

- system success: 80.36%
- `P(success | exact query)`: 84.92%
- false confident: 0

### Speech-to-Text

Selected provisionally: `whisper-1`

Synthetic benchmark:

- WER: 36.4%
- Entity preservation: 40.9%
- E2E search success: 57.4%

Human validation was insufficient for a permanent STT winner.

## Main components

- Query Understanding → natural language to SearchQuery
- IntentResolutionRouter → deterministic route classification
- OpenEntity → canonical entity resolution
- SearchPlanBuilder → exact executable meaning
- SearchRepository → relational execution
- Conversation state → canonical referent inheritance
- Voice endpoint → transcription only; no auto-submit

## Major bugs fixed

1. **Startup blocking** — OpenEntity warmup moved to background with `/health` and `/ready` separation.
2. **Noisy entity recovery** — misspellings such as `aluqsne`, `aluksnay`, and `max freemn` resolve safely.
3. **SearchPlan layer** — execution separated from model output.
4. **Residual token routing** — filler words no longer trigger false entity lookups.
5. **VIDEO_ACTIONS PERSON-vs-RALLY** — `max freeman` now routes to PERSON rather than rally clarification.
6. **Clarification preservation** — clicking a candidate preserves the pending intent, filters, referents, and generation.
7. **Ungrounded temporal hallucinations** — invented years are neutralized deterministically.
8. **Exact canonical rally resolution** — exact year-qualified canonical names beat fuzzy ambiguity logic.
9. **Multi-driver fallback IDs** — each driver candidate now receives its own fallback ID.
10. **Conversation referents** — “Show videos from that rally” preserves the active rally’s canonical event ID.

## Production validation

Before the last targeted fixes:

- 52/56 acceptable text validations = 92.86%
- false confident: 0/56
- HTTP p50 ~1.52s
- HTTP p95 ~2.04s
- historical regressions 5/5
- downstream regressions 5/5

Further targeted regression fixes were applied afterward.

## Core lesson

The project’s key outcome is the architectural boundary:

```text
LLM interprets
Router/OpenEntity canonicalize
SearchPlan executes
Repository/DB decide truth
```

That boundary made the system safer, easier to benchmark, and easier to debug.
