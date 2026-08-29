from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from app.domain.search_intent import SearchIntent
from app.domain.search_query import SearchQuery

VALID_INTENTS = {i.value for i in SearchIntent}
VALID_CATEGORIES = {
    "simple_filter",
    "multi_filter",
    "entity_heavy",
    "noisy/phonetic",
    "multi_value",
    "ambiguity/clarification",
    "conversation/referents",
    "video/action",
    "realistic/adversarial",
    "immutable_regression",
}

IMMUTABLE_REGRESSION_PHRASES = {
    "aluqsne",
    "Rally aluqsne",
    "aluksnay",
    "donegl",
    "max freemn",
    "Rallies in Ireland",
    "Rallies in 2025",
}


def validate_dataset(gold_path: Path) -> dict[str, Any]:
    if not gold_path.exists():
        raise FileNotFoundError(f"Gold dataset not found at {gold_path}")

    raw_bytes = gold_path.read_bytes()
    dataset_hash = hashlib.sha256(raw_bytes).hexdigest()

    lines = [line.strip() for line in raw_bytes.decode("utf-8").splitlines() if line.strip()]
    total_cases = len(lines)

    case_ids = set()
    seen_inputs = set()
    intent_counts: dict[str, int] = {}
    category_counts: dict[str, int] = {}
    source_counts: dict[str, int] = {}
    confidence_counts: dict[str, int] = {}
    db_validated_count = 0

    errors: list[str] = []
    warnings: list[str] = []
    immutable_found = set()

    for idx, line in enumerate(lines, 1):
        try:
            case = json.loads(line)
        except Exception as exc:
            errors.append(f"Line {idx}: JSON parse error: {exc}")
            continue

        cid = case.get("case_id")
        if not cid:
            errors.append(f"Line {idx}: missing case_id")
        elif cid in case_ids:
            errors.append(f"Line {idx}: duplicate case_id '{cid}'")
        else:
            case_ids.add(cid)

        inp = case.get("input_text", "").strip()
        if not inp:
            errors.append(f"Case {cid}: empty input_text")
        
        # Check immutable regression phrases
        if inp in IMMUTABLE_REGRESSION_PHRASES:
            immutable_found.add(inp)

        # Duplicate inputs (allow only if conversational or explicit category)
        cat = case.get("category", "")
        if inp in seen_inputs and cat not in ("conversation/referents", "ambiguity/clarification"):
            warnings.append(f"Case {cid}: non-conversational duplicate input_text '{inp}'")
        seen_inputs.add(inp)

        # Category check
        if cat not in VALID_CATEGORIES:
            errors.append(f"Case {cid}: invalid category '{cat}'")
        category_counts[cat] = category_counts.get(cat, 0) + 1

        # Expected query schema validation
        expected = case.get("expected")
        if not expected or not isinstance(expected, dict):
            errors.append(f"Case {cid}: missing or non-dict expected field")
            continue

        try:
            validated_query = SearchQuery.model_validate(expected)
        except Exception as exc:
            errors.append(f"Case {cid}: SearchQuery validation failure: {exc}")
            continue

        intent_val = validated_query.intent.value if validated_query.intent else None
        if not intent_val or intent_val not in VALID_INTENTS:
            errors.append(f"Case {cid}: invalid intent '{intent_val}'")
        else:
            intent_counts[intent_val] = intent_counts.get(intent_val, 0) + 1

        # Year validation
        if validated_query.year_from is not None and validated_query.year_to is not None:
            if validated_query.year_from > validated_query.year_to:
                errors.append(f"Case {cid}: yearFrom ({validated_query.year_from}) > yearTo ({validated_query.year_to})")

        # Metadata validation
        meta = case.get("metadata") or {}
        src = meta.get("generation_source", "unknown")
        conf = meta.get("gold_confidence", "unknown")
        db_val = bool(meta.get("validated_against_db", False))

        source_counts[src] = source_counts.get(src, 0) + 1
        confidence_counts[conf] = confidence_counts.get(conf, 0) + 1
        if db_val:
            db_validated_count += 1

        # Expected resolution check
        exp_res = case.get("expected_resolution") or {}
        outcome = exp_res.get("outcome")
        if outcome not in ("RESOLVED", "CLARIFY", "NO_MATCH"):
            errors.append(f"Case {cid}: invalid expected_resolution outcome '{outcome}'")

    missing_immutables = IMMUTABLE_REGRESSION_PHRASES - immutable_found
    if missing_immutables:
        errors.append(f"Missing immutable regression phrases in dataset: {missing_immutables}")

    return {
        "valid": len(errors) == 0,
        "total_cases": total_cases,
        "dataset_hash": dataset_hash,
        "intent_counts": intent_counts,
        "category_counts": category_counts,
        "source_counts": source_counts,
        "confidence_counts": confidence_counts,
        "db_validated_count": db_validated_count,
        "errors": errors,
        "warnings": warnings,
        "immutable_count": len(immutable_found),
    }


def generate_qa_report(report_data: dict[str, Any], output_path: Path) -> str:
    lines = [
        "# Dataset QA Report",
        "",
        f"- **Dataset Path**: `benchmarks/datasets/query_understanding_gold.jsonl`",
        f"- **Dataset SHA-256 Hash**: `{report_data['dataset_hash']}`",
        f"- **Total Cases**: {report_data['total_cases']}",
        f"- **Validation Status**: `{'PASS' if report_data['valid'] else 'FAIL'}`",
        f"- **DB-Validated Cases**: {report_data['db_validated_count']}/{report_data['total_cases']}",
        f"- **Immutable Regression Cases Found**: {report_data['immutable_count']}/{len(IMMUTABLE_REGRESSION_PHRASES)}",
        "",
        "## Distribution by Canonical Intent",
        "",
        "| Search Intent | Case Count |",
        "| :--- | :---: |",
    ]
    for intent in sorted(VALID_INTENTS):
        cnt = report_data["intent_counts"].get(intent, 0)
        lines.append(f"| `{intent}` | {cnt} |")

    lines.extend([
        "",
        "## Distribution by Category",
        "",
        "| Category | Case Count |",
        "| :--- | :---: |",
    ])
    for cat in sorted(report_data["category_counts"]):
        cnt = report_data["category_counts"][cat]
        lines.append(f"| `{cat}` | {cnt} |")

    lines.extend([
        "",
        "## Generation Source & Confidence",
        "",
        f"- **Sources**: {report_data['source_counts']}",
        f"- **Confidence Breakdown**: {report_data['confidence_counts']}",
        "",
        "## Errors & Warnings",
        "",
        f"- **Errors ({len(report_data['errors'])})**:",
    ])
    if report_data["errors"]:
        for err in report_data["errors"][:20]:
            lines.append(f"  - ❌ {err}")
    else:
        lines.append("  - None")

    lines.append(f"- **Warnings ({len(report_data['warnings'])})**:")
    if report_data["warnings"]:
        for w in report_data["warnings"][:20]:
            lines.append(f"  - ⚠️ {w}")
    else:
        lines.append("  - None")

    content = "\n".join(lines) + "\n"
    output_path.write_text(content, encoding="utf-8")
    return content


if __name__ == "__main__":
    dataset_file = Path(__file__).parent / "query_understanding_gold.jsonl"
    report_file = Path(__file__).parent / "dataset_qa_report.md"
    res = validate_dataset(dataset_file)
    print(generate_qa_report(res, report_file))
