# STT-2 database-aware transcription experiment

Status: **DOMAIN_CONTEXT_NO_MEANINGFUL_GAIN**

The contextual path remains disabled. This experiment did not modify PY-1,
PY-2 scoring or thresholds, PY-3 prompts, PY-4 conversation behavior, Flutter,
or the production speech provider.

## Controlled configuration

- Model: `gpt-transcribe` for both passes.
- Five labeled human WAV files; Raw NoOp audio; ten successful STT calls.
- Pass A: no prompt and no keyword hints.
- Pass B: same audio plus exactly 24 bounded canonical names/locations per
  request. Values came from the live Entity Search index/database only.
- Retrieval: top three candidates per entity type across rally, person, stage,
  and uploader; bounded latest-year rally/location vocabulary filled remaining
  keyword capacity.
- No canonical/internal IDs were sent to OpenAI. IDs are retained only in the
  local report to establish provenance.
- No full person database was sent. At most three retrieved person names were
  included in a request.
- Known language was sent with `languages[0]`; singular `language` was not sent.
- No prose prompt, aliases, phonetic spellings, typo dictionary, or manually
  authored entity vocabulary was used.
- Raw and contextual transcripts are stored separately. Confidence was not
  combined and the contextual result is not treated as independent evidence.
- Safety guard: a newly hinted exact canonical resolution would be downgraded
  to clarification. No guard fired because context never produced a new exact
  canonical spelling.

This request shape follows the official OpenAI file-transcription guidance for
`gpt-transcribe`: `keywords` are literal hints and may cause unspoken terms to
appear, while `languages` replaces singular `language`.

## Aggregate scoreboard

| Metric | Raw | Database-context pass | Delta |
|---|---:|---:|---:|
| Normalized WER | 25.93% | 25.93% | 0 |
| Entity-token accuracy | 55.56% | 55.56% | 0 |
| Canonical accuracy | 25.00% | 25.00% | 0 |
| Correct confident | 1 | 1 | 0 |
| Clarification | 3 | 3 | 0 |
| No match | 0 | 0 | 0 |
| Wrong confident | 1 | 1 | 0 |
| Average STT latency | 868 ms | 1,099 ms | +231 ms for STT alone |
| p95 STT latency | 983 ms | 1,675 ms | +692 ms |

Candidate retrieval averaged 2,339 ms. The complete incremental second-pass
cost—retrieval plus contextual STT—averaged **3,438 ms**, p95 **4,914 ms**.

## Per-recording comparison

| Recording | Reference | Raw transcript | Contextual transcript | Most relevant retrieved hints | Raw outcome | Context outcome |
|---|---|---|---|---|---|---|
| `asim1.wav` | drivers that participated in aluksne rally | Drivers that participated in Alex's rally. | Drivers that participated in Alex's rally. | `Rally Alūksne 2026`, `Sligo Stages Rally 2025`, `Ireland Rally Test`, `Alex Lee`, `Alex Benn`, `Alex Hill` | CLARIFICATION | CLARIFICATION |
| `asim2.wav` | rallies in aluksne | Rallies in Alytus. | Rallies in Ellucsne. | `Rally Alūksne 2026`, `Alina Test`, `Ireland Rally Test`, `Lind`, `Inês Veiga`, `Inês Braga` | WRONG_CONFIDENT (0 DB results) | WRONG_CONFIDENT (0 DB results) |
| `asim3.wav` | drivers that participated in aluksne rally | Drivers that participated in Alex's rally. | Drivers that participated in Alex's rally. | Same byte-identical audio and relevant hints as `asim1.wav` | CLARIFICATION | CLARIFICATION |
| `record_out.wav` | show me all rallies in which max freeman participated | Show me all rallies in which Max Freeman participated. | Show me all rallies in which Max Freeman participated. | `Max Freeman`, `Max Maier`, `Max Murray`, `ME Rallysport Showground Stages 2026` | CORRECT_CONFIDENT, 9 results | CORRECT_CONFIDENT, 9 results |
| `record_out (1).wav` | rally aluksne drivers | Rally aloops نے drivers. | Rally aloops نے drivers. | `Rally Alūksne 2026`, `Rallye National du Pays de Fayence 2025`, `Raven's Rock Stages Rally 2025` | CLARIFICATION | CLARIFICATION |

Every Alūksne recording received `Rally Alūksne 2026` as a literal,
database-derived keyword. None produced an exact `Alūksne` contextual
transcription. The only transcript change, `Alytus` to `Ellucsne`, did not
improve WER, entity correctness, canonical correctness, or downstream safety.

The Max Freeman safety control did not regress: both passes preserved the exact
name, `SEARCH_DRIVER_RALLIES`, the correct canonical person, and 9 current live
MySQL results.

## Decision

Wrong-confident outcomes did not increase, but they also did not reach the
preferred target of zero. Correct-confident outcomes, domain entity accuracy,
canonical accuracy, and normalized WER were unchanged, while the second pass
added substantial latency.

**DOMAIN_CONTEXT_NO_MEANINGFUL_GAIN**

The complete machine-readable artifact contains all 24 hints per request,
candidate IDs and scores for local provenance, both structured/resolved queries,
DB result counts, per-pass latencies, and raw/contextual transcripts:
`stt2_database_context_report.json`.
