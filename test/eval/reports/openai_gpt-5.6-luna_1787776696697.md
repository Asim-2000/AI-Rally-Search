# LLM Query Parser Evaluation Report

**Provider:** `OPENAI` | **Model:** `gpt-5.6-luna` | **Evaluated At:** `2026-08-26T22:38:16.688401`

## Executive Summary

| Metric | Score | Target | Status |
|---|---|---|---|
| **Intent Accuracy** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Filter Precision** | 99.7% | ≥ 90.0% | ✅ PASS |
| **Filter Recall** | 99.7% | ≥ 90.0% | ✅ PASS |
| **Filter F1 Score** | 99.7% | ≥ 90.0% | ✅ PASS |
| **Exact Match Rate** | 99.4% | ≥ 85.0% | ✅ PASS |
| **Compound Completeness** | 100.0% | ≥ 85.0% | ✅ PASS |
| **Clarification Accuracy** | 100.0% | ≥ 90.0% | ✅ PASS |
| **Hallucination Rate** | 0.6% | ≤ 2.0% | ✅ PASS |
| **Entity Preservation** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Production Weighted Score** | **99.7%** | ≥ 90.0% | ✅ PASS |

## Latency & Economics

| Metric | Value |
|---|---|
| Total Test Cases | 176 |
| Mean Latency | 1954.2 ms |
| P50 (Median) Latency | 1806 ms |
| P95 Latency | 2864 ms |
| Total Tokens (Prompt / Completion) | 472545 (454218 / 18327) |
| Total Evaluation Cost | N/A |
| Estimated Cost / 1,000 Queries | N/A |

## Category Performance Breakdown

| Category | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| Rally Discovery | 15 | 100.0% | 93.3% | 95.7% | 100.0% | 1840 ms |
| Driver Participation | 15 | 100.0% | 100.0% | 100.0% | 100.0% | 1712 ms |
| Driver Wins | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1781 ms |
| Results | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1612 ms |
| Leaderboards | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 2201 ms |
| Video Search | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1834 ms |
| Video Actions | 22 | 100.0% | 100.0% | 100.0% | 100.0% | 2150 ms |
| Uploaders | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 1965 ms |
| Global Stats | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 1601 ms |
| Compound Queries | 22 | 100.0% | 100.0% | 100.0% | 100.0% | 1822 ms |
| Ambiguous Queries | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 1966 ms |
| Casual Language | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 2353 ms |
| Typos | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 2551 ms |

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

