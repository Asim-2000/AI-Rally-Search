# LLM Query Parser Evaluation Report

**Provider:** `OPENAI` | **Model:** `gpt-5.6-luna` | **Evaluated At:** `2026-08-26T22:23:51.965524`

## Executive Summary

| Metric | Score | Target | Status |
|---|---|---|---|
| **Intent Accuracy** | 98.9% | ≥ 95.0% | ✅ PASS |
| **Filter Precision** | 99.0% | ≥ 90.0% | ✅ PASS |
| **Filter Recall** | 96.9% | ≥ 90.0% | ✅ PASS |
| **Filter F1 Score** | 98.0% | ≥ 90.0% | ✅ PASS |
| **Exact Match Rate** | 93.2% | ≥ 85.0% | ✅ PASS |
| **Compound Completeness** | 91.3% | ≥ 85.0% | ✅ PASS |
| **Clarification Accuracy** | 98.9% | ≥ 90.0% | ✅ PASS |
| **Hallucination Rate** | 1.1% | ≤ 2.0% | ✅ PASS |
| **Entity Preservation** | 100.0% | ≥ 95.0% | ✅ PASS |
| **Production Weighted Score** | **95.2%** | ≥ 90.0% | ✅ PASS |

## Latency & Economics

| Metric | Value |
|---|---|
| Total Test Cases | 176 |
| Mean Latency | 1986.2 ms |
| P50 (Median) Latency | 1943 ms |
| P95 Latency | 2877 ms |
| Total Tokens (Prompt / Completion) | 298357 (278234 / 20123) |
| Total Evaluation Cost | N/A |
| Estimated Cost / 1,000 Queries | N/A |

## Category Performance Breakdown

| Category | Cases | Intent Acc | Exact Match | Filter F1 | Compound Acc | Avg Latency |
|---|---|---|---|---|---|---|
| Rally Discovery | 15 | 100.0% | 100.0% | 100.0% | 100.0% | 1962 ms |
| Driver Participation | 15 | 100.0% | 100.0% | 100.0% | 100.0% | 1889 ms |
| Driver Wins | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1854 ms |
| Results | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1764 ms |
| Leaderboards | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 2018 ms |
| Video Search | 12 | 100.0% | 100.0% | 100.0% | 100.0% | 1922 ms |
| Video Actions | 22 | 100.0% | 77.3% | 93.6% | 77.3% | 2068 ms |
| Uploaders | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 2073 ms |
| Global Stats | 10 | 100.0% | 100.0% | 100.0% | 100.0% | 1508 ms |
| Compound Queries | 22 | 100.0% | 90.9% | 98.1% | 90.9% | 1929 ms |
| Ambiguous Queries | 10 | 80.0% | 80.0% | 100.0% | 80.0% | 2330 ms |
| Casual Language | 12 | 100.0% | 91.7% | 97.8% | 91.7% | 2298 ms |
| Typos | 12 | 100.0% | 83.3% | 91.9% | 83.3% | 2208 ms |

## Per-Slot Extraction Metrics

| Slot | Expected | Extracted | Correct | Precision | Recall | F1 |
|---|---|---|---|---|---|---|
| `driverName` | 63 | 63 | 63 | 100.0% | 100.0% | 100.0% |
| `rallyName` | 87 | 85 | 85 | 100.0% | 97.7% | 98.8% |
| `actionType` | 43 | 36 | 36 | 100.0% | 83.7% | 91.1% |
| `country` | 31 | 31 | 30 | 96.8% | 96.8% | 96.8% |
| `city` | 3 | 5 | 3 | 60.0% | 100.0% | 75.0% |
| `stageName` | 8 | 8 | 8 | 100.0% | 100.0% | 100.0% |
| `year` | 65 | 65 | 65 | 100.0% | 100.0% | 100.0% |
| `limit` | 21 | 168 | 21 | 12.5% | 100.0% | 22.2% |

## Failure Diagnostic Samples

### `[ACT-08]` "Show spins and doughnuts in Killarney."
- **Category:** `Video Actions` (medium)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: spin, rallyName: Killarney}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{action: "spin", city: "Killarney"}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "rallyName" (expected "Killarney")
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "city" with value "Killarney"

### `[ACT-10]` "Show water splashes from Woodpecker Rally."
- **Category:** `Video Actions` (easy)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: water splash, rallyName: Woodpecker Rally}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{rally: "Woodpecker Rally"}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "actionType" (expected "water splash")

### `[ACT-11]` "Donut clips from Trackrod Rally."
- **Category:** `Video Actions` (easy)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: donut, rallyName: Trackrod Rally}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{rally: "Trackrod Rally"}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "actionType" (expected "donut")

### `[ACT-12]` "Show hairpins and handbrake turns in Get Jerky Rally."
- **Category:** `Video Actions` (medium)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: hairpin, rallyName: Get Jerky Rally}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{rally: "Get Jerky Rally"}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "actionType" (expected "hairpin")

### `[ACT-18]` "Water crossing clips from Woodpecker."
- **Category:** `Video Actions` (medium)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: water splash, rallyName: Woodpecker}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{rally: "Woodpecker"}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "actionType" (expected "water splash")

### `[CMP-09]` "Find water splashes from Woodpecker Rally 2025 on Tarenig stage."
- **Category:** `Compound Queries` (hard)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: water splash, rallyName: Woodpecker Rally, year: 2025, stageName: Tarenig}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{rally: "Woodpecker Rally", stage: "Tarenig", year: 2025}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "actionType" (expected "water splash")

### `[CMP-10]` "Show spins in Killarney in 2024."
- **Category:** `Compound Queries` (medium)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: spin, rallyName: Killarney, year: 2024}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{action: "spin", city: "Killarney", year: 2024}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "rallyName" (expected "Killarney")
  - **`hallucinatedFilter`**: Hallucinated unsupported filter "city" with value "Killarney"

### `[AMB-04]` "Find clips"
- **Category:** `Ambiguous Queries` (medium)
- **Expected:** Intent=`null`, Filters=`{}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{}`
- **Failures:**
  - **`incorrectClarification`**: Expected query to trigger clarification, but parser produced structured query

### `[AMB-07]` "Uploaders"
- **Category:** `Ambiguous Queries` (medium)
- **Expected:** Intent=`null`, Filters=`{}`
- **Actual:** Intent=`getTopUploaders`, Filters=`{}`
- **Failures:**
  - **`incorrectClarification`**: Expected query to trigger clarification, but parser produced structured query

### `[CAS-12]` "show me some sick water splashes from woodpecker"
- **Category:** `Casual Language` (medium)
- **Expected:** Intent=`searchVideoActions`, Filters=`{actionType: water splash, rallyName: Woodpecker}`
- **Actual:** Intent=`searchVideoActions`, Filters=`{rally: "woodpecker"}`
- **Failures:**
  - **`missingFilter`**: Missing expected filter "actionType" (expected "water splash")

