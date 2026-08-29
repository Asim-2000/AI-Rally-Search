# Learnings

## Model quality is not product quality

`gpt-5.6-luna` had stronger raw parsing, but `gemini-3.5-flash-lite` won on final system success, latency, and cost. Benchmark the whole application, not only the LLM.

## Deterministic recovery makes cheaper models viable

A model can be imperfect if downstream layers are explicit, safe, and observable.

## Clarification beats wrong confidence

Use this priority:

```text
correct confident > clarification > safe no-match > wrong confident
```

## Canonical identity must never belong to the LLM

LLMs may infer names, never DB IDs. Resolved canonical IDs should survive conversation turns instead of being reconstructed from display text.

## Clarification is part of query state

A candidate chip is not a new search. It resolves one ambiguous dimension in the existing pending query while preserving all other filters and referents.

## SearchPlan was the key architectural boundary

```text
SearchQuery → canonicalization → SearchPlan → repository
```

The repository should not need to understand natural language.

## Router logic must stay conservative

Residual-token recovery is useful but dangerous. Filler words such as `held`, `featuring`, and `competing` must not become entity mentions. Do not turn the router into a mini-NLP engine.

## Multi-entity intents need capability-aware routing

`SEARCH_VIDEO_ACTIONS` can legitimately contain RALLY, PERSON, STAGE, or UPLOADER. Residual text cannot safely default to one entity type.

## Exact canonical matches should beat fuzzy ambiguity

If input already exactly matches a canonical entity, fuzzy score-gap ambiguity should not reintroduce uncertainty.

## Hallucinations should be neutralized deterministically when possible

Flash-Lite sometimes invented season years. A grounding guard now checks whether temporal filters appear in raw text or valid conversation context before execution.

## Health and readiness are different

```text
/health = process alive
/ready  = dependencies/index ready
```

Background OpenEntity warmup improved startup behavior and operational clarity.

## Benchmark in phases

The useful workflow was:

```text
gold dataset
→ QA
→ smoke
→ calibration
→ evaluator audit
→ deterministic hardening
→ full benchmark
→ production validation
```

## Synthetic STT is useful but insufficient

Synthetic audio can compare provider plumbing, latency, and controlled errors, but final STT selection should eventually use more human speakers, accents, devices, and environments.

## WER is not enough

For domain speech, entity preservation matters more than generic transcription similarity. `Aluksne → Alaska` is much more damaging than dropping a filler word.

## Relational truth must be explicit

Different questions use different DB relationships:

- participation: `entry_list → sub_event → event`
- wins/results: `rally_results`
- driver video/actions: `video_metadata.entry_list_id → entry_list`

Using the wrong relational source creates semantic bugs.

## Capability gaps should not be disguised as model failures

“drivers that participated in Rally X” is a rally→participants relation, while the current architecture supports driver→rallies. That requires a new explicit intent/capability rather than forcing existing semantics.

## Freeze architecture during benchmark runs

Changing prompts, thresholds, router rules, or SearchPlan semantics during a benchmark invalidates comparability.

## Cached replay saves money and improves diagnosis

Once model outputs are recorded, downstream hardening can be tested without new paid calls.

## Trace the entire pipeline before patching

Many apparent “model bugs” were downstream:

- Max Freeman becoming rally clarification → routing bug
- clarification chip losing filters → pending-query state bug
- exact rally name becoming ambiguous → fuzzy precedence bug

Always inspect:

```text
raw text
→ SearchQuery
→ Router
→ entity resolution
→ SearchPlan
→ repository
```

## Most important lesson

```text
LLM = interpretation
Router/OpenEntity = canonicalization
SearchPlan = execution contract
Repository/DB = truth
```
