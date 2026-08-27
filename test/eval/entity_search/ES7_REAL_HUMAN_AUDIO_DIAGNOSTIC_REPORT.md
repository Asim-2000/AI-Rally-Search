# ES-7 — Labeled Human Audio Smoke Benchmark

## Decision

`HUMAN_BENCHMARK_STATUS = LABELED_SMOKE_TEST_ONLY`

The five human files now have authoritative owner-supplied transcript labels. They contain four unique waveforms, so this remains a labeled smoke test and is not statistically meaningful human-voice validation.

**Preprocessing recommendation: INSUFFICIENT / MIXED. Do not enable preprocessing.** Some strategies improve aggregate WER/CER on the four unique recordings, but none improves exact entity-mention accuracy or aggregate canonical correctness, and several produce transcript, wrong-clarification, or canonical regressions.

STT biasing remained disabled, all derived audio stayed in memory, the original WAV files were not overwritten, and production voice routing was not changed.

## Inventory and duplicate handling

| Measure | Value |
|---|---:|
| `TOTAL_FILES` | 5 |
| `UNIQUE_AUDIO_FILES` | 4 |
| `DUPLICATE_GROUPS` | 1: human-smoke-001 / human-smoke-003 |

`asim1.wav` and `asim3.wav` were verified byte-identical and retain separate manifest entries. Per-file results include both. Unique-audio aggregates use human-smoke-001 as the representative and exclude human-smoke-003, preventing the duplicate from improving or worsening aggregate accuracy.

The duplicate produced the same STT text but different RAW query-parser behavior. That is downstream LLM nondeterminism, not an audio difference, and is another reason to treat this suite as diagnostic only.

## Authoritative transcript labels

| Recording | File | `referenceTranscriptRaw` | `referenceTranscriptNormalized` |
|---|---|---|---|
| 001 | `asim1.wav` | drivers that participated in aluksne rally | same |
| 002 | `asim2.wav` | rallies in aluksne | same |
| 003 | `asim3.wav` | drivers that participated in aluksne rally | same |
| 004 | `record_out.wav` | show me all rallies in which max freeman patcipated | show me all rallies in which max freeman participated |
| 005 | `record_out (1).wav` | rally aluksne drivers | same |

The raw labels are preserved verbatim. Only the obvious typed `patcipated` typo is normalized to `participated` for WER/CER. No reference transcript is inferred from STT output.

## Independent live-DB canonical truth

Canonical labels were established with exact live-database queries before evaluating Entity Search results:

- Exact `rally_events.event_name = 'Rally Alūksne 2026'` identifies event ID `0cea6942-72e3-4257-a8c1-0f8148747d82`; the match is unambiguous.
- Exact Max Freeman profile and raw entry-list participation joins identify canonical person ID `person:account:cf3ddf9c-a64b-4f59-a5e4-5230c44b4d87` and co-driver profile ID `7a633b52-950e-49ef-8cab-34cd43e99366`. Live truth contains 0 driver-role and 9 co-driver-role participations. The expected query role remains `ANY`: the utterance asks for participation, not wins or results.
- “rallies in aluksne” is explicitly marked ambiguous at the canonical-entity layer. Its literal semantics are a city filter, not a single event lookup. Rally Alūksne 2026 is persisted as the independently verified related event, but its event ID is not forced as the expected result because that would change the utterance semantics. Canonical correctness is therefore unscored for this fixture.

The legacy resolver returns the Max Freeman co-driver profile ID. The evaluator accepts that ID only as an explicitly persisted equivalent of the canonical account-level person identity.

## Expected query semantics

| Recording | Expected intent | Entity type | Role | Canonical target |
|---|---|---|---|---|
| 001 / 003 | `GET_RALLY_TOP_FINISHERS` | rally | — | Rally Alūksne 2026 event ID |
| 002 | `SEARCH_RALLIES` | city | — | city filter `Alūksne`; canonical event not forced |
| 004 | `SEARCH_DRIVER_RALLIES` | person | `ANY` | Max Freeman person ID; participation semantics |
| 005 | `GET_RALLY_TOP_FINISHERS` | rally | — | Rally Alūksne 2026 event ID |

