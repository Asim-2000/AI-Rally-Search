# STT-3 audio-grounded domain interpretation

Status: **AUDIO_GROUNDING_INSUFFICIENT**

`gpt-audio` was accessible and all five explicitly authorized calls completed.
The experiment remains disabled in production. No PY-2 threshold/scoring,
PY-3 prompt, alias, typo dictionary, Flutter behavior, or production voice path
was changed.

## Architecture and safety

- Pass A reused the separately stored STT-2 `gpt-transcribe` raw transcript.
  No new transcription call was made.
- The raw transcript was passed through the existing PY-2 candidate generator.
- Each `gpt-audio` request contained the original WAV, raw transcript, language,
  and at most 3 rally, 3 person, 3 stage, and 4 location display terms.
- Locations came only from the metadata of retrieved rally candidates.
- No IDs, credentials, full person universe, aliases, or unrelated DB values
  were sent.
- `gpt-audio` was forced to call `interpret_spoken_search`; returned arguments
  were validated by strict Pydantic models.
- Returned entity selections had to be members of the supplied display terms.
  The resulting normalized transcript then passed through unchanged PY-3,
  unchanged PY-2 resolution, and live PY-1/MySQL.
- Raw STT and audio grounding were not treated as statistically independent,
  and no confidence values were combined.

The request shape follows the official OpenAI model/API contract: `gpt-audio`
accepts audio in Chat Completions and supports function calling, while native
Structured Outputs are not supported.

## Product metrics

| Metric | Raw path | Final after audio grounding and safety | Delta |
|---|---:|---:|---:|
| Normalized WER (diagnostic) | 25.93% | 18.52% | -7.41 pp |
| Entity-token accuracy | 55.56% | 66.67% | +11.11 pp |
| Fully correct entity recordings | 1/5 | 2/5 | +1 |
| Intent accuracy | 40% | 40% | 0 |
| Canonical accuracy | 25% | 50% | +25 pp |
| Correct confident | 1 | 1 | 0 |
| Clarification | 3 | 3 | 0 |
| No match | 0 | 0 | 0 |
| Wrong confident | 1 | 1 | 0 net |

The net wrong-confident count hides an unsafe shift: the unlisted `Alytus`
location was caught and downgraded to clarification, but the one corrected
Alūksne recording advanced to a different wrong-confident outcome because PY-3
assigned the wrong intent.

## Per-recording evidence

### `asim1.wav`

- Reference: `drivers that participated in aluksne rally`
- Raw: `Drivers that participated in Alex's rally.`
- Candidates sent:
  - rallies: `Sligo Stages Rally 2025`, `Rally Alūksne 2026`, `Ireland Rally Test`
  - people: `Alex Lee`, `Alex Benn`, `Alex Hill`
  - stages: `Aalbeke`
  - locations: `Sligo`, `Ireland`, `Alūksne`, `Latvia`
- `heard_text`: `Drivers that participated in Alex's rally.`
- `normalized_transcript`: unchanged
- `uncertain_terms`: none
- PY-3 intent: `SEARCH_DRIVER_RALLIES` (incorrect for fixture)
- PY-2/final: clarification; Alūksne not recovered
- Latency raw/retrieval/audio/total: 926 / 3,208 / 3,439 / 9,612 ms

### `asim2.wav`

- Reference: `rallies in aluksne`
- Raw: `Rallies in Alytus.`
- Candidates sent:
  - rallies: `Rally Alūksne 2026`, `Alina Test`, `Ireland Rally Test`
  - people: `Lind`, `Inês Veiga`, `Inês Braga`
  - stages: `Ring 1`, `Ring 2`
  - locations: `Alūksne`, `Latvia`, `Islamabad`, `Pakistan`
- `heard_text` / `normalized_transcript`: `Rallies in Alytus.`
- `uncertain_terms`: none
- `Alytus` was not an allowed location candidate. Candidate membership failed,
  so the raw successful-zero-result path was downgraded to clarification.
- Latency raw/retrieval/audio/total: 728 / 666 / 1,237 / 4,445 ms

### `asim3.wav`

- This WAV is byte-identical to `asim1.wav`.
- Raw, candidates, `heard_text`, and normalized transcript matched `asim1.wav`.
- Final: clarification; Alūksne not recovered.
- Latency raw/retrieval/audio/total: 814 / 3,418 / 1,123 / 7,186 ms

### `record_out.wav` — Max Freeman control

- Reference/raw/heard/normalized: `Show me all rallies in which Max Freeman participated.`
- Candidate people: `Max Freeman`, `Max Maier`, `Max Murray`
- Selected person: `Max Freeman`; no uncertain terms.
- PY-3 intent: `SEARCH_DRIVER_RALLIES`
- PY-2: correct Max Freeman canonical identity
- Live MySQL: 9 results
- Final: `CORRECT_CONFIDENT`; no regression
- Latency raw/retrieval/audio/total: 890 / 2,939 / 1,269 / 6,860 ms

### `record_out (1).wav`

- Reference: `rally aluksne drivers`
- Raw: `Rally aloops نے drivers.`
- Candidates sent:
  - rallies: `Rally Alūksne 2026`, `Rallye National du Pays de Fayence 2025`, `Raven's Rock Stages Rally 2025`
  - people: `New Driver`, `Dries Vergote`, `Dries Deprez`
  - stages: `Metālu Pasaule (Korneti 2)`, `Callan River 1`, `Callan River 2`
  - locations: `Alūksne`, `Latvia`, `Fayence`, `France`
- `heard_text`: `Rally aloops نے drivers.`
- `normalized_transcript`: `Rally Alūksne drivers.`
- Selected rally: `Rally Alūksne 2026`
- `uncertain_terms`: `aloops`
- Candidate membership: passed
- PY-2 canonical resolution: correct Rally Alūksne event
- PY-3 intent: `SEARCH_DRIVER_RALLIES`, expected `GET_RALLY_TOP_FINISHERS`
- Live MySQL: 1 result under the incorrect intent
- Final: `WRONG_CONFIDENT`
- Latency raw/retrieval/audio/total: 983 / 1,525 / 1,304 / 5,429 ms

## Latency

| Component | Average | p95 where retained |
|---|---:|---:|
| Raw `gpt-transcribe` | 868 ms | — |
| PY-2 candidate retrieval | 2,351 ms | — |
| `gpt-audio` | 1,675 ms | 3,439 ms |
| Complete path | 6,706 ms | 9,612 ms |

## Decision

Only one of four Alūksne fixture rows—one of three unique Alūksne waveforms—was
fixed. The two byte-identical participation recordings and the city recording
remained unfixed. Correct-confident results did not increase, zero
wrong-confident was not achieved, and the corrected rally spelling produced a
wrong-confident search intent/result.

**AUDIO_GROUNDING_INSUFFICIENT**

The complete machine-readable artifact preserves raw transcripts, every display
term sent, local candidate provenance IDs/scores, forced-call arguments,
uncertain terms, Pydantic status, safety-gate decisions, resolved queries,
canonical IDs, DB counts, usage, and latency in `stt3_audio_grounding_report.json`.
