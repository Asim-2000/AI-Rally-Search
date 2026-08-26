# LLM Query Parser Evaluation Report

**Provider:** `OPENAI` | **Model:** `gpt-5.6-luna` | **Evaluated At:** `2026-08-26T23:09:45.824565`

## Executive Summary

| Metric | Score | Target | Status |
|---|---|---|---|
| **Intent Accuracy** | 99.4% | ≥ 95.0% | ✅ PASS |
| **Filter Precision** | 99.1% | ≥ 90.0% | ✅ PASS |
| **Filter Recall** | 99.7% | ≥ 90.0% | ✅ PASS |
| **Filter F1 Score** | 99.4% | ≥ 90.0% | ✅ PASS |
| **Exact Match Rate** | 97.7% | ≥ 85.0% | ✅ PASS |
| **Compound Completeness** | 99.1% | ≥ 85.0% | ✅ PASS |
| **Clarification Accuracy** | 100.0% | ≥ 90.0% | ✅ PASS |
| **Hallucination Rate** | 1.7% | ≤ 2.0% | ✅ PASS |
| **Entity Preservation** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Production Weighted Score** | **98.8%** | ≥ 90.0% | ✅ PASS |

## Latency & Economics

| Metric | Value |
|---|---|
| Total Test Cases | 176 |
| Mean Latency | 2391.1 ms |
| P50 (Median) Latency | 2347 ms |
| P95 Latency | 3586 ms |
| Total Tokens (Prompt / Completion) | 672465 (648770 / 23695) |
| Total Evaluation Cost | N/A |
| Estimated Cost / 1,000 Queries | N/A |

## Category Performance Breakdown

| Category | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| Rally Discovery | 15 | 100.0% | 93.3% | 95.7% | 100.0% | 2942 ms |
| Driver Participation | 15 | 100.0% | 100.0% | 100.0% | 100.0% | 2603 ms |
| Driver Wins | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 2304 ms |
| Results | 12 | 91.7% | 91.7% | 100.0% | 91.7% | 2404 ms |
| Leaderboards | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 2925 ms |
| Video Search | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 2706 ms |
| Video Actions | 22 | 100.0% | 100.0% | 100.0% | 100.0% | 2203 ms |
| Uploaders | 10 | 100.0% | 90.0% | 96.0% | 100.0% | 2306 ms |
| Global Stats | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 1624 ms |
| Compound Queries | 22 | 100.0% | 100.0% | 100.0% | 100.0% | 2067 ms |
| Ambiguous Queries | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 2095 ms |
| Casual Language | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 2695 ms |
| Typos | 12 | 100.0% | 91.7% | 97.4% | 100.0% | 2256 ms |

## Per-Slot Extraction Metrics

| Slot | Expected | Extracted | Correct | Precision | Recall | F1 |
|---|---|---|---|---|---|---|
| `driverName` | 63 | 63 | 63 | 100.0% | 100.0% | 100.0% |
| `rallyName` | 87 | 88 | 87 | 98.9% | 100.0% | 99.4% |
| `actionType` | 43 | 43 | 43 | 100.0% | 100.0% | 100.0% |
| `country` | 31 | 31 | 31 | 100.0% | 100.0% | 100.0% |
| `city` | 3 | 2 | 2 | 100.0% | 66.7% | 80.0% |
| `stageName` | 8 | 8 | 8 | 100.0% | 100.0% | 100.0% |
| `year` | 65 | 65 | 65 | 100.0% | 100.0% | 100.0% |
| `limit` | 21 | 166 | 21 | 12.7% | 100.0% | 22.5% |

## Failure Diagnostic Samples

### `[RAL-05]` "Rallies in Donegal."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Donegal}`
- **Actual:** Intent=`searchRallies`, Filters=`{rally: "Donegal"}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "rallyName" with value "Donegal"
  - **`missingFilter`**: Missing expected filter "city" (expected "Donegal")

### `[RES-09]` "Results of Killarney Historic Rally 2024."
- **Category:** `Results` (easy)
- **Expected:** Intent=`getRallyResults`, Filters=`{rallyName: Killarney Historic Rally, year: 2024}`
- **Actual:** Intent=`getRallyTopFinishers`, Filters=`{rally: "Killarney Historic Rally", year: 2024}`
- **Failures:**
  - **`invalidIntent`**: Expected intent getRallyResults, got getRallyTopFinishers

### `[UPL-09]` "Who uploaded the most clips for Cambrian Rally?"
- **Category:** `Uploaders` (easy)
- **Expected:** Intent=`getTopUploaders`, Filters=`{rallyName: Cambrian Rally}`
- **Actual:** Intent=`getTopUploaders`, Filters=`{rally: "Cambrian Rally", limit: 1}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "limit" with value "1"

### `[TYP-12]` "who uploded the most vids for Trackrod"
- **Category:** `Typos` (medium)
- **Expected:** Intent=`getTopUploaders`, Filters=`{rallyName: Trackrod}`
- **Actual:** Intent=`getTopUploaders`, Filters=`{rally: "Trackrod", limit: 1}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "limit" with value "1"

