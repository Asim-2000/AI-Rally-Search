# ES-8A — Real-Human Dynamic Top-3 Biasing Smoke Test

## Decision

**Recommendation: PROMISING — COLLECT MORE HUMAN AUDIO.**

Dynamic top-3 improved the one failed scorable unique recording from `NO_MATCH` to `CORRECT_CLARIFICATION`, preserved the two accepted winners without retranscribing them, and produced zero wrong-confident outcomes. This is only a four-unique-recording labeled smoke test. Dynamic biasing remains experimental and disabled; production voice routing is unchanged.

`HUMAN_BENCHMARK_STATUS = LABELED_SMOKE_TEST_ONLY`

## A. Frozen RAW baseline per unique human recording

| File | Reference raw / normalized | Expected intent and canonical entity | RAW STT / extracted mention | Target rank | Resolver / final ID | Classification |
|---|---|---|---|---:|---|---|
| `asim1.wav` | drivers that participated in aluksne rally / same | `GET_RALLY_TOP_FINISHERS`; Rally Alūksne 2026 (`0cea6942-72e3-4257-a8c1-0f8148747d82`) | “Drivers that participated in Alex's rally.” / none because parsing failed | — | no-match / none | `NO_MATCH` |
| `asim2.wav` | rallies in aluksne / same | `SEARCH_RALLIES`; ambiguous city filter, no forced event target | “Rallies in Alytus.” / city `Alytus` | — | no-match / none | `NO_MATCH` (canonical unscored) |
| `record_out.wav` | show me all rallies in which max freeman patcipated / …participated | `SEARCH_DRIVER_RALLIES`, role `ANY`; Max Freeman | exact normalized transcript / person `Max Freeman` | 1 | resolved / equivalent co-driver ID `7a633b52-950e-49ef-8cab-34cd43e99366` | `CORRECT_CONFIDENT` |
| `record_out (1).wav` | rally aluksne drivers / same | `GET_RALLY_TOP_FINISHERS`; Rally Alūksne 2026 | mixed-script “Rally aloops …” / rally `Rally aloops` | 1 | clarification for Rally Alūksne / none | `CORRECT_CLARIFICATION` |

Frozen unique canonical correctness: **2/3 scorable**.

## B–C. Existing 1/3 failure and root cause

The failed unique recording was `asim1.wav`.

| Diagnostic step | Finding |
|---|---|
| A. STT error | Yes. `Alūksne` became `Alex's`. |
| B. Query Understanding error | Yes. The frozen run returned no parseable transcript. |
| C. Entity extraction error | Yes. No mention was produced. |
| D. Target absent from candidate pool | Not assessable: no pool existed because extraction failed. |
| E. Target ranked too low | No rank existed; this was not a low-rank failure. |
| F. Resolver result | `NO_MATCH`. |
| G. Wrong canonical candidate | No candidate was selected. |

The immutable diagnosis was recorded before ES-8A implementation in `es8a_raw_failure_diagnosis.json`, tied to frozen baseline SHA-256 `2a10f02f249ae55a45f6708d20f61fff4d0c7a40f43e9f51d10ae2aa4fa71ef4`.

## D–G. Dynamic top-3 results per unique recording

