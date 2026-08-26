# LLM Query Parser Evaluation Report

**Provider:** `MOCK` | **Model:** `mock-parser-v1` | **Evaluated At:** `2026-08-26T23:02:23.806108`

## Executive Summary

| Metric | Score | Target | Status |
|---|---|---|---|
| **Intent Accuracy** | 54.5% | ≥ 95.0% | ⚠️ WARN |
| **Filter Precision** | 95.5% | ≥ 90.0% | ✅ PASS |
| **Filter Recall** | 78.5% | ≥ 90.0% | ⚠️ WARN |
| **Filter F1 Score** | 86.2% | ≥ 90.0% | ⚠️ WARN |
| **Exact Match Rate** | 39.8% | ≥ 85.0% | ⚠️ WARN |
| **Compound Completeness** | 46.1% | ≥ 85.0% | ⚠️ WARN |
| **Clarification Accuracy** | 94.3% | ≥ 90.0% | ✅ PASS |
| **Hallucination Rate** | 4.5% | ≤ 2.0% | ❌ FAIL |
| **Entity Preservation** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Production Weighted Score** | **56.9%** | ≥ 90.0% | ⚠️ WARN |

## Latency & Economics

| Metric | Value |
|---|---|
| Total Test Cases | 176 |
| Mean Latency | 0.0 ms |
| P50 (Median) Latency | 0 ms |
| P95 Latency | 0 ms |
| Total Tokens (Prompt / Completion) | 7040 (2640 / 4400) |
| Total Evaluation Cost | $0.000000 |
| Estimated Cost / 1,000 Queries | $0.000000 |

## Category Performance Breakdown

| Category | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| Rally Discovery | 15 | 100.0% | 73.3% | 88.4% | 93.3% | 0 ms |
| Driver Participation | 15 | 20.0% | 20.0% | 82.6% | 33.3% | 0 ms |
| Driver Wins | 12 | 50.0% | 50.0% | 82.4% | 58.3% | 0 ms |
| Results | 12 | 75.0% | 25.0% | 72.7% | 58.3% | 0 ms |
| Leaderboards | 12 | 33.3% | 25.0% | 76.0% | 25.0% | 0 ms |
| Video Search | 12 | 41.7% | 41.7% | 76.5% | 58.3% | 0 ms |
| Video Actions | 22 | 86.4% | 63.6% | 90.3% | 63.6% | 0 ms |
| Uploaders | 10 | 50.0% | 30.0% | 80.0% | 90.0% | 0 ms |
| Global Stats | 10 | 10.0% | 10.0% | 100.0% | 100.0% | 0 ms |
| Compound Queries | 22 | 77.3% | 59.1% | 94.0% | 59.1% | 0 ms |
| Ambiguous Queries | 10 | 0.0% | 0.0% | 100.0% | 0.0% | 0 ms |
| Casual Language | 12 | 50.0% | 41.7% | 90.9% | 58.3% | 0 ms |
| Typos | 12 | 50.0% | 25.0% | 77.4% | 66.7% | 0 ms |

## Per-Slot Extraction Metrics

| Slot | Expected | Extracted | Correct | Precision | Recall | F1 |
|---|---|---|---|---|---|---|
| `driverName` | 63 | 37 | 37 | 100.0% | 58.7% | 74.0% |
| `rallyName` | 87 | 64 | 63 | 98.4% | 72.4% | 83.4% |
| `actionType` | 43 | 36 | 35 | 97.2% | 81.4% | 88.6% |
| `country` | 31 | 37 | 30 | 81.1% | 96.8% | 88.2% |
| `city` | 3 | 0 | 0 | 100.0% | 0.0% | 0.0% |
| `stageName` | 8 | 6 | 6 | 100.0% | 75.0% | 85.7% |
| `year` | 65 | 63 | 63 | 100.0% | 96.9% | 98.4% |
| `limit` | 21 | 176 | 18 | 10.2% | 85.7% | 18.3% |

## Failure Diagnostic Samples

