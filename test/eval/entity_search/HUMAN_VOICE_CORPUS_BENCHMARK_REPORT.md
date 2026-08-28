# Human Voice Corpus Benchmark

`HUMAN_BENCHMARK_STATUS = LABELED_SMOKE_TEST_ONLY`

Architecture status: **FROZEN FOR HUMAN DATA COLLECTION**.

Recommendation: **PROMISING — COLLECT MORE HUMAN AUDIO**

## Fixture validation

| Measure | Value |
|---|---:|
| Valid | true |
| Errors | 0 |
| Warnings | 5 |
| Fixtures silently dropped | 0 |
| TOTAL_FILES | 5 |
| UNIQUE_AUDIO_FILES | 4 |
| DUPLICATE_GROUPS | 1 |

## Primary unique-audio metrics

| Metric | RAW_BASELINE | RAW_DYNAMIC_TOP3 |
|---|---:|---:|
| Canonical correct | 1/3 | 2/3 |
| Correct confident | 1 | 1 |
| Correct clarification | 0 | 1 |
| WRONG_CONFIDENT | 0 | 0 |
| Wrong clarification | 1 | 0 |
| No-match | 2 | 2 |
| Mean WER | 33.33% | 16.67% |
| Mean CER | 14.88% | 7.74% |

Recovery: **1 improved, 3 unchanged, 0 worsened**.

Second-pass trigger rate: 50.00%; average STT calls/query: 1.500.

| Total latency | RAW_BASELINE | RAW_DYNAMIC_TOP3 |
|---|---:|---:|
| Average | 3707.8 ms | 6217.8 ms |
| p50 | 2758.0 ms | 2758.0 ms |
| p95 | 4839.0 ms | 10995.0 ms |

Per-file metrics are retained in JSON (5 files); primary metrics are SHA-256-deduplicated.

## WRONG_CONFIDENT safety

**No wrong-confident human results.**


### Newly introduced by RAW_DYNAMIC_TOP3

**None.**

## Bias recovery triggers

### human-smoke-001

- Pass 1: Drivers that participated in Alex Nerelli.
- Trigger: `PASS1_NO_MATCH`
- Top 3: Alex Lee; Alexine Serin; Alexander Derez
- Pass 2: Drivers that participated in Alex Nerelli.
- Outcome: `NO_MATCH → NO_MATCH` (`UNCHANGED`)
- `CIRCULAR_EVIDENCE_CONFIRMATION_REQUIRED = false`

### human-smoke-003

- Pass 1: Drivers that participated in Alex Nerelli.
- Trigger: `PASS1_NO_MATCH`
- Top 3: Alex Lee; Alexine Serin; Alexander Derez
- Pass 2: Drivers that participated in Alex Nereli.
- Outcome: `NO_MATCH → NO_MATCH` (`UNCHANGED`)
- `CIRCULAR_EVIDENCE_CONFIRMATION_REQUIRED = false`

### human-smoke-005

- Pass 1: Rally aloops نے drivers.
- Trigger: `PASS1_CLARIFICATION_DISAGREES_WITH_ENTITY_SEARCH_TOP1`
- Top 3: Rally Alūksne 2026; Rallye National du Pays de Fayence 2025; McDonald & Munro Speyside Stages 2025
- Pass 2: Rally Alūksne drivers.
- Outcome: `WRONG_CLARIFICATION → CORRECT_CLARIFICATION` (`IMPROVED`)
- `CIRCULAR_EVIDENCE_CONFIRMATION_REQUIRED = true`

## Corpus coverage — unique audio

```json
{
  "recordings": 4,
  "speakers": {
    "speaker-anon-01": 4
  },
  "languages": {
    "en": 4
  },
  "entityTypes": {
    "CITY": 1,
    "PERSON": 1,
    "RALLY": 2
  },
  "entities": {
    "AMBIGUOUS:aluksne": 1,
    "Max Freeman": 1,
    "Rally Alūksne 2026": 2
  },
  "personRoles": {
    "ANY": 1,
    "NOT_APPLICABLE": 3
  },
  "canonicalLabelStatus": {
    "AMBIGUOUS_UNSCORABLE": 1,
    "SCORABLE": 3
  },
  "queryIntents": {
    "GET_RALLY_TOP_FINISHERS": 2,
    "SEARCH_DRIVER_RALLIES": 1,
    "SEARCH_RALLIES": 1
  },
  "audioConditions": {
    "status": "NOT_YET_LABELED",
    "unlabeled": 4
  }
}
```

## Collection milestones

| Milestone | Unique recordings | Speakers | Remaining | Reached |
|---|---:|---:|---:|---|
| 1 | 4/30 | 1/3 | 26 recordings, 2 speakers | false |
| 2 | 4/50 | 1/5 | 46 recordings, 4 speakers | false |
| 3 | 4/100 | 1/8 | 96 recordings, 7 speakers | false |

These are engineering collection milestones, not statistical proof thresholds.

## Permanent regression

`asim1.wav` remains `ES8A_ASIM1_DYNAMIC_TOP3_RECOVERY`: frozen RAW “Alex's” → `NO_MATCH`; dynamic “Alūksne Rally” → guarded `CORRECT_CLARIFICATION`.

## One-command workflow

```bash
flutter test test/eval/entity_search/human_voice_corpus_benchmark_test.dart --reporter expanded
```

The command validates every fixture, runs RAW and dynamic top-3, and regenerates this Markdown file plus the machine-readable JSON report.
