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

## Lessons from the Python cutover + accuracy-hardening cycle

1. Conversation correctness cannot depend entirely on the LLM re-emitting prior context; deterministic protections are needed as a net.
2. Deterministic downstream recovery is most valuable when it restores facts explicitly grounded in the raw text or in trusted canonical context — never invented.
3. Recovery must not invent semantic information; only literal, grounded values may be restored.
4. Canonical IDs should persist across follow-ups so identity is stable turn to turn.
5. Fuzzy re-resolution of an already-resolved identity creates avoidable drift and re-clarification risk.
6. Strong, grounded intent cues can act as a conservative safety net when the model's intent is incompatible with the explicit request — scoped narrowly so broad searches are untouched.
7. Valid ambiguity should beat cross-type recovery. But the rule must be graded on match *strength*: a blanket "any ambiguous rally blocks person recovery" also blocks correct recoveries when the rally match is spurious/low-confidence. The post-hardening benchmark showed exactly this — 2 correct person recoveries became safe clarifications. **This was refined**: recovery now gates on whether any original-type candidate clears the confidence threshold (genuine ambiguity → clarify) versus all being weak noise (→ allow a confident cross-type recovery). Validated at 312/392, 0 false-confident, 0 new regressions — without lowering any threshold.
8. Safe clarification is better than wrong-confident substitution — and a lenient evaluator can score a wrong-entity execution as "success," hiding a real safety defect that a stricter rule then "regresses." Read the case traces, not just the aggregate.
9. Zero-result is better than silently changing entity or intent.
10. Cached model-output replay is the correct experiment for downstream-only changes; an A/B through the identical frozen evaluator isolates the pipeline's effect from model noise.
11. Raw model accuracy and final system accuracy are different metrics and must be reported separately; the model can be frozen while system success moves.
12. Removing the legacy production search path removes a dual-source-of-truth and a class of semantic drift; retaining it only as a test seam keeps coverage without runtime risk.
13. Benchmark hardening must preserve historical model results rather than rewriting them — "same frozen outputs, newer pipeline changed system success from X to Y," never "the model improved."
14. Single-turn benchmarks barely exercise conversation features; validate ACC-style conversation fixes with a dedicated multi-turn benchmark and a small live run, not only the frozen single-turn set.
15. A binary `is_ambiguous` flag is too coarse for cross-type recovery decisions: **weak retrieval ambiguity ≠ strong semantic ambiguity.** A phrase can be flagged "ambiguous" simply because fuzzy matching returned several low-scoring, unrelated candidates. Decide using the *strength* of the original candidate evidence (does anything clear the confidence threshold?) before letting ambiguity block a recovery.
16. Aggregate system-success % can reward semantically wrong executions when the evaluator is too coarse — e.g. a "Mayo …" rally phrase resolving to the driver "Simon May" was scored as success. Therefore: inspect case-level diffs, never optimize solely for the headline score, and treat false-confident safety and semantic correctness as higher priorities than recovering a headline number. A metric drop that removes wrong-entity executions is an improvement, not a regression.

## Offline search

17. **Separate the two offline axes or the numbers lie.** "Data/execution capability" (can local data answer this intent?) and "query-understanding capability" (can the deterministic parser interpret this phrasing?) are independent. Reporting one blended number hides that execution is 7/9 fully local while the parser is intentionally narrower than Gemini. Measure and report them separately (execution parity vs `OFFLINE_COVERAGE_RATE`).
18. **A grounding guard beats endless stop-word lists.** The offline parser's spurious clarifications on junk text ("explain the offside rule…") were killed not by enumerating bad words but by a principled rule: only clarify when the *top* ambiguous candidate itself clears the confidence threshold; a merely-plausible top (<0.75) is treated as ungrounded → decline or fall back to filters. This moved intent/entity/safe-decline accuracy to 100% with wrong-confident still 0, without lowering any threshold.
19. **Execution parity needs a real oracle, not a re-derivation.** Comparing the offline SQLite executor against results captured from the live online repository (SearchPlanBuilder + SearchRepository over MySQL) caught real semantic issues that comparing offline-against-offline never would. Pin resolved queries (concrete ids/filters) so parser noise doesn't contaminate the execution check.
20. **Atomic import via a single transaction is the whole game for offline caching.** Staging tables + count verification + promotion inside one SQLite transaction gives "a half-written snapshot never becomes live" for free: any failure rolls back and the previous valid snapshot survives, including an app crash mid-write.
21. **Precomputed global aggregates must decline filtered queries.** `driver_wins`/`uploader_stats` are shipped as global leaderboards; answering a country-filtered "top drivers in Ireland" from a global aggregate is a wrong-scope confident answer. Declining (unsupported) is the correct, safe behaviour offline.
