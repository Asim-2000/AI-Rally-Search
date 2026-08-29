import hashlib
import json
import math
import statistics
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Awaitable, Callable

from ..domain.search_query import SearchQuery
from .models import QueryUnderstandingResult
from .service import QueryUnderstandingService

CanonicalHook = Callable[[SearchQuery, dict[str, Any]], Awaitable[dict[str, Any]]]
DatabaseHook = Callable[[SearchQuery, dict[str, Any]], Awaitable[dict[str, Any]]]
LIST_FIELDS = ("rallyNames", "eventNames", "countries", "cities", "stageNames", "stageNumbers", "driverNames", "actionTypes", "years", "uploaders")


@dataclass(frozen=True)
class Pricing:
    input_per_million: float | None = None
    output_per_million: float | None = None
    cached_per_million: float | None = None
    reasoning_per_million: float | None = None

    def cost(self, usage: dict[str, Any]) -> float | None:
        if self.input_per_million is None or self.output_per_million is None:
            return None
        return ((usage.get("input_tokens") or 0) * self.input_per_million + (usage.get("output_tokens") or 0) * self.output_per_million + (usage.get("cached_tokens") or 0) * (self.cached_per_million or 0) + (usage.get("reasoning_tokens") or 0) * (self.reasoning_per_million or 0)) / 1_000_000


class BenchmarkRunner:
    def __init__(self, service: QueryUnderstandingService, *, canonical_hook: CanonicalHook | None = None, database_hook: DatabaseHook | None = None, pricing: Pricing | None = None, run_version: str = "BASELINE_V1"):
        self.service, self.canonical_hook, self.database_hook, self.pricing, self.run_version = service, canonical_hook, database_hook, pricing, run_version

    async def run(self, fixture_path: Path) -> dict[str, Any]:
        fixture_bytes = fixture_path.read_bytes()
        fixture = json.loads(fixture_bytes)
        records = []
        for case in fixture["cases"]:
            result = await self.service.parse(case["input"], language=case.get("language"))
            records.append(await self._evaluate(case, result))
        return {"runVersion": self.run_version, "fixture": {"path": str(fixture_path), "version": fixture.get("fixtureVersion"), "count": len(fixture["cases"]), "sha256": hashlib.sha256(fixture_bytes).hexdigest()}, "provider": self.service.provider.config.provider, "model": self.service.provider.config.model, "configuration": _safe_config(self.service.provider.config), "versions": {"prompt": records[0]["promptVersion"] if records else None, "schema": records[0]["schemaVersion"] if records else None, "fewShot": records[0]["fewShotVersion"] if records else None}, "summary": summarize(records), "records": records}

    async def _evaluate(self, case: dict[str, Any], result: QueryUnderstandingResult) -> dict[str, Any]:
        expected = case["expected"]
        actual = result.query.model_dump(by_alias=True, mode="json", exclude_none=True) if result.query else None
        failures: list[str] = []
        metrics = _parser_metrics(expected, actual)
        if result.failure_kind:
            failures.append(result.failure_kind.value)
        elif not metrics["intentMatch"]:
            failures.append("WRONG_INTENT")
        if actual:
            failures.extend(_field_failures(expected, actual))
        canonical = await self.canonical_hook(result.query, case) if result.query and self.canonical_hook else None
        if canonical and canonical.get("outcome") == "wrong_confident": failures.append("ENTITY_RESOLUTION_FAILURE")
        database = await self.database_hook(result.query, case) if result.query and self.database_hook and case.get("expectedDb") else None
        if database and not database.get("exactResultSetMatch", False): failures.append("DATABASE_RESULT_MISMATCH")
        usage = result.usage.model_dump()
        return {"caseId": case["caseId"], "input": case["input"], "language": case.get("language"), "category": case.get("category"), "tags": case.get("tags", []), "expected": expected, "rawResponse": result.raw_response, "parsedSearchQuery": actual, "validation": {"succeeded": result.succeeded, "failureKind": result.failure_kind, "error": result.error}, "parserMetrics": metrics, "canonicalResolution": canonical, "databaseResult": database, "latencyMs": {"provider": result.provider_latency_ms, "validation": result.validation_latency_ms, "entitySearch": canonical.get("latencyMs") if canonical else None, "database": database.get("latencyMs") if database else None, "total": result.total_latency_ms + (canonical.get("latencyMs", 0) if canonical else 0) + (database.get("latencyMs", 0) if database else 0)}, "usage": usage, "estimatedCost": self.pricing.cost(usage) if self.pricing else None, "attempts": result.attempts, "providerRetries": result.provider_retries, "schemaRetries": result.schema_retries, "failureCategories": sorted(set(failures)) or [], "promptVersion": result.prompt_version, "schemaVersion": result.schema_version, "fewShotVersion": result.few_shot_version}


