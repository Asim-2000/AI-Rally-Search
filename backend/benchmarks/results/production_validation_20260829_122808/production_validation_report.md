# Production Search Validation

## Executive Summary

The real localhost HTTP path was validated with fresh `gemini-3.5-flash-lite` calls, the configured read-only MySQL database, and two existing human audio files through `whisper-1`. The 56-case text set achieved **52/56 acceptable outcomes (92.86%)** with **0 false-confident executions**. Five of five downstream-hardening regressions passed.

Production approval is nevertheless blocked by missing verified MySQL TLS, three failing deployable Flutter tests, two failed conversation video follow-ups, and provisional Whisper quality of only 1/2 semantically correct human recordings.

## Effective Production Configuration

| Setting | Effective value | Evidence |
|---|---|---|
| Query-understanding provider | `gemini` | `Settings` loaded explicit root `.env` value |
| Query-understanding model | `gemini-3.5-flash-lite` | `Settings` and real HTTP responses |
| Speech provider | `openai` | `/v1/voice/transcribe` response |
| Speech model | `whisper-1` | Both voice responses |
| Whisper status | `PROVISIONAL` | Production configuration decision |
| Entity fallback | `FALLBACK` | Effective backend settings |
| Database SSL setting | `true` | Effective backend settings |

Explicit `QUERY_UNDERSTANDING_*` variables override the stale legacy `LLM_PROVIDER=openai` and `OPENAI_MODEL=gpt-5.6-luna` values in the local `.env`. Railway should remove those stale variables after confirming the explicit values. Secrets were present but never printed.

Startup logs identify Uvicorn lifecycle state but do not log safe effective QU/STT provider and model names. This is an observability gap.

## Test Environment

- Date: 2026-08-29, Europe/Berlin
- Backend: local Uvicorn deployment-style process on `127.0.0.1:8000`
- Database: configured AWS RDS MySQL development database, read-only use
- HTTP endpoint: `/v1/conversation/search`
- Voice endpoint: `/v1/voice/transcribe`
- OpenEntity index: 11,245 entities
- Fresh paid model calls: Gemini Flash-Lite for 56 measured text cases plus error-contract/no-match checks; Whisper for two human files
- No alternative QU or STT model was compared

## Automated Test Suite

| Suite | Passed | Failed | Skipped/deselected |
|---|---:|---:|---:|
| Backend unit + parity, explicit mock QU | 176 | 0 | 0 |
| Backend integration/OpenEntity/SearchPlan/conversation | 22 | 0 | 3 |
| Deployable Flutter app suites | 299 | 3 | 4 |
| **Completed relevant total** | **497** | **3** | **7** |

The initial backend unit run had 175 passes and one configuration-coupled failure because a nominal unit test inherited the production Gemini `.env`. It passed under the explicit mock configuration used for the hermetic rerun.

The three repeatable Flutter failures are:

1. The editable native-voice UI test finds two `VoiceSearchButton` widgets after dual-STT UI introduction and expects exactly one.
2. The legacy Dart multi-entity resolver returns only the first of two expected driver IDs.
3. The legacy Dart confidently-resolved zero-video case no longer produces the expected clean success.

The unrestricted Flutter command accidentally included legacy live benchmark suites. It was stopped when the 560-audio synthetic benchmark began, after six calls. Its incomplete counts are excluded from totals; several stale fixture/export failures had already appeared.

## Startup / Readiness

- Process launch to Uvicorn application-ready: approximately **5.8 s**.
- Warm `/health`: **200**, 1.472 ms.
- Warm `/ready`: **200**, 0.691 ms.
- Readiness reported `entityIndexReady=true` and 11,245 entities.
- No evidence of duplicate index construction appeared.
- Unit coverage independently verifies `/health` remains available while `/ready` returns 503 during warmup.

The first external probe occurred before the Uvicorn socket was available and returned connection refused. Once application startup completed, both probes were correct.

## Text Search Validation

| Classification | Count |
|---|---:|
| `CORRECT_RESULT` | 27 |
| `CORRECT_CLARIFICATION` | 13 |
| `CORRECT_NO_MATCH` | 0 in the 56-case set |
| `SAFE_RECOVERY` | 12 |
| `WRONG_RESULT` | 4 |
| `ERROR` | 0 |
| `FALSE_CONFIDENT` | **0** |

