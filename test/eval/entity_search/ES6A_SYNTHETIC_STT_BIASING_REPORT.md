# ES-6A — Synthetic STT Biasing Benchmark

Date: 2026-08-28  
Seed: `20260829`  
Gate: **NO-GO**  
Human voice status: **HUMAN_VOICE_BENCHMARK = BLOCKED**

This is an engineering benchmark using synthetic speech. It is not human-voice, accent, or real-pronunciation validation. Production voice routing, Entity Search scoring, resolver thresholds, confirmation policy, and entity-specific pronunciation aliases were not changed.

## A. Synthetic corpus composition

- 140 held-out live-DB entities: 30 rallies, 50 people, 30 stages, and 30 uploaders.
- 280 natural query utterances: two templates per selected entity.
- 560 main audio fixtures: clean and deterministically perturbed audio for every utterance.
- 6 negative-control fixtures: clean and noisy versions of three negative-bias utterances; the clean versions were evaluated at top 3, 5, and 10.
- 2,800 positive evaluation rows: the same 560 audio files evaluated as baseline, static context, and dynamic top 3/5/10.
- Historical failure names were excluded from held-out sampling and retained only in the separate transcript regression.

## B. Entity types and names sampled

The JSON artifact contains the canonical IDs and complete utterance manifest.

- Rallies (30): R Kings Down Rally 2026; R Kings Down Rally 2025; Mayo Forestry Rally 2025; Mayo Stages Rally 2026; Moonraker Forestry Rally 2025; Moonraker Forestry Rally 2026; Ardeca Ypres Rally 2026; Ardeca Ypres Rally 2025; Rali Terras d'Aboboreira 2026; Rali Terras d'Aboboreira 2025; New test; New Test Rally 2025; Clonakilty Park Hotel West Cork Rally 2025; Clonakilty Park Hotel West Cork Rally 2026; TrackTest Forest Stages 2025; Qatar International Rally 2026; Monaghan Stages Rally 2026; Woodpecker Rally 2025; MARMA Rajd Rzeszowski 2026; Corrib Oil Galway International Rally 2026; 7bet Rally Lazdijai 2025; Editor Portal Testing; OBM Land der 1000 Hügel Rallye 2026; Get Jerky Rally North Wales 2026; Barum Czech Rally Zlín 2026; Jim Walsh Cork Forest Rally 2025; Rally van Wervik 2026; Rally Clásico Isla de Mallorca-Puerto Portals 2026; Ardeca Ypres Rally test; Lakeland Stages Rally 2025.
- People (50 identities): Dave, Declan, and Nomol Jackson; Ryan, Stanley, and Steve Graham; Martin, Anthony, and Aaron O'Halloran; Billy, Gary, and Tom White; John Henderson plus two distinct David Henderson identities; Niall, Jack, and Sean Devine; Ray, Jonathan, and Niall McKenna; Grace, Michael, and Jason O'Brien; Fergal, Cathal, and Liam Keane; Alan, Josh, and Tommy Moffett; Neil and Brian Commons; Josephine, Josh, and Steve Harris; Mark, Glenn, and Nicholas Alcorn; Simon and Jason Woodley; Tommy, Eugene, and Anthony Cronin; Hayden and Andrew Graves; James O'Reilly, Killian O’Reilly, and Damian O'Reilly; Colin and Mark Blunt.
- Stages (30 identities): Aberhirnant 1 (3); Goolder 2, 3, and 1; Jackets 1 and 2; Sargé-sur-Braye 1 and 2; Atlantic Drive 1 (3); Windyhill 1 and 2; Semer Water 1 and 2; Arena Monster Energy 2, 1, and 4; Forty Acres 3, 2, and 1; Fanad Head 1 (2) and 2; New Stage (3); Lough Keel 1.
- Uploaders (30): alinashoaib1000; alinashoaib; Almeida74; Almeida; Silva98; Silva; Silva57; Tom; Tom54; Evan55; Evan46; Ralph; Ralph1; Niamh25; Niamh27; Rodrigues; Rodrigues97; testuser; testuser124; Testuser2; James; James8410; Dano555; Dano; Dias; Dias1980; ar9; ar7; ar6; Lynch.

