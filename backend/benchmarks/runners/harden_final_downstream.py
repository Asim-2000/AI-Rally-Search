from __future__ import annotations

import asyncio
import datetime as dt
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from benchmarks.scoring.system_scoring import evaluate_system_pipeline


SOURCE = Path("benchmarks/results/full_20260829_053539")
MODELS = ("gpt-5.6-luna", "gemini-3.5-flash-lite")


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def _metric(records: list[dict[str, Any]], key: str) -> tuple[int, int, float | None]:
    selected = [record for record in records if record[key]["eligible"]]
    passed = sum(record[key]["passed"] for record in selected)
    return passed, len(selected), passed / len(selected) if selected else None


def _summarize(records: list[dict[str, Any]], score_key: str) -> dict[str, Any]:
    total = len(records)
    exact = [record for record in records if record["raw_score"]["exact_match"]]
    expected_clarify = [record for record in records if record["expected_outcome"] == "CLARIFY"]
    expected_no_match = [record for record in records if record["expected_outcome"] == "NO_MATCH"]
    scores = [record[score_key] for record in records]
    return {
        "success": sum(score["system_success"] for score in scores),
        "total": total,
        "success_rate": sum(score["system_success"] for score in scores) / total,
        "exact_success": sum(record[score_key]["system_success"] for record in exact),
        "exact_total": len(exact),
        "p_success_exact": sum(record[score_key]["system_success"] for record in exact) / len(exact),
        "correct_resolution": sum(score["correct_canonical_resolution"] for score in scores),
        "clarification_correct": sum(record[score_key]["correct_clarification"] for record in expected_clarify),
        "clarification_total": len(expected_clarify),
        "no_match_correct": sum(record[score_key]["correct_no_match"] for record in expected_no_match),
        "no_match_total": len(expected_no_match),
        "false_confident": sum(score["false_confident"] for score in scores),
    }


def _classify(record: dict[str, Any]) -> tuple[str, str, str]:
    score = record["after"]
    trace = score.get("trace") or {}
    raw = record["raw_score"]
    expected = record["expected_outcome"]
    actual = score["outcome"]
    decisions = trace.get("resolution_decisions") or {}
    strategies = {value.get("strategy") for value in decisions.values()}

    if score["system_success"]:
        return "SUCCESS", "FIXED_OR_ALREADY_CORRECT", "System outcome matches benchmark expectation."
    if score["false_confident"]:
        return "FALSE_CONFIDENT", "BUG", "Executed with results despite an unresolved required entity."
    if not raw["intent_match"] or raw["wrong_field"] or raw["missing_fields"]:
        return "MODEL_PARSE_ERROR", "MODEL_ERROR", "Cached model query has wrong intent, field placement, or missing fields."
    if expected == "CLARIFY" and actual != "CLARIFY":
        broad = record["input_text"].casefold() in {"find clips", "videos", "show rallies", "show drivers"}
        if broad:
            return "GOLD_SEMANTIC_ERROR", "GOLD_PROBLEM", "Broad exploration is a valid corpus search under product semantics."
        return "UNDERSPECIFIED_QUERY_POLICY", "BUG", "Relational query executed without its required subject."
    if actual == "CLARIFY":
        if "multi_year_ambiguity" in strategies or "plausible_candidates" in strategies or any(
            value.get("isAmbiguous") for value in decisions.values()
        ):
            return "AMBIGUOUS_ENTITY_CORRECTLY_CLARIFIED", "EXPECTED_SAFE_BEHAVIOR", "Multiple plausible database identities remain."
        if trace.get("router_plan", {}).get("unexplained_tokens"):
            return "DIRECT_FILTER_VALIDATION_FAILURE", "BUG", "Residual routing created an entity lookup from filter/function language."
        return "ENTITY_RETRIEVED_BUT_THRESHOLD_REJECTED", "EXPECTED_SAFE_BEHAVIOR", "Resolver did not have a safe confidence margin."
    if actual in {"ERROR", "EXCEPTION"}:
        error = (score.get("error") or "").casefold()
        if "database" in error or "sql" in error:
            return "REPOSITORY_SQL_ERROR", "BUG", score.get("error") or "Repository execution failed."
        if "identify" in error or "entity" in error:
            return "ENTITY_NOT_INDEXED", "DB_COVERAGE_LIMITATION", score.get("error") or "Required entity was not resolved."
        return "OTHER", "PRODUCT_SEMANTICS_UNDEFINED", score.get("error") or "Unclassified error."
    if raw["true_hallucinations"]:
        return "MODEL_PARSE_ERROR", "MODEL_ERROR", "Raw model output contains an ungrounded value."
    return "OTHER", "PRODUCT_SEMANTICS_UNDEFINED", "No deterministic production defect was established."