Production validation success: **52/56 = 92.86%**. An additional error-contract query, `Rallies in Antarctica in 1900`, returned a clean 200 response with zero results and is classified `CORRECT_NO_MATCH` outside the measured set.

The four failed text cases were:

- `Crashes in Ireland in 2025`: Flash-Lite dropped both country and year, after which residual `ireland` was treated as a rally and clarified.
- `max freemn`: Flash-Lite selected `SEARCH_DRIVER_VIDEOS` rather than the intended general driver-rally lookup; Max Freeman still resolved canonically but the search intent was wrong.
- Both `Show videos from that rally` conversation turns: Flash-Lite emitted `SEARCH_RALLIES`, not `SEARCH_VIDEO_ACTIONS`.

## Historical Regression Cases

All **5/5** special-query cases passed: greeting, thanks, capability help, joke, and aliveness. The matcher returned special responses without database search.

`weather at Rally Aluksne 2026` was not swallowed as a generic weather response; it continued through rally search semantics and safely recovered Rally Alūksne.

## Downstream Hardening Regression Cases

All **5/5** passed:

- Global historical driver leaderboard executed without invented entity routing.
- `located in` multi-country filtering executed deterministically.
- Conflicting event identity year/search-filter year completed safely.
- Missing-subject `Show results` clarified.
- Weather-plus-rally text continued into legitimate rally semantics.

## Conversation Validation

Conversation success was **4/6**. Generation advanced monotonically and sessions were returned on each successful turn. Rally and driver names survived follow-ups, but the requested video follow-up failed in both sessions because fresh QU selected `SEARCH_RALLIES`.

The result-derived `activeDriverId` remained null after a canonical Max Freeman resolution, even though the resolved query retained the co-driver ID. Canonical referent-ID preservation is therefore incomplete.

The Max Freeman participation response also displays primary crew driver names for rows matched through the co-driver ID. The event set appears to be the intended participation set, but the item-level person display is misleading and needs repository projection review.

## Entity Resolution / Clarification

- All 6/6 dedicated ambiguity cases clarified safely.
- `donegl` and multi-edition Donegal results were not forced to an unsafe identity.
- Rally Alūksne typos recovered or clarified with the correct candidate.
- Max Freeman resolved with `ANY`/co-driver semantics without threshold changes.
- No false-confident entity execution was observed.
- Resolver thresholds were not modified during validation.

## Ungrounded Temporal Guard

The live guard activated twice, both on model-produced `years:2026` during Rally Alūksne conversation follow-ups. In each case, 2026 came from the canonical event name rather than an explicit search-filter year, so removing the standalone year filter preserved entity-identity/search-filter separation. The SearchPlans were not incorrectly constrained by that year.

## Voice Smoke

The transcription-only endpoint accepted both WAV files, returned editable transcript text, reported provider `openai` and model `whisper-1`, and did not automatically submit search. Each transcript was then manually passed to `/v1/conversation/search`.

| Audio | STT result | STT HTTP | STT latency | Search latency | Total | Semantic result |
|---|---|---:|---:|---:|---:|---|
| `record_out.wav` | Max Freeman participation transcript | 200 | 1,916 ms | 1,725 ms | 3,641 ms | Correct |
| `record_out (1).wav` | Severe unrelated massacre/police hallucination | 200 | 3,597 ms | 1,507 ms | 5,104 ms | Incorrect transcript; downstream safely clarified |

Technical endpoint smoke: **2/2**. Human-audio semantic smoke: **1/2**. Whisper remains provisional. The endpoint is DB-independent by dependency structure and unit tests; only the manual transcript search used the database. Official OpenAI documentation lists WAV and M4A among supported transcription formats and `whisper-1` as a transcription model: <https://platform.openai.com/docs/api-reference/audio/verbose-json-object>.

## Latency

| Layer | p50 | p95 | Max |
|---|---:|---:|---:|
| Integrated text HTTP | 1,522 ms | 2,039 ms | 2,886 ms |
| QU component | 1,177 ms | 1,341 ms | 1,580 ms |
| Entity resolution | 69 ms | 144 ms | 175 ms |
| Database | 80 ms | 474 ms | 1,200 ms |
| Backend internal total | 1,315 ms | 1,835 ms | 2,678 ms |