The sample deliberately includes duplicate visible names, same-name identities, similar surnames, numbered stages/uploaders, and the same rally across different years. Biasing did not bypass role, year, identity, or duplicate-name clarification.

## C. Voices, styles, and perturbations

- Local macOS system TTS; no TTS provider calls or TTS API cost.
- Voices: Samantha and Daniel.
- Speaking rates: 165, 180, 205, and 210 words/minute.
- Variation came from voice, rate, template/sentence length, and clean/noisy condition.
- Noisy fixtures applied deterministic low background noise, volume reduction, mild dynamic compression, and leading/trailing silence.
- The generated audio remains synthetic and does not represent human accents.

## D. STT provider capabilities used

- OpenAI `gpt-transcribe` through the existing speech-provider abstraction.
- Baseline: English language hint only; no entity vocabulary.
- Static: generic rally-domain prompt and seven generic keywords.
- Dynamic: the same generic prompt plus legitimate live-DB `canonicalName`/`searchableNames` candidates and `keywords[]`, limited to top 3, 5, or 10.
- `transcriptionOrigin` is recorded as `baseline`, `staticContext`, or `dynamicBiased`.
- At most one second pass is allowed. The resolver remains authoritative, and biased output never receives a confidence boost.

Provider capability and pricing references: [Speech-to-text guide](https://developers.openai.com/api/docs/guides/speech-to-text) and [GPT-Transcribe model](https://developers.openai.com/api/docs/models/gpt-transcribe).

## E–I. Strategy results

Outcomes are mutually exclusive: correct-confident, clarification, no-match, or wrong-confident.

| Metric | E. Baseline | F. Static | G. Dynamic top 3 | H. Dynamic top 5 | I. Dynamic top 10 |
|---|---:|---:|---:|---:|---:|
| Cases | 560 | 560 | 560 | 560 | 560 |
| Canonical accuracy / Recall@1 | 37.86% | 36.43% | 39.46% | 39.64% | 40.71% |
| Correct confident | 136 (24.29%) | 128 (22.86%) | 169 (30.18%) | 165 (29.46%) | 167 (29.82%) |
| Clarification | 239 (42.68%) | 250 (44.64%) | 203 (36.25%) | 204 (36.43%) | 207 (36.96%) |
| No-match | 178 (31.79%) | 176 (31.43%) | 184 (32.86%) | 186 (33.21%) | 179 (31.96%) |
| Wrong confident | 7 (1.25%) | 6 (1.07%) | 4 (0.71%) | 5 (0.89%) | 7 (1.25%) |
| Bias-induced entity errors | 0 | 24 (4.29%) | 7 (1.25%) | 9 (1.61%) | 7 (1.25%) |
| Second-pass trigger rate | 0% | 0% | 78.57% | 78.57% | 78.57% |
| Average STT calls/query | 1.000 | 1.000 | 1.786 | 1.786 | 1.786 |
| Average STT latency | 773 ms | 676 ms | 1,331 ms | 1,046 ms | 1,015 ms |
| Average total latency | 3,971 ms | 3,875 ms | 7,064 ms | 6,671 ms | 6,674 ms |
| p95 total latency | 6,688 ms | 6,732 ms | 12,082 ms | 11,615 ms | 11,577 ms |
| WER (secondary) | 64.16% | 64.84% | 59.78% | 59.90% | 59.30% |
| CER (secondary) | 21.54% | 21.47% | 18.57% | 18.73% | 18.50% |
| Clean canonical accuracy | 37.50% | 36.43% | 39.64% | 40.00% | 41.79% |
| Noisy canonical accuracy | 38.21% | 36.43% | 39.29% | 39.29% | 39.64% |

## J. Canonical accuracy comparison

- Static context regressed by 1.43 percentage points relative to baseline.
- Dynamic top 3 improved by 1.61 points, top 5 by 1.79 points, and top 10 by 2.86 points.
- Top 10 had the best Recall@1, but “more hints” was not uniformly safer: it had 7 wrong-confident cases versus 4 for top 3.
- By entity type, baseline/top-10 accuracy was: people 62.5%/63.0%; rallies 61.7%/69.2%; stages 10.8%/15.8%; uploaders 0%/0%. The gains were concentrated in rallies and stages; uploader query understanding remained a major gap.

## K. Clarification and no-match comparison

- Dynamic top 3 reduced clarification by 36 cases (6.43 points), with no-match increasing by 6 cases (1.07 points).
- Dynamic top 5 reduced clarification by 35 cases, with no-match increasing by 8.
- Dynamic top 10 reduced clarification by 32 cases, while no-match was essentially unchanged (+1 case).
- Static context increased clarification by 11 cases and did not improve the combined unresolved outcome.

## L. Wrong-confident count

Baseline 7; static 6; dynamic top 3 **4**; dynamic top 5 **5**; dynamic top 10 **7**. The success rule requires zero, so no dynamic configuration passes the safety gate.

## M. Bias-induced error count

- Positive corpus: static 24; dynamic top 3 7; top 5 9; top 10 7.
- Required negative corpus: **0/9** bias-induced errors across three utterances × three vocabulary sizes.
- The wrong-person negative transcript changed under bias (`Josh Moffett` → variants such as `Shil Josh Moffat`) but still resolved conservatively to the spoken name rather than a supplied wrong candidate.
- Zero negative-control failures does not override the positive-corpus bias errors.

## N. Latency

Dynamic second pass added approximately 2.70–3.09 seconds to average end-to-end latency and approximately 4.89–5.39 seconds at p95 versus baseline. About 20 of 560 main-corpus items reused resumable transcript-cache entries during the final aggregation, so the latency averages are slightly downward-biased; quality results are unaffected.

## O. STT calls/query

- Baseline/static: 1.000.
- Each dynamic configuration: 1.786 because 78.57% triggered one additional transcription.
- Across the experiment: 563 baseline/negative first-pass calls, 560 static calls, and 1,329 dynamic second-pass calls; 2,452 total logical provider calls.

## P. Experimental cost

- TTS API calls: 0. Local TTS syntheses for the main corpus: 560.
- Unique main-corpus duration: 1,260.244 seconds (21:00.244).
- Repeated STT-billed audio represented by all evaluated calls, including negative controls: 3,115.352 seconds (51:55.352).
- At $0.0045/minute, estimated `gpt-transcribe` experimental cost: **$0.23365**.
- No production cost extrapolation is made.

## Q. Historical transcript regressions (separate)

These are transcript strings, not synthetic-audio or human-audio results. All 12 expected canonical targets ranked first: `aluksni`, `aluksnay`, `aluksney`, `alux new`, `a looks nay`, `eluksne`, `aluknse`, `pawel malgo`, `shea brain`, `donny gall`, `kemel berg`, and `dushniki`.

Resolver outcomes were 6 conservative resolutions and 6 clarifications, with 0 no-match and 0 wrong target. This separate regression test passed against the live DB.

## R. Synthetic benchmark limitations

- System TTS cannot validate real human pronunciation, microphones, accents, hesitations, code-switching, or environmental variability.
- It does not prove real-speaker handling of Alūksne, Paweł Molgo, or any other difficult name.
- Dynamic transcription is causally influenced by Entity Search. Candidate echo is not independent evidence and was not treated as such.
- The corpus has only two query templates per entity and one clean/one perturbed recording per query; moderate-noise and broader style coverage remain limited.
- The final latency aggregation contains a small number of resumable cache hits, as disclosed above.
- Low stage and uploader accuracy shows that downstream query understanding remains a bottleneck independent of STT spelling quality.

## S. Human gate

**HUMAN_VOICE_BENCHMARK = BLOCKED**

No conservative real-user voice confirmation policy should be relaxed until genuine human recordings have been evaluated.

## T. Recommendation

**NO-GO**

Dynamic biasing produced a modest accuracy improvement and materially fewer clarifications, but every top-K configuration produced wrong-confident resolutions and 7–9 positive-corpus bias-induced errors. This violates the explicit zero wrong-confident requirement. Do not enable or shadow dynamic STT biasing yet. Keep the experimental architecture and fixtures for a later phase focused on query-understanding gaps and safer second-pass gating; production routing remains unchanged.

## Verification

- Full synthetic benchmark: 560/560 audio files, passed.
- Focused unit and speech abstraction tests: 9 passed.
- Historical transcript regression: passed, 12/12 Recall@1.
- Scoped static analysis: 0 errors/warnings; 3 pre-existing style notices in the OpenAI speech service.
