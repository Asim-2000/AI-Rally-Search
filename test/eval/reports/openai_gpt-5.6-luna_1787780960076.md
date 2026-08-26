# LLM Query Parser Evaluation Report

**Provider:** `OPENAI` | **Model:** `gpt-5.6-luna` | **Evaluated At:** `2026-08-26T23:49:20.067774`

## Executive Summary

| Metric | Score | Target | Status |
|---|---|---|---|
| **Intent Accuracy** | 98.9% | ≥ 95.0% | ✅ PASS |
| **Filter Precision** | 98.8% | ≥ 90.0% | ✅ PASS |
| **Filter Recall** | 99.1% | ≥ 90.0% | ✅ PASS |
| **Filter F1 Score** | 98.9% | ≥ 90.0% | ✅ PASS |
| **Exact Match Rate** | 97.2% | ≥ 85.0% | ✅ PASS |
| **Compound Completeness** | 99.1% | ≥ 85.0% | ✅ PASS |
| **Clarification Accuracy** | 99.4% | ≥ 90.0% | ✅ PASS |
| **Hallucination Rate** | 1.1% | ≤ 2.0% | ✅ PASS |
| **Entity Preservation** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Production Weighted Score** | **98.3%** | ≥ 90.0% | ✅ PASS |

## Latency & Economics

| Metric | Value |
|---|---|
| Total Test Cases | 176 |
| Mean Latency | 1864.2 ms |
| P50 (Median) Latency | 1883 ms |
| P95 Latency | 2565 ms |
| Total Tokens (Prompt / Completion) | 800021 (777027 / 22994) |
| Total Evaluation Cost | N/A |
| Estimated Cost / 1,000 Queries | N/A |

## Category Performance Breakdown

| Category | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| Rally Discovery | 15 | 100.0% | 100.0% | 100.0% | 100.0% | 1720 ms |
| Driver Participation | 15 | 100.0% | 100.0% | 100.0% | 100.0% | 1923 ms |
| Driver Wins | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1724 ms |
| Results | 12 | 91.7% | 91.7% | 100.0% | 100.0% | 1514 ms |
| Leaderboards | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1857 ms |
| Video Search | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1985 ms |
| Video Actions | 22 | 100.0% | 100.0% | 100.0% | 100.0% | 1674 ms |
| Uploaders | 10 | 100.0% | 90.0% | 96.0% | 100.0% | 1741 ms |
| Global Stats | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 1933 ms |
| Compound Queries | 22 | 100.0% | 100.0% | 100.0% | 100.0% | 1835 ms |
| Ambiguous Queries | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 2227 ms |
| Casual Language | 12 | 91.7% | 91.7% | 93.3% | 91.7% | 2306 ms |
| Typos | 12 | 100.0% | 83.3% | 92.3% | 100.0% | 2051 ms |

## Per-Slot Extraction Metrics

| Slot | Expected | Extracted | Correct | Precision | Recall | F1 |
|---|---|---|---|---|---|---|
| `driverName` | 63 | 63 | 62 | 98.4% | 98.4% | 98.4% |
| `rallyName` | 87 | 86 | 86 | 100.0% | 98.9% | 99.4% |
| `actionType` | 43 | 43 | 43 | 100.0% | 100.0% | 100.0% |
| `country` | 31 | 31 | 31 | 100.0% | 100.0% | 100.0% |
| `city` | 3 | 3 | 3 | 100.0% | 100.0% | 100.0% |
| `stageName` | 8 | 8 | 8 | 100.0% | 100.0% | 100.0% |
| `year` | 65 | 65 | 65 | 100.0% | 100.0% | 100.0% |
| `limit` | 21 | 165 | 20 | 12.1% | 95.2% | 21.5% |

## Failure Diagnostic Samples

### `[RES-03]` "Results for Donegal International Rally."
- **Category:** `Results` (easy)
- **Expected:** Intent=`getRallyResults`, Filters=`{rallyName: Donegal International Rally}`
- **Actual:** Intent=`getRallyTopFinishers`, Filters=`{rally: "Donegal International Rally"}`
- **Failures:**
  - **`invalidIntent`**: Expected intent getRallyResults, got getRallyTopFinishers

### `[UPL-09]` "Who uploaded the most clips for Cambrian Rally?"
- **Category:** `Uploaders` (easy)
- **Expected:** Intent=`getTopUploaders`, Filters=`{rallyName: Cambrian Rally}`
- **Actual:** Intent=`getTopUploaders`, Filters=`{rally: "Cambrian Rally", limit: 1}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "limit" with value "1"

### `[CAS-08]` "wanna see top 5 guys in donegal"
- **Category:** `Casual Language` (medium)
- **Expected:** Intent=`getRallyTopFinishers`, Filters=`{rallyName: Donegal, limit: 5}`
- **Actual:** Intent=`null`, Filters=`{null}`
- **Failures:**
  - **`incorrectClarification`**: Parser incorrectly triggered clarification for a clear query
  - **`invalidIntent`**: Expected intent getRallyTopFinishers, got searchRallies
  - **`missingFilter`**: Missing expected filter "rallyName" (expected "Donegal")
  - **`incorrectFilterValue`**: Slot "limit" mismatch: expected "5", got "20"

### `[TYP-11]` "Kris Meke victories"
- **Category:** `Typos` (medium)
- **Expected:** Intent=`searchDriverWins`, Filters=`{driverName: Kris Meke}`
- **Actual:** Intent=`searchDriverWins`, Filters=`{driver: "Kris Meeke"}`
- **Failures:**
  - **`incorrectFilterValue`**: Slot "driverName" mismatch: expected "Kris Meke", got "Kris Meeke"

### `[TYP-12]` "who uploded the most vids for Trackrod"
- **Category:** `Typos` (medium)
- **Expected:** Intent=`getTopUploaders`, Filters=`{rallyName: Trackrod}`
- **Actual:** Intent=`getTopUploaders`, Filters=`{rally: "Trackrod", limit: 1}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "limit" with value "1"

