# Urgent STT quality bake-off

Status: **RAW_STT_INSUFFICIENT**

No STT model/configuration candidate was changed. PY-1 through PY-4, Flutter,
the frozen PY-3 prompt/schema, Entity Search, resolver, and repository semantics
were not modified. The final cross-model product benchmark remains deferred.

## Controlled setup

- Exactly tested: `whisper-1`, `gpt-4o-mini-transcribe`,
  `gpt-4o-transcribe`, and `gpt-transcribe`. All four were accessible.
- Corpus: the five physically present, labeled human WAV fixtures from
  `human_voice_smoke_manifest.json`; no synthetic audio was used.
- Caveat: `asim1.wav` and `asim3.wav` are byte-identical (same SHA-256), so the
  five-file corpus contains four unique recordings.
- Audio input: original WAV bytes, Raw NoOp, fixture language only, no prompt,
  vocabulary, aliases, entity hints, second pass, or preprocessing.
- Downstream: frozen PY-3.1 OpenAI `gpt-4.1-mini`, temperature `0.0`, then PY-2
  Entity Search, resolver, PY-1 repository, and live MySQL.
- Scoring: corpus-level word edit distance / reference words. Normalized WER
  additionally uses the labeled normalized reference and accent folding.
  Entity token accuracy is expected-domain-token recall. Exact entity phrase
  matching is accent-insensitive.

## Aggregate results

| STT model | WER | normalized WER | entity token accuracy | intent accuracy | canonical accuracy | correct | clarification | no match | wrong confident | avg / p95 STT latency | estimated USD/min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `whisper-1` | 59.26% | 55.56% | 33.33% | 40% | 25% | 1 | 4 | 0 | 0 | 1,318 / 1,583 ms | $0.0060 |
| `gpt-4o-mini-transcribe` | 37.04% | 33.33% | 22.22% | 40% | 25% | 1 | 2 | 0 | 2 | 793 / 884 ms | $0.0030 |
| `gpt-4o-transcribe` | 37.04% | 29.63% | 33.33% | 40% | 50% | 2 | 1 | 0 | 2 | 963 / 1,510 ms | $0.0060 |
| `gpt-transcribe` | **29.63%** | **25.93%** | 33.33% | 40% | 25% | 1 | 2 | 0 | 2 | **792** / 936 ms | $0.0045 |

The evaluated audio totals 0.4515 minutes. Corresponding estimated corpus costs
were $0.002709, $0.001355, $0.002709, and $0.002032 in table order. These are
static list-price estimates, not observed invoice line items.

Rally phrase accuracy on the three rally-labeled rows was **0/3 for every
model**. City accuracy was 0/1, 0/1, 1/1, and 0/1 respectively. Person phrase
accuracy was 1/1, 1/1, 0/1, and 1/1 respectively.

## Verbatim domain diagnostics

| Fixture | Reference | whisper-1 | gpt-4o-mini-transcribe | gpt-4o-transcribe | gpt-transcribe |
|---|---|---|---|---|---|
| asim1 | drivers that participated in aluksne rally | Drivers that participated in Aleut's narrative. | Drivers that participated in Alex Neary. | Drivers that participated in elites narrowly. | Drivers that participated in Alex Nerelli. |
| asim2 | rallies in aluksne | Raleigh is an Aleutian name. | rallies in Olympics | Rallies in Alūksne. | Rallies in Alytus. |
| asim3 | drivers that participated in aluksne rally | Drivers that participated in Aleut's narrative. | Drivers that participated in Alex near | Drivers that participated in Alutsne Rally. | Drivers that participated in Alex Nerelli. |
| record_out.wav | show me all rallies in which max freeman patcipated | Show me all rallies in which Max Freeman participated. | Show me all rallies in which Max Freeman participated. | Show me all rallies in which Max Freemann participated. | Show me all rallies in which Max Freeman participated. |
| record_out (1).wav | rally aluksne drivers | Rally a Luke's name drivers | رالی الپس نے ڈرائیورز | ریلی الوپس نے ڈرائیورز. | Rally eloops نے drivers. |

`gpt-4o-transcribe` was the only model to produce exact accent-normalized
`Alūksne` once, on the city recording. It still failed all three rally-labeled
phrase checks. `Max Freeman` was exact for three models; `gpt-4o-transcribe`
produced `Max Freemann`, although PY-2 still resolved it to the correct person.

## Downstream safety and conclusion

All successful transcripts executed through the same live deterministic path.
Whisper avoided wrong-confident results only because four of five cases stopped
for clarification; that does not make it an acceptable recognizer. The other
three models each produced two wrong-confident outcomes. Empty-result successful
queries caused by substitutions such as `Olympics` and `Alytus` are counted as
wrong-confident, not as correct merely because their broad intent matched.

No model demonstrated adequate raw domain recognition on the central Alūksne
rally task. Therefore this run does not set `STT_WINNER` and does not update the
PY-5 STT candidate:

**RAW_STT_INSUFFICIENT**

The durable machine-readable evidence, including every transcript, WER edit
count, entity diagnostic, structured/resolved query, canonical IDs, DB count,
outcome, and latency is in `stt_quality_bakeoff_report.json`. The repeatable
runner is `backend/scripts/run_stt_quality_bakeoff.py`.