### `[RAL-05]` "Rallies in Donegal."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Donegal}`
- **Actual:** Intent=`searchRallies`, Filters=`{rally: "Donegal"}`
- **Failures:**
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "rallyName" with value "Donegal"
  - **`missingFilter`**: Missing expected filter "city" (expected "Donegal")

### `[RAL-07]` "Show Irish rallies from last year."
- **Category:** `Rally Discovery` (medium)
- **Expected:** Intent=`searchRallies`, Filters=`{country: Ireland, year: 2025}`
- **Actual:** Intent=`searchRallies`, Filters=`{country: "Ireland"}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "year" (expected "2025")

### `[RAL-08]` "Rallies held in Killarney."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Killarney}`
- **Actual:** Intent=`searchRallies`, Filters=`{}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "city" (expected "Killarney")

### `[RAL-12]` "Rallies in Alūksne."
- **Category:** `Rally Discovery` (easy)
- **Expected:** Intent=`searchRallies`, Filters=`{city: Alūksne}`
- **Actual:** Intent=`searchRallies`, Filters=`{}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "city" (expected "Alūksne")

### `[DRV-04]` "Find Irish rallies Josh Moffett entered."
- **Category:** `Driver Participation` (medium)
- **Expected:** Intent=`searchDriverRallies`, Filters=`{driverName: Josh Moffett, country: Ireland}`
- **Actual:** Intent=`searchRallies`, Filters=`{driver: "Josh Moffett", country: "Ireland"}`
- **Failures:**
  - **`invalidIntent`**: Expected intent searchDriverRallies, got searchRallies

### `[DRV-05]` "Where did Philip Squires drive in 2025?"
- **Category:** `Driver Participation` (easy)
- **Expected:** Intent=`searchDriverRallies`, Filters=`{driverName: Philip Squires, year: 2025}`
- **Actual:** Intent=`searchRallies`, Filters=`{driver: "Philip Squires", year: 2025}`
- **Failures:**
  - **`invalidIntent`**: Expected intent searchDriverRallies, got searchRallies

### `[DRV-06]` "Show all rallies entered by Kris Meeke in 2026."
- **Category:** `Driver Participation` (easy)
- **Expected:** Intent=`searchDriverRallies`, Filters=`{driverName: Kris Meeke, year: 2026}`
- **Actual:** Intent=`searchRallies`, Filters=`{driver: "Kris Meeke", year: 2026}`
- **Failures:**
  - **`invalidIntent`**: Expected intent searchDriverRallies, got searchRallies

### `[DRV-07]` "Rallies entered by Sebastien Ogier."
- **Category:** `Driver Participation` (easy)
- **Expected:** Intent=`searchDriverRallies`, Filters=`{driverName: Sebastien Ogier}`
- **Actual:** Intent=`searchRallies`, Filters=`{}`
- **Failures:**
  - **`invalidIntent`**: Expected intent searchDriverRallies, got searchRallies
  - **`missingFilter`**: Missing expected filter "driverName" (expected "Sebastien Ogier")

### `[DRV-08]` "Which rallies did Craig Breen enter in Ireland?"
- **Category:** `Driver Participation` (medium)
- **Expected:** Intent=`searchDriverRallies`, Filters=`{driverName: Craig Breen, country: Ireland}`
- **Actual:** Intent=`searchRallies`, Filters=`{driver: "Craig Breen", country: "Ireland"}`
- **Failures:**
  - **`invalidIntent`**: Expected intent searchDriverRallies, got searchRallies

### `[DRV-09]` "Show rallies for Keith Cronin in 2024."
- **Category:** `Driver Participation` (easy)
- **Expected:** Intent=`searchDriverRallies`, Filters=`{driverName: Keith Cronin, year: 2024}`
- **Actual:** Intent=`searchRallies`, Filters=`{year: 2024}`
- **Failures:**
  - **`invalidIntent`**: Expected intent searchDriverRallies, got searchRallies
  - **`missingFilter`**: Missing expected filter "driverName" (expected "Keith Cronin")