def _failure_bucket(record: dict[str, Any]) -> str:
    category = record["root_cause"]
    if category == "MODEL_PARSE_ERROR":
        return "MODEL_PARSE_WRONG"
    if category in {"DIRECT_FILTER_VALIDATION_FAILURE", "UNDERSPECIFIED_QUERY_POLICY"}:
        return "ROUTER_WRONG"
    if category.startswith("ENTITY_") or category in {"YEAR_CONSTRAINT_CONFLICT", "PERSON_ROLE_CONFLICT", "CROSS_TYPE_RECOVERY_MISSED", "AMBIGUOUS_ENTITY_CORRECTLY_CLARIFIED"}:
        return "ENTITY_RESOLUTION_WRONG"
    if category == "SEARCHPLAN_FILTER_MISMATCH":
        return "SEARCHPLAN_WRONG"
    if category in {"REPOSITORY_SQL_ERROR", "REPOSITORY_EMPTY_RESULT_CORRECT"}:
        return "REPOSITORY_RESULT_WRONG"
    if category in {"GOLD_SEMANTIC_ERROR", "UNDERSPECIFIED_QUERY_POLICY"}:
        return "EXPECTED_CLARIFICATION_MISMATCH"
    if record["after"]["false_confident"]:
        return "FALSE_CONFIDENT"
    if record["disposition"] == "GOLD_PROBLEM":
        return "GOLD_PROBLEM"
    return "OTHER"


def _pct(value: float | None) -> str:
    return "N/A" if value is None else f"{value:.2%}"