def _parser_metrics(expected: dict, actual: dict | None) -> dict[str, Any]:
    if actual is None:
        return {"intentMatch": False, "exactExpectedFieldsMatch": False, "fieldCounts": {"tp": 0, "fp": 0, "fn": sum(len(v) if isinstance(v, list) else 1 for k, v in expected.items() if k != "intent")}}
    tp = fp = fn = 0
    for field in LIST_FIELDS:
        if field not in expected: continue
        e, a = {_key(v) for v in expected[field]}, {_key(v) for v in actual.get(field, [])}
        tp += len(e & a); fp += len(a - e); fn += len(e - a)
    scalar_fields = [k for k in expected if k not in LIST_FIELDS and k != "intent"]
    for field in scalar_fields:
        if actual.get(field) == expected[field]: tp += 1
        else: fp += int(actual.get(field) is not None); fn += 1
    expected_fields_match = all(_equal(expected[k], actual.get(k)) for k in expected if k != "intent")
    return {"intentMatch": actual.get("intent") == expected.get("intent"), "exactExpectedFieldsMatch": expected_fields_match, "fieldCounts": {"tp": tp, "fp": fp, "fn": fn}}


def _field_failures(expected: dict, actual: dict) -> list[str]:
    failures = []
    mapping = {"personRole": "WRONG_PERSON_ROLE", "years": "WRONG_YEAR", "yearFrom": "WRONG_RANGE", "yearTo": "WRONG_RANGE"}
    for field, kind in mapping.items():
        if field in expected and not _equal(expected[field], actual.get(field)): failures.append(kind)
    for field in LIST_FIELDS:
        if field not in expected: continue
        e, a = {_key(v) for v in expected[field]}, {_key(v) for v in actual.get(field, [])}
        if e - a: failures.append("MISSING_ENTITY" if field in ("driverNames", "rallyNames", "eventNames", "stageNames") else "MULTIVALUE_LOSS")
        if a - e: failures.append("EXTRA_ENTITY" if field in ("driverNames", "rallyNames", "eventNames", "stageNames") else "HALLUCINATED_FILTER")
    return failures