| File | Pass 1 transcript; WER/CER | Pass-1 entity / rank / resolver | Pass 2? | Top-3 hints | Pass 2 transcript; WER/CER | Final outcome |
|---|---|---|---|---|---|---|
| `asim1.wav` | “Drivers that participated in Alex's rally.”; 33.33% / 11.90% | rally `Alex's rally`; rank 1; wrong clarification disagreeing with Entity Search top 1 | Yes | Rally Alūksne 2026; Raven's Rock Stages Rally 2025; Alina Test | “Drivers that participated in Alūksne Rally.”; 0% / 0% | Underlying resolver resolved the correct event, but circular-evidence guard removed the ID and required confirmation: `CORRECT_CLARIFICATION` |
| `asim2.wav` | “Rallies in Ellucsne.”; 33.33% / 16.67% | city `Ellucsne`; no indexed candidate group; no-match | No | none | — | `NO_MATCH`, canonical unscored |
| `record_out.wav` | exact Max Freeman transcript; 0% / 0% | person `Max Freeman`; rank 1; resolved | No—frozen winner protected | Max Freeman; Max Matton; Max McRae (computed but not supplied) | — | `CORRECT_CONFIDENT`, ID `7a633b52-950e-49ef-8cab-34cd43e99366` |
| `record_out (1).wav` | “Rally aloops … drivers.”; 66.67% / 28.57% | rally `Rally aloops`; rank 1; correct top-1 clarification | No—frozen winner protected | Rally Alūksne 2026 plus two alternatives (computed but not supplied) | — | `CORRECT_CLARIFICATION` |

Only `asim1.wav` triggered a second pass in the unique-audio view. The byte-identical `asim3.wav` manifest entry also triggered in the per-file view, but it is excluded from primary metrics. Its different Query Understanding and hint set despite duplicate audio is further evidence of downstream LLM nondeterminism.

## H–K. Canonical outcome, recovery delta, and safety

| Metric | Per file (5) | Unique audio (4) |
|---|---:|---:|
| Canonical scorable | 4 | 3 |
| Frozen baseline correct | 2 | 2 |
| Dynamic final correct | 4 | 3 |
| Improved | 2 | 1 |
| Unchanged | 3 | 3 |
| Worsened | 0 | 0 |
| Dynamic wrong-confident | 0 | 0 |
| Circular-evidence guards applied | 1 | 1 |

`dynamicWrongConfident = 0`, satisfying the mandatory safety requirement.

The `asim1.wav` pass-2 STT result exactly reflected a supplied hint. The deterministic resolver would have returned the Rally Alūksne event confidently, but this is circular evidence. The ES-8A guard therefore removed the final canonical ID and emitted a Rally Alūksne clarification. The improvement is `NO_MATCH → CORRECT_CLARIFICATION`, not independent confident resolution.

No previously correct baseline recording was retranscribed.

## L–M. Human-audio latency and STT calls

Primary duplicate-aware means:

| Measure | Milliseconds |
|---|---:|
| Frozen baseline STT | 711.00 |
| Frozen baseline total | 3,972.25 |
| Dynamic pass-1 STT | 793.50 |
| Dynamic pass-1 total | 4,502.00 |
| Dynamic second-pass STT, triggered queries only | 779.00 |
| Dynamic total | 5,134.75 |

For recovered `asim1.wav`, dynamic total latency was 9,158 ms versus its frozen baseline total of 5,154 ms.

| Measure | Per file | Unique audio |
|---|---:|---:|
| Second-pass trigger rate | 40.00% | 25.00% |
| Average STT calls/query | 1.40 | 1.25 |

These numbers describe this execution only. Four unique recordings cannot support production-latency extrapolation.

## N. Duplicate handling

`TOTAL_FILES = 5`

`UNIQUE_AUDIO_FILES = 4`

`DUPLICATE_GROUPS = 1` (`asim1.wav`, `asim3.wav`)

Both manifest entries were retained and executed. Primary metrics use `asim1.wav` as the SHA-group representative and exclude `asim3.wav`, so duplicate audio cannot improve the headline recovery rate.

## O. Ambiguous-case handling

`asim2.wav` remains a literal Alūksne city-filter query. It is not forced to the Rally Alūksne event ID. Pass 1 produced no Entity Search candidate group for the city mention, so no top-3 hints existed and no second pass ran. It remains excluded from canonical correctness metrics.

## P. Status and scope

`HUMAN_BENCHMARK_STATUS = LABELED_SMOKE_TEST_ONLY`

- Original WAV files were used unchanged.
- `IAudioPreprocessor = NoOpAudioPreprocessor`; audio preprocessing was not mixed into the experiment.
- No static domain prompt or static vocabulary was used.
- Only dynamic top 3 was tested; top 5 and top 10 were not run.
- Maximum second passes was one.
- The existing 560-audio synthetic benchmark was not rerun.
- Production routing and resolver implementation were not changed.
- Dynamic STT biasing remains disabled.
- No general human/accent robustness claim is made.

## Recommendation

**PROMISING — COLLECT MORE HUMAN AUDIO.**

The isolated behavior recovered the sole failed unique canonical case safely, but this is one recovery in a four-waveform corpus and ends in clarification by design. Collect a materially larger labeled human corpus before reconsidering shadow or production use.

Machine-readable evidence:

- `es8a_raw_failure_diagnosis.json`
- `human_voice_dynamic_top3_report.json`