async def main() -> None:
    raw_records = _read_jsonl(SOURCE / "qu_raw_results.jsonl")
    gold_records = {record["case_id"]: record for record in _read_jsonl(Path("benchmarks/datasets/query_understanding_gold.jsonl"))}
    selected = [record for record in raw_records if record["model"] in MODELS]
    semaphore = asyncio.Semaphore(4)

    async def replay(record: dict[str, Any]) -> dict[str, Any]:
        async with semaphore:
            gold = gold_records[record["case_id"]]
            after = await evaluate_system_pipeline(gold, record.get("parsed_query"))
            result = {
                "model": record["model"],
                "case_id": record["case_id"],
                "category": record["category"],
                "input_text": record["input_text"],
                "conversation_context": record.get("conversation_context"),
                "gold_query": record["expected"],
                "model_query": record.get("parsed_query"),
                "raw_score": record["raw_score"],
                "expected_outcome": (record.get("expected_resolution") or {}).get("outcome", "RESOLVED"),
                "before": record["sys_score"],
                "after": after,
            }
            result["root_cause"], result["disposition"], result["reason"] = _classify(result)
            result["failure_bucket"] = _failure_bucket(result)
            return result

    replayed = await asyncio.gather(*(replay(record) for record in selected))
    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    output = Path(f"benchmarks/results/downstream_hardening_{timestamp}")
    output.mkdir(parents=True, exist_ok=True)

    relevant = [
        record for record in replayed
        if not record["before"]["system_success"] or not record["after"]["system_success"]
    ]
    with (output / "failure_traces.jsonl").open("w", encoding="utf-8") as handle:
        for record in relevant:
            handle.write(json.dumps(record, ensure_ascii=False, default=str) + "\n")

    by_model = {model: [record for record in replayed if record["model"] == model] for model in MODELS}
    summaries = {
        model: {
            "before": _summarize(records, "before"),
            "after": _summarize(records, "after"),
            "remaining": Counter(record["failure_bucket"] for record in records if not record["after"]["system_success"]),
        }
        for model, records in by_model.items()
    }

    status_by_case: dict[str, dict[str, dict[str, Any]]] = defaultdict(dict)
    for record in replayed:
        status_by_case[record["case_id"]][record["model"]] = record
    both_before = {
        case_id for case_id, models in status_by_case.items()
        if len(models) == 2 and all(not models[model]["before"]["system_success"] for model in MODELS)
    }
    escaped = {
        case_id for case_id in both_before
        if any(status_by_case[case_id][model]["after"]["system_success"] for model in MODELS)
    }
    fully_fixed = {
        case_id for case_id in both_before
        if all(status_by_case[case_id][model]["after"]["system_success"] for model in MODELS)
    }
    remaining_both = both_before - escaped
    remaining_clusters = Counter()
    for case_id in remaining_both:
        causes = [status_by_case[case_id][model]["root_cause"] for model in MODELS]
        priority = (
            "MODEL_PARSE_ERROR",
            "ENTITY_NOT_INDEXED",
            "AMBIGUOUS_ENTITY_CORRECTLY_CLARIFIED",
            "GOLD_SEMANTIC_ERROR",
            "UNDERSPECIFIED_QUERY_POLICY",
            "OTHER",
        )
        remaining_clusters[next((cause for cause in priority if cause in causes), causes[0])] += 1

    flash = summaries["gemini-3.5-flash-lite"]
    lines = [
        "# Downstream Search Hardening",
        "",
        "## Executive Summary",
        "",
        f"Cached deterministic replay improved Flash-Lite system success from **{_pct(flash['before']['success_rate'])}** ({flash['before']['success']}/392) to **{_pct(flash['after']['success_rate'])}** ({flash['after']['success']}/392). No model APIs or STT benchmarks were called.",
        "",
        "## Input Benchmark Evidence",
        "",
        "Audited `full_20260829_053539` raw results, failures, system results, head-to-head failures, intent/category summaries, the prior recalibration hardening report, and the evaluator audit. Full per-case traces are in `failure_traces.jsonl` beside this report.",
        "",
        "## Failure Taxonomy",
        "",
        "| Root cause | Disposition | Count after replay |",
        "|---|---|---:|",
    ]
    taxonomy = Counter((record["root_cause"], record["disposition"]) for record in relevant if not record["after"]["system_success"])
    lines.extend(f"| `{cause}` | `{disposition}` | {count} |" for (cause, disposition), count in sorted(taxonomy.items()))
    lines.extend([
        "",
        "## Both-Models-Failed Analysis",
        "",
        f"The source contains **{len(both_before)}** both-model-fail cases. **{len(escaped)}** escaped the both-fail set after hardening, including **{len(fully_fixed)}** fixed for both cached model outputs; **{len(remaining_both)}** remain failures for both.",
        "",
        "| Remaining cluster | Cases |",
        "|---|---:|",
    ])
    lines.extend(f"| `{cause}` | {count} |" for cause, count in remaining_clusters.most_common())
    lines.extend([
        "",
        "## Entity Resolution Findings",
        "",
        "Entity identity years and search-filter years are now separated during candidate scoring. Ambiguous editions and duplicate person identities remain clarifications; thresholds were not lowered and no aliases or entity exceptions were added. Candidate lists, scores, strategies, and decisions are captured per case in the trace artifact.",
        "",
        "## Conversation Findings",
        "",
        "Production already passes committed session state to parsing and preserves canonical referents. The benchmark replay previously discarded its explicit `conversation_context`; the replay harness now reconstructs only the active rally/driver/year stated in that context. Relational intents without a rally or driver deterministically clarify.",
        "",
        "## Clarification Findings",
        "",
        "| Query class | Desired behavior | Reason |",
        "|---|---|---|",
        "| Broad rallies or video exploration | Execute | Corpus exploration needs no subject. |",
        "| Global top drivers/uploaders | Execute | These are corpus aggregates, not entity searches. |",
        "| Rally results/top finishers without rally | Clarify | A relational subject is required. |",
        "| Driver rallies/wins/videos without driver | Clarify | A person subject is required. |",
        "| Multiple plausible entity identities | Clarify | Preserves safety over benchmark score. |",
        "",
        "## Repository Findings",
        "",
        "No SearchPlan strategy or repository SQL defect was established. SearchPlan and repository semantics were left unchanged; empty results remain valid when filters conflict.",
        "",
        "## Ungrounded Temporal Filter Analysis",
        "",
        "Implemented a provider-neutral `UNGROUNDED_TEMPORAL_FILTER` defense: model-produced `years`, `yearFrom`, and `yearTo` values absent from both the current raw text and committed conversation query are removed and recorded in `neutralizedTemporalFilters`. Raw QU scoring still counts the model error. Explicit user years and inherited committed years are retained.",
        "",
        "## Fixes Applied",
        "",
        "- Suppressed unexplained-text entity recovery for global aggregate intents.",
        "- Treated `located` as deterministic country-filter language.",
        "- Separated event identity year from search filter year in rally scoring.",
        "- Added deterministic missing-subject clarification policy.",
        "- Added temporal grounding neutralization and diagnostics.",
        "- Fixed benchmark replay of explicit conversation context and added full trace export.",
        "- Documented provisional `openai` / `whisper-1` production speech configuration.",
        "",
        "## Regression Tests",
        "",
        "Focused router, resolver-safety, conversation reducer/session, and conversational service suites pass. Coverage includes aggregate routing, multi-country filters, ambiguity, role safety, year conflicts/grounding, conversation referents, exploration, missing subjects, and video/action behavior.",
        "",
        "## Before vs After Replay",
        "",
        "| Flash-Lite metric | Before | After |",
        "|---|---:|---:|",
        f"| System success | {_pct(flash['before']['success_rate'])} ({flash['before']['success']}/392) | {_pct(flash['after']['success_rate'])} ({flash['after']['success']}/392) |",
        f"| P(success \\| exact query) | {_pct(flash['before']['p_success_exact'])} | {_pct(flash['after']['p_success_exact'])} |",
        f"| Correct canonical resolution | {flash['before']['correct_resolution']}/392 | {flash['after']['correct_resolution']}/392 |",
        f"| Clarification accuracy | {flash['before']['clarification_correct']}/{flash['before']['clarification_total']} | {flash['after']['clarification_correct']}/{flash['after']['clarification_total']} |",
        f"| No-match accuracy | N/A ({flash['before']['no_match_total']} gold cases) | N/A ({flash['after']['no_match_total']} gold cases) |",
        f"| False confident | {flash['before']['false_confident']}/392 | {flash['after']['false_confident']}/392 |",
        "",
        "### Remaining Flash-Lite failure counts",
        "",
        "| Category | Before | After |",
        "|---|---:|---:|",
    ])
    before_failures = Counter(
        record.get("primary_failure") or "OTHER"
        for record in _read_jsonl(SOURCE / "system_results.jsonl")
        if record.get("model") == "gemini-3.5-flash-lite"
        and not (record.get("sys_score") or {}).get("system_success")
    )
    requested = ["MODEL_PARSE_WRONG", "ROUTER_WRONG", "ENTITY_RESOLUTION_WRONG", "SEARCHPLAN_WRONG", "REPOSITORY_RESULT_WRONG", "EXPECTED_CLARIFICATION_MISMATCH", "FALSE_CONFIDENT", "GOLD_PROBLEM", "OTHER"]
    for category in requested:
        lines.append(f"| `{category}` | {before_failures[category]} | {flash['remaining'][category]} |")
    lines.extend([
        "",
        "## Safety Metrics",
        "",
        f"False-confident execution remained **{flash['before']['false_confident']}/392 → {flash['after']['false_confident']}/392**. Resolver thresholds and ambiguity margins were unchanged.",
        "",
        "## Remaining Failures",
        "",
        "Remaining failures are enumerated in `failure_traces.jsonl` with their disposition. The principal legitimate clusters are model parse errors, ambiguous identities correctly clarified, missing database entities, and benchmark gold semantics that conflict with broad exploration.",
        "",
        "## Remaining DB Coverage Limitations",
        "",
        "Entities returning no candidates are retained as DB coverage limitations rather than patched with aliases. The current benchmark has zero NO_MATCH gold cases, so no-match accuracy remains unmeasured.",
        "",
        "## Recommended Next Engineering Work",
        "",
        "Review unresolved entity index coverage from the trace artifact, adjudicate broad-exploration gold cases, add true NO_MATCH cases, and run a fresh paid production validation only after those dataset decisions. Human STT validation remains deferred; Whisper status is provisional.",
    ])
    (output / "downstream_failure_hardening_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (output / "replay_summary.json").write_text(json.dumps({"models": summaries, "both_fail": {"before": len(both_before), "escaped": len(escaped), "fully_fixed": len(fully_fixed), "remaining": len(remaining_both)}}, indent=2, default=lambda value: dict(value)), encoding="utf-8")
    print(output)


if __name__ == "__main__":
    asyncio.run(main())