def summarize(records: list[dict]) -> dict[str, Any]:
    n = len(records) or 1
    tp = sum(r["parserMetrics"]["fieldCounts"]["tp"] for r in records); fp = sum(r["parserMetrics"]["fieldCounts"]["fp"] for r in records); fn = sum(r["parserMetrics"]["fieldCounts"]["fn"] for r in records)
    precision = tp / (tp + fp) if tp + fp else 1.0; recall = tp / (tp + fn) if tp + fn else 1.0
    latencies = [r["latencyMs"]["total"] for r in records]
    canonical = Counter(r["canonicalResolution"].get("outcome") for r in records if r["canonicalResolution"])
    db = [r for r in records if r["databaseResult"]]
    costs = [r["estimatedCost"] for r in records if r["estimatedCost"] is not None]
    return {"cases": len(records), "searchQueryAccuracy": sum(r["parserMetrics"]["intentMatch"] and r["parserMetrics"]["exactExpectedFieldsMatch"] for r in records) / n, "intentAccuracy": sum(r["parserMetrics"]["intentMatch"] for r in records) / n, "fieldPrecision": precision, "fieldRecall": recall, "fieldF1": 2 * precision * recall / (precision + recall) if precision + recall else 0, "schemaSuccessRate": sum(r["validation"]["succeeded"] for r in records) / n, "hallucinatedFilterRate": sum("HALLUCINATED_FILTER" in r["failureCategories"] or "EXTRA_ENTITY" in r["failureCategories"] for r in records) / n, "canonicalOutcomes": dict(canonical), "endToEndExactRate": sum(r["databaseResult"].get("exactResultSetMatch", False) for r in db) / len(db) if db else None, "latencyMs": _latency(latencies), "totalRetries": sum(r["providerRetries"] + r["schemaRetries"] for r in records), "failureCategories": dict(Counter(x for r in records for x in r["failureCategories"])), "estimatedCostPerQuery": statistics.fmean(costs) if costs else None, "estimatedCompleteBenchmarkCost": sum(costs) if costs else None}


def markdown_report(report: dict[str, Any]) -> str:
    s, f = report["summary"], report["fixture"]
    rows = ["# PY-3 Query Understanding BASELINE_V1", "", f"- Fixture: `{f['version']}` ({f['count']} cases, SHA-256 `{f['sha256']}`)", f"- Provider/model: `{report['provider']}` / `{report['model']}`", f"- Prompt/schema/few-shot: `{report['versions']['prompt']}` / `{report['versions']['schema']}` / `{report['versions']['fewShot']}`", "", "| Metric | Value |", "|---|---:|", f"| SearchQuery accuracy | {s['searchQueryAccuracy']:.2%} |", f"| Intent accuracy | {s['intentAccuracy']:.2%} |", f"| Field precision / recall / F1 | {s['fieldPrecision']:.2%} / {s['fieldRecall']:.2%} / {s['fieldF1']:.2%} |", f"| Schema success | {s['schemaSuccessRate']:.2%} |", f"| Hallucinated-filter rate | {s['hallucinatedFilterRate']:.2%} |", f"| End-to-end exact | {_pct(s['endToEndExactRate'])} |", f"| Latency avg / p50 / p95 / max (ms) | {s['latencyMs']['avg']:.1f} / {s['latencyMs']['p50']:.1f} / {s['latencyMs']['p95']:.1f} / {s['latencyMs']['max']:.1f} |", f"| Retries | {s['totalRetries']} |", f"| Cost/query | {s['estimatedCostPerQuery'] if s['estimatedCostPerQuery'] is not None else 'not configured'} |", "", "## Failure categories", ""]
    rows.extend(f"- {k}: {v}" for k, v in sorted(s["failureCategories"].items()))
    if not s["failureCategories"]: rows.append("- None")
    return "\n".join(rows) + "\n"


def _key(v: Any) -> str: return str(v).strip().casefold()
def _equal(a: Any, b: Any) -> bool: return {_key(v) for v in a} == {_key(v) for v in (b or [])} if isinstance(a, list) else a == b
def _pct(v: float | None) -> str: return "not run" if v is None else f"{v:.2%}"
def _latency(v: list[float]) -> dict: 
    values = sorted(v) or [0.0]
    def p(q): return values[math.ceil(q * len(values)) - 1]
    return {"avg": statistics.fmean(values), "p50": p(.5), "p95": p(.95), "max": max(values)}
def _safe_config(c) -> dict: return {"provider": c.provider, "model": c.model, "temperature": c.temperature, "maxTokens": c.max_tokens, "timeoutSeconds": c.timeout_seconds, "maxRetries": c.max_retries, "structuredOutput": c.structured_output, "seed": c.seed, "reasoning": c.reasoning, "parameters": c.parameters}
