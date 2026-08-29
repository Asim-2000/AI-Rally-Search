# Human Voice Corpus Workflow

The voice benchmark architecture is frozen for data collection. Only `RAW_BASELINE` and `RAW_DYNAMIC_TOP3` are evaluated. Audio preprocessing is NoOp, static STT context is disabled, top 5/top 10 are excluded, and nothing in this workflow changes production routing.

## Add a recording

1. Place the original audio file under `test/eval/audio/human/`.
2. Add a fixture to `human_voice_smoke_manifest.json` using schema `ES8B_HUMAN_FIXTURE_V1`.
3. Supply every required field:
   - `fixtureId`, `speakerId`, `filePath`, `sha256`
   - `referenceTranscriptRaw`, `referenceTranscriptNormalized`, `language`
   - `expectedIntent`, `expectedEntityMention`, `expectedEntityType`
   - `expectedCanonicalId`, `expectedCanonicalName`, `expectedPersonRole`
   - `canonicalScorable`, plus `ambiguityReason` when false
   - optional `notes`, `audioCondition`, `expectedYear`, and `expectedEventId`
4. Keep the legacy aliases in the manifest identical until the older ES-7 reports are retired: `recordingId`, `audioFile`, `entityMention`, `canonicalEntityId`, `canonicalEntityName`, and `expectedIntents`.

Never infer reference labels from STT or Entity Search output. Establish canonical labels independently from live DB truth.

## Run everything

From the repository root:

```bash
flutter test test/eval/entity_search/human_voice_corpus_benchmark_test.dart --reporter expanded
```

This one command:

1. validates every fixture and fails without silently dropping invalid entries;
2. verifies live canonical IDs, role compatibility, and event/year constraints;
3. computes SHA-256 duplicate groups and selects unique-audio representatives;
4. runs unbiased RAW and targeted dynamic top-3 on original audio;
5. writes `human_voice_corpus_benchmark_report.json`;
6. writes `HUMAN_VOICE_CORPUS_BENCHMARK_REPORT.md` automatically.

Any newly introduced `WRONG_CONFIDENT` result is listed individually in both report data and blocks a safe recommendation.

## Collection priorities

Grow beyond Alūksne across RALLY, PERSON, STAGE, and UPLOADER. Include difficult international names, easy controls, confusable names, same-name identities, driver/co-driver roles, and different rally years.

Milestones are engineering collection targets, not statistical proof thresholds:

- Milestone 1: 30 unique recordings and 3 speakers
- Milestone 2: 50 unique recordings and 5 speakers
- Milestone 3: 100 unique recordings and 8 speakers

`asim1.wav` is permanent regression `ES8A_ASIM1_DYNAMIC_TOP3_RECOVERY` and must retain its authoritative labels and historical frozen outcomes.