The first measured text request was 1,500 ms, close to the warm median. Provider latency dominates normal text requests; local HTTP overhead is not counted as provider latency.

## Error Contract

- Malformed non-string query: structured 422 `VALIDATION_ERROR` with no secret or stack trace.
- Empty query: structured 422 `VALIDATION_ERROR`.
- Empty voice body: 422 with a short safe message.
- Ambiguity: structured 200 clarification response with candidates.
- Unresolved/noisy entity: safe clarification or controlled entity error.
- No-match: structured 200 with zero results.
- Database exceptions: global handler returns generic 503 `DATABASE_ERROR`; covered by tests rather than disconnecting the measured backend.
- Provider errors: adapter/unit coverage verifies controlled failures. Live provider failure was not induced during measurement.

No SQL, credentials, API keys, or stack traces appeared in measured client errors. The conversation response currently exposes parsed query, routing plan, resolution details, and SearchPlan. Those fields predate this validation but should be reviewed as a production API-surface concern.

## Security / Deployment Readiness

### Blocker: verified database TLS is not implemented

`DB_USE_SSL=true` is parsed by `Settings`, but `Settings.database_url` contains only `charset=utf8mb4`, and `create_async_engine` receives no SSL context or RDS CA bundle. Therefore SQLAlchemy/asyncmy is **not proven to use TLS with AWS RDS certificate verification**. This is a production blocker. Certificate verification must not be disabled.

Other checks:

- Root `.env` is ignored by Git and is not tracked.
- No tracked OpenAI/Gemini key patterns were found outside excluded generated benchmark material.
- FastAPI debug mode and Uvicorn reload are not enabled in application code.
- No CORS middleware is configured. This is restrictive for native clients, but a separately hosted Flutter web app would require an explicit allowlist.
- `/v1/query-understanding`, `/v1/search`, and internal-rich conversation responses should be reviewed before public exposure; no authentication/rate-limit layer was observed in this backend.

## Railway Environment Checklist

Required production variables:

- `QUERY_UNDERSTANDING_PROVIDER=gemini`
- `QUERY_UNDERSTANDING_MODEL=gemini-3.5-flash-lite`
- `GEMINI_API_KEY=<secret>`
- `SPEECH_PROVIDER=openai`
- `SPEECH_MODEL=whisper-1`
- `OPENAI_API_KEY=<secret>`
- `WHISPER_PRODUCTION_STATUS=PROVISIONAL`
- `DB_HOST=<RDS host>`
- `DB_PORT=3306`
- `DB_NAME=<database>`
- `DB_USER=<least-privilege user>`
- `DB_PASSWORD=<secret>`
- `DB_USE_SSL=true`
- `ENTITY_SEARCH_FALLBACK_MODE=<approved mode>`

Remove or reconcile stale `LLM_PROVIDER`, `OPENAI_MODEL`, `GEMINI_MODEL`, and provider-specific legacy fallback variables. Explicit `QUERY_UNDERSTANDING_*` values currently win, but stale values create rollback and operational ambiguity.

Railway was not modified or deployed.

## Remaining Issues

1. Implement verified AWS RDS TLS with the AWS CA bundle and hostname/certificate verification.
2. Resolve the three failing deployable Flutter tests, especially the editable voice UI regression.
3. Fix or constrain conversation semantics for `Show videos from that rally`; fresh QU failed both measured follow-ups.
4. Preserve canonical referent IDs across conversation turns.
5. Correct co-driver participation result projection so matched-person identity is displayed accurately.
6. Keep Whisper provisional and expand human validation; one of two human samples failed badly.
7. Add safe startup logging for effective provider/model names and TLS mode.
8. Separate legacy live benchmarks from default `flutter test` discovery to prevent accidental paid runs.

## Production Recommendation

The deterministic backend and false-confidence safety gate passed, but deployment approval is blocked. Complete verified DB TLS and the critical test/conversation fixes, then rerun this same frozen production set. Do not change resolver thresholds to improve the score.

**PRODUCTION_VALIDATION_PASSED_WITH_BLOCKERS**