## Complete RAW pipeline results

WER/CER use the normalized reference while the raw reference remains in every fixture result.

| Recording | RAW STT | WER | CER | Extracted mention | Expected canonical entity | Target rank | Resolver / final ID | Final SearchQuery semantics | Outcome |
|---|---|---:|---:|---|---|---:|---|---|---|
| 001 | Drivers that participated in Alex's rally. | 33.33% | 11.90% | none; parse failed | Rally Alūksne 2026 | — | no-match / none | none | `NO_MATCH` |
| 002 | Rallies in Alytus. | 33.33% | 27.78% | city `Alytus` | city `Alūksne` | — | no-match / none | `SEARCH_RALLIES`, wrong city | `NO_MATCH` |
| 003 | Drivers that participated in Alex's rally. | 33.33% | 11.90% | rally `Alex's rally` | Rally Alūksne 2026 | 1 | clarification for an unrelated rally / none | expected intent, wrong entity phrase | `WRONG_CLARIFICATION` |
| 004 | Show me all rallies in which Max Freeman participated. | 0.00% | 0.00% | person `Max Freeman` | Max Freeman | 1 | resolved / equivalent co-driver ID `7a633b52-950e-49ef-8cab-34cd43e99366` | `SEARCH_DRIVER_RALLIES`, role `ANY` | `CORRECT_CONFIDENT` |
| 005 | Rally aloops نے ڈرائیورز۔ | 100.00% | 66.67% | rally `Rally aloops` | Rally Alūksne 2026 | 1 | clarification for Rally Alūksne / none | parsed `SEARCH_RALLIES`; intended top-finishers semantics not preserved | `CORRECT_CLARIFICATION` |

`CORRECT_CLARIFICATION` requires the actual clarification question to name the expected canonical entity. Merely ranking the target in Entity Search does not qualify.

## RAW aggregate metrics

| Metric | Per file (5) | Unique audio (4) |
|---|---:|---:|
| Mean WER | 40.00% | 41.67% |
| Mean CER | 23.65% | 26.59% |
| Exact entity mention | 1/5 | 1/4 |
| Confident final canonical ID correct | 1/4 scorable | 1/3 scorable |
| Canonical outcome correct, including clarification | 2/4 scorable | 2/3 scorable |
| Final query semantics correct | 1/5 | 1/4 |

Per-file outcomes: 2 `NO_MATCH`, 1 `WRONG_CLARIFICATION`, 1 `CORRECT_CONFIDENT`, 1 `CORRECT_CLARIFICATION`.

Unique-audio outcomes: 2 `NO_MATCH`, 1 `CORRECT_CONFIDENT`, 1 `CORRECT_CLARIFICATION`. The excluded duplicate is the per-file `WRONG_CLARIFICATION` case, so both views are reported rather than allowing it to skew the headline metric.

## Preprocessing STT A/B

| Recording | RAW | VAD only | Normalized | Noise suppressed | VAD + normalized + noise suppressed |
|---|---|---|---|---|---|
| 001 | Alex's rally | Alex Nerelli | Alex Nerelli | Alice Nere | Alice Nere |
| 002 | Rallies in Alytus | Rallies and elucinate | Rallies in Alytus | Rallies in Alytus | Rallies in Alytus |
| 003 | Alex's rally | Alex Nerelli | Alex Nerelli | Alice Nere | Alice Nere |
| 004 | Max Freeman participated | unchanged | unchanged | unchanged | unchanged |
| 005 | Rally aloops + Urdu-script “drivers” | unchanged | Rally aloops + English “drivers” | Rally Aloops + English “drivers” | Rally aloops + English “drivers” |

The full report preserves each complete transcript, WER, CER, entity mention, candidate rank, resolver outcome, final canonical ID, and final SearchQuery.

## Preprocessing pipeline outcomes

| Recording | RAW | VAD only | Normalized | Noise suppressed | Full |
|---|---|---|---|---|---|
| 001 | `NO_MATCH` | `NO_MATCH` | `NO_MATCH` | `WRONG_CLARIFICATION` | `WRONG_CLARIFICATION` |
| 002 | `NO_MATCH` | `NO_MATCH` | `NO_MATCH` | `NO_MATCH` | `NO_MATCH` |
| 003 | `WRONG_CLARIFICATION` | `NO_MATCH` | `NO_MATCH` | `WRONG_CLARIFICATION` | `WRONG_CLARIFICATION` |
| 004 | `CORRECT_CONFIDENT` | `CORRECT_CONFIDENT` | `CORRECT_CONFIDENT` | `CORRECT_CONFIDENT` | `CORRECT_CONFIDENT` |
| 005 | `CORRECT_CLARIFICATION` | `CORRECT_CLARIFICATION` | `CORRECT_CLARIFICATION` | `CORRECT_CLARIFICATION` | `WRONG_CLARIFICATION` |

## Unique-audio preprocessing metrics

| Strategy | Mean WER | Mean CER | Exact mention | Correct canonical outcome | Regressions observed |
|---|---:|---:|---:|---:|---|
| RAW | 41.67% | 26.59% | 1/4 | 2/3 scorable | baseline |
| VAD only | 50.00% | 29.96% | 1/4 | 2/3 | 2 transcript regressions |
| Normalized | 33.33% | 17.66% | 1/4 | 2/3 | 1 transcript improvement, 1 transcript regression |
| Noise suppressed | 33.33% | 19.44% | 1/4 | 2/3 | 1 transcript improvement, 1 wrong-clarification regression |
| Full | 33.33% | 19.44% | 1/4 | 1/3 | 1 canonical regression and 1 wrong-clarification regression |

Important case-level findings:

- VAD damages the city example: `Alytus` becomes `elucinate`, increasing WER from 33.33% to 66.67% and CER from 27.78% to 38.89%.
- Normalization and noise suppression improve recording 005's WER from 100% to 66.67% and CER from 66.67% to 28.57%, but they do not recover the exact `Alūksne` mention.
- Noise suppression turns recording 001 from no-match into a wrong clarification for `Alina Test`.
- The full strategy turns recording 005's correct Rally Alūksne clarification into a wrong clarification for `Rapalloo`, despite better WER/CER.
- No strategy changes unique-audio exact mention accuracy (1/4) or confident final canonical resolution accuracy (1/3 scorable).

Aggregate transcription gains therefore do not establish entity or canonical gains. The labeled evidence does not support enabling preprocessing.

## Safety and scope

- `VOICE_EXACT_MATCH_ESCALATION`: 0 confirmed cases across 20 per-file scorable runs and 0 across 15 unique-audio scorable runs.
- `WRONG_CONFIDENT`: 0 for every preprocessing strategy.
- STT context biasing: disabled.
- Production voice behavior: unchanged.
- Original recordings: unchanged; derived audio was memory-only.
- A second STT provider was not tested because the project has no second already-supported non-mock provider.

## Verification

- Five-file unbiased RAW baseline: passed and frozen.
- Twenty preprocessing runs (four strategies × five files): passed.
- Exact live-DB ground-truth assertions: passed before Entity Search evaluation.
- Benchmark static analysis: no issues.
- The earlier 560-audio ES-6A synthetic biasing benchmark was intentionally not rerun; ES-6 STT biasing remains shelved.

Machine-readable evidence:

- `human_voice_smoke_manifest.json`
- `human_voice_smoke_baseline_report.json`
- `human_voice_preprocessing_ab_report.json`
